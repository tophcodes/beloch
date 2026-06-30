(** Exact constructible-real plane geometry. A line a*x + b*y = c with a,b,c in
    Num (the v0.3 constructible reals; rational on the fast-path). *)

type point = { x : Num.t; y : Num.t }
type line = { a : Num.t; b : Num.t; c : Num.t }

let point_equal (p : point) (q : point) : bool =
  Num.equal p.x q.x && Num.equal p.y q.y

let line_through (p : point) (q : point) : line =
  let a = Num.sub q.y p.y in
  let b = Num.sub p.x q.x in
  let c = Num.add (Num.mul a p.x) (Num.mul b p.y) in
  { a; b; c }

let perpendicular_bisector (p : point) (q : point) : line =
  let a = Num.sub q.x p.x in
  let b = Num.sub q.y p.y in
  let two = Num.of_int 2 in
  let mx = Num.div (Num.add p.x q.x) two in
  let my = Num.div (Num.add p.y q.y) two in
  let c = Num.add (Num.mul a mx) (Num.mul b my) in
  { a; b; c }

let perpendicular_through (l : line) (p : point) : line =
  let a = l.b and b = Num.neg l.a in
  let c = Num.add (Num.mul a p.x) (Num.mul b p.y) in
  { a; b; c }

let parallel (l1 : line) (l2 : line) : bool =
  Num.equal (Num.sub (Num.mul l1.a l2.b) (Num.mul l2.a l1.b)) Num.zero

let intersection (l1 : line) (l2 : line) : point option =
  let det = Num.sub (Num.mul l1.a l2.b) (Num.mul l2.a l1.b) in
  if Num.sign det = 0 then None
  else
    let x = Num.div (Num.sub (Num.mul l1.c l2.b) (Num.mul l2.c l1.b)) det in
    let y = Num.div (Num.sub (Num.mul l1.a l2.c) (Num.mul l2.a l1.c)) det in
    Some { x; y }

(* axiom 4: the crease that projects p onto l1 with the crease perpendicular to
   l2 — p moves parallel to l2 until it lands on l1. None when l1 ∥ l2 (then
   the move never meets l1, or — if p ∈ l1 — meets it everywhere). Exact, no
   sqrt: every operation stays in ℚ. [justin1986 §8.1 operation ④] *)
let project_crease (p : point) (l1 : line) (l2 : line) : line option =
  if parallel l1 l2 then None
  else
    (* m: the line through p parallel to l2 (same normal, shifted to pass through p) *)
    let m = { a = l2.a; b = l2.b; c = Num.add (Num.mul l2.a p.x) (Num.mul l2.b p.y) } in
    match intersection m l1 with
    | None -> None (* unreachable: l1 ∦ l2 ⟹ l1 ∦ m *)
    | Some q ->
        if point_equal p q then Some (perpendicular_through l2 p)
        else Some (perpendicular_bisector p q)

(* circle (centre c, radius² r2) ∩ line a·x+b·y=e : 0, 1, or 2 points. The foot
   of the perpendicular from c to the line is c − (s/n2)·(a,b) with
   s = a·cx+b·cy−e and n2 = a²+b²; the half-chord² is (r2·n2 − s²)/n2, so the
   sign of r2·n2 − s² decides the count without dividing. The chord runs along
   the line direction (b,−a); the offset magnitude is √(r2·n2−s²)/n2. The only
   sqrt — stays in the quadratic tower. [justin1986 §8.2c] *)
let circle_line_intersection (c : point) (r2 : Num.t) (l : line) : point list =
  let n2 = Num.add (Num.mul l.a l.a) (Num.mul l.b l.b) in
  let s = Num.sub (Num.add (Num.mul l.a c.x) (Num.mul l.b c.y)) l.c in
  let t = Num.div s n2 in
  let foot = { x = Num.sub c.x (Num.mul t l.a); y = Num.sub c.y (Num.mul t l.b) } in
  let disc = Num.sub (Num.mul r2 n2) (Num.mul s s) in
  match Num.sign disc with
  | n when n < 0 -> []
  | 0 -> [ foot ]
  | _ ->
      let k = Num.div (Num.sqrt disc) n2 in
      [
        { x = Num.add foot.x (Num.mul l.b k); y = Num.sub foot.y (Num.mul l.a k) };
        { x = Num.sub foot.x (Num.mul l.b k); y = Num.add foot.y (Num.mul l.a k) };
      ]

