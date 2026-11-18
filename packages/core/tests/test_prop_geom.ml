(* Property tests for the polygon predicates of [Geom]: the overlap test
   [convex_overlap] that the layer order and the non-crossing checks read,
   and the half-plane clip [clip_convex_halfplane] that splits a face along
   a crease. Generators in arb.ml: a polygon is the convex hull of three to
   six rational points, sometimes moved by an isometry with irrational
   entries. *)

open Beloch
module G = QCheck2.Gen

let cross (o : Geom.point) (a : Geom.point) (b : Geom.point) =
  Num.sign
    (Num.sub
       (Num.mul (Num.sub a.Geom.x o.Geom.x) (Num.sub b.Geom.y o.Geom.y))
       (Num.mul (Num.sub a.Geom.y o.Geom.y) (Num.sub b.Geom.x o.Geom.x)))

(* Convex and counter-clockwise: every turn is a left turn or straight, the
   area is positive, and no vertex repeats its successor. *)
let convex_ccw (v : Geom.point array) =
  let k = Array.length v in
  k >= 3
  && Num.sign (Geom.signed_area v) > 0
  && List.for_all
       (fun i ->
         let a = v.(i) and b = v.((i + 1) mod k) and c = v.((i + 2) mod k) in
         (not (Geom.point_equal a b)) && cross a b c >= 0)
       (List.init k Fun.id)

(* strictly inside a convex CCW polygon: strictly left of every edge *)
let strictly_inside (v : Geom.point array) (p : Geom.point) =
  let k = Array.length v in
  List.for_all
    (fun i -> cross v.(i) v.((i + 1) mod k) p > 0)
    (List.init k Fun.id)

let centroid (v : Geom.point array) =
  let k = Num.of_int (Array.length v) in
  let sum f = Array.fold_left (fun acc p -> Num.add acc (f p)) Num.zero v in
  {
    Geom.x = Num.div (sum (fun p -> p.Geom.x)) k;
    y = Num.div (sum (fun p -> p.Geom.y)) k;
  }

let reverse v =
  let k = Array.length v in
  Array.init k (fun i -> v.(k - 1 - i))

let poly2 = G.pair Arb.poly Arb.poly
let print_poly2 (a, b) = Arb.poly_str a ^ " ; " ^ Arb.poly_str b

(* ---- [convex_overlap] ---- *)

let overlap_symmetric =
  Arb.make ~name:"convex_overlap p q = convex_overlap q p" ~count:60
    ~print:print_poly2 poly2 (fun (p, q) ->
      let p = Arb.poly_value p and q = Arb.poly_value q in
      QCheck2.assume (Arb.proper_poly p && Arb.proper_poly q);
      Geom.convex_overlap p q = Geom.convex_overlap q p)

let overlap_self =
  Arb.make ~name:"a polygon overlaps itself" ~count:40 ~print:Arb.poly_str
    Arb.poly (fun p ->
      let p = Arb.poly_value p in
      QCheck2.assume (Arb.proper_poly p);
      Geom.convex_overlap p p)

(* The centroid of [p]'s vertices lies strictly inside [p]; if it lies strictly
   inside [q] too, the two share a neighborhood of it, so positive area. *)
let overlap_shared_interior_point =
  Arb.make ~name:"a common interior point means overlap" ~count:60
    ~print:print_poly2 poly2 (fun (p, q) ->
      let p = Arb.poly_value p and q = Arb.poly_value q in
      QCheck2.assume (Arb.proper_poly p && Arb.proper_poly q);
      let c = centroid p in
      (not (strictly_inside q c)) || Geom.convex_overlap p q)

(* The mirror image of [p] in the line of one of its edges lies on the other
   side of that line and touches [p] along the edge: no area in common. *)
let touching_along_an_edge =
  Arb.make ~name:"a polygon and its mirror image in an edge do not overlap"
    ~count:40
    ~print:(fun (p, i) -> Arb.poly_str p ^ Printf.sprintf " ; edge %d" i)
    (G.pair Arb.poly (G.int_range 0 5))
    (fun (p, i) ->
      let p = Arb.poly_value p in
      QCheck2.assume (Arb.proper_poly p);
      let k = Array.length p in
      let edge = Geom.line_through p.(i mod k) p.((i + 1) mod k) in
      let mirror = reverse (Array.map (Geom.reflect_point edge) p) in
      (not (Geom.convex_overlap p mirror)) && not (Geom.convex_overlap mirror p))

(* The half-turn of [p] about one of its vertices meets [p] in that vertex
   only: [p] lies in a cone of angle below π at the vertex, the image in the
   opposite cone. *)
