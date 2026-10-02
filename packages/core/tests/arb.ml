(* Generators for the property tests (test_prop_*.ml): exact numbers in each
   of [Num]'s three representations, points, lines, plane and space isometries,
   and convex polygons. Sizes are bounded on purpose: arithmetic is exact, a
   sum of two irrationals of degree 4 and 5 already has degree 20, and every
   case here runs inside [check].

   The seed is fixed so that [check] and CI draw the same cases and a failure
   reproduces; QCHECK_SEED=<n> draws another set. *)

open Beloch
module G = QCheck2.Gen

let seed =
  match Option.bind (Sys.getenv_opt "QCHECK_SEED") int_of_string_opt with
  | Some s -> s
  | None -> 1729

(* Every property gets its own state, from the seed and its name: a case
   does not depend on which properties ran before it, and two properties
   over the same generator still draw different cases. *)
let to_alcotest (t : QCheck2.Test.t) : unit Alcotest.test_case =
  let (QCheck2.Test.Test cell) = t in
  QCheck_alcotest.to_alcotest ~speed_level:`Quick
    ~rand:
      (Random.State.make [| seed; Hashtbl.hash (QCheck2.Test.get_name cell) |])
    t

let run suite groups =
  Printf.printf "qcheck seed %d (set QCHECK_SEED to draw other cases)\n%!" seed;
  Alcotest.run suite
    (List.map (fun (name, tests) -> (name, List.map to_alcotest tests)) groups)

(* [QCheck2.Test.make], timed: with BELOCH_PROP_SLOW=<seconds> set, every case
   that takes longer is printed to stderr (run the suite with --verbose to
   see it), which is how the generators' sizes were tuned. *)
let slow = Option.bind (Sys.getenv_opt "BELOCH_PROP_SLOW") float_of_string_opt

let make ?count ?max_gen ~name ~print gen prop =
  let prop =
    match slow with
    | None -> prop
    | Some bound ->
        fun x ->
          let t0 = Unix.gettimeofday () in
          let r = prop x in
          let dt = Unix.gettimeofday () -. t0 in
          if dt > bound then
            Printf.eprintf "SLOW %.3f %s: %s\n%!" dt name (print x);
          r
  in
  QCheck2.Test.make ?count ?max_gen ~name ~print gen prop

let q n d = Num.of_q (Q.of_ints n d)
let n = Num.of_int

(* ---- numbers ---- *)

(* An irrational a number expression is built from. [Sqrt] and [Root2] are the
   same number held two ways: [Num.sqrt] gives a FLINT-backed [Qq], [Num.make]
   on x² − k a [Field] over its own generator. [Cbrt] is a cubic [Field];
   [Quartic] is √(2 + √2), degree 4 (what an axiom-5 crease on a √2 base
   produces); [Quintic] is the real root of x⁵ − x − 1, degree 5, above
   [Num.field_degree_cap], so it never leaves [Qq]. *)
type atom = Sqrt of int | Root2 of int | Cbrt of int | Quartic | Quintic

type expr =
  | Lit of int * int  (** the rational n/d *)
  | Atom of atom
  | Neg of expr
  | Add of expr * expr
  | Mul of expr * expr
  | Inv of expr  (** 1/x, and 0 where x = 0, so every expression has a value *)

let poly l = Poly.of_list (List.map Q.of_int l)

let atom_value_uncached = function
  | Sqrt k -> Num.sqrt (n k)
  | Root2 k -> Num.make (poly [ -k; 0; 1 ]) Q.one (Q.of_int k)
  | Cbrt k -> Num.make (poly [ -k; 0; 0; 1 ]) Q.zero (Q.of_int k)
  | Quartic ->
      Num.make (poly [ 2; 0; -4; 0; 1 ]) (Q.of_ints 9 5) (Q.of_ints 19 10)
  | Quintic -> Num.make (poly [ -1; -1; 0; 0; 0; 1 ]) Q.one (Q.of_int 2)

let atom_cache : (atom, Num.t) Hashtbl.t = Hashtbl.create 16

let atom_value a =
  match Hashtbl.find_opt atom_cache a with
  | Some v -> v
  | None ->
      let v = atom_value_uncached a in
      Hashtbl.add atom_cache a v;
      v

let rec eval = function
  | Lit (a, b) -> q a b
  | Atom a -> atom_value a
  | Neg e -> Num.neg (eval e)
  | Add (a, b) -> Num.add (eval a) (eval b)
  | Mul (a, b) -> Num.mul (eval a) (eval b)
  | Inv e ->
      let v = eval e in
      if Num.sign v = 0 then v else Num.inv v

let atom_str = function
  | Sqrt k -> Printf.sprintf "sqrt(%d)" k
  | Root2 k -> Printf.sprintf "root2(%d)" k
  | Cbrt k -> Printf.sprintf "cbrt(%d)" k
  | Quartic -> "sqrt(2+sqrt2)"
  | Quintic -> "quintic"

let rec expr_str = function
  | Lit (a, 1) -> string_of_int a
  | Lit (a, b) -> Printf.sprintf "%d/%d" a b
  | Atom a -> atom_str a
  | Neg e -> "-(" ^ expr_str e ^ ")"
  | Add (a, b) -> "(" ^ expr_str a ^ " + " ^ expr_str b ^ ")"
  | Mul (a, b) -> "(" ^ expr_str a ^ " * " ^ expr_str b ^ ")"
  | Inv e -> "inv(" ^ expr_str e ^ ")"

(* The same expression with every [Sqrt] held as a [Root2]: the same number in
   another representation. *)
let rec as_fields = function
  | Atom (Sqrt k) -> Atom (Root2 k)
  | (Lit _ | Atom _) as e -> e
  | Neg e -> Neg (as_fields e)
  | Add (a, b) -> Add (as_fields a, as_fields b)
  | Mul (a, b) -> Mul (as_fields a, as_fields b)
  | Inv e -> Inv (as_fields e)

let atom : atom G.t =
  G.oneof_weighted
    [
      (3, G.map (fun k -> Sqrt k) (G.oneof_list [ 2; 3; 5; 6 ]));
      (3, G.map (fun k -> Root2 k) (G.oneof_list [ 2; 3; 5; 6 ]));
      (2, G.map (fun k -> Cbrt k) (G.oneof_list [ 2; 3 ]));
      (1, G.return Quartic);
      (1, G.return Quintic);
    ]

(* One irrational per case, or in half of the cases two, which is where
   [Num] has to find a common field or fall back to qqbar. Mixing two fields
   costs a lattice search per new generator ([Qqbar.express_over]), tenths
   of a second, and the degree of the compositum drives FLINT's cost, so the
   quartic √(2 + √2) is paired only with √2, the field it contains (the
   crane's case); with √6 it makes degree 8, a second per property. *)
let atoms : atom list G.t =
  G.(
    let* a = atom and* b = atom and* two = bool in
    match (a, b) with
    | _ when not two -> return [ a ]
    | Quartic, (Sqrt 2 | Root2 2) | (Sqrt 2 | Root2 2), Quartic ->
        return [ a; b ]
    | Quartic, _ | _, Quartic -> return [ a ]
    | _ -> return [ a; b ])

let lit : expr G.t =
  G.map2
    (fun a b -> Lit (a, b))
    (G.int_range ~origin:0 (-6) 6)
    (G.int_range 1 4)

let expr_over (atoms : atom list) : expr G.t =
  let leaf =
    G.oneof_weighted
      [ (2, lit); (3, G.map (fun a -> Atom a) (G.oneof_list atoms)) ]
  in
  let rec go depth =
    if depth = 0 then leaf
    else
      let sub = go (depth - 1) in
      G.oneof_weighted
        [
          (3, leaf);
          (1, G.map (fun e -> Neg e) sub);
          (3, G.map2 (fun a b -> Add (a, b)) sub sub);
          (3, G.map2 (fun a b -> Mul (a, b)) sub sub);
          (1, G.map (fun e -> Inv e) sub);
        ]
  in
  G.(int_range 0 2 >>= go)

let expr : expr G.t = G.(atoms >>= expr_over)

(* Two or three expressions over one shared pair of irrationals, so that
   they meet in a common field often enough to exercise the paths that
   combine fields. *)
let expr2 : (expr * expr) G.t =
  G.(atoms >>= fun at -> pair (expr_over at) (expr_over at))

let expr3 : (expr * expr * expr) G.t =
  G.(atoms >>= fun at -> triple (expr_over at) (expr_over at) (expr_over at))

let print_expr2 (a, b) = expr_str a ^ " ; " ^ expr_str b
let print_expr3 (a, b, c) = expr_str a ^ " ; " ^ expr_str b ^ " ; " ^ expr_str c

(* ---- coordinates, points, lines ---- *)

(* A coordinate: mostly a small rational, sometimes r + s·√2 with √2 in one of
   its two representations, so the geometry meets [Field] and [Qq] values.
   One irrational only: two independent ones (√2 and √3) send almost every
   operation through a lattice search for a common field, a fifth of a
   second each, and the number suite covers that path. *)
type coord = R of int * int | Irr of (int * int) * (int * int) * atom

let coord_value = function
  | R (a, b) -> q a b
  | Irr ((a, b), (c, d), at) ->
      Num.add (q a b) (Num.mul (q c d) (atom_value at))

let coord_str = function
  | R (a, 1) -> string_of_int a
  | R (a, b) -> Printf.sprintf "%d/%d" a b
  | Irr ((a, b), (c, d), at) ->
      Printf.sprintf "%d/%d+%d/%d*%s" a b c d (atom_str at)

let small_q : (int * int) G.t =
  G.pair (G.int_range ~origin:0 (-6) 6) (G.int_range 1 3)

let rational_coord : coord G.t = G.map (fun (a, b) -> R (a, b)) small_q

let coord : coord G.t =
  G.oneof_weighted
    [
      (4, rational_coord);
      ( 1,
        G.map3
          (fun r s at -> Irr (r, s, at))
          small_q small_q
          (G.oneof_list [ Sqrt 2; Root2 2 ]) );
    ]

type pt = coord * coord

let pt_value ((x, y) : pt) : Geom.point =
  { Geom.x = coord_value x; y = coord_value y }

let pt_str ((x, y) : pt) = Printf.sprintf "(%s, %s)" (coord_str x) (coord_str y)
let rational_pt : pt G.t = G.pair rational_coord rational_coord
let pt : pt G.t = G.pair coord coord

(* A line through two points; the generator may give two equal points, which
   the properties discard. *)
type ln = pt * pt

let ln_value ((p, r) : ln) : Geom.line =
  Geom.line_through (pt_value p) (pt_value r)

let ln_str ((p, r) : ln) = Printf.sprintf "line[%s %s]" (pt_str p) (pt_str r)
let rational_ln : ln G.t = G.pair rational_pt rational_pt
let ln : ln G.t = G.pair pt pt
let proper_ln ((p, r) : ln) = not (Geom.point_equal (pt_value p) (pt_value r))

(* ---- exact helpers ---- *)

let num_str (x : Num.t) =
  match x with
  | Num.Rat r -> Q.to_string r
  | Num.Field _ | Num.Qq _ -> Printf.sprintf "~%.9g" (Num.to_float x)

let point_str (p : Geom.point) =
  Printf.sprintf "(%s, %s)" (num_str p.Geom.x) (num_str p.Geom.y)

let line_str (l : Geom.line) =
  Printf.sprintf "%s x + %s y = %s" (num_str l.Geom.a) (num_str l.Geom.b)
    (num_str l.Geom.c)

let is_line (l : Geom.line) = Num.sign l.Geom.a <> 0 || Num.sign l.Geom.b <> 0
let on_line (l : Geom.line) (p : Geom.point) = Geom.side_of_line l p = 0

(* Two distinct points of a proper line. *)
let two_points_on (l : Geom.line) : Geom.point * Geom.point =
  let open Geom in
  if Num.sign l.b <> 0 then
    ( { x = Num.zero; y = Num.div l.c l.b },
      { x = Num.one; y = Num.div (Num.sub l.c l.a) l.b } )
  else
    let x = Num.div l.c l.a in
    ({ x; y = Num.zero }, { x; y = Num.one })

(* The image of a line under the reflection in [c]. *)
let reflect_line (c : Geom.line) (l : Geom.line) : Geom.line =
  let p, r = two_points_on l in
  Geom.line_through (Geom.reflect_point c p) (Geom.reflect_point c r)

let perpendicular (l1 : Geom.line) (l2 : Geom.line) =
  Num.sign (Num.add (Num.mul l1.Geom.a l2.Geom.a) (Num.mul l1.Geom.b l2.Geom.b))
  = 0

let dist2 (u : Geom.point) (v : Geom.point) =
  let dx = Num.sub u.Geom.x v.Geom.x and dy = Num.sub u.Geom.y v.Geom.y in
  Num.add (Num.mul dx dx) (Num.mul dy dy)

(* ---- plane isometries: products of reflections ---- *)

(* Every isometry of the plane is a product of at most three reflections. *)
type iso = ln list

let iso_value (lines : iso) : Isometry.t =
  List.fold_left
    (fun acc l ->
      Isometry.compose acc (Isometry.reflect_across_line (ln_value l)))
    Isometry.identity lines

let iso_str (lines : iso) =
  "[" ^ String.concat "; " (List.map ln_str lines) ^ "]"

let iso : iso G.t =
  G.map (List.filter proper_ln) (G.list_size (G.int_range 0 3) ln)

let iso_equal (a : Isometry.t) (b : Isometry.t) =
  let open Isometry in
  Num.equal a.m00 b.m00 && Num.equal a.m01 b.m01 && Num.equal a.m10 b.m10
  && Num.equal a.m11 b.m11 && Num.equal a.tx b.tx && Num.equal a.ty b.ty

(* ---- motions of space: products of half-turns ---- *)

type pt3 = (int * int) * (int * int) * (int * int)

let pt3_value (((a, b), (c, d), (e, f)) : pt3) : Isometry3.point =
  { Isometry3.x = q a b; y = q c d; z = q e f }

let pt3_str (((a, b), (c, d), (e, f)) : pt3) =
  Printf.sprintf "(%d/%d, %d/%d, %d/%d)" a b c d e f

let pt3 : pt3 G.t = G.triple small_q small_q small_q

(* A half-turn about the line through [on] along [dir]; a zero [dir] is
   dropped by [axis_ok]. *)
type axis = pt3 * pt3

let axis_ok ((_, ((a, _), (c, _), (e, _))) : axis) = a <> 0 || c <> 0 || e <> 0

let half_turn ((on, dir) : axis) =
  Isometry3.half_turn_about_line ~on:(pt3_value on) ~dir:(pt3_value dir)

let axis_str ((on, dir) : axis) =
  Printf.sprintf "axis[on %s dir %s]" (pt3_str on) (pt3_str dir)

let axis : axis G.t = G.pair pt3 pt3

type motion = axis list

let motion_value (m : motion) =
  List.fold_left
    (fun acc a -> Isometry3.compose acc (half_turn a))
    Isometry3.identity m

let motion_str (m : motion) =
  "[" ^ String.concat "; " (List.map axis_str m) ^ "]"

let motion : motion G.t =
  G.map (List.filter axis_ok) (G.list_size (G.int_range 0 3) axis)

let pt3_equal (a : Isometry3.point) (b : Isometry3.point) =
  Num.equal a.Isometry3.x b.Isometry3.x
  && Num.equal a.Isometry3.y b.Isometry3.y
  && Num.equal a.Isometry3.z b.Isometry3.z

(* ---- convex polygons ---- *)

(* The convex hull of three to six rational points, sometimes moved by a plane
   isometry whose lines carry √2 or √3, so the vertices are irrational. A
   reflection reverses the order of the vertices, so a moved polygon whose
   isometry reverses orientation is read backwards to stay counter-clockwise. *)
type poly = { pts : pt list; moved : iso }

let poly_value (p : poly) : Geom.point array =
  let hull = Geom.convex_hull (List.map pt_value p.pts) in
  match p.moved with
  | [] -> hull
  | m ->
      let i = iso_value m in
      let moved = Array.map (Isometry.apply_point i) hull in
      if Isometry.det_sign i < 0 then
        let k = Array.length moved in
        Array.init k (fun j -> moved.(k - 1 - j))
      else moved

let poly_str (p : poly) =
  Printf.sprintf "hull{%s}%s"
    (String.concat " " (List.map pt_str p.pts))
    (match p.moved with [] -> "" | m -> " moved by " ^ iso_str m)

let poly : poly G.t =
  G.map2
    (fun pts moved -> { pts; moved })
    (G.list_size (G.int_range 3 6) rational_pt)
    (G.oneof_weighted [ (3, G.return []); (1, iso) ])

(* A polygon in the sense of the kernel: at least three vertices, positive
   area. A hull of collinear points is neither and is discarded. *)
let proper_poly (v : Geom.point array) =
  Array.length v >= 3 && Num.sign (Geom.signed_area v) > 0

let polygon_str (v : Geom.point array) =
  "[" ^ String.concat " " (Array.to_list (Array.map point_str v)) ^ "]"
