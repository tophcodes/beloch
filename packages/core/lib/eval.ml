(** Evaluate a program, resolving names and applying axioms. Geometry is exact;
    preconditions are reported as Error.Beloch_error. *)

open Ctx

(* Re-exported so the public [Eval] surface is unchanged for [fold_emit],
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
      (* crease id per name for [Material]/[Mark] creases: the identity the
         line coefficients in [named_lines] lose (a folded crease's current
         line can coincide with another crease's line) *)
  frames : (Fold_state.t * Error.span option) list;
  statements : stmt_log_entry list;
  references : Ctx.reference list;
  annotations : Ctx.annot_entry list;
  trace : Trace.entry list;
  sheet : Sheet.t;
      (* the sheet the program opened, whose unfolded state is frame 0 *)
  unit_name : string;  (* the unit the file declares, "unit" for none *)
  free_points : (string * free_info) list;
      (* one entry per `free on` point, recorded at bind time in the [PsFree]
         arm: a running log (like [statements]), not reconstructed from
         scope state at finalize (unlike [named_points]), since [free_info]
         carries per-placement data the point's final bound value alone
         doesn't retain. *)
}

(* The value of a number of the source: a literal, or a parameter of the
   shape whose body is running. *)
let number_value (ctx : Ctx.ctx) (n : Ast.number) : Q.t =
  match n with
  | Ast.NLit (q, _) -> q
  | Ast.NParam (w, sp) -> (
      match ctx.shape_params with
      | Some env -> (
          match List.assoc_opt w env with
          | Some q -> q
          | None ->
              Error.fail sp (Printf.sprintf "`%s` is no parameter of this shape" w))
      | None ->
          Error.fail sp
            (Printf.sprintf
               "`%s` is no number; a name stands for a number only in a shape body"
               w))

let eval_free_point (ctx : Ctx.ctx) (n : string) (line : Ast.line_operand)
    (anchor : Ast.point_operand) (pos : Ast.free_pos option) (span : Error.span) : unit =
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
        match Sheet.clip ctx.sheet l with
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
  let tv =
    match pos with
    | None -> Num.div Num.one (Num.of_int 2)
    | Some (Ast.FreeAt t) ->
        let tv = Num.of_q (number_value ctx t) in
        if Num.sign tv < 0 || Num.compare tv Num.one > 0 then
          Error.fail span "t is out of range (must be between 0 and 1)";
        tv
    | Some (Ast.FreeBy d) ->
        (* the distance as a fraction of the range's length, which the
           kernel holds exactly (ADR 0012, 0013) *)
        let d = Num.of_q (number_value ctx d) in
        let dx = Num.sub e1.Geom.x e0.Geom.x and dy = Num.sub e1.Geom.y e0.Geom.y in
        let len = Num.sqrt (Num.add (Num.mul dx dx) (Num.mul dy dy)) in
        if Num.compare d len > 0 then
          Error.fail span "the distance is longer than the line's material";
        Num.div d len
  in
  let px = Num.add e0.Geom.x (Num.mul tv (Num.sub e1.Geom.x e0.Geom.x)) in
  let py = Num.add e0.Geom.y (Num.mul tv (Num.sub e1.Geom.y e0.Geom.y)) in
  bind_point ctx n span { Geom.x = px; y = py };
  (* namespace the emitted name the same way [prov_name] qualifies crease
     [provenance] (~1439-1445): a bare name collides across independent
     `apply` instances of the same def, since [free_points_rev] is one
     flat list across the whole evaluation, not scoped per instance. Temp
     names are dropped, mirroring the [is_temp] filter that already keeps
     `_`-prefixed names out of named_points/[named_lines]. *)
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
  if Hashtbl.mem ctx.shapes name then
    Error.fail span (Printf.sprintf "%s is already defined as a shape" name);
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
  | Ast.Unfold (lo, fs, span) -> Action.eval_unfold ctx lo fs span
  | Ast.Point (n, Ast.PsExpr po, span) ->
      bind_point ctx n span (Resolve.resolve_point ctx po)
  | Ast.Point (n, Ast.PsFree { line; anchor; pos; span }, _) ->
      eval_free_point ctx n line anchor pos span
  | Ast.Flip span ->
      (* a flip is a write (ADR 0030): it gets a frame and an entry of its own *)
      ctx.state := Fold_state.flip !(ctx.state);
      Ctx.push_frame ctx (Some span)
  | Ast.Def (name, params, body, span) -> eval_def ctx name params body span
  | Ast.Apply (bind_opt, defname, args, span) ->
      eval_apply ctx bind_opt defname args span
  | Ast.Export (entries_opt, iname, span) -> eval_export ctx entries_opt iname span
  | Ast.Flatten (out, elems, overs, staying_opt, on_opt, toward_opt, span) ->
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
      Flatten_solve.run ctx ~into ~bind_out ~elems ~overs ~staying_opt ~on_opt
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
  (* resolve [args] in the CALLER scope, then swap in the closed scope *)
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
  (* the annotations after the body's last statement belong to the state it
     left; they keep the target -1 *)
  ctx.annots_rev <- ctx.annots_pending @ ctx.annots_rev;
  ctx.annots_pending <- [];
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
     [named_lines] below read root_scope.points/.lines: scoped tables, saved/
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
     layout, which differs between a fresh evaluation (insert in program order)
     and a restored session (Hashtbl.reset + Hashtbl.iter replace). Sorting
     here makes the emitted overlay arrays independent of that iteration
     order, so fresh and resumed evaluations of the same program are byte-identical. *)
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
    statements; free_points; sheet = ctx.sheet; unit_name = ctx.unit_name;
    references = List.rev ctx.references_rev;
    (* the annotations after the program's last statement belong to the final
       state; they keep the target -1 *)
    annotations = List.rev (ctx.annots_pending @ ctx.annots_rev);
    trace = List.rev ctx.trace_rev }

let run_stmts (ctx : Ctx.ctx) on_step (stmts : Ast.stmt list) : unit =
  List.iter
    (fun stmt ->
      (* a kernel precondition the language checks missed (a zero inverse, a
         point in no face) is reported against the statement that hit it *)
      (try eval_logged ctx stmt
       with Invalid_argument msg ->
         Error.fail (Spine.span_of_stmt stmt)
           (Printf.sprintf "internal error in this statement: %s" msg));
      on_step ctx)
    stmts

(* ---- Sheets (spec/BELOCH.md, "Sheets") ---- *)

(* the physical units of the FOLD format, each a rational multiple of the
   millimeter *)
let units = [ "in"; "pt"; "m"; "cm"; "mm"; "um"; "nm" ]

(* A sheet with the names it comes with. *)
type opened = {
  o_sheet : Sheet.t;
  o_points : (string * Geom.point) list;
  o_lines : (string * Ctx.crease_val) list;
}

let square_opened (side : Num.t) : opened =
  let sheet = Sheet.square side in
  let name i = String.make 1 "abcd".[i mod 4] in
  {
    o_sheet = sheet;
    o_points = Array.to_list (Array.mapi (fun i p -> (name i, p)) (Sheet.square_corners side));
    o_lines =
      List.mapi
        (fun i (pa, pb) ->
          let n = name i ^ name (i + 1) in
          (n, Ctx.Edge (n, Geom.line_through pa pb)))
        sheet.Sheet.outline;
  }

(* Whether the outline of [sheet] runs along [l] for a positive length. *)
let outline_on (sheet : Sheet.t) (l : Geom.line) : bool =
  List.exists (fun (b, _) -> Geom.same_line b l) (Sheet.boundary_lines sheet)

(* A bundle keeps its expression, which reads the names [points] and
   [lines] of [sheet]: there it names the part of its pieces on the sheet.
   One that names no piece there, or reads a name that is gone, is gone
   itself; dropping one can drop another that reads it, so the check repeats
   until it holds. *)
let settle_bundles (sheet : Sheet.t) (points : (string * Geom.point) list)
    (lines : (string * Ctx.crease_val) list) : (string * Ctx.crease_val) list =
  let names_pieces lines expr =
    let sctx = Ctx.create () in
    Ctx.open_sheet sctx sheet ~points ~lines;
    match Resolve.bundle_segments sctx expr with
    | _, _ :: _ -> true
    | _, [] -> false
    | exception Error.Beloch_error _ -> false
  in
  let rec settle lines =
    let kept =
      List.filter
        (fun (_, cv) ->
          match cv with Ctx.Bundle expr -> names_pieces lines expr | _ -> true)
        lines
    in
    if List.length kept = List.length lines then lines else settle kept
  in
  settle lines

(* The names of the body [bctx] that lie on the trimmed [sheet], cut from
   the faces [flap] of the body's last state: a point on it, a line for its
   part on it. A crease with flat hinges or marks left on the sheet stays a
   crease, one that runs along the sheet's outline becomes an edge of it, a
   bundle keeps its expression where that names a piece on the sheet, and
   every other name, a temp among them, is gone. *)
let trimmed_names (bctx : Ctx.ctx) (flap : int list) (sheet : Sheet.t) :
    (string * Geom.point) list * (string * Ctx.crease_val) list =
  let old_st = !(bctx.state) and st = sheet.Sheet.start in
  let root = List.hd bctx.scopes in
  let on_sheet p =
    Array.exists (fun f -> Geom.in_convex_polygon f p) (Fold_state.faces st)
  in
  let sorted tbl =
    Hashtbl.fold (fun k v acc -> if is_temp k then acc else (k, v) :: acc) tbl []
    |> List.sort (fun (a, _) (b, _) -> String.compare a b)
  in
  let points = List.filter (fun (_, p) -> on_sheet p) (sorted root.points) in
  let hinge_lines g keep cid =
    let hs = Fold_state.hinges g in
    List.filter_map
      (fun i ->
        let h = hs.(i) in
        if h.Fold_state.crease_id = cid && keep h then
          let a, b = Fold_state.hinge_segment g i in
          Some (Geom.line_through a b)
        else None)
      (List.init (Array.length hs) Fun.id)
  in
  (* the line a crease runs along the outline of the sheet, if it does *)
  let as_edge name cid =
    let in_flap f = List.mem f flap in
    match
      hinge_lines old_st
        (fun h -> in_flap h.Fold_state.fa <> in_flap h.Fold_state.fb)
        cid
    with
    | l :: rest
      when List.for_all (Geom.same_line l) rest && outline_on sheet l ->
        Some (Ctx.Edge (name, l))
    | _ -> None
  in
  let lines =
    List.filter_map
      (fun (k, cv) ->
        let carried =
          match cv with
          | Ctx.Edge (_, l) -> if outline_on sheet l then Some (Ctx.Edge (k, l)) else None
          | Ctx.Material (cid, _) -> (
              match hinge_lines st (fun _ -> true) cid with
              | l :: _ when not (List.mem cid sheet.Sheet.joins) ->
                  Some (Ctx.Material (cid, l))
              | _ -> as_edge k cid)
          | Ctx.Mark (cid, _) -> (
              match Fold_state.mark_chords st cid with
              | (a, b) :: _ -> Some (Ctx.Mark (cid, Geom.line_through a b))
              | [] -> None)
          | Ctx.Frozen l -> (
              match Sheet.clip sheet l with Some _ -> Some cv | None -> None)
          | Ctx.Bundle _ -> Some cv
        in
        Option.map (fun cv -> (k, cv)) carried)
      (sorted root.lines)
  in
  (points, settle_bundles sheet points lines)

(* The names a trim's list exports (ADR 0047): each entry's name of the
   body, which must lie on the trimmed sheet, under its landing name. *)
let exported (bctx : Ctx.ctx) (sheet : Sheet.t)
    ~(points : (string * Geom.point) list)
    ~(lines : (string * Ctx.crease_val) list) (entries : Ast.export_entry list) :
    (string * Geom.point) list * (string * Ctx.crease_val) list =
  let root = List.hd bctx.scopes in
  let landed = Hashtbl.create 8 in
  let pick (e : Ast.export_entry) =
    let sigil = match e.Ast.ekind with `Point -> "." | `Line -> "--" in
    let src = e.Ast.esrc and dst = Option.value e.Ast.erename ~default:e.Ast.esrc in
    if is_temp src then
      Error.fail e.Ast.espan
        (Printf.sprintf "`%s%s` is a temp; a trim exports no temp" sigil src);
    if Hashtbl.mem landed (sigil ^ dst) then
      Error.fail e.Ast.espan (Printf.sprintf "two entries land on `%s%s`" sigil dst);
    Hashtbl.replace landed (sigil ^ dst) ();
    let bound, carried =
      match e.Ast.ekind with
      | `Point ->
          ( Hashtbl.mem root.points src,
            Option.map (fun p -> `P (dst, p)) (List.assoc_opt src points) )
      | `Line ->
          ( Hashtbl.mem root.lines src,
            Option.map
              (fun cv ->
                `L (dst, match cv with Ctx.Edge (_, l) -> Ctx.Edge (dst, l) | cv -> cv))
              (List.assoc_opt src lines) )
    in
    match carried with
    | Some c -> c
    | None when bound ->
        Error.fail e.Ast.espan
          (Printf.sprintf "`%s%s` does not lie on the flap" sigil src)
    | None ->
        Error.fail e.Ast.espan
          (Printf.sprintf "undefined %s %s%s"
             (match e.Ast.ekind with `Point -> "point" | `Line -> "crease")
             sigil src)
  in
  let picked = List.map (fun e -> (e, pick e)) entries in
  let points = List.filter_map (fun (_, c) -> match c with `P x -> Some x | `L _ -> None) picked in
  let lines = List.filter_map (fun (_, c) -> match c with `L x -> Some x | `P _ -> None) picked in
  (* a listed bundle reads the names of the body; it must still name its
     pieces through the names the list exports *)
  let settled = settle_bundles sheet points lines in
  List.iter
    (fun ((e : Ast.export_entry), c) ->
      match c with
      | `L (dst, Ctx.Bundle _) when not (List.mem_assoc dst settled) ->
          Error.fail e.Ast.espan
            (Printf.sprintf "`--%s` reads a name the trim does not export" e.Ast.esrc)
      | _ -> ())
    picked;
  (points, lines)

(* The sheet a `paper` line opens, with the names it comes with. A shape is
   opened by running its body on a context of its own, which sees the
   shapes before it and its parameters, and trimming the body's last state
   to the flap the body names. *)
let rec open_sheet (ctx : Ctx.ctx) ~(visible : int) (sheet : Ast.sheet) : opened =
  match sheet with
  | Ast.SSquare (n, sp) ->
      let side =
        match n with Some n -> Num.of_q (number_value ctx n) | None -> Num.one
      in
      if Num.sign side <= 0 then
        Error.fail sp "the side of a square is a positive number";
      square_opened side
  | Ast.SShape (name, args, sp) -> (
      match Hashtbl.find_opt ctx.shapes name with
      | Some (idx, sd) when idx < visible ->
          let np = List.length sd.Ast.sd_params and na = List.length args in
          if np <> na then
            Error.fail sp
              (Printf.sprintf "`%s` takes %d number%s, %d given" name np
                 (if np = 1 then "" else "s")
                 na);
          let env =
            List.map2 (fun (p, _) a -> (p, number_value ctx a)) sd.Ast.sd_params args
          in
          open_shape ctx ~idx ~env sd
      | _ -> Error.fail sp (Printf.sprintf "`%s` is no shape" name))

and open_shape (ctx : Ctx.ctx) ~(idx : int) ~(env : (string * Q.t) list)
    (sd : Ast.shape_def) : opened =
  let bctx = Ctx.create () in
  Hashtbl.iter (fun k v -> Hashtbl.replace bctx.shapes k v) ctx.shapes;
  bctx.shape_params <- Some env;
  let o = open_sheet bctx ~visible:idx sd.Ast.sd_sheet in
  Ctx.open_sheet bctx o.o_sheet ~points:o.o_points ~lines:o.o_lines;
  run_stmts bctx ignore sd.Ast.sd_body;
  let fa, tspan = sd.Ast.sd_trim in
  let flap = Resolve.resolve_flap_cluster bctx fa tspan in
  (* a crease the body folded at any point is no crease of the trimmed sheet *)
  let folded = Hashtbl.create 8 in
  List.iter
    (fun (st, _) ->
      Array.iter
        (fun (h : Fold_state.hinge) ->
          if Num.sign h.Fold_state.angle <> 0 then
            Hashtbl.replace folded h.Fold_state.crease_id ())
        (Fold_state.hinges st))
    ((!(bctx.state), None) :: bctx.frames_rev);
  match Sheet.trim !(bctx.state) flap ~folded:(Hashtbl.mem folded) with
  | Error `Hole -> Error.fail tspan "the flap has a hole and is no sheet"
  | Ok sheet ->
      let points, lines = trimmed_names bctx flap sheet in
      let points, lines =
        match sd.Ast.sd_exports with
        | None -> (points, lines)
        | Some entries -> exported bctx sheet ~points ~lines entries
      in
      { o_sheet = sheet; o_points = points; o_lines = lines }

(* The header of [prog] on a fresh [ctx]: the unit, the shapes of [prelude]
   and of the program, and the sheet the program opens. *)
let open_program (ctx : Ctx.ctx) ~(prelude : Ast.shape_def list)
    (prog : Ast.program) : unit =
  (match prog.Ast.p_unit with
  | None -> ()
  | Some (u, sp) ->
      if not (List.mem u units) then
        Error.fail sp
          (Printf.sprintf "`%s` is no unit; the units are %s" u
             (String.concat ", " units));
      ctx.unit_name <- u);
  List.iteri
    (fun i (sd : Ast.shape_def) ->
      if Hashtbl.mem ctx.shapes sd.Ast.sd_name then
        Error.fail sd.Ast.sd_name_span
          (Printf.sprintf "shape %s is already defined" sd.Ast.sd_name);
      let seen = Hashtbl.create 4 in
      List.iter
        (fun (p, sp) ->
          if Hashtbl.mem seen p then
            Error.fail sp (Printf.sprintf "duplicate parameter %s" p);
          Hashtbl.replace seen p ())
        sd.Ast.sd_params;
      Hashtbl.replace ctx.shapes sd.Ast.sd_name (i, sd))
    (prelude @ prog.Ast.p_shapes);
  let o = open_sheet ctx ~visible:max_int prog.Ast.p_sheet in
  Ctx.open_sheet ctx o.o_sheet ~points:o.o_points ~lines:o.o_lines

(* The whole program on a fresh [ctx]: its header, then its statements. *)
let run_program ?prelude (ctx : Ctx.ctx) on_step (prog : Ast.program) : unit =
  let prelude =
    match prelude with Some p -> p | None -> Lazy.force Prelude.shapes
  in
  open_program ctx ~prelude prog;
  run_stmts ctx on_step prog.Ast.p_stmts

let eval_program ?(resume : snapshot option) ?(on_step : ctx -> unit = fun _ -> ())
    ?prelude (prog : Ast.program) : folded =
  (match resume with None -> Fold_state.reset_ids () | Some _ -> ());
  let ctx = Ctx.create () in
  (match resume with
  | Some s ->
      restore ctx s;
      run_stmts ctx on_step prog.Ast.p_stmts
  | None -> run_program ?prelude ctx on_step prog);
  build_output ctx (List.hd ctx.scopes)

let eval_folded (prog : Ast.program) : folded = eval_program prog
