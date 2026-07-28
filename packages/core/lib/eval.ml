(** Evaluate a program, resolving names and applying axioms. Geometry is exact;
    preconditions are reported as Error.Beloch_error. *)

open Ctx

(* Re-exported so the public [Eval] surface is unchanged for fold_emit,
   session, the test suites and packages/www/public/beloch/beloch-eval.js. *)
type snapshot = Ctx.snapshot
type stmt_kind = Ctx.stmt_kind = SFold | SMark
type stmt_log_entry = Ctx.stmt_log_entry = {
  sl_kind : stmt_kind;
  sl_span : Error.span;
  sl_frame_index : int;
  sl_mark : Fold_state.mark option;
  sl_kept : Fold_state.mark list;
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
  named_points : (string * Geom.point * int) list;
      (* [int] is the 0-based creation step (index into [frames] at bind
         time); see [scope.point_steps]/[scope.line_steps] *)
  named_lines : (string * Geom.line * int) list;
  named_line_cids : (string * int) list;
      (* crease id per name for [Material]/[Mark] creases — the identity the
         line coefficients in [named_lines] lose (a folded crease's current
         line can coincide with another crease's line) *)
  frames : (Fold_state.t * Error.span option) list;
  statements : stmt_log_entry list;
  free_points : (string * free_info) list;
      (* one entry per `free on` point, recorded at bind time in the [PsFree]
         arm — a running log (like [statements]), not reconstructed from
         scope state at finalize (unlike [named_points]), since [free_info]
         carries per-placement data the point's final bound value alone
         doesn't retain. *)
}


let run_fold_checked (ctx : Ctx.ctx) ~(span : Error.span) ~(axis : Geom.line)
    ~(fs : Ast.fold_spec) ~(implied : Ast.point_operand option)
    ~(side_override : int option) ~(crease_id : int)
    ~(prov : State.provenance option)
    ~(check : ((int -> bool) -> unit) option) : unit =
  (* A degenerate fold: the crease is a supporting line of the convex paper —
     collinear with a boundary edge, or tangent at a single corner (zero-length
     crease). Either way one open half-plane holds no material, so there is no
     second flap to reflect. Structurally impossible (issue #39), an error, not
     a no-op. `line_cuts_paper` is false iff no face is strictly cut. *)
  if not (Fold_state.line_cuts_paper !(ctx.state) axis) then
    Error.fail span
      "this fold is degenerate — the crease line lies along the edge of the \
       paper and does not separate it into two flaps to reflect";
  (* [side_override] fixes the moving side (axiom-5 derived direction), so the
     anchor is only needed to scope an `up to` range *)
  let anchor_arg =
    match (fs.Ast.moving, implied) with
    | Some fa, _ -> Some fa
    | None, Some p -> Some (Ast.FlapPoint p)
    | None, None -> None
  in
  let valley = fs.Ast.direction = Ast.Valley in
  match fs.Ast.up_to with
  | None ->
      (* Default scope: the outside-contiguous prefix down to the flap(s)
         carrying the anchor operand — not every layer on the side. *)
      let move_side =
        match side_override with
        | Some s -> s
        | None -> (
            match anchor_arg with
            | Some fa -> Resolve.default_move_side ctx axis fa span
            | None ->
                Error.fail span "this fold needs `moving .p` to choose the side")
      in
      let seed =
        match anchor_arg with
        | Some fa -> Resolve.anchor_faces ctx fa span
        | None ->
            (* No `moving` clause and no implied point (e.g. a bare axiom-5
               line-onto-line fold): move_side above only succeeded because
               side_override resolved the direction, so there is nothing to
               anchor a prefix to. Fall back to every face with a piece on
               move_side — default_scope's closure never removes an already-
               seeded candidate, so this reproduces the pre-default_scope
               "all layers on the side" behavior exactly. *)
            let st = !(ctx.state) in
            List.filter
              (fun fi ->
                Array.length
                  (Geom.clip_convex_halfplane axis move_side
                     (Fold_state.table_polygon st fi))
                >= 3)
              (List.init (Array.length (Fold_state.faces st)) Fun.id)
      in
      let moving_parents =
        Fold_state.default_scope !(ctx.state) ~axis ~move_side ~valley ~seed
      in
      (match
         Fold_state.scoped_fold_hinge_closed !(ctx.state) ~axis ~move_side
           ~moving_parents
       with
      | Ok () -> ()
      | Error (ta, tb) ->
          Error.fail span
            (Printf.sprintf
               "the moving flap is joined to a stationary layer along a \
                segment ((%g,%g)-(%g,%g)) that is not on the fold axis — it \
                cannot fold on its own without tearing the paper. Move those \
                layers too, or fold along a crease on the axis."
               (Num.to_float ta.Geom.x) (Num.to_float ta.Geom.y)
               (Num.to_float tb.Geom.x) (Num.to_float tb.Geom.y)));
      (match check with
      | Some k -> k (fun fi -> moving_parents.(fi))
      | None -> ());
      ctx.state :=
        Fold_state.fold !(ctx.state) ~moving_parents ~axis ~move_side ~valley
          ~crease_id ~prov
  | Some tgt -> (
      let move_side =
        match side_override with
        | Some s -> s
        | None -> (
            match anchor_arg with
            | Some fa -> Resolve.side_of_flap_arg ctx axis fa span
            | None ->
                Error.fail span "this fold needs `moving .p` to choose the side")
      in
      let anchor =
        match anchor_arg with
        | Some fa ->
            let st = !(ctx.state) in
            let cluster = Resolve.resolve_flap_cluster ctx fa span in
            (match
               List.find_opt
                 (fun f ->
                   Array.length
                     (Geom.clip_convex_halfplane axis move_side
                        (Fold_state.table_polygon st f))
                   >= 3)
                 cluster
             with
            | Some f -> f
            | None -> List.hd cluster)
        | None ->
            Error.fail span "`up to` needs `moving` to anchor the moving flaps"
      in
      let target = Resolve.target_of ctx tgt span in
      match
        Fold_state.select_scope !(ctx.state) ~axis ~move_side ~valley ~anchor
          ~target
      with
      | Error msg -> Error.fail span msg
      | Ok moving_parents ->
          (match
             Fold_state.scoped_fold_hinge_closed !(ctx.state) ~axis
               ~move_side ~moving_parents
           with
          | Ok () -> ()
          | Error (ta, tb) ->
              Error.fail span
                (Printf.sprintf
                   "the moving flap is joined to a stationary layer along a \
                    segment ((%g,%g)-(%g,%g)) that is not on the fold axis \
                    — it cannot fold on its own without tearing the paper. \
                    Move those layers too, or fold along a crease on the \
                    axis."
                   (Num.to_float ta.Geom.x) (Num.to_float ta.Geom.y)
                   (Num.to_float tb.Geom.x) (Num.to_float tb.Geom.y)));
          (match check with
          | Some k -> k (fun fi -> moving_parents.(fi))
          | None -> ());
          ctx.state :=
            Fold_state.fold !(ctx.state) ~moving_parents ~axis
              ~move_side ~valley ~crease_id ~prov)

let run_fold (ctx : Ctx.ctx) ~(span : Error.span) ~(axis : Geom.line) ~(fs : Ast.fold_spec)
    ~(implied : Ast.point_operand option) ~(side_override : int option)
    ~(crease_id : int) ~(prov : State.provenance option) : unit =
  run_fold_checked ctx ~span ~axis ~fs ~implied ~side_override ~crease_id ~prov
    ~check:None

(* Resolve a markable to either a fresh motion (axis + provenance + the
   axiom-5 side override / implied-anchor, mirroring the old Crease arm) or
   an existing line to fold/mark along. [fold_opt] is [Some fs] only when
   called from a `fold` statement (axiom-5 direction resolution differs
   between bind/mark and fold). *)
let resolve_markable (ctx : Ctx.ctx) (span : Error.span) (name_opt : string option)
    (fold_opt : Ast.fold_spec option) (m : Ast.markable) =
  match m with
  | Ast.MMotion ax ->
      let cid = Fold_state.fresh_crease_id () in
      let prov_name =
        match name_opt with
        | Some n when not (is_temp n) -> (
            match ctx.name_ctx with
            | Root -> Some n
            | InInstance i -> Some (i ^ "." ^ n)
            | Anon -> None)
        | _ -> None
      in
      (* axiom 5 defers bisector choice to the fold state (direction / paper
         incidence); every other axiom resolves its axis up front *)
      let axis, axiom, sources, side_override =
        match Axiom.axis_of ctx span ax with
        | Axiom.Axis (axis, axiom, sources) -> (axis, axiom, sources, None)
        | Axiom.Ax5 p ->
            let axis, so =
              match fold_opt with
              | None -> (Axiom.select_axiom5_bind ctx span p, None)
              | Some fs -> Axiom.select_axiom5_fold ctx span p ~fs
            in
            (axis, "axiom5", Axiom.ax5_sources p, so)
      in
      let prov : State.provenance option =
        Some { State.axiom; sources; span; name = prov_name }
      in
      let implied =
        match ax with
        | Ast.MapPoints (p, _)
        | Ast.MapThrough (p, _, _, _)
        | Ast.MapBoth (p, _, _, _, _) ->
            Some p
        | _ -> None
      in
      `Fresh (cid, axis, prov, side_override, implied)
  | Ast.MLine lo -> `Existing lo

let eval_mark (ctx : Ctx.ctx) (name_opt : string option) (m : Ast.markable)
    (ext : Ast.extent) (dir : Ast.direction) (layer_opt : Ast.flap_operand option)
    (span : Error.span) : unit =
  let intent = intent_of dir in
  let bind_mark cid line =
    match name_opt with
    | Some n -> bind_crease ctx n span (Mark (cid, line))
    | None -> ()
  in
  let record ~prov cid mgeom paper_axis =
    let m : Fold_state.mark =
      { Fold_state.mgeom; mline = paper_axis; mintent = intent;
        mcrease_id = cid; mprov = prov }
    in
    ctx.state := Fold_state.add_mark !(ctx.state) m;
    let prior_kept =
      match ctx.statements_rev with
      | prev :: _ -> prev.sl_kept
      | [] -> []
    in
    ctx.statements_rev <-
      { sl_kind = SMark; sl_span = span;
        sl_frame_index = List.length ctx.frames_rev; sl_mark = Some m;
        sl_kept = prior_kept @ [ m ] }
      :: ctx.statements_rev;
    bind_mark cid paper_axis
  in
  (* A full mark is the whole line clipped to its flap; it records as a
     material chord (never subdivides). Resolve the flap (explicit #[...]
     wins; else the carrying flap of a rep point on the axis), then take
     the extreme endpoints of the per-face paper clips. *)
  let record_full ~prov cid table_axis =
    let st = !(ctx.state) in
    let clips =
      List.init (Array.length (Fold_state.faces st)) Fun.id
      |> List.filter_map (fun fi -> Fold_state.axis_chord_in_face st fi table_axis)
    in
    let rep =
      match clips with
      | (p, q) :: _ ->
          { Geom.x = Num.div (Num.add p.Geom.x q.Geom.x) (Num.of_int 2);
            y = Num.div (Num.add p.Geom.y q.Geom.y) (Num.of_int 2) }
      | [] -> Error.fail span "the mark's line does not cross the paper"
    in
    let flap = Resolve.resolve_mark_flap ctx layer_opt rep span in
    let pts =
      List.filter_map
        (fun fi -> Fold_state.axis_chord_in_face st fi table_axis)
        flap
      |> List.concat_map (fun (p, q) -> [ p; q ])
    in
    match Geom.extreme_pair pts with
    | Some (a, b) ->
        record ~prov cid (Fold_state.MSeg (a, b)) (Geom.line_through a b)
    | None -> Error.fail span "the mark's line does not cross its flap"
  in
  (* Behaviour 4: dispatch a partial extent's classification. Under the
     material-layer model NO mark subdivides — CSubdivide (a full chord
     between two boundary points) records exactly like CRecord. Only
     `Ast.Between` can ever yield [CCrossesFold]. *)
  let dispatch_partial ~prov ~cid ~flap ~extent_geom ~paper_axis () =
    match
      Fold_state.classify_mark_extent !(ctx.state) ~flap ~axis:paper_axis
        ~extent_geom
    with
    | Fold_state.CSubdivide (a, b) -> record ~prov cid (Fold_state.MSeg (a, b)) paper_axis
    | Fold_state.CRecord g -> record ~prov cid g paper_axis
    | Fold_state.CCrossesFold _ ->
        let a, b =
          match ext with Ast.Between (a, b) -> (a, b) | _ -> assert false
        in
        Error.fail span
          (Printf.sprintf
             "the mark's extent from %s to %s crosses a folded crease \
              (it leaves its flap)"
             (Resolve.pstr a) (Resolve.pstr b))
  in
  match resolve_markable ctx span name_opt None m with
  | `Fresh (cid, table_axis, prov, _side_override, _implied) -> (
      match Resolve.resolve_mark_extent ctx table_axis ext span with
      | `Full -> record_full ~prov cid table_axis
      | `Partial (extent_geom, rep, paper_axis) ->
          let flap = Resolve.resolve_mark_flap ctx layer_opt rep span in
          dispatch_partial ~prov ~cid ~flap ~extent_geom ~paper_axis ())
  | `Existing lo ->
      (* mark an already-bound value line: record a material chord. If it
         names a pure value (Frozen), promote its binding to Mark so a
         later `fold --d` can materialize a real crease along it. *)
      let table_axis = Resolve.resolve_line ctx lo in
      let cid = Fold_state.fresh_crease_id () in
      let promote () =
        match lo with
        | Ast.LNamed cr -> (
            match lookup_crease ctx cr with
            | Frozen _ ->
                promote_crease ctx cr.Ast.cname (Mark (cid, table_axis))
            | Mark _ | Material _ | Bundle _ | Edge _ -> ())
        | _ -> ()
      in
      (match Resolve.resolve_mark_extent ctx table_axis ext span with
      | `Full -> record_full ~prov:None cid table_axis
      | `Partial (extent_geom, rep, paper_axis) ->
          let flap = Resolve.resolve_mark_flap ctx layer_opt rep span in
          dispatch_partial ~prov:None ~cid ~flap ~extent_geom ~paper_axis ());
      promote ()

let eval_fold (ctx : Ctx.ctx) (name_opt : string option) (m : Ast.markable)
    (fs : Ast.fold_spec) (span : Error.span) : unit =
  match resolve_markable ctx span name_opt (Some fs) m with
  | `Fresh (cid, axis, prov, side_override, implied) ->
      run_fold ctx ~span ~axis ~fs ~implied ~side_override ~crease_id:cid ~prov;
      (* push the frame BEFORE binding the name: a first-fold crease's
         creation step must count that fold (step 1), not the
         pre-fold count (step 0) — see scope.line_steps. *)
      push_frame ctx (Some span);
      (match name_opt with
      | Some n -> bind_crease ctx n span (Material (cid, axis))
      | None -> ())
  | `Existing (Ast.LNamed cr)
    when (match lookup_crease ctx cr with Mark _ -> true | _ -> false) ->
      (* fold along a MARK: marks never subdivide, so there is no existing
         crease to fold along — materialize a fresh real crease on the
         mark's line. At emit the coincident mark is superseded by this
         crease. *)
      let mark_cid, mark_line =
        match lookup_crease ctx cr with
        | Mark (c, line) -> (c, line)
        | _ -> assert false
      in
      let axis =
        match Fold_state.mark_axis_current !(ctx.state) mark_cid with
        | `Line l -> l
        | `Empty -> mark_line
        | `Collapsed ->
            Error.fail span
              (Printf.sprintf
                 "--%s has collapsed to a point under folding, so there \
                  is no line to fold along" cr.Ast.cname)
        | `Bent ->
            Error.fail span
              (Printf.sprintf
                 "--%s is no longer straight after folding; select a \
                  segment with `at`, e.g. --%s at #[.a .b .c]"
                 cr.Ast.cname cr.Ast.cname)
      in
      let cid = Fold_state.fresh_crease_id () in
      let prov : State.provenance option =
        Some { State.axiom = "fold"; sources = [ "--" ^ cr.Ast.cname ];
               span; name = None }
      in
      run_fold ctx ~span ~axis ~fs ~implied:None ~side_override:None
        ~crease_id:cid ~prov;
      push_frame ctx (Some span);
      (match name_opt with
      | Some n -> bind_crease ctx n span (Material (cid, axis))
      | None -> promote_crease ctx cr.Ast.cname (Material (cid, axis)))
  | `Existing lo ->
      (* fold along an existing material crease (the old FoldAlong path) *)
      let cid =
        match lo with
        | Ast.LNamed cr -> Resolve.material_cid ctx cr
        | Ast.LFilter _ | Ast.LUnion _ -> (
            match fst (Resolve.bundle_segments ctx lo) with
            | Some c -> c
            | None ->
                Error.fail span
                  "fold folds along one existing crease; a union spans \
                   several")
        | _ ->
            Error.fail span
              "fold folds along an existing crease; give a crease \
               name, e.g. fold --d or fold --d & .p"
      in
      let axis = Resolve.resolve_line ctx lo in
      (* per-flap material check: every segment of the bundle carried by
         a moving flap must lie on the axis — a crease bent under the
         moving set cannot fold (#28) *)
      let check_straight (moves : int -> bool) =
        List.iter
          (fun (s : Fold_state.crease_segment) ->
            let l, r = s.Fold_state.faces in
            if
              (moves l || (r >= 0 && moves r))
              && (Geom.side_of_line axis s.Fold_state.ta <> 0
                 || Geom.side_of_line axis s.Fold_state.tb <> 0)
            then
              Error.fail span
                "the crease is bent under the moving flaps; select a \
                 straight segment with `at` or move fewer flaps")
          (Fold_state.crease_segments !(ctx.state) cid)
      in
      let prov : State.provenance option =
        Some
          {
            State.axiom = "fold";
            sources = [ Resolve.lstr lo ];
            span;
            name = None;
          }
      in
      run_fold_checked ctx ~span ~axis ~fs ~implied:None ~side_override:None
        ~crease_id:cid ~prov ~check:(Some check_straight);
      push_frame ctx (Some span)

let eval_free_point (ctx : Ctx.ctx) (n : string) (line : Ast.line_operand)
    (anchor : Ast.point_operand) (t : Num.t option) (span : Error.span) : unit =
  (* a bare value-bound line (`--l = through .a .b`, unmarked) has no
     material of its own; `free on` treats it as backed by the whole
     paper square rather than raising paper_line_of_crease's Frozen
     "no material mark to cross" error (that guard is for `*`/meet,
     which does require a physical mark; a free point does not). *)
  let l, chords_opt =
    match line with
    | Ast.LNamed cr -> (
        match lookup_crease ctx cr with
        | Frozen fl -> (fl, None)
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
           Error.fail espan
             (Printf.sprintf "%s%s exists; use ! to shadow" sigil target)
       | false, true ->
           Error.fail espan
             (Printf.sprintf "nothing to shadow with %s%s; remove !" sigil
                target)
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
          Option.value (Hashtbl.find_opt inst.ipoint_steps src) ~default:0
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
          Option.value (Hashtbl.find_opt inst.iline_steps src) ~default:0
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
  | Ast.BindBundle (name, expr, span) ->
      bind_crease ctx name span (Bundle expr)
  | Ast.BindLine (n, ax, span) ->
      (* pure value: resolve the axiom to a line, bind Frozen, no subdivide *)
      let axis =
        match Axiom.axis_of ctx span ax with
        | Axiom.Axis (axis, _, _) -> axis
        | Axiom.Ax5 p -> Axiom.select_axiom5_bind ctx span p
      in
      bind_crease ctx n span (Frozen axis)
  | Ast.Mark (name_opt, m, ext, dir, layer_opt, span) ->
      eval_mark ctx name_opt m ext dir layer_opt span
  | Ast.Fold (name_opt, m, fs, span) -> eval_fold ctx name_opt m fs span
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
  | Ast.Flatten (name_opt, elems, overs, staying_opt, toward_opt, span) ->
      Flatten_solve.run ctx ~name_opt ~elems ~overs ~staying_opt ~toward_opt span

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
  List.iter (eval_stmt ctx) body;
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
    match Hashtbl.find_opt root_scope.point_steps n with Some s -> s | None -> 0
  in
  let step_of_line n =
    match Hashtbl.find_opt root_scope.line_steps n with Some s -> s | None -> 0
  in
  (* Sorted by name: Hashtbl.fold/iter order depends on internal bucket
     layout, which differs between a fresh eval (insert in program order)
     and a restored session (Hashtbl.reset + Hashtbl.iter replace). Sorting
     here makes the emitted overlay arrays independent of that iteration
     order, so fresh and resumed evals of the same program are byte-identical. *)
  let named_points =
    Hashtbl.fold
      (fun k v acc -> if is_temp k then acc else (k, v, step_of_point k) :: acc)
      root_scope.points []
    |> List.sort (fun (a, _, _) (b, _, _) -> String.compare a b)
  in
  let named_lines =
    Hashtbl.fold
      (fun k cv acc ->
        if is_temp k then acc
        else
          match cv with
          | Frozen l -> (k, l, step_of_line k) :: acc
          | Mark (_, l) -> (k, l, step_of_line k) :: acc
          | Material (cid, l_orig) -> (
              match Fold_state.crease_axis !(ctx.state) cid l_orig with
              | `Line l -> (k, l, step_of_line k) :: acc
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
    |> List.sort (fun (a, _, _) (b, _, _) -> String.compare a b)
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
    statements; free_points }

let eval_program ?(resume : snapshot option) ?(on_step : ctx -> unit = fun _ -> ())
    (prog : Ast.program) : folded =
  (match resume with None -> Fold_state.reset_ids () | Some _ -> ());
  let root_scope = make_scope () in
  List.iter (fun (n, p) -> Hashtbl.replace root_scope.points n p) corners;
  List.iter
    (fun (n, a, b) -> Hashtbl.replace root_scope.lines n (Edge (a, b)))
    [ ("ab", "a", "b"); ("bc", "b", "c"); ("cd", "c", "d"); ("da", "d", "a") ];
  let ctx = {
    scopes = [root_scope];
    name_ctx = Root;
    cur_def_idx = None;
    next_def_idx = 0;
    defs = Hashtbl.create 4;
    state  = ref Fold_state.init_square;
    frames_rev = [];
    statements_rev = [];
    free_points_rev = [];
    pending = true;
  } in
  (match resume with Some s -> restore ctx s | None -> ());
  List.iter (fun stmt -> eval_stmt ctx stmt; on_step ctx) prog;
  build_output ctx root_scope

let eval_folded (prog : Ast.program) : folded = eval_program prog
