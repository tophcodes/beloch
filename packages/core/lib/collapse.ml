(** Single-vertex collapse: fold along n >= 4 material crease segments sharing
    one interior endpoint O: the flat end state of a multi-crease move
    (rabbit ear [hull2020, Thm 8.5]). Skips the 3D intermediate entirely:
    checks the end state exists (Kawasaki and Maekawa where the anchor
    surrounds O, the closure of the paper paths everywhere), moves each face
    by the creases on its paper path (ADR 0044), enumerates valid layer
    orders. *)

type elem = { cid : int; ea : Geom.point; eb : Geom.point; valley : bool }

(* --- error strings: spec §Errors table, verbatim ------------------------- *)
let e_no_vertex = "no common interior vertex"
let e_count = "count"
let e_midpaper = "crease ends inside the sheet"
let e_kawasaki = "vertex not flat-foldable (angles)"
let e_maekawa = "Maekawa violated by the stated assignment"
let e_selfint = "assignment forces self-intersection"
let e_contra = "contradictory `over`"
let e_dup_ray = "duplicate ray in collapse"
let e_ambig k = Printf.sprintf "ambiguous stacking (%d orders)" k
let e_out_of_paper =
  "collapse folds a flap off the paper (no seating keeps it in the sheet)"
let e_stayer_collinear = "collinear leading creases don't pick a stayer"
let e_stayer_dead = "no realization keeps the staying flap still"
let e_unaligned = "collapse through unaligned layers"
let e_anchor_stays =
  "the anchor flap has no material outside the staying sector"
let e_staying_none = "no sector of the fan holds every staying point"
let e_staying_several = "the staying points lie in more than one sector"
let e_staying_off_anchor = "the staying sector holds no material of the anchor"

(* the hint that goes with an error string above, where it has one (ADR 0028) *)
let hint_of (m : string) : string option =
  if m = e_count then Some "use `fold` for n = 2"
  else if m = e_stayer_collinear then Some "add (staying .p)"
  else if m = e_staying_several then
    Some "add a point inside the sector that stays"
  else None

(* --- stayer: the material that does not move (design 2026-07-17) -----------
   Anchors the fan labeling geometrically instead of at [sort_ccw]'s arbitrary
   east origin. [Arc (pa, pb)] = the far tips of the two leading elements'
   folded rays; the stayer region is the <π CCW arc between them. [Faces fs] =
   the pre-collapse face indices carrying the stayed material. [Points ps] =
   the table images of the points of `staying` (ADR 0048): the stayer is the
   one sector whose closed wedge holds all of them. *)
type stayer =
  | Arc of Geom.point * Geom.point
  | Faces of int list
  | Points of Geom.point list

exception Stayer_collinear

(* --- small exact helpers -------------------------------------------------- *)

let cross (ox, oy) (px, py) (qx, qy) =
  (* cross of (p-o) and (q-o) *)
  Num.sub
    (Num.mul (Num.sub px ox) (Num.sub qy oy))
    (Num.mul (Num.sub py oy) (Num.sub qx ox))

(* 1. common vertex: a point equal to one endpoint of EVERY elem *)
let common_vertex (es : elem list) : Geom.point option =
  match es with
  | [] -> None
  | e0 :: _ ->
      let shared_by_all p =
        List.for_all
          (fun e -> Geom.point_equal e.ea p || Geom.point_equal e.eb p)
          es
      in
      if shared_by_all e0.ea then Some e0.ea
      else if shared_by_all e0.eb then Some e0.eb
      else None

