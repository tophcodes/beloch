(** Exact rational plane geometry. A line a*x + b*y = c with a,b,c in Q. *)

type point = { x : Q.t; y : Q.t }
type line = { a : Q.t; b : Q.t; c : Q.t }

let point_equal (p : point) (q : point) : bool =
  Q.equal p.x q.x && Q.equal p.y q.y

(* axiom 1: the line through two points.
   (y2-y1)(x-x1) - (x2-x1)(y-y1) = 0  ->  a=(y2-y1), b=-(x2-x1) *)
let line_through (p : point) (q : point) : line =
  let a = Q.sub q.y p.y in
  let b = Q.sub p.x q.x in
  let c = Q.add (Q.mul a p.x) (Q.mul b p.y) in
  { a; b; c }

(* axiom 2: perpendicular bisector of p,q. The bisector is perpendicular to the
   segment, so the segment direction (q-p) is the bisector's normal, and it
   passes through the midpoint m. *)
let perpendicular_bisector (p : point) (q : point) : line =
  let a = Q.sub q.x p.x in
  let b = Q.sub q.y p.y in
  let two = Q.of_int 2 in
  let mx = Q.div (Q.add p.x q.x) two in
  let my = Q.div (Q.add p.y q.y) two in
  let c = Q.add (Q.mul a mx) (Q.mul b my) in
  { a; b; c }

let parallel (l1 : line) (l2 : line) : bool =
  Q.equal (Q.sub (Q.mul l1.a l2.b) (Q.mul l2.a l1.b)) Q.zero

let intersection (l1 : line) (l2 : line) : point option =
  let det = Q.sub (Q.mul l1.a l2.b) (Q.mul l2.a l1.b) in
  if Q.equal det Q.zero then None
  else
    let x = Q.div (Q.sub (Q.mul l1.c l2.b) (Q.mul l2.c l1.b)) det in
    let y = Q.div (Q.sub (Q.mul l1.a l2.c) (Q.mul l2.a l1.c)) det in
    Some { x; y }

let in_unit_square (p : point) : bool =
  Q.sign p.x >= 0
  && Q.compare p.x Q.one <= 0
  && Q.sign p.y >= 0
  && Q.compare p.y Q.one <= 0
