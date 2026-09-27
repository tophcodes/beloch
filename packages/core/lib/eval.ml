(** Evaluate a program, resolving names and applying axioms. Geometry is exact;
    preconditions are reported as Error.Beloch_error. *)

open Ctx

(* Re-exported so the public [Eval] surface is unchanged for fold_emit,
   session, the test suites and packages/www/public/beloch/beloch-eval.js. *)
type snapshot = Ctx.snapshot
type stmt_kind = Ctx.stmt_kind = SFold | SMark | SBind | SApply of string
type stmt_log_entry = Ctx.stmt_log_entry = {
  sl_kind : stmt_kind;
  sl_span : Error.span;
  sl_frame_index : int;
  sl_mark : Fold_state.mark option;
  sl_kept : Fold_state.mark list;
  sl_parent : int option;
}
type free_info = Ctx.free_info = {
  fi_t : Num.t;
  fi_p0 : Geom.point;
  fi_p1 : Geom.point;
  fi_source_line : int;
}
let snapshot = Ctx.snapshot
let restore = Ctx.restore

type folded = {
  state : Fold_state.t;
  named_points : (string * Geom.point * int * int option) list;
      (* [int] is the 0-based creation step (index into [frames] at bind
         time); see [scope.point_steps]/[scope.line_steps] *)
  named_lines : (string * Geom.line * int * int option) list;
  named_line_cids : (string * int) list;
      (* crease id per name for [Material]/[Mark] creases — the identity the
         line coefficients in [named_lines] lose (a folded crease's current
         line can coincide with another crease's line) *)
  frames : (Fold_state.t * Error.span option) list;
  statements : stmt_log_entry list;
  references : Ctx.reference list;
  annotations : Ctx.annot_entry list;
  trace : Trace.entry list;
  free_points : (string * free_info) list;
      (* one entry per `free on` point, recorded at bind time in the [PsFree]
         arm — a running log (like [statements]), not reconstructed from
         scope state at finalize (unlike [named_points]), since [free_info]
         carries per-placement data the point's final bound value alone
         doesn't retain. *)
}

let eval_free_point (ctx : Ctx.ctx) (n : string) (line : Ast.line_operand)
    (anchor : Ast.point_operand) (t : Num.t option) (span : Error.span) : unit =
  (* `free on` measures along material, so its line slot is crease-sorted
     (spec/BELOCH.md, Parameter types). *)
  let l, chords_opt =
    match line with
    | Ast.LNamed cr -> (
        match Resolve.crease_of ctx cr ~slot:"free on" cr.Ast.cspan with
        | Bundle expr -> Resolve.resolve_paper_line ctx expr
        | cv -> Resolve.paper_line_of_crease ctx ~name:cr.Ast.cname cr.Ast.cspan cv)
    | _ -> Resolve.resolve_paper_line ctx line
  in
  let p0raw, p1raw =
    match chords_opt with
    | None -> (
        match Geom.clip_to_unit_square l with
        | Some (a, b) -> (a, b)
        | None -> Error.fail span "the line does not cross the paper")
    | Some chords -> (
        match Geom.material_bundle chords with
        | Some (a, b) -> (a, b)
        | None -> Error.fail span "the line has no material on the paper")
  in
  let ax = Resolve.resolve_point ctx anchor in
  (* orient: t=0 at the anchor endpoint *)
  let e0, e1 =
    if Geom.point_equal ax p0raw then (p0raw, p1raw)
    else if Geom.point_equal ax p1raw then (p1raw, p0raw)
    else Error.fail span "the anchor is not an endpoint of the line's material"
  in
  let tv = match t with Some v -> v | None -> Num.div Num.one (Num.of_int 2) in
  if Num.sign tv < 0 || Num.compare tv Num.one > 0 then
    Error.fail span "t is out of range (must be between 0 and 1)";
  let px = Num.add e0.Geom.x (Num.mul tv (Num.sub e1.Geom.x e0.Geom.x)) in
  let py = Num.add e0.Geom.y (Num.mul tv (Num.sub e1.Geom.y e0.Geom.y)) in
  bind_point ctx n span { Geom.x = px; y = py };
  (* namespace the emitted name the same way prov_name qualifies crease
     provenance (~1439-1445): a bare name collides across independent
     `apply` instances of the same def, since [free_points_rev] is one
     flat list across the whole eval, not scoped per instance. Temp
     names are dropped, mirroring the is_temp filter that already keeps
     `_`-prefixed names out of named_points/named_lines. *)
  (match ctx.name_ctx with
  | _ when is_temp n -> ()
  | Root ->
      ctx.free_points_rev <-
        (n,
         { fi_t = tv; fi_p0 = e0; fi_p1 = e1;
           fi_source_line = (fst span).Lexing.pos_lnum })
        :: ctx.free_points_rev
  | InInstance i ->
      ctx.free_points_rev <-
        (i ^ "." ^ n,
         { fi_t = tv; fi_p0 = e0; fi_p1 = e1;
           fi_source_line = (fst span).Lexing.pos_lnum })
        :: ctx.free_points_rev
  | Anon -> ())

let eval_def (ctx : Ctx.ctx) (name : string) (params : Ast.param list)
    (body : Ast.stmt list) (span : Error.span) : unit =
  if Hashtbl.mem ctx.defs name then
    Error.fail span (Printf.sprintf "def %s is already defined" name);
  let seen = Hashtbl.create 4 in
  List.iter
    (fun (p : Ast.param) ->
      if Hashtbl.mem seen p.Ast.pname then
        Error.fail p.Ast.pspan
          (Printf.sprintf "duplicate parameter %s" p.Ast.pname);
      Hashtbl.replace seen p.Ast.pname ())
    params;
  Hashtbl.replace ctx.defs name (ctx.next_def_idx, params, body);
  ctx.next_def_idx <- ctx.next_def_idx + 1

let eval_export (ctx : Ctx.ctx) (entries_opt : Ast.export_entry list option)
    (iname : string) (span : Error.span) : unit =
  let inst = lookup_instance ctx iname span in
  let cur = List.hd ctx.scopes in
  let land_name ~(kind : [ `Point | `Line ]) ~(shadow : bool)
      ~(espan : Error.span) (src : string) (target : string) =
    let target_exists, sigil =
      match kind with
      | `Point -> (Hashtbl.mem cur.points target, ".")
      | `Line -> (Hashtbl.mem cur.lines target, "--")
    in
    (if not (is_temp target) then
       match (target_exists, shadow) with
       | true, false ->
           Error.fail ~hint:"use ! to shadow" espan
             (Printf.sprintf "%s%s exists" sigil target)
       | false, true ->
           Error.fail ~hint:"remove !" espan
             (Printf.sprintf "nothing to shadow with %s%s" sigil target)
       | _ -> ());
    (* the landed name is the SAME geometric object as the source member
       inside the def body: it carries the source's own creation step,
       not a fresh one at export time (defaults to 0 if the source was
       never routed through bind_point/bind_crease, e.g. a def
       parameter passed straight through unmodified). Looked up in the
       kind-appropriate table (point vs line) so a same-stem point/line
       pair can't clobber each other's step. *)
    match kind with
    | `Point -> (
        let step =
          Option.value (Hashtbl.find_opt inst.ipoint_steps src) ~default:(0, None)
        in
        match Hashtbl.find_opt inst.ipoints src with
        | Some v ->
            Hashtbl.replace cur.points target v;
            Hashtbl.replace cur.point_steps target step
        | None ->
            Error.fail espan
              (Printf.sprintf "instance $%s has no point member %s" iname src))
    | `Line -> (
        let step =
          Option.value (Hashtbl.find_opt inst.iline_steps src) ~default:(0, None)
        in
        match Hashtbl.find_opt inst.ilines src with
        | Some v ->
            Hashtbl.replace cur.lines target v;
            Hashtbl.replace cur.line_steps target step
        | None ->
            Error.fail espan
              (Printf.sprintf "instance $%s has no line member %s" iname src))
  in
  (match entries_opt with
  | Some entries ->
      List.iter
        (fun (e : Ast.export_entry) ->
          land_name ~kind:e.Ast.ekind ~shadow:e.Ast.eshadow ~espan:e.Ast.espan
            e.Ast.esrc
            (Option.value e.Ast.erename ~default:e.Ast.esrc))
        entries
  | None ->
      Hashtbl.iter
        (fun k _ -> land_name ~kind:`Point ~shadow:false ~espan:span k k)
        inst.ipoints;
      Hashtbl.iter
        (fun k _ -> land_name ~kind:`Line ~shadow:false ~espan:span k k)
        inst.ilines)

let rec eval_stmt (ctx : Ctx.ctx) (stmt : Ast.stmt) : unit =
  match stmt with
  | Ast.Annotation a ->
      ctx.annots_pending <- Annotation.resolve ctx a :: ctx.annots_pending
  | Ast.BindBundle (name, expr, span) ->
      bind_crease ctx name span (Bundle expr)
  | Ast.BindLine (n, c, sides, span) ->
      (* pure value: resolve the construction to a line, bind Frozen, no
         subdivide *)
      let axis =
        (Axiom.select ctx span (snd (Axiom.axis_of ctx span c)) ~fold:false sides)
          .Axiom.line
      in
      bind_crease ctx n span (Frozen axis)
  | Ast.Mark (out, m, ext, dir, layer_opt, sides, span) ->
      Action.eval_mark ctx out m ext dir layer_opt sides span
  | Ast.Fold (out, m, fs, span) -> Action.eval_fold ctx out m fs span
  | Ast.Reverse (out, m, rs, span) -> Action.eval_reverse ctx out m rs span
  | Ast.Point (n, Ast.PsExpr po, span) ->
      bind_point ctx n span (Resolve.resolve_point ctx po)
  | Ast.Point (n, Ast.PsFree { line; anchor; t; span }, _) ->
      eval_free_point ctx n line anchor t span
  | Ast.Flip _ ->
      ctx.state := Fold_state.flip !(ctx.state);
      ctx.pending <- true
  | Ast.Def (name, params, body, span) -> eval_def ctx name params body span
  | Ast.Apply (bind_opt, defname, args, span) ->
      eval_apply ctx bind_opt defname args span
  | Ast.Export (entries_opt, iname, span) -> eval_export ctx entries_opt iname span
  | Ast.Flatten (out, elems, overs, staying_opt, toward_opt, span) ->
      (* the emergent crease is minted inside the solver, where the even case
         mints nothing, so the id this call returns (-1) has no reader.
         `into` hands the solver its own id and axis check: the emergent
         crease is scored under the named crease's id, on its line. *)
      let cid, check_axis, bind_out = Action.crease_id_for ctx out ~fresh:(fun () -> -1) in
      let into =
        match out with
        | Ast.Into _ -> Some (cid, check_axis)
        | Ast.Anonymous | Ast.Named _ -> None
      in
      Flatten_solve.run ctx ~into ~bind_out ~elems ~overs ~staying_opt
        ~toward_opt span

and eval_apply (ctx : Ctx.ctx) (bind_opt : string option) (defname : string)
    (args : Ast.arg list) (span : Error.span) : unit =
  let def_idx, params, body =
    match Hashtbl.find_opt ctx.defs defname with
    | Some d -> d
    | None -> Error.fail span (Printf.sprintf "undefined def %s" defname)
  in
  (match ctx.cur_def_idx with
  | Some k when def_idx >= k ->
      Error.fail span
        (Printf.sprintf "def %s is not defined before this body" defname)
  | _ -> ());
  if List.length args <> List.length params then
    Error.fail span
      (Printf.sprintf "def %s takes %d argument(s), got %d" defname
         (List.length params) (List.length args));
  (* resolve args in the CALLER scope, then swap in the closed scope *)
  let body_scope = make_scope () in
  List.iter2
    (fun (p : Ast.param) (a : Ast.arg) ->
      match (p.Ast.pkind, a) with
      | `Point, Ast.APoint po ->
          Hashtbl.replace body_scope.points p.Ast.pname (Resolve.resolve_point ctx po)
      | `Line, Ast.ALine lo ->
          (* a named crease argument stays material inside the body
             (cross needs its marks); only constructed lines freeze *)
          let cv =
            match lo with
            | Ast.LNamed cr -> lookup_crease ctx cr
            | Ast.LFilter _ | Ast.LUnion _ | Ast.LSelect _ ->
                Frozen (Resolve.resolve_line ctx lo)
          in
          Hashtbl.replace body_scope.lines p.Ast.pname cv
      | `Point, Ast.ALine _ ->
          Error.fail span
            (Printf.sprintf "parameter .%s of %s needs a point argument"
               p.Ast.pname defname)
      | `Line, Ast.APoint _ ->
          Error.fail span
            (Printf.sprintf "parameter --%s of %s needs a line argument"
               p.Ast.pname defname))
    params args;
  let saved_scopes = ctx.scopes
  and saved_nctx = ctx.name_ctx
  and saved_def_idx = ctx.cur_def_idx in
  ctx.scopes <- [ body_scope ];
  ctx.cur_def_idx <- Some def_idx;
  (ctx.name_ctx <-
     (match (bind_opt, saved_nctx) with
     | None, _ -> Anon
     | Some i, _ when is_temp i -> Anon
     | Some _, Anon -> Anon
     | Some i, Root -> InInstance i
     | Some i, InInstance outer -> InInstance (outer ^ "." ^ i)));
  let saved_parent = ctx.parent in
  ctx.parent <- Some (push_apply ctx defname span);
  List.iter (eval_logged ctx) body;
  ctx.parent <- saved_parent;
  ctx.scopes <- saved_scopes;
  ctx.name_ctx <- saved_nctx;
  ctx.cur_def_idx <- saved_def_idx;
  (match bind_opt with
  | None -> ()
  | Some iname ->
      let cur = List.hd ctx.scopes in
      if (not (is_temp iname)) && Hashtbl.mem cur.instances iname then
        Error.fail span
          (Printf.sprintf
             "instance $%s is already bound; only _-prefixed temps rebind"
             iname);
      let inst =
        { ipoints = Hashtbl.create 8; ilines = Hashtbl.create 8;
          ipoint_steps = Hashtbl.create 8; iline_steps = Hashtbl.create 8 }
      in
      Hashtbl.iter
        (fun k v -> if not (is_temp k) then Hashtbl.replace inst.ipoints k v)
        body_scope.points;
      Hashtbl.iter
        (fun k v -> if not (is_temp k) then Hashtbl.replace inst.ilines k v)
        body_scope.lines;
      (* carries each member's OWN creation step (recorded in the def
         body's own scope) forward onto the instance, so a later
         [export] can stamp the landed name with the source's real
         step instead of defaulting to 0 (see [land_name]). Points and
         lines carried separately (see [scope.point_steps]/
         [line_steps]) so a same-stem point/line pair can't clobber
         each other's step. *)
      Hashtbl.iter
        (fun k v -> if not (is_temp k) then Hashtbl.replace inst.ipoint_steps k v)
        body_scope.point_steps;
      Hashtbl.iter
        (fun k v -> if not (is_temp k) then Hashtbl.replace inst.iline_steps k v)
        body_scope.line_steps;
      Hashtbl.replace cur.instances iname inst)

(* Evaluate one statement and give it its entry on the second axis. A write
   logs itself as it pushes its frame or records its mark, and an [apply]
   logs itself ahead of its body; a statement that logged nothing bound a
   name and moved no paper, and gets its entry here (ADR 0030). *)
and eval_logged (ctx : Ctx.ctx) (stmt : Ast.stmt) : unit =
  match stmt with
  | Ast.Annotation _ -> eval_stmt ctx stmt
  | _ ->
      (* the annotations waiting for this statement take its entry, which is
         the next one logged *)
      let logged = List.length ctx.statements_rev in
      ctx.annots_rev <-
        List.map (fun a -> { a with an_target = logged }) ctx.annots_pending
        @ ctx.annots_rev;
      ctx.annots_pending <- [];
      (try eval_stmt ctx stmt
       with Error.Beloch_error _ as e ->
         (* a statement that fails before logging itself still gets its
            entry, so a traced run can point at it *)
         if List.length ctx.statements_rev = logged then
           Ctx.push_entry ctx (Ctx.kind_of_stmt stmt) (Spine.span_of_stmt stmt);
         raise e);
      if List.length ctx.statements_rev = logged then
        Ctx.push_bind ctx (Spine.span_of_stmt stmt)

let build_output (ctx : Ctx.ctx) (root_scope : Ctx.scope) : folded =
  (* corners and other names never routed through bind_point/bind_crease (the
     prelude corners/edges, set up directly via Hashtbl.replace above) have no
     entry in root_scope.point_steps/.line_steps; they default to step 0.
     Reads root_scope.point_steps/.line_steps the same way named_points/
     named_lines below read root_scope.points/.lines — scoped tables, saved/
     restored across `apply` exactly like those. Kept separate (not one
     shared-key table) because points and lines are separate namespaces: a
     point and a line may share a stem (`.m` / `--m`) without clobbering each
     other's step. *)
  let step_of_point n =
    match Hashtbl.find_opt root_scope.point_steps n with
    | Some s -> s
    | None -> (0, None)
  in
  let step_of_line n =
    match Hashtbl.find_opt root_scope.line_steps n with
    | Some s -> s
    | None -> (0, None)
  in
  (* Sorted by name: Hashtbl.fold/iter order depends on internal bucket
     layout, which differs between a fresh eval (insert in program order)
     and a restored session (Hashtbl.reset + Hashtbl.iter replace). Sorting
     here makes the emitted overlay arrays independent of that iteration
     order, so fresh and resumed evals of the same program are byte-identical. *)
  let named_points =
    Hashtbl.fold
      (fun k v acc ->
        if is_temp k then acc
        else
          let frame, stmt = step_of_point k in
          (k, v, frame, stmt) :: acc)
      root_scope.points []
    |> List.sort (fun (a, _, _, _) (b, _, _, _) -> String.compare a b)
  in
  let named_lines =
    Hashtbl.fold
      (fun k cv acc ->
        if is_temp k then acc
        else
          let frame, stmt = step_of_line k in
          match cv with
          | Frozen l -> (k, l, frame, stmt) :: acc
          | Mark (_, l) -> (k, l, frame, stmt) :: acc
          | Material (cid, l_orig) -> (
              match Fold_state.crease_axis !(ctx.state) cid l_orig with
              | `Line l -> (k, l, frame, stmt) :: acc
              (* bent by a later fold, no material endpoints left, or folded
                 onto a single point: no single current line to emit, so omit
                 from the map rather than emit the stale frozen original *)
              | `Bent | `Empty | `Collapsed -> acc)
          (* a bundle is not a single line; it is not emitted in the
             one-line-per-name overlay map. the prelude paper edges are
             implicit, not user-declared construction lines, so they are
             likewise not emitted. *)
          | Bundle _ | Edge _ -> acc)
      root_scope.lines []
    |> List.sort (fun (a, _, _, _) (b, _, _, _) -> String.compare a b)
  in
  let named_line_cids =
    Hashtbl.fold
      (fun k cv acc ->
        if is_temp k then acc
        else
          match cv with
          | Material (cid, _) | Mark (cid, _) -> (k, cid) :: acc
          | Frozen _ | Bundle _ | Edge _ -> acc)
      root_scope.lines []
    |> List.sort (fun (a, _) (b, _) -> String.compare a b)
  in
  if ctx.pending then
    ctx.frames_rev <- (!(ctx.state), None) :: ctx.frames_rev;
  let frames = List.rev ctx.frames_rev in
  let statements = List.rev ctx.statements_rev in
  let free_points = List.rev ctx.free_points_rev in
  { state = !(ctx.state); named_points; named_lines; named_line_cids; frames;
    statements; free_points;
    references = List.rev ctx.references_rev;
    annotations = List.rev ctx.annots_rev;
    trace = List.rev ctx.trace_rev }

let run_program (ctx : Ctx.ctx) on_step (prog : Ast.program) : unit =
  List.iter
    (fun stmt ->
      (* a kernel precondition the language checks missed (a zero inverse, a
         point in no face) is reported against the statement that hit it *)
      (try eval_logged ctx stmt
       with Invalid_argument msg ->
         Error.fail (Spine.span_of_stmt stmt)
           (Printf.sprintf "internal error in this statement: %s" msg));
      on_step ctx)
    prog

let eval_program ?(resume : snapshot option) ?(on_step : ctx -> unit = fun _ -> ())
    (prog : Ast.program) : folded =
  (match resume with None -> Fold_state.reset_ids () | Some _ -> ());
  let ctx = Ctx.create () in
  (match resume with Some s -> restore ctx s | None -> ());
  run_program ctx on_step prog;
  build_output ctx (List.hd ctx.scopes)

let eval_folded (prog : Ast.program) : folded = eval_program prog