let touching_at_a_vertex =
  Arb.make ~name:"a polygon and its half-turn about a vertex do not overlap"
    ~count:40
    ~print:(fun (p, i) -> Arb.poly_str p ^ Printf.sprintf " ; vertex %d" i)
    (G.pair Arb.poly (G.int_range 0 5))
    (fun (p, i) ->
      let p = Arb.poly_value p in
      QCheck2.assume (Arb.proper_poly p);
      let v = p.(i mod Array.length p) in
      let two = Num.of_int 2 in
      let turned =
        Array.map
          (fun (u : Geom.point) ->
            {
              Geom.x = Num.sub (Num.mul two v.Geom.x) u.Geom.x;
              y = Num.sub (Num.mul two v.Geom.y) u.Geom.y;
            })
          p
      in
      (not (Geom.convex_overlap p turned)) && not (Geom.convex_overlap turned p))

(* ---- the float boxes behind [convex_overlap] ---- *)

(* A pair of polygons for the box filter: [p] with a second polygon made from
   it or drawn on its own, both moved by one translation. *)
type partner =
  | Other of Arb.poly  (** an independent polygon *)
  | Same  (** [p] itself *)
  | Mirror of int  (** [p] mirrored in edge i: the two touch along it *)
  | Near of int * int * bool
      (** the mirror in edge i moved 2^-k along the edge's normal, into [p]
          (true) or away from it: overlapping or apart by a hair *)
  | Turned of int  (** the half-turn of [p] about vertex i: touching there *)

(* The translation of both polygons: none, or (t, t) for an irrational t of
   degree 2 or 4, which puts every coordinate in a [Field] or [Qq]. *)
type shift = No_shift | Shift of Arb.atom

type box_case = { p : Arb.poly; partner : partner; shift : shift }

let partner_str = function
  | Other q -> Arb.poly_str q
  | Same -> "same"
  | Mirror i -> Printf.sprintf "mirror in edge %d" i
  | Near (i, k, inward) ->
      Printf.sprintf "mirror in edge %d moved 2^-%d %s" i k
        (if inward then "inward" else "outward")
  | Turned i -> Printf.sprintf "half-turn about vertex %d" i

let box_case_str c =
  Printf.sprintf "%s ; %s%s" (Arb.poly_str c.p) (partner_str c.partner)
    (match c.shift with
    | No_shift -> ""
    | Shift a -> " ; shifted by " ^ Arb.atom_str a)

let box_case =
  G.(
    let* p = Arb.poly
    and* partner =
      oneof_weighted
        [
          (2, map (fun q -> Other q) Arb.poly);
          (1, return Same);
          (2, map (fun i -> Mirror i) (int_range 0 5));
          ( 3,
            map3
              (fun i k inward -> Near (i, k, inward))
              (int_range 0 5) (int_range 20 70) bool );
          (1, map (fun i -> Turned i) (int_range 0 5));
        ]
    and* shift =
      oneof_weighted
        [
          (2, return No_shift);
          (1, map (fun a -> Shift a) (oneof_list Arb.[ Sqrt 2; Root2 2; Quartic ]));
        ]
    in
    return { p; partner; shift })

let box_case_value (c : box_case) : Geom.point array * Geom.point array =
  let p = Arb.poly_value c.p in
  let k = Array.length p in
  let mirror i =
    let a = p.(i mod k) and b = p.((i + 1) mod k) in
    (reverse (Array.map (Geom.reflect_point (Geom.line_through a b)) p), a, b)
  in
  let move (dx, dy) v =
    Array.map
      (fun (u : Geom.point) ->
        { Geom.x = Num.add u.Geom.x dx; y = Num.add u.Geom.y dy })
      v
  in
  let q =
    match c.partner with
    | Other q -> Arb.poly_value q
    | Same -> p
    | Mirror i ->
        let m, _, _ = mirror i in
        m
    | Near (i, e, inward) ->
        let m, a, b = mirror i in
        (* (a.y - b.y, b.x - a.x) points into [p], which is counter-clockwise *)
        let eps =
          Num.of_q (Q.make (if inward then Z.one else Z.minus_one)
                      (Z.shift_left Z.one e))
        in
        move
          ( Num.mul eps (Num.sub a.Geom.y b.Geom.y),
            Num.mul eps (Num.sub b.Geom.x a.Geom.x) )
          m
    | Turned i ->
        let v = p.(i mod k) and two = Num.of_int 2 in
        Array.map
          (fun (u : Geom.point) ->
            {
              Geom.x = Num.sub (Num.mul two v.Geom.x) u.Geom.x;
              y = Num.sub (Num.mul two v.Geom.y) u.Geom.y;
            })
          p
  in
  match c.shift with
  | No_shift -> (p, q)
  | Shift a ->
      let t = Arb.atom_value a in
      (move (t, t) p, move (t, t) q)

