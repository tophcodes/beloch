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

(* axiom 3: the line through point p, perpendicular to line l. A line
   perpendicular to a·x+b·y=c has its normal along l's direction (b,−a), so it
   has the form b·x − a·y = k; fix k by passing through p. Exact over ℚ. *)
let perpendicular_through (l : line) (p : point) : line =
  let a = l.b and b = Q.neg l.a in
  let c = Q.add (Q.mul a p.x) (Q.mul b p.y) in
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

type segment = point * point

let seg_param ((p, q) : segment) (r : point) : Q.t =
  let dx = Q.sub q.x p.x and dy = Q.sub q.y p.y in
  let num = Q.add (Q.mul (Q.sub r.x p.x) dx) (Q.mul (Q.sub r.y p.y) dy) in
  let den = Q.add (Q.mul dx dx) (Q.mul dy dy) in
  Q.div num den

(* Intersect the (infinite) line with the four unit-square edges, keep the hits
   that land on the square, dedup, and take two distinct ones as the segment. *)
let clip_to_unit_square (l : line) : segment option =
  let z = Q.zero and o = Q.one in
  let cands = ref [] in
  let add p = if in_unit_square p then cands := p :: !cands in
  if not (Q.equal l.a Q.zero) then begin
    add { x = Q.div l.c l.a; y = z };               (* bottom y=0 *)
    add { x = Q.div (Q.sub l.c l.b) l.a; y = o }    (* top y=1 *)
  end;
  if not (Q.equal l.b Q.zero) then begin
    add { x = z; y = Q.div l.c l.b };               (* left x=0 *)
    add { x = o; y = Q.div (Q.sub l.c l.a) l.b }    (* right x=1 *)
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
  let (p1, q1) = s1 and (p2, q2) = s2 in
  match intersection (line_through p1 q1) (line_through p2 q2) with
  | None -> None
  | Some r ->
      let on s =
        let t = seg_param s r in
        Q.sign t >= 0 && Q.compare t Q.one <= 0
      in
      if on s1 && on s2 && in_unit_square r then Some r else None

(* Half-plane of a direction (dx,dy): 0 for angles in [0,180) — i.e. dy>0, or
   on the +x axis; 1 for [180,360). Used to make CCW ordering total. *)
let direction_half (dx : Q.t) (dy : Q.t) : int =
  if Q.sign dy > 0 || (Q.equal dy Q.zero && Q.sign dx > 0) then 0 else 1

(* Order points a, b by the CCW angle of (a-center), (b-center), from +x axis. *)
let ccw_compare ~(center : point) (a : point) (b : point) : int =
  let dax = Q.sub a.x center.x and day = Q.sub a.y center.y in
  let dbx = Q.sub b.x center.x and dby = Q.sub b.y center.y in
  let ha = direction_half dax day and hb = direction_half dbx dby in
  if ha <> hb then compare ha hb
  else
    (* same half-plane: a before b iff a is clockwise of b, i.e. cross(a,b) > 0 *)
    let cross = Q.sub (Q.mul dax dby) (Q.mul dbx day) in
    let s = Q.sign cross in
    if s > 0 then -1 else if s < 0 then 1 else 0

(* Shoelace signed area; sign encodes orientation (CCW > 0). *)
let signed_area (pts : point array) : Q.t =
  let n = Array.length pts in
  let s = ref Q.zero in
  for i = 0 to n - 1 do
    let p = pts.(i) and q = pts.((i + 1) mod n) in
    s := Q.add !s (Q.sub (Q.mul p.x q.y) (Q.mul q.x p.y))
  done;
  Q.div !s (Q.of_int 2)
