(** The 3D-native folded-state core (issue #48, spec 2026-07-15-fold-state-3d-
    rewrite). Faces = 2D paper polygons; hinges = the face-adjacency graph. A
    face's 3D placement is DERIVED as the product of hinge motions along a path
    from the root — so adjacent faces differ by exactly their hinge's motion and
    a torn state cannot be written down. Layer order is a rank permutation and
    M/V is derived from it (never stored). Flat-first: hinge angle (dihedral/π) ∈
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
  intent : assign;  (* crease-pattern colour (old eintent) — user intent, stored *)
  prov : State.provenance option;
}

type mark_geom = MSeg of Geom.point * Geom.point | MPoint of Geom.point

(* Paper-space, fold-invariant reference/pinch record (moved verbatim from the
   old Fold_state; see that module's doc comment). No invariants of its own. *)
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
  rank : int array;  (* stacking height per face, higher = above; permutation *)
  base : Isometry3.t;  (* placement of the root face — ONE whole-sheet motion *)
  marks : mark array;
  isos : Isometry3.t array;  (* derived in [make] (memoized BFS); [t] abstract ⇒ cannot desync *)
  segs : (Geom.point * Geom.point) array [@warning "-69"];
      (* per-hinge shared paper segment; unread until Task 2 exposes an accessor *)
}

(* Mints internal crease ids; reset per eval so ids are a deterministic
   function of the program. Own counter — the old Fold_state keeps its own
   until Plan 3c deletes it. *)
let next_id = ref 0
let reset_ids () = next_id := 0
let fresh_crease_id () =
  let id = !next_id in
  incr next_id;
  id

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
   composes its motion onto the already-placed face's placement. [hinge_motion]
   is oriented fa→fb (iso.(fb) = compose iso.(fa) (hinge_motion h)); crossing
   fb→fa uses the inverse. Flat-first the two coincide (half-turns are
   involutions), but the direction-awareness is what keeps this — and the
   uniform closure check in [make] — valid for Stage B's non-involutive rπ
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

let to3 (p : Geom.point) : I3.point = { I3.x = p.Geom.x; y = p.Geom.y; z = Num.zero }
let to2 (p : I3.point) : Geom.point = { Geom.x = p.I3.x; y = p.I3.y }

(* Flat projection of face [i] under its derived placement, normalized to CCW:
   a reflected placement reverses the winding, and
   [Geom.segment_crosses_interior] requires CCW input. *)
let table_polygon_ccw (faces : face array) (isos : I3.t array) (i : int) :
    Geom.point array =
  let tp = Array.map (fun p -> to2 (I3.apply_point isos.(i) (to3 p))) faces.(i) in
  if Num.sign (Geom.signed_area tp) < 0 then begin
    let n = Array.length tp in
    Array.init n (fun k -> tp.(n - 1 - k))
  end
  else tp

(* Is [c]'s rank strictly between [a]'s and [b]'s? *)
let rank_between (rank : int array) (a : int) (c : int) (b : int) : bool =
  (rank.(a) < rank.(c) && rank.(c) < rank.(b))
  || (rank.(b) < rank.(c) && rank.(c) < rank.(a))

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
      then raise (V (Bad_angle i));
      if Num.sign h.line.Geom.a = 0 && Num.sign h.line.Geom.b = 0 then
        raise (V (Bad_line i)))
    hinges;
  if Array.length rank <> n then raise (V Bad_rank);
  let hit = Array.make n false in
  Array.iter
    (fun r ->
      if r < 0 || r >= n || hit.(r) then raise (V Bad_rank) else hit.(r) <- true)
    rank

(* [?base]/[?marks] are LEADING optional arguments with only labelled
   required arguments after them; OCaml can only erase omitted optional
   arguments when a positional argument follows, so [make] takes a trailing
   [unit] to anchor that — existing call sites add a trailing [()]. *)
let make ?(base = I3.identity) ?(marks = [||]) ~(faces : face array)
    ~(hinges : hinge array) ~(root : int) ~(rank : int array) () :
    (t, violation) result =
  try
    check_structure ~faces ~hinges ~root ~rank;
    let isos, seen = derive_isos ~faces ~hinges ~root ~base in
    Array.iteri (fun i s -> if not s then raise (V (Disconnected i))) seen;
    (* hinge adjacency: each hinge's line must carry a positive-length shared
       boundary segment between its faces (paper space); the segments feed the
       non-crossing checks (Task 6) *)
    let segs =
      Array.mapi
        (fun i h ->
          match hinge_shared_segment faces h with
          | Some s -> s
          | None -> raise (V (Hinge_not_shared i)))
        hinges
    in
    (* cycle closure: the BFS fixed a spanning tree; every hinge must agree
       with the placements — for non-tree (cycle) hinges this is the real
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
    (* Non-crossing [hull2020 §6.5; hullzakharevich2023 §2.1] over the flat
       projection. Rank decides every pair, so tortilla-tortilla and stacking
       cycles are unrepresentable; these two residual conditions remain. Rank
       comparison is sound here because each check first establishes geometric
       coincidence (interior crossing / collinear overlap), so the compared
       faces genuinely overlap where they are compared. *)
    let n = Array.length faces in
    let tseg i =
      let p, q = segs.(i) in
      let place = isos.(hinges.(i).fa) in
      (to2 (I3.apply_point place (to3 p)), to2 (I3.apply_point place (to3 q)))
    in
    (* taco-tortilla: a folded hinge's faces coincide after the fold (they
       share the crease edge and fold to the same side), forming a taco; no
       face ranked between them may cross the crease's interior *)
    Array.iteri
      (fun i h ->
        if Num.sign h.angle <> 0 then begin
          let seg = tseg i in
          for c = 0 to n - 1 do
            if
              c <> h.fa && c <> h.fb
              && rank_between rank h.fa c h.fb
              && Geom.segment_crosses_interior seg
                   (table_polygon_ccw faces isos c)
            then raise (V (Taco_tortilla { tortilla = c; hinge = i }))
          done
        end)
      hinges;
    (* taco-taco: two folded hinges over disjoint face pairs whose crease
       segments coincide on the table must not interleave in the stack *)
    let m = Array.length hinges in
    for i = 0 to m - 1 do
      for j = i + 1 to m - 1 do
        let h1 = hinges.(i) and h2 = hinges.(j) in
        let a = h1.fa and b = h1.fb and c = h2.fa and d = h2.fb in
        if
          Num.sign h1.angle <> 0 && Num.sign h2.angle <> 0
          && a <> c && a <> d && b <> c && b <> d
          && Geom.segments_overlap_collinear (tseg i) (tseg j)
          && rank_between rank a c b <> rank_between rank a d b
        then raise (V (Taco_taco (i, j)))
      done
    done;
    Ok
      {
        faces = Array.map Array.copy faces;
        hinges = Array.copy hinges;
        root;
        rank = Array.copy rank;
        base;
        marks = Array.copy marks;
        isos;
        segs;
      }
  with V v -> Error v

let faces (g : t) : face array = Array.map Array.copy g.faces
let hinges (g : t) : hinge array = Array.copy g.hinges
let root (g : t) : int = g.root
let rank (g : t) : int array = Array.copy g.rank
let above (g : t) (i : int) (j : int) : bool = g.rank.(i) > g.rank.(j)
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
   above(fb, fa) = face_up(fa). Side-symmetric — read from fb, BOTH sides of
   the equality negate (above by rank antisymmetry, face_up because a folded
   hinge separates one face-up from one face-down placement), so both
   readings give the same M/V. Flat hinges
   (angle = 0) derive F. Derived, never stored: rank and placements are
   the only inputs, so MV cannot contradict the geometry. Stage B: partial
   angles (rπ) make m22 = cos(rπ) ≠ ±1 and "folded" non-binary — both this
   and [face_up] need revisiting when the angle domain widens (until then
   [make]'s Bad_angle check keeps them unreachable). *)
let mv (g : t) (i : int) : assign =
  let h = g.hinges.(i) in
  if Num.sign h.angle = 0 then F
  else if above g h.fb h.fa = face_up g h.fa then V else M
