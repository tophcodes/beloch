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
  segs : (Geom.point * Geom.point) array;
      (* per-hinge shared paper segment; exposed via [hinge_segment] *)
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
   placement (±π about the same axis coincide) — M/V is the layer order. *)
let hinge_motion (h : hinge) : I3.t =
  if Num.sign h.angle = 0 then I3.identity else half_turn3_of_line h.line

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
let table_polygon_ccw_raw (faces : face array) (isos : I3.t array) (i : int) :
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
                   (table_polygon_ccw_raw faces isos c)
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

(* In-plane 2D restriction of face [i]'s derived placement. Flat-first the
   motions keep z = 0 invariant (angles ∈ {0, ±1}), so the upper-left block +
   (tx, ty) IS the table placement as a 2D isometry. Stage B (partial angles)
   lifts faces off the plane and must not use this. *)
let face_iso2 (g : t) (i : int) : Isometry.t =
  let m = g.isos.(i) in
  { Isometry.m00 = m.I3.m00; m01 = m.I3.m01; m10 = m.I3.m10; m11 = m.I3.m11;
    tx = m.I3.tx; ty = m.I3.ty }

let table_polygon (g : t) (i : int) : Geom.point array =
  Array.map (Isometry.apply_point (face_iso2 g i)) g.faces.(i)

(* CCW-normalized (a reflected placement reverses winding); the clip/crossing
   helpers in Geom require CCW input. *)
let table_polygon_ccw (g : t) (i : int) : Geom.point array =
  let tp = table_polygon g i in
  if Num.sign (Geom.signed_area tp) < 0 then begin
    let n = Array.length tp in
    Array.init n (fun k -> tp.(n - 1 - k))
  end
  else tp

type rel = Above | Below | Apart

(* Layer relation of two faces: rank order where the flat projections overlap
   (Geom.convex_overlap is SAT-based, winding-independent, strict — touching
   is not overlap, same as the old Layer_order), Apart otherwise. *)
let rel (g : t) (i : int) (j : int) : rel =
  if i = j then Apart
  else if Geom.convex_overlap (table_polygon g i) (table_polygon g j) then
    if g.rank.(i) > g.rank.(j) then Above else Below
  else Apart

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
    if i >= n then invalid_arg "Fold_graph.table_position: point in no face"
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
(* Construction operations (Plan 3a). Each op builds new arrays and    *)
(* re-validates through [make]; a violation raises [Error.fail] at the *)
(* provenance span. Faces never carry isometries — a fold only sets    *)
(* hinge angles and the rank.                                          *)
(* ------------------------------------------------------------------ *)

let fail_of_violation (prov : State.provenance option) (v : violation) : 'a =
  let span =
    match prov with
    | Some p -> p.State.span
    | None -> (Lexing.dummy_pos, Lexing.dummy_pos)
  in
  Error.fail span (violation_to_string v)

let init_square : t =
  let p x y = { Geom.x = Num.of_int x; y = Num.of_int y } in
  match
    make ~faces:[| [| p 0 0; p 1 0; p 1 1; p 0 1 |] |] ~hinges:[||] ~root:0
      ~rank:[| 0 |] ()
  with
  | Ok g -> g
  | Error _ -> assert false

(* The chord (in PAPER coordinates) where table-space [axis] crosses the
   interior of face [i]; None if it misses (touches at most a point).
   Port of the old Fold_state.axis_segment_in_face. *)
let axis_chord_in_face (g : t) (i : int) (axis : Geom.line) :
    (Geom.point * Geom.point) option =
  let iso2 = face_iso2 g i in
  let table = Array.map (Isometry.apply_point iso2) g.faces.(i) in
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
         [reattach_hinges]'s adjacency check, both sign-invariant — but a
         stable, deterministic order still matters so the same cut always
         mints the same hinge-line representation. Child order (plus vs
         minus) is decided upstream by clipping [axis] itself, not by this
         chord. *)
      let lo, hi =
        if Num.compare (line_param axis p) (line_param axis q0) <= 0 then
          (p, q0)
        else (q0, p)
      in
      let inv = Isometry.inverse iso2 in
      Some (Isometry.apply_point inv lo, Isometry.apply_point inv hi)
  | _ -> None

(* Re-attach the old hinges over a face split. [children_of p] lists the child
   indices of old face p (a single element when uncut). A candidate pair keeps
   the hinge iff its line still carries a positive shared boundary segment
   between the two children (D7) — degenerate pieces drop out here. *)
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

(* Dense rank over the children: children inherit their parent's height;
   within one parent, array order (plus-child first) breaks the tie. *)
