(** Axiom construction: the seven Huzita-Justin axioms and the axiom-5
    bisector-selection path. Every stateful function takes
    [(ctx : Ctx.ctx)] as its first parameter. *)

open Ctx

(* ---- recognition: an alignment set as one of the seven axioms ---- *)

type classified =
  | Ax1 of Ast.point_operand * Ast.point_operand
  | Ax2 of Ast.point_operand * Ast.point_operand
  | Ax3 of Ast.point_operand * Ast.line_operand
  | Ax4 of Ast.point_operand * Ast.line_operand * Ast.line_operand
  | Ax5 of Ast.line_operand * Ast.line_operand * Ast.point_operand option
  | Ax6 of
      Ast.point_operand * Ast.line_operand * Ast.point_operand
      * Ast.point_operand option
  | Ax7 of
      Ast.point_operand * Ast.line_operand * Ast.point_operand
      * Ast.line_operand * Ast.point_operand option

let kind_name (k : Ast.alignment_kind) : string =
  match k with
  | Ast.AlOnto (Ast.AoPoint _, Ast.AoPoint _) -> "point onto point"
  | Ast.AlOnto (Ast.AoPoint _, Ast.AoLine _) -> "point onto line"
  | Ast.AlOnto (Ast.AoLine _, Ast.AoPoint _) -> "line onto point"
  | Ast.AlOnto (Ast.AoLine _, Ast.AoLine _) -> "line onto line"
  | Ast.AlThrough _ -> "through a point"
  | Ast.AlPerp _ -> "perp to a line"

let unrecognised (c : Ast.construction) : 'a =
  Error.fail c.Ast.c_span
    ("these alignments are not one of the seven axioms: "
    ^ String.concat ", "
        (List.map (fun (a : Ast.alignment) -> kind_name a.Ast.al_kind)
           c.Ast.c_alignments))

(* A construction that names fold lines, in its head or on an alignment, is
   the two-fold form: representable, and outside what the kernel solves. *)
let names_fold_lines (c : Ast.construction) : bool =
  c.Ast.c_fold_lines <> []
  || List.exists
       (fun (a : Ast.alignment) ->
         a.Ast.al_fold_line <> None || a.Ast.al_fold_line2 <> None)
       c.Ast.c_alignments

let classify (c : Ast.construction) : classified =
  if names_fold_lines c then
    Error.fail c.Ast.c_span
      "a construction over named fold lines is not evaluated yet";
  (* the multiset of kinds, each bucket in source order: where a kind occurs
     twice (axioms 1 and 7), source order fixes the operand roles *)
  let onto_pp = ref [] and onto_pl = ref [] and onto_ll = ref [] in
  let through = ref [] and perp = ref [] and other = ref false in
  List.iter
    (fun (a : Ast.alignment) ->
      match a.Ast.al_kind with
      | Ast.AlOnto (Ast.AoPoint p, Ast.AoPoint q) -> onto_pp := (p, q) :: !onto_pp
      | Ast.AlOnto (Ast.AoPoint p, Ast.AoLine l) -> onto_pl := (p, l) :: !onto_pl
      | Ast.AlOnto (Ast.AoLine l, Ast.AoLine m) -> onto_ll := (l, m) :: !onto_ll
      | Ast.AlOnto (Ast.AoLine _, Ast.AoPoint _) -> other := true
      | Ast.AlThrough p -> through := p :: !through
      | Ast.AlPerp l -> perp := l :: !perp)
    c.Ast.c_alignments;
  let onto_pp = List.rev !onto_pp
  and onto_pl = List.rev !onto_pl
  and onto_ll = List.rev !onto_ll
  and through = List.rev !through
  and perp = List.rev !perp in
  let one_line () =
    (* toward selects among the candidates of axioms 5, 6 and 7; the other
       four determine one line *)
    if c.Ast.c_toward <> None then
      Error.fail ~hint:"drop toward" c.Ast.c_span
        "this construction determines one line"
  in
  if !other then unrecognised c
  else
    match (onto_pp, onto_pl, onto_ll, through, perp) with
    | [], [], [], [ p; q ], [] ->
        one_line ();
        Ax1 (p, q)
    | [ (p, q) ], [], [], [], [] ->
        one_line ();
        Ax2 (p, q)
    | [], [], [], [ p ], [ l ] ->
        one_line ();
        Ax3 (p, l)
    | [], [ (p, d) ], [], [], [ m ] ->
        one_line ();
        Ax4 (p, d, m)
    | [], [], [ (l, m) ], [], [] -> Ax5 (l, m, c.Ast.c_toward)
    | [], [ (p, d) ], [], [ q ], [] -> Ax6 (p, d, q, c.Ast.c_toward)
    | [], [ (p, d); (q, e) ], [], [], [] -> Ax7 (p, d, q, e, c.Ast.c_toward)
    | _ -> unrecognised c

