(* Sides of layer pairs as a union-find with parity. A node stands for one
   pair (s, m) of overlapping faces, its value for "s lies above m". The
   node [truth] is the constant true; a pair joined to it is decided, a
   pair in a class without it is undecided, and every pair of one class
   turns with the class. *)

type pair = int * int

type lit = Known of bool | Side of pair * bool

type t = {
  parent : (pair, pair * bool) Hashtbl.t;
      (* node -> (parent, parity): value(node) = value(parent) xor parity;
         a root maps to itself with parity false *)
}

let truth : pair = (-1, -1)

let create () : t =
  let parent = Hashtbl.create 64 in
  Hashtbl.replace parent truth (truth, false);
  { parent }

let rec find (t : t) (x : pair) : pair * bool =
  match Hashtbl.find_opt t.parent x with
  | None ->
      Hashtbl.replace t.parent x (x, false);
      (x, false)
  | Some (p, par) when p = x -> (x, par)
  | Some (p, par) ->
      let r, pr = find t p in
      let par' = par <> pr in
      Hashtbl.replace t.parent x (r, par');
      (r, par')

(* A literal as (node, parity), so that its value is value(node) xor parity. *)
let node (t : t) = function
  | Known b -> (truth, not b)
  | Side (p, neg) ->
      let r, par = find t p in
      (r, par <> neg)

let relate (t : t) (a : lit) (b : lit) ~(why : 'why) : (unit, 'why) result =
  let ra, pa = node t a and rb, pb = node t b in
  if ra = rb then if pa = pb then Ok () else Error why
  else begin
    (* [truth] stays a root, so a decided class reads its value off it *)
    let child, root = if ra = truth then (rb, ra) else (ra, rb) in
    Hashtbl.replace t.parent child (root, pa <> pb);
    Ok ()
  end

let classes (t : t) (pairs : pair list) :
    (pair * bool) list * (pair * bool) list list =
  let decided = ref [] and free = Hashtbl.create 16 and roots = ref [] in
  List.iter
    (fun p ->
      let r, par = find t p in
      if r = truth then decided := (p, not par) :: !decided
      else begin
        if not (Hashtbl.mem free r) then roots := r :: !roots;
        (* the value of [p] when the class root is set to true *)
        Hashtbl.replace free r
          ((p, not par) :: Option.value (Hashtbl.find_opt free r) ~default:[])
      end)
    pairs;
  ( List.rev !decided,
    List.rev_map (fun r -> List.rev (Hashtbl.find free r)) !roots )
