(** Axiom construction: the seven Huzita-Justin axioms and the selection
    among their candidates (ADR 0031). Every stateful function takes
    [(ctx : Ctx.ctx)] as its first parameter. *)

open Ctx

(* ---- recognition: an alignment set as one of the seven axioms ---- *)

type classified =
  | Ax1 of Ast.point_operand * Ast.point_operand
  | Ax2 of Ast.point_operand * Ast.point_operand
  | Ax3 of Ast.point_operand * Ast.line_operand
  | Ax4 of Ast.point_operand * Ast.line_operand * Ast.line_operand
  | Ax5 of Ast.line_operand * Ast.line_operand
  | Ax6 of Ast.point_operand * Ast.line_operand * Ast.point_operand
  | Ax7 of
      Ast.point_operand * Ast.line_operand * Ast.point_operand * Ast.line_operand

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
  let through = ref [] and perp = ref [] in
  List.iter
    (fun (a : Ast.alignment) ->
      match a.Ast.al_kind with
      | Ast.AlOnto (Ast.AoPoint p, Ast.AoPoint q) -> onto_pp := (p, q) :: !onto_pp
      | Ast.AlOnto (Ast.AoPoint p, Ast.AoLine l) -> onto_pl := (p, l) :: !onto_pl
      | Ast.AlOnto (Ast.AoLine l, Ast.AoLine m) -> onto_ll := (l, m) :: !onto_ll
      (* an incidence: a line onto a point is the point onto the line *)
      | Ast.AlOnto (Ast.AoLine l, Ast.AoPoint p) -> onto_pl := (p, l) :: !onto_pl
      | Ast.AlThrough p -> through := p :: !through
      | Ast.AlPerp l -> perp := l :: !perp)
    c.Ast.c_alignments;
  let onto_pp = List.rev !onto_pp
  and onto_pl = List.rev !onto_pl
  and onto_ll = List.rev !onto_ll
  and through = List.rev !through
  and perp = List.rev !perp in
  let one_line () =
    (* heading selects among the candidates of axioms 5, 6 and 7; the other
       four determine one line *)
    if c.Ast.c_heading <> None then
      Error.fail ~hint:"drop heading" c.Ast.c_span
        "this construction determines one line"
  in
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
    | [], [], [ (l, m) ], [], [] -> Ax5 (l, m)
    | [], [ (p, d) ], [], [ q ], [] -> Ax6 (p, d, q)
    | [], [ (p, d); (q, e) ], [], [], [] -> Ax7 (p, d, q, e)
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
  | Ax2 (p, _) | Ax6 (p, _, _) | Ax7 (p, _, _, _) -> Some p
  | Ax1 _ | Ax3 _ | Ax4 _ | Ax5 _ -> None

(* ---- the objects of a construction, and its candidates ---- *)

(* An object of an `onto` alignment on the table: a point, or a line with
   its material as table segments. *)
type obj =
  | Obj_point of Geom.point * string
  | Obj_line of Geom.line * Geom.segment list * string

type pending = {
  tag : string;
  what : string;  (* the construction in prose, for messages *)
  cands : Geom.line list;
  single : bool;
      (* one line by construction (axioms 1 to 4, a parallel axiom 5): no
         paper filter and no `heading`, only the side items *)
  aligns : (obj * obj) list;  (* the `onto` alignments, in source order *)
  heading : (Geom.line * string) option;
  base : string list;  (* provenance sources *)
  conics : Trace.conic list;
}

(* The material of a line operand on the table: the segments of a crease,
   or the chord of the paper under a line that is no crease. *)
let line_material (ctx : Ctx.ctx) (lo : Ast.line_operand) (la : Geom.line) :
    Geom.segment list =
  let of_segments segs =
    List.map
      (fun (s : Fold_state.crease_segment) -> (s.Fold_state.ta, s.Fold_state.tb))
      segs
  in
  match lo with
  | Ast.LNamed cr -> (
      match lookup_crease ctx cr with
      | Material (cid, _) -> of_segments (Fold_state.crease_segments !(ctx.state) cid)
      | Bundle _ -> of_segments (snd (Resolve.bundle_segments ctx (Ast.LNamed cr)))
      | Edge _ | Mark _ | Frozen _ -> Fold_state.line_material_segments !(ctx.state) la)
  | Ast.LSelect _ -> Fold_state.line_material_segments !(ctx.state) la
  | (Ast.LFilter _ | Ast.LUnion _) as b -> of_segments (snd (Resolve.bundle_segments ctx b))