let filtered_equals_exact =
  Arb.make ~name:"convex_overlap equals the exact test" ~count:150
    ~print:box_case_str box_case (fun c ->
      let p, q = box_case_value c in
      QCheck2.assume (Arb.proper_poly p && Arb.proper_poly q);
      let exact = Geom.convex_overlap_exact p q in
      Geom.convex_overlap p q = exact
      && (match Geom.convex_overlap_boxes p q with
         | Some b -> b = exact
         | None -> true))

(* A coordinate's box has finite ends, each on its side of the exact
   value. *)
let box_encloses =
  Arb.make ~name:"a box encloses its number" ~count:100
    ~print:box_case_str box_case (fun c ->
      let p, q = box_case_value c in
      Array.for_all
        (fun (v : Geom.point) ->
          List.for_all
            (fun x ->
              let lo, hi = Num.box x in
              Float.is_finite lo && Float.is_finite hi
              && lo <= hi
              && Num.compare (Num.of_q (Q.of_float lo)) x <= 0
              && Num.compare (Num.of_q (Q.of_float hi)) x >= 0)
            [ v.Geom.x; v.Geom.y ])
        (Array.append p q))

(* ---- [clip_convex_halfplane] ---- *)

(* The clipping line: through two generated points, or through a vertex of
   the polygon, so that a vertex on the line is a common case. *)
type cut = {
  poly : Arb.poly;
  through_vertex : int option;
  other : Arb.pt;
  along : Arb.pt;
  keep : int;
}

let cut =
  G.(
    let* poly = Arb.poly
    and* through_vertex =
      oneof_weighted [ (1, return None); (1, map Option.some (int_range 0 5)) ]
    and* other = Arb.pt
    and* along = Arb.pt
    and* keep = oneof_list [ 1; -1 ] in
    return { poly; through_vertex; other; along; keep })

let cut_line (c : cut) (v : Geom.point array) =
  let a =
    match c.through_vertex with
    | Some i -> v.(i mod Array.length v)
    | None -> Arb.pt_value c.along
  in
  (a, Arb.pt_value c.other)

let print_cut (c : cut) =
  Printf.sprintf "%s ; line through %s and %s ; keep %d" (Arb.poly_str c.poly)
    (match c.through_vertex with
    | Some i -> Printf.sprintf "vertex %d" i
    | None -> Arb.pt_str c.along)
    (Arb.pt_str c.other) c.keep

let with_cut (c : cut) f =
  let v = Arb.poly_value c.poly in
  QCheck2.assume (Arb.proper_poly v);
  let a, b = cut_line c v in
  QCheck2.assume (not (Geom.point_equal a b));
  let l = Geom.line_through a b in
  f v l (Geom.clip_convex_halfplane l c.keep v)

let clip_convex =
  Arb.make ~name:"clip returns nothing or a convex CCW polygon" ~count:60
    ~print:print_cut cut (fun c ->
      with_cut c (fun _ _ r -> Array.length r = 0 || convex_ccw r))

let clip_in_halfplane =
  Arb.make ~name:"clip lies in the half-plane it kept" ~count:60
    ~print:print_cut cut (fun c ->
      with_cut c (fun _ l r ->
          Array.for_all
            (fun p ->
              let s = Geom.side_of_line l p in
              s = 0 || s = c.keep)
            r))

let clip_in_polygon =
  Arb.make ~name:"clip lies in the polygon it clipped" ~count:60
    ~print:print_cut cut (fun c ->
      with_cut c (fun v _ r -> Array.for_all (Geom.in_convex_polygon v) r))

(* The two sides of a line partition the polygon, so their areas add up. *)
let clip_areas_add_up =
  Arb.make ~name:"the clips to both sides add up to the polygon's area"
    ~count:60 ~print:print_cut cut (fun c ->
      with_cut c (fun v l r ->
          let other = Geom.clip_convex_halfplane l (-c.keep) v in
          let area x =
            if Array.length x = 0 then Num.zero else Geom.signed_area x
          in
          Num.equal (Num.add (area r) (area other)) (Geom.signed_area v)))

let () =
  Arb.run "beloch-prop-geom"
    [
      ( "convex_overlap",
        [
          overlap_symmetric;
          overlap_self;
          overlap_shared_interior_point;
          touching_along_an_edge;
          touching_at_a_vertex;
        ] );
      ("float boxes", [ filtered_equals_exact; box_encloses ]);
      ( "clip",
        [ clip_convex; clip_in_halfplane; clip_in_polygon; clip_areas_add_up ]
      );
    ]