let densify_rank ~(old_rank : int array) ~(parent : int array) : int array =
  let n' = Array.length parent in
  let idx = Array.init n' Fun.id in
  Array.sort
    (fun i j -> compare (old_rank.(parent.(i)), i) (old_rank.(parent.(j)), j))
    idx;
  let rank' = Array.make n' 0 in
  Array.iteri (fun h i -> rank'.(i) <- h) idx;
  rank'

(* Shared splitter for [subdivide] (table-space axis, optional ray guard) and
   [subdivide_paper] (paper-space line). [cut_of i] gives the PRE-CLIPPED
   paper-space children plus the paper chord for face i, or None to keep it
   whole (the caller decides: not cut, guard-excluded, or a degenerate part
   with fewer than 3 vertices). Children order per parent: plus side first,
   then minus (D9 — matches the old face order). Clipping the caller's
   canonical line/axis directly (rather than reconstructing a line from the
   chord via [Geom.line_through], whose sign depends on point order) is what
   keeps child order in sync with the old model — see findings on commit
   1f0436f. *)
let split_with_flat_hinges (g : t) ~(cid : int) ~(intent : assign)
    ~(prov : State.provenance option)
    ~(cut_of :
       int ->
       (Geom.point array * Geom.point array * (Geom.point * Geom.point))
       option) : t =
  let out = ref [] in (* (paper_poly, parent) — prepended, reversed at the end *)
  let chords = ref [] in (* (parent, a, b) for each actually-cut face *)
  Array.iteri
    (fun fi f ->
      match cut_of fi with
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
              crease_id = cid; intent; prov }
        | _ -> assert false)
      !chords
  in
  let carried = reattach_hinges ~faces' ~children_of g.hinges in
  let rank' = densify_rank ~old_rank:g.rank ~parent in
  let root' = List.hd (children_of g.root) in
  match
    make ~base:g.base ~marks:g.marks ~faces:faces'
      ~hinges:(Array.of_list (new_hinges @ carried)) ~root:root' ~rank:rank'
      ()
  with
  | Ok g' -> g'
  | Error v -> fail_of_violation prov v

let subdivide ?crease_id ?(intent : assign = V) ?keep_side (g : t) (axis : Geom.line)
    ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  let on_keep_side fi =
    match keep_side with
    | None -> true
    | Some (guard, keep) ->
        (* table centroid of the face, old on_keep_side *)
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
     paper via the face's own [face_iso2] — never reconstruct a line from the
     chord (its sign would depend on point order, see findings on commit
     1f0436f). *)
  let cut_of fi =
    if not (on_keep_side fi) then None
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
          match axis_chord_in_face g fi axis with
          | Some (a, b) -> Some (map_back tp, map_back tm, (a, b))
          | None -> None)
      | _ -> None
  in
  split_with_flat_hinges g ~cid ~intent ~prov ~cut_of

