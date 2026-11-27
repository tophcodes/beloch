(** Single-vertex collapse: fold along n >= 4 material crease segments sharing
    one interior endpoint O: the flat end state of a multi-crease move
    (rabbit ear [hull2020, Thm 8.5]). Skips the 3D intermediate entirely:
    checks the end state exists (Kawasaki and Maekawa where the anchor
    surrounds O, the closure of the paper paths everywhere), moves each face
    by the creases on its paper path (spec multifold,
    "A fan moves each piece by the changing hinges on its paper path"),
    enumerates valid layer orders. *)

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
let e_stayer_collinear = "collinear leading creases don't pick a stayer"
let e_stayer_dead = "no realization keeps the staying flap still"
let e_unaligned = "collapse through unaligned layers"
let e_anchor_stays =
  "the anchor flap has no material outside the staying sector"
let e_staying_none = "no sector of the fan holds every staying point"
let e_staying_several = "the staying points lie in more than one sector"
let e_staying_off_anchor = "the staying sector holds no material of the anchor"

(* A flatten names the part that stays (spec multifold,
   "A flatten names the part that stays"). A default stayer, the part that
   holds the lowest face under the vertex and among those the largest, could
   be added later; the design of the change drop-outline-ranking under
   openspec/changes/ weighs it. *)
let e_staying_missing verb = verb ^ " needs (staying .p)"
let hint_staying_missing = "name a point in the part that stays"

(* The end of the error of a fan whose moving part holds a layer under the
   vertex that no hinge of the fan folds (spec multifold,
   "A fan moves every part the stayer does not hold"); the message names the
   layer before it. *)
let e_unfolded_layer = "no ray of the fan folds it"

let is_layer_error (m : string) : bool =
  let n = String.length e_unfolded_layer and l = String.length m in
  l >= n && String.sub m (l - n) n = e_unfolded_layer

(* the hint that goes with an error string above, where it has one
   (spec diagnostics,
   "A rejected program is reported as a span, a message and an optional hint") *)
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
   the table images of the points of `staying` (spec multifold,
   "staying names the part that holds every point"): the stayer is the one
   sector whose closed wedge holds all of them. *)
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
  Isometry.is_identity prod

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

