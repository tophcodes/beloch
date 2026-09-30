(** Single-vertex collapse: fold along n >= 4 material crease segments sharing
    one interior endpoint O — the flat end state of a multi-crease move
    (rabbit ear [hull2020, Thm 8.5]). Skips the 3D intermediate entirely:
    checks the end state exists (reflection closure = Kawasaki, Maekawa),
    assigns per-sector isometries, enumerates valid layer orders. *)

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

(* the hint that goes with an error string above, where it has one (ADR 0028) *)
let hint_of (m : string) : string option =
  if m = e_count then Some "use `fold` for n = 2"
  else if m = e_stayer_collinear then Some "add (staying <flap>)"
  else None

(* --- stayer: the material that does not move (design 2026-07-17) -----------
   Anchors the fan labeling geometrically instead of at [sort_ccw]'s arbitrary
   east origin. [Arc (pa, pb)] = the far tips of the two leading elements'
   folded rays; the stayer region is the <π CCW arc between them. [Faces fs] =
   the pre-collapse face indices carrying the stayed material. *)
type stayer = Arc of Geom.point * Geom.point | Faces of int list

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

(* 2. rays: sort elems CCW by the direction (far tip − O), using the exact
   angular comparator in Geom (half classification then cross product). *)
let sort_ccw (o : Geom.point) (es : elem list) : (Geom.point * elem) list =
  es
  |> List.map (fun e -> (far_of o e, e))
  |> List.sort (fun (a, _) (b, _) -> Geom.ccw_compare ~center:o a b)

(* Two elements pointing in the SAME direction from O collapse to a zero-width
   sector: their reflections cancel in the closure product, so Kawasaki,
   Maekawa, and the n-count all pass on a self-contradictory vertex. After
   [sort_ccw] such rays are adjacent, so a consecutive scan (ccw_compare = 0 ⇒
   same half AND collinear ⇒ same direction) catches them. Opposite collinear
   rays — the waterbomb's through-O lines — land in different halves, so
   ccw_compare ≠ 0 and they stay legal. *)