let axis_of ?(trace = true) (ctx : Ctx.ctx) (span : Error.span) (c : Ast.construction) :
    classified * pending =
  let cl = classify c in
  let t = tag cl in
  let p = Resolve.pstr and l = Resolve.lstr in
  let pt = Resolve.table_of ctx and ln = Resolve.resolve_line ctx in
  let obj_l lo = let ll = ln lo in Obj_line (ll, line_material ctx lo ll, l lo) in
  let one ?(aligns = []) what line base =
    { tag = t; what; cands = [ line ]; single = true; aligns;
      heading = None; base; conics = [] }
  in
  let pend =
    match cl with
    | Ax1 (a, b) ->
        let aa = pt a and bb = pt b in
        if Geom.point_equal aa bb then
          Error.fail span
            (Printf.sprintf
               "%s and %s are at the same place, so there is no line through \
                them"
               (p a) (p b));
        one (Printf.sprintf "through %s %s" (p a) (p b)) (Geom.line_through aa bb)
          [ p a; p b ]
    | Ax2 (a, b) ->
        let aa = pt a and bb = pt b in
        if Geom.point_equal aa bb then
          Error.fail span
            (Printf.sprintf "%s and %s are already at the same place" (p a) (p b));
        one ~aligns:[ (Obj_point (aa, p a), Obj_point (bb, p b)) ]
          (Printf.sprintf "map %s onto %s" (p a) (p b))
          (Geom.perpendicular_bisector aa bb) [ p a; p b ]
    | Ax3 (a, m) ->
        one (Printf.sprintf "perp %s through %s" (l m) (p a))
          (Geom.perpendicular_through (ln m) (pt a)) [ p a; l m ]
    | Ax4 (a, l1, l2) -> (
        let aa = pt a in
        match Geom.project_crease aa (ln l1) (ln l2) with
        | None ->
            Error.fail span
              (Printf.sprintf "map %s onto %s perp %s: lines are parallel, no fold exists"
                 (p a) (l l1) (l l2))
        | Some crease ->
            one ~aligns:[ (Obj_point (aa, p a), obj_l l1) ]
              (Printf.sprintf "map %s onto %s perp %s" (p a) (l l1) (l l2))
              crease [ p a; l l1; l l2 ])
    | Ax5 (l1, l2) -> (
        let la = ln l1 and lb = ln l2 in
        let what = Printf.sprintf "map %s onto %s" (l l1) (l l2) in
        let aligns = [ (obj_l l1, obj_l l2) ] in
        let base = [ l l1; l l2 ] in
        match Geom.angle_bisectors la lb with
        | None ->
            let k =
              if Num.sign la.Geom.a <> 0 then Num.div lb.Geom.a la.Geom.a
              else Num.div lb.Geom.b la.Geom.b
            in
            if Num.equal lb.Geom.c (Num.mul k la.Geom.c) then
              Error.fail span "lines are identical";
            one ~aligns what (Geom.parallel_midline la lb) base
        | Some (b1, b2) ->
            { tag = t; what; cands = [ b1; b2 ]; single = false; aligns;
              heading = None; base; conics = [] })
    | Ax6 (a, d, q) ->
        let aa = pt a and dd = ln d and qq = pt q in
        if Geom.point_equal aa qq then
          Error.fail span
            (Printf.sprintf
               "map %s onto %s through %s: %s and %s are the same point, so no \
                fold exists"
               (p a) (l d) (p q) (p a) (p q));
        let conics = [ { Trace.focus = aa; directrix = dd } ] in
        let what = Printf.sprintf "map %s onto %s through %s" (p a) (l d) (p q) in
        let cands = Geom.beloch_creases aa dd qq in
        if cands = [] then begin
          if trace then Ctx.record_trace ctx ~axiom:t ~toward:None ~conics [];
          Error.fail span
            (Printf.sprintf "cannot fold %s onto %s through %s: out of reach"
               (p a) (l d) (p q))
        end;
        { tag = t; what; cands; single = false;
          aligns = [ (Obj_point (aa, p a), obj_l d) ]; heading = None; base = [ p a; l d; p q ]; conics }
    | Ax7 (a, d, q, e) ->
        let aa = pt a and dd = ln d and qq = pt q and ee = ln e in
        let what =
          Printf.sprintf "map %s onto %s and %s onto %s" (p a) (l d) (p q) (l e)
        in
        if Geom.side_of_line ee qq = 0 then
          Error.fail
            ~hint:
              (Printf.sprintf
                 "use axiom 6 (fold %s onto %s through a point) then axiom 4"
                 (p a) (l d))
            span
            (Printf.sprintf "%s: %s already lies on %s" what (p q) (l e));
        if Geom.parallel dd ee then
          Error.fail span
            (Printf.sprintf
               "%s: %s and %s are parallel, so the cubic degenerates and no fold exists"
               what (l d) (l e));
        let conics =
          [ { Trace.focus = aa; directrix = dd }; { Trace.focus = qq; directrix = ee } ]
        in
        let cands = Geom.beloch7_creases aa dd qq ee in
        if cands = [] then begin
          if trace then Ctx.record_trace ctx ~axiom:t ~toward:None ~conics [];
          Error.fail span
            (Printf.sprintf
               "cannot fold %s onto %s and %s onto %s: out of reach (no common \
                tangent)"
               (p a) (l d) (p q) (l e))
        end;
        { tag = t; what; cands; single = false;
          aligns = [ (Obj_point (aa, p a), obj_l d); (Obj_point (qq, p q), obj_l e) ];
          heading = None;
          base = [ p a; l d; p q; l e ]; conics }
  in
  (* the objects in the order the program writes them: a line onto a point
     keeps the line first, which is what the default side reads *)
  let written_flipped =
    List.filter_map
      (fun (a : Ast.alignment) ->
        match a.Ast.al_kind with
        | Ast.AlOnto (Ast.AoLine _, Ast.AoPoint _) -> Some true
        | Ast.AlOnto (Ast.AoPoint _, Ast.AoLine _) -> Some false
        | _ -> None)
      c.Ast.c_alignments
  in
  let aligns =
    match cl with
    | Ax4 _ | Ax6 _ | Ax7 _ ->
        List.mapi
          (fun i (x, y) -> if List.nth_opt written_flipped i = Some true then (y, x) else (x, y))
          pend.aligns
    | Ax1 _ | Ax2 _ | Ax3 _ | Ax5 _ -> pend.aligns
  in
  let heading = Option.map (fun lo -> (ln lo, l lo)) c.Ast.c_heading in
  (cl, { pend with heading; aligns })


