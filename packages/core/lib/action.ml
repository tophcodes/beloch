(** The disposition verbs that write to the fold state: `mark`, `fold` and
    `reverse` (ADR 0011), plus the checked-fold primitive `fold` and
    `reverse` share. Every stateful function takes [(ctx : Ctx.ctx)] as its
    first parameter. *)

open Ctx

let tear_error span (ta, tb) =
  Error.fail
    ~hint:"move those layers too, or fold along a crease on the axis" span
    (Printf.sprintf
       "the moving flap is joined to a stationary layer along a segment \
        ((%g,%g)-(%g,%g)) that is not on the fold axis — it cannot fold on \
        its own without tearing the paper"
       (Num.to_float ta.Geom.x) (Num.to_float ta.Geom.y)
       (Num.to_float tb.Geom.x) (Num.to_float tb.Geom.y))

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
  let record ~move_side moving placement =
    Ctx.record_write ctx
      (Trace.fold_terms !(ctx.state) ~axis ~move_side ~moving placement)
      []
  in
  let outside = if valley then Fold_state.Top else Fold_state.Bottom in
  match (fs.Ast.place, fs.Ast.up_to) with
  | Some place, _ ->
      (* A placed fold: the anchor flap's material beyond the axis, or with
         no anchor every layer on the side the side items fixed, moves as one
         block and is spliced next to the target flap instead of at the
         outside of the stack. The direction follows from the placement, so
         [valley] is unused here. *)
      if anchor_arg = None && side_override = None then
        Error.fail span "a placed fold needs `moving .p` or `toward .p` to name the flap";
      let move_side, block, placement =
        Resolve.placed_fold_plan ctx axis ~anchor:anchor_arg ?side:side_override ~place
          span
      in
      record ~move_side block placement;
      (match
         Fold_state.scoped_fold_hinge_closed !(ctx.state) ~axis ~move_side
           ~moving_parents:block
       with
      | Ok () -> ()
      | Error t -> tear_error span t);
      (match check with Some k -> k (fun fi -> block.(fi)) | None -> ());
      (match
         Fold_state.fold_blocks ~crease_id ~blocks:[ (block, placement) ]
           !(ctx.state) ~axis ~move_side ~prov
       with
      | Ok st -> ctx.state := st
      | Error v ->
          Error.fail span
            (Resolve.placement_failure_message (fst place) (snd place) v))
  | None, None ->
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
      record ~move_side moving_parents outside;
      (match
         Fold_state.scoped_fold_hinge_closed !(ctx.state) ~axis ~move_side
           ~moving_parents
       with
      | Ok () -> ()
      | Error t -> tear_error span t);
      (match check with
      | Some k -> k (fun fi -> moving_parents.(fi))
      | None -> ());
      ctx.state :=
        Fold_state.fold !(ctx.state) ~moving_parents ~axis ~move_side ~valley
          ~crease_id ~prov
  | None, Some tgt -> (
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
      | Error (msg, hint) -> Error.fail ?hint span msg
      | Ok moving_parents ->
          record ~move_side moving_parents outside;
          (match
             Fold_state.scoped_fold_hinge_closed !(ctx.state) ~axis
               ~move_side ~moving_parents
           with
          | Ok () -> ()
          | Error t -> tear_error span t);
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

(* ---- the output clause (BELOCH.md, Write statements) ---- *)

(* The crease id a write scores under, the check its axis has to pass before
   the write runs, and the binding step to run once the write has succeeded.
   [Anonymous] and [Named _] score a crease of their own, so they take
   [fresh ()]; `into` scores onto the crease its name is already bound to, so
   a fold along a mark keeps one id instead of minting a second, coincident
   crease for the emitter to supersede. *)
let crease_id_for (ctx : Ctx.ctx) (out : Ast.output) ~(fresh : unit -> int) :
    int * (Geom.line -> unit) * (crease_val -> unit) =
  match out with
  | Ast.Anonymous -> (fresh (), ignore, fun _ -> ())
  | Ast.Named (n, rebind, sp) -> (fresh (), ignore, bind_output ctx n ~rebind sp)
  | Ast.Into (n, sp) ->
      let cid, check_axis = Resolve.into_crease ctx n sp in
      (* a fold promotes the mark it scored into to material; a mark adds a
         record under the id already bound and changes nothing *)
      ( cid, check_axis,
        fun cv ->
          match cv with
          | Material _ -> promote_crease ctx n cv
          | Frozen _ | Mark _ | Bundle _ | Edge _ -> () )

(* Resolve a markable to either a fresh construction (axis, provenance, the
   side that folds over where the side items fix it, and the implied anchor)
   or an existing line to fold or mark along. [fold] is true for the writes
   that move paper, which need a side the fold can take. *)
let resolve_markable (ctx : Ctx.ctx) (span : Error.span) (out : Ast.output)
    ~(fold : bool) (sides : Ast.sides) (m : Ast.markable) =
  match m with
  | Ast.MConstruction c ->
      let cid, check_axis, bind_out =
        crease_id_for ctx out ~fresh:Fold_state.fresh_crease_id
      in
      let prov_name =
        match out with
        | (Ast.Named (n, _, _) | Ast.Into (n, _)) when not (is_temp n) -> (
            match ctx.name_ctx with
            | Root -> Some n
            | InInstance i -> Some (i ^ "." ^ n)
            | Anon -> None)
        | _ -> None
      in
      let cl, pending = Axiom.axis_of ctx span c in
      let { Axiom.line = axis; fold_side = side_override; sources } =
        Axiom.select ctx span pending ~fold sides
      in
      let axiom = Axiom.tag cl in
      let prov : State.provenance option =
        Some { State.axiom; sources; span; name = prov_name; stmt = Ctx.stmt_index ctx }
      in
      check_axis axis;
      (* the implied anchor seeds the moving flap only where it lies on the
         side that folds over; an alignment met by the other object leaves it
         behind *)
      let implied =
        match (Axiom.implied_point cl, side_override) with
        | Some po, Some s when Geom.side_of_line axis (Resolve.table_of ctx po) <> s -> None
        | ip, _ -> ip
      in
      `Fresh (cid, bind_out, axis, prov, side_override, implied)
  | Ast.MLine lo -> `Existing lo

let eval_mark (ctx : Ctx.ctx) (out : Ast.output) (m : Ast.markable)
    (ext : Ast.extent) (dir : Ast.direction) (layer_opt : Ast.flap_arg option)
    (sides : Ast.sides) (span : Error.span) : unit =
  let intent = intent_of dir in
  (* a `mark` along an already-bound line records a material chord of its
     own: the axis slot of `mark` is line-sorted, so a Frozen name stands
     here where `fold`'s axis would refuse it. *)
  let cid, bind_out, table_axis, prov =
    match resolve_markable ctx span out ~fold:false sides m with
    | `Fresh (cid, bind_out, axis, prov, _side_override, _implied) ->
        (cid, bind_out, axis, prov)
    | `Existing lo ->
        if sides.Ast.s_toward <> None || sides.Ast.s_moving <> None then
          Error.fail ~hint:"drop them" span
            "a mark along an existing line has no candidates to select and moves \
             nothing, so it takes no toward or moving";
        let axis = Resolve.resolve_line ctx lo in
        let cid, check_axis, bind_out =
          crease_id_for ctx out ~fresh:Fold_state.fresh_crease_id
        in
        check_axis axis;
        (cid, bind_out, axis, None)
  in
  let record mgeom paper_axis =
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
        sl_kept = prior_kept @ [ m ]; sl_parent = ctx.parent }
      :: ctx.statements_rev;
    bind_out (Mark (cid, paper_axis))
  in
  (* A full mark is the whole line clipped to its flap; it records as a
     material chord (never subdivides). Resolve the flap (explicit layer
     wins; else the carrying flap of a rep point on the axis), then take
     the extreme endpoints of the per-face paper clips. *)
  let record_full () =
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
    | Some (a, b) -> record (Fold_state.MSeg (a, b)) (Geom.line_through a b)
    | None -> Error.fail span "the mark's line does not cross its flap"
  in
  (* Behaviour 4: dispatch a partial extent's classification. Under the
     material-layer model NO mark subdivides — CSubdivide (a full chord
     between two boundary points) records exactly like CRecord. Only
     `Ast.Between` can ever yield [CCrossesFold]. *)
  let dispatch_partial ~flap ~extent_geom ~paper_axis =
    match
      Fold_state.classify_mark_extent !(ctx.state) ~flap ~axis:paper_axis
        ~extent_geom
    with
    | Fold_state.CSubdivide (a, b) -> record (Fold_state.MSeg (a, b)) paper_axis
    | Fold_state.CRecord g -> record g paper_axis
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
  match Resolve.resolve_mark_extent ctx table_axis ext span with
  | `Full -> record_full ()
  | `Partial (extent_geom, rep, paper_axis) ->
      let flap = Resolve.resolve_mark_flap ctx layer_opt rep span in
      dispatch_partial ~flap ~extent_geom ~paper_axis

let eval_fold (ctx : Ctx.ctx) (out : Ast.output) (m : Ast.markable)
    (fs : Ast.fold_spec) (span : Error.span) : unit =
  let sides = { Ast.s_toward = fs.Ast.toward; s_moving = fs.Ast.moving; s_spans = fs.Ast.spans } in
  match resolve_markable ctx span out ~fold:true sides m with
  | `Fresh (cid, bind_out, axis, prov, side_override, implied) ->
      run_fold ctx ~span ~axis ~fs ~implied ~side_override ~crease_id:cid ~prov;
      (* push the frame BEFORE binding the name: a first-fold crease's
         creation step must count that fold (step 1), not the
         pre-fold count (step 0) — see scope.line_steps. *)
      push_frame ctx (Some span);
      bind_out (Material (cid, axis))
  | `Existing (Ast.LNamed cr)
    when (match Resolve.crease_of ctx cr ~slot:"the axis of fold" cr.Ast.cspan with
          | Mark _ -> true
          | _ -> false) ->
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
            Error.fail
              ~hint:
                (Printf.sprintf "narrow it to one piece with &, e.g. --%s & .p"
                   cr.Ast.cname)
              span
              (Printf.sprintf "--%s is no longer straight after folding"
                 cr.Ast.cname)
      in
      let cid, check_axis, bind_out =
        crease_id_for ctx out ~fresh:Fold_state.fresh_crease_id
      in
      check_axis axis;
      let prov : State.provenance option =
        Some { State.axiom = "fold"; sources = [ "--" ^ cr.Ast.cname ];
               span; name = None; stmt = Ctx.stmt_index ctx }
      in
      run_fold ctx ~span ~axis ~fs ~implied:None
        ~side_override:(Axiom.fold_side_of_line ctx span axis sides)
        ~crease_id:cid ~prov;
      push_frame ctx (Some span);
      bind_out (Material (cid, axis))
  | `Existing lo ->
      (* fold along an existing material crease (the old FoldAlong path).
         The write scores no crease of its own, so the output clause names
         the crease that is already there rather than a fresh id. *)
      let along =
        match lo with
        | Ast.LNamed cr ->
            ignore (Resolve.crease_of ctx cr ~slot:"the axis of fold" cr.Ast.cspan);
            Resolve.material_cid ctx cr
        | Ast.LFilter _ | Ast.LUnion _ -> (
            match fst (Resolve.bundle_segments ctx lo) with
            | Some c -> c
            | None ->
                Error.fail span
                  "fold folds along one existing crease; a union spans \
                   several")
        | _ ->
            Error.fail
              ~hint:"give a crease name, e.g. fold --d or fold --d & .p" span
              "fold folds along an existing crease"
      in
      let axis = Resolve.resolve_line ctx lo in
      let cid, check_axis, bind_out =
        crease_id_for ctx out ~fresh:(fun () -> along)
      in
      check_axis axis;
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
              Error.fail
                ~hint:"select a straight segment with `&` or move fewer flaps"
                span "the crease is bent under the moving flaps")
          (Fold_state.crease_segments !(ctx.state) along)
      in
      let prov : State.provenance option =
        Some
          {
            State.axiom = "fold";
            sources = [ Resolve.lstr lo ];
            span;
            name = None;
            stmt = Ctx.stmt_index ctx;
          }
      in
      run_fold_checked ctx ~span ~axis ~fs ~implied:None
        ~side_override:(Axiom.fold_side_of_line ctx span axis sides)
        ~crease_id:cid ~prov ~check:(Some check_straight);
      push_frame ctx (Some span);
      bind_out (Material (cid, axis))

let eval_reverse (ctx : Ctx.ctx) (out : Ast.output) (m : Ast.markable)
    (rs : Ast.reverse_spec) (span : Error.span) : unit =
  let sides = { Ast.s_toward = rs.Ast.rtoward; s_moving = rs.Ast.rmoving; s_spans = rs.Ast.rspans } in
  let cid, bind_out, axis, prov, side, implied =
    match resolve_markable ctx span out ~fold:true sides m with
    | `Fresh (cid, bind_out, axis, prov, side, implied) ->
        (cid, bind_out, axis, prov, side, implied)
    | `Existing lo ->
        (match lo with
        | Ast.LNamed cr ->
            ignore
              (Resolve.crease_of ctx cr ~slot:"the axis of reverse"
                 cr.Ast.cspan)
        | _ -> ());
        let axis = Resolve.resolve_line ctx lo in
        let side = Axiom.fold_side_of_line ctx span axis sides in
        let cid, check_axis, bind_out =
          crease_id_for ctx out ~fresh:Fold_state.fresh_crease_id
        in
        check_axis axis;
        let prov : State.provenance option =
          Some { State.axiom = "reverse"; sources = [ Resolve.lstr lo ]; span;
                 name = None; stmt = Ctx.stmt_index ctx }
        in
        (cid, bind_out, axis, prov, side, None)
  in
  (* the tip: the flap of the anchor, or with no anchor the material on the
     side the side items fixed *)
  let anchor =
    match (rs.Ast.rmoving, implied) with
    | Some fa, _ -> Some fa
    | None, Some p -> Some (Ast.FlapPoint p)
    | None, None -> None
  in
  if anchor = None && side = None then
    Error.fail span "this reverse needs `moving .p` or `toward .p` to name the tip";
  let move_side, tip = Resolve.tip_faces ctx axis ~anchor ?side span in
  let st = !(ctx.state) and inside = not rs.Ast.outside in
  let attempts =
    Fold_state.reverse_attempts ~crease_id:cid st ~axis ~move_side ~tip ~inside ~prov
  in
  let terms, states = Trace.reverse_write st ~axis ~move_side ~tip ~inside attempts in
  Ctx.record_write ctx terms states;
  (match Fold_state.reverse_of_attempts attempts with
  | Ok st -> ctx.state := st
  | Error (Fold_state.Invalid (Fold_state.Taco_tortilla { tortilla; _ })) ->
      Error.fail span (Printf.sprintf "reversing the tip would pierce layer %d" tortilla)
  | Error (Fold_state.Invalid (Fold_state.Taco_taco (_, _))) ->
      Error.fail span "reversing the tip would pierce another layer"
  | Error e ->
      Error.fail
        ?hint:
          (match e with
          | Fold_state.Several_spines _ -> Some "fold less so that one remains"
          | _ -> None)
        span
        (Fold_state.reverse_failure_to_string e));
  push_frame ctx (Some span);
  bind_out (Material (cid, axis))