let has_duplicate_ray (o : Geom.point) (rays : (Geom.point * 'a) array) : bool =
  let n = Array.length rays in
  let dup = ref false in
  for k = 0 to n - 2 do
    let a, _ = rays.(k) and b, _ = rays.(k + 1) in
    if Geom.ccw_compare ~center:o a b = 0 then dup := true
  done;
  !dup

(* 3. sector isometries. With rays r0..r_{n-1} CCW and Li = line through O along
   ri, sector k (between rk and r_{k+1}) is placed by
     T_0 = identity,  T_k = T_{k-1} ∘ R(L_k)   (crease r_k separates s_{k-1},s_k)
   so T_k = R(L_1) ∘ … ∘ R(L_k) and det_sign(T_k) = (-1)^k. *)
let sector_isometries (o : Geom.point) (rays : (Geom.point * 'a) array) :
    Isometry.t array =
  let n = Array.length rays in
  let t = Array.make n Isometry.identity in
  for k = 1 to n - 1 do
    let far, _ = rays.(k) in
    let refl = Isometry.reflect_across_line (Geom.line_through o far) in
    t.(k) <- Isometry.compose t.(k - 1) refl
  done;
  t

(* Effective valley of a crease whose LEFT (stayer) sector is placed by
   [sec_transform] over a stayer face already carrying [face_iso]. Mirrors
   [Fold_state.fold]'s CP-frame intent convention: a stored/effective valley is
   the user's valley XORed with the parity of the stayer face's *final*
   orientation — [sec_transform ∘ face_iso]. Folding in [face_iso] (not just
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
   identity — this is exactly Kawasaki at O. Any cyclic rotation of the product
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

let strictly_interior (p : Geom.point) : bool =
  Num.sign p.Geom.x > 0
  && Num.compare p.Geom.x Num.one < 0
  && Num.sign p.Geom.y > 0
  && Num.compare p.Geom.y Num.one < 0

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
   composed by hand, so there is no [folded]/[faces_for_anchor] analogue —
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
   Every sector is narrower than a half-turn, so a sector is convex and holds
   the polygon iff it holds every vertex. *)
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
    if
      !found < 0
      && Array.for_all
           (fun pc ->
             Num.sign (cross oc (rk.Geom.x, rk.Geom.y) pc) >= 0
             && Num.sign (cross oc pc (rk1.Geom.x, rk1.Geom.y)) >= 0)
           pts
    then found := k
  done;
  !found

(* --- shared pipeline: every check and enumeration step common to [collapse]
   and [collapse_all], up to signature dedup. Returns, per distinct-signature
   realization, the (sector-rank, face-rank) pair anchoring needs — anchoring
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

(* rotate the ray labeling so that sector [s0] becomes sector 0 — the stayer
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

(* checks common to every stayer run — vertex, count, boundary, duplicate ray,
   Kawasaki closure, Maekawa. All rotation-invariant, so run once, before the
   admissible-sector fan-out. Returns the vertex O and the CCW-sorted rays. *)
(* geometry-only prechecks: everything rotation- AND valley-invariant. The
   Maekawa parity is the one per-pattern check, split into [maekawa_ok] so
   [collapse_all_patterns] can share this over every M/V pattern. *)
let prepipeline_geom (g : Fold_state.t) (es : elem list) :
    (Geom.point * (Geom.point * elem) array, string) result =
  let n = List.length es in
  match common_vertex es with
  | None -> Error e_no_vertex
  | Some o when not (strictly_interior o) -> Error e_no_vertex
  | Some o ->
      if n < 4 || n mod 2 = 1 then Error e_count
      else if List.exists (fun e -> not (far_on_flap_boundary g o e)) es then
        Error e_midpaper
      else
        let rays = Array.of_list (sort_ccw o es) in
        if has_duplicate_ray o rays then Error e_dup_ray
        else if not (closure_ok o rays) then Error e_kawasaki
        else Ok (o, rays)

let maekawa_ok (valley : bool list) : bool =
  let n = List.length valley in
  let nm = List.length (List.filter (fun v -> not v) valley) in
  abs ((n - nm) - nm) = 2

let prepipeline (g : Fold_state.t) (es : elem list) :
    (Geom.point * (Geom.point * elem) array, string) result =
  match prepipeline_geom g es with
  | Error _ as e -> e
  | Ok (o, rays) ->
      if maekawa_ok (List.map (fun e -> e.valley) es) then Ok (o, rays)
      else Error e_maekawa

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

(* The valley-INDEPENDENT geometry of one (rotated) sector fan: sector
   isometries, per-face sector, per-ray orientation representative, the anchor
   root, and the ray<->hinge matching. A mountain and a valley half-turn land
   every face in the SAME place (fold_state.ml: "the sign (M vs V) does NOT
   change the flat placement"), and the layering-validity check reads only
   angles + rank — so none of this depends on the M/V letters. [collapse_all_
   patterns] builds it ONCE per vertex/sector and reuses it across every
   Maekawa pattern; [overlaps] (also placement-derived, hence valley- and
   rank-independent) is memoized lazily the first time a pattern needs it. *)
type sector_geom = {
  sg_g : Fold_state.t;
  sg_o : Geom.point;
  sg_rays : (Geom.point * elem) array;
  sg_faces : Geom.point array array;
  sg_nf : int;
  sg_n : int;
  sg_tsec : Isometry.t array;
  sg_sec : int array;  (* per face, its sector, -1 if a ray crosses it *)
  sg_tip : bool array;  (* the faces the fan moves (ADR 0037) *)
  sg_unit : int array;  (* per face, the unit of the stacking it is ranked in *)
  sg_nu : int;  (* units: the n sectors, then the stationary blocks *)
  sg_stat_cons : (int * int) list;  (* (upper, lower), stationary units *)
  sg_ray_rep : Isometry.t array;
  sg_g_rank : int array;
  sg_root : int;
  sg_marks : Fold_state.mark array;
  sg_old_hinges : Fold_state.hinge array;
  sg_hinge_ray : int option array;  (* per hinge, the ray it carries, else None *)
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

(* The units the stacking ranks. Sector k < n holds the tip's faces in that
   sector, and sector 0 the faces of the stayer's wedge the tip hangs from
   ([tip_base]). Every other face is a layer the fan leaves where it lies,
   inside the stayer's wedge or outside it; those faces form one more unit
   per piece joined by flat hinges, since a moving sector cannot pass between
   two faces of one flat piece, and the tip can land between them and sector
   0. Between the stationary units, the order of overlapping faces is kept;
   units that overlap both ways are merged, into sector 0 when it takes
   part. Returns the unit of each face, the unit count and the (upper, lower)
   order between stationary units. *)
let stacking_units (g : Fold_state.t) ~(n : int) ~(sec : int array)
    ~(tip : bool array) : int array * int * (int * int) list =
  let nf = Array.length sec in
  let base = tip_base g ~sec ~tip in
  let unit =
    Array.init nf (fun i -> if tip.(i) || base.(i) then sec.(i) else -1)
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

let mk_sector_geom (g : Fold_state.t) ~(o : Geom.point)
    ~(rays : (Geom.point * elem) array) ~(faces : Geom.point array array)
    ~(nf : int) ~(anchor : bool array) : (sector_geom, string) result =
  let n = Array.length rays in
  let tsec = sector_isometries o rays in
  (* sector of each face (fixed, independent of stacking) *)
  let sec =
    Array.init nf (fun i ->
        sector_of_poly_opt o rays (faces.(i), Fold_state.face_iso2 g i))
  in
  let tip = tip_of g ~sec ~anchor in
  if not (Array.exists Fun.id tip) then Error e_anchor_stays
  else if Array.exists2 (fun t s -> t && s < 0) tip sec then Error e_unaligned
  else
  let unit, nu, stat_cons = stacking_units g ~n ~sec ~tip in
  let g_rank = Fold_state.rank g in
  (* a face that moves, or a stationary face hinged to one: the layers whose
     letters a ray of the fan describes *)
  let touches_tip =
    let t = Array.copy tip in
    Array.iter
      (fun (h : Fold_state.hinge) ->
        if tip.(h.Fold_state.fa) || tip.(h.Fold_state.fb) then begin
          t.(h.Fold_state.fa) <- true;
          t.(h.Fold_state.fb) <- true
        end)
      (Fold_state.hinges g);
    t
  in
  (* Per-ray orientation representative feeding [effective_valley]. For ray [j]
     the stayer-side sector is [l = (j-1+n) mod n] (the sector CCW-before the
     ray). The M/V letter carried by ray [j] is about the *layer of stayer
     material actually adjacent to that crease*, not an arbitrary face in a
     possibly mixed-orientation sector: pick the face in sector [l] whose table
     polygon has an edge running from O out along the ray segment (O -> far_j).
     That edge is the crease itself, so its face is the layer the letter
     describes. This is what lets a mixed sector — a stationary base strip
     (det>0) with a folded stack (det<0) riding on it, e.g. the fish's
     second-ear vertex — read parity from the crease-adjacent base layer rather
     than from whatever face happens to be first by array index (the old
     per-sector representative, which flipped one hinge constraint and starved
     the true stacking chain). *)
  let ray_rep =
    Array.init n (fun j ->
        let l = (j - 1 + n) mod n in
        let far, _ = rays.(j) in
        let adjacent i =
          sec.(i) = l && touches_tip.(i)
          &&
          let poly =
            Array.map (Isometry.apply_point (Fold_state.face_iso2 g i)) faces.(i)
          in
          let m = Array.length poly in
          let hit = ref false in
          for k = 0 to m - 1 do
            let a = poly.(k) and b = poly.((k + 1) mod m) in
            if
              (Geom.point_equal a o
              && (not (Geom.point_equal b o))
              && Geom.on_segment (o, far) b)
              || (Geom.point_equal b o
                 && (not (Geom.point_equal a o))
                 && Geom.on_segment (o, far) a)
            then hit := true
          done;
          !hit
        in
        (* Among crease-adjacent faces take the lowest prior rank. Several
           qualify only for a through-folded multi-layer crease (not in today's
           corpus); which layer's letter wins is #48 territory. If none
           qualifies (should not happen — the crease bounds the sector), fall
           back to the old first-in-sector representative rather than raise. *)
        let best = ref (-1) in
        for i = 0 to nf - 1 do
          if adjacent i && (!best < 0 || g_rank.(i) < g_rank.(!best)) then
            best := i
        done;
        if !best < 0 then
          for i = 0 to nf - 1 do
            if !best < 0 && sec.(i) = l && touches_tip.(i) then best := i
          done;
        if !best < 0 then Isometry.identity
        else Fold_state.face_iso2 g !best)
  in
  (* anchor root = first face in the stayer sector (rotated sector 0). Its
     [tsec.(0) = identity] is orientation-preserving, so validity filtering
     (rigid-motion invariant) reads the same as at any proper sector. *)
  let root =
    let found = ref (-1) in
    for i = 0 to nf - 1 do
      if !found < 0 && sec.(i) = 0 && unit.(i) = 0 then found := i
    done;
    if !found < 0 then
      invalid_arg
        "Collapse.pipeline_at: stayer sector 0 holds no face (unreachable — \
         every sector holds >= 1 face)";
    !found
  in
  (* which ray (if any) each hinge carries — pure geometry, so matched once and
     reused: only the M/V *letter* stamped on it later varies by pattern. *)
  let old_hinges = Fold_state.hinges g in
  let hinge_ray =
    Array.mapi
      (fun i (h : Fold_state.hinge) ->
        let ta, tb = Fold_state.hinge_table_segment g i in
        let hit = ref None in
        for j = 0 to n - 1 do
          let far, elem = rays.(j) in
          if
            elem.cid = h.Fold_state.crease_id
            && Geom.on_segment (o, far) ta
            && Geom.on_segment (o, far) tb
          then hit := Some j
        done;
        !hit)
      old_hinges
  in
  Ok {
    sg_g = g; sg_o = o; sg_rays = rays; sg_faces = faces; sg_nf = nf; sg_n = n;
    sg_tsec = tsec; sg_sec = sec; sg_tip = tip; sg_unit = unit; sg_nu = nu;
    sg_stat_cons = stat_cons; sg_ray_rep = ray_rep; sg_g_rank = g_rank;
    sg_root = root; sg_marks = Fold_state.marks g; sg_old_hinges = old_hinges;
    sg_hinge_ray = hinge_ray; sg_overlaps = None;
  }

(* The valley-DEPENDENT half of the old [pipeline_at]: given the shared
   [sector_geom] and this pattern's per-ray valley, enumerate the layer
   stackings and dedup by overlap signature. Byte-identical to the fused
   version — the split only hoists the geometry out of the pattern loop. *)
let pipeline_solve (sg : sector_geom) ~(valley : bool array)
    ~(over : (int * int) list) : (pipeline, string) result =
  let n = sg.sg_n and nf = sg.sg_nf in
  let tsec = sg.sg_tsec and sec = sg.sg_unit and ray_rep = sg.sg_ray_rep in
  let g_rank = sg.sg_g_rank and root = sg.sg_root in
  (* hinge constraints *)
  let eff_of_ray j =
    let l = (j - 1 + n) mod n in
    effective_valley valley.(j) tsec.(l) ray_rep.(j)
  in
  let constraints =
    List.init n (fun j -> let l = (j - 1 + n) mod n in
        if eff_of_ray j then (j, l) else (l, j))
  in
  let stackings =
    linear_extensions sg.sg_nu (constraints @ sg.sg_stat_cons)
  in
  (* new hinges: every hinge of the tip whose crease matches a ray gets angle
     1; others are carried unchanged *)
  let new_hinges =
    Array.mapi
      (fun i (h : Fold_state.hinge) ->
        match sg.sg_hinge_ray.(i) with
        | Some _
          when sg.sg_tip.(h.Fold_state.fa) || sg.sg_tip.(h.Fold_state.fb) ->
            { h with Fold_state.angle = Num.one }
        | _ -> h)
      sg.sg_old_hinges
  in
  (* total face rank from a sector stacking: sort by (srank.(sector),
     intra-sector order), tiebreak by index (never fires). *)
  let intra i =
    if sec.(i) >= n || Isometry.det_sign tsec.(sec.(i)) > 0 then g_rank.(i)
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
      ~hinges:new_hinges ~root ~rank ()
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

(* the original fused entry: build the sector geometry and solve for the one
   valley vector carried by [rays]. Direct callers ([collapse]/[collapse_all]
   via [collapse_runs]) keep byte-identical behavior; the pattern-sharing path
   ([collapse_all_patterns]) reuses [mk_sector_geom] across many valleys. *)
let pipeline_at (g : Fold_state.t) ~(o : Geom.point)
    ~(rays : (Geom.point * elem) array) ~(faces : Geom.point array array)
    ~(nf : int) ~(anchor : bool array) ~(over : (int * int) list) :
    (pipeline, string) result =
  match mk_sector_geom g ~o ~rays ~faces ~nf ~anchor with
  | Error e -> Error e
  | Ok sg ->
      let valley = Array.map (fun (_, e) -> e.valley) rays in
      pipeline_solve sg ~valley ~over

let in_bounds (gg : Fold_state.t) : bool =
  let nfg = Array.length (Fold_state.faces gg) in
  let ok = ref true in
  for i = 0 to nfg - 1 do
    if not (Array.for_all Geom.in_unit_square (Fold_state.table_polygon gg i))
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
  | Ok gg when in_bounds gg -> Ok gg
  | Ok _ -> Error e_out_of_paper
  | Error _ -> Error e_out_of_paper

(* pool the per-sector runs: any in-bounds realization wins (Ok pool); an empty
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

(* run the pipeline once per admissible stayer sector (rotating that sector to
   0), pooling every in-bounds anchored realization. No cross-run dedup — two
   admissible sectors are two different stayers, i.e. physically different
   folds — while per-run signature dedup stays. *)
let collapse_runs ?anchor (g : Fold_state.t) (es : elem list)
    ~(over : (int * int) list) ~(stayer : stayer) :
    (Fold_state.t list, string) result =
  match prepipeline g es with
  | Error e -> Error e
  | Ok (o, rays) -> (
      let faces = Fold_state.faces g in
      let nf = Array.length faces in
      let sec_orig =
        Array.init nf (fun i ->
            sector_of_poly_opt o rays (faces.(i), Fold_state.face_iso2 g i))
      in
      let anchor = anchor_faces g o anchor in
      match
        try Ok (admissible_sectors ~stayer o rays sec_orig nf)
        with Stayer_collinear -> Error e_stayer_collinear
      with
      | Error e -> Error e
      | Ok [] -> Error e_stayer_dead
      | Ok sectors ->
          let run s0 =
            match
              pipeline_at g ~o ~rays:(rotate_rays rays s0) ~faces ~nf ~anchor
                ~over
            with
            | Error e -> `Err e
            | Ok { root; candidate_at; distinct } ->
                `Run
                  (List.map
                     (fun fr -> anchor_realization g ~root ~candidate_at fr)
                     distinct)
          in
          pool_of_runs (List.map run sectors))

(* The many-pattern entry: solve a whole batch of Maekawa patterns over ONE
   fixed vertex geometry, sharing the sector geometry (placements, overlap set,
   ray reps) across every pattern instead of rebuilding it per pattern as a
   [List.map (collapse_all g (es_with_valley p)) patterns] would. [es] carries
   the geometry (its own valley is ignored); [patterns.(p)] is the per-ray
   valley in [es] order. Returns one result per pattern, parallel to
   [patterns]. Behaviorally identical to calling [collapse_all] once per
   pattern. *)
let collapse_all_patterns ?anchor (g : Fold_state.t) (es : elem list)
    ~(over : (int * int) list) ~(stayer : stayer)
    ~(patterns : bool list list) : (Fold_state.t list, string) result list =
  match prepipeline_geom g es with
  | Error e -> List.map (fun _ -> Error e) patterns
  | Ok (o, rays) -> (
      let faces = Fold_state.faces g in
      let nf = Array.length faces in
      let sec_orig =
        Array.init nf (fun i ->
            sector_of_poly_opt o rays (faces.(i), Fold_state.face_iso2 g i))
      in
      let anchor = anchor_faces g o anchor in
      match
        try Ok (admissible_sectors ~stayer o rays sec_orig nf)
        with Stayer_collinear -> Error e_stayer_collinear
      with
      | Error e -> List.map (fun _ -> Error e) patterns
      | Ok [] -> List.map (fun _ -> Error e_stayer_dead) patterns
      | Ok sectors ->
          (* per-sector geometry, built ONCE and reused across all patterns *)
          let sgs =
            List.map
              (fun s0 ->
                let rays_r = rotate_rays rays s0 in
                (s0, mk_sector_geom g ~o ~rays:rays_r ~faces ~nf ~anchor))
              sectors
          in
          (* map each pattern's valley (in [es] order) onto the sorted rays.
             Match by far tip, NOT cid: a full crease through O subdivides into
             two rays that share one crease id (the "+" vertex's --h/--v), so
             cid is not unique per ray, but the far tip is (distinct ray
             directions, boundary endpoints). *)
          let es_arr = Array.of_list es in
          let perm =
            Array.map
              (fun (far, _) ->
                let idx = ref (-1) in
                Array.iteri
                  (fun i (e' : elem) ->
                    if !idx < 0 && Geom.point_equal (far_of o e') far then idx := i)
                  es_arr;
                !idx)
              rays
          in
          List.map
            (fun pat ->
              if not (maekawa_ok pat) then Error e_maekawa
              else begin
                let pat_arr = Array.of_list pat in
                let valley_sorted =
                  Array.map (fun oi -> pat_arr.(oi)) perm
                in
                let run (s0, sg) =
                  let valley = rotate_rays valley_sorted s0 in
                  match
                    Result.bind sg (fun sg -> pipeline_solve sg ~valley ~over)
                  with
                  | Error e -> `Err e
                  | Ok { root; candidate_at; distinct } ->
                      `Run
                        (List.map
                           (fun fr -> anchor_realization g ~root ~candidate_at fr)
                           distinct)
                in
                pool_of_runs (List.map run sgs)
              end)
            patterns)

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