(* ---- exact distances on the table ---- *)

let dist2 (u : Geom.point) (v : Geom.point) : Num.t =
  let dx = Num.sub u.Geom.x v.Geom.x and dy = Num.sub u.Geom.y v.Geom.y in
  Num.add (Num.mul dx dx) (Num.mul dy dy)

let num_min (xs : Num.t list) : Num.t =
  List.fold_left (fun m x -> if Num.compare x m < 0 then x else m) (List.hd xs) xs

(* the squared distance from a point to a segment, which may be a point *)
let dist2_point_segment (r : Geom.point) ((a, b) : Geom.segment) : Num.t =
  if Geom.point_equal a b then dist2 r a
  else
    let t = Geom.seg_param (a, b) r in
    if Num.sign t <= 0 then dist2 r a
    else if Num.compare t Num.one >= 0 then dist2 r b
    else
      dist2 r
        { Geom.x = Num.add a.Geom.x (Num.mul t (Num.sub b.Geom.x a.Geom.x));
          y = Num.add a.Geom.y (Num.mul t (Num.sub b.Geom.y a.Geom.y)) }

(* Two segments that cross share a point; collinear ones never count as
   crossing here, and the endpoint distances cover their overlap. *)
let segments_cross ((a, b) : Geom.segment) ((c, d) : Geom.segment) : bool =
  (not (Geom.point_equal a b || Geom.point_equal c d))
  &&
  let l1 = Geom.line_through a b and l2 = Geom.line_through c d in
  let sc = Geom.side_of_line l1 c and sd = Geom.side_of_line l1 d in
  let sa = Geom.side_of_line l2 a and sb = Geom.side_of_line l2 b in
  (sc <> 0 || sd <> 0) && sc * sd <= 0 && sa * sb <= 0

