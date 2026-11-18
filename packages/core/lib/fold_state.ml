(** The 3D-native folded-state core (issue #48). Faces = 2D paper polygons; hinges = the face-adjacency graph. A
    face's 3D placement is DERIVED as the product of hinge motions along a path
    from the root, so adjacent faces differ by exactly their hinge's motion and
    a torn state cannot be written down. Layer order is one side per pair of
    overlapping faces and M/V is derived from it (never stored). Flat-first: hinge angle (dihedral/π) ∈
    {0, ±1}; |angle|=1 folds via a half-turn about the crease line (= the 2D
    reflection on z=0), reproducing today's flat folds. General rπ is Stage B. *)

module I3 = Isometry3

type face = Geom.point array

type assign = M | V | F

type hinge = {
  fa : int;
  fb : int;
  line : Geom.line;
  angle : Num.t;
  crease_id : int;  (* internal identity; unique within a state, never serialized *)
  prov : State.provenance option;
}

type mark_geom = MSeg of Geom.point * Geom.point | MPoint of Geom.point

(* Paper-space, fold-invariant reference/pinch record (moved verbatim from the
   old [Fold_state]; see that module's doc comment). No invariants of its own. *)
type mark = {
  mgeom : mark_geom;
  mline : Geom.line;
  mintent : assign;
  mcrease_id : int;
  mprov : State.provenance option;
}

type t = {
  faces : face array;
  hinges : hinge array;
  root : int;
  order : Bytes.t;
      (* the layer order (MODEL def-flat-state): entry [i * n + j] is
         [above] when face [i] lies above face [j], [below] when it lies
         below, [apart] when their flat projections do not overlap. An entry
         and its transpose are opposite. *)
  base : Isometry3.t;  (* placement of the root face: ONE whole-sheet motion *)
  marks : mark array;
  isos : Isometry3.t array;  (* derived in [make] (memoized BFS); [t] abstract ⇒ cannot desync *)
  segs : (Geom.point * Geom.point) array;
      (* per-hinge shared paper segment; exposed via [hinge_segment] *)
  tps : Geom.point array array;
      (* per-face flat projection under [isos], derived in [make]; applying
         the placement to every vertex is exact arithmetic, and the layer
         queries ([rel], the scope searches, the emitted [faceOrders]) read
         every face's projection many times per state *)
}

(* Mints internal crease ids; reset per evaluation so ids are a deterministic
   function of the program. *)
let next_id = ref 0
let reset_ids () = next_id := 0
let next_id_value () = !next_id
let set_next_id n = next_id := n
let fresh_crease_id () =
  let id = !next_id in
  incr next_id;
  id

(* The most classes of undecided sides a placed fold searches; the search
   validates 2^k stackings for k classes. Ceiling: a fold beyond it fails
   with [Too_many_undecided]. The upgrade is to propagate the taco-taco
   condition and the flat-hinge form of taco-tortilla before the search, as
   the taco-tortilla condition is now, so that fewer classes stay open. *)
let max_undecided = 10

type violation =
  | Bad_index of string
  | Bad_rank
  | Bad_angle of int
  | Bad_line of int
  | Disconnected of int
  | Hinge_not_shared of int
  | Hinge_not_closed of int
  | Taco_tortilla of { tortilla : int; hinge : int }
  | Taco_taco of int * int
  | Several_stackings of int
  | Too_many_undecided of int
  | Layer_cycle
  | Bad_order of int * int

let violation_to_string = function
  | Bad_index s -> "fold graph: index out of range: " ^ s
  | Bad_rank -> "fold graph: rank is not a permutation of the faces"
  | Bad_angle i ->
      Printf.sprintf "fold graph: hinge %d angle outside {0, ±1} (flat-first)" i
  | Bad_line i ->
      Printf.sprintf "fold graph: hinge %d has a degenerate line (a = b = 0)" i
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
  | Several_stackings n ->
      Printf.sprintf
        "layer ordering: the moved layers fold flat in %d stackings; nothing \
         in the state decides on which side of them some layers they land on \
         lie"
        n
  | Too_many_undecided k ->
      Printf.sprintf
        "layer ordering: the moved layers land on %d groups of layers whose \
         side nothing decides; the kernel searches at most %d"
        k max_undecided
  | Layer_cycle ->
      "layer ordering: three layers lie in a cycle where all three overlap"
  | Bad_order (i, j) ->
      Printf.sprintf
        "fold graph: the order of faces %d and %d is given twice, given though \
         they do not overlap, or missing though they do"
        i j

(* 3D half-turn about a 2D line embedded in z = 0. *)
let half_turn3_of_line (l : Geom.line) : I3.t =
  let on =
    if Num.sign l.Geom.a <> 0 then
      { I3.x = Num.div l.Geom.c l.Geom.a; y = Num.zero; z = Num.zero }
    else { I3.x = Num.zero; y = Num.div l.Geom.c l.Geom.b; z = Num.zero }
  in
  let dir = { I3.x = Num.neg l.Geom.b; y = l.Geom.a; z = Num.zero } in
  I3.half_turn_about_line ~on ~dir

(* 3D motion a folded hinge applies (in the sheet frame): a half-turn about the
   crease line embedded in the z=0 plane. Flat crease (angle=0) → identity.
   Flat-first: |angle|=1 → half-turn; the sign (M vs V) does NOT change the flat
   placement (±π about the same axis coincide): M/V is the layer order. *)
let hinge_motion (h : hinge) : I3.t =
  if Num.sign h.angle = 0 then I3.identity else half_turn3_of_line h.line

(* Derived placements: BFS from [root] over the hinge graph; crossing a hinge
   composes its motion onto the already-placed face's placement. [hinge_motion]
   is oriented fa→[fb] (iso.([fb]) = compose iso.(fa) ([hinge_motion] h)); crossing
   fb→fa uses the inverse. Flat-first the two coincide (half-turns are
   involutions), but the direction-awareness is what keeps this (and the
   uniform closure check in [make]) valid for Stage B's non-involutive rπ
   rotations. [seen] doubles as the connectivity witness. *)
let derive_isos ~(faces : face array) ~(hinges : hinge array) ~(root : int)
    ~(base : I3.t) : I3.t array * bool array =
  let n = Array.length faces in
  let iso = Array.make n I3.identity in
  let seen = Array.make n false in
  let queue = Queue.create () in
  seen.(root) <- true;
  iso.(root) <- base;
  Queue.push root queue;
  while not (Queue.is_empty queue) do
    let fi = Queue.pop queue in
    Array.iter
      (fun h ->
        let step other motion =
          if not seen.(other) then begin
            seen.(other) <- true;
            iso.(other) <- I3.compose iso.(fi) motion;
            Queue.push other queue
          end
        in
        if h.fa = fi then step h.fb (hinge_motion h)
        else if h.fb = fi then step h.fa (I3.inverse (hinge_motion h)))
      hinges
  done;
  (iso, seen)

(* Parameter of an on-line point along [l]'s direction (-b, a); monotone along
   the line: used to order and intersect on-line vertex intervals. *)
let line_param (l : Geom.line) (p : Geom.point) : Num.t =
  Num.sub (Num.mul l.Geom.a p.Geom.y) (Num.mul l.Geom.b p.Geom.x)

(* The positive-length sub-segment of [h.line] shared by the boundaries of
   [h.fa] and [h.fb], provided the two faces lie in opposite closed half-planes
  : i.e. [h] hinges adjacent faces. Paper space. None otherwise. *)
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

let to3 (p : Geom.point) : I3.point = { I3.x = p.Geom.x; y = p.Geom.y; z = Num.zero }
let to2 (p : I3.point) : Geom.point = { Geom.x = p.I3.x; y = p.I3.y }

(* In-plane 2D restriction of a derived placement. Flat-first the motions
   keep z = 0 invariant (angles ∈ {0, ±1}), so the upper-left block +
   ([tx], [ty]) IS the table placement as a 2D isometry. Stage B (partial angles)
   lifts faces off the plane and must not use this. *)
let iso2_of_iso3 (m : I3.t) : Isometry.t =
  { Isometry.m00 = m.I3.m00; m01 = m.I3.m01; m10 = m.I3.m10; m11 = m.I3.m11;
    tx = m.I3.tx; ty = m.I3.ty }

(* Flat projection of face [i] under its derived placement. *)
let project (faces : face array) (isos : I3.t array) (i : int) :
    Geom.point array =
  Array.map (Isometry.apply_point (iso2_of_iso3 isos.(i))) faces.(i)

(* CCW-normalized projection (the input itself when it is already CCW): a
   reflected placement reverses the winding, and the clip/crossing helpers
   in Geom require CCW input. *)
let ccw (tp : Geom.point array) : Geom.point array =
  if Num.sign (Geom.signed_area tp) < 0 then begin
    let n = Array.length tp in
    Array.init n (fun k -> tp.(n - 1 - k))
  end
  else tp

(* The entries of [t.order]. *)
let apart = '\000'
let above_c = '\001'
let below_c = '\002'

(* +1 when face [i] lies above face [j], -1 when below, 0 when the two do
   not overlap. *)
let side_in (order : Bytes.t) (n : int) (i : int) (j : int) : int =
  match Bytes.unsafe_get order ((i * n) + j) with
  | '\001' -> 1
  | '\002' -> -1
  | _ -> 0

(* Does [c] overlap [a] and [b] and lie between them? *)
let between (order : Bytes.t) (n : int) (a : int) (c : int) (b : int) : bool =
  let s = side_in order n c a and t = side_in order n c b in
  s <> 0 && t <> 0 && s <> t

exception V of violation

(* The structure checks that read no rank: root and hinge indices, the angle
   domain and line non-degeneracy, in that order. *)
let check_hinges ~(faces : face array) ~(hinges : hinge array) ~(root : int) :
    unit =
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
      then raise (V (Bad_angle i));
      if Num.sign h.line.Geom.a = 0 && Num.sign h.line.Geom.b = 0 then
        raise (V (Bad_line i)))
    hinges

(* [rank] is a permutation of the [n] faces. *)
let check_rank (n : int) (rank : int array) : unit =
  if Array.length rank <> n then raise (V Bad_rank);
  let hit = Array.make n false in
  Array.iter
    (fun r ->
      if r < 0 || r >= n || hit.(r) then raise (V Bad_rank) else hit.(r) <- true)
    rank

(* What [geometry] derives once a face set is connected and its hinges
   close: per face its placement and flat projection (and that projection
   counter-clockwise), per hinge its shared paper segment, that segment on
   the table, and whether it is folded. The two predicate tables hold, per
   hinge and face, whether the hinge's table segment crosses the face's
   interior, and per hinge pair whether their table segments lie on one
   line and overlap, and per face pair whether their flat projections
   overlap in positive area ([p_overlap], read at [i] < [j]); an entry is
   computed the first time a check reads it. *)
type placed = {
  p_isos : I3.t array;
  p_segs : (Geom.point * Geom.point) array;
  p_tps : Geom.point array array;
  p_ccw_tps : Geom.point array array;
  p_tsegs : (Geom.point * Geom.point) array;
  p_folded : bool array;
  p_crosses : bool option array array;
  p_overlaps : bool option array array;
  p_overlap : bool option array array;
}

type geometry = {
  g_faces : face array;
  g_hinges : hinge array;
  g_root : int;
  g_base : I3.t;
  g_placed : (placed, violation) result;
      (* [Error] holds the first of connectivity, hinge adjacency and cycle
         closure that fails; [with_rank] reports it after the rank check, in
         the order [make] documents *)
}

(* The placed half of a geometry. Raises the first of connectivity, hinge
   adjacency and cycle closure that fails. *)
let place ~(faces : face array) ~(hinges : hinge array) ~(root : int)
    ~(base : I3.t) : placed =
  let isos, seen = derive_isos ~faces ~hinges ~root ~base in
  Array.iteri (fun i s -> if not s then raise (V (Disconnected i))) seen;
  (* hinge adjacency: each hinge's line must carry a positive-length shared
     boundary segment between its faces (paper space); the segments feed the
     non-crossing checks *)
  let segs =
    Array.mapi
      (fun i h ->
        match hinge_shared_segment faces h with
        | Some s -> s
        | None -> raise (V (Hinge_not_shared i)))
      hinges
  in
  (* cycle closure: the BFS fixed a spanning tree; every hinge must agree
     with the placements: for non-tree (cycle) hinges this is the real
     tear check. Tree hinges hold by construction in both traversal
     directions (a fb→fa step assigns iso.(fa) = iso.(fb) ∘ motion⁻¹, which
     is equivalent to this fa→fb equation), so the uniform check does not
     depend on motions being involutions. *)
  Array.iteri
    (fun i h ->
      if
        not
          (I3.equal isos.(h.fb) (I3.compose isos.(h.fa) (hinge_motion h)))
      then raise (V (Hinge_not_closed i)))
    hinges;
  let n = Array.length faces and m = Array.length hinges in
  let tps = Array.init n (project faces isos) in
  let tsegs =
    Array.mapi
      (fun i (p, q) ->
        let place = isos.(hinges.(i).fa) in
        (to2 (I3.apply_point place (to3 p)), to2 (I3.apply_point place (to3 q))))
      segs
  in
  { p_isos = isos; p_segs = segs; p_tps = tps; p_ccw_tps = Array.map ccw tps;
    p_tsegs = tsegs;
    p_folded = Array.map (fun h -> Num.sign h.angle <> 0) hinges;
    p_crosses = Array.init m (fun _ -> Array.make n None);
    p_overlaps = Array.init m (fun _ -> Array.make m None);
    p_overlap = Array.init n (fun _ -> Array.make n None) }

let geometry ?(base = I3.identity) ~(faces : face array) ~(hinges : hinge array)
    ~(root : int) () : (geometry, violation) result =
  try
    check_hinges ~faces ~hinges ~root;
    let faces = Array.map Array.copy faces and hinges = Array.copy hinges in
    let g_placed =
      try Ok (place ~faces ~hinges ~root ~base) with V v -> Error v
    in
    Ok { g_faces = faces; g_hinges = hinges; g_root = root; g_base = base;
         g_placed }
  with V v -> Error v

(* [table.(i).(j)], computed by [f] on first read. *)
let memo (table : bool option array array) (i : int) (j : int) (f : unit -> bool)
    : bool =
  match table.(i).(j) with
  | Some b -> b
  | None ->
      let b = f () in
      table.(i).(j) <- Some b;
      b

(* Whether faces [i] and [j] overlap on the table in positive area
   ([Geom.convex_overlap]: touching is not overlap). *)
let overlap_in (p : placed) (i : int) (j : int) : bool =
  i <> j
  &&
  let i, j = if i < j then (i, j) else (j, i) in
  memo p.p_overlap i j (fun () ->
      Geom.convex_overlap p.p_ccw_tps.(i) p.p_ccw_tps.(j))

(* The part of convex CCW [p] inside convex CCW [q]: [p] clipped to the
   inner side of every edge of [q], [||] when no area remains. *)
let clip_convex (p : Geom.point array) (q : Geom.point array) : Geom.point array =
  let n = Array.length q in
  let k = Num.of_int n in
  let sum f = Array.fold_left (fun a v -> Num.add a (f v)) Num.zero q in
  let inner =
    { Geom.x = Num.div (sum (fun v -> v.Geom.x)) k;
      y = Num.div (sum (fun v -> v.Geom.y)) k }
  in
  let acc = ref p in
  for i = 0 to n - 1 do
    if Array.length !acc > 0 then begin
      let l = Geom.line_through q.(i) q.((i + 1) mod n) in
      acc := Geom.clip_convex_halfplane l (Geom.side_of_line l inner) !acc
    end
  done;
  !acc

(* Whether faces [i], [j] and [k] share a region of the table of positive
   area: [i] clipped to [j], and the result against [k], exactly. *)
let share_region (p : placed) (i : int) (j : int) (k : int) : bool =
  let r = clip_convex p.p_ccw_tps.(i) p.p_ccw_tps.(j) in
  Array.length r >= 3
  && Num.sign (Geom.signed_area r) <> 0
  && Geom.convex_overlap p.p_ccw_tps.(k) r

(* The conditions of a non-crossing order that speak about hinges
   [hull2020 §6.5; hullzakharevich2023 §2.1], over the flat projection. Each
   compares the sides of faces that overlap where they are compared:
   [between] answers only for a face that overlaps both others. [order] may
   leave the side of an overlapping pair open, as [apart]; [decided i j] is
   false for such a pair, and no condition fails on a side that is open. *)
let check_tacos ?(decided = fun _ _ -> true) (geo : geometry) (p : placed)
    (order : Bytes.t) : unit =
  let hinges = geo.g_hinges in
  let n = Array.length geo.g_faces in
  let between = between order n in
  let crosses i c =
    memo p.p_crosses i c (fun () ->
        Geom.segment_crosses_interior p.p_tsegs.(i) p.p_ccw_tps.(c))
  in
  let overlaps i j =
    memo p.p_overlaps i j (fun () ->
        Geom.segments_overlap_collinear p.p_tsegs.(i) p.p_tsegs.(j))
  in
  (* taco-tortilla: a folded hinge's faces coincide after the fold (they
     share the crease edge and fold to the same side), forming a taco; no
     face that crosses the crease's interior may lie between them *)
  Array.iteri
    (fun i h ->
      if p.p_folded.(i) then
        for c = 0 to n - 1 do
          if c <> h.fa && c <> h.fb && between h.fa c h.fb && crosses i c then
            raise (V (Taco_tortilla { tortilla = c; hinge = i }))
        done)
    hinges;
  (* taco-taco: two folded hinges over disjoint face pairs whose crease
     segments coincide on the table must not interleave in the stack. Two
     tacos that open to opposite sides of the line share no region, and
     [between] is false for them. *)
  let m = Array.length hinges in
  for i = 0 to m - 1 do
    for j = i + 1 to m - 1 do
      let h1 = hinges.(i) and h2 = hinges.(j) in
      let a = h1.fa and b = h1.fb and c = h2.fa and d = h2.fb in
      if
        p.p_folded.(i) && p.p_folded.(j)
        && a <> c && a <> d && b <> c && b <> d
        && overlaps i j
        && decided a c && decided c b && decided a d && decided d b
        && between a c b <> between a d b
      then raise (V (Taco_taco (i, j)))
    done
  done;
  (* taco-tortilla, flat-hinge form: a FLAT hinge's two faces are one
     continuous sheet crossing its own segment. Where that segment lies
     collinear on a folded hinge's crease, the taco's leaves meet in a
     closed joint spanning the mouth: a sheet crossing the axis there may
     pass entirely OUTSIDE the mouth (wrapping the joint is fine), but any
     crossing face that lies strictly inside the mouth goes through the
     joint. The interior-crossing form above cannot see this: each sheet
     face only ABUTS the crease segment (it lies on their shared edge),
     never crosses it alone. Found via the two-ear fish base, both ears
     (toward .d): a ghost seated one wing under the stationary strip with
     its ear above: front paper visibly sandwiched inside the ear's taco. *)
  for i = 0 to m - 1 do
    for j = 0 to m - 1 do
      let h1 = hinges.(i) and h2 = hinges.(j) in
      let a = h1.fa and b = h1.fb and c = h2.fa and d = h2.fb in
      if
        p.p_folded.(i) && (not p.p_folded.(j)) && d >= 0
        && a <> c && a <> d && b <> c && b <> d
        && overlaps i j
        && (between a c b || between a d b)
      then raise (V (Taco_tortilla { tortilla = c; hinge = i }))
    done
  done

(* The order condition (MODEL cond-order): no three faces that share a
   region lie in a cycle. Three faces suffice: the faces over one point of
   the table overlap pairwise, and an order of pairwise comparable faces
   has a cycle only if it has one of three. Only a cyclic triple costs an
   exact intersection. *)
let check_cycles (p : placed) (order : Bytes.t) (n : int) : unit =
  for i = 0 to n - 1 do
    for j = i + 1 to n - 1 do
      let s = side_in order n i j in
      if s <> 0 then
        for k = j + 1 to n - 1 do
          if
            side_in order n j k = s
            && side_in order n k i = s
            && share_region p i j k
          then raise (V Layer_cycle)
        done
    done
  done

(* The state of [geo] in which, of two overlapping faces [i] < [j], [i] lies
   above [j] iff [side i j]. Raises [V]: a violation the geometry holds,
   then the conditions on hinges, then, with [cycles], the order condition.
   A caller passes [cycles:false] where [side] cannot hold a cycle: it
   compares heights, or it copies the sides of a state, and [tacos:false]
   where the conditions on hinges hold by construction. *)
let build ?(marks = [||]) ?(tacos = true) ~(cycles : bool) (geo : geometry)
    ~(side : int -> int -> bool) : t =
  let n = Array.length geo.g_faces in
  let p = match geo.g_placed with Ok p -> p | Error v -> raise (V v) in
  let order = Bytes.make (n * n) apart in
  for i = 0 to n - 1 do
    for j = i + 1 to n - 1 do
      if overlap_in p i j then begin
        let up = side i j in
        Bytes.unsafe_set order ((i * n) + j) (if up then above_c else below_c);
        Bytes.unsafe_set order ((j * n) + i) (if up then below_c else above_c)
      end
    done
  done;
  if tacos then check_tacos geo p order;
  if cycles then check_cycles p order n;
  {
    faces = Array.map Array.copy geo.g_faces;
    hinges = Array.copy geo.g_hinges;
    root = geo.g_root;
    order;
    base = geo.g_base;
    marks = Array.copy marks;
    isos = p.p_isos;
    segs = p.p_segs;
    tps = p.p_tps;
  }

let with_rank ?(marks = [||]) (geo : geometry) ~(rank : int array) :
    (t, violation) result =
  try
    check_rank (Array.length geo.g_faces) rank;
    Ok (build ~marks ~cycles:false geo ~side:(fun i j -> rank.(i) > rank.(j)))
  with V v -> Error v

let with_order ?(marks = [||]) (geo : geometry) ~(above : (int * int) list) :
    (t, violation) result =
  try
    let n = Array.length geo.g_faces in
    let given = Hashtbl.create 64 in
    List.iter
      (fun (i, j) ->
        if i < 0 || i >= n || j < 0 || j >= n || i = j then
          raise (V (Bad_index (Printf.sprintf "order (%d|%d)" i j)));
        let key = if i < j then (i, j) else (j, i) in
        if Hashtbl.mem given key then raise (V (Bad_order (fst key, snd key)));
        Hashtbl.replace given key (i < j))
      above;
    (match geo.g_placed with
    | Error v -> raise (V v)
    | Ok p ->
        Hashtbl.iter
          (fun (i, j) _ -> if not (overlap_in p i j) then raise (V (Bad_order (i, j))))
          given);
    Ok
      (build ~marks ~cycles:true geo ~side:(fun i j ->
           match Hashtbl.find_opt given (i, j) with
           | Some up -> up
           | None -> raise (V (Bad_order (i, j)))))
  with V v -> Error v

(* Every layer order of [geo] that keeps the sides [kept] gives, puts [i]
   above [j] for each [(i, j)] of [fixed], and satisfies the conditions of
   [with_order]. [kept i j], asked for two overlapping faces [i] < [j], is
   [Some up] where the caller knows the side ([i] above [j] iff [up]) and
   [None] where the search decides it.

   The search relates the open sides before it tries any: a face that covers
   part of a hinge's crease lies on one side of both faces of the hinge, the
   taco-tortilla condition at a folded hinge and one uncreased sheet at a
   flat one (MODEL cond-taco-tortilla, def-flat-state). The sides this leaves
   open fall into classes that turn together. The classes are set one after
   the other, and a partial order that breaks a condition among the sides
   set so far is given up. Ceiling: the order condition and the taco-taco
   condition only reject, they set no side, so the work doubles with every
   class that neither rejects. *)
let orders ?(marks = [||]) (geo : geometry) ~(kept : int -> int -> bool option)
    ~(fixed : (int * int) list) : (t list, violation) result =
  match geo.g_placed with
  | Error v -> Error v
  | Ok p -> (
      let n = Array.length geo.g_faces in
      let order = Bytes.make (n * n) apart in
      let set i j up =
        Bytes.unsafe_set order ((i * n) + j) (if up then above_c else below_c);
        Bytes.unsafe_set order ((j * n) + i) (if up then below_c else above_c)
      in
      let clear i j =
        Bytes.unsafe_set order ((i * n) + j) apart;
        Bytes.unsafe_set order ((j * n) + i) apart
      in
      let is_open = Array.make_matrix n n false in
      let pairs = ref [] in
      for i = n - 1 downto 0 do
        for j = n - 1 downto i + 1 do
          if overlap_in p i j then
            match kept i j with
            | Some up -> set i j up
            | None ->
                is_open.(i).(j) <- true;
                is_open.(j).(i) <- true;
                pairs := (i, j) :: !pairs
        done
      done;
      let pairs = !pairs in
      (* "[x] above [y]" for two overlapping faces *)
      let lit x y =
        if is_open.(x).(y) then
          if x < y then Layer_sides.Side ((x, y), false)
          else Layer_sides.Side ((y, x), true)
        else Layer_sides.Known (side_in order n x y > 0)
      in
      let uf = Layer_sides.create () in
      let ( let* ) = Result.bind in
      let crosses h c =
        memo p.p_crosses h c (fun () ->
            Geom.segment_crosses_interior p.p_tsegs.(h) p.p_ccw_tps.(c))
      in
      let related =
        let* () =
          List.fold_left
            (fun acc (i, j) ->
              let* () = acc in
              if i <> j && overlap_in p i j then
                Layer_sides.relate uf (lit i j) (Layer_sides.Known true) ~why:()
              else Error ())
            (Ok ()) fixed
        in
        let acc = ref (Ok ()) in
        Array.iteri
          (fun hi (h : hinge) ->
            for c = 0 to n - 1 do
              if
                !acc = Ok () && c <> h.fa && c <> h.fb
                && (is_open.(c).(h.fa) || is_open.(c).(h.fb))
                && overlap_in p c h.fa && overlap_in p c h.fb && crosses hi c
              then acc := Layer_sides.relate uf (lit c h.fa) (lit c h.fb) ~why:()
            done)
          geo.g_hinges;
        !acc
      in
      match related with
      | Error () -> Ok []
      | Ok () ->
          let decided, free = Layer_sides.classes uf pairs in
          List.iter (fun ((i, j), up) -> set i j up) decided;
          let free = Array.of_list free in
          let k = Array.length free in
          let pending = Array.make_matrix n n false in
          let mark cls b =
            List.iter
              (fun ((i, j), _) ->
                pending.(i).(j) <- b;
                pending.(j).(i) <- b)
              cls
          in
          Array.iter (fun cls -> mark cls true) free;
          let is_decided i j = not pending.(i).(j) in
          (* no three faces that share a region lie in a cycle through the
             pair [(i, j)] *)
          let acyclic_at i j =
            let s = side_in order n i j in
            let ok = ref true in
            for c = 0 to n - 1 do
              if
                !ok && c <> i && c <> j
                && side_in order n j c = s
                && side_in order n c i = s
                && share_region p i j c
              then ok := false
            done;
            !ok
          in
          let tacos_ok () =
            match check_tacos ~decided:is_decided geo p order with
            | () -> true
            | exception V _ -> false
          in
          let found = ref [] in
          let state () =
            {
              faces = Array.map Array.copy geo.g_faces;
              hinges = Array.copy geo.g_hinges;
              root = geo.g_root;
              order = Bytes.copy order;
              base = geo.g_base;
              marks = Array.copy marks;
              isos = p.p_isos;
              segs = p.p_segs;
              tps = p.p_tps;
            }
          in
          let rec go d =
            if d = k then found := state () :: !found
            else
              List.iter
                (fun on ->
                  List.iter (fun ((i, j), v) -> set i j (v = on)) free.(d);
                  mark free.(d) false;
                  if
                    List.for_all (fun ((i, j), _) -> acyclic_at i j) free.(d)
                    && tacos_ok ()
                  then go (d + 1);
                  List.iter (fun ((i, j), _) -> clear i j) free.(d);
                  mark free.(d) true)
                [ false; true ]
          in
          let start_ok =
            tacos_ok ()
            && match check_cycles p order n with () -> true | exception V _ -> false
          in
          if start_ok then go 0;
          Ok (List.rev !found))

(* [?base]/[?marks] are LEADING optional arguments with only labeled
   required arguments after them; OCaml can only erase omitted optional
   arguments when a positional argument follows, so [make] takes a trailing
   [unit] to anchor that: existing call sites add a trailing [()]. *)
let make ?(base = I3.identity) ?(marks = [||]) ~(faces : face array)
    ~(hinges : hinge array) ~(root : int) ~(rank : int array) () :
    (t, violation) result =
  match geometry ~base ~faces ~hinges ~root () with
  | Error v -> Error v
  | Ok geo -> with_rank ~marks geo ~rank

let faces (g : t) : face array = Array.map Array.copy g.faces
let hinges (g : t) : hinge array = Array.copy g.hinges
let root (g : t) : int = g.root

(* +1 when face [i] lies above face [j], -1 when below, 0 when apart. *)
let side (g : t) (i : int) (j : int) : int =
  side_in g.order (Array.length g.faces) i j

let above (g : t) (i : int) (j : int) : bool = side g i j > 0

let order (g : t) : (int * int) list =
  let n = Array.length g.faces in
  let acc = ref [] in
  for i = n - 1 downto 0 do
    for j = n - 1 downto 0 do
      if side g i j > 0 then acc := (i, j) :: !acc
    done
  done;
  !acc

let same_order (a : t) (b : t) : bool = Bytes.equal a.order b.order
let face_isos (g : t) : I3.t array = Array.copy g.isos
let face_iso (g : t) (i : int) : I3.t = g.isos.(i)
let base (g : t) : I3.t = g.base
let marks (g : t) : mark array = Array.copy g.marks

(* Does face [i]'s derived placement preserve in-plane orientation? The
   motions here map the z=0 plane to itself with 3D determinant +1 (identity,
   half-turns about in-plane axes, and their products), so the in-plane
   determinant equals the m22 entry: +1 for an even number of folds crossed,
   -1 for odd (a reflected, face-down placement). *)
let face_up (g : t) (i : int) : bool = Num.sign g.isos.(i).I3.m22 > 0

(* Derived M/V of hinge [i] [hullzakharevich2023, §2.1]: for a crease between
   U1 and U2 with U1's orientation preserved, the crease is a valley iff U1
   lies below U2 (the paper's λ(p,q) = 1 reads "p below q"). Here: V ⟺
   above([fb], fa) = [face_up](fa). Side-symmetric: read from [fb], BOTH sides of
   the equality negate (above by antisymmetry, [face_up] because a folded
   hinge separates one face-up from one face-down placement), so both
   readings give the same M/V. Flat hinges
   (angle = 0) derive F. Derived, never stored: the order and placements are
   the only inputs, so MV cannot contradict the geometry. Stage B: partial
   angles (rπ) make m22 = cos(rπ) ≠ ±1 and "folded" non-binary: both this
   and [face_up] need revisiting when the angle domain widens (until then
   [make]'s [Bad_angle] check keeps them unreachable). *)
let mv (g : t) (i : int) : assign =
  let h = g.hinges.(i) in
  if Num.sign h.angle = 0 then F
  else if above g h.fb h.fa = face_up g h.fa then V else M

(* In-plane 2D restriction of face [i]'s derived placement (see
   [iso2_of_iso3] for why that restriction is the table placement). *)
let face_iso2 (g : t) (i : int) : Isometry.t = iso2_of_iso3 g.isos.(i)

let table_polygon (g : t) (i : int) : Geom.point array = Array.copy g.tps.(i)

let table_polygon_ccw (g : t) (i : int) : Geom.point array =
  ccw (table_polygon g i)

type rel = Above | Below | Apart

(* Layer relation of two faces: their stored side where the flat projections
   overlap, Apart otherwise. *)
let rel (g : t) (i : int) (j : int) : rel =
  match side g i j with 1 -> Above | -1 -> Below | _ -> Apart

let hinge_segment (g : t) (i : int) : Geom.point * Geom.point = g.segs.(i)

let hinge_table_segment (g : t) (i : int) : Geom.point * Geom.point =
  let a, b = g.segs.(i) in
  let iso = face_iso2 g g.hinges.(i).fa in
  (Isometry.apply_point iso a, Isometry.apply_point iso b)

(* Current table position of a material paper point: faces partition the paper
   and placements agree on shared hinges, so any containing face works. *)
let table_position (g : t) (paper : Geom.point) : Geom.point =
  let n = Array.length g.faces in
  let rec find i =
    if i >= n then invalid_arg "Fold_state.table_position: point in no face"
    else if Geom.in_convex_polygon g.faces.(i) paper then
      Isometry.apply_point (face_iso2 g i) paper
    else find (i + 1)
  in
  find 0

(* Distinct paper coordinates whose current table position is [tp] (one per
   overlapping layer covering that table point). *)
let paper_preimages (g : t) (tp : Geom.point) : Geom.point list =
  let acc = ref [] in
  Array.iteri
    (fun i f ->
      let pp = Isometry.apply_point (Isometry.inverse (face_iso2 g i)) tp in
      if
        Geom.in_convex_polygon f pp
        && not (List.exists (Geom.point_equal pp) !acc)
      then acc := pp :: !acc)
    g.faces;
  List.rev !acc

let on_paper (g : t) (pp : Geom.point) : bool =
  Array.exists (fun f -> Geom.in_convex_polygon f pp) g.faces

(* ------------------------------------------------------------------ *)
(* Construction operations. Each op builds new arrays and             *)
(* re-validates through [make]; a violation raises [Error.fail] at the *)
(* [provenance] span. Faces never carry isometries. A fold only sets   *)
(* hinge angles and the order.                                         *)
(* ------------------------------------------------------------------ *)

let fail_of_violation (prov : State.provenance option) (v : violation) : 'a =
  let span =
    match prov with
    | Some p -> p.State.span
    | None -> (Lexing.dummy_pos, Lexing.dummy_pos)
  in
  Error.fail span (violation_to_string v)

let flat ?(hinges = [||]) ?(marks = [||]) (faces : face array) : t =
  match
    make ~marks ~faces ~hinges ~root:0
      ~rank:(Array.init (Array.length faces) Fun.id) ()
  with
  | Ok g -> g
  | Error v -> invalid_arg ("Fold_state.flat: " ^ violation_to_string v)

(* The chord (in PAPER coordinates) where table-space [axis] crosses the
   interior of an already-placed [table] polygon (face [i]'s table placement,
   [inv] its inverse isometry back to paper); None if it misses (touches at
   most a point). Factored out of [axis_chord_in_face] so a caller that has
   already built [table]/[inv] (e.g. [subdivide]'s [cut_of]) need not rebuild
   them: carry-in cleanup, pure equivalence. *)
let chord_of_table (table : Geom.point array) (inv : Isometry.t)
    (axis : Geom.line) : (Geom.point * Geom.point) option =
  let n = Array.length table in
  let pts = ref [] in
  let add p =
    if not (List.exists (Geom.point_equal p) !pts) then pts := p :: !pts
  in
  for k = 0 to n - 1 do
    let a = table.(k) and b = table.((k + 1) mod n) in
    let sa = Geom.side_of_line axis a and sb = Geom.side_of_line axis b in
    if sa = 0 then add a
    else if sb <> 0 && sa <> sb then
      match Geom.intersection axis (Geom.line_through a b) with
      | Some r -> add r
      | None -> ()
  done;
  match !pts with
  | [ p; q0 ] ->
      (* Canonicalize the pair's order by position along [axis] (not the
         arbitrary boundary-walk order they were found in): the chord only
         feeds the new hinge's line (via [Geom.line_through]) and
         [reattach_hinges]'s adjacency check, both sign-invariant, but a
         stable, deterministic order still matters so the same cut always
         mints the same hinge-line representation. Child order (plus vs
         minus) is decided upstream by clipping [axis] itself, not by this
         chord. *)
      let lo, hi =
        if Num.compare (line_param axis p) (line_param axis q0) <= 0 then
          (p, q0)
        else (q0, p)
      in
      Some (Isometry.apply_point inv lo, Isometry.apply_point inv hi)
  | _ -> None

(* The chord (in PAPER coordinates) where table-space [axis] crosses the
   interior of face [i]; None if it misses (touches at most a point). *)
let axis_chord_in_face (g : t) (i : int) (axis : Geom.line) :
    (Geom.point * Geom.point) option =
  let iso2 = face_iso2 g i in
  let table = Array.map (Isometry.apply_point iso2) g.faces.(i) in
  chord_of_table table (Isometry.inverse iso2) axis

(* Re-attach the old hinges over a face split. [children_of p] lists the child
   indices of old face p (a single element when uncut). A candidate pair keeps
   the hinge iff its line still carries a positive shared boundary segment
   between the two children (D7): degenerate pieces drop out here. *)
let reattach_hinges ~(faces' : face array) ~(children_of : int -> int list)
    (hinges : hinge array) : hinge list =
  Array.to_list hinges
  |> List.concat_map (fun h ->
         List.concat_map
           (fun cp ->
             List.filter_map
               (fun cq ->
                 let h' = { h with fa = cp; fb = cq } in
                 match hinge_shared_segment faces' h' with
                 | Some _ -> Some h'
                 | None -> None)
               (children_of h.fb))
           (children_of h.fa))

(* The state of the faces [faces'] cut from the faces of [g], [parent] giving
   the face each was cut from: two children that overlap lie as their
   parents do. The children of one face do not overlap, and a cycle among
   children would be one among their parents. *)
let inherit_order (g : t) ~(prov : State.provenance option)
    ~(faces' : face array) ~(hinges' : hinge array) ~(root' : int)
    ~(parent : int array) : t =
  match geometry ~base:g.base ~faces:faces' ~hinges:hinges' ~root:root' () with
  | Error v -> fail_of_violation prov v
  | Ok geo -> (
      try
        build ~marks:g.marks ~cycles:false geo ~side:(fun i j ->
            side g parent.(i) parent.(j) > 0)
      with V v -> fail_of_violation prov v)

(* Shared splitter for [subdivide] (table-space axis, optional ray guard) and
   [subdivide_paper] (paper-space line). [cut_of i] gives the PRE-CLIPPED
   paper-space children plus the paper chord for face i, or None to keep it
   whole (the caller decides: not cut, guard-excluded, or a degenerate part
   with fewer than 3 vertices). Children order per parent: plus side first,
   then minus. FOLD emit enumerates faces by array index, so this order is
   observable output, not an implementation detail. Clipping the caller's
   canonical line/axis directly (rather than reconstructing a line from the
   chord via [Geom.line_through], whose sign depends on point order) is what
   keeps that order deterministic. When [cut_of] keeps every face whole,
   [g] itself is the result. *)
let split_with_flat_hinges (g : t) ~(cid : int)
    ~(prov : State.provenance option)
    ~(cut_of :
       int ->
       (Geom.point array * Geom.point array * (Geom.point * Geom.point))
       option) : t =
  let cuts = Array.init (Array.length g.faces) cut_of in
  if Array.for_all Option.is_none cuts then g
  else
  let out = ref [] in (* ([paper_poly], parent): prepended, reversed at the end *)
  let chords = ref [] in (* (parent, a, b) for each cut face *)
  Array.iteri
    (fun fi f ->
      match cuts.(fi) with
      | None -> out := (f, fi) :: !out
      | Some (pp, pm, (a, b)) ->
          chords := (fi, a, b) :: !chords;
          out := (pm, fi) :: (pp, fi) :: !out)
    g.faces;
  let arr = Array.of_list (List.rev !out) in
  let faces' = Array.map fst arr in
  let parent = Array.map snd arr in
  let children_of p =
    let acc = ref [] in
    Array.iteri (fun k pp -> if pp = p then acc := k :: !acc) parent;
    List.rev !acc
  in
  let new_hinges =
    List.rev_map
      (fun (fi, a, b) ->
        match children_of fi with
        | [ cp; cm ] ->
            { fa = cp; fb = cm; line = Geom.line_through a b; angle = Num.zero;
              crease_id = cid; prov }
        | _ -> assert false)
      !chords
  in
  let carried = reattach_hinges ~faces' ~children_of g.hinges in
  let root' = List.hd (children_of g.root) in
  inherit_order g ~prov ~faces' ~hinges':(Array.of_list (new_hinges @ carried))
    ~root' ~parent

let subdivide ?crease_id ?keep_side ?(only = fun _ -> true) (g : t)
    (axis : Geom.line) ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  let on_keep_side fi =
    match keep_side with
    | None -> true
    | Some (guard, keep) ->
        (* table centroid of the face, old [on_keep_side] *)
        let tp = table_polygon g fi in
        let n = Array.length tp in
        let sx = ref Num.zero and sy = ref Num.zero in
        Array.iter
          (fun (p : Geom.point) ->
            sx := Num.add !sx p.Geom.x;
            sy := Num.add !sy p.Geom.y)
          tp;
        let c =
          { Geom.x = Num.div !sx (Num.of_int n); y = Num.div !sy (Num.of_int n) }
        in
        Geom.side_of_line guard c = keep
  in
  (* PLUS child = axis side +1 IN TABLE SPACE (old-model convention): clip the
     face's table placement by [axis] directly, then map each part back to
     paper via the face's own [face_iso2]: never reconstruct a line from the
     chord (its sign would depend on point order, see findings on commit
     1f0436f). *)
  let cut_of fi =
    if not (only fi && on_keep_side fi) then None
    else
      let iso2 = face_iso2 g fi in
      let inv = Isometry.inverse iso2 in
      let map_back = Array.map (Isometry.apply_point inv) in
      let table = Array.map (Isometry.apply_point iso2) g.faces.(fi) in
      let part k =
        let sub = Geom.clip_convex_halfplane axis k table in
        if Array.length sub >= 3 then Some sub else None
      in
      match (part 1, part (-1)) with
      | Some tp, Some tm -> (
          match chord_of_table table inv axis with
          | Some (a, b) -> Some (map_back tp, map_back tm, (a, b))
          | None -> None)
      | _ -> None
  in
  split_with_flat_hinges g ~cid ~prov ~cut_of

(* The splitter of [subdivide_fan]: [cut_of i] gives the paper children of
   face i, and the new flat hinges between them as (child index within the
   list, child index within the list, paper chord, crease id), or None to
   keep the face whole. Returns the new state and the parent of each new
   face. Children follow their parent in the given order, and the new hinges
   precede the carried ones in the order of their faces, as in
   [split_with_flat_hinges]. A new hinge of crease [cid] carries
   [hinge_prov cid], [prov] when it is absent. When [cut_of] keeps every
   face whole, the result is [g] itself with each face its own parent. *)
let split_faces ?hinge_prov (g : t) ~(prov : State.provenance option)
    ~(cut_of :
       int ->
       (face list * (int * int * (Geom.point * Geom.point) * int) list) option)
    : t * int array =
  let n = Array.length g.faces in
  let split = Array.init n cut_of in
  if Array.for_all Option.is_none split then (g, Array.init n Fun.id)
  else
  let hinge_prov = Option.value hinge_prov ~default:(fun _ -> prov) in
  let out = ref [] in
  let cuts = ref [] in
  let next = ref 0 in
  Array.iteri
    (fun fi f ->
      match split.(fi) with
      | None ->
          out := (f, fi) :: !out;
          incr next
      | Some (children, hs) ->
          let first = !next in
          List.iter
            (fun c ->
              out := (c, fi) :: !out;
              incr next)
            children;
          cuts := (first, hs) :: !cuts)
    g.faces;
  let arr = Array.of_list (List.rev !out) in
  let faces' = Array.map fst arr in
  let parent = Array.map snd arr in
  let children_of p =
    let acc = ref [] in
    Array.iteri (fun k pp -> if pp = p then acc := k :: !acc) parent;
    List.rev !acc
  in
  let new_hinges =
    List.concat_map
      (fun (first, hs) ->
        List.map
          (fun (i, j, (a, b), cid) ->
            { fa = first + i; fb = first + j; line = Geom.line_through a b;
              angle = Num.zero; crease_id = cid; prov = hinge_prov cid })
          hs)
      (List.rev !cuts)
  in
  let carried = reattach_hinges ~faces' ~children_of g.hinges in
  let root' = List.hd (children_of g.root) in
  ( inherit_order g ~prov ~faces' ~hinges':(Array.of_list (new_hinges @ carried))
      ~root' ~parent,
    parent )

let subdivide_fan ?(only = fun _ -> true) (g : t) ~(o : Geom.point)
    ~(rays : (int * Geom.line * Geom.point) list)
    ~(prov : State.provenance option) : t =
  let dir (p : Geom.point) =
    (Num.sub p.Geom.x o.Geom.x, Num.sub p.Geom.y o.Geom.y)
  in
  let cross (ax, ay) (bx, by) = Num.sub (Num.mul ax by) (Num.mul ay bx) in
  let dot (ax, ay) (bx, by) = Num.add (Num.mul ax bx) (Num.mul ay by) in
  let offset (dx, dy) =
    { Geom.x = Num.add o.Geom.x dx; y = Num.add o.Geom.y dy }
  in
  let table_of g fi =
    Array.map (Isometry.apply_point (face_iso2 g fi)) g.faces.(fi)
  in
  (* 1. a face that holds O in its interior is cut into the wedges between
     consecutive rays at once: one half-line alone does not divide it into
     convex pieces. The rays then run from O on every face. *)
  let sorted =
    List.sort (fun (_, _, p) (_, _, q) -> Geom.ccw_compare ~center:o p q) rays
    |> Array.of_list
  in
  let k = Array.length sorted in
  let wedges_convex =
    k >= 2
    && Array.for_all Fun.id
         (Array.init k (fun j ->
              let _, _, p = sorted.(j) and _, _, q = sorted.((j + 1) mod k) in
              let c = Num.sign (cross (dir p) (dir q)) in
              c > 0 || (c = 0 && Num.sign (dot (dir p) (dir q)) < 0)))
  in
  let cut_wedges fi =
    let table = table_of g fi and ccw = table_polygon_ccw g fi in
    let n = Array.length ccw in
    if not (wedges_convex && only fi && Geom.in_convex_polygon ccw o
            && Array.for_all
                 (fun i ->
                   not (Geom.on_segment (ccw.(i), ccw.((i + 1) mod n)) o))
                 (Array.init n Fun.id))
    then None
    else
      let inv = Isometry.inverse (face_iso2 g fi) in
      let back = Isometry.apply_point inv in
      let wedge j =
        let _, lj, p = sorted.(j) and _, lk, q = sorted.((j + 1) mod k) in
        let dx, dy = dir p and ex, ey = dir q in
        let left = offset (Num.neg dy, dx)
        and right = offset (ey, Num.neg ex) in
        let poly =
          Geom.clip_convex_halfplane lj (Geom.side_of_line lj left) table
          |> Geom.clip_convex_halfplane lk (Geom.side_of_line lk right)
        in
        Array.map back poly
      in
      let exit_of j =
        let _, l, p = sorted.(j) in
        match Geom.clip_line_to_convex l ccw with
        | Some (a, b) -> if Num.sign (dot (dir a) (dir p)) > 0 then a else b
        | None -> p
      in
      let children = List.init k wedge in
      if List.exists (fun c -> Array.length c < 3) children then None
      else
        Some
          ( children,
            List.init k (fun j ->
                let cid, _, _ = sorted.(j) in
                ((j - 1 + k) mod k, j, (back o, back (exit_of j)), cid)) )
  in
  let g, parent = split_faces g ~prov ~cut_of:cut_wedges in
  let only = Array.map only parent in
  (* 2. every other face a ray crosses between O and its point is cut along
     it, as [subdivide] cuts it: plus child first *)
  let g, _ =
    List.fold_left
      (fun (g, only) (cid, axis, p) ->
        let cut_of fi =
          if not only.(fi) then None
          else
            let table = table_of g fi in
            match Geom.clip_line_to_convex axis (table_polygon_ccw g fi) with
            | Some (a, b)
              when Num.sign (dot (dir a) (dir p)) >= 0
                   && Num.sign (dot (dir b) (dir p)) >= 0
                   && Num.compare (dot (dir a) (dir p)) (dot (dir p) (dir p)) <= 0
                   && Num.compare (dot (dir b) (dir p)) (dot (dir p) (dir p)) <= 0 -> (
                let part s =
                  let sub = Geom.clip_convex_halfplane axis s table in
                  if Array.length sub >= 3 then Some sub else None
                in
                let inv = Isometry.inverse (face_iso2 g fi) in
                match (part 1, part (-1), chord_of_table table inv axis) with
                | Some tp, Some tm, Some chord ->
                    let back = Array.map (Isometry.apply_point inv) in
                    Some ([ back tp; back tm ], [ (0, 1, chord, cid) ])
                | _ -> None)
            | _ -> None
        in
        let g', parent = split_faces g ~prov ~cut_of in
        (g', Array.map (fun p -> only.(p)) parent))
      (g, only) rays
  in
  g

(* Cut faces along several table segments at once. [segments i] gives the
   segments that score face [i], each with its crease id; a face it gives
   none for stays whole. The face's edges and the segments form a planar
   graph, split wherever two of them meet, and the cells of that graph are
   the children: each is traced by turning clockwise at every node, so it
   lies to the left of the edges it is traced along. A face stays whole
   when a segment leaves it, when a cell is not convex, or when a segment
   ends inside a cell. A hinge of crease [cid] carries [crease_prov cid]. *)
let subdivide_segments (g : t)
    ~(segments : int -> (int * (Geom.point * Geom.point)) list)
    ~(crease_prov : int -> State.provenance option)
    ~(prov : State.provenance option) : t =
  let cut_of fi =
    match segments fi with
    | [] -> None
    | segs -> (
        let ccw = table_polygon_ccw g fi in
        let n = Array.length ccw in
        let inside p = Geom.in_convex_polygon ccw p in
        if not (List.for_all (fun (_, (a, b)) -> inside a && inside b) segs) then
          None
        else
          (* the carriers: the face's edges, then the segments *)
          let carriers =
            List.init n (fun i -> (None, (ccw.(i), ccw.((i + 1) mod n))))
            @ List.map (fun (cid, seg) -> (Some cid, seg)) segs
          in
          let nodes = ref [] in
          let add p =
            if not (List.exists (Geom.point_equal p) !nodes) then
              nodes := p :: !nodes
          in
          List.iter
            (fun (_, (a, b)) ->
              add a;
              add b)
            carriers;
          List.iter
            (fun (_, s1) ->
              List.iter
                (fun (_, s2) ->
                  match Geom.segment_intersection s1 s2 with
                  | Some r -> add r
                  | None -> ())
                carriers)
            carriers;
          let nodes = Array.of_list (List.rev !nodes) in
          let m = Array.length nodes in
          (* the edges of the graph: each carrier between consecutive nodes *)
          let edges = Hashtbl.create 64 in
          List.iter
            (fun (cid, (a, b)) ->
              let on =
                List.filter
                  (fun i -> Geom.on_segment (a, b) nodes.(i))
                  (List.init m Fun.id)
                |> List.sort (fun i j ->
                       Num.compare
                         (Geom.seg_param (a, b) nodes.(i))
                         (Geom.seg_param (a, b) nodes.(j)))
              in
              let rec link = function
                | u :: (v :: _ as rest) ->
                    if not (Hashtbl.mem edges (u, v)) then begin
                      Hashtbl.replace edges (u, v) cid;
                      Hashtbl.replace edges (v, u) cid
                    end;
                    link rest
                | _ -> ()
              in
              link on)
            carriers;
          let out = Array.make m [] in
          Hashtbl.iter (fun (u, v) _ -> out.(u) <- v :: out.(u)) edges;
          let out =
            Array.mapi
              (fun u vs ->
                List.sort
                  (fun a b -> Geom.ccw_compare ~center:nodes.(u) nodes.(a) nodes.(b))
                  vs
                |> Array.of_list)
              out
          in
          (* the edge after (u, v) around the cell to its left *)
          let next (u, v) =
            let o = out.(v) in
            let k = Array.length o in
            let i = ref 0 in
            Array.iteri (fun j w -> if w = u then i := j) o;
            (v, o.((!i - 1 + k) mod k))
          in
          let cell_of = Hashtbl.create 64 in
          let cells = ref [] in
          Hashtbl.iter
            (fun e _ ->
              if not (Hashtbl.mem cell_of e) then begin
                let id = List.length !cells in
                let rec walk e acc =
                  Hashtbl.replace cell_of e id;
                  let e' = next e in
                  if Hashtbl.mem cell_of e' then List.rev (fst e :: acc)
                  else walk e' (fst e :: acc)
                in
                cells := (id, walk e []) :: !cells
              end)
            edges;
          let poly ns = Array.of_list (List.map (fun i -> nodes.(i)) ns) in
          (* a cell without the nodes that lie on a straight side *)
          let corners ns =
            let a = Array.of_list ns in
            let k = Array.length a in
            List.filteri
              (fun i _ ->
                let p = nodes.(a.((i - 1 + k) mod k))
                and q = nodes.(a.(i))
                and r = nodes.(a.((i + 1) mod k)) in
                Geom.side_of_line (Geom.line_through p r) q <> 0)
              ns
          in
          let convex ns =
            let a = poly ns in
            let k = Array.length a in
            k >= 3
            && List.length (List.sort_uniq compare ns) = k
            && Array.for_all Fun.id
                 (Array.init k (fun i ->
                      Num.sign
                        (Geom.signed_area
                           [| a.(i); a.((i + 1) mod k); a.((i + 2) mod k) |])
                      > 0))
          in
          (* the cell traced around the outside has negative area *)
          let inner =
            List.filter
              (fun (_, ns) -> Num.sign (Geom.signed_area (poly ns)) > 0)
              (List.rev !cells)
          in
          let inner = List.map (fun (id, ns) -> (id, corners ns)) inner in
          if
            List.length inner < 2
            || List.length inner <> List.length !cells - 1
            || not (List.for_all (fun (_, ns) -> convex ns) inner)
          then None
          else
            let inv = Isometry.inverse (face_iso2 g fi) in
            let back = Isometry.apply_point inv in
            let turn = Num.sign (Geom.signed_area g.faces.(fi)) in
            let child ns =
              let c = Array.map back (poly ns) in
              if Num.sign (Geom.signed_area c) = turn then c
              else
                let k = Array.length c in
                Array.init k (fun i -> c.(k - 1 - i))
            in
            let slot id =
              let rec go i = function
                | [] -> -1
                | (id', _) :: rest -> if id' = id then i else go (i + 1) rest
              in
              go 0 inner
            in
            let hinges =
              Hashtbl.fold
                (fun (u, v) cid acc ->
                  match cid with
                  | Some cid when u < v ->
                      let a = slot (Hashtbl.find cell_of (u, v))
                      and b = slot (Hashtbl.find cell_of (v, u)) in
                      if a < 0 || b < 0 || a = b then acc
                      else (a, b, (back nodes.(u), back nodes.(v)), cid) :: acc
                  | _ -> acc)
                edges []
              |> List.sort compare
            in
            Some (List.map (fun (_, ns) -> child ns) inner, hinges))
  in
  fst (split_faces ~hinge_prov:crease_prov g ~prov ~cut_of)

let subdivide_paper ?crease_id (g : t) (paper_axis : Geom.line)
    ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  (* PLUS child = [paper_axis] side +1 (old-model convention): clip the paper
     polygon directly, no isometry. *)
  let cut_of fi =
    let f = g.faces.(fi) in
    let part k =
      let sub = Geom.clip_convex_halfplane paper_axis k f in
      if Array.length sub >= 3 then Some sub else None
    in
    match (part 1, part (-1)) with
    | Some pp, Some pm -> (
        match Geom.clip_line_to_convex paper_axis f with
        | Some (a, b) -> Some (pp, pm, (a, b))
        | None -> None)
    | _ -> None
  in
  split_with_flat_hinges g ~cid ~prov ~cut_of

let subdivide_paper_segment ?crease_id (g : t) ((a, b) : Geom.point * Geom.point)
    ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  let paper_axis = Geom.line_through a b in
  let within (p : Geom.point) =
    let t = Geom.seg_param (a, b) p in
    Num.sign t >= 0 && Num.compare t Num.one <= 0
  in
  (* a face is cut where the segment crosses it from boundary to boundary;
     the line beyond the segment, and a face the segment only enters, stay
     whole *)
  let cut_of fi =
    let f = g.faces.(fi) in
    let part k =
      let sub = Geom.clip_convex_halfplane paper_axis k f in
      if Array.length sub >= 3 then Some sub else None
    in
    match (part 1, part (-1), Geom.clip_line_to_convex paper_axis f) with
    | Some pp, Some pm, Some (p, q) when within p && within q -> Some (pp, pm, (p, q))
    | _ -> None
  in
  split_with_flat_hinges g ~cid ~prov ~cut_of

(* Where a moved block lands after a fold. *)
type placement = Top | Bottom | Over of int list | Under of int list

(* Exact geometric answers a placed fold computes, kept across the openings
   of one reverse fold. An answer is keyed on the faces and creases it reads,
   each named by its parent and whether it moved, and it is reused only where
   each of them has, in the state at hand, exactly the table polygon or table
   segment it had when the answer was computed: [sh_poly] and [sh_seg] hold
   those, and a face or crease that differs is answered afresh. *)
type shared = {
  sh_poly : (int * bool, Geom.point array) Hashtbl.t;
  sh_seg : ((int * bool) * (int * bool), Geom.point * Geom.point) Hashtbl.t;
  sh_overlap : ((int * bool) * (int * bool), bool) Hashtbl.t;
  sh_crosses : ((int * bool) * (int * bool) * (int * bool), bool) Hashtbl.t;
  sh_collinear :
    (((int * bool) * (int * bool)) * ((int * bool) * (int * bool)), bool) Hashtbl.t;
  sh_in_region : ((int * bool) * (int * bool) * (int * bool), bool) Hashtbl.t;
}

let new_shared () =
  { sh_poly = Hashtbl.create 128; sh_seg = Hashtbl.create 256;
    sh_overlap = Hashtbl.create 512; sh_crosses = Hashtbl.create 512;
    sh_collinear = Hashtbl.create 1024; sh_in_region = Hashtbl.create 256 }

(* [p] and [q] are the same polygon, vertex by vertex *)
let same_polygon (p : Geom.point array) (q : Geom.point array) : bool =
  Array.length p = Array.length q && Array.for_all2 Geom.point_equal p q

let same_segment ((a, b) : Geom.point * Geom.point) ((c, d) : Geom.point * Geom.point) =
  Geom.point_equal a c && Geom.point_equal b d

(* The stackings of a fold whose blocks all lie [Over] or [Under] an anchor,
   given the folded geometry [geo]. [anchors.(b)] holds block [b]'s anchor
   faces, the block lying directly on each, and whether it lies over them.

   The sides of a stationary face and a moved face that overlap are what
   the fold decides; every other overlapping pair keeps the order it had:
   two faces of one unit, the stationary faces or one block, their parents'
   order, exchanged where [turned] says the face turns over, and of two
   blocks the one listed first lies below.
   Three conditions decide sides, each read only where the faces overlap:

   - the placement: the block lies directly over (under) its anchors, so an
     anchor is below (above) every moved face of the block it overlaps;
   - the anchor: where a stationary face, an anchor and a moved face of the
     block share a region of the table, the face lies on the side of the
     moved face that it lies on of the anchor. This is the order condition
     (MODEL cond-order) in that region, with nothing between the block and
     the anchor;
   - one sheet: a face that covers the interior of a hinge's crease lies on
     the same side of both faces of the hinge. For a folded hinge, the new
     ones on the axis among them, this is the taco-tortilla condition
     (MODEL cond-taco-tortilla); for a flat hinge, the two faces are one
     uncreased region, whose order with a face over it is one value
     (MODEL def-flat-state, the paragraph after the definition).

   A side two conditions decide differently makes the fold invalid. The
   sides nothing decides fall into classes that turn together; the layer
   search of a fan ([orders]) sets them, and each state it finds is a
   stacking of the fold. Where it finds none, the error is the violation of
   the combination that turns every class one way. *)
let placed_stackings ~(shared : shared) ~(g : t) ~(geo : geometry)
    ~(parent : int array) ~(moved : bool array) ~(block_of : int array)
    ~(turned : bool array) ~(anchors : (int list * bool) array) :
    (t list, violation) result =
  match geo.g_placed with
  | Error v -> Error v
  | Ok p -> (
      let n = Array.length parent in
      let name i = (parent.(i), moved.(i)) in
      (* the face has the table polygon the shared answers about it read *)
      let kept =
        Array.init n (fun i ->
            match Hashtbl.find_opt shared.sh_poly (name i) with
            | Some q -> same_polygon q p.p_ccw_tps.(i)
            | None ->
                Hashtbl.replace shared.sh_poly (name i) p.p_ccw_tps.(i);
                true)
      in
      let hinge_name h =
        let a = name geo.g_hinges.(h).fa and b = name geo.g_hinges.(h).fb in
        if a < b then (a, b) else (b, a)
      in
      let hinge_names = Array.init (Array.length geo.g_hinges) hinge_name in
      let kept_seg =
        Array.init (Array.length geo.g_hinges) (fun h ->
            match Hashtbl.find_opt shared.sh_seg hinge_names.(h) with
            | Some s -> same_segment s p.p_tsegs.(h)
            | None ->
                Hashtbl.replace shared.sh_seg hinge_names.(h) p.p_tsegs.(h);
                true)
      in
      (* [f ()] through [table] under [key] where [ok] *)
      let cached table ok key f =
        if not ok then f ()
        else
          match Hashtbl.find_opt table key with
          | Some b -> b
          | None ->
              let b = f () in
              Hashtbl.replace table key b;
              b
      in
      let overlap i j =
        i <> j
        &&
        let i, j = if i < j then (i, j) else (j, i) in
        memo p.p_overlap i j (fun () ->
            let key = if name i < name j then (name i, name j) else (name j, name i) in
            cached shared.sh_overlap (kept.(i) && kept.(j)) key (fun () ->
                Geom.convex_overlap p.p_ccw_tps.(i) p.p_ccw_tps.(j)))
      in
      let crosses h c =
        memo p.p_crosses h c (fun () ->
            let a, b = hinge_names.(h) in
            cached shared.sh_crosses (kept_seg.(h) && kept.(c)) (a, b, name c) (fun () ->
                Geom.segment_crosses_interior p.p_tsegs.(h) p.p_ccw_tps.(c)))
      in
      (* The crossings and collinear overlaps another opening answered
         serve the checks of [build]; its answers serve the next. *)
      let exchange () =
        Array.iteri
          (fun h row ->
            if kept_seg.(h) then
              let a, b = hinge_names.(h) in
              Array.iteri
                (fun c v ->
                  if kept.(c) then
                    let key = (a, b, name c) in
                    match v with
                    | Some r -> Hashtbl.replace shared.sh_crosses key r
                    | None -> row.(c) <- Hashtbl.find_opt shared.sh_crosses key)
                row)
          p.p_crosses;
        Array.iteri
          (fun i row ->
            if kept_seg.(i) then
              Array.iteri
                (fun j v ->
                  if kept_seg.(j) then
                    let key = (hinge_names.(i), hinge_names.(j)) in
                    match v with
                    | Some r -> Hashtbl.replace shared.sh_collinear key r
                    | None -> row.(j) <- Hashtbl.find_opt shared.sh_collinear key)
                row)
          p.p_overlaps
      in
      exchange ();
      (* [i] above [j], for an overlapping pair the fold does not decide *)
      let kept_above i j =
        if moved.(i) && block_of.(i) <> block_of.(j) then block_of.(i) > block_of.(j)
        else if turned.(i) then side g parent.(i) parent.(j) < 0
        else side g parent.(i) parent.(j) > 0
      in
      (* "[x] above [y]" as a literal over the (stationary, moved) pairs *)
      let lit x y =
        if moved.(x) = moved.(y) then Layer_sides.Known (kept_above x y)
        else if moved.(y) then Layer_sides.Side ((x, y), false)
        else Layer_sides.Side ((y, x), true)
      in
      let all = List.init n Fun.id in
      let stat = List.filter (fun i -> not moved.(i)) all in
      let movers = List.filter (fun i -> moved.(i)) all in
      let pairs =
        List.concat_map
          (fun m -> List.filter_map (fun s -> if overlap s m then Some (s, m) else None) stat)
          movers
      in
      let uf = Layer_sides.create () in
      let ( let* ) = Result.bind in
      (* two anchors that put one face on two sides of a moved face lying
         directly on both form a cycle across regions *)
      let fix pr above =
        Layer_sides.relate uf (Layer_sides.Side (pr, false)) (Known above) ~why:Layer_cycle
      in
      (* whether [s], the anchor [a] and the moved face [m] share a region of
         positive area: asked only where the three pairs overlap, then [m]
         clipped to [a] and the result against [s], exactly *)
      let in_region s m a =
        cached shared.sh_in_region (kept.(s) && kept.(m) && kept.(a))
          (name s, name m, name a) (fun () ->
            overlap s a && overlap m a
            &&
            let r = clip_convex p.p_ccw_tps.(m) p.p_ccw_tps.(a) in
            Array.length r >= 3
            && Num.sign (Geom.signed_area r) <> 0
            && Geom.convex_overlap p.p_ccw_tps.(s) r)
      in
      let seeded =
        List.fold_left
          (fun acc ((s, m) as pr) ->
            let* () = acc in
            let on, over = anchors.(block_of.(m)) in
            if List.mem s on then fix pr (not over)
            else
              List.fold_left
                (fun acc a ->
                  let* () = acc in
                  if in_region s m a then fix pr (kept_above s a) else Ok ())
                (Ok ()) on)
          (Ok ()) pairs
      in
      let adj = Array.make n [] in
      Array.iteri
        (fun hi (h : hinge) ->
          adj.(h.fa) <- (hi, h.fb) :: adj.(h.fa);
          adj.(h.fb) <- (hi, h.fa) :: adj.(h.fb))
        geo.g_hinges;
      let rec propagate = function
        | [] -> Ok ()
        | (s, m) :: rest ->
            let side = lit s m in
            let* () =
              List.fold_left
                (fun acc (hi, s') ->
                  let* () = acc in
                  if s' <> m && crosses hi m then
                    Layer_sides.relate uf side (lit s' m)
                      ~why:(Taco_tortilla { tortilla = m; hinge = hi })
                  else Ok ())
                (Ok ()) adj.(s)
            in
            let* () =
              List.fold_left
                (fun acc (hi, m') ->
                  let* () = acc in
                  if m' <> s && crosses hi s then
                    Layer_sides.relate uf side (lit s m')
                      ~why:(Taco_tortilla { tortilla = s; hinge = hi })
                  else Ok ())
                (Ok ()) adj.(m)
            in
            propagate rest
      in
      match Result.bind seeded (fun () -> propagate pairs) with
      | Error v -> Error v
      | Ok () ->
          let decided, free = Layer_sides.classes uf pairs in
          let k = List.length free in
          if k > max_undecided then Error (Too_many_undecided k)
          else begin
            (* every pair of the state, through the answers kept across
               openings *)
            for i = 0 to n - 1 do
              for j = i + 1 to n - 1 do
                ignore (overlap i j)
              done
            done;
            let kept i j = if moved.(i) = moved.(j) then Some (kept_above i j) else None in
            let fixed = List.map (fun ((s, m), up) -> if up then (s, m) else (m, s)) decided in
            let found = orders ~marks:g.marks geo ~kept ~fixed in
            exchange ();
            match found with
            | Error v -> Error v
            | Ok (_ :: _ as gs) -> Ok gs
            | Ok [] -> (
                (* the violation of the combination with every open class
                   turned one way, the first the search tries *)
                let stat_above = Hashtbl.create ((2 * List.length pairs) + 1) in
                List.iter (fun (pr, v) -> Hashtbl.replace stat_above pr v) decided;
                List.iter
                  (List.iter (fun (pr, v) -> Hashtbl.replace stat_above pr (not v)))
                  free;
                let side i j =
                  if moved.(i) = moved.(j) then kept_above i j
                  else if moved.(j) then Hashtbl.find stat_above (i, j)
                  else not (Hashtbl.find stat_above (j, i))
                in
                match build ~marks:g.marks ~cycles:true geo ~side with
                | exception V v -> Error v
                | _ -> Error Layer_cycle)
          end)

(* The faces of [g] cut by the TABLE-space [axis] for a fold of [nb] blocks.
   A parent in no block ([block_of_parent] gives -1) stays whole; a block
   parent gives its piece on [-move_side] to the stationary faces and its
   piece on [move_side] to its block. Returns the stationary faces with
   their parents, in the order of the parents; per block its pieces with
   their parents, in the reverse order of the parents; per parent the axis
   cuts, the chord, in the reverse order of the parents; and per parent
   whether it stays whole. FOLD emit enumerates faces by index, so these
   orders are observable output. *)
let cut_blocks (g : t) ~(axis : Geom.line) ~(move_side : int) ~(nb : int)
    ~(block_of_parent : int -> int) =
  let stay = ref [] in (* ([paper_poly], parent) *)
  let movs = Array.make (max nb 1) [] in (* per block, ([paper_poly], parent) *)
  let chords = ref [] in (* (parent, a, b) for each face cut *)
  let uncut = Array.make (Array.length g.faces) false in
  Array.iteri
    (fun fi f ->
      let b = block_of_parent fi in
      if b < 0 then begin
        stay := (f, fi) :: !stay;
        uncut.(fi) <- true
      end
      else begin
        let iso2 = face_iso2 g fi in
        let table = Array.map (Isometry.apply_point iso2) f in
        let inv = Isometry.inverse iso2 in
        let part k =
          let sub = Geom.clip_convex_halfplane axis k table in
          if Array.length sub >= 3 then
            Some (Array.map (Isometry.apply_point inv) sub)
          else None
        in
        let s = part (-move_side) and m = part move_side in
        (match (s, m) with
        | Some _, Some _ -> (
            match axis_chord_in_face g fi axis with
            | Some (a, b) -> chords := (fi, a, b) :: !chords
            | None -> ())
        | _ -> ());
        if s = None || m = None then uncut.(fi) <- true;
        (match s with Some poly -> stay := (poly, fi) :: !stay | None -> ());
        match m with
        | Some poly -> movs.(b) <- (poly, fi) :: movs.(b)
        | None -> ()
      end)
    g.faces;
  (List.rev !stay, movs, !chords, uncut)

(* The hinges of a fold of blocks before the fold turns any of them: per
   chord of [cut_blocks] a flat hinge along the axis between the stationary
   and the moved child, then the hinges of [g] re-attached to the children
   of their faces (D7). Each comes with the index of the hinge of [g] it
   carries, -1 for a hinge along the axis, and whether the fold changes it:
   every hinge along the axis, and a carried hinge that lies on the axis
   with exactly one moving side (D8). *)
let block_hinges (g : t) ~(axis : Geom.line) ~(cid : int)
    ~(prov : State.provenance option) ~(faces' : face array)
    ~(parent : int array) ~(moved : bool array)
    ~(chords : (int * Geom.point * Geom.point) list) : (hinge * int * bool) list =
  let children_of p =
    let acc = ref [] in
    Array.iteri (fun k pp -> if pp = p then acc := k :: !acc) parent;
    List.rev !acc
  in
  let along =
    List.rev_map
      (fun (fi, a, b) ->
        let sc = ref (-1) and mc = ref (-1) in
        Array.iteri (fun k pp -> if pp = fi then if moved.(k) then mc := k else sc := k) parent;
        ( { fa = !sc; fb = !mc; line = Geom.line_through a b; angle = Num.zero;
            crease_id = cid; prov },
          -1,
          true ))
      chords
  in
  let moved_parent = Array.make (Array.length g.faces) false in
  Array.iteri (fun k pp -> if moved.(k) then moved_parent.(pp) <- true) parent;
  let carried =
    List.concat
      (List.mapi
         (fun hi (h : hinge) ->
           let ta, tb = hinge_table_segment g hi in
           let changes =
             Geom.side_of_line axis ta = 0 && Geom.side_of_line axis tb = 0
             && moved_parent.(h.fa) <> moved_parent.(h.fb)
           in
           List.concat_map
             (fun cp ->
               List.filter_map
                 (fun cq ->
                   let h' = { h with fa = cp; fb = cq } in
                   match hinge_shared_segment faces' h' with
                   | Some _ -> Some (h', hi, changes)
                   | None -> None)
                 (children_of h.fb))
             (children_of h.fa))
         (Array.to_list g.hinges))
  in
  along @ carried

(* A hinge the fold changes: a flat one folds, a folded one opens. *)
let turn_hinge (h : hinge) : hinge =
  { h with angle = (if Num.sign h.angle = 0 then Num.one else Num.zero) }

(* Two uncut children that both moved or both stayed overlap iff their
   parents did. *)
let seed_overlaps (g : t) (geo : geometry) ~(parent : int array)
    ~(moved : bool array) ~(uncut : bool array) : unit =
  match geo.g_placed with
  | Error _ -> ()
  | Ok p ->
      let n = Array.length parent in
      for i = 0 to n - 1 do
        if uncut.(parent.(i)) then
          for j = i + 1 to n - 1 do
            if uncut.(parent.(j)) && moved.(i) = moved.(j) then
              p.p_overlap.(i).(j) <- Some (side g parent.(i) parent.(j) <> 0)
          done
      done

(* The side of two faces of a fold whose blocks all lie outside the stack:
   the blocks and the stationary faces (unit -1) from the bottom up, a block
   placed [Top] above everything before it, one placed [Bottom] below. Two
   faces of one unit lie as their parents did, exchanged where [turned] says
   the face turns over. No cycle arises: a cycle of three would be one among
   the parents. *)
let level_side (g : t) ~(parent : int array) ~(unit_of : int array)
    ~(turned : bool array) ~(places : placement list) : int -> int -> bool =
  let levels =
    List.fold_left
      (fun acc (b, place) ->
        match place with Bottom -> b :: acc | _ -> acc @ [ b ])
      [ -1 ]
      (List.mapi (fun b place -> (b, place)) places)
  in
  let level = Array.make (List.length places + 1) 0 in
  List.iteri (fun pos b -> level.(b + 1) <- pos) levels;
  fun i j ->
    let ui = unit_of.(i) and uj = unit_of.(j) in
    if ui <> uj then level.(ui + 1) > level.(uj + 1)
    else if turned.(i) then side g parent.(i) parent.(j) < 0
    else side g parent.(i) parent.(j) > 0

(* Whether every block lies on faces ([Over]/[Under]); a fold places every
   block outside the stack or every block on faces. *)
let placed_only (places : placement list) : bool =
  let outside = function Top | Bottom -> true | Over _ | Under _ -> false in
  let placed = not (List.exists outside places) in
  if (not placed) && not (List.for_all outside places) then
    invalid_arg
      "Fold_state.fold_blocks: one fold places blocks outside the stack and \
       blocks on a face";
  placed

(* Per block, the stationary children of its anchor parents and whether it
   lies over them. *)
let block_anchors ~(parent : int array) ~(moved : bool array)
    (places : placement list) : (int list * bool) array =
  let stationary_child_of p =
    let found = ref (-1) in
    Array.iteri
      (fun k pp -> if pp = p && (not moved.(k)) && !found < 0 then found := k)
      parent;
    if !found < 0 then
      invalid_arg
        (Printf.sprintf
           "Fold_state.fold_blocks: placement face %d has no stationary child" p);
    !found
  in
  Array.of_list
    (List.map
       (function
         | Over ps -> (List.map stationary_child_of ps, true)
         | Under ps -> (List.map stationary_child_of ps, false)
         | Top | Bottom -> assert false)
       places)

let block_index (blocks : (bool array * placement) list) (fi : int) : int =
  let rec go b = function
    | [] -> -1
    | (mask, _) :: rest -> if mask.(fi) then b else go (b + 1) rest
  in
  go 0 blocks

(* The root of a fold: a stationary child of the old root, whose parent's
   placement is unchanged, or else the first stationary face; None when
   every face moves. *)
let block_root (g : t) ~(parent : int array) ~(moved : bool array) : int option =
  let stat = ref (-1) in
  Array.iteri
    (fun k pp -> if pp = g.root && (not moved.(k)) && !stat < 0 then stat := k)
    parent;
  if !stat >= 0 then Some !stat
  else begin
    let first = ref (-1) in
    Array.iteri (fun k m -> if (not m) && !first < 0 then first := k) moved;
    if !first >= 0 then Some !first else None
  end

let fold_blocks_gen ?crease_id ~(shared : shared) ~(blocks : (bool array * placement) list) (g : t)
    ~(axis : Geom.line) ~(move_side : int) ~(prov : State.provenance option) :
    (t list, violation) result =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  let nb = List.length blocks in
  let places = List.map snd blocks in
  let block_of_parent = block_index blocks in
  let stationary, movs, chords, uncut =
    cut_blocks g ~axis ~move_side ~nb ~block_of_parent
  in
  let placed_bottom b = List.nth places b = Bottom in
  let bottom_blocks =
    List.concat (List.init nb (fun b -> if placed_bottom b then movs.(b) else []))
  in
  let other_blocks =
    List.concat (List.init nb (fun b -> if placed_bottom b then [] else movs.(b)))
  in
  let arr = Array.of_list (bottom_blocks @ stationary @ other_blocks) in
  let faces' = Array.map fst arr in
  let parent = Array.map snd arr in
  let n' = Array.length arr in
  (* a child is moved iff its parent is in a block AND it is that parent's
     move-side piece; stationary pieces of block parents sit in [stationary] *)
  let n_bottom = List.length bottom_blocks and n_stay = List.length stationary in
  let moved = Array.init n' (fun k -> k < n_bottom || k >= n_bottom + n_stay) in
  let unit_of = Array.init n' (fun k -> if moved.(k) then block_of_parent parent.(k) else -1) in
  let hinges' =
    List.map
      (fun (h, _, changes) -> if changes then turn_hinge h else h)
      (block_hinges g ~axis ~cid ~prov ~faces' ~parent ~moved ~chords)
  in
  (* root + base: a stationary child keeps its parent's placement; if
     everything moved, reflect the base across the axis *)
  let root', base' =
    match block_root g ~parent ~moved with
    | Some r -> (r, g.isos.(parent.(r)))
    | None -> (0, I3.compose (half_turn3_of_line axis) g.isos.(parent.(0)))
  in
  let placed = placed_only places in
  match
    geometry ~base:base' ~faces:faces' ~hinges:(Array.of_list hinges') ~root:root' ()
  with
  | Error v -> Error v
  | Ok geo when not placed -> (
      seed_overlaps g geo ~parent ~moved ~uncut;
      let side = level_side g ~parent ~unit_of ~turned:moved ~places in
      try Ok [ build ~marks:g.marks ~cycles:false geo ~side ] with V v -> Error v)
  | Ok geo ->
      seed_overlaps g geo ~parent ~moved ~uncut;
      placed_stackings ~shared ~g ~geo ~parent ~moved ~block_of:unit_of ~turned:moved
        ~anchors:(block_anchors ~parent ~moved places)

let fold_blocks_all ?crease_id ~blocks g ~axis ~move_side ~prov =
  fold_blocks_gen ?crease_id ~shared:(new_shared ()) ~blocks g ~axis ~move_side ~prov

let fold_blocks ?crease_id ~blocks g ~axis ~move_side ~prov =
  match fold_blocks_all ?crease_id ~blocks g ~axis ~move_side ~prov with
  | Ok [ g' ] -> Ok g'
  | Ok gs -> Error (Several_stackings (List.length gs))
  | Error v -> Error v

let fold ?crease_id ?moving_parents (g : t) ~(axis : Geom.line)
    ~(move_side : int) ~(valley : bool) ~(prov : State.provenance option) : t =
  let mask =
    match moving_parents with
    | Some m -> m
    | None -> Array.make (Array.length g.faces) true
  in
  match
    fold_blocks ?crease_id ~blocks:[ (mask, if valley then Top else Bottom) ] g
      ~axis ~move_side ~prov
  with
  | Ok g' -> g'
  | Error v -> fail_of_violation prov v

let simple_fold (g : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) : t =
  fold g ~axis ~move_side ~valley ~prov:None

(* A reverse fold as a fan (BEP-0077). [rf_scored] is [rf_before] with every
   face of the tip cut along the axis by a flat hinge, its faces in the
   order [cut_blocks] gives one block, the tip: the stationary faces, then
   the pieces beyond the axis. The fan changes the hinges [rf_change]
   marks, and every piece beyond the axis moves by the reflection across
   it whatever the opening, so every opening is a stacking of one folded
   state. [rf_origin] holds per hinge the hinge of [rf_before] it carries,
   -1 for a hinge along the axis. *)
type reverse_fan = {
  rf_before : t;
  rf_scored : t;
  rf_parent : int array;
  rf_moved : bool array;
  rf_uncut : bool array;
  rf_origin : int array;
  rf_change : bool array;
  rf_root : int;
  rf_scored_geo : geometry;
  rf_shared : shared;
}

let reverse_fan ~(cid : int) (g : t) ~(axis : Geom.line) ~(move_side : int)
    ~(tip : bool array) ~(prov : State.provenance option) :
    (reverse_fan, violation) result =
  let stationary, movs, chords, uncut =
    cut_blocks g ~axis ~move_side ~nb:1
      ~block_of_parent:(fun fi -> if tip.(fi) then 0 else -1)
  in
  let arr = Array.of_list (stationary @ movs.(0)) in
  let faces' = Array.map fst arr and parent = Array.map snd arr in
  let n = Array.length arr and n_stay = List.length stationary in
  let moved = Array.init n (fun k -> k >= n_stay) in
  let hs = block_hinges g ~axis ~cid ~prov ~faces' ~parent ~moved ~chords in
  let hinges' = Array.of_list (List.map (fun (h, _, _) -> h) hs) in
  match block_root g ~parent ~moved with
  | None -> Error (Disconnected 0) (* no face stays: the tip holds every face *)
  | Some root -> (
      match geometry ~base:g.isos.(parent.(root)) ~faces:faces' ~hinges:hinges' ~root () with
      | Error v -> Error v
      | Ok geo -> (
          (* before the fold nothing has moved *)
          seed_overlaps g geo ~parent ~moved:(Array.make n false) ~uncut;
          (* Cutting a face of a valid state along a flat hinge breaks no
             condition on hinges: a face between the two faces of a hinge,
             or crossing it, has a parent that is so, and a flat hinge on
             the line of a folded one cuts a parent that crosses that
             folded hinge. *)
          match
            build ~marks:g.marks ~tacos:false ~cycles:false geo ~side:(fun i j ->
                side g parent.(i) parent.(j) > 0)
          with
          | exception V v -> Error v
          | scored ->
              Ok
                { rf_before = g; rf_scored = scored; rf_parent = parent;
                  rf_moved = moved; rf_uncut = uncut;
                  rf_origin = Array.of_list (List.map (fun (_, o, _) -> o) hs);
                  rf_change = Array.of_list (List.map (fun (_, _, c) -> c) hs);
                  rf_root = root; rf_scored_geo = geo; rf_shared = new_shared () }))

let reverse_scored (rf : reverse_fan) : t = rf.rf_scored
let reverse_moved (rf : reverse_fan) : bool array = Array.copy rf.rf_moved
let reverse_changes (rf : reverse_fan) : bool array = Array.copy rf.rf_change
let reverse_root (rf : reverse_fan) : int = rf.rf_root

(* [geo] with face [face_order.(k)] as face [k] and hinge [hinge_order.(k)]
   as hinge [k], the answers it has computed carried along. *)
let permute_geometry (geo : geometry) ~(face_order : int array)
    ~(hinge_order : int array) : geometry =
  let pos = Array.make (Array.length face_order) 0 in
  Array.iteri (fun k f -> pos.(f) <- k) face_order;
  let pf a = Array.map (fun f -> a.(f)) face_order in
  let ph a = Array.map (fun h -> a.(h)) hinge_order in
  let pair (t : bool option array array) =
    Array.map
      (fun a -> Array.map (fun b -> t.(min a b).(max a b)) face_order)
      face_order
  in
  {
    g_faces = pf geo.g_faces;
    g_hinges =
      Array.map
        (fun h ->
          let x = geo.g_hinges.(h) in
          { x with fa = pos.(x.fa); fb = pos.(x.fb) })
        hinge_order;
    g_root = pos.(geo.g_root);
    g_base = geo.g_base;
    g_placed =
      Result.map
        (fun p ->
          { p_isos = pf p.p_isos; p_segs = ph p.p_segs; p_tps = pf p.p_tps;
            p_ccw_tps = pf p.p_ccw_tps; p_tsegs = ph p.p_tsegs;
            p_folded = ph p.p_folded;
            p_crosses =
              Array.map (fun h -> Array.map (fun f -> p.p_crosses.(h).(f)) face_order) hinge_order;
            p_overlaps =
              Array.map (fun h -> Array.map (fun h' -> p.p_overlaps.(h).(h')) hinge_order) hinge_order;
            p_overlap = pair p.p_overlap })
        geo.g_placed;
  }

(* The answers [geo'], [geo] permuted, computed that [geo] has not. *)
let keep_answers (geo : geometry) (geo' : geometry) ~(face_order : int array)
    ~(hinge_order : int array) : unit =
  match (geo.g_placed, geo'.g_placed) with
  | Ok p, Ok p' ->
      let fill (t : bool option array array) i j v =
        if t.(i).(j) = None then t.(i).(j) <- v
      in
      Array.iteri
        (fun k a ->
          Array.iteri
            (fun l b ->
              if p'.p_overlap.(k).(l) <> None then
                fill p.p_overlap (min a b) (max a b) p'.p_overlap.(k).(l))
            face_order)
        face_order;
      Array.iteri
        (fun k h ->
          Array.iteri (fun l f -> fill p.p_crosses h f p'.p_crosses.(k).(l)) face_order;
          Array.iteri (fun l h' -> fill p.p_overlaps h h' p'.p_overlaps.(k).(l)) hinge_order)
        hinge_order
  | _ -> ()

(* The stackings of one opening of a reverse fold, its two [blocks] placed
   as [fold_blocks] places them, on [geo], the folded state of [rf]. The
   units of the layer search are the stationary faces and each block; a
   face keeps its side against a face of its own unit, exchanged where
   [turned] says the fan turns it over. The states have their faces and
   hinges in the order [fold_blocks] gives them: the blocks placed
   [Bottom], the stationary faces, the other blocks, each in the order of
   [rf_scored]; the hinges along the axis, then the carried hinges by the
   hinge they carry and their faces. *)
let fold_opening (rf : reverse_fan) (geo : geometry) ~(turned : bool array)
    ~(blocks : (bool array * placement) list) : (t list, violation) result =
  let g = rf.rf_before in
  let places = List.map snd blocks in
  let n = Array.length rf.rf_parent in
  let block_of k = if rf.rf_moved.(k) then block_index blocks rf.rf_parent.(k) else -1 in
  let rank k =
    let b = block_of k in
    if b < 0 then (1, 0) else if List.nth places b = Bottom then (0, b) else (2, b)
  in
  let face_order =
    Array.of_list (List.stable_sort (fun a b -> compare (rank a) (rank b)) (List.init n Fun.id))
  in
  let pos = Array.make n 0 in
  Array.iteri (fun k f -> pos.(f) <- k) face_order;
  let hs = geo.g_hinges in
  let along, carried =
    List.partition (fun h -> rf.rf_origin.(h) < 0) (List.init (Array.length hs) Fun.id)
  in
  let key h = (rf.rf_origin.(h), pos.(hs.(h).fa), pos.(hs.(h).fb)) in
  let hinge_order =
    Array.of_list (along @ List.stable_sort (fun a b -> compare (key a) (key b)) carried)
  in
  (* two faces that both moved or both stayed lie as they did in the cut
     state, so they overlap as they did there *)
  (match (rf.rf_scored_geo.g_placed, geo.g_placed) with
  | Ok ps, Ok p ->
      for i = 0 to n - 1 do
        for j = i + 1 to n - 1 do
          if rf.rf_moved.(i) = rf.rf_moved.(j) && p.p_overlap.(i).(j) = None then
            p.p_overlap.(i).(j) <- ps.p_overlap.(i).(j)
        done
      done
  | _ -> ());
  let geo' = permute_geometry geo ~face_order ~hinge_order in
  let parent = Array.map (fun f -> rf.rf_parent.(f)) face_order in
  let moved = Array.map (fun f -> rf.rf_moved.(f)) face_order in
  let unit_of = Array.map block_of face_order in
  let turned = Array.map (fun f -> turned.(f)) face_order in
  seed_overlaps g geo' ~parent ~moved ~uncut:rf.rf_uncut;
  let found =
    if placed_only places then
      placed_stackings ~shared:rf.rf_shared ~g ~geo:geo' ~parent ~moved ~block_of:unit_of
        ~turned ~anchors:(block_anchors ~parent ~moved places)
    else
      let side = level_side g ~parent ~unit_of ~turned ~places in
      match orders ~marks:g.marks geo' ~kept:(fun i j -> Some (side i j)) ~fixed:[] with
      | Error v -> Error v
      | Ok (_ :: _ as gs) -> Ok gs
      | Ok [] -> (
          match build ~marks:g.marks ~cycles:false geo' ~side with
          | exception V v -> Error v
          | _ -> Error Layer_cycle)
  in
  keep_answers geo geo' ~face_order ~hinge_order;
  found

type reverse_failure =
  | No_spine
  | Several_openings of spine_attempt list
  | Bodies_interleaved
  | Invalid of violation

and spine_outcome =
  | No_body
  | Interleaved
  | Crossing of violation
  | Reversed of t

and spine_attempt = {
  crease : int;
  hinge : int;
  turning : int list;
  halves : bool array * bool array;
  bodies : (int list * int list) option;
  outcome : spine_outcome;
}

let reverse_failure_to_string = function
  | No_spine ->
      "reverse needs a tip folded along one spine; the moving material does \
       not split into two halves"
  | Several_openings attempts ->
      Printf.sprintf "the tip opens at %d places" (List.length attempts)
  | Bodies_interleaved ->
      "the two halves are hinged to interleaved layers; that is not a reverse \
       fold"
  | Invalid v -> violation_to_string v

let reverse_attempts ~(cid : int) (g : t) ~(axis : Geom.line) ~(move_side : int)
    ~(tip : bool array) ~(inside : bool)
    ~(fold : (bool array * placement) list -> (t list, violation) result) :
    spine_attempt list =
  let n = Array.length g.faces in
  let nh = Array.length g.hinges in
  let internal =
    List.filter
      (fun hi ->
        let h = g.hinges.(hi) in
        tip.(h.fa) && tip.(h.fb))
      (List.init nh Fun.id)
  in
  let reaches_beyond hi =
    let ta, tb = hinge_table_segment g hi in
    Geom.side_of_line axis ta = move_side || Geom.side_of_line axis tb = move_side
  in
  let line_of hi =
    let ta, tb = hinge_table_segment g hi in
    Geom.line_through ta tb
  in
  let has_stay_piece fi =
    let table = table_polygon g fi in
    Array.length (Geom.clip_convex_halfplane axis (-move_side) table) >= 3
  in
  let tip_faces = List.filter (fun i -> tip.(i)) (List.init n Fun.id) in
  (* [i] below [j], for two faces of the tip that overlap *)
  let below_overlapping i j = side g i j < 0 in
  (* An opening parts the tip into a lower and an upper half where every
     hinge joining the two is folded and lies on one table line, the
     spine's, which reaches beyond the axis (BEP-0043), and no face of the
     upper half lies below a face of the lower half it overlaps. Per spine
     line, the faces joined by the tip's other hinges move together; the
     lower halves are the sets of such groups that hold every group below
     one of their own. *)
  let spine_lines =
    List.fold_left
      (fun acc hi ->
        if
          Num.sign g.hinges.(hi).angle <> 0 && reaches_beyond hi
          && not (List.exists (fun l -> Geom.same_line l (line_of hi)) acc)
        then line_of hi :: acc
        else acc)
      [] internal
    |> List.rev
  in
  let halves_on line =
    let on_spine hi =
      Num.sign g.hinges.(hi).angle <> 0 && Geom.same_line line (line_of hi)
    in
    let group = Array.init n Fun.id in
    let rec root i = if group.(i) = i then i else root group.(i) in
    List.iter
      (fun hi ->
        if not (on_spine hi) then
          let a = root g.hinges.(hi).fa and b = root g.hinges.(hi).fb in
          if a <> b then group.(a) <- b)
      internal;
    let members r = List.filter (fun i -> root i = r) tip_faces in
    let below_of groups =
      List.map
        (fun r ->
          ( r,
            List.filter
              (fun r' ->
                r' <> r
                && List.exists
                     (fun i -> List.exists (fun j -> below_overlapping j i) (members r'))
                     (members r))
              groups ))
        groups
    in
    (* groups that lie below each other, through other groups or directly,
       part only together: they become one group *)
    let groups0 = List.sort_uniq compare (List.map root tip_faces) in
    let below0 = below_of groups0 in
    let reaches r =
      let seen = Hashtbl.create 8 in
      let rec go r =
        List.iter
          (fun r' ->
            if not (Hashtbl.mem seen r') then begin
              Hashtbl.replace seen r' ();
              go r'
            end)
          (List.assoc r below0)
      in
      go r;
      seen
    in
    let reach = List.map (fun r -> (r, reaches r)) groups0 in
    List.iter
      (fun r ->
        List.iter
          (fun r' ->
            if
              r < r'
              && Hashtbl.mem (List.assoc r reach) r'
              && Hashtbl.mem (List.assoc r' reach) r
            then
              let a = root r and b = root r' in
              if a <> b then group.(a) <- b)
          groups0)
      groups0;
    let groups = List.sort_uniq compare (List.map root tip_faces) in
    let below_group = below_of groups in
    (* the groups with every group below one of them first, so that a group
       is decided after the groups below it *)
    let order =
      let rec go placed rest =
        match
          List.find_opt
            (fun r -> List.for_all (fun r' -> List.mem r' placed) (List.assoc r below_group))
            rest
        with
        | Some r -> go (r :: placed) (List.filter (( <> ) r) rest)
        | None -> List.rev placed @ rest
      in
      go [] groups
    in
    (* every set of groups that holds the groups below each of its own,
       other than none and all *)
    let rec downsets chosen = function
      | [] -> [ chosen ]
      | r :: rest ->
          let without = downsets chosen rest in
          if List.for_all (fun r' -> List.mem r' chosen) (List.assoc r below_group)
          then without @ downsets (r :: chosen) rest
          else without
    in
    downsets [] order
    |> List.filter (fun d -> d <> [] && List.length d < List.length groups)
    |> List.filter_map (fun d ->
           let below = Array.init n (fun i -> tip.(i) && List.mem (root i) d) in
           let crossing =
             List.filter
               (fun hi -> below.(g.hinges.(hi).fa) <> below.(g.hinges.(hi).fb))
               internal
           in
           if crossing <> [] && List.exists reaches_beyond crossing then
             Some
               ( crossing,
                 below,
                 Array.init n (fun i -> tip.(i) && not below.(i)) )
           else None)
  in
  let count a = Array.fold_left (fun k b -> if b then k + 1 else k) 0 a in
  let openings =
    List.concat_map halves_on spine_lines
    |> List.sort_uniq (fun (_, lo1, _) (_, lo2, _) ->
           compare (count lo1, lo1) (count lo2, lo2))
  in
  let attempt (crossing, lower, upper) =
    let body half =
      List.filter (fun i -> half.(i) && has_stay_piece i) (List.init n Fun.id)
    in
    let tried bodies outcome =
      { crease = cid; hinge = List.hd crossing; turning = crossing; halves = (lower, upper);
        bodies; outcome }
    in
    let blo = body lower and bup = body upper in
    if blo = [] || bup = [] then [ tried (Some (blo, bup)) No_body ]
    else if
      List.exists (fun i -> List.exists (fun j -> below_overlapping i j) blo) bup
    then [ tried (Some (blo, bup)) Interleaved ]
    else
      (* the layers of a body that no layer of it overlaps from the side
         facing the opening: the block lies directly on each of them. *)
      let outermost l toward_opening =
        List.filter
          (fun i ->
            not
              (List.exists
                 (fun j ->
                   if toward_opening then below_overlapping i j
                   else below_overlapping j i)
                 l))
          l
      in
      let tops_lo = outermost blo true and tops_up = outermost bup false in
      (* each block is reflected as a whole and keeps its place against
         the other, so every hinge across the opening turns *)
      let blocks =
        if inside then [ (lower, Over tops_lo); (upper, Under tops_up) ]
        else [ (lower, Bottom); (upper, Top) ]
      in
      match fold blocks with
      | Ok gs -> List.map (fun g' -> tried (Some (blo, bup)) (Reversed g')) gs
      | Error v -> [ tried (Some (blo, bup)) (Crossing v) ]
  in
  List.concat_map attempt openings

let reverse_letter (g : t) (a : spine_attempt) (hi : int) : assign =
  let l = mv g hi in
  if not (List.mem hi a.turning) then l
  else match l with V -> M | M -> V | F -> F

let reverse_of_attempts (attempts : spine_attempt list) :
    (t, reverse_failure) result =
  let oks =
    List.filter_map
      (fun a -> match a.outcome with Reversed g' -> Some (a, g') | _ -> None)
      attempts
  in
  (* openings whose states stack every overlapping pair alike are one state
     (def-flat-state) *)
  let groups =
    List.fold_left
      (fun acc ((_, g') as x) ->
        match List.partition (fun grp -> same_order (snd (List.hd grp)) g') acc with
        | [ grp ], rest -> (grp @ [ x ]) :: rest
        | _, rest -> [ x ] :: rest)
      [] oks
    |> List.rev
  in
  match groups with
  | [ grp ] -> Ok (snd (List.hd grp))
  | _ :: _ :: _ -> Error (Several_openings (List.map (fun grp -> fst (List.hd grp)) groups))
  | [] -> (
      match
        List.find_map
          (fun a ->
            match a.outcome with
            | Interleaved -> Some Bodies_interleaved
            | Crossing v -> Some (Invalid v)
            | _ -> None)
          attempts
      with
      | Some e -> Error e
      | None -> Error No_spine)

(* Turn the whole sheet over: reflect across the footprint's vertical
   centerline (cosmetic internal axis), reverse the face
   array (observable: FOLD emit enumerates faces by index), reverse the
   stack. base absorbs the reflection:
   the ONE whole-sheet motion. *)
let flip (g : t) : t =
  let n = Array.length g.faces in
  if n = 0 then g
  else begin
    let p0 = (table_polygon g 0).(0) in
    let lo = ref p0.Geom.x and hi = ref p0.Geom.x in
    for i = 0 to n - 1 do
      Array.iter
        (fun (q0 : Geom.point) ->
          if Num.compare q0.Geom.x !lo < 0 then lo := q0.Geom.x;
          if Num.compare q0.Geom.x !hi > 0 then hi := q0.Geom.x)
        (table_polygon g i)
    done;
    let cx = Num.div (Num.add !lo !hi) (Num.of_int 2) in
    let axis = { Geom.a = Num.one; b = Num.zero; c = cx } in
    let faces' = Array.init n (fun k -> g.faces.(n - 1 - k)) in
    let hinges' =
      Array.map
        (fun h -> { h with fa = n - 1 - h.fa; fb = n - 1 - h.fb })
        g.hinges
    in
    let root' = n - 1 - g.root in
    let base' = I3.compose (half_turn3_of_line axis) g.isos.(g.root) in
    (* a pair turned over lies the other way round *)
    match geometry ~base:base' ~faces:faces' ~hinges:hinges' ~root:root' () with
    | Error v -> fail_of_violation None v
    | Ok geo -> (
        try
          build ~marks:g.marks ~cycles:false geo ~side:(fun i j ->
              side g (n - 1 - i) (n - 1 - j) < 0)
        with V v -> fail_of_violation None v)
  end

(* Marks carry no invariants; append without re-validation. *)
let add_mark (g : t) (m : mark) : t =
  { g with marks = Array.append g.marks [| m |] }

(* Every hinge and mark of crease [from] becomes one of crease [into]: the two
   are one crease from here on. Ids carry no invariant of the state, so this
   is a plain record update. *)
let merge_crease (g : t) ~(from : int) ~(into : int) : t =
  { g with
    hinges = Array.map (fun h -> if h.crease_id = from then { h with crease_id = into } else h) g.hinges;
    marks = Array.map (fun m -> if m.mcrease_id = from then { m with mcrease_id = into } else m) g.marks }

(* {1 Selectors} *)

(* Face ids sharing a hinge with face [i]. *)
let neighbors (g : t) (i : int) : int list =
  Array.fold_left
    (fun acc (h : hinge) ->
      if h.fa = i then h.fb :: acc
      else if h.fb = i then h.fa :: acc
      else acc)
    [] g.hinges

(* The hinge incident to face [i] whose paper segment equals (pa,pb) in either
   order (old [edge_between], as an index). *)
let hinge_between (g : t) (i : int) (pa : Geom.point) (pb : Geom.point) :
    int option =
  let n = Array.length g.hinges in
  let rec go k =
    if k >= n then None
    else
      let h = g.hinges.(k) in
      let a, b = g.segs.(k) in
      if (h.fa = i || h.fb = i)
         && ((Geom.point_equal a pa && Geom.point_equal b pb)
            || (Geom.point_equal a pb && Geom.point_equal b pa))
      then Some k
      else go (k + 1)
  in
  go 0

let all_crease_ids (g : t) : int list =
  let seen = Hashtbl.create 16 in
  Array.iter
    (fun (h : hinge) ->
      if h.crease_id >= 0 then Hashtbl.replace seen h.crease_id ())
    g.hinges;
  Hashtbl.fold (fun k () acc -> k :: acc) seen []

type crease_segment = {
  faces : int * int;
  ta : Geom.point;
  tb : Geom.point;
  pa : Geom.point;
  pb : Geom.point;
}

(* Every material segment of crease [cid]. Degenerate pieces cannot exist in
   the new model ([make] rejects them), so no positive-length filter is
   needed. List order is unspecified. *)
let crease_segments (g : t) (cid : int) : crease_segment list =
  let acc = ref [] in
  Array.iteri
    (fun i (h : hinge) ->
      if h.crease_id = cid then begin
        let pa, pb = g.segs.(i) in
        let ta, tb = hinge_table_segment g i in
        acc := { faces = (h.fa, h.fb); ta; tb; pa; pb } :: !acc
      end)
    g.hinges;
  !acc

(* table-space endpoints of every piece of crease [cid] *)
let crease_table_endpoints (g : t) (cid : int) : Geom.point list =
  List.concat_map (fun s -> [ s.ta; s.tb ]) (crease_segments g cid)

(* Boundary pieces of a paper edge [line]: walk every face's polygon sides on
   [line] not paired with a neighbor across a hinge. *)
let edge_boundary_segments (g : t) (line : Geom.line) : crease_segment list =
  let acc = ref [] in
  Array.iteri
    (fun fi f ->
      let m = Array.length f in
      let iso2 = face_iso2 g fi in
      for k = 0 to m - 1 do
        let pa = f.(k) and pb = f.((k + 1) mod m) in
        if
          Geom.side_of_line line pa = 0
          && Geom.side_of_line line pb = 0
          && hinge_between g fi pa pb = None
        then
          let ta = Isometry.apply_point iso2 pa
          and tb = Isometry.apply_point iso2 pb in
          if not (Geom.point_equal ta tb) then
            acc := { faces = (fi, -1); ta; tb; pa; pb } :: !acc
      done)
    g.faces;
  List.rev !acc

let rec pick_two_distinct = function
  | a :: rest -> (
      match List.find_opt (fun b -> not (Geom.point_equal a b)) rest with
      | Some b -> Some (a, b)
      | None -> pick_two_distinct rest)
  | [] -> None

(* CAVEAT (here and in [crease_paper_axis]): the reconstructed line's
   coefficient SIGN is hinge-array-order dependent ([pick_two_distinct] over
   endpoints collected in hinge order, which is unspecified). Same line,
   possibly opposite normal: every consumer must be sign-insensitive
   ([side_of_line] = 0 tests, drawing between clip points). A future consumer
   needing an oriented normal must canonicalize first. *)
let axis_of_table_points (pts : Geom.point list) (l_orig : Geom.line) :
    [ `Line of Geom.line | `Bent | `Empty | `Collapsed ] =
  match pts with
  | [] -> `Empty
  | pts ->
      if List.for_all (fun p -> Geom.side_of_line l_orig p = 0) pts then
        `Line l_orig
      else (
        match pick_two_distinct pts with
        | None -> `Collapsed
        | Some (a, b) ->
            let l = Geom.line_through a b in
            if List.for_all (fun p -> Geom.side_of_line l p = 0) pts then
              `Line l
            else `Bent)

let crease_axis (g : t) (cid : int) (l_orig : Geom.line) =
  axis_of_table_points (crease_table_endpoints g cid) l_orig

let edge_axis (g : t) (line : Geom.line) =
  axis_of_table_points
    (List.concat_map (fun s -> [ s.ta; s.tb ]) (edge_boundary_segments g line))
    line

let crease_paper_axis (g : t) (cid : int) :
    [ `Line of Geom.line | `Bent | `Empty ] =
  let pts = ref [] in
  Array.iteri
    (fun i (h : hinge) ->
      if h.crease_id = cid then begin
        let a, b = g.segs.(i) in
        pts := a :: b :: !pts
      end)
    g.hinges;
  match pick_two_distinct !pts with
  | None -> `Empty
  | Some (a, b) ->
      let l = Geom.line_through a b in
      if List.for_all (fun p -> Geom.side_of_line l p = 0) !pts then `Line l
      else `Bent

(* Component id per face: F-adjacency (hinges with angle 0) union-find. Two
   faces separated only by a flat (angle 0) hinge are the same flap; the
   instant that hinge folds (angle -> ±1) the flap splits there, exactly and
   only there (BEP-0017). Recomputed from the current hinge-angle set on
   every call: no incremental cache, so a future `unfold` (which merges
   clusters) needs no extra bookkeeping. O(faces + hinges) per call. *)
let coplanar_clusters (g : t) : int array =
  let n = Array.length g.faces in
  let parent = Array.init n Fun.id in
  let rec find i =
    if parent.(i) = i then i
    else begin
      let r = find parent.(i) in
      parent.(i) <- r;
      r
    end
  in
  let union a b =
    let ra = find a and rb = find b in
    if ra <> rb then parent.(ra) <- rb
  in
  Array.iter
    (fun (h : hinge) -> if Num.sign h.angle = 0 then union h.fa h.fb)
    g.hinges;
  Array.init n (fun i -> find i)

(* The unique flap (coplanar cluster, as its face-index list) whose union of
   paper polygons contains every point in [pts]. A point on a shared flat
   hinge belongs to both incident faces, but they're the same cluster, so
   that's still one id. `Zero if no cluster contains every point, `Ambiguous
   if more than one does. *)
let cluster_of_points (g : t) (pts : Geom.point list) :
    [ `Cluster of int list | `Zero | `Ambiguous ] =
  let cl = coplanar_clusters g in
  let n = Array.length g.faces in
  let ids_of_point p =
    let s = ref [] in
    for i = 0 to n - 1 do
      if Geom.in_convex_polygon g.faces.(i) p && not (List.mem cl.(i) !s) then
        s := cl.(i) :: !s
    done;
    !s
  in
  match pts with
  | [] -> `Zero
  | p0 :: rest ->
      let common =
        List.fold_left
          (fun acc p -> List.filter (fun id -> List.mem id (ids_of_point p)) acc)
          (ids_of_point p0) rest
      in
      (match common with
       | [ id ] ->
           `Cluster (List.filter (fun i -> cl.(i) = id) (List.init n Fun.id))
       | [] -> `Zero
       | _ -> `Ambiguous)

let flap_of_points = cluster_of_points

(* on-paper material of a table-space line: its positive-length intersection
   with each face, table space. Stacked layers yield duplicate segments:
   fine for existence/sign tests, any future measure-based use must dedupe. *)
let line_material_segments (g : t) (l : Geom.line) :
    (Geom.point * Geom.point) list =
  List.filter_map
    (fun i -> Geom.clip_line_to_convex l (table_polygon_ccw g i))
    (List.init (Array.length g.faces) Fun.id)

(* the line creases some face (strict interior cut) *)
let line_cuts_paper (g : t) (l : Geom.line) : bool =
  List.exists
    (fun i -> Geom.line_cuts_polygon l (table_polygon_ccw g i))
    (List.init (Array.length g.faces) Fun.id)

(* material strictly on each side of the line: the faces need not be cut by
   it, since a face split along it lies on one side *)
let paper_on_both_sides (g : t) (l : Geom.line) : bool =
  let sides =
    List.concat_map
      (fun i -> Array.to_list (Array.map (Geom.side_of_line l) (table_polygon_ccw g i)))
      (List.init (Array.length g.faces) Fun.id)
  in
  List.mem 1 sides && List.mem (-1) sides

type scope_target = TargetFaces of int list | TargetHinged of (int -> bool)

(* Per face, the faces joined to it by a hinge off [axis]: one whose table
   segment reaches strictly into the [move_side] half-plane. Such a hinge
   cannot be torn, so a moving set holds both of its faces or neither. *)
let off_axis_neighbours (g : t) ~(axis : Geom.line) ~(move_side : int) :
    int list array =
  let adj = Array.make (Array.length g.faces) [] in
  Array.iteri
    (fun hi (h : hinge) ->
      let ta, tb = hinge_table_segment g hi in
      if Geom.side_of_line axis ta = move_side || Geom.side_of_line axis tb = move_side
      then begin
        adj.(h.fa) <- h.fb :: adj.(h.fa);
        adj.(h.fb) <- h.fa :: adj.(h.fb)
      end)
    g.hinges;
  adj

let close_off_axis (g : t) ~(axis : Geom.line) ~(move_side : int)
    (mask : bool array) : bool array =
  let adj = off_axis_neighbours g ~axis ~move_side in
  let inm = Array.copy mask in
  let rec visit f =
    List.iter
      (fun o ->
        if not inm.(o) then begin
          inm.(o) <- true;
          visit o
        end)
      adj.(f)
  in
  Array.iteri (fun f b -> if b then visit f) mask;
  inm

let select_scope (g : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) ~(anchor : int option) ~(target : scope_target) :
    (bool array, string * string option) result =
  let n = Array.length g.faces in
  let cl = coplanar_clusters g in
  let tp = g.tps in
  let rel_m = rel g in
  let piece =
    Array.init n (fun i ->
        let sub = Geom.clip_convex_halfplane axis move_side tp.(i) in
        if Array.length sub >= 3 then Some sub else None)
  in
  let cand i = piece.(i) <> None in
  let overlap i j =
    match (piece.(i), piece.(j)) with
    | Some a, Some b -> Geom.convex_overlap a b
    | _ -> false
  in
  let outer i j =
    overlap i j && rel_m i j = (if valley then Above else Below)
  in
  let find_targets () : (int list, string * string option) result =
    match target with
    | TargetFaces fs -> (
        match List.filter cand fs with
        | [] ->
            Error
              ( "`up to`: the target flap is not on the moving side of the fold",
                None )
        | ts -> Ok ts)
    | TargetHinged pred -> (
        match anchor with
        | None ->
            Error
              ( "`up to` a crease needs `moving` to walk inward from",
                Some "name the flap with a point instead" )
        | Some anchor when not (cand anchor) ->
            Error
              ( "the moving flap has no material on the moving side of the fold axis",
                None )
        | Some anchor when pred anchor -> Ok [ anchor ]
        | Some anchor ->
            let visited = Array.make n false in
            visited.(anchor) <- true;
            let result = ref None in
            while !result = None do
              let frontier = ref [] in
              for gi = 0 to n - 1 do
                if (not visited.(gi)) && cand gi then begin
                  let inward = ref false in
                  for v = 0 to n - 1 do
                    if visited.(v) && outer v gi then inward := true
                  done;
                  if !inward then frontier := gi :: !frontier
                end
              done;
              match List.filter pred !frontier with
              | [] ->
                  if !frontier = [] then
                    result :=
                      Some
                        (Error
                           ( "`up to`: no flap hinged on that crease is \
                              reachable from the anchor over the crease region",
                             None ))
                  else List.iter (fun gi -> visited.(gi) <- true) !frontier
              | hits -> result := Some (Ok hits)
            done;
            Option.get !result)
  in
  match find_targets () with
  | Error e -> Error e
  | Ok targets ->
      let joined = off_axis_neighbours g ~axis ~move_side in
      let inm = Array.make n false in
      List.iter (fun t -> inm.(t) <- true) targets;
      let changed = ref true in
      while !changed do
        changed := false;
        for gi = 0 to n - 1 do
          if (not inm.(gi)) && cand gi then
            for m = 0 to n - 1 do
              if
                inm.(m) && (not inm.(gi))
                && (outer gi m || cl.(gi) = cl.(m) || List.mem m joined.(gi))
              then begin
                inm.(gi) <- true;
                changed := true
              end
            done
        done
      done;
      Ok inm

(* The outside-contiguous prefix of layers down to and including the seed
   faces, closed under cohesion. "Outside" is top for valley, bottom for
   mountain. *)
let default_scope (g : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) ~(seed : int list) : bool array =
  let n = Array.length g.faces in
  let tp = g.tps in
  let piece =
    Array.init n (fun i ->
        let sub = Geom.clip_convex_halfplane axis move_side tp.(i) in
        if Array.length sub >= 3 then Some sub else None)
  in
  let cand i = piece.(i) <> None in
  let overlap i j =
    match (piece.(i), piece.(j)) with
    | Some a, Some b -> Geom.convex_overlap a b
    | _ -> false
  in
  let rel_m = rel g in
  (* [gi] is outside [m]: overlaps m and sits on the outer side (Above for valley) *)
  let outer gi m =
    overlap gi m && rel_m gi m = (if valley then Above else Below)
  in
  let cl = coplanar_clusters g in
  let inm = Array.make n false in
  List.iter (fun s -> if cand s then inm.(s) <- true) seed;
  let changed = ref true in
  while !changed do
    changed := false;
    for gi = 0 to n - 1 do
      if (not inm.(gi)) && cand gi then
        for m = 0 to n - 1 do
          if inm.(m) && (not inm.(gi)) && (outer gi m || cl.(gi) = cl.(m)) then begin
            inm.(gi) <- true;
            changed := true
          end
        done
    done
  done;
  inm

(* A scoped moving set is hinge-closed iff every crease segment separating a
   moving face from a stationary face lies on the fold axis with no endpoint
   strictly on the move side. *)
let scoped_fold_hinge_closed (g : t) ~(axis : Geom.line) ~(move_side : int)
    ~(moving_parents : bool array) : (unit, Geom.point * Geom.point) result =
  let n = Array.length moving_parents in
  let rec check = function
    | [] -> Ok ()
    | cid :: rest ->
        let rec check_segs = function
          | [] -> check rest
          | (s : crease_segment) :: more ->
              let l, r = s.faces in
              if
                l < n && r >= 0 && r < n
                && moving_parents.(l) <> moving_parents.(r)
                && (Geom.side_of_line axis s.ta = move_side
                   || Geom.side_of_line axis s.tb = move_side)
              then Error (s.ta, s.tb)
              else check_segs more
        in
        check_segs (crease_segments g cid)
  in
  check (all_crease_ids g)

(* Mark machinery. Faces are bare polygons and edges are hinges; the
   face and edge queries below work on that substrate. *)

let mark_rep_point (m : mark) : Geom.point =
  match m.mgeom with MSeg (a, _) -> a | MPoint p -> p

(* Paper-space chords (segment endpoints) of every [MSeg] mark carrying [cid].
   Point marks ([MPoint]) contribute no chord. Used by the meet operator to test
   that a marked line physically reaches a crossing. *)
let mark_chords (g : t) (cid : int) : (Geom.point * Geom.point) list =
  Array.to_list g.marks
  |> List.filter_map (fun m ->
         if m.mcrease_id = cid then
           match m.mgeom with MSeg (a, b) -> Some (a, b) | MPoint _ -> None
         else None)

(* The table pieces of the paper segment [(pa, pb)]: its positive-length
   part in each face, carried by that face's placement. A segment that runs
   along a hinge yields a piece from each face beside it. *)
let paper_segment_pieces (g : t) ((pa, pb) : Geom.point * Geom.point) :
    (Geom.point * Geom.point) list =
  if Geom.point_equal pa pb then []
  else
    let l = Geom.line_through pa pb in
    let at t =
      { Geom.x = Num.add pa.Geom.x (Num.mul t (Num.sub pb.Geom.x pa.Geom.x));
        y = Num.add pa.Geom.y (Num.mul t (Num.sub pb.Geom.y pa.Geom.y)) }
    in
    List.filter_map
      (fun i ->
        match Geom.clip_line_to_convex l (ccw g.faces.(i)) with
        | None -> None
        | Some (u, v) ->
            let tu = Geom.seg_param (pa, pb) u and tv = Geom.seg_param (pa, pb) v in
            let mx x y = if Num.compare x y >= 0 then x else y
            and mn x y = if Num.compare x y <= 0 then x else y in
            let lo = mx Num.zero (mn tu tv) and hi = mn Num.one (mx tu tv) in
            if Num.compare lo hi >= 0 then None
            else
              let iso = face_iso2 g i in
              Some (Isometry.apply_point iso (at lo), Isometry.apply_point iso (at hi)))
      (List.init (Array.length g.faces) Fun.id)

(* The bundle of the mark [cid] on the table (BEP-0033): its extent, one
   piece per face it crosses, and a point mark as its point. *)
let mark_material_segments (g : t) (cid : int) : (Geom.point * Geom.point) list =
  Array.to_list g.marks
  |> List.concat_map (fun m ->
         if m.mcrease_id <> cid then []
         else
           match m.mgeom with
           | MSeg (a, b) -> paper_segment_pieces g (a, b)
           | MPoint p ->
               let t = table_position g p in
               [ (t, t) ])

(* The mark [cid]'s current TABLE-space axis, tracking folds/flips (its paper
   geometry is fold-invariant, so the current line is the paper chord mapped to
   the table). [`Bent] if a fold has bent the chord (its paper midpoint no
   longer maps onto the straight table chord): the caller must pick a flap. *)
let mark_axis_current (g : t) (cid : int) :
    [ `Line of Geom.line | `Bent | `Empty | `Collapsed ] =
  match mark_chords g cid with
  | [] -> `Empty
  | (a, b) :: _ ->
      let ta = table_position g a and tb = table_position g b in
      if Geom.point_equal ta tb then `Collapsed
      else
        let mid =
          { Geom.x = Num.div (Num.add a.Geom.x b.Geom.x) (Num.of_int 2);
            y = Num.div (Num.add a.Geom.y b.Geom.y) (Num.of_int 2) }
        in
        let tm = table_position g mid in
        let l = Geom.line_through ta tb in
        if Geom.side_of_line l tm = 0 then `Line l else `Bent

(* the face whose PAPER polygon contains the mark's representative point; paper
   coordinates partition the sheet, so this is unique in the interior (a point on
   a shared boundary may match several: first match wins, callers disambiguate). *)
let mark_face (g : t) (m : mark) : int option =
  let p = mark_rep_point m in
  let n = Array.length g.faces in
  let rec go i =
    if i >= n then None
    else if Geom.in_convex_polygon g.faces.(i) p then Some i
    else go (i + 1)
  in
  go 0

(* A mark's paper-space extent, classified against the flap (coplanar cluster)
   it lives on: does it subdivide the flap (a FULL CHORD: both endpoints on
   the flap's outer boundary, crossing only F edges in between), merely
   record (ANY endpoint strictly mid-face: the whole contiguous extent
   becomes one non-subdividing record, splitting nothing, even where it
   crosses face-to-face in the middle), or is it illegal because it would
   leave the flap across a folded (M/V) crease? *)
type mark_class =
  | CSubdivide of Geom.point * Geom.point
  | CRecord of mark_geom
  | CCrossesFold of Geom.point * Geom.point

(* true iff point [p] lies on some edge (endpoints included) of convex CCW
   [poly]. *)
let point_on_polygon_boundary (poly : Geom.point array) (p : Geom.point) : bool
    =
  let n = Array.length poly in
  let rec go i =
    if i >= n then false
    else
      let a = poly.(i) and b = poly.((i + 1) mod n) in
      if Geom.on_segment (a, b) p then true else go (i + 1)
  in
  go 0

(* Emit-time graduation test (design §3.6, packages/core/lib/fold_emit.ml's
   [cp_display]): true when a [seg] mark's endpoints already sit on a face
   boundary in this state's current topology, i.e. it's indistinguishable
   from a real crease and should stop being drawn as a dangling record.
   Point marks never graduate. *)
let mark_graduates (st : t) (m : mark) : bool =
  let material (p : Geom.point) =
    Array.exists (fun f -> point_on_polygon_boundary f p) (faces st)
  in
  match m.mgeom with
  | MSeg (a, b) -> material a && material b
  | MPoint _ -> false

(* The polygon edge (as its two vertices) of convex CCW [poly] that contains
   point [p], assumed to lie on the boundary. First match wins: at a vertex
   this picks one of the two incident edges arbitrarily, which is fine here:
   every caller only needs the *no-crease vs M/V* status of whichever real
   crease (if any) meets the flap at [p]. *)
let polygon_edge_at (poly : Geom.point array) (p : Geom.point) :
    (Geom.point * Geom.point) option =
  let n = Array.length poly in
  let rec go i =
    if i >= n then None
    else
      let a = poly.(i) and b = poly.((i + 1) mod n) in
      if Geom.on_segment (a, b) p then Some (a, b) else go (i + 1)
  in
  go 0

(* Is some polygon edge of face [fi] passing through boundary point [p] a
   genuine flap boundary: a bare paper edge (no hinge recorded at all) or a
   folded (M/V) hinge? A flat (angle 0) hinge never counts: within one flap
   every internal edge is flat by construction (coplanar clusters are exactly
   the flat-connected components), so a flat edge here always stays inside the
   flap. At a vertex of the face both incident edges are asked, since one of
   them may be a flat hinge while the other is the flap's boundary. *)
let is_flap_boundary_at (g : t) (fi : int) (p : Geom.point) : bool =
  let poly = g.faces.(fi) in
  let n = Array.length poly in
  List.exists
    (fun i ->
      let v1 = poly.(i) and v2 = poly.((i + 1) mod n) in
      Geom.on_segment (v1, v2) p
      &&
      match hinge_between g fi v1 v2 with
      | None -> true
      | Some hi -> Num.sign g.hinges.(hi).angle <> 0)
    (List.init n Fun.id)

(* [p] lies on an edge of some face that no hinge joins to another face: the
   raw edge of the sheet, whatever its shape. *)
let on_raw_edge (g : t) (p : Geom.point) : bool =
  let on_face_raw_edge fi =
    let poly = g.faces.(fi) in
    let n = Array.length poly in
    List.exists
      (fun i ->
        let v1 = poly.(i) and v2 = poly.((i + 1) mod n) in
        Geom.on_segment (v1, v2) p && hinge_between g fi v1 v2 = None)
      (List.init n Fun.id)
  in
  List.exists on_face_raw_edge (List.init (Array.length g.faces) Fun.id)

(* The flap face [p] is strictly interior to, if any. *)
let strictly_interior_to_flap_face (g : t) (flap : int list) (p : Geom.point)
    : int option =
  List.find_opt
    (fun fi ->
      let poly = g.faces.(fi) in
      Geom.in_convex_polygon poly p && not (point_on_polygon_boundary poly p))
    flap

(* [p] is "on the flap boundary" iff it is not strictly interior to any flap
   face and it lies on a true boundary edge (paper edge or M/V hinge) of some
   flap face. *)
let endpoint_is_flap_boundary (g : t) (flap : int list) (p : Geom.point) :
    bool =
  match strictly_interior_to_flap_face g flap p with
  | Some _ -> false
  | None -> List.exists (fun fi -> is_flap_boundary_at g fi p) flap

(* For each face in [flap], the portion (as a parameter range over [a,b], with
   t=0 at [a] and t=1 at [b]) of [axis] clipped to that face's paper polygon
   AND to the extent [a,b] itself. Only positive-length overlaps are kept,
   sorted by increasing [lo]. *)
let flap_face_overlap (g : t) (flap : int list) (axis : Geom.line)
    (a : Geom.point) (b : Geom.point) : (int * Num.t * Num.t) list =
  List.filter_map
    (fun fi ->
      match Geom.clip_line_to_convex axis g.faces.(fi) with
      | None -> None
      | Some (p, q) ->
          let tp = Geom.seg_param (a, b) p and tq = Geom.seg_param (a, b) q in
          let lo = if Num.compare tp tq <= 0 then tp else tq in
          let hi = if Num.compare tp tq <= 0 then tq else tp in
          let lo' = if Num.compare lo Num.zero > 0 then lo else Num.zero in
          let hi' = if Num.compare hi Num.one < 0 then hi else Num.one in
          if Num.compare lo' hi' < 0 then Some (fi, lo', hi') else None)
    flap
  |> List.sort (fun (_, l1, _) (_, l2, _) -> Num.compare l1 l2)

(* Classify a segment extent [a,b] with motion line [axis] against [flap]. See
   [classify_mark_extent] below for the full algorithm; this is its [MSeg]
   case, split out for readability. *)
let classify_seg (g : t) ~(flap : int list) ~(axis : Geom.line)
    (a : Geom.point) (b : Geom.point) : mark_class =
  let point_at t =
    {
      Geom.x = Num.add a.Geom.x (Num.mul t (Num.sub b.Geom.x a.Geom.x));
      y = Num.add a.Geom.y (Num.mul t (Num.sub b.Geom.y a.Geom.y));
    }
  in
  let segs = flap_face_overlap g flap axis a b in
  let fully_covers_axis =
    match segs with
    | [] -> false
    | (_, lo0, _) :: _ when Num.sign lo0 <> 0 -> false
    | _ ->
        let rec walk = function
          | (fi, _, hii) :: ((_fj, loj, _) :: _ as rest) ->
              if Num.compare hii loj <> 0 then false
              else begin
                match polygon_edge_at g.faces.(fi) (point_at hii) with
                | Some (v1, v2) -> (
                    match hinge_between g fi v1 v2 with
                    | Some hi when Num.sign g.hinges.(hi).angle <> 0 -> false
                    | _ -> walk rest)
                | None -> false
              end
          | [ (_, _, hilast) ] -> Num.compare hilast Num.one = 0
          | [] -> false
        in
        walk segs
  in
  if not fully_covers_axis then CCrossesFold (a, b)
  else
    let a_boundary = endpoint_is_flap_boundary g flap a in
    let b_boundary = endpoint_is_flap_boundary g flap b in
    if a_boundary && b_boundary then CSubdivide (a, b)
    else
      (* at least one endpoint strictly mid-face: the whole contiguous extent
         records as one stub, splitting nothing, even the faces it crosses
         boundary-to-boundary in the middle. *)
      CRecord (MSeg (a, b))

(* Does a mark's paper-space [extent_geom] subdivide [flap] (the coplanar
   cluster it lives on), merely record onto it, do both, or illegally cross a
   folded (M/V) crease? [axis] is the extent's own paper-space motion line
   (the line the segment/point lies on, e.g. the line a [between] extent was
   cut from). A full-extent mark never reaches here (the caller handles that
   as a plain [subdivide]).

   [MPoint] never subdivides and has no span to cross a fold with, so it
   always records. For [MSeg (a, b)]: walk the sub-segments of [axis] clipped
   to each flap face's paper polygon and to [a,b] itself; a gap, or an
   internal crossing over a non-flat hinge, means the extent leaves the flap
   (illegal: [CCrossesFold]); full coverage plus both endpoints on the
   flap's true boundary (a bare paper edge or an M/V hinge, never a flat
   hinge) subdivides (a full chord); full coverage with at least one endpoint
   strictly mid-face records the whole contiguous extent as one stub,
   splitting nothing, even faces it crosses boundary-to-boundary in the
   middle. *)
let classify_mark_extent (g : t) ~(flap : int list) ~(axis : Geom.line)
    ~(extent_geom : mark_geom) : mark_class =
  match extent_geom with
  | MPoint p -> CRecord (MPoint p)
  | MSeg (a, b) -> classify_seg g ~flap ~axis a b
