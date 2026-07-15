(** The 3D-native folded-state core (issue #48, spec 2026-07-15-fold-state-3d-
    rewrite). Faces = 2D paper polygons; hinges = the face-adjacency graph. A
    face's 3D placement is DERIVED as the product of hinge motions along a path
    from the root — so adjacent faces differ by exactly their hinge's motion and
    a torn state cannot be written down. Flat-first: hinge angle (dihedral/π) ∈
    {0, ±1}; |angle|=1 folds via a half-turn about the crease line (= the 2D
    reflection on z=0), reproducing today's flat folds. General rπ is Stage B. *)

module I3 = Isometry3

type face = Geom.point array

type hinge = { fa : int; fb : int; line : Geom.line; angle : Num.t }

type t = {
  faces : face array;
  hinges : hinge array;
  root : int;
  rank : int array;  (* stacking height per face, higher = above; permutation *)
  isos : Isometry3.t array;  (* derived in [make] (memoized BFS); [t] abstract ⇒ cannot desync *)
}

type violation =
  | Bad_index of string
  | Bad_rank
  | Bad_angle of int
  | Disconnected of int
  | Hinge_not_shared of int
  | Hinge_not_closed of int
  | Taco_tortilla of { tortilla : int; hinge : int }
  | Taco_taco of int * int

let violation_to_string = function
  | Bad_index s -> "fold graph: index out of range: " ^ s
  | Bad_rank -> "fold graph: rank is not a permutation of the faces"
  | Bad_angle i ->
      Printf.sprintf "fold graph: hinge %d angle outside {0, ±1} (flat-first)" i
  | Disconnected i ->
      Printf.sprintf "fold graph: face %d is not connected to the root" i
  | Hinge_not_shared i ->
      Printf.sprintf
        "fold graph: hinge %d's line is not a shared edge of its two faces" i
  | Hinge_not_closed i ->
      Printf.sprintf "fold graph: hinge %d does not close — the sheet would tear"
        i
  | Taco_tortilla { tortilla; hinge } ->
      Printf.sprintf
        "layer ordering: face %d would pass through the crease of hinge %d — \
         taco-tortilla violation" tortilla hinge
  | Taco_taco (i, j) ->
      Printf.sprintf
        "layer ordering: creases of hinges %d and %d cross — taco-taco violation"
        i j

(* 3D motion a folded hinge applies (in the sheet frame): a half-turn about the
   crease line embedded in the z=0 plane. Flat crease (angle=0) → identity.
   Flat-first: |angle|=1 → half-turn; the sign (M vs V) does NOT change the flat
   placement (±π about the same axis coincide) — M/V is the layer order. *)
let hinge_motion (h : hinge) : I3.t =
  if Num.sign h.angle = 0 then I3.identity
  else
    let l = h.line in
    let on =
      if Num.sign l.Geom.a <> 0 then
        { I3.x = Num.div l.Geom.c l.Geom.a; y = Num.zero; z = Num.zero }
      else { I3.x = Num.zero; y = Num.div l.Geom.c l.Geom.b; z = Num.zero }
    in
    let dir = { I3.x = Num.neg l.Geom.b; y = l.Geom.a; z = Num.zero } in
    I3.half_turn_about_line ~on ~dir

(* Derived placements: BFS from [root] over the hinge graph; crossing a hinge
   composes its motion onto the already-placed face's placement,
   iso.(other) = compose iso.(fi) (hinge_motion h). Half-turns are involutions,
   so crossing a hinge either direction uses the same motion (flat-first).
   [seen] doubles as the connectivity witness. *)
let derive_isos ~(faces : face array) ~(hinges : hinge array) ~(root : int) :
    I3.t array * bool array =
  let n = Array.length faces in
  let iso = Array.make n I3.identity in
  let seen = Array.make n false in
  let queue = Queue.create () in
  seen.(root) <- true;
  Queue.push root queue;
  while not (Queue.is_empty queue) do
    let fi = Queue.pop queue in
    Array.iter
      (fun h ->
        let step other =
          if not seen.(other) then begin
            seen.(other) <- true;
            iso.(other) <- I3.compose iso.(fi) (hinge_motion h);
            Queue.push other queue
          end
        in
        if h.fa = fi then step h.fb else if h.fb = fi then step h.fa)
      hinges
  done;
  (iso, seen)

(* Parameter of an on-line point along [l]'s direction (-b, a); monotone along
   the line — used to order and intersect on-line vertex intervals. *)
let line_param (l : Geom.line) (p : Geom.point) : Num.t =
  Num.sub (Num.mul l.Geom.a p.Geom.y) (Num.mul l.Geom.b p.Geom.x)

(* The positive-length sub-segment of [h.line] shared by the boundaries of
   [h.fa] and [h.fb], provided the two faces lie in opposite closed half-planes
   — i.e. [h] really hinges adjacent faces. Paper space. None otherwise. *)
let hinge_shared_segment (faces : face array) (h : hinge) :
    (Geom.point * Geom.point) option =
  let fa = faces.(h.fa) and fb = faces.(h.fb) in
  let sides f = Array.map (fun p -> Geom.side_of_line h.line p) f in
  let sa = sides fa and sb = sides fb in
  let all_ge s = Array.for_all (fun x -> x >= 0) s
  and all_le s = Array.for_all (fun x -> x <= 0) s in
  if not ((all_ge sa && all_le sb) || (all_le sa && all_ge sb)) then None
  else
    (* a convex face meets the line in at most one boundary edge: the interval
       of its on-line vertices, ordered by [line_param] *)
    let interval f =
      let on =
        Array.to_list f
        |> List.filter (fun p -> Geom.side_of_line h.line p = 0)
        |> List.map (fun p -> (line_param h.line p, p))
      in
      match on with
      | [] | [ _ ] -> None
      | tp :: tps ->
          let lo =
            List.fold_left
              (fun a b -> if Num.compare (fst b) (fst a) < 0 then b else a)
              tp tps
          in
          let hi =
            List.fold_left
              (fun a b -> if Num.compare (fst b) (fst a) > 0 then b else a)
              tp tps
          in
          if Num.compare (fst lo) (fst hi) < 0 then Some (lo, hi) else None
    in
    match (interval fa, interval fb) with
    | Some (la, ha), Some (lb, hb) ->
        let lo = if Num.compare (fst la) (fst lb) >= 0 then la else lb in
        let hi = if Num.compare (fst ha) (fst hb) <= 0 then ha else hb in
        if Num.compare (fst lo) (fst hi) < 0 then Some (snd lo, snd hi)
        else None
    | _ -> None

exception V of violation

let check_structure ~(faces : face array) ~(hinges : hinge array) ~(root : int)
    ~(rank : int array) : unit =
  let n = Array.length faces in
  if root < 0 || root >= n then
    raise (V (Bad_index (Printf.sprintf "root %d" root)));
  Array.iteri
    (fun i (h : hinge) ->
      if h.fa < 0 || h.fa >= n || h.fb < 0 || h.fb >= n || h.fa = h.fb then
        raise (V (Bad_index (Printf.sprintf "hinge %d (%d|%d)" i h.fa h.fb)));
      if
        not
          (Num.equal h.angle Num.zero || Num.equal h.angle Num.one
          || Num.equal h.angle (Num.neg Num.one))
      then raise (V (Bad_angle i)))
    hinges;
  if Array.length rank <> n then raise (V Bad_rank);
  let hit = Array.make n false in
  Array.iter
    (fun r ->
      if r < 0 || r >= n || hit.(r) then raise (V Bad_rank) else hit.(r) <- true)
    rank

let make ~(faces : face array) ~(hinges : hinge array) ~(root : int)
    ~(rank : int array) : (t, violation) result =
  try
    check_structure ~faces ~hinges ~root ~rank;
    let isos, seen = derive_isos ~faces ~hinges ~root in
    Array.iteri (fun i s -> if not s then raise (V (Disconnected i))) seen;
    (* hinge adjacency: each hinge's line must carry a positive-length shared
       boundary segment between its faces (paper space); the segments feed the
       non-crossing checks (Task 6) *)
    let (_ : (Geom.point * Geom.point) array) =
      Array.mapi
        (fun i h ->
          match hinge_shared_segment faces h with
          | Some s -> s
          | None -> raise (V (Hinge_not_shared i)))
        hinges
    in
    Ok
      {
        faces = Array.copy faces;
        hinges = Array.copy hinges;
        root;
        rank = Array.copy rank;
        isos;
      }
  with V v -> Error v

let faces (g : t) : face array = Array.copy g.faces
let hinges (g : t) : hinge array = Array.copy g.hinges
let root (g : t) : int = g.root
let rank (g : t) : int array = Array.copy g.rank
let above (g : t) (i : int) (j : int) : bool = g.rank.(i) > g.rank.(j)
let face_isos (g : t) : I3.t array = Array.copy g.isos
let face_iso (g : t) (i : int) : I3.t = g.isos.(i)