let dist2_segments (s : Geom.segment) (u : Geom.segment) : Num.t =
  if segments_cross s u then Num.zero
  else
    let a, b = s and c, d = u in
    num_min
      [ dist2_point_segment a u; dist2_point_segment b u;
        dist2_point_segment c s; dist2_point_segment d s ]

(* the squared distance between two sets of segments, both non-empty *)
let dist2_sets (xs : Geom.segment list) (ys : Geom.segment list) : Num.t =
  num_min (List.concat_map (fun x -> List.map (dist2_segments x) ys) xs)

(* ---- the selection (ADR 0031) ---- *)

(* what a `toward` item names, on the table *)
type toward_obj = { t_segs : Geom.segment list; t_point : Geom.point option; t_str : string }

let toward_obj (ctx : Ctx.ctx) (t : Ast.toward) : toward_obj =
  match t with
  | Ast.TowardPoint po ->
      let x = Resolve.table_of ctx po in
      { t_segs = [ (x, x) ]; t_point = Some x; t_str = Resolve.pstr po }
  | Ast.TowardLine lo ->
      { t_segs = line_material ctx lo (Resolve.resolve_line ctx lo);
        t_point = None; t_str = Resolve.lstr lo }

(* The side of [c] that a set of segments lies on; none where they lie on
   both sides or only on [c]. *)
let side_of_segs (c : Geom.line) (segs : Geom.segment list) : int option =
  let sides =
    List.concat_map (fun (u, v) -> [ Geom.side_of_line c u; Geom.side_of_line c v ]) segs
  in
  match (List.mem 1 sides, List.mem (-1) sides) with
  | true, false -> Some 1
  | false, true -> Some (-1)
  | _ -> None

(* The side of [c] a `toward` names: the side that holds the point, or the
   side the line's material lies on. A point on [c], or a line [c] crosses,
   names no side of it. *)
let toward_side (c : Geom.line) (t : toward_obj) : int option = side_of_segs c t.t_segs

(* The side of [c] a `moving` names: the side of its first anchor point off
   [c], which is the side the fold then moves, or the side of the material of
   a line; none where every point lies on [c] or the line lies on both sides
   or on [c]. *)
let moving_side (ctx : Ctx.ctx) (c : Geom.line) (fa : Ast.flap_arg)
    : int option =
  let of_points pts =
    List.find_map
      (fun po ->
        match Geom.side_of_line c (Resolve.table_of ctx po) with 0 -> None | s -> Some s)
      pts
  in
  match fa with
  | Ast.FlapPoint po -> of_points [ po ]
  | Ast.FlapSpec (Ast.FByPoints (pts, _)) -> of_points pts
  | Ast.FlapLine lo ->
      (* a flap operand is crease-sorted: a line bound by `=` is refused here *)
      (match lo with
      | Ast.LNamed cr -> ignore (Resolve.crease_of ctx cr ~slot:"a flap operand" cr.Ast.cspan)
      | _ -> ());
      side_of_segs c (line_material ctx lo (Resolve.resolve_line ctx lo))

(* a point of the material strictly on side [s] of [c] *)
let on_side (c : Geom.line) (s : int) (segs : Geom.segment list) : bool =
  List.exists (fun (u, v) -> Geom.side_of_line c u = s || Geom.side_of_line c v = s) segs

(* A fold along [c] with folding side [s] makes [x] meet [y] by moving [x]:
   a point on that side, or a line's material there. A line that carries
   the point [y] has to have paper at the one place that lands on it. *)
let carries (c : Geom.line) (s : int) (x : obj) (y : obj) : bool =
  match (x, y) with
  | Obj_point (p, _), _ -> Geom.side_of_line c p = s
  | Obj_line (_, segs, _), Obj_point (q, _) ->
      let r = Geom.reflect_point c q in
      Geom.side_of_line c r = s && List.exists (fun sg -> Geom.on_segment sg r) segs
  | Obj_line (_, segs, _), Obj_line _ -> on_side c s segs

(* a point on [c] and on its target line meets it without moving *)
let already (c : Geom.line) (x : obj) (y : obj) : bool =
  match (x, y) with
  | Obj_point (p, _), Obj_line (l, _, _) | Obj_line (l, _, _), Obj_point (p, _) ->
      Geom.side_of_line c p = 0 && Geom.side_of_line l p = 0
  | _ -> false

(* A fold along [c] with folding side [s] carries out every alignment: in
   each, one object moves onto the other, or they meet already. *)
