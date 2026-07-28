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

(* axiom-5 (`map --l1 onto --l2`) needs its candidate bisectors selected against
   the current fold state (material of l1, paper incidence, `toward` direction),
   so [axis_of] defers that: intersecting lines yield [Ax5], everything else a
   fully-resolved [Axis]. *)
type ax5_pending = {
  la : Geom.line;
  lb : Geom.line;
  cands : Geom.line * Geom.line;   (* angle bisectors of la, lb *)
  toward : Geom.point option;      (* table space, already checked off la *)
  l1_op : Ast.line_operand;        (* for the l1-material lookup *)
  l1_str : string;
  l2_str : string;
  toward_str : string option;
  sources : string list;           (* provenance, includes toward when present *)
}

type axis_result =
  | Axis of Geom.line * string * string list
  | Ax5 of ax5_pending

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
  (* axis line + provenance (axiom tag, source names), evaluated against the
     current table positions *)
  let axis_of (span : Error.span) (ax : Ast.axiom) : axis_result =
    match ax with
    | Ast.Through (p, q) ->
        let pp = Resolve.table_of ctx p and qq = Resolve.table_of ctx q in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf
               "%s and %s are at the same place, so there is no line through \
                them"
               (Resolve.pstr p) (Resolve.pstr q));
        Axis (Geom.line_through pp qq, "axiom1", [ Resolve.pstr p; Resolve.pstr q ])
    | Ast.MapPoints (p, q) ->
        let pp = Resolve.table_of ctx p and qq = Resolve.table_of ctx q in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf "%s and %s are already at the same place" (Resolve.pstr p)
               (Resolve.pstr q));
        Axis (Geom.perpendicular_bisector pp qq, "axiom2", [ Resolve.pstr p; Resolve.pstr q ])
    | Ast.Perp (p, l) ->
        Axis
          ( Geom.perpendicular_through (Resolve.resolve_line ctx l) (Resolve.table_of ctx p),
            "axiom3",
            [ Resolve.pstr p; Resolve.lstr l ] )
    | Ast.MapOntoLine (p, l1, l2) -> (
        let pp = Resolve.table_of ctx p and ll1 = Resolve.resolve_line ctx l1 and ll2 = Resolve.resolve_line ctx l2 in
        match Geom.project_crease pp ll1 ll2 with
        | None ->
            Error.fail span
              (Printf.sprintf "map %s onto %s perp %s: lines are parallel, no fold exists"
                 (Resolve.pstr p) (Resolve.lstr l1) (Resolve.lstr l2))
        | Some crease -> Axis (crease, "axiom4", [ Resolve.pstr p; Resolve.lstr l1; Resolve.lstr l2 ]))
    | Ast.MapLines (l1, l2, p_opt) -> (
        let la = Resolve.resolve_line ctx l1 and lb = Resolve.resolve_line ctx l2 in
        let l1_str = Resolve.lstr l1 and l2_str = Resolve.lstr l2 in
        match Geom.angle_bisectors la lb with
        | None ->
            (* parallel: unique midline, `toward` has no meaning here *)
            let k =
              if Num.sign la.Geom.a <> 0 then Num.div lb.Geom.a la.Geom.a
              else Num.div lb.Geom.b la.Geom.b
            in
            if Num.equal lb.Geom.c (Num.mul k la.Geom.c) then
              Error.fail span "lines are identical";
            Axis (Geom.parallel_midline la lb, "axiom5", [ l1_str; l2_str ])
        | Some cands ->
            (* intersecting: defer bisector choice to the fold state. `toward`
               names where the fold goes, so a point on l1 is meaningless (E1);
               a point on l2 is fine. *)
            let toward = Option.map (Resolve.table_of ctx) p_opt in
            let toward_str = Option.map Resolve.pstr p_opt in
            (match toward with
            | Some x when Geom.side_of_line la x = 0 ->
                Error.fail span
                  (Printf.sprintf
                     "`toward %s` lies on %s; `toward` names where the fold \
                      goes — pick a point off %s"
                     (Option.get toward_str) l1_str l1_str)
            | _ -> ());
            let sources =
              [ l1_str; l2_str ]
              @ (match toward_str with Some s -> [ s ] | None -> [])
            in
            Ax5
              {
                la;
                lb;
                cands;
                toward;
                l1_op = l1;
                l1_str;
                l2_str;
                toward_str;
                sources;
              })
    | Ast.MapThrough (p, d, p', x_opt) -> (
        let pp = Resolve.table_of ctx p and dd = Resolve.resolve_line ctx d and pp' = Resolve.table_of ctx p' in
        if Geom.point_equal pp pp' then
          Error.fail span
            (Printf.sprintf
               "map %s onto %s through %s: %s and %s are the same point, so no \
                fold exists"
               (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr p') (Resolve.pstr p) (Resolve.pstr p'));
        let base = [ Resolve.pstr p; Resolve.lstr d; Resolve.pstr p' ] in
        match Geom.beloch_creases pp dd pp' with
        | [] ->
            Error.fail span
              (Printf.sprintf "cannot fold %s onto %s through %s: out of reach"
                 (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr p'))
        | [ c ] -> Axis (c, "axiom6", base)
        | creases -> (
            match x_opt with
            | None ->
                Error.fail span
                  (Printf.sprintf
                     "two folds place %s onto %s through %s; add 'toward .x'"
                     (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr p'))
            | Some xo ->
                let xt = Resolve.table_of ctx xo in
                (* pick the crease whose landing (the reflection of p across it)
                   is nearest x; exact squared-distance comparison *)
                let dist2 (c : Geom.line) =
                  let im = Geom.reflect_point c pp in
                  let ex = Num.sub im.Geom.x xt.Geom.x
                  and ey = Num.sub im.Geom.y xt.Geom.y in
                  Num.add (Num.mul ex ex) (Num.mul ey ey)
                in
                let best =
                  List.fold_left
                    (fun acc c ->
                      match acc with
                      | None -> Some c
                      | Some b ->
                          if Num.compare (dist2 c) (dist2 b) < 0 then Some c
                          else acc)
                    None creases
                in
                match best with
                | Some c -> Axis (c, "axiom6", base @ [ Resolve.pstr xo ])
                (* unreachable: this arm only runs with ≥2 creases, so the
                   fold over a non-empty list always yields [Some]. *)
                | None -> assert false))
    | Ast.MapBoth (p, d, q, e, x_opt) -> (
        let pp = Resolve.table_of ctx p and dd = Resolve.resolve_line ctx d in
        let qq = Resolve.table_of ctx q and ee = Resolve.resolve_line ctx e in
        let base = [ Resolve.pstr p; Resolve.lstr d; Resolve.pstr q; Resolve.lstr e ] in
        (* degeneracy guards *)
        if Geom.side_of_line ee qq = 0 then
          Error.fail span
            (Printf.sprintf
               "map %s onto %s and %s onto %s: %s already lies on %s — use \
                axiom 6 (fold %s onto %s through a point) then axiom 4"
               (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr q) (Resolve.lstr e) (Resolve.pstr q) (Resolve.lstr e) (Resolve.pstr p)
               (Resolve.lstr d));
        if Geom.parallel dd ee then
          Error.fail span
            (Printf.sprintf
               "map %s onto %s and %s onto %s: %s and %s are parallel — \
                degenerate, no general cubic fold"
               (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr q) (Resolve.lstr e) (Resolve.lstr d) (Resolve.lstr e));
        match Geom.beloch7_creases pp dd qq ee with
        | [] ->
            Error.fail span
              (Printf.sprintf
                 "cannot fold %s onto %s and %s onto %s: out of reach (no \
                  common tangent)"
                 (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr q) (Resolve.lstr e))
        | [ c ] -> Axis (c, "axiom7", base)
        | creases -> (
            match x_opt with
            | None ->
                Error.fail span
                  (Printf.sprintf
                     "%d folds place %s onto %s and %s onto %s; add 'toward \
                      .x'"
                     (List.length creases) (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr q) (Resolve.lstr e))
            | Some xo ->
                let xt = Resolve.table_of ctx xo in
                (* nearest landing of the first point p, exact squared distance *)
                let dist2 (c : Geom.line) =
                  let im = Geom.reflect_point c pp in
                  let ex = Num.sub im.Geom.x xt.Geom.x
                  and ey = Num.sub im.Geom.y xt.Geom.y in
                  Num.add (Num.mul ex ex) (Num.mul ey ey)
                in
                let best =
                  List.fold_left
                    (fun acc c ->
                      match acc with
                      | None -> Some c
                      | Some b ->
                          if Num.compare (dist2 c) (dist2 b) < 0 then Some c
                          else acc)
                    None creases
                in
                match best with
                | Some c -> Axis (c, "axiom7", base @ [ Resolve.pstr xo ])
                | None -> assert false))
  in
  let run_fold_checked ~(span : Error.span) ~(axis : Geom.line)
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
  in
  let run_fold ~(span : Error.span) ~(axis : Geom.line) ~(fs : Ast.fold_spec)
      ~(implied : Ast.point_operand option) ~(side_override : int option)
      ~(crease_id : int) ~(prov : State.provenance option) : unit =
    run_fold_checked ~span ~axis ~fs ~implied ~side_override ~crease_id ~prov
      ~check:None
  in
  (* ---- axiom-5 bisector selection (direction + paper incidence) ---- *)
  (* l1's swinging material as table-space segments *)
  let ax5_material (p : ax5_pending) : (Geom.point * Geom.point) list =
    let of_material cid =
      List.map
        (fun (s : Fold_state.crease_segment) -> (s.Fold_state.ta, s.Fold_state.tb))
        (Fold_state.crease_segments !(ctx.state) cid)
    in
    match p.l1_op with
    | Ast.LNamed cr -> (
        match lookup_crease ctx cr with
        | Material (cid, _) -> of_material cid
        | Bundle _ ->
            List.map
              (fun (s : Fold_state.crease_segment) ->
                (s.Fold_state.ta, s.Fold_state.tb))
              (snd (Resolve.bundle_segments ctx (Ast.LNamed cr)))
        | Edge _ -> Fold_state.line_material_segments !(ctx.state) p.la
        | Mark _ | Frozen _ -> Fold_state.line_material_segments !(ctx.state) p.la)
    | Ast.LSelect _ -> Fold_state.line_material_segments !(ctx.state) p.la
    | (Ast.LFilter _ | Ast.LUnion _) as b ->
        List.map
          (fun (s : Fold_state.crease_segment) ->
            (s.Fold_state.ta, s.Fold_state.tb))
          (snd (Resolve.bundle_segments ctx b))
  in
  (* viability core (shared by bind and fold): one material endpoint strictly on
     side [s] of candidate [b] is a representative of the swinging half; its
     image under reflection lands on [xside] of la iff the fold moves that half
     toward the target. The image is never clipped — a sign suffices. *)
  let swing_rep mat (b : Geom.line) (s : int) : Geom.point option =
    List.find_map
      (fun (u, v) ->
        if Geom.side_of_line b u = s then Some u
        else if Geom.side_of_line b v = s then Some v
        else None)
      mat
  in
  let viable ~(la : Geom.line) ~(xside : int) mat (b : Geom.line) (s : int) : bool
      =
    match swing_rep mat b s with
    | None -> false
    | Some q -> Geom.side_of_line la (Geom.reflect_point b q) = xside
  in
  (* paper-incidence filter for omitted `toward`: keep only bisectors that crease
     the sheet *)
  let ax5_filter (p : ax5_pending) : Geom.line list =
    let b1, b2 = p.cands in
    List.filter (Fold_state.line_cuts_paper !(ctx.state)) [ b1; b2 ]
  in
  let e2 (p : ax5_pending) =
    Printf.sprintf
      "map %s onto %s is ambiguous: both bisectors land on the paper; add \
       `toward .p` to pick the direction"
      p.l1_str p.l2_str
  in
  let e3 (p : ax5_pending) =
    Printf.sprintf
      "map %s onto %s: neither bisector lands on the paper — no fold to make"
      p.l1_str p.l2_str
  in
  let e5_head (p : ax5_pending) (x : string) =
    Printf.sprintf
      "map %s onto %s toward %s is ambiguous: %s straddles the crossing, so \
       both bisectors move material toward %s"
      p.l1_str p.l2_str x p.l1_str x
  in
  let select_axiom5_bind (span : Error.span) (p : ax5_pending) : Geom.line =
    let b1, b2 = p.cands in
    match p.toward with
    | None -> (
        match ax5_filter p with
        | [ b ] -> b
        | [ _; _ ] -> Error.fail span (e2 p)
        | _ -> Error.fail span (e3 p))
    | Some x ->
        let xside = Geom.side_of_line p.la x in
        let mat = ax5_material p in
        let xs = Option.get p.toward_str in
        let viable_c b = viable ~la:p.la ~xside mat b 1 || viable ~la:p.la ~xside mat b (-1) in
        (match List.filter viable_c [ b1; b2 ] with
        | [ b ] -> b
        | [] ->
            Error.fail span
              (Printf.sprintf "no fold of %s onto %s moves its material toward %s"
                 p.l1_str p.l2_str xs)
        | _ ->
            Error.fail span
              (e5_head p xs
              ^ Printf.sprintf "; select the swinging segment of %s with `at`"
                  p.l1_str))
  in
  (* returns the chosen axis + an optional move-side override (Some when the
     direction is derived, not read off an explicit `moving`) *)
  let select_axiom5_fold (span : Error.span) (p : ax5_pending)
      ~(fs : Ast.fold_spec) : Geom.line * int option =
    let b1, b2 = p.cands in
    match p.toward with
    | None -> (
        let b =
          match ax5_filter p with
          | [ b ] -> b
          | [ _; _ ] -> Error.fail span (e2 p)
          | _ -> Error.fail span (e3 p)
        in
        match fs.Ast.moving with
        | Some _ -> (b, None) (* explicit moving: side read off the anchor *)
        | None ->
            (* implied moving: l1's material swings; the side it sits on decides *)
            let mat = ax5_material p in
            if mat = [] then
              Error.fail span
                (Printf.sprintf "%s has no material on the paper to fold" p.l1_str);
            let on s = swing_rep mat b s <> None in
            (match (on 1, on (-1)) with
            | true, false -> (b, Some 1)
            | false, true -> (b, Some (-1))
            | true, true ->
                Error.fail span
                  (Printf.sprintf
                     "%s straddles the fold line; add `moving` to pick the \
                      swinging flap"
                     p.l1_str)
            | false, false ->
                Error.fail span
                  (Printf.sprintf "%s has no material on the paper to fold"
                     p.l1_str)))
    | Some x ->
        let xside = Geom.side_of_line p.la x in
        let mat = ax5_material p in
        let xs = Option.get p.toward_str in
        if mat = [] then
          Error.fail span
            (Printf.sprintf "%s has no material on the paper to fold" p.l1_str);
        (match fs.Ast.moving with
        | None ->
            (* geometry guarantees ≤1 viable side per candidate *)
            let cand_side b =
              if viable ~la:p.la ~xside mat b 1 then Some 1
              else if viable ~la:p.la ~xside mat b (-1) then Some (-1)
              else None
            in
            let viables =
              List.filter_map
                (fun b -> Option.map (fun s -> (b, s)) (cand_side b))
                [ b1; b2 ]
            in
            (match viables with
            | [ (b, s) ] -> (b, Some s)
            | [] ->
                Error.fail span
                  (Printf.sprintf
                     "no fold of %s onto %s moves its material toward %s"
                     p.l1_str p.l2_str xs)
            | _ ->
                Error.fail span
                  (e5_head p xs ^ "; add `moving` to pick the swinging flap"))
        | Some fa ->
            (* the anchor's side of each candidate names the swinging half; a
               candidate is viable iff that half moves toward x. On-axis /
               straddling anchors just reject the candidate. *)
            let viable_c b =
              match Resolve.side_of_flap_arg_res ctx b fa span with
              | Ok s -> viable ~la:p.la ~xside mat b s
              | Error _ -> false
            in
            (match List.filter viable_c [ b1; b2 ] with
            | [ b ] -> (b, None) (* side resolved normally via the anchor *)
            | [] ->
                Error.fail span
                  (Printf.sprintf "no fold of %s onto %s moves %s toward %s"
                     p.l1_str p.l2_str (Resolve.fstr fa) xs)
            | _ ->
                Error.fail span
                  (Printf.sprintf
                     "map %s onto %s toward %s is ambiguous even with `moving \
                      %s`: it lies in both swinging flaps; anchor with a point \
                      in only one flap"
                     p.l1_str p.l2_str xs (Resolve.fstr fa))))
  in
  (* Resolve a markable to either a fresh motion (axis + provenance + the
     axiom-5 side override / implied-anchor, mirroring the old Crease arm) or
     an existing line to fold/mark along. [fold_opt] is [Some fs] only when
     called from a `fold` statement (axiom-5 direction resolution differs
     between bind/mark and fold). *)
  let resolve_markable (span : Error.span) (name_opt : string option)
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
          match axis_of span ax with
          | Axis (axis, axiom, sources) -> (axis, axiom, sources, None)
          | Ax5 p ->
              let axis, so =
                match fold_opt with
                | None -> (select_axiom5_bind span p, None)
                | Some fs -> select_axiom5_fold span p ~fs
              in
              (axis, "axiom5", p.sources, so)
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
  in
  let rec eval_stmt (stmt : Ast.stmt) =
    match stmt with
    | Ast.BindBundle (name, expr, span) ->
        bind_crease ctx name span (Bundle expr)
    | Ast.BindLine (n, ax, span) ->
        (* pure value: resolve the axiom to a line, bind Frozen, no subdivide *)
        let axis =
          match axis_of span ax with
          | Axis (axis, _, _) -> axis
          | Ax5 p -> select_axiom5_bind span p
        in
        bind_crease ctx n span (Frozen axis)
    | Ast.Mark (name_opt, m, ext, dir, layer_opt, span) -> (
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
        match resolve_markable span name_opt None m with
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
            promote ())
    | Ast.Fold (name_opt, m, fs, span) -> (
        match resolve_markable span name_opt (Some fs) m with
        | `Fresh (cid, axis, prov, side_override, implied) ->
            run_fold ~span ~axis ~fs ~implied ~side_override ~crease_id:cid ~prov;
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
            run_fold ~span ~axis ~fs ~implied:None ~side_override:None
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
            run_fold_checked ~span ~axis ~fs ~implied:None ~side_override:None
              ~crease_id:cid ~prov ~check:(Some check_straight);
            push_frame ctx (Some span))
    | Ast.Point (n, Ast.PsExpr po, span) ->
        bind_point ctx n span (Resolve.resolve_point ctx po)
    | Ast.Point (n, Ast.PsFree { line; anchor; t; span }, _) ->
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
    | Ast.Flip _ ->
        ctx.state := Fold_state.flip !(ctx.state);
        ctx.pending <- true
    | Ast.Def (name, params, body, span) ->
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
    | Ast.Apply (bind_opt, defname, args, span) ->
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
        List.iter eval_stmt body;
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
    | Ast.Export (entries_opt, iname, span) ->
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
    | Ast.Flatten (name_opt, elems, overs, staying_opt, toward_opt, span) ->
        (* materialize every collapse crease FIRST (a mark subdivides on
           segment-selection), so all of them cross and the shared collapse
           vertex is fully formed before any ray is selected. Selecting rays
           one-by-one would subdivide the first crease before the others exist,
           leaving it unsplit at the vertex (`no common interior vertex`). *)
        let rec force_material (lo : Ast.line_operand) =
          match lo with
          | Ast.LNamed cr -> ignore (Resolve.material_cid ctx cr)
          | Ast.LFilter (b, _, _) -> force_material b
          | Ast.LUnion (los, _) -> List.iter force_material los
          | Ast.LSelect _ -> ()
        in
        List.iter (fun (el : Ast.collapse_elem) -> force_material el.Ast.cline) elems;
        (* a resolved ray keeps its M/V CONSTRAINT (not yet a concrete valley
           — that's the solver's job now, spec 2026-07-16-flatten-derive-v2-
           design.md "the model"), as a 4-tuple rather than [Collapse.elem] so
           its fields can't be confused with that type's same-named
           cid/ea/eb once both are in scope below. *)
        let fail_not_material (el : Ast.collapse_elem) () =
          Error.fail span
            (Printf.sprintf
               "collapse folds along existing creases; %s is not a material \
                crease" (Resolve.lstr el.Ast.cline))
        in
        (* each element resolves to 1..k material SEGMENTS at the vertex — no
           eager multi-segment error any more (spec 2026-07-17 §Segment
           inference): the stayer filter and the vertex check prune the wrong
           segment combinations. Only genuinely-non-material operands error,
           with the old zero-segment texts verbatim. *)
        let resolve_elem_candidates (el : Ast.collapse_elem) :
            (int * Geom.point * Geom.point * Ast.mv_constraint) list =
          let seg_tuple cid (s : Fold_state.crease_segment) =
            (cid, s.Fold_state.ta, s.Fold_state.tb, el.Ast.cdir)
          in
          match el.Ast.cline with
          | Ast.LNamed cr -> (
              let cid = Resolve.material_cid ctx cr in
              match Fold_state.crease_segments !(ctx.state) cid with
              | [] ->
                  Error.fail span
                    (Printf.sprintf "--%s has no material segment" cr.Ast.cname)
              | segs -> List.map (seg_tuple cid) segs)
          | (Ast.LFilter _ | Ast.LUnion _) as lo -> (
              match Resolve.bundle_segments ctx lo with
              | _, [] ->
                  Error.fail span
                    (Printf.sprintf "no segment of %s matches" (Resolve.lstr lo))
              | Some cid, segs -> List.map (seg_tuple cid) segs
              | None, _ ->
                  (* segments from a cross-crease union: no single cid to fold
                     along *)
                  fail_not_material el ())
          | _ -> fail_not_material el ()
        in
        let elem_cands = List.map resolve_elem_candidates elems in
        let elem_of (fcid, fea, feb, valley) =
          { Collapse.cid = fcid; ea = fea; eb = feb; valley }
        in
        (* vertex O: the strictly-interior point shared by >= 1 candidate
           segment of EVERY element (generalizes [Collapse.common_vertex] to the
           per-element candidate lists). *)
        let strictly_interior_pt (p : Geom.point) =
          Num.sign p.Geom.x > 0
          && Num.compare p.Geom.x Num.one < 0
          && Num.sign p.Geom.y > 0
          && Num.compare p.Geom.y Num.one < 0
        in
        let o =
          let shared_by_all p =
            List.for_all
              (fun cands ->
                List.exists
                  (fun (_, a, b, _) ->
                    Geom.point_equal a p || Geom.point_equal b p)
                  cands)
              elem_cands
          in
          let endpoints =
            List.concat_map (fun (_, a, b, _) -> [ a; b ]) (List.hd elem_cands)
          in
          match
            List.find_opt
              (fun p -> strictly_interior_pt p && shared_by_all p)
              endpoints
          with
          | Some o -> o
          | None -> Error.fail span Collapse.e_no_vertex
        in
        (* keep only the candidate segments that actually end at O; every
           element has >= 1 such by O's construction. *)
        let elem_cands_at_o =
          List.map
            (List.filter (fun (_, a, b, _) ->
                 Geom.point_equal a o || Geom.point_equal b o))
            elem_cands
        in
        let far_at_o (a : Geom.point) (b : Geom.point) : Geom.point =
          if Geom.point_equal a o then b else a
        in
        let far_of_combo_elem (_, a, b, _) = far_at_o a b in
        (* combinations: one chosen segment per element (product; <= 2 per
           element in practice, so the corpus tops out at 2 combinations). *)
        let rec product = function
          | [] -> [ [] ]
          | xs :: rest ->
              List.concat_map
                (fun x -> List.map (fun r -> x :: r) (product rest))
                xs
        in
        let combos = product elem_cands_at_o in
        let over =
          List.map
            (fun (u, l) -> (Resolve.resolve_sector_face ctx u span, Resolve.resolve_sector_face ctx l span))
            overs
        in
        (* explicit staying: X's material is the stayer, order carries no
           meaning. The flap must touch the vertex fan, else it names no stayer
           sector at all (distinct from "no realization keeps it still"). *)
        let staying_stayer =
          match staying_opt with
          | None -> None
          | Some fa ->
              let faces = Resolve.resolve_flap_cluster ctx fa span in
              let touches =
                List.exists
                  (fun f ->
                    Array.exists (Geom.point_equal o)
                      (Fold_state.table_polygon_ccw !(ctx.state) f))
                  faces
              in
              if not touches then
                Error.fail span "the staying flap does not touch the vertex"
              else Some (Collapse.Faces faces)
        in
        let n_given = List.length elems in
        let odd = n_given mod 2 = 1 in
        let prov : State.provenance option =
          Some
            { State.axiom = "flatten"; sources = []; span; name = None }
        in
        (* pre-mint the emergent crease id ONCE (odd case only — the even
           case never materializes anything), so every candidate's probe
           subdivision (below) and the eventual winner share one id instead
           of drifting the global counter per candidate. *)
        let new_cid = lazy (Fold_state.fresh_crease_id ()) in
        (* the stayer for a bare combination: the <π arc between the first two
           ELEMENTS' chosen folded rays (leading-element convention). *)
        let arc_stayer combo =
          match combo with
          | e1 :: e2 :: _ ->
              Collapse.Arc (far_of_combo_elem e1, far_of_combo_elem e2)
          | _ -> Collapse.Arc (o, o)
        in
        (* KERNEL LIMITATION cover (Task-2 reviewer finding): the kernel's
           [admissible_sectors] cannot tell "the emergent splits the leading
           arc" (legitimate, 2 mirror worlds) from "another GIVEN element's ray
           sits strictly inside the arc" (dead — stayed material cannot carry a
           folding crease, spec §Semantics). The latter kill is ours, done here
           over the GIVEN rays before the kernel runs. Gated on a genuine
           segment choice (>1 combination): with a single combination the input
           has no alternative and the pre-2026-07-17 convention behaviour stands.
           Absent under [staying] — the convention carries no meaning then. *)
        let leading_arc_ok combo =
          match (staying_opt, combo) with
          | Some _, _ -> true
          | None, e1 :: e2 :: rest ->
              let f1 = far_of_combo_elem e1 and f2 = far_of_combo_elem e2 in
              let oc = (o.Geom.x, o.Geom.y) in
              let c =
                Collapse.cross oc (f1.Geom.x, f1.Geom.y) (f2.Geom.x, f2.Geom.y)
              in
              if Num.sign c = 0 then true (* collinear -> kernel: e_stayer_collinear *)
              else
                let a, b = if Num.sign c > 0 then (f1, f2) else (f2, f1) in
                not
                  (List.exists
                     (fun e -> Collapse.in_ccw_arc o a b (far_of_combo_elem e))
                     rest)
          | None, _ -> true
        in
        (* the all-layers congruence guard (spec §Semantics: "Material /
           layers"), now judged per combination so a wrong-segment combination
           is dropped rather than aborting the whole statement. For each chosen
           element segment's table-space line, any face it actually cuts (not
           just grazes) must already carry THAT element's crease on that line —
           else the bundle is bent/missing on some layer and folding it as one
           unit is unsound. Returns the guard error, or None if the combination
           passes. *)
        let all_layers_error combo =
          let st = !(ctx.state) in
          List.find_map
            (fun (fcid, fea, feb, _) ->
              let line = Geom.line_through fea feb in
              let aligned_faces =
                Fold_state.crease_segments st fcid
                |> List.concat_map (fun (s : Fold_state.crease_segment) ->
                       if
                         Geom.side_of_line line s.Fold_state.ta = 0
                         && Geom.side_of_line line s.Fold_state.tb = 0
                       then
                         let l, r = s.Fold_state.faces in
                         l :: (if r >= 0 then [ r ] else [])
                       else [])
              in
              let bad = ref false in
              Array.iteri
                (fun i _ ->
                  if
                    Geom.segment_cuts_polygon (fea, feb)
                      (Fold_state.table_polygon_ccw st i)
                    && not (List.mem i aligned_faces)
                  then bad := true)
                (Fold_state.faces st);
              if !bad then Some "collapse through unaligned layers" else None)
            combo
        in
        (* run one combination: pool every (state, tier, emergent-binding) that
           a candidate x M/V-pattern attempt closed, and every failure message.
           [given_fars] is this combination's given rays' far tips (the emergent
           scan excludes them). *)
        let run_combo combo (stayer : Collapse.stayer) =
          let local_real :
              (Fold_state.t * [ `Tier1 | `Tier2 ] * (int * Geom.line) option)
              list ref =
            ref []
          in
          let local_err = ref [] in
          let elems_geom =
            List.map (fun (a, b, c, _) -> elem_of (a, b, c, true)) combo
          in
          let given_fars = List.map (Collapse.far_of o) elems_geom in
          let try_patterns (st' : Fold_state.t) (tier : [ `Tier1 | `Tier2 ])
              (emergent : (int * Geom.line) option)
              (all_rays :
                (int * Geom.point * Geom.point * Ast.mv_constraint) list) =
            let constraints = List.map (fun (_, _, _, d) -> d) all_rays in
            let patterns = Flatten.mv_patterns constraints in
            (* one call solves every Maekawa pattern over the fixed vertex
               geometry, sharing placements/overlaps across patterns instead of
               refolding per pattern; [es_geom]'s valley is a placeholder (the
               real per-ray valley rides in [patterns]). *)
            let es_geom =
              List.map (fun (fcid, fea, feb, _) -> elem_of (fcid, fea, feb, true))
                all_rays
            in
            List.iter
              (fun res ->
                match res with
                | Ok sts ->
                    List.iter
                      (fun s -> local_real := (s, tier, emergent) :: !local_real)
                      sts
                | Error msg -> local_err := msg :: !local_err)
              (Collapse.collapse_all_patterns st' es_geom ~over ~stayer ~patterns)
          in
          (if odd then
             let fixed = Collapse.sort_ccw o elems_geom in
             match Flatten.candidates o ~fixed with
             | [] -> local_err := Flatten.e_infeasible :: !local_err
             | cands ->
                 List.iter
                   (fun (line, ray_pt, tag) ->
                     let tier : [ `Tier1 | `Tier2 ] =
                       match tag with
                       | `LineNew -> `Tier1
                       | `OppositeRay -> `Tier2
                     in
                     (* materialize ONLY this candidate ray on a local copy of
                        the pre-flatten state, then scan every crease ray now
                        sitting at O on the kept side (the perpendicular guard
                        confines the cut to [ray_pt]'s side). Collinear-reuse
                        (the rabbit-ear up-spine) is found among EXISTING
                        segments, not [new_cid]. *)
                     let guard = Geom.perpendicular_through line o in
                     let keep = Geom.side_of_line guard ray_pt in
                     let st' =
                       Fold_state.subdivide !(ctx.state) line
                         ~crease_id:(Lazy.force new_cid)
                         ~keep_side:(guard, keep) ~prov
                     in
                     let far_of_seg (s : Fold_state.crease_segment) =
                       if Geom.point_equal s.Fold_state.ta o then s.Fold_state.tb
                       else s.Fold_state.ta
                     in
                     let matches =
                       Fold_state.all_crease_ids st'
                       |> List.concat_map (fun cid ->
                              Fold_state.crease_segments st' cid
                              |> List.filter_map
                                   (fun (s : Fold_state.crease_segment) ->
                                     let far = far_of_seg s in
                                     if
                                       (Geom.point_equal s.Fold_state.ta o
                                       || Geom.point_equal s.Fold_state.tb o)
                                       && Geom.side_of_line line far = 0
                                       && Geom.side_of_line guard far = keep
                                       && not
                                            (List.exists (Geom.point_equal far)
                                               given_fars)
                                     then Some (cid, far)
                                     else None))
                     in
                     List.iter
                       (fun (cid, far) ->
                         let emergent_ray = (cid, o, far, Ast.MvFree) in
                         try_patterns st' tier (Some (cid, line))
                           (emergent_ray :: combo))
                       matches)
                   cands
           else try_patterns !(ctx.state) `Tier1 None combo);
          (!local_real, !local_err, given_fars)
        in
        (* enumerate combinations; each yields realizations + errors. A
           combination is dropped (contributes only errors) when the leading-arc
           filter or the all-layers guard rejects it. *)
        let multiseg =
          let rec find els cands =
            match (els, cands) with
            | el :: es, cs :: cr ->
                if List.length cs > 1 then Resolve.lstr el.Ast.cline else find es cr
            | _ -> "--?"
          in
          find elems elem_cands_at_o
        in
        let combo_runs =
          List.map
            (fun combo ->
              let stayer =
                match staying_stayer with
                | Some s -> s
                | None -> arc_stayer combo
              in
              if List.length combos > 1 && not (leading_arc_ok combo) then
                (combo, [], [])
              else
                match all_layers_error combo with
                | Some e -> (combo, [], [ e ])
                | None ->
                    let r, e, _ = run_combo combo stayer in
                    (combo, r, e))
            combos
        in
        let surviving = List.filter (fun (_, r, _) -> r <> []) combo_runs in
        (* a genuine segment contradiction: two combinations both close with
           non-empty pools -> the user must disambiguate with `&`. *)
        (match surviving with
        | _ :: _ :: _ ->
            Error.fail span
              (Printf.sprintf
                 "%s is ambiguous at the vertex; select a segment with `&`"
                 multiseg)
        | _ -> ());
        (* the winning combination (or the leading one when none survive, so the
           selection code's [rays]/[given_fars] are well-defined for the
           error-reporting path). *)
        let winner_combo =
          match surviving with (c, _, _) :: _ -> c | [] -> List.hd combos
        in
        let rays = winner_combo in
        let given_fars =
          List.map
            (fun (a, b, c, _) -> Collapse.far_of o (elem_of (a, b, c, true)))
            winner_combo
        in
        let realizations =
          match surviving with (_, r, _) :: _ -> r | [] -> []
        in
        let error_pool = List.concat_map (fun (_, _, e) -> e) combo_runs in
        let tier1, tier2 = List.partition (fun (_, t, _) -> t = `Tier1) realizations in
        let deciding = if tier1 <> [] then tier1 else tier2 in
        (* records the emergent crease's (id, line) here so the name (if
           any) binds to it instead of the given rays; None if no candidate
           ray was materialized (even case) or left unbound. *)
        let emergent_bind = ref None in
        (match deciding with
        | [] ->
            (* spec step 6: out-of-paper trumps everything; otherwise the
               odd/even cases report differently — the odd case collapses
               every closure failure into one message (364660f's original
               differentiation, preserved verbatim); the even case surfaces
               the pool's own dominant kernel error instead, since there is
               no derived-crease framing to fall back on. *)
            let pool = error_pool in
            if List.mem Collapse.e_out_of_paper pool then
              Error.fail span Collapse.e_out_of_paper
            else (
              match
                (* eval-level and stayer diagnoses outrank the generic
                   "derived crease does not close": the all-layers guard
                   (a dropped combination), a collinear leading pair, and a
                   dead [staying] flap each name a specific fixable cause. *)
                List.find_opt
                  (fun m ->
                    m = "collapse through unaligned layers"
                    || m = Collapse.e_stayer_collinear
                    || m = Collapse.e_stayer_dead)
                  pool
              with
            | Some m -> Error.fail span m
            | None ->
            if odd then
              Error.fail span "the derived crease does not close the vertex"
            else begin
              match List.find_opt (fun m -> m <> Collapse.e_selfint) pool with
              | Some m -> Error.fail span m
              | None ->
                  (* pool = [] only when every candidate's pin set was itself
                     Maekawa-unsatisfiable (no pattern to even try); a pool of
                     all-e_selfint falls back to e_selfint itself. *)
                  Error.fail span
                    (if pool = [] then Collapse.e_maekawa else Collapse.e_selfint)
            end)
        | [ (st, _, emergent) ] ->
            ctx.state := st;
            emergent_bind := emergent
        | many ->
            (* |deciding| > 1 — three-stage selection (amended spec 38bd69e +
               .superpowers/sdd/toward-stacking-rule.md, 2026-07-16):
               1. POSITION stage: placements depend only on ray LINES, so
                  realizations group into position classes by moved-material
                  centroid; {toward} picks the class by centroid dot.
               2. MIN-MOUNTAIN CANON: within the class, keep only the
                  realizations with the fewest derived mountains among the
                  USER-GIVEN creases (a freshly-materialized emergent cid is
                  not a given cid, so it is excluded automatically; a
                  collinear-reuse emergent — the fish diagonal — IS a given
                  cid and counts, per the rule doc's fish derivation).
               3. RANK-DIPOLE stage: if several remain, maximize
                  S(R) = Σ_faces area · (rank − (nf−1)/2) ·
                  ((table_centroid − O)·(toward − O)) — "the material lying
                  toward p ends up on top." Mirror realizations score ±equal,
                  so any off-axis toward decides; toward ON a reflective
                  symmetry axis of the given rays is guarded explicitly. *)
            let paper_centroid_area (poly : Geom.point array) :
                Geom.point * Num.t =
              let n = Array.length poly in
              let a2 = ref Num.zero and cx = ref Num.zero and cy = ref Num.zero in
              for i = 0 to n - 1 do
                let p = poly.(i) and q = poly.((i + 1) mod n) in
                let cross =
                  Num.sub (Num.mul p.Geom.x q.Geom.y) (Num.mul q.Geom.x p.Geom.y)
                in
                a2 := Num.add !a2 cross;
                cx := Num.add !cx (Num.mul (Num.add p.Geom.x q.Geom.x) cross);
                cy := Num.add !cy (Num.mul (Num.add p.Geom.y q.Geom.y) cross)
              done;
              let area = Num.div !a2 (Num.of_int 2) in
              let denom = Num.mul (Num.of_int 3) !a2 in
              ({ Geom.x = Num.div !cx denom; y = Num.div !cy denom }, area)
            in
            (* stage-2 canon: derived (never stored) M/V per hinge —
               [Fold_state.mv] reads rank + orientation, so two stackings of
               one pattern can differ. A given cid is a mountain iff some
               FOLDED hinge of that cid derives M. *)
            let given_cids =
              List.sort_uniq compare (List.map (fun (c, _, _, _) -> c) rays)
            in
            let given_mountains (st, _, _) : int =
              List.length
                (List.filter
                   (fun cid ->
                     let hs = Fold_state.hinges st in
                     let m = ref false in
                     Array.iteri
                       (fun i (h : Fold_state.hinge) ->
                         if
                           h.Fold_state.crease_id = cid
                           && Num.sign h.Fold_state.angle <> 0
                           && Fold_state.mv st i = Fold_state.M
                         then m := true)
                       hs;
                     !m)
                   given_cids)
            in
            let min_mountain_filter rs =
              let counted = List.map (fun r -> (given_mountains r, r)) rs in
              let m = List.fold_left (fun acc (c, _) -> min acc c) max_int counted in
              List.filter_map (fun (c, r) -> if c = m then Some r else None) counted
            in
            let commit (st, _, emergent) =
              ctx.state := st;
              emergent_bind := emergent
            in
            (match toward_opt with
            | None -> (
                (* no class to pick without {toward}; the min-mountain canon
                   is toward-independent, so it may still single out THE
                   least-forced realization — only a post-canon surplus is a
                   genuine ambiguity (spec: "no {toward} while |S| > 1 after
                   stage 2"). *)
                match min_mountain_filter many with
                | [ r ] -> commit r
                | kept ->
                    Error.fail span
                      (Printf.sprintf
                         "flatten is ambiguous: %d realizations; add {toward \
                          .p} to pick the fold direction"
                         (List.length kept)))
            | Some toward_po ->
                let toward_pt = Resolve.resolve_point ctx toward_po in
                let st_pre = !(ctx.state) in
                (* stage 1 — moved-material centroid per realization; a pure
                   function of table placement, shared within a class. *)
                let centroid_of (st_post, _, _) : Geom.point =
                  let faces = Fold_state.faces st_post in
                  let nf = Array.length faces in
                  let sx = ref Num.zero and sy = ref Num.zero and sa = ref Num.zero in
                  for f = 0 to nf - 1 do
                    let c_f, a_f = paper_centroid_area faces.(f) in
                    let pre_pos = Fold_state.table_position st_pre c_f in
                    let post_pos =
                      Isometry.apply_point (Fold_state.face_iso2 st_post f) c_f
                    in
                    if not (Geom.point_equal pre_pos post_pos) then begin
                      sx := Num.add !sx (Num.mul a_f post_pos.Geom.x);
                      sy := Num.add !sy (Num.mul a_f post_pos.Geom.y);
                      sa := Num.add !sa a_f
                    end
                  done;
                  if Num.sign !sa = 0 then
                    invalid_arg
                      "Flatten: a completed collapse moved no material \
                       (unreachable)"
                  else { Geom.x = Num.div !sx !sa; y = Num.div !sy !sa }
                in
                let dot_toward (p : Geom.point) : Num.t =
                  Num.add
                    (Num.mul (Num.sub p.Geom.x o.Geom.x)
                       (Num.sub toward_pt.Geom.x o.Geom.x))
                    (Num.mul (Num.sub p.Geom.y o.Geom.y)
                       (Num.sub toward_pt.Geom.y o.Geom.y))
                in
                let by_centroid = List.map (fun r -> (centroid_of r, r)) many in
                let distinct_centroids =
                  List.fold_left
                    (fun acc (c, _) ->
                      if List.exists (Geom.point_equal c) acc then acc else c :: acc)
                    [] by_centroid
                in
                let class_scored =
                  List.map (fun c -> (dot_toward c, c)) distinct_centroids
                  |> List.sort (fun (d1, _) (d2, _) -> Num.compare d2 d1)
                in
                let winning_centroid =
                  match class_scored with
                  | (d0, _) :: (d1, _) :: _ when Num.compare d0 d1 = 0 ->
                      (* two DISTINCT position classes tie — toward is
                         collinear with a crease through O (the classes are
                         mirror-symmetric about it) *)
                      Error.fail span Flatten.e_toward_ambiguous
                  | (_, c) :: _ -> c
                  | [] -> assert false (* [many] is non-empty here *)
                in
                let winners =
                  List.filter_map
                    (fun (c, r) ->
                      if Geom.point_equal c winning_centroid then Some r else None)
                    by_centroid
                in
                (* stage 2 *)
                (match min_mountain_filter winners with
                | [] -> assert false (* filter of a non-empty list *)
                | [ r ] -> commit r
                | kept ->
                    (* stage 3 — but first the symmetry-axis guard (rule doc
                       §Ties): the dipole's null direction is NOT the
                       geometric mirror axis, so an on-axis toward would get
                       a strict-but-arbitrary argmax; if the given-ray
                       direction set is invariant under reflection across the
                       O–toward line, the sides are genuinely
                       indistinguishable. *)
                    let on_symmetry_axis =
                      Geom.point_equal toward_pt o
                      ||
                      let axis = Geom.line_through o toward_pt in
                      let refl = Isometry.reflect_across_line axis in
                      List.for_all
                        (fun far ->
                          let rf = Isometry.apply_point refl far in
                          List.exists
                            (fun g -> Geom.ccw_compare ~center:o rf g = 0)
                            given_fars)
                        given_fars
                    in
                    if on_symmetry_axis then
                      Error.fail span Flatten.e_toward_ambiguous
                    else
                      let dipole (st, _, _) : Num.t =
                        let faces = Fold_state.faces st in
                        let rank = Fold_state.rank st in
                        let nf = Array.length faces in
                        let center =
                          Num.div (Num.of_int (nf - 1)) (Num.of_int 2)
                        in
                        let acc = ref Num.zero in
                        for f = 0 to nf - 1 do
                          let pc, a_f = paper_centroid_area faces.(f) in
                          let a_f = if Num.sign a_f < 0 then Num.neg a_f else a_f in
                          let tc =
                            Isometry.apply_point (Fold_state.face_iso2 st f) pc
                          in
                          acc :=
                            Num.add !acc
                              (Num.mul a_f
                                 (Num.mul
                                    (Num.sub (Num.of_int rank.(f)) center)
                                    (dot_toward tc)))
                        done;
                        !acc
                      in
                      let scored =
                        List.map (fun r -> (dipole r, r)) kept
                        |> List.sort (fun (d1, _) (d2, _) -> Num.compare d2 d1)
                      in
                      (match scored with
                      | (d0, _) :: (d1, _) :: _ when Num.compare d0 d1 = 0 ->
                          Error.fail span Flatten.e_toward_ambiguous
                      | (_, r) :: _ -> commit r
                      | [] -> assert false (* [kept] has >= 2 elements *)))));
        (* bind the name (if any): with no emergent ray materialized, bind a
           selectable bundle of the given rays; with one, bind the EMERGENT
           crease instead (the newly-completed vertex's own crease, not the
           rays that produced it), so a meet-point selector against the name
           (e.g. `.[--ear --ab]`) finds the emergent crease's tip. *)
        (match name_opt with
        | Some n ->
            let cv =
              match !emergent_bind with
              | Some (cid, line) -> Material (cid, line)
              | None ->
                  Bundle
                    (Ast.LUnion
                       (List.map (fun (el : Ast.collapse_elem) -> el.Ast.cline) elems, span))
            in
            bind_crease ctx n span cv
        | None -> ());
        push_frame ctx (Some span)
  in
  (match resume with Some s -> restore ctx s | None -> ());
  List.iter (fun stmt -> eval_stmt stmt; on_step ctx) prog;
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

let eval_folded (prog : Ast.program) : folded = eval_program prog