(* the endpoint of [e] that is NOT [o] (the ray's far tip) *)
let far_of (o : Geom.point) (e : elem) : Geom.point =
  if Geom.point_equal e.ea o then e.eb else e.ea

(* 2. rays: sort [elems] CCW by the direction (far tip − O), using the exact
   angular comparator in Geom (half classification then cross product). *)
let sort_ccw (o : Geom.point) (es : elem list) : (Geom.point * elem) list =
  es
  |> List.map (fun e -> (far_of o e, e))
  |> List.sort (fun (a, _) (b, _) -> Geom.ccw_compare ~center:o a b)

(* Effective valley of a crease whose LEFT (stayer) sector is placed by
   [sec_transform] over a stayer face already carrying [face_iso]. Mirrors
   [Fold_state.fold]'s CP-frame intent convention: a stored/effective valley is
   the user's valley [XORed] with the parity of the stayer face's *final*
   orientation: [sec_transform ∘ face_iso]. Folding in [face_iso] (not just
   the sector transform) is what makes a prior `flip` invert M/V relative to
   the original front (spec §4.7): every pre-collapse face is
   orientation-reversed, so every effective valley flips. Shared by the
   hinge-constraint and intent sites. *)
let effective_valley (valley : bool) (sec_transform : Isometry.t)
    (face_iso : Isometry.t) : bool =
  valley <> (Isometry.det_sign (Isometry.compose sec_transform face_iso) < 0)

let is_identity (i : Isometry.t) : bool =
  let z = Num.zero and o = Num.one in
  let probes =
    [ { Geom.x = z; y = z }; { Geom.x = o; y = z }; { Geom.x = z; y = o } ]
  in
  List.for_all (fun p -> Geom.point_equal (Isometry.apply_point i p) p) probes

(* closure: the full-loop reflection product over all n creases must be the
   identity: this is exactly Kawasaki at O. Any cyclic rotation of the product
   is conjugate, so the starting ray does not matter; fold in ray order. *)
let closure_ok (o : Geom.point) (rays : (Geom.point * 'a) array) : bool =
  let prod =
    Array.fold_left
      (fun acc (far, _) ->
        Isometry.compose acc
          (Isometry.reflect_across_line (Geom.line_through o far)))
      Isometry.identity rays
  in
  is_identity prod

(* --- boundary predicates ---------------------------------------------------- *)

(* The ray of [e] from O reaches the boundary of its flap (def-flatten): every
   piece of crease [e.cid] that ends at the ray's far tip on the table, coming
   from O's side, ends there on a raw paper edge or a folded edge of the flap
   it lies in. The test runs in paper space, per layer, so a far tip on a
   folded edge inside the table's square (a book fold's spine) counts. *)
let far_on_flap_boundary (g : Fold_state.t) (o : Geom.point) (e : elem) : bool
    =
  let far = far_of o e in
  let clusters = Fold_state.coplanar_clusters g in
  let nf = Array.length (Fold_state.faces g) in
  let flap_of fi =
    List.filter (fun i -> clusters.(i) = clusters.(fi)) (List.init nf Fun.id)
  in
  let pieces =
    List.filter_map
      (fun (s : Fold_state.crease_segment) ->
        if
          Geom.point_equal s.Fold_state.tb far
          && Geom.on_segment (o, far) s.Fold_state.ta
        then Some (s.Fold_state.pb, s.Fold_state.faces)
        else if
          Geom.point_equal s.Fold_state.ta far
          && Geom.on_segment (o, far) s.Fold_state.tb
        then Some (s.Fold_state.pa, s.Fold_state.faces)
        else None)
      (Fold_state.crease_segments g e.cid)
  in
  pieces <> []
  && List.for_all
       (fun (p, (l, r)) ->
         let flap = flap_of l @ if r >= 0 then flap_of r else [] in
         Fold_state.endpoint_is_flap_boundary g flap p)
       pieces

(* check 4: table point [o] is an interior vertex of the creases [cids] when
   each of them has a segment ending at [o], and every such segment's paper
   point lies off the sheet's raw edge. Read on the paper, not the table, so
   the sheet's shape and where folding has placed it do not matter. *)
let interior_vertex (g : Fold_state.t) (cids : int list) (o : Geom.point) :
    bool =
  List.for_all
    (fun cid ->
      let papers =
        List.filter_map
          (fun (s : Fold_state.crease_segment) ->
            if Geom.point_equal s.Fold_state.ta o then Some s.Fold_state.pa
            else if Geom.point_equal s.Fold_state.tb o then
              Some s.Fold_state.pb
            else None)
          (Fold_state.crease_segments g cid)
      in
      papers <> []
      && List.for_all (fun p -> not (Fold_state.on_raw_edge g p)) papers)
    cids

(* --- enumeration of sector stackings -------------------------------------- *)

(* A stacking is a rank array over sectors: rank.(s) = height (0 = bottom). The
   hinge constraints are pairs (hi, lo): sector hi must be Above sector lo. We
   enumerate linear extensions bottom→top, pruning against those pairs. *)
let linear_extensions (n : int) (constraints : (int * int) list) :
    int array list =
  let results = ref [] in
  let placed = Array.make n false in
  let order = Array.make n (-1) in
  let can_append s =
    (* s goes strictly above every already-placed sector *)
    List.for_all
      (fun (hi, lo) ->
        (* if s is the upper one, its lower must already be below it *)
        (hi <> s || placed.(lo))
        (* if s is the lower one, its upper must not yet be placed below it *)
        && (lo <> s || not placed.(hi)))
      constraints
  in
  let rec go depth =
    if depth = n then begin
      (* order.(depth) = sector at that height; build rank *)
      let rank = Array.make n 0 in
      Array.iteri (fun h s -> rank.(s) <- h) order;
      results := rank :: !results
    end
    else
      for s = 0 to n - 1 do
        if (not placed.(s)) && can_append s then begin
          placed.(s) <- true;
          order.(depth) <- s;
          go (depth + 1);
          placed.(s) <- false
        end
      done
  in
  go 0;
  !results

(* --- the kernel: single-vertex collapse on the hinge-graph core (issue #48).
   Hinge angles and a total face rank are set directly;
   placements (and hence overlaps) are DERIVED by [Fold_state.make], not
   composed by hand, so there is no [folded]/[faces_for_anchor] analogue:
   re-anchoring is just a different (root, base) into the same [make]. -- *)

(* Sector membership of a placed polygon. Interior representative = vertex
   average (convex ⇒ interior), placed on the table via [iso2]. After closure
   every sector angle < π, so p is in sector k iff (p−O) is strictly CCW of
   ray k and strictly CW of ray k+1. Faces were subdivided along every ray,
   so a representative is never exactly on a ray (asserted). *)
let sector_of_poly (o : Geom.point) (rays : (Geom.point * 'a) array)
    ((poly, iso2) : Geom.point array * Isometry.t) : int =
  let n = Array.length rays in
  let sumx = ref Num.zero and sumy = ref Num.zero in
  Array.iter
    (fun (p : Geom.point) ->
      let tp = Isometry.apply_point iso2 p in
      sumx := Num.add !sumx tp.Geom.x;
      sumy := Num.add !sumy tp.Geom.y)
    poly;
  let m = Num.of_int (Array.length poly) in
  let rep = { Geom.x = Num.div !sumx m; y = Num.div !sumy m } in
  let ocoord = (o.Geom.x, o.Geom.y) in
  let repc = (rep.Geom.x, rep.Geom.y) in
  let found = ref (-1) in
  for k = 0 to n - 1 do
    let rk, _ = rays.(k) and rk1, _ = rays.((k + 1) mod n) in
    let c0 = cross ocoord (rk.Geom.x, rk.Geom.y) repc in
    let c1 = cross ocoord (rk1.Geom.x, rk1.Geom.y) repc in
    if Num.sign c0 > 0 && Num.sign c1 < 0 then found := k
  done;
  if !found < 0 then
    invalid_arg
      "Collapse.sector_of_poly: representative not strictly inside a sector";
  !found

(* The sector a placed polygon lies in, or -1 when a ray's half-line from O
   runs through it: a layer the fan crosses without its rays scored on it.
   A sector no wider than a half-turn is convex and holds the polygon iff it
   holds every vertex. A wider one, which a fan has when its rays all lie in
   one half-plane (ADR 0044), holds it iff no vertex lies strictly inside the
   opposite cone. That test can miss an edge that crosses the cone between
   two vertices; the layers of the tip are scored along every ray, so only a
   stationary layer can have such an edge, and it only feeds the stacking of
   the layers the fan leaves where they lie. *)
let sector_of_poly_opt (o : Geom.point) (rays : (Geom.point * 'a) array)
    ((poly, iso2) : Geom.point array * Isometry.t) : int =
  let n = Array.length rays in
  let oc = (o.Geom.x, o.Geom.y) in
  let pts =
    Array.map
      (fun p ->
        let tp = Isometry.apply_point iso2 p in
        (tp.Geom.x, tp.Geom.y))
      poly
  in
  let found = ref (-1) in
  for k = 0 to n - 1 do
    let rk, _ = rays.(k) and rk1, _ = rays.((k + 1) mod n) in
    let rkc = (rk.Geom.x, rk.Geom.y) and rk1c = (rk1.Geom.x, rk1.Geom.y) in
    let wide = n > 1 && Num.sign (cross oc rkc rk1c) < 0 in
    if
      !found < 0
      && Array.for_all
           (fun pc ->
             let c0 = Num.sign (cross oc rkc pc)
             and c1 = Num.sign (cross oc pc rk1c) in
             if wide then not (c0 < 0 && c1 < 0) else c0 >= 0 && c1 >= 0)
           pts
    then found := k
  done;
  !found

(* --- shared pipeline: every check and enumeration step common to [collapse]
   and [collapse_all], up to signature dedup. Returns, per distinct-signature
   realization, the (sector-rank, face-rank) pair anchoring needs: anchoring
   itself is entry-point-specific ([collapse] takes the single rank or errors
   [e_ambig]; [collapse_all] anchors every rank, dropping ones with no
   in-bounds seating instead of erroring). Factored out so [collapse]'s
   observable behavior stays byte-identical (same code path, just relocated)
   while [collapse_all] is new territory built on the same guarantees. *)
(* q strictly inside the CCW arc from a to b around o (endpoints excluded).
   The caller guarantees a->b is the <π CCW arc (cross(a,b) > 0). *)
let in_ccw_arc (o : Geom.point) (a : Geom.point) (b : Geom.point)
    (q : Geom.point) : bool =
  let oc = (o.Geom.x, o.Geom.y) in
  Num.sign (cross oc (a.Geom.x, a.Geom.y) (q.Geom.x, q.Geom.y)) > 0
  && Num.sign (cross oc (q.Geom.x, q.Geom.y) (b.Geom.x, b.Geom.y)) > 0

(* q in the closed wedge swept CCW around o from the ray through a to the ray
   through b, of any angle below 2π: the vertex and both bounding rays
   included. *)
let in_closed_sector (o : Geom.point) (a : Geom.point) (b : Geom.point)
    (q : Geom.point) : bool =
  let oc = (o.Geom.x, o.Geom.y) in
  let pt (p : Geom.point) = (p.Geom.x, p.Geom.y) in
  let on_ray (r : Geom.point) =
    Num.sign (cross oc (pt r) (pt q)) = 0
    && Num.sign
         (Num.add
            (Num.mul (Num.sub r.Geom.x o.Geom.x) (Num.sub q.Geom.x o.Geom.x))
            (Num.mul (Num.sub r.Geom.y o.Geom.y) (Num.sub q.Geom.y o.Geom.y)))
       > 0
  in
  let c = Num.sign (cross oc (pt a) (pt b)) in
  Geom.point_equal q o || on_ray a || on_ray b
  || (if c > 0 then in_ccw_arc o a b q
      else if c < 0 then not (in_ccw_arc o b a q)
      else Num.sign (cross oc (pt a) (pt q)) > 0)

(* rotate the ray labeling so that sector [s0] becomes sector 0: the stayer
   anchoring step. Sector k (between rays k, k+1) maps to k-s0; ray k to k-s0. *)
let rotate_rays (rays : 'a array) (s0 : int) : 'a array =
  let n = Array.length rays in
  Array.init n (fun k -> rays.((k + s0) mod n))

(* admissible ORIGINAL fan sectors carrying the stayer, on the un-rotated
   [rays]. [Faces] -> the sectors of those pre-collapse faces; [Arc] -> the fan
   sectors strictly inside the <π CCW arc between the two leading rays (one
   normally; two when an emergent ray splits the arc). The endpoint-degeneracy
   conjuncts drop the zero-width readings at the arc's own bounding rays. A
   collinear arc cannot pick a side -> [Stayer_collinear]. *)
let admissible_sectors ~(stayer : stayer) (o : Geom.point)
    (rays : (Geom.point * 'a) array) (sec_orig : int array) (nf : int) :
    int list =
  match stayer with
  | Faces fs ->
      List.sort_uniq compare
        (List.filter_map
           (fun i ->
             if i >= 0 && i < nf && sec_orig.(i) >= 0 then Some sec_orig.(i)
             else None)
           fs)
  | Arc (pa, pb) ->
      let oc = (o.Geom.x, o.Geom.y) in
      let c = cross oc (pa.Geom.x, pa.Geom.y) (pb.Geom.x, pb.Geom.y) in
      if Num.sign c = 0 then raise Stayer_collinear
      else
        let a, b = if Num.sign c > 0 then (pa, pb) else (pb, pa) in
        let n = Array.length rays in
        List.filter
          (fun k ->
            let rk, _ = rays.(k) and rk1, _ = rays.((k + 1) mod n) in
            let inc p =
              Geom.point_equal p a || Geom.point_equal p b || in_ccw_arc o a b p
            in
            inc rk && inc rk1
            && (not (Geom.point_equal rk b))
            && not (Geom.point_equal rk1 a))
          (List.init n Fun.id)
  | Points ps ->
      let n = Array.length rays in
      List.filter
        (fun k ->
          let rk, _ = rays.(k) and rk1, _ = rays.((k + 1) mod n) in
          List.for_all (in_closed_sector o rk rk1) ps)
        (List.init n Fun.id)

(* the sectors a run of the pipeline takes as stayer: [admissible_sectors],
   held to exactly one sector carrying material of the anchor under [Points]
   (ADR 0048) *)
let stayer_sectors ~(stayer : stayer) ~(anchor : bool array) (o : Geom.point)
    (rays : (Geom.point * 'a) array) (sec_orig : int array) (nf : int) :
    (int list, string) result =
  match admissible_sectors ~stayer o rays sec_orig nf with
  | exception Stayer_collinear -> Error e_stayer_collinear
  | sectors -> (
      match (stayer, sectors) with
      | Points _, [] -> Error e_staying_none
      | Points _, [ s ] ->
          if
            Array.exists Fun.id
              (Array.mapi (fun i a -> a && sec_orig.(i) = s) anchor)
          then Ok sectors
          else Error e_staying_off_anchor
      | Points _, _ -> Error e_staying_several
      | _, [] -> Error e_stayer_dead
      | _ -> Ok sectors)

(* The faces of the anchor flap (ADR 0040). [Some polys]: the faces lying in
   those paper polygons, the faces of the flap `on` names before the state was
   scored further. [None]: the topmost flap under the table point [o]. *)
let anchor_faces (g : Fold_state.t) (o : Geom.point)
    (anchor : Geom.point array list option) : bool array =
  let faces = Fold_state.faces g in
  let nf = Array.length faces in
  match anchor with
  | Some polys ->
      Array.map
        (fun (f : Geom.point array) ->
          let m = Num.of_int (Array.length f) in
          let sum get =
            Array.fold_left (fun acc p -> Num.add acc (get p)) Num.zero f
          in
          let c =
            { Geom.x = Num.div (sum (fun p -> p.Geom.x)) m;
              y = Num.div (sum (fun p -> p.Geom.y)) m }
          in
          List.exists (fun poly -> Geom.in_convex_polygon poly c) polys)
        faces
  | None ->
      let rank = Fold_state.rank g in
      let top = ref (-1) in
      for i = 0 to nf - 1 do
        if
          Geom.in_convex_polygon (Fold_state.table_polygon_ccw g i) o
          && (!top < 0 || rank.(i) > rank.(!top))
        then top := i
      done;
      let cl = Fold_state.coplanar_clusters g in
      Array.init nf (fun i -> !top >= 0 && cl.(i) = cl.(!top))

(* Whether the anchor flap surrounds the vertex on the paper: its paper point
   under [o] lies inside the sheet and on no folded hinge. Only there do the
   rays close a loop on the paper around one point, and Kawasaki's and
   Maekawa's conditions at [o] apply; elsewhere [Fold_state.make] checks
   that the paper paths close (ADR 0044). *)
let surrounded (g : Fold_state.t) (o : Geom.point) (anchor : bool array) :
    bool =
  let nf = Array.length anchor in
  let under = ref (-1) in
  for i = 0 to nf - 1 do
    if
      !under < 0 && anchor.(i)
      && Geom.in_convex_polygon (Fold_state.table_polygon_ccw g i) o
    then under := i
  done;
  if !under < 0 then true
  else
    let p =
      Isometry.apply_point
        (Isometry.inverse (Fold_state.face_iso2 g !under))
        o
    in
    (not (Fold_state.on_raw_edge g p))
    && not
         (List.exists
            (fun k ->
              let h = (Fold_state.hinges g).(k) in
              Num.sign h.Fold_state.angle <> 0
              && Geom.on_segment (Fold_state.hinge_segment g k) p)
            (List.init (Array.length (Fold_state.hinges g)) Fun.id))

(* The rays of the fan, one per direction from [o] in CCW order, each with
   the first element pointing that way. Elements of different creases that
   point the same way are one ray, their hinges lying in different layers
   (ADR 0044); the same crease twice in one direction is a duplicate ray. *)
let rays_of (o : Geom.point) (es : elem list) :
    ((Geom.point * elem) array, string) result =
  let sorted = sort_ccw o es in
  let rec dedup acc = function
    | [] -> Ok (Array.of_list (List.rev acc))
    | ((far, e) as r) :: rest -> (
        match acc with
        | (far', e') :: _ when Geom.ccw_compare ~center:o far' far = 0 ->
            if e'.cid = e.cid then Error e_dup_ray else dedup acc rest
        | _ -> dedup (r :: acc) rest)
  in
  dedup [] sorted

(* Checks common to every stayer run: vertex, count, boundary, duplicate
   ray, and Kawasaki's condition where the anchor surrounds the vertex. All
   are rotation- and valley-invariant, so they run once, before the
   admissible-sector fan-out. Returns the vertex O, the CCW-sorted rays and
   whether the anchor surrounds O. Maekawa's parity is the one per-pattern
   check, split into [maekawa_ok]. *)
let prepipeline_geom ?anchor (g : Fold_state.t) (es : elem list) :
    (Geom.point * (Geom.point * elem) array * bool, string) result =
  let n = List.length es in
  match common_vertex es with
  | None -> Error e_no_vertex
  | Some o when not (interior_vertex g (List.map (fun e -> e.cid) es) o) ->
      Error e_no_vertex
  | Some o -> (
      if n < 4 || n mod 2 = 1 then Error e_count
      else if List.exists (fun e -> not (far_on_flap_boundary g o e)) es then
        Error e_midpaper
      else
        match rays_of o es with
        | Error e -> Error e
        | Ok rays ->
            let sur = surrounded g o (anchor_faces g o anchor) in
            if sur && not (closure_ok o rays) then Error e_kawasaki
            else Ok (o, rays, sur))

let maekawa_ok (valley : bool list) : bool =
  let n = List.length valley in
  let nm = List.length (List.filter (fun v -> not v) valley) in
  abs ((n - nm) - nm) = 2

(* --- shared enumeration body: every check and enumeration step common to
   [collapse] and [collapse_all], run on a [rays] array ALREADY ROTATED so the
   stayer sector is sector 0. In that frame [tsec.(0) = identity] sits on the
   stayer BY CONSTRUCTION, so [effective_valley] / [intra] / [ray_assign] /
   [over] all read a labeling anchored on the material that does not move; the
   root for anchoring is a face in sector 0, orientation-preserving by that
   same construction. Returns, per distinct overlap signature, the face rank
   anchoring needs. *)
type pipeline = {
  root : int;  (* first face in the (rotated) stayer sector 0 *)
  candidate_at :
    root:int ->
    base:Isometry3.t ->
    int array ->
    (Fold_state.t, Fold_state.violation) result;
  distinct : int array list;  (* face rank per distinct overlap signature *)
}

(* The valley-independent geometry of one way the fan folds with one stayer
   sector: per face its wedge and its motion, the tip, the stacking units,
   the hinge angles after the fold, and the hinges that carry the letters of
   the elements. A mountain and a valley half-turn land every face in the
   same place, and the layering-validity check reads only angles and rank,
   so none of this depends on the letters. [collapse_all_patterns] builds it
   once per vertex, sector and hinge choice and reuses it across every
   pattern; [overlaps], placement-derived as well, is memoized the first time
   a pattern needs it. *)
type sector_geom = {
  sg_g : Fold_state.t;
  sg_faces : Geom.point array array;
  sg_nf : int;
  sg_nt : int;  (* the units of the tip and its base lie below [sg_nt] *)
  sg_motion : Isometry.t array;  (* per face, how the fan moves it *)
  sg_unit : int array;  (* per face, the unit of the stacking it is ranked in *)
  sg_nu : int;  (* units: the tip and its base, then the stationary blocks *)
  sg_stat_cons : (int * int) list;  (* (upper, lower), stationary units *)
  sg_letters : (int * int * int * bool) list;
      (* per element with a hinge at the tip: the element, the unit on the
         clockwise side of its ray, the unit across, and whether the face on
         the clockwise side ends face down *)
  sg_g_rank : int array;
  sg_root : int;
  sg_marks : Fold_state.mark array;
  sg_new_hinges : Fold_state.hinge array;
  mutable sg_overlaps : (int * int) list option;
}

(* The tip of the fan (ADR 0037) on rays rotated so that sector 0 is the
   stayer: the candidates are the faces outside the stayer's wedge, and the
   tip is the least set of candidates that holds the anchor's candidates and
   is closed under hinges of any angle between candidates. *)
let tip_of (g : Fold_state.t) ~(sec : int array) ~(anchor : bool array) :
    bool array =
  let nf = Array.length sec in
  let candidate i = sec.(i) <> 0 in
  let tip = Array.init nf (fun i -> anchor.(i) && candidate i) in
  let hinges = Fold_state.hinges g in
  let grown = ref true in
  while !grown do
    grown := false;
    Array.iter
      (fun (h : Fold_state.hinge) ->
        let a = h.Fold_state.fa and b = h.Fold_state.fb in
        let join x y =
          if tip.(x) && (not tip.(y)) && candidate y then begin
            tip.(y) <- true;
            grown := true
          end
        in
        join a b;
        join b a)
      hinges
  done;
  tip

(* The faces of the stayer's wedge that the tip hangs from: every piece of
   the wedge, joined by flat hinges inside it, that holds a face hinged to a
   face of the tip. When no face of the wedge is hinged to the tip, the whole
   wedge. *)
let tip_base (g : Fold_state.t) ~(sec : int array) ~(tip : bool array) :
    bool array =
  let nf = Array.length sec in
  let hinges = Fold_state.hinges g in
  let base = Array.make nf false in
  Array.iter
    (fun (h : Fold_state.hinge) ->
      let a = h.Fold_state.fa and b = h.Fold_state.fb in
      if tip.(a) && sec.(b) = 0 then base.(b) <- true;
      if tip.(b) && sec.(a) = 0 then base.(a) <- true)
    hinges;
  if not (Array.exists Fun.id base) then Array.map (fun s -> s = 0) sec
  else begin
    let grown = ref true in
    while !grown do
      grown := false;
      Array.iter
        (fun (h : Fold_state.hinge) ->
          let a = h.Fold_state.fa and b = h.Fold_state.fb in
          if Num.sign h.Fold_state.angle = 0 && sec.(a) = 0 && sec.(b) = 0
             && base.(a) <> base.(b)
          then begin
            base.(a) <- true;
            base.(b) <- true;
            grown := true
          end)
        hinges
    done;
    base
  end

(* The units the stacking ranks. Unit [tip_unit.(i)] < n holds the tip face
   [i] with the faces of the tip that share its wedge and its motion
   (ADR 0044), and unit 0 the faces of the stayer's wedge the tip hangs from
   ([tip_base]). Every other face is a layer the fan leaves where it lies,
   inside the stayer's wedge or outside it; those faces form one more unit
   per piece joined by flat hinges, since a moving sector cannot pass between
   two faces of one flat piece, and the tip can land between them and sector
   0. Between the stationary units, the order of overlapping faces is kept;
   units that overlap both ways are merged, into sector 0 when it takes
   part. Returns the unit of each face, the unit count and the (upper, lower)
   order between stationary units. *)
let stacking_units (g : Fold_state.t) ~(n : int) ~(sec : int array)
    ~(tip : bool array) ~(tip_unit : int array) :
    int array * int * (int * int) list =
  let nf = Array.length sec in
  let base = tip_base g ~sec ~tip in
  let unit =
    Array.init nf (fun i ->
        if tip.(i) then tip_unit.(i) else if base.(i) then sec.(i) else -1)
  in
  if Array.for_all (fun u -> u >= 0) unit then (unit, n, [])
  else begin
    (* flat pieces of the stationary faces outside sector 0 *)
    let parent = Array.init nf Fun.id in
    let rec find i = if parent.(i) = i then i else find parent.(i) in
    Array.iter
      (fun (h : Fold_state.hinge) ->
        let a = h.Fold_state.fa and b = h.Fold_state.fb in
        if Num.sign h.Fold_state.angle = 0 && unit.(a) < 0 && unit.(b) < 0
        then
          let ra = find a and rb = find b in
          if ra <> rb then parent.(ra) <- rb)
      (Fold_state.hinges g);
    let next = ref n in
    let id_of_root = Hashtbl.create 8 in
    Array.iteri
      (fun i u ->
        if u < 0 then begin
          let r = find i in
          match Hashtbl.find_opt id_of_root r with
          | Some k -> unit.(i) <- k
          | None ->
              Hashtbl.add id_of_root r !next;
              unit.(i) <- !next;
              incr next
        end)
      unit;
    let nu = !next in
    (* order between stationary units, from the faces that overlap *)
    let g_rank = Fold_state.rank g in
    let stationary i = not tip.(i) in
    let tps = Array.init nf (Fold_state.table_polygon_ccw g) in
    let above = Array.make_matrix nu nu false in
    for i = 0 to nf - 1 do
      for j = 0 to nf - 1 do
        let ui = unit.(i) and uj = unit.(j) in
        if
          stationary i && stationary j && ui <> uj && (ui >= n || uj >= n)
          && g_rank.(i) > g_rank.(j)
          && Geom.convex_overlap tps.(i) tps.(j)
        then above.(ui).(uj) <- true
      done
    done;
    (* merge the units that lie both above and below one another *)
    let reach = Array.map Array.copy above in
    for k = 0 to nu - 1 do
      for a = 0 to nu - 1 do
        if reach.(a).(k) then
          for b = 0 to nu - 1 do
            if reach.(k).(b) then reach.(a).(b) <- true
          done
      done
    done;
    let rep =
      Array.init nu (fun a ->
          let r = ref a in
          for b = a - 1 downto 0 do
            if reach.(a).(b) && reach.(b).(a) then r := b
          done;
          !r)
    in
    (* renumber so the units stay 0 .. nu' - 1 *)
    let fresh = Array.make nu (-1) in
    let nu' = ref n in
    for u = 0 to nu - 1 do
      if u < n then fresh.(u) <- u
      else if rep.(u) = u then begin
        fresh.(u) <- !nu';
        incr nu'
      end
    done;
    let final u = fresh.(rep.(u)) in
    let unit = Array.map final unit in
    let cons = ref [] in
    for a = 0 to nu - 1 do
      for b = 0 to nu - 1 do
        let fa = final a and fb = final b in
        if above.(a).(b) && fa <> fb && not (List.mem (fa, fb) !cons) then
          cons := (fa, fb) :: !cons
      done
    done;
    (unit, !nu', List.rev !cons)
  end

(* How a hinge takes part in the fan (ADR 0044). [Keep]: off the fan's rays
   or away from the tip, it keeps its angle. [Fold]: a flat hinge an element
   names folds. [Try]: a folded hinge an element names keeps or opens, and a
   hinge on a ray that no element names keeps or changes; the write tries
   both. *)
type role = Keep | Fold | Try

(* The ways the fan folds on rays rotated so that sector 0 is the stayer,
   one per choice for the [Try] hinges whose motions close. The motion of a
   face is the product of the reflections across the changing hinges on a
   path to it from a face that stays [hull2020, Def. 6.5]; a choice whose
   paths disagree does not close [hull2020, Thm. 6.6]. An element names
   every hinge of its crease on its ray, in every layer. The choices are
   enumerated whole, so the work doubles with every [Try] hinge; a fan in
   the corpus has a handful at most. A search that propagates each choice
   along the paths would prune the rest. *)
let mk_sector_geoms (g : Fold_state.t) ~(o : Geom.point)
    ~(rays : (Geom.point * elem) array) ~(es : elem array)
    ~(faces : Geom.point array array) ~(nf : int) ~(anchor : bool array) :
    (sector_geom list, string) result =
  let n = Array.length rays in
  let sec =
    Array.init nf (fun i ->
        sector_of_poly_opt o rays (faces.(i), Fold_state.face_iso2 g i))
  in
  let tip = tip_of g ~sec ~anchor in
  if not (Array.exists Fun.id tip) then Error e_anchor_stays
  else if Array.exists2 (fun t s -> t && s < 0) tip sec then Error e_unaligned
  else
  let g_rank = Fold_state.rank g in
  let old_hinges = Fold_state.hinges g in
  let nh = Array.length old_hinges in
  let touches_tip (h : Fold_state.hinge) =
    tip.(h.Fold_state.fa) || tip.(h.Fold_state.fb)
  in
  (* the ray each hinge lies on, whichever crease it belongs to *)
  let on_ray =
    Array.init nh (fun i ->
        let ta, tb = Fold_state.hinge_table_segment g i in
        let hit = ref None in
        Array.iteri
          (fun j (far, _) ->
            if
              !hit = None
              && Geom.on_segment (o, far) ta
              && Geom.on_segment (o, far) tb
            then hit := Some j)
          rays;
        !hit)
  in
  let elem_ray =
    Array.map
      (fun e ->
        let far = far_of o e in
        let r = ref (-1) in
        Array.iteri
          (fun j (f, _) ->
            if !r < 0 && Geom.ccw_compare ~center:o f far = 0 then r := j)
          rays;
        !r)
      es
  in
  (* per hinge, the element that names it *)
  let names =
    Array.init nh (fun i ->
        let h = old_hinges.(i) in
        match on_ray.(i) with
        | None -> None
        | Some j ->
            let found = ref None in
            Array.iteri
              (fun k (e : elem) ->
                if
                  !found = None && elem_ray.(k) = j
                  && e.cid = h.Fold_state.crease_id
                then found := Some k)
              es;
            !found)
  in
  let role =
    Array.init nh (fun i ->
        let h = old_hinges.(i) in
        if on_ray.(i) = None || not (touches_tip h) then Keep
        else
          match names.(i) with
          | Some _ when Num.sign h.Fold_state.angle = 0 -> Fold
          | _ -> Try)
  in
  let tries = List.filter (fun i -> role.(i) = Try) (List.init nh Fun.id) in
  let hinge_line i =
    let ta, tb = Fold_state.hinge_table_segment g i in
    Geom.line_through ta tb
  in
  let adj = Array.make nf [] in
  Array.iteri
    (fun i (h : Fold_state.hinge) ->
      adj.(h.Fold_state.fa) <- i :: adj.(h.Fold_state.fa);
      adj.(h.Fold_state.fb) <- i :: adj.(h.Fold_state.fb))
    old_hinges;
  let same_iso a b = is_identity (Isometry.compose (Isometry.inverse a) b) in
  (* the motion of every face under one choice, or None when two paths to a
     face disagree; the faces outside the tip stay *)
  let motions_of (change : bool array) : Isometry.t array option =
    let m = Array.make nf None in
    let queue = Queue.create () in
    Array.iteri
      (fun i t ->
        if not t then begin
          m.(i) <- Some Isometry.identity;
          Queue.add i queue
        end)
      tip;
    let ok = ref true in
    while !ok && not (Queue.is_empty queue) do
      let a = Queue.pop queue in
      let ma = Option.get m.(a) in
      List.iter
        (fun hi ->
          if !ok then begin
            let h = old_hinges.(hi) in
            let b = if h.Fold_state.fa = a then h.Fold_state.fb else h.Fold_state.fa in
            let mb =
              if change.(hi) then
                Isometry.compose ma (Isometry.reflect_across_line (hinge_line hi))
              else ma
            in
            match m.(b) with
            | None ->
                m.(b) <- Some mb;
                Queue.add b queue
            | Some x -> if not (same_iso x mb) then ok := false
          end)
        adj.(a)
    done;
    if !ok && Array.for_all Option.is_some m then Some (Array.map Option.get m)
    else None
  in
  let build (change : bool array) (motion : Isometry.t array) :
      sector_geom =
    (* A wedge's first motion keeps the wedge's number, so a fan on one sheet
       ranks the units it ranked with one motion per wedge; a further motion
       in a wedge takes a number past the wedges. *)
    let first = Array.make n None in
    let extra = ref [] and next = ref n in
    let tip_unit =
      Array.init nf (fun i ->
          if not tip.(i) then -1
          else
            let s = sec.(i) in
            match first.(s) with
            | None ->
                first.(s) <- Some motion.(i);
                s
            | Some m0 when same_iso m0 motion.(i) -> s
            | Some _ -> (
                match
                  List.find_opt
                    (fun (s', m', _) -> s' = s && same_iso m' motion.(i))
                    !extra
                with
                | Some (_, _, id) -> id
                | None ->
                    let id = !next in
                    incr next;
                    extra := (s, motion.(i), id) :: !extra;
                    id))
    in
    let nt = !next in
    let unit, nu, stat_cons = stacking_units g ~n:nt ~sec ~tip ~tip_unit in
    let opened i =
      change.(i) && Num.sign old_hinges.(i).Fold_state.angle <> 0
    in
    (* The letter of an element holds at its hinge whose face on the
       clockwise side of the ray lies lowest; the other hinges it names take
       whatever letter the stacking gives them. A hinge that opens has no
       letter. *)
    let letters =
      List.filter_map
        (fun k ->
          let l = (elem_ray.(k) - 1 + n) mod n in
          let best = ref None in
          Array.iteri
            (fun i (h : Fold_state.hinge) ->
              if names.(i) = Some k && touches_tip h && not (opened i) then begin
                let a = h.Fold_state.fa and b = h.Fold_state.fb in
                let side =
                  if sec.(a) = l then Some (a, b)
                  else if sec.(b) = l then Some (b, a)
                  else None
                in
                match (side, !best) with
                | Some (fl, _), Some (bl, _) when g_rank.(fl) >= g_rank.(bl) -> ()
                | Some s, _ -> best := Some s
                | None, _ -> ()
              end)
            old_hinges;
          match !best with
          | Some (fl, fo) when unit.(fl) <> unit.(fo) ->
              let down =
                Isometry.det_sign
                  (Isometry.compose motion.(fl) (Fold_state.face_iso2 g fl))
                < 0
              in
              Some (k, unit.(fl), unit.(fo), down)
          | _ -> None)
        (List.init (Array.length es) Fun.id)
    in
    let root =
      let found = ref (-1) in
      for i = 0 to nf - 1 do
        if !found < 0 && unit.(i) = 0 then found := i
      done;
      if !found < 0 then
        invalid_arg
          "Collapse.mk_sector_geoms: stayer sector 0 holds no face \
           (unreachable, every sector holds a face)";
      !found
    in
    let new_hinges =
      Array.mapi
        (fun i (h : Fold_state.hinge) ->
          if change.(i) then
            { h with
              Fold_state.angle =
                (if Num.sign h.Fold_state.angle = 0 then Num.one else Num.zero)
            }
          else h)
        old_hinges
    in
    { sg_g = g; sg_faces = faces; sg_nf = nf; sg_nt = nt; sg_motion = motion;
      sg_unit = unit; sg_nu = nu; sg_stat_cons = stat_cons;
      sg_letters = letters; sg_g_rank = g_rank; sg_root = root;
      sg_marks = Fold_state.marks g; sg_new_hinges = new_hinges;
      sg_overlaps = None }
  in
  let geoms =
    List.filter_map
      (fun mask ->
        let change = Array.map (fun r -> r = Fold) role in
        List.iteri
          (fun bit i -> if mask land (1 lsl bit) <> 0 then change.(i) <- true)
          tries;
        match motions_of change with
        | Some motion
          when Array.exists2
                 (fun t m -> t && not (is_identity m))
                 tip motion ->
            Some (build change motion)
        | _ -> None)
      (List.init (1 lsl List.length tries) Fun.id)
  in
  if geoms = [] then Error e_kawasaki else Ok geoms

(* The valley-dependent half: given one [sector_geom] and the letter of each
   element, enumerate the layer stackings and dedup them by overlap
   signature. *)
let pipeline_solve (sg : sector_geom) ~(valley : bool array)
    ~(over : (int * int) list) : (pipeline, string) result =
  let nf = sg.sg_nf in
  let sec = sg.sg_unit in
  let g_rank = sg.sg_g_rank and root = sg.sg_root in
  (* hinge constraints: a valley puts the unit across the ray above the unit
     on its clockwise side, as seen from that side's final face *)
  let constraints =
    List.map
      (fun (k, ul, uo, down) ->
        if valley.(k) <> down then (uo, ul) else (ul, uo))
      sg.sg_letters
  in
  let stackings =
    linear_extensions sg.sg_nu (constraints @ sg.sg_stat_cons)
  in
  (* total face rank from a sector stacking: sort by (srank.(sector),
     intra-sector order), tiebreak by index (never fires). *)
  let intra i =
    if sec.(i) >= sg.sg_nt || Isometry.det_sign sg.sg_motion.(i) > 0 then
      g_rank.(i)
    else -g_rank.(i)
  in
  let build_face_rank (srank : int array) : int array =
    let idx = Array.init nf Fun.id in
    Array.sort
      (fun i j ->
        compare (srank.(sec.(i)), intra i, i) (srank.(sec.(j)), intra j, j))
      idx;
    let rank = Array.make nf 0 in
    Array.iteri (fun h i -> rank.(i) <- h) idx;
    rank
  in
  let candidate_at ~root ~base rank =
    Fold_state.make ~base ~marks:sg.sg_marks ~faces:sg.sg_faces
      ~hinges:sg.sg_new_hinges ~root ~rank ()
  in
  let anchor_base = Fold_state.face_iso sg.sg_g root in
  let valid_srank =
    List.filter
      (fun srank ->
        match candidate_at ~root ~base:anchor_base (build_face_rank srank) with
        | Ok _ -> true
        | Error _ -> false)
      stackings
  in
  if valid_srank = [] then Error e_selfint
  else begin
    (* over filter at the sector level, BEFORE face-rank expansion
       (valid -> over -> dedup) *)
    let over_ok srank =
      List.for_all
        (fun (up, lo) ->
          let su = sec.(up) and sl = sec.(lo) in
          su = sl || srank.(su) > srank.(sl))
        over
    in
    let filtered = List.filter over_ok valid_srank in
    if filtered = [] then Error e_contra
    else begin
      (* placements depend on neither rank nor the M/V letters, so the overlap
         set is computed once per sector geometry and shared across every
         pattern (any surviving candidate's flat projections give it). *)
      let overlaps =
        match sg.sg_overlaps with
        | Some ov -> ov
        | None ->
            let sample =
              match
                candidate_at ~root ~base:anchor_base
                  (build_face_rank (List.hd filtered))
              with
              | Ok c -> c
              | Error _ -> assert false
            in
            let ov =
              let acc = ref [] in
              for i = 0 to nf - 1 do
                for j = i + 1 to nf - 1 do
                  if
                    Geom.convex_overlap
                      (Fold_state.table_polygon sample i)
                      (Fold_state.table_polygon sample j)
                  then acc := (i, j) :: !acc
                done
              done;
              List.rev !acc
            in
            sg.sg_overlaps <- Some ov;
            ov
      in
      let signature fr =
        List.map (fun (i, j) -> (i, j, fr.(i) > fr.(j))) overlaps
      in
      let distinct =
        List.fold_left
          (fun acc srank ->
            let fr = build_face_rank srank in
            let s = signature fr in
            if List.exists (fun (s', _) -> s' = s) acc then acc
            else (s, fr) :: acc)
          [] filtered
      in
      Ok { root; candidate_at; distinct = List.map snd distinct }
    end
  end

(* The convex hull of every table polygon of [g]: the outline a collapse of
   [g] keeps its realizations within (ADR 0046). The last hull is kept,
   since every realization of one collapse is tested against the same [g]. *)
let hull_cache : (Fold_state.t * Geom.point array) option ref = ref None

let table_hull (g : Fold_state.t) : Geom.point array =
  match !hull_cache with
  | Some (g', h) when g' == g -> h
  | _ ->
      let pts =
        List.concat
          (List.init (Array.length (Fold_state.faces g)) (fun i ->
               Array.to_list (Fold_state.table_polygon g i)))
      in
      let h = Geom.convex_hull pts in
      hull_cache := Some (g, h);
      h

let in_bounds (hull : Geom.point array) (gg : Fold_state.t) : bool =
  let nfg = Array.length (Fold_state.faces gg) in
  let ok = ref true in
  for i = 0 to nfg - 1 do
    if not (Array.for_all (Geom.in_convex_polygon hull) (Fold_state.table_polygon gg i))
    then ok := false
  done;
  !ok

(* anchor one realization on the stayer sector's root face. The improper-anchor
   reversed-rank fallback (1a4f6d9) is gone: the stayer sector is placed by the
   identity by construction, so there is exactly one seat. Failing [in_bounds]
   is an honest [e_out_of_paper] for that realization, not a fallback trigger. *)
let anchor_realization (g : Fold_state.t) ~(root : int)
    ~(candidate_at :
       root:int ->
       base:Isometry3.t ->
       int array ->
       (Fold_state.t, Fold_state.violation) result) (fr : int array) :
    (Fold_state.t, string) result =
  match candidate_at ~root ~base:(Fold_state.face_iso g root) fr with
  | Ok gg when in_bounds (table_hull g) gg -> Ok gg
  | Ok _ -> Error e_out_of_paper
  | Error _ -> Error e_out_of_paper

(* pool the per-sector runs: any in-bounds realization wins ([Ok] pool); an empty
   pool surfaces [e_contra] > [e_out_of_paper] > [e_stayer_dead]. Shared by the
   single-valley [collapse_runs] and the pattern-sharing path. *)
let pool_of_runs
    (results :
      [ `Err of string | `Run of (Fold_state.t, string) result list ] list) :
    (Fold_state.t list, string) result =
  let pool =
    List.concat_map
      (function
        | `Run rs ->
            List.filter_map (function Ok gg -> Some gg | Error _ -> None) rs
        | `Err _ -> [])
      results
  in
  match pool with
  | _ :: _ -> Ok pool
  | [] ->
      let errs =
        List.concat_map
          (function
            | `Err e -> [ e ]
            | `Run rs ->
                List.filter_map (function Error e -> Some e | Ok _ -> None) rs)
          results
      in
      if List.mem e_contra errs then Error e_contra
      else if List.mem e_out_of_paper errs then Error e_out_of_paper
      else if List.mem e_unaligned errs then Error e_unaligned
      else if List.mem e_anchor_stays errs then Error e_anchor_stays
      else Error e_stayer_dead

(* The admissible stayer sectors of the fan on [g], after the checks at the
   vertex, with everything a run on one of them reads. *)
let fan_setup ?anchor (g : Fold_state.t) (es : elem list) ~(stayer : stayer) =
  match prepipeline_geom ?anchor g es with
  | Error e -> Error e
  | Ok (o, rays, sur) -> (
      let faces = Fold_state.faces g in
      let nf = Array.length faces in
      let sec_orig =
        Array.init nf (fun i ->
            sector_of_poly_opt o rays (faces.(i), Fold_state.face_iso2 g i))
      in
      let anchor = anchor_faces g o anchor in
      match stayer_sectors ~stayer ~anchor o rays sec_orig nf with
      | Error e -> Error e
      | Ok sectors -> Ok (o, rays, sur, faces, nf, anchor, sectors))

(* One realization per distinct stacking of every way the fan folds with
   stayer sector [s0], for the letters [valley]. *)
let runs_of_sector (g : Fold_state.t) sgs ~(valley : bool array)
    ~(over : (int * int) list) =
  match sgs with
  | Error e -> [ `Err e ]
  | Ok sgs ->
      List.map
        (fun sg ->
          match pipeline_solve sg ~valley ~over with
          | Error e -> `Err e
          | Ok { root; candidate_at; distinct } ->
              `Run
                (List.map
                   (fun fr -> anchor_realization g ~root ~candidate_at fr)
                   distinct))
        sgs

(* run the pipeline once per admissible stayer sector (rotating that sector to
   0) and each way the fan folds there, pooling every in-bounds anchored
   realization. Runs are not deduplicated against each other, since two
   admissible sectors are two different stayers and so two physically
   different folds; each run deduplicates its stackings by signature. *)
let collapse_runs ?anchor (g : Fold_state.t) (es : elem list)
    ~(over : (int * int) list) ~(stayer : stayer) :
    (Fold_state.t list, string) result =
  match fan_setup ?anchor g es ~stayer with
  | Error e -> Error e
  | Ok (o, rays, sur, faces, nf, anchor, sectors) ->
      if sur && not (maekawa_ok (List.map (fun e -> e.valley) es)) then
        Error e_maekawa
      else
        let es = Array.of_list es in
        let valley = Array.map (fun e -> e.valley) es in
        pool_of_runs
          (List.concat_map
             (fun s0 ->
               runs_of_sector g ~valley ~over
                 (mk_sector_geoms g ~o ~rays:(rotate_rays rays s0) ~es ~faces
                    ~nf ~anchor))
             sectors)

(* The many-pattern entry: solve a whole batch of patterns over ONE fixed
   vertex geometry, sharing the sector geometry (placements, overlap set)
   across every pattern instead of rebuilding it per pattern. [es] carries
   the geometry (its own valley is ignored); [patterns.(p)] is the letter of
   each element, in [es] order. Returns one result per pattern,
   parallel to [patterns]. Maekawa's parity applies where the anchor
   surrounds the vertex. *)
let collapse_all_patterns ?anchor ?sectors:only (g : Fold_state.t)
    (es : elem list) ~(over : (int * int) list) ~(stayer : stayer)
    ~(patterns : bool list list) : (Fold_state.t list, string) result list =
  match fan_setup ?anchor g es ~stayer with
  | Error e -> List.map (fun _ -> Error e) patterns
  | Ok (o, rays, sur, faces, nf, anchor, sectors) ->
      let sectors =
        match only with
        | None -> sectors
        | Some l -> List.filter (fun s -> List.mem s l) sectors
      in
      let es = Array.of_list es in
      (* per-sector geometry, built ONCE and reused across all patterns *)
      let sgs =
        List.map
          (fun s0 ->
            mk_sector_geoms g ~o ~rays:(rotate_rays rays s0) ~es ~faces ~nf
              ~anchor)
          sectors
      in
      List.map
        (fun pat ->
          if sur && not (maekawa_ok pat) then Error e_maekawa
          else
            let valley = Array.of_list pat in
            pool_of_runs
              (List.concat_map (runs_of_sector g ~valley ~over) sgs))
        patterns

(* The tip of the fan on [g] for each admissible stayer sector (ADR 0037):
   the sector, as [collapse_all_patterns ~sectors] takes it, and per face of
   [g] whether the tip holds it. Empty when the fan fails before its tip is
   defined; solving it then reports that failure. *)
let tips ?anchor (g : Fold_state.t) (es : elem list) ~(stayer : stayer) :
    (int * bool array) list =
  match fan_setup ?anchor g es ~stayer with
  | Error _ -> []
  | Ok (o, rays, _, faces, nf, anchor, sectors) ->
      let sec_on rays =
        Array.init nf (fun i ->
            sector_of_poly_opt o rays (faces.(i), Fold_state.face_iso2 g i))
      in
      List.map
        (fun s0 -> (s0, tip_of g ~sec:(sec_on (rotate_rays rays s0)) ~anchor))
        sectors

let collapse ?anchor (g : Fold_state.t) (es : elem list)
    ~(over : (int * int) list) ~(stayer : stayer) :
    (Fold_state.t, string) result =
  match collapse_runs ?anchor g es ~over ~stayer with
  | Error e -> Error e
  | Ok [ one ] -> Ok one
  | Ok [] -> Error e_stayer_dead (* unreachable: an empty pool errors above *)
  | Ok many -> Error (e_ambig (List.length many))

let collapse_all ?anchor (g : Fold_state.t) (es : elem list)
    ~(over : (int * int) list) ~(stayer : stayer) :
    (Fold_state.t list, string) result =
  collapse_runs ?anchor g es ~over ~stayer