let subdivide_paper ?crease_id ?(intent : assign = V) (g : t) (paper_axis : Geom.line)
    ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  (* PLUS child = paper_axis side +1 (old-model convention): clip the paper
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
  split_with_flat_hinges g ~cid ~intent ~prov ~cut_of

(* Simple flat fold as a graph transformation: cut the moving faces along
   [axis], give the cut hinges angle 1, toggle existing on-axis hinges with
   exactly one moving side (D8), restack via rank blocks. Placements are
   derived; nothing composes isometries onto faces. Raises [Error.fail] when
   the resulting state violates an invariant (old validity_error behaviour). *)
let fold ?crease_id ?moving_parents (g : t) ~(axis : Geom.line)
    ~(move_side : int) ~(valley : bool) ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  let moves fi =
    match moving_parents with None -> true | Some m -> m.(fi)
  in
  (* the crease-pattern letter of the fold on parent face fi: the user's
     valley XOR the parent's orientation parity (old assign_of) *)
  let letter_of fi : assign =
    if valley <> (Isometry.det_sign (face_iso2 g fi) < 0) then V else M
  in
  (* 1. split: stationary children (stay side + all non-movers) and moved
     children, in the OLD accumulation order (D9): stay list is reversed at
     the end, mov list is not. *)
  let stay = ref [] and mov = ref [] in (* (paper_poly, parent) *)
  let chords = ref [] in (* (parent, a, b) for each face actually cut *)
  Array.iteri
    (fun fi f ->
      if not (moves fi) then stay := (f, fi) :: !stay
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
        (match s with Some poly -> stay := (poly, fi) :: !stay | None -> ());
        match m with Some poly -> mov := (poly, fi) :: !mov | None -> ()
      end)
    g.faces;
  let stationary = List.rev !stay in
  let moved = !mov in
  let ordered = if valley then stationary @ moved else moved @ stationary in
  let arr = Array.of_list ordered in
  let faces' = Array.map fst arr in
  let parent = Array.map snd arr in
  let n_stay = List.length stationary in
  let moved_flag =
    if valley then Array.init (Array.length arr) (fun i -> i >= n_stay)
    else Array.init (Array.length arr) (fun i -> i < List.length moved)
  in
  let children_of p =
    let acc = ref [] in
    Array.iteri (fun k pp -> if pp = p then acc := k :: !acc) parent;
    List.rev !acc
  in
  (* 2. new folded hinges along the axis, one per cut parent *)
  let new_hinges =
    List.rev_map
      (fun (fi, a, b) ->
        let sc = ref (-1) and mc = ref (-1) in
        Array.iteri
          (fun k pp ->
            if pp = fi then if moved_flag.(k) then mc := k else sc := k)
          parent;
        { fa = !sc; fb = !mc; line = Geom.line_through a b; angle = Num.one;
          crease_id = cid; intent = letter_of fi; prov })
      !chords
  in
  (* 3. carried hinges: re-attach (D7), then toggle on-axis hinges with
     exactly one moving side (D8) *)
  let moved_parent = Array.make (Array.length g.faces) false in
  Array.iteri
    (fun k pp -> if moved_flag.(k) then moved_parent.(pp) <- true)
    parent;
  let on_axis_of_old = Array.make (Array.length g.hinges) false in
  Array.iteri
    (fun hi (_ : hinge) ->
      let ta, tb = hinge_table_segment g hi in
      on_axis_of_old.(hi) <-
        Geom.side_of_line axis ta = 0 && Geom.side_of_line axis tb = 0)
    g.hinges;
  let carried =
    Array.to_list
      (Array.mapi
         (fun hi (h : hinge) ->
           let toggled =
             on_axis_of_old.(hi)
             && moved_parent.(h.fa) <> moved_parent.(h.fb)
           in
           let h =
             if not toggled then h
             else if Num.sign h.angle = 0 then
               (* precrease upgrade: F -> folded, intent gets the live letter
                  of the MOVED parent (old assign_of_parent mf, #27) *)
               let mf = if moved_parent.(h.fa) then h.fa else h.fb in
               { h with angle = Num.one; intent = letter_of mf }
             else { h with angle = Num.zero } (* physical unfold *)
           in
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
         g.hinges)
    |> List.concat
  in
  (* 4. rank blocks: stationaries keep their order; movers reversed; movers
     on top for valley, below for mountain (old rel_of semantics) *)
  let n' = Array.length faces' in
  let idx = Array.init n' Fun.id in
  let key i =
    let r = g.rank.(parent.(i)) in
    if moved_flag.(i) then (1, -r, i) else (0, r, i)
  in
  let block_first = if valley then 0 else 1 in
  Array.sort
    (fun i j ->
      let (bi, ki, ti) = key i and (bj, kj, tj) = key j in
      let bi = if bi = block_first then 0 else 1
      and bj = if bj = block_first then 0 else 1 in
      compare (bi, ki, ti) (bj, kj, tj))
    idx;
  let rank' = Array.make n' 0 in
  Array.iteri (fun h i -> rank'.(i) <- h) idx;
  (* 5. root + base: prefer a stationary child (its parent's placement is
     unchanged); if everything moved, reflect the base across the axis *)
  let root', base' =
    let stat = ref (-1) in
    (match children_of g.root with
    | cs -> List.iter (fun c -> if (not (moved_flag.(c))) && !stat < 0 then stat := c) cs);
    if !stat >= 0 then (!stat, g.isos.(g.root))
    else begin
      let first_stat = ref (-1) in
      Array.iteri
        (fun k m -> if (not m) && !first_stat < 0 then first_stat := k)
        moved_flag;
      if !first_stat >= 0 then (!first_stat, g.isos.(parent.(!first_stat)))
      else (0, I3.compose (half_turn3_of_line axis) g.isos.(parent.(0)))
    end
  in
  match
    make ~base:base' ~marks:g.marks ~faces:faces'
      ~hinges:(Array.of_list (List.rev_append (List.rev new_hinges) carried))
      ~root:root' ~rank:rank' ()
  with
  | Ok g' -> g'
  | Error v -> fail_of_violation prov v

let simple_fold (g : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) : t =
  fold g ~axis ~move_side ~valley ~prov:None

(* Turn the whole sheet over: reflect across the footprint's vertical
   centerline (cosmetic internal axis, as in the old model), reverse the face
   array (D9 — emit order), reverse the stack. base absorbs the reflection —
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
    let rank' = Array.init n (fun k -> n - 1 - g.rank.(n - 1 - k)) in
    let root' = n - 1 - g.root in
    let base' = I3.compose (half_turn3_of_line axis) g.isos.(g.root) in
    match
      make ~base:base' ~marks:g.marks ~faces:faces' ~hinges:hinges'
        ~root:root' ~rank:rank' ()
    with
    | Ok g' -> g'
    | Error v -> fail_of_violation None v
  end

(* Marks carry no invariants; append without re-validation. *)
let add_mark (g : t) (m : mark) : t =
  { g with marks = Array.append g.marks [| m |] }

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
   [line] not paired with a neighbor across a hinge (port of the old function;
   see its doc comment in fold_state.ml). *)
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

let crease_axis (g : t) (cid : int) (l_orig : Geom.line) :
    [ `Line of Geom.line | `Bent | `Empty ] =
  match crease_table_endpoints g cid with
  | [] -> `Empty
  | pts ->
      if List.for_all (fun p -> Geom.side_of_line l_orig p = 0) pts then
        `Line l_orig
      else (
        match pick_two_distinct pts with
        | None -> `Empty
        | Some (a, b) ->
            let l = Geom.line_through a b in
            if List.for_all (fun p -> Geom.side_of_line l p = 0) pts then
              `Line l
            else `Bent)

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