let performs (c : Geom.line) (s : int) (aligns : (obj * obj) list) : bool =
  List.for_all (fun (x, y) -> carries c s x y || carries c s y x || already c x y) aligns

(* What the fold along [c] with folding side [s] lands of the object [o]:
   a point on that side, and the part of a line on it, reflected. The part
   of a line on the other side stays, and a point on [c] stays where it is. *)
let landed_of (c : Geom.line) (s : int) (o : obj) : Geom.segment list =
  let r = Geom.reflect_point c in
  match o with
  | Obj_point (p, _) -> if Geom.side_of_line c p = s then [ (r p, r p) ] else []
  | Obj_line (_, segs, _) ->
      List.filter_map
        (fun (u, v) ->
          let su = Geom.side_of_line c u and sv = Geom.side_of_line c v in
          if su <> s && sv <> s then (if su = 0 && sv = 0 then Some (u, v) else None)
          else if su <> -s && sv <> -s then Some (r u, r v)
          else
            (* one end on each side: cut where the segment crosses [c] *)
            match Geom.intersection c (Geom.line_through u v) with
            | Some x -> Some (r (if su = s then u else v), r x)
            | None -> None)
        segs

(* the square of the cosine of the angle between two lines *)
let cos2 (l1 : Geom.line) (l2 : Geom.line) : Num.t =
  let dot = Num.add (Num.mul l1.Geom.a l2.Geom.a) (Num.mul l1.Geom.b l2.Geom.b) in
  let n (l : Geom.line) = Num.add (Num.mul l.Geom.a l.Geom.a) (Num.mul l.Geom.b l.Geom.b) in
  Num.div (Num.mul dot dot) (Num.mul (n l1) (n l2))

(* the candidates of [xs] with the least [key]; several on a tie *)
let least (key : Geom.line -> Num.t) (xs : Geom.line list) : Geom.line list =
  let ks = List.map (fun c -> (key c, c)) xs in
  let m = num_min (List.map fst ks) in
  List.filter_map (fun (k, c) -> if Num.compare k m = 0 then Some c else None) ks

let obj_str (o : obj) : string = match o with Obj_point (_, s) | Obj_line (_, _, s) -> s

(* every object of the alignments, once *)
let objects (p : pending) : obj list =
  List.fold_left
    (fun acc o -> if List.memq o acc then acc else acc @ [ o ])
    [] (List.concat_map (fun (x, y) -> [ x; y ]) p.aligns)

(* The objects an `(x toward …)` names: those at the place of [x]. *)
let subject_objs (ctx : Ctx.ctx) (span : Error.span) (p : pending) (x : Ast.align_object)
    : obj list * string =
  let matching, xs =
    match x with
    | Ast.AoPoint po ->
        let q = Resolve.table_of ctx po in
        ( List.filter
            (function Obj_point (r, _) -> Geom.point_equal q r | Obj_line _ -> false)
            (objects p),
          Resolve.pstr po )
    | Ast.AoLine lo ->
        let m = Resolve.resolve_line ctx lo in
        ( List.filter
            (function Obj_line (l, _, _) -> Geom.same_line m l | Obj_point _ -> false)
            (objects p),
          Resolve.lstr lo )
  in
  if matching = [] then
    Error.fail
      ~hint:
        (Printf.sprintf "name one of %s"
           (String.concat ", " (List.map obj_str (objects p))))
      span
      (Printf.sprintf "%s is none of the objects of %s" xs p.what);
  (matching, xs)

type chosen = {
  line : Geom.line;
  fold_side : int option;
      (* the side that folds over, when the side items, the geometry or the
         first object fix it; [None] leaves it to the anchor *)
  sources : string list;
}

