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