let tag (cl : classified) : string =
  match cl with
  | Ax1 _ -> "axiom1"
  | Ax2 _ -> "axiom2"
  | Ax3 _ -> "axiom3"
  | Ax4 _ -> "axiom4"
  | Ax5 _ -> "axiom5"
  | Ax6 _ -> "axiom6"
  | Ax7 _ -> "axiom7"

(* the point a map construction moves: a `fold` with no `moving` anchors on
   it, and `reverse` reads it as the tip *)
let implied_point (cl : classified) : Ast.point_operand option =
  match cl with
  | Ax2 (p, _) | Ax6 (p, _, _, _) | Ax7 (p, _, _, _, _) -> Some p
  | Ax1 _ | Ax3 _ | Ax4 _ | Ax5 _ -> None

(* axiom-5 (`map --l1 onto --l2`) needs its candidate bisectors selected against
   the current fold state (material of l1, paper incidence, `toward` direction),
   so [axis_of] defers that: intersecting lines yield [Ax5], everything else a
   fully-resolved [Axis]. *)
type ax5_pending = {
  la : Geom.line;
  cands : Geom.line * Geom.line;   (* angle bisectors of la and l2's line *)
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

let ax5_sources (p : ax5_pending) : string list = p.sources

(* axis line + provenance (axiom tag, source names), evaluated against the
   current table positions *)
(* One candidate, the one the construction yields. *)
let only (l : Geom.line) : Trace.candidate list =
  [ { Trace.line = l; removed_by = None; selected = true } ]

(* The selection axioms 6 and 7 share: drop the candidates that crease no
   face (a line on the abstract plane has nothing to fold), keep a single
   survivor, and among several take the one whose landing of [moved] lies
   nearest the `toward` point, by exact squared distance. A point as near to
   two landings selects nothing (spec/MODEL.md, def-selection). Records every
   candidate with the rule that removed it before failing or returning. *)
let pick (ctx : Ctx.ctx) ~trace span t ~conics ~(moved : Geom.point) ~x_opt
    ~base ~none_msg ~ambig_msg (cands : Geom.line list) : axis_result =
  let cuts = List.map (fun c -> (c, Fold_state.line_cuts_paper !(ctx.state) c)) cands in
  let kept = List.filter_map (fun (c, ok) -> if ok then Some c else None) cuts in
  let xt = Option.map (Resolve.table_of ctx) x_opt in
  let dist2 (xt : Geom.point) (c : Geom.line) =
    let im = Geom.reflect_point c moved in
    let ex = Num.sub im.Geom.x xt.Geom.x and ey = Num.sub im.Geom.y xt.Geom.y in
    Num.add (Num.mul ex ex) (Num.mul ey ey)
  in
  (* the candidates whose landing lies nearest the `toward` point; several
     when the point is as near to one landing as to another *)
  let nearest =
    match (kept, xt) with
    | _ :: _ :: _, Some xt ->
        let d = List.map (fun c -> (dist2 xt c, c)) kept in
        let m =
          List.fold_left (fun m (x, _) -> if Num.compare x m < 0 then x else m) (fst (List.hd d)) d
        in
        List.filter_map (fun (x, c) -> if Num.compare x m = 0 then Some c else None) d
    | _ -> kept
  in
  let chosen = match nearest with [ c ] -> Some c | _ -> None in
  if trace then
    Ctx.record_trace ctx ~axiom:t ~toward:xt ~conics
      (List.map
         (fun (c, ok) ->
           let selected = match chosen with Some s -> s == c | None -> false in
           let removed_by =
             if not ok then Some Trace.By_paper
             else if not (List.memq c nearest) then Some Trace.By_toward
             else None
           in
           { Trace.line = c; removed_by; selected })
         cuts);
  match (kept, chosen, x_opt) with
  | [], _, _ -> Error.fail span none_msg
  | [ _ ], Some c, _ -> Axis (c, t, base)
  | _, Some c, Some xo -> Axis (c, t, base @ [ Resolve.pstr xo ])
  | _, None, Some xo ->
      Error.fail ~hint:"name a toward point nearer to one of them" span
        (Printf.sprintf
           "toward %s lies as near to where one fold moves the point as to \
            where another does"
           (Resolve.pstr xo))
  | _ -> Error.fail ~hint:"add 'toward .x'" span ambig_msg

let axis_of ?(trace = true) (ctx : Ctx.ctx) (span : Error.span) (c : Ast.construction) :
    classified * axis_result =
  let cl = classify c in
  let t = tag cl in
  let res =
  match cl with
  | Ax1 (p, q) ->
      let pp = Resolve.table_of ctx p and qq = Resolve.table_of ctx q in
      if Geom.point_equal pp qq then
        Error.fail span
          (Printf.sprintf
             "%s and %s are at the same place, so there is no line through \
              them"
             (Resolve.pstr p) (Resolve.pstr q));
      Axis (Geom.line_through pp qq, t, [ Resolve.pstr p; Resolve.pstr q ])
  | Ax2 (p, q) ->
      let pp = Resolve.table_of ctx p and qq = Resolve.table_of ctx q in
      if Geom.point_equal pp qq then
        Error.fail span
          (Printf.sprintf "%s and %s are already at the same place" (Resolve.pstr p)
             (Resolve.pstr q));
      Axis (Geom.perpendicular_bisector pp qq, t, [ Resolve.pstr p; Resolve.pstr q ])
  | Ax3 (p, l) ->
      Axis
        ( Geom.perpendicular_through (Resolve.resolve_line ctx l) (Resolve.table_of ctx p),
          t,
          [ Resolve.pstr p; Resolve.lstr l ] )
  | Ax4 (p, l1, l2) -> (
      let pp = Resolve.table_of ctx p and ll1 = Resolve.resolve_line ctx l1 and ll2 = Resolve.resolve_line ctx l2 in
      match Geom.project_crease pp ll1 ll2 with
      | None ->
          Error.fail span
            (Printf.sprintf "map %s onto %s perp %s: lines are parallel, no fold exists"
               (Resolve.pstr p) (Resolve.lstr l1) (Resolve.lstr l2))
      | Some crease -> Axis (crease, t, [ Resolve.pstr p; Resolve.lstr l1; Resolve.lstr l2 ]))
  | Ax5 (l1, l2, p_opt) -> (
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
          Axis (Geom.parallel_midline la lb, t, [ l1_str; l2_str ])
      | Some cands ->
          (* intersecting: defer bisector choice to the fold state. `toward`
             names where the fold goes, so a point on l1 is meaningless (E1);
             a point on l2 is fine. *)
          let toward = Option.map (Resolve.table_of ctx) p_opt in
          let toward_str = Option.map Resolve.pstr p_opt in
          (match toward with
          | Some x when Geom.side_of_line la x = 0 ->
              Error.fail
                ~hint:(Printf.sprintf "pick a point off %s" l1_str)
                span
                (Printf.sprintf
                   "`toward %s` lies on %s; `toward` names where the fold goes"
                   (Option.get toward_str) l1_str)
          | _ -> ());
          let sources =
            [ l1_str; l2_str ]
            @ (match toward_str with Some s -> [ s ] | None -> [])
          in
          Ax5
            {
              la;
              cands;
              toward;
              l1_op = l1;
              l1_str;
              l2_str;
              toward_str;
              sources;
            })
  | Ax6 (p, d, p', x_opt) -> (
      let pp = Resolve.table_of ctx p and dd = Resolve.resolve_line ctx d and pp' = Resolve.table_of ctx p' in
      if Geom.point_equal pp pp' then
        Error.fail span
          (Printf.sprintf
             "map %s onto %s through %s: %s and %s are the same point, so no \
              fold exists"
             (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr p') (Resolve.pstr p) (Resolve.pstr p'));
      let base = [ Resolve.pstr p; Resolve.lstr d; Resolve.pstr p' ] in
      let conics = [ { Trace.focus = pp; directrix = dd } ] in
      match Geom.beloch_creases pp dd pp' with
      | [] ->
          if trace then
            Ctx.record_trace ctx ~axiom:t
              ~toward:(Option.map (Resolve.table_of ctx) x_opt) ~conics [];
          Error.fail span
            (Printf.sprintf "cannot fold %s onto %s through %s: out of reach"
               (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr p'))
      | candidates ->
          pick ctx ~trace span t ~conics ~moved:pp ~x_opt ~base
            ~none_msg:
              (Printf.sprintf
                 "map %s onto %s through %s: no crease lands on the paper — \
                  no fold to make"
                 (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr p'))
            ~ambig_msg:
              (Printf.sprintf
                 "two folds place %s onto %s through %s, both landing on the \
                  paper"
                 (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr p'))
            candidates)
  | Ax7 (p, d, q, e, x_opt) -> (
      let pp = Resolve.table_of ctx p and dd = Resolve.resolve_line ctx d in
      let qq = Resolve.table_of ctx q and ee = Resolve.resolve_line ctx e in
      let base = [ Resolve.pstr p; Resolve.lstr d; Resolve.pstr q; Resolve.lstr e ] in
      (* degeneracy guards *)
      if Geom.side_of_line ee qq = 0 then
        Error.fail
          ~hint:
            (Printf.sprintf
               "use axiom 6 (fold %s onto %s through a point) then axiom 4"
               (Resolve.pstr p) (Resolve.lstr d))
          span
          (Printf.sprintf "map %s onto %s and %s onto %s: %s already lies on %s"
             (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr q) (Resolve.lstr e) (Resolve.pstr q) (Resolve.lstr e));
      if Geom.parallel dd ee then
        Error.fail span
          (Printf.sprintf
             "map %s onto %s and %s onto %s: %s and %s are parallel — \
              degenerate, no general cubic fold"
             (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr q) (Resolve.lstr e) (Resolve.lstr d) (Resolve.lstr e));
      let conics =
        [ { Trace.focus = pp; directrix = dd }; { Trace.focus = qq; directrix = ee } ]
      in
      match Geom.beloch7_creases pp dd qq ee with
      | [] ->
          if trace then
            Ctx.record_trace ctx ~axiom:t
              ~toward:(Option.map (Resolve.table_of ctx) x_opt) ~conics [];
          Error.fail span
            (Printf.sprintf
               "cannot fold %s onto %s and %s onto %s: out of reach (no \
                common tangent)"
               (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr q) (Resolve.lstr e))
      | candidates ->
          (* the landing of the first point p decides among several *)
          pick ctx ~trace span t ~conics ~moved:pp ~x_opt ~base
            ~none_msg:
              (Printf.sprintf
                 "map %s onto %s and %s onto %s: no crease lands on the \
                  paper — no fold to make"
                 (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr q) (Resolve.lstr e))
            ~ambig_msg:
              (Printf.sprintf
                 "%d folds place %s onto %s and %s onto %s, all landing on the \
                  paper"
                 (List.length
                    (List.filter (Fold_state.line_cuts_paper !(ctx.state)) candidates))
                 (Resolve.pstr p) (Resolve.lstr d) (Resolve.pstr q) (Resolve.lstr e))
            candidates)
  in
  (match (cl, res) with
  | (Ax1 _ | Ax2 _ | Ax3 _ | Ax4 _ | Ax5 _), Axis (l, _, _) when trace ->
      Ctx.record_trace ctx ~axiom:t ~toward:None (only l)
  | _ -> ());
  (cl, res)

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
    "map %s onto %s is ambiguous: both bisectors land on the paper"
    p.l1_str p.l2_str

let e2_hint = "add `toward .p` to pick the direction"

let e3 (p : ax5_pending) =
  Printf.sprintf
    "map %s onto %s: neither bisector lands on the paper — no fold to make"
    p.l1_str p.l2_str

let e5_head (p : ax5_pending) (x : string) =
  Printf.sprintf
    "map %s onto %s toward %s is ambiguous: %s straddles the crossing, so \
     both bisectors move material toward %s"
    p.l1_str p.l2_str x p.l1_str x

(* Record both bisectors: those in [kept] survived the selection, the others
   were removed by [removal]; [chosen] is the one the construction yields. *)
let trace5 (ctx : Ctx.ctx) ~trace (p : ax5_pending) ~removal ~kept chosen =
  if trace then
    let b1, b2 = p.cands in
    Ctx.record_trace ctx ~axiom:"axiom5" ~toward:p.toward
      (List.map
         (fun b ->
           { Trace.line = b;
             removed_by = (if List.memq b kept then None else Some removal);
             selected = (match chosen with Some c -> c == b | None -> false) })
         [ b1; b2 ])

let select_axiom5_bind ?(trace = true) (ctx : Ctx.ctx) (span : Error.span)
    (p : ax5_pending) : Geom.line =
  let b1, b2 = p.cands in
  match p.toward with
  | None -> (
      let kept = ax5_filter ctx p in
      let one = match kept with [ b ] -> Some b | _ -> None in
      trace5 ctx ~trace p ~removal:Trace.By_paper ~kept one;
      match kept with
      | [ b ] -> b
      | [ _; _ ] -> Error.fail ~hint:e2_hint span (e2 p)
      | _ -> Error.fail span (e3 p))
  | Some x ->
      let xside = Geom.side_of_line p.la x in
      let mat = ax5_material ctx p in
      let xs = Option.get p.toward_str in
      let viable_c b = viable ~la:p.la ~xside mat b 1 || viable ~la:p.la ~xside mat b (-1) in
      let kept = List.filter viable_c [ b1; b2 ] in
      let one = match kept with [ b ] -> Some b | _ -> None in
      trace5 ctx ~trace p ~removal:Trace.By_toward ~kept one;
      (match kept with
      | [ b ] -> b
      | [] ->
          Error.fail span
            (Printf.sprintf "no fold of %s onto %s moves its material toward %s"
               p.l1_str p.l2_str xs)
      | _ ->
          Error.fail
            ~hint:
              (Printf.sprintf "select the swinging segment of %s with `&`"
                 p.l1_str)
            span (e5_head p xs))

(* returns the chosen axis + an optional move-side override (Some when the
   direction is derived, not read off an explicit `moving`) *)
let select_axiom5_fold (ctx : Ctx.ctx) (span : Error.span) (p : ax5_pending)
    ~(fs : Ast.fold_spec) : Geom.line * int option =
  let b1, b2 = p.cands in
  let trace5 = trace5 ctx ~trace:true p in
  match p.toward with
  | None -> (
      let kept = ax5_filter ctx p in
      let b =
        match kept with
        | [ b ] -> trace5 ~removal:Trace.By_paper ~kept (Some b); b
        | [ _; _ ] ->
            trace5 ~removal:Trace.By_paper ~kept None;
            Error.fail ~hint:e2_hint span (e2 p)
        | _ ->
            trace5 ~removal:Trace.By_paper ~kept None;
            Error.fail span (e3 p)
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
              Error.fail ~hint:"add `moving` to pick the swinging flap" span
                (Printf.sprintf "%s straddles the fold line" p.l1_str)
          | false, false ->
              Error.fail span
                (Printf.sprintf "%s has no material on the paper to fold"
                   p.l1_str)))
  | Some x ->
      let xside = Geom.side_of_line p.la x in
      let mat = ax5_material ctx p in
      let xs = Option.get p.toward_str in
      if mat = [] then begin
        trace5 ~removal:Trace.By_toward ~kept:[ b1; b2 ] None;
        Error.fail span
          (Printf.sprintf "%s has no material on the paper to fold" p.l1_str)
      end;
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
          let kept = List.map fst viables in
          (match viables with
          | [ (b, s) ] -> trace5 ~removal:Trace.By_toward ~kept (Some b); (b, Some s)
          | [] ->
              trace5 ~removal:Trace.By_toward ~kept None;
              Error.fail span
                (Printf.sprintf
                   "no fold of %s onto %s moves its material toward %s"
                   p.l1_str p.l2_str xs)
          | _ ->
              trace5 ~removal:Trace.By_toward ~kept None;
              Error.fail ~hint:"add `moving` to pick the swinging flap" span
                (e5_head p xs))
      | Some fa ->
          (* the anchor's side of each candidate names the swinging half; a
             candidate is viable iff that half moves toward x. On-axis /
             straddling anchors just reject the candidate. *)
          let viable_c b =
            match Resolve.side_of_flap_arg_res ctx b fa span with
            | Ok s -> viable ~la:p.la ~xside mat b s
            | Error _ -> false
          in
          let kept = List.filter viable_c [ b1; b2 ] in
          (match kept with
          | [ b ] -> trace5 ~removal:Trace.By_moving ~kept (Some b); (b, None) (* side resolved normally via the anchor *)
          | [] ->
              trace5 ~removal:Trace.By_moving ~kept None;
              Error.fail span
                (Printf.sprintf "no fold of %s onto %s moves %s toward %s"
                   p.l1_str p.l2_str (Resolve.fstr fa) xs)
          | _ ->
              trace5 ~removal:Trace.By_moving ~kept None;
              Error.fail ~hint:"anchor with a point in only one flap" span
                (Printf.sprintf
                   "map %s onto %s toward %s is ambiguous even with `moving \
                    %s`: it lies in both swinging flaps"
                   p.l1_str p.l2_str xs (Resolve.fstr fa))))
