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
  (* The moving side comes from the side items, else from the anchor; the
     anchor names a side and nothing else (ADR 0036). *)
  let move_side () =
    match (side_override, anchor_arg) with
    | Some s, _ -> s
    | None, Some fa -> Resolve.default_move_side ctx axis fa span
    | None, None -> Error.fail span "this fold needs `moving .p` to choose the side"
  in
  let apply ~move_side moving_parents =
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
  in
  match (fs.Ast.place, fs.Ast.up_to) with
  | Some place, depth ->
      (* A placed fold: every layer on the moving side, or with `up to` the
         flap it names, moves as one block and is spliced next to the target
         flap instead of at the outside of the stack. The direction follows
         from the placement, so [valley] is unused here. *)
      if anchor_arg = None && side_override = None then
        Error.fail span "a placed fold needs `moving .p` or `toward .p` to name the side";
      let move_side, block, placement =
        Resolve.placed_fold_plan ctx axis ~anchor:anchor_arg ~depth ?side:side_override
          ~place span
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
      (* every layer on the moving side *)
      let move_side = move_side () in
      let seed = List.init (Array.length (Fold_state.faces !(ctx.state))) Fun.id in
      apply ~move_side
        (Fold_state.default_scope !(ctx.state) ~axis ~move_side ~valley ~seed)
  | None, Some tgt -> (
      (* the layers from the flap `up to` names outward *)
      let move_side = move_side () in
      let target = Resolve.target_of ctx tgt span in
      (* the anchor is where a walk to a crease target starts, and nothing
         else: a face carrying it with a piece on the moving side *)
      let anchor =
        match (target, anchor_arg) with
        | Fold_state.TargetHinged _, Some fa ->
            let st = !(ctx.state) in
            let faces = Resolve.anchor_faces ctx fa span in
            Some
              (match
                 List.find_opt
                   (fun f ->
                     Array.length
                       (Geom.clip_convex_halfplane axis move_side
                          (Fold_state.table_polygon st f))
                     >= 3)
                   faces
               with
              | Some f -> f
              | None -> List.hd faces)
        | _ -> None
      in
      match
        Fold_state.select_scope !(ctx.state) ~axis ~move_side ~valley ~anchor
          ~target
      with
      | Error (msg, hint) -> Error.fail ?hint span msg
      | Ok moving_parents -> apply ~move_side moving_parents)

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
  (* One mark per piece, all under [cid]: a piece per layer the mark scores.
     The statement's own entry carries the first piece; every piece stays
     kept. *)
  let record_pieces pieces =
    let ms =
      List.map
        (fun (mgeom, paper_axis) ->
          { Fold_state.mgeom; mline = paper_axis; mintent = intent;
            mcrease_id = cid; mprov = prov })
        pieces
    in
    List.iter (fun m -> ctx.state := Fold_state.add_mark !(ctx.state) m) ms;
    let prior_kept =
      match ctx.statements_rev with
      | prev :: _ -> prev.sl_kept
      | [] -> []
    in
    let first = List.hd ms in
    ctx.statements_rev <-
      { sl_kind = SMark; sl_span = span;
        sl_frame_index = List.length ctx.frames_rev; sl_mark = Some first;
        sl_kept = prior_kept @ ms; sl_parent = ctx.parent }
      :: ctx.statements_rev;
    bind_out (Mark (cid, first.Fold_state.mline))
  in
  let record mgeom paper_axis = record_pieces [ (mgeom, paper_axis) ] in
  (* A full mark is the whole line clipped to each flap it scores; each
     piece records as a material chord (never subdivides) between the
     extreme endpoints of that flap's per-face paper clips. With `on` it
     scores the named flap; without, every flap the line crosses, one piece
     per flap (ADR 0036). *)
  let record_full () =
    let st = !(ctx.state) in
    let n = Array.length (Fold_state.faces st) in
    let chord_of flap =
      List.filter_map
        (fun fi -> Fold_state.axis_chord_in_face st fi table_axis)
        flap
      |> List.concat_map (fun (p, q) -> [ p; q ])
      |> Geom.extreme_pair
    in
    let piece (a, b) = (Fold_state.MSeg (a, b), Geom.line_through a b) in
    match layer_opt with
    | Some _ -> (
        let clips =
          List.init n Fun.id
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
        match chord_of flap with
        | Some ab -> record_pieces [ piece ab ]
        | None -> Error.fail span "the mark's line does not cross its flap")
    | None -> (
        let cl = Fold_state.coplanar_clusters st in
        let flaps =
          List.sort_uniq compare (List.init n (fun fi -> cl.(fi)))
          |> List.map (fun id -> List.filter (fun fi -> cl.(fi) = id) (List.init n Fun.id))
        in
        match List.filter_map chord_of flaps with
        | [] -> Error.fail span "the mark's line does not cross the paper"
        | chords -> record_pieces (List.map piece chords))
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
  (* A partial extent without `on`: a piece on every flap under the extent,
     its material of the axis clipped to the extent (ADR 0036). *)
  let record_partial_every_layer extent_geom =
    let st = !(ctx.state) in
    let n = Array.length (Fold_state.faces st) in
    let cl = Fold_state.coplanar_clusters st in
    let flaps =
      List.sort_uniq compare (List.init n (fun fi -> cl.(fi)))
      |> List.map (fun id -> List.filter (fun fi -> cl.(fi) = id) (List.init n Fun.id))
    in
    let to_paper fi p = Isometry.apply_point (Isometry.inverse (Fold_state.face_iso2 st fi)) p in
    let paper_axis_in fi =
      match Fold_state.axis_chord_in_face st fi table_axis with
      | Some (p, q) when not (Geom.point_equal p q) -> Some (Geom.line_through p q)
      | _ -> None
    in
    let pieces =
      match extent_geom with
      | Fold_state.MPoint pp ->
          let tp = Fold_state.table_position st pp in
          List.filter_map
            (fun flap ->
              List.find_map
                (fun fi ->
                  let q = to_paper fi tp in
                  if Geom.in_convex_polygon (Fold_state.faces st).(fi) q then
                    Some
                      ( Fold_state.MPoint q,
                        match paper_axis_in fi with
                        | Some l -> l
                        | None -> table_axis )
                  else None)
                flap)
            flaps
      | Fold_state.MSeg (pa, pb) ->
          let ta = Fold_state.table_position st pa
          and tb = Fold_state.table_position st pb in
          let d = { Geom.x = Num.sub tb.Geom.x ta.Geom.x; y = Num.sub tb.Geom.y ta.Geom.y } in
          let param (p : Geom.point) =
            Num.add
              (Num.mul (Num.sub p.Geom.x ta.Geom.x) d.Geom.x)
              (Num.mul (Num.sub p.Geom.y ta.Geom.y) d.Geom.y)
          in
          let len2 = param tb in
          let at t =
            let k = Num.div t len2 in
            { Geom.x = Num.add ta.Geom.x (Num.mul k d.Geom.x);
              y = Num.add ta.Geom.y (Num.mul k d.Geom.y) }
          in
          let nmax a b = if Num.compare a b >= 0 then a else b in
          let nmin a b = if Num.compare a b <= 0 then a else b in
          (* the part of face [fi]'s chord of the axis inside the extent, as
             paper points *)
          let clip fi =
            match
              Geom.clip_line_to_convex table_axis (Fold_state.table_polygon_ccw st fi)
            with
            | None -> []
            | Some (c1, c2) ->
                let t1 = param c1 and t2 = param c2 in
                let lo = nmax Num.zero (nmin t1 t2) and hi = nmin len2 (nmax t1 t2) in
                if Num.compare lo hi < 0 then [ to_paper fi (at lo); to_paper fi (at hi) ]
                else []
          in
          List.filter_map
            (fun flap ->
              match Geom.extreme_pair (List.concat_map clip flap) with
              | Some (a, b) ->
                  (* ordered as the extent runs, from its first point *)
                  let a, b =
                    if
                      Num.compare
                        (param (Fold_state.table_position st a))
                        (param (Fold_state.table_position st b))
                      > 0
                    then (b, a)
                    else (a, b)
                  in
                  Some (Fold_state.MSeg (a, b), Geom.line_through a b)
              | None -> None)
            flaps
    in
    if pieces = [] then Error.fail span "the mark's extent is not on the paper";
    record_pieces pieces
  in
  match Resolve.resolve_mark_extent ctx table_axis ext span with
  | `Full -> record_full ()
  | `Partial (extent_geom, _, _) when layer_opt = None ->
      record_partial_every_layer extent_geom
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