(* axiom 6 (Justin ⑥): the crease(s) folding p onto line d with a crease through
   the fixed point p'. p' is on the crease, so it is equidistant from p and the
   image q of p, putting q on the circle (centre p', radius |p'p|) ∩ d; the
   crease is the perpendicular bisector of p and q. 0, 1, or 2 creases. A
   landing q = p is the identity (no fold) and is dropped. Square roots only. *)
let beloch_creases (p : point) (d : line) (p' : point) : line list =
  let dx = Num.sub p.x p'.x and dy = Num.sub p.y p'.y in
  let r2 = Num.add (Num.mul dx dx) (Num.mul dy dy) in
  circle_line_intersection p' r2 d
  |> List.filter (fun q -> not (point_equal q p))
  |> List.map (fun q -> perpendicular_bisector p q)

(* axiom 7 (Justin ⑦): the crease(s) that simultaneously fold p onto line d and
   q onto line e — a common tangent to the two parabolas (focus p, directrix d)
   and (focus q, directrix e). Parametrize p's landing along d by t; the
   "lands q on e" condition is a cubic F(t); each real root is a crease (the
   perpendicular bisector of p and its landing). 0, 1, or 3 creases.
   [justin1986 §2–3; hull2020 §2.4] *)
let beloch7_creases (p : point) (d : line) (q : point) (e : line) : line list =
  (* polynomials in t as Num.t arrays, low-first *)
  let padd a b =
    let n = max (Array.length a) (Array.length b) in
    Array.init n (fun i ->
        let x = if i < Array.length a then a.(i) else Num.zero in
        let y = if i < Array.length b then b.(i) else Num.zero in
        Num.add x y)
  in
  let pscale (s : Num.t) a = Array.map (fun c -> Num.mul s c) a in
  let pmul a b =
    let r = Array.make (Array.length a + Array.length b - 1) Num.zero in
    Array.iteri
      (fun i ca -> Array.iteri (fun j cb -> r.(i + j) <- Num.add r.(i + j) (Num.mul ca cb)) b)
      a;
    r
  in
  let psub a b = padd a (pscale (Num.of_int (-1)) b) in
  let n2 = Num.add (Num.mul d.a d.a) (Num.mul d.b d.b) in
  let d0x = Num.div (Num.mul d.a d.c) n2 and d0y = Num.div (Num.mul d.b d.c) n2 in
  let two = Num.of_int 2 in
  (* p*(t) = (d0x + t·d.b, d0y − t·d.a) *)
  (* A(t) = p*.x − p.x = (d0x − p.x) + t·d.b *)
  let aA = [| Num.sub d0x p.x; d.b |] in
  (* B(t) = p*.y − p.y = (d0y − p.y) + t·(−d.a) *)
  let bB = [| Num.sub d0y p.y; Num.neg d.a |] in
  (* mx(t) = (p.x + p*.x)/2,  my(t) = (p.y + p*.y)/2 *)
  let mx = [| Num.div (Num.add p.x d0x) two; Num.div d.b two |] in
  let my = [| Num.div (Num.add p.y d0y) two; Num.div (Num.neg d.a) two |] in
  (* C(t) = A·mx + B·my *)
  let cC = padd (pmul aA mx) (pmul bB my) in
  (* n2c(t) = A² + B² *)
  let n2c = padd (pmul aA aA) (pmul bB bB) in
  (* dd(t) = A·q.x + B·q.y − C *)
  let dd = psub (padd (pscale q.x aA) (pscale q.y bB)) cC in
  (* L(t) = e.a·A + e.b·B *)
  let lL = padd (pscale e.a aA) (pscale e.b bB) in
  (* S = e.a·q.x + e.b·q.y − e.c   (constant) *)
  let s = Num.sub (Num.add (Num.mul e.a q.x) (Num.mul e.b q.y)) e.c in
  (* F(t) = S·n2c − 2·dd·L *)
  let fF = psub (pscale s n2c) (pscale two (pmul dd lL)) in
  Num.real_roots fF
  |> List.map (fun t ->
         let pstar = { x = Num.add d0x (Num.mul t d.b); y = Num.sub d0y (Num.mul t d.a) } in
         perpendicular_bisector p pstar)

let in_unit_square (p : point) : bool =
  Num.sign p.x >= 0
  && Num.compare p.x Num.one <= 0
  && Num.sign p.y >= 0
  && Num.compare p.y Num.one <= 0

type segment = point * point

let seg_param ((p, q) : segment) (r : point) : Num.t =
  let dx = Num.sub q.x p.x and dy = Num.sub q.y p.y in
  let num =
    Num.add (Num.mul (Num.sub r.x p.x) dx) (Num.mul (Num.sub r.y p.y) dy)
  in
  let den = Num.add (Num.mul dx dx) (Num.mul dy dy) in
  Num.div num den

let clip_to_unit_square (l : line) : segment option =
  let z = Num.zero and o = Num.one in
  let cands = ref [] in
  let add p = if in_unit_square p then cands := p :: !cands in
  if Num.sign l.a <> 0 then begin
    add { x = Num.div l.c l.a; y = z };
    add { x = Num.div (Num.sub l.c l.b) l.a; y = o }
  end;
  if Num.sign l.b <> 0 then begin
    add { x = z; y = Num.div l.c l.b };
    add { x = o; y = Num.div (Num.sub l.c l.a) l.b }
  end;
  let uniq =
    List.fold_left
      (fun acc p -> if List.exists (point_equal p) acc then acc else p :: acc)
      [] !cands
  in
  match uniq with
  | p :: q :: _ when not (point_equal p q) -> Some (p, q)
  | _ -> None

let segment_intersection (s1 : segment) (s2 : segment) : point option =
  let p1, q1 = s1 and p2, q2 = s2 in
  match intersection (line_through p1 q1) (line_through p2 q2) with
  | None -> None
  | Some r ->
      let on s =
        let t = seg_param s r in
        Num.sign t >= 0 && Num.compare t Num.one <= 0
      in
      if on s1 && on s2 && in_unit_square r then Some r else None

let direction_half (dx : Num.t) (dy : Num.t) : int =
  if Num.sign dy > 0 || (Num.sign dy = 0 && Num.sign dx > 0) then 0 else 1

let ccw_compare ~(center : point) (a : point) (b : point) : int =
  let dax = Num.sub a.x center.x and day = Num.sub a.y center.y in
  let dbx = Num.sub b.x center.x and dby = Num.sub b.y center.y in
  let ha = direction_half dax day and hb = direction_half dbx dby in
  if ha <> hb then compare ha hb
  else
    let cross = Num.sub (Num.mul dax dby) (Num.mul dbx day) in
    let s = Num.sign cross in
    if s > 0 then -1 else if s < 0 then 1 else 0

let signed_area (pts : point array) : Num.t =
  let n = Array.length pts in
  let s = ref Num.zero in
  for i = 0 to n - 1 do
    let p = pts.(i) and q = pts.((i + 1) mod n) in
    s := Num.add !s (Num.sub (Num.mul p.x q.y) (Num.mul q.x p.y))
  done;
  Num.div !s (Num.of_int 2)

(* axiom 5: the two angle bisectors of l1, l2 (None if parallel). With
   ni = √(ai²+bi²), points equidistant satisfy n2·L1 = ±n1·L2, giving lines
     (n2 a1 ∓ n1 a2) x + (n2 b1 ∓ n1 b2) y = n2 c1 ∓ n1 c2.
   bis_eq is the d1=d2 bisector (minus); bis_opp the d1=−d2 bisector (plus). *)
let angle_bisectors (l1 : line) (l2 : line) : (line * line) option =
  let det = Num.sub (Num.mul l1.a l2.b) (Num.mul l2.a l1.b) in
  if Num.sign det = 0 then None
  else
    let n1 = Num.sqrt (Num.add (Num.mul l1.a l1.a) (Num.mul l1.b l1.b)) in
    let n2 = Num.sqrt (Num.add (Num.mul l2.a l2.a) (Num.mul l2.b l2.b)) in
    let mk add_sign =
      let comb u v = if add_sign then Num.add u v else Num.sub u v in
      {
        a = comb (Num.mul n2 l1.a) (Num.mul n1 l2.a);
        b = comb (Num.mul n2 l1.b) (Num.mul n1 l2.b);
        c = comb (Num.mul n2 l1.c) (Num.mul n1 l2.c);
      }
    in
    Some (mk false, mk true)

(* midline of two parallel lines: rescale l2 to l1's normal, average offsets. *)
let parallel_midline (l1 : line) (l2 : line) : line =
  let k = if Num.sign l1.a <> 0 then Num.div l2.a l1.a else Num.div l2.b l1.b in
  let c = Num.div (Num.add l1.c (Num.div l2.c k)) (Num.of_int 2) in
  { a = l1.a; b = l1.b; c }

(* signed side of a point: sign (a·px + b·py − c). 0 means on the line. *)
let side_of_line (l : line) (p : point) : int =
  Num.sign (Num.sub (Num.add (Num.mul l.a p.x) (Num.mul l.b p.y)) l.c)

(* reflect p across a·x + b·y = c:  p − 2·(a·px+b·py−c)/(a²+b²)·(a,b). Exact, no sqrt. *)
let reflect_point (l : line) (p : point) : point =
  let n2 = Num.add (Num.mul l.a l.a) (Num.mul l.b l.b) in
  let d = Num.sub (Num.add (Num.mul l.a p.x) (Num.mul l.b p.y)) l.c in
  let k = Num.div (Num.mul (Num.of_int 2) d) n2 in
  { x = Num.sub p.x (Num.mul k l.a); y = Num.sub p.y (Num.mul k l.b) }

(* Keep the part of convex CCW [poly] on the side where [side_of_line l = keep]
   (vertices on the line are kept). Sutherland–Hodgman against one half-plane;
   preserves convexity and CCW order. Returns [||] if no area remains. *)
let clip_convex_halfplane (l : line) (keep : int) (poly : point array) :
    point array =
  let n = Array.length poly in
  if n = 0 then [||]
  else begin
    let out = ref [] in
    for i = 0 to n - 1 do
      let cur = poly.(i) and nxt = poly.((i + 1) mod n) in
      let sc = side_of_line l cur and sn = side_of_line l nxt in
      if sc = keep || sc = 0 then out := cur :: !out;
      if sc <> 0 && sn <> 0 && sc <> sn then
        match intersection l (line_through cur nxt) with
        | Some r -> out := r :: !out
        | None -> ()
    done;
    let pts = List.rev !out in
    if List.length pts < 3 then [||] else Array.of_list pts
  end

(* p inside or on the boundary of convex CCW [poly]: left-of-or-on every edge. *)
let in_convex_polygon (poly : point array) (p : point) : bool =
  let n = Array.length poly in
  let ok = ref true in
  for i = 0 to n - 1 do
    let a = poly.(i) and b = poly.((i + 1) mod n) in
    let cross =
      Num.sub
        (Num.mul (Num.sub b.x a.x) (Num.sub p.y a.y))
        (Num.mul (Num.sub b.y a.y) (Num.sub p.x a.x))
    in
    if Num.sign cross < 0 then ok := false
  done;
  !ok

(* p collinear with segment (a,b) and within it (endpoints included). *)
let on_segment ((a, b) : segment) (p : point) : bool =
  let cross =
    Num.sub
      (Num.mul (Num.sub b.x a.x) (Num.sub p.y a.y))
      (Num.mul (Num.sub b.y a.y) (Num.sub p.x a.x))
  in
  if Num.sign cross <> 0 then false
  else
    let t = seg_param (a, b) p in
    Num.sign t >= 0 && Num.compare t Num.one <= 0

(* Two convex polygons share positive area? Separating-axis test over the edge
   normals of both: separated (no positive overlap) iff some axis's projections
   are disjoint or merely touching. *)
let convex_overlap (p : point array) (q : point array) : bool =
  let normals poly =
    let n = Array.length poly in
    List.init n (fun i ->
        let a = poly.(i) and b = poly.((i + 1) mod n) in
        (Num.sub a.y b.y, Num.sub b.x a.x))
  in
  let project poly (nx, ny) =
    let v i = Num.add (Num.mul nx poly.(i).x) (Num.mul ny poly.(i).y) in
    let lo = ref (v 0) and hi = ref (v 0) in
    for i = 1 to Array.length poly - 1 do
      let vi = v i in
      if Num.compare vi !lo < 0 then lo := vi;
      if Num.compare vi !hi > 0 then hi := vi
    done;
    (!lo, !hi)
  in
  let separated (nx, ny) =
    let alo, ahi = project p (nx, ny) and blo, bhi = project q (nx, ny) in
    Num.compare ahi blo <= 0 || Num.compare bhi alo <= 0
  in
  not (List.exists separated (normals p @ normals q))