(* --- the kernel: single-vertex collapse on the hinge-graph core (issue #48).
   Hinge angles and the sides of overlapping faces are set directly;
   placements (and hence overlaps) are DERIVED by [Fold_state.geometry], not
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
   one half-plane (spec multifold, "The closure condition at the vertex
   applies inside the sheet"), holds it iff no vertex lies strictly inside the
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
   (spec multifold, "staying names the part that holds every point") *)
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

(* The faces of the anchor flap (spec multifold, "A reverse or squash fan
   sits at a point of the projective table"). [Some polys]: the faces lying in
   those paper polygons, the faces of the flap `on` names before the state was
   scored further. [None]: the flap of a face under the table point [o] that
   no other face under [o] lies above. *)
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
      let top = ref (-1) in
      for i = 0 to nf - 1 do
        if
          Geom.in_convex_polygon (Fold_state.table_polygon_ccw g i) o
          && (!top < 0 || Fold_state.above g i !top)
        then top := i
      done;
      let cl = Fold_state.coplanar_clusters g in
      Array.init nf (fun i -> !top >= 0 && cl.(i) = cl.(!top))

(* Whether the anchor flap surrounds the vertex on the paper: its paper point
   under [o] lies inside the sheet and on no folded hinge. Only there do the
   rays close a loop on the paper around one point, and Kawasaki's and
   Maekawa's conditions at [o] apply; elsewhere [Fold_state.make] checks
   that the paper paths close (spec multifold,
   "The closure condition at the vertex applies inside the sheet"). *)
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
   (spec multifold, "The fan tries each hinge no item fixes both ways"); the
   same crease twice in one direction is a duplicate ray. *)
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

(* The tip of the fan (spec multifold,
   "A fan with an anchor moves the tip of its anchor") on rays rotated so that
   sector 0 is the stayer: the candidates are the faces outside the stayer's
   wedge, and the tip is the least set of candidates that holds the anchor's
   candidates and is closed under hinges of any angle between candidates. *)
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

(* The ways the fan folds on rays rotated so that sector 0 is the stayer
   ([Fan.make]), placed from the first face of the stayer outside the tip.
   An element names every hinge of its crease on its ray, in every layer.
   A hinge off the fan's rays or away from the tip keeps its angle, a flat
   hinge an element names folds, and the fan tries both ways a folded hinge
   an element names, which keeps or opens, and a hinge on a ray that no
   element names, which keeps or changes (spec multifold, "The fan tries
   each hinge no item fixes both ways"). *)
let mk_sector_geoms ?tip_rule (g : Fold_state.t) ~(o : Geom.point)
    ~(rays : (Geom.point * elem) array) ~(es : elem array)
    ~(faces : Geom.point array array) ~(nf : int) ~(anchor : bool array) :
    (Fan.t list, string) result =
  let n = Array.length rays in
  let sec =
    Array.init nf (fun i ->
        sector_of_poly_opt o rays (faces.(i), Fold_state.face_iso2 g i))
  in
  (* [tip_rule] gives the tip, the hinges of the fan, and the hinges that
     pass through the vertex on the paper (spec multifold,
     "A ray folds the pieces of its bundle that pass through the vertex"), or
     the error of a fan it cannot fold; without it the tip is the anchor's
     (spec multifold, "A fan with an anchor moves the tip of its anchor") *)
  match
    match tip_rule with
    | Some f -> f g sec
    | None -> Ok (tip_of g ~sec ~anchor, (fun _ -> true), fun _ -> true)
  with
  | Error e -> Error e
  | Ok (tip, in_bundle, at_vertex) ->
  if not (Array.exists Fun.id tip) then Error e_anchor_stays
  else if Array.exists2 (fun t s -> t && s < 0) tip sec then Error e_unaligned
  else if not (Array.exists2 (fun t s -> (not t) && s = 0) tip sec) then
    Error e_stayer_dead
  else
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
                  && in_bundle i
                then found := Some k)
              es;
            !found)
  in
  let role =
    Array.init nh (fun i ->
        let h = old_hinges.(i) in
        if on_ray.(i) = None || not (touches_tip h) || not (at_vertex i) then
          Fan.Keep
        else
          match names.(i) with
          | Some _ when Num.sign h.Fold_state.angle = 0 -> Fan.Fold
          | _ -> Fan.Try)
  in
  let root =
    let found = ref (-1) in
    for i = 0 to nf - 1 do
      if !found < 0 && sec.(i) = 0 && not tip.(i) then found := i
    done;
    !found
  in
  match
    Fan.make g ~root ~tip ~names ~role ~nelem:(Array.length es)
      ~side:(fun k a b ->
        let l = (elem_ray.(k) - 1 + n) mod n in
        if sec.(a) = l then Some (a, b)
        else if sec.(b) = l then Some (b, a)
        else None)
  with
  | Some fans -> Ok fans
  | None -> Error e_kawasaki

(* The states of one way the fan folds for the letter of each element
   ([Fan.stackings] with [Fan.Letters]) that put the upper face of each pair
   of [over] above its lower face. The two faces must overlap:
   a pair that lies apart holds in no state. Only the named faces are
   compared, so a flap can lie between two layers of one piece (spec
   multifold, "An over item orders the faces of its two points"). *)
let pipeline_solve (fan : Fan.t) ~(valley : bool array)
    ~(over : (int * int) list) : (Fold_state.t list, string) result =
  match Fan.stackings fan (Fan.Letters valley) with
  | Error _ | Ok [] -> Error e_selfint
  | Ok states -> (
      let over_ok st =
        List.for_all
          (fun (up, lo) -> Fold_state.rel st up lo = Fold_state.Above)
          over
      in
      match List.filter over_ok states with
      | [] -> Error e_contra
      | l -> Ok l)

(* pool the per-sector runs: every state of every run ([Ok] pool); an empty
   pool surfaces [e_contra] > [e_unaligned] > [e_anchor_stays] >
   [e_stayer_dead], below the layer error of a [tip_rule].
   Shared by the single-valley [collapse_runs] and the pattern-sharing
   path. *)
let pool_of_runs
    (results : [ `Err of string | `Run of Fold_state.t list ] list) :
    (Fold_state.t list, string) result =
  let pool =
    List.concat_map (function `Run rs -> rs | `Err _ -> []) results
  in
  match pool with
  | _ :: _ -> Ok pool
  | [] ->
      let errs =
        List.filter_map (function `Err e -> Some e | `Run _ -> None) results
      in
      match List.find_opt is_layer_error errs with
      | Some e -> Error e
      | None ->
      if List.mem e_contra errs then Error e_contra
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

(* The states of every way the fan folds with one stayer sector, for the
   letters [valley]. *)
let runs_of_sector sgs ~(valley : bool array) ~(over : (int * int) list) =
  match sgs with
  | Error e -> [ `Err e ]
  | Ok sgs ->
      List.map
        (fun sg ->
          match pipeline_solve sg ~valley ~over with
          | Error e -> `Err e
          | Ok states -> `Run states)
        sgs

(* run the pipeline once per admissible stayer sector (rotating that sector to
   0) and each way the fan folds there, pooling every anchored realization.
   Runs are not deduplicated against each other, since two
   admissible sectors are two different stayers and so two physically
   different folds; the layer orders of one run differ in the side of at
   least one pair. *)
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
               runs_of_sector ~valley ~over
                 (mk_sector_geoms g ~o ~rays:(rotate_rays rays s0) ~es
                    ~faces ~nf ~anchor))
             sectors)

(* The many-pattern entry: solve a whole batch of patterns over ONE fixed
   vertex geometry, sharing the sector geometry (placements, overlap set)
   across every pattern instead of rebuilding it per pattern. [es] carries
   the geometry (its own valley is ignored); [patterns.(p)] is the letter of
   each element, in [es] order. Returns one result per pattern,
   parallel to [patterns], not ranked by the outline: the caller ranks the
   states of all its patterns together. Maekawa's parity applies where the anchor
   surrounds the vertex. *)
let collapse_all_patterns ?anchor ?sectors:only ?tip_rule (g : Fold_state.t)
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
            mk_sector_geoms ?tip_rule g ~o ~rays:(rotate_rays rays s0) ~es
              ~faces ~nf ~anchor)
          sectors
      in
      List.map
        (fun pat ->
          if sur && not (maekawa_ok pat) then Error e_maekawa
          else
            let valley = Array.of_list pat in
            pool_of_runs
              (List.concat_map (runs_of_sector ~valley ~over) sgs))
        patterns

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