let select ?(trace = true) (ctx : Ctx.ctx) (span : Error.span) (p : pending)
    ~(fold : bool) (sides : Ast.sides) : chosen =
  let removed = ref [] in
  let remove why cs = List.iter (fun c -> removed := (c, why) :: !removed) cs in
  let t = Option.map (fun (ti : Ast.toward_item) -> toward_obj ctx ti.Ast.target) sides.Ast.s_toward in
  let subject =
    match sides.Ast.s_toward with
    | Some { Ast.subject = Some x; _ } -> Some (subject_objs ctx span p x)
    | _ -> None
  in
  let moving = sides.Ast.s_moving in
  let finish chosen =
    if trace then
      Ctx.record_trace ctx ~axiom:p.tag
        ~toward:(Option.bind t (fun t -> t.t_point))
        ~conics:p.conics
        (List.map
           (fun c ->
             let removed_by = List.assq_opt c !removed in
             { Trace.line = c; removed_by;
               selected = (match chosen with Some s -> s == c | None -> false);
               landing =
                 (match p.aligns with
                 | (Obj_point (q, _), _) :: _ when removed_by <> Some Trace.By_paper ->
                     Some (Geom.reflect_point c q)
                 | _ -> None) })
           p.cands)
  in
  let fail ?hint msg =
    finish None;
    Error.fail ?hint span msg
  in
  if p.single && p.heading <> None then
    fail ~hint:"drop heading" "this construction determines one line";
  (* 1. the paper: a line off the paper is no fold *)
  let kept =
    if p.single then p.cands
    else
      let on, off =
        List.partition (Fold_state.line_cuts_paper !(ctx.state)) p.cands
      in
      remove Trace.By_paper off;
      on
  in
  if kept = [] then
    fail
      (Printf.sprintf "%s: no crease lands on the paper, so there is no fold to make"
         p.what);
  (* 2. heading: the direction of the crease; a tie passes on to toward *)
  let kept =
    match p.heading with
    | Some (la, _) when not p.single ->
        let near = least (fun c -> Num.neg (cos2 c la)) kept in
        remove Trace.By_heading (List.filter (fun c -> not (List.memq c near)) kept);
        near
    | _ -> kept
  in
  (* 3. the folding side, and whether the fold with it carries out every
     alignment. [conflict] is set where `moving` names the side `toward`
     keeps. *)
  let conflict = ref false in
  (* the candidates for which `moving` names no side: its points lie on them *)
  let no_side = ref 0 in
  let first = match p.aligns with (x, _) :: _ -> Some x | [] -> None in
  let side_of c : (int option, Trace.removal) result =
    match (t, moving) with
    | Some t, mv -> (
        match toward_side c t with
        | None -> Error Trace.By_toward
        | Some s -> (
            match mv with
            | None -> Ok (Some (-s))
            | Some fa -> (
                match moving_side ctx c fa with
                | Some m when m = -s -> Ok (Some (-s))
                | Some _ -> conflict := true; Error Trace.By_moving
                | None -> incr no_side; Error Trace.By_moving)))
    | None, Some fa -> (
        match moving_side ctx c fa with
        | Some s -> Ok (Some s)
        | None -> incr no_side; Error Trace.By_moving)
    | None, None -> Ok None
  in
  (* with no side item, the side that alone carries the construction out,
     else the side of the first object (ADR 0031) *)
  let default_side c =
    match (performs c 1 p.aligns, performs c (-1) p.aligns) with
    | true, false -> Some (Some 1)
    | false, true -> Some (Some (-1))
    | false, false -> None
    | true, true -> (
        match first with
        | Some (Obj_point (q, _)) ->
            let s = Geom.side_of_line c q in
            Some (if s = 0 then None else Some s)
        | Some (Obj_line (_, segs, _)) -> Some (side_of_segs c segs)
        | None -> Some None)
  in
  let why_fail = match (t, moving) with
    | Some _, _ -> Trace.By_toward | None, Some _ -> Trace.By_moving | None, None -> Trace.By_moved
  in
  let subject_folds c s =
    match subject with
    | None -> true
    | Some (objs, _) -> List.exists (fun o -> landed_of c s o <> []) objs
  in
  let sided =
    List.filter_map
      (fun c ->
        match side_of c with
        | Error why -> remove why [ c ]; None
        | Ok None -> (
            match default_side c with
            | Some fs -> Some (c, fs)
            | None -> remove why_fail [ c ]; None)
        | Ok (Some s) when performs c s p.aligns && subject_folds c s -> Some (c, Some s)
        | Ok (Some _) -> remove why_fail [ c ]; None)
      kept
  in
  if sided = [] then
    fail
      ?hint:(if !conflict then Some "drop one of them" else None)
      (match (t, moving) with
      | _, Some fa when !no_side = List.length kept ->
          Printf.sprintf "moving %s names no side of the fold line of %s" (Resolve.fstr fa)
            p.what
      | Some t, Some fa when !conflict ->
          Printf.sprintf "toward %s and moving %s name the same side of the fold line"
            t.t_str (Resolve.fstr fa)
      | Some t, _ when p.single && toward_side (List.hd kept) t = None ->
          Printf.sprintf "toward %s names no side of the fold line of %s" t.t_str p.what
      | Some t, _ -> (
          match subject with
          | Some (_, xs) ->
              Printf.sprintf
                "no fold of %s keeps %s on the side that stays, folds %s over and \
                 carries out its alignments"
                p.what t.t_str xs
          | None ->
              Printf.sprintf
                "no fold of %s keeps %s on the side that stays and carries out its \
                 alignments"
                p.what t.t_str)
      | None, Some fa ->
          Printf.sprintf "no fold of %s moves %s and carries out its alignments" p.what
            (Resolve.fstr fa)
      | None, None ->
          Printf.sprintf "no fold of %s carries out all its alignments at once" p.what);
  (* 4. toward keeps the candidate that lands its material nearest it: what
     folds over, or only the named object's part of it *)
  let sided =
    match (sided, t) with
    | _ :: _ :: _, Some t ->
        let landing c s =
          let objs = match subject with Some (objs, _) -> objs | None -> objects p in
          List.concat_map (landed_of c s) objs
        in
        let d =
          List.filter_map
            (fun (c, s) ->
              match landing c (Option.get s) with
              | [] -> remove Trace.By_toward [ c ]; None
              | l -> Some ((c, s), dist2_sets l t.t_segs))
            sided
        in
        if d = [] then []
        else
          let m = num_min (List.map snd d) in
          List.filter_map
            (fun ((c, s), x) ->
              if Num.compare x m = 0 then Some (c, s)
              else (remove Trace.By_toward [ c ]; None))
            d
    | _ -> sided
  in
  let c, fold_side =
    match (sided, t) with
    | [ one ], _ -> one
    | _, Some t ->
        fail
          ~hint:
            (match (subject, first) with
            | None, Some x ->
                Printf.sprintf "name what goes toward %s, e.g. (%s toward %s)" t.t_str
                  (obj_str x) t.t_str
            | _ -> "name a toward nearer to one of them")
          (Printf.sprintf
             "toward %s lies as near to where one fold of %s lands its material as \
              to where another does"
             t.t_str p.what)
    | _, None ->
        fail
          ~hint:
            (if moving = None && p.heading = None then "add (toward .x) or a heading"
             else "add (toward .x)")
          (Printf.sprintf "%s is ambiguous: %d folds carry it out, all landing on the paper"
             p.what (List.length sided))
  in
  if fold && fold_side = None && t = None && moving = None
     && (match first with Some (Obj_line _) -> true | _ -> false)
  then
    fail ~hint:"add `moving` to pick the swinging flap"
      (Printf.sprintf "%s straddles the fold line"
         (match first with Some x -> obj_str x | None -> ""));
  finish (Some c);
  let decided = List.length p.cands > 1 in
  let sources =
    p.base
    @ (match p.heading with Some (_, s) when not p.single -> [ s ] | _ -> [])
    @ (match t with Some t when decided -> [ t.t_str ] | _ -> [])
  in
  { line = c; fold_side; sources }

(* The side items over an axis that is no construction: `toward` names the
   side that stays, and `moving`, when also given, has to name the other. *)
let fold_side_of_line (ctx : Ctx.ctx) (span : Error.span) (axis : Geom.line)
    (sides : Ast.sides) : int option =
  match sides.Ast.s_toward with
  | None -> None
  | Some { Ast.subject = Some _; _ } ->
      Error.fail ~hint:"write (toward .p)" span
        "an axis that is no construction has no objects to name before toward"
  | Some { Ast.target; _ } -> (
      let t = toward_obj ctx target in
      match toward_side axis t with
      | None ->
          Error.fail span
            (Printf.sprintf "toward %s names no side of the fold line" t.t_str)
      | Some s ->
          (match sides.Ast.s_moving with
          | Some fa when moving_side ctx axis fa = None ->
              Error.fail span
                (Printf.sprintf "moving %s names no side of the fold line" (Resolve.fstr fa))
          | Some fa when moving_side ctx axis fa <> Some (-s) ->
              Error.fail ~hint:"drop one of them" span
                (Printf.sprintf
                   "toward %s and moving %s name the same side of the fold line"
                   t.t_str (Resolve.fstr fa))
          | _ -> ());
          Some (-s))
