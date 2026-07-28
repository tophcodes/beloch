(** Axiom construction: the seven Huzita-Justin axioms and the axiom-5
    bisector-selection path. Every stateful function takes
    [(ctx : Ctx.ctx)] as its first parameter. *)

open Ctx

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

(* axis line + provenance (axiom tag, source names), evaluated against the
   current table positions *)
let axis_of (ctx : Ctx.ctx) (span : Error.span) (ax : Ast.axiom) : axis_result =
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

(* ---- axiom-5 bisector selection (direction + paper incidence) ---- *)
(* l1's swinging material as table-space segments *)
let ax5_material (ctx : Ctx.ctx) (p : ax5_pending) : (Geom.point * Geom.point) list =
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

let viable ~(la : Geom.line) ~(xside : int) mat (b : Geom.line) (s : int) : bool
    =
  match swing_rep mat b s with
  | None -> false
  | Some q -> Geom.side_of_line la (Geom.reflect_point b q) = xside

(* paper-incidence filter for omitted `toward`: keep only bisectors that crease
   the sheet *)
let ax5_filter (ctx : Ctx.ctx) (p : ax5_pending) : Geom.line list =
  let b1, b2 = p.cands in
  List.filter (Fold_state.line_cuts_paper !(ctx.state)) [ b1; b2 ]

let e2 (p : ax5_pending) =
  Printf.sprintf
    "map %s onto %s is ambiguous: both bisectors land on the paper; add \
     `toward .p` to pick the direction"
    p.l1_str p.l2_str

let e3 (p : ax5_pending) =
  Printf.sprintf
    "map %s onto %s: neither bisector lands on the paper — no fold to make"
    p.l1_str p.l2_str

let e5_head (p : ax5_pending) (x : string) =
  Printf.sprintf
    "map %s onto %s toward %s is ambiguous: %s straddles the crossing, so \
     both bisectors move material toward %s"
    p.l1_str p.l2_str x p.l1_str x

let select_axiom5_bind (ctx : Ctx.ctx) (span : Error.span) (p : ax5_pending) : Geom.line =
  let b1, b2 = p.cands in
  match p.toward with
  | None -> (
      match ax5_filter ctx p with
      | [ b ] -> b
      | [ _; _ ] -> Error.fail span (e2 p)
      | _ -> Error.fail span (e3 p))
  | Some x ->
      let xside = Geom.side_of_line p.la x in
      let mat = ax5_material ctx p in
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

(* returns the chosen axis + an optional move-side override (Some when the
   direction is derived, not read off an explicit `moving`) *)
let select_axiom5_fold (ctx : Ctx.ctx) (span : Error.span) (p : ax5_pending)
    ~(fs : Ast.fold_spec) : Geom.line * int option =
  let b1, b2 = p.cands in
  match p.toward with
  | None -> (
      let b =
        match ax5_filter ctx p with
        | [ b ] -> b
        | [ _; _ ] -> Error.fail span (e2 p)
        | _ -> Error.fail span (e3 p)
      in
      match fs.Ast.moving with
      | Some _ -> (b, None) (* explicit moving: side read off the anchor *)
      | None ->
          (* implied moving: l1's material swings; the side it sits on decides *)
          let mat = ax5_material ctx p in
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
      let mat = ax5_material ctx p in
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
