(** The folded state of the paper as a stack of flat faces. Each face is a
    convex CCW polygon in paper coordinates plus the isometry placing it on the
    table. [order] is a sparse per-face partial order (a [Layer_order.t], queried
    with [Layer_order.get]): it says whether face i is Above/Below face j when
    folded, or Apart if they do not overlap on the table. Array index carries no
    z-meaning — all stacking lives in [order]. *)

type face = { paper : Geom.point array; iso : Isometry.t }
type rel = Layer_order.rel = Above | Below | Apart
type assign = M | V | F

type mark_geom = MSeg of Geom.point * Geom.point | MPoint of Geom.point

(* A non-subdividing reference/pinch crease. [mgeom] is PAPER-space and therefore
   fold-invariant, so marks carry through subdivide/fold/flip unchanged; the
   current table position is derived at emit time from the containing face's
   isometry (see mark_face). [mline] is the underlying motion line, kept only to
   orient a point-mark's display tick. [mintent] is the crease-pattern colour;
   the mark is always flat (F) in the folded form. [mcrease_id] rides with the
   name's bundle, mirroring edge.crease_id. *)
type mark = {
  mgeom : mark_geom;
  mline : Geom.line;
  mintent : assign;
  mcrease_id : int;
  mprov : State.provenance option;
}

(* A first-class crease edge between two faces. [ea]/[eb] are the segment
   endpoints in the [left] face's paper coordinates. [right] is [-1] when the
   edge lies on the paper boundary (no face on the other side). [crease_id] is
   internal identity only — never serialized, need only be unique within one
   state. [eassign] is the folded-form dihedral (F for a flat mark);
   [eintent] is the crease-pattern colour (M/V even when flat) — for a real
   fold the two agree. *)
type edge = {
  ea : Geom.point;
  eb : Geom.point;
  left : int;
  right : int;
  eassign : assign;
  eintent : assign;
  crease_id : int;
  eprov : State.provenance option;
}

type t = { faces : face array; order : Layer_order.t; edges : edge array; marks : mark array }

(* Mints internal crease ids. Unique within a state; not deterministic across
   eval calls and never serialized. *)
let next_id = ref 0

let fresh_crease_id () =
  let id = !next_id in
  incr next_id;
  id

let negate = Layer_order.negate

(* table-space polygon of a face *)
let table_poly_of (f : face) : Geom.point array =
  Array.map (Isometry.apply_point f.iso) f.paper

let table_polygon (st : t) (i : int) : Geom.point array = table_poly_of st.faces.(i)

(* table_polygon is CCW only when face i's placing isometry is proper (paper
   is always CCW); a fold reflects the moving side (det_sign < 0), reversing
   its table-space winding to CW. [clip_line_to_convex]/[line_cuts_polygon]/
   [segment_crosses_interior] require CCW input, so restore it here before
   calling into them. *)
let table_polygon_ccw (st : t) (i : int) : Geom.point array =
  let tp = table_polygon st i in
  if Isometry.det_sign st.faces.(i).iso < 0 then
    Array.of_list (List.rev (Array.to_list tp))
  else tp

(* Build the sparse order over table-space polygons. [rel_of i j] is consulted
   only for i<j pairs whose table polygons overlap; everything else stays
   Apart. *)
let build_order (faces : face array) (rel_of : int -> int -> rel) : Layer_order.t
    =
  Layer_order.build (Array.map table_poly_of faces) rel_of

(* table-space segment of crease edge [e], via its [left] face's isometry. The
   endpoints live in the shared paper frame, so either bordering face's isometry
   places them on the same table segment. *)
let edge_table_segment (st : t) (e : edge) : Geom.point * Geom.point =
  let iso = st.faces.(e.left).iso in
  (Isometry.apply_point iso e.ea, Isometry.apply_point iso e.eb)

(* Does segment [pa]-[pb] pass through the *interior* of convex CCW [poly]? True
   iff the portion of the segment inside [poly] has positive length and its
   midpoint is strictly interior — a segment lying along a boundary edge (a crease
   bordering the face, i.e. a taco-taco situation) is excluded. Exact throughout:
   clip the parameter t∈[0,1] to every interior half-plane, then sign-test the
   midpoint. *)
let segment_crosses_interior ((pa, pb) : Geom.point * Geom.point)
    (poly : Geom.point array) : bool =
  if Geom.point_equal pa pb then false
  else begin
    let dx = Num.sub pb.Geom.x pa.Geom.x and dy = Num.sub pb.Geom.y pa.Geom.y in
    let n = Array.length poly in
    let lo = ref Num.zero and hi = ref Num.one and empty = ref false in
    for i = 0 to n - 1 do
      let e1 = poly.(i) and e2 = poly.((i + 1) mod n) in
      let ex = Num.sub e2.Geom.x e1.Geom.x and ey = Num.sub e2.Geom.y e1.Geom.y in
      (* interior of a CCW polygon is left of each edge: cross(e1→e2, p−e1) ≥ 0.
         Along the segment this is affine in t: f(t) = f0 + t·fd. *)
      let f0 =
        Num.sub
          (Num.mul ex (Num.sub pa.Geom.y e1.Geom.y))
          (Num.mul ey (Num.sub pa.Geom.x e1.Geom.x))
      in
      let fd = Num.sub (Num.mul ex dy) (Num.mul ey dx) in
      match Num.sign fd with
      | 0 -> if Num.sign f0 < 0 then empty := true
      | s ->
          let t = Num.div (Num.neg f0) fd in
          if s > 0 then (if Num.compare t !lo > 0 then lo := t)
          else if Num.compare t !hi < 0 then hi := t
    done;
    if !empty || Num.compare !lo !hi >= 0 then false
    else begin
      let tm = Num.div (Num.add !lo !hi) (Num.of_int 2) in
      let m =
        { Geom.x = Num.add pa.Geom.x (Num.mul tm dx);
          y = Num.add pa.Geom.y (Num.mul tm dy) }
      in
      let strict = ref true in
      for i = 0 to n - 1 do
        let a = poly.(i) and b = poly.((i + 1) mod n) in
        let cross =
          Num.sub
            (Num.mul (Num.sub b.Geom.x a.Geom.x) (Num.sub m.Geom.y a.Geom.y))
            (Num.mul (Num.sub b.Geom.y a.Geom.y) (Num.sub m.Geom.x a.Geom.x))
        in
        if Num.sign cross <= 0 then strict := false
      done;
      !strict
    end
  end

(* Do two table segments coincide over a sub-segment of positive length (i.e. the
   two creases strictly overlap under the folding map)? Collinear + overlapping
   parameter ranges. *)
let segments_overlap_collinear ((p1, q1) : Geom.point * Geom.point)
    ((p2, q2) : Geom.point * Geom.point) : bool =
  if Geom.point_equal p1 q1 || Geom.point_equal p2 q2 then false
  else
    let l = Geom.line_through p1 q1 in
    if Geom.side_of_line l p2 <> 0 || Geom.side_of_line l q2 <> 0 then false
    else
      let ta = Geom.seg_param (p1, q1) p2 and tb = Geom.seg_param (p1, q1) q2 in
      let tlo = if Num.compare ta tb <= 0 then ta else tb in
      let thi = if Num.compare ta tb <= 0 then tb else ta in
      let olo = if Num.compare tlo Num.zero > 0 then tlo else Num.zero in
      let ohi = if Num.compare thi Num.one < 0 then thi else Num.one in
      Num.compare olo ohi < 0

(* Is face [y] stacked strictly between faces [x] and [z]? *)
let between (st : t) x y z : bool =
  (Layer_order.get st.order x y = Above && Layer_order.get st.order y z = Above)
  || (Layer_order.get st.order z y = Above && Layer_order.get st.order y x = Above)

(* Taco-tortilla (face-crease non-crossing): for a folded taco a|b (its two faces
   strictly overlap on the table), no other face may both cross the crease through
   its interior and lie between a and b. [hullzakharevich2023, §2.1]. *)
let taco_tortilla_error (st : t) : string option =
  let n = Array.length st.faces in
  let result = ref None in
  Array.iter
    (fun e ->
      if !result = None && e.left >= 0 && e.right >= 0
         && Layer_order.get st.order e.left e.right <> Apart then begin
        let a = e.left and b = e.right in
        let seg = edge_table_segment st e in
        for c = 0 to n - 1 do
          if !result = None && c <> a && c <> b
             && segment_crosses_interior seg (table_polygon_ccw st c)
             && between st a c b
          then
            result :=
              Some
                (Printf.sprintf
                   "layer ordering: face %d would pass through crease (%d|%d) — \
                    taco-tortilla violation" c a b)
        done
      end)
    st.edges;
  !result

(* Taco-taco (crease-crease non-crossing): when two distinct creases coincide on
   the table and hinge disjoint face pairs {a,b} and {c,d}, the pairs must not
   interleave in the stack — exactly one of c,d lying between a,b is a crossing.
   [hullzakharevich2023, §2.1]. *)
let taco_taco_error (st : t) : string option =
  let m = Array.length st.edges in
  let result = ref None in
  for i = 0 to m - 1 do
    for j = i + 1 to m - 1 do
      if !result = None then begin
        let e1 = st.edges.(i) and e2 = st.edges.(j) in
        let a = e1.left and b = e1.right and c = e2.left and d = e2.right in
        if a >= 0 && b >= 0 && c >= 0 && d >= 0 && e1.crease_id <> e2.crease_id
           && a <> c && a <> d && b <> c && b <> d
           && Layer_order.get st.order a b <> Apart
           && Layer_order.get st.order c d <> Apart
           && segments_overlap_collinear (edge_table_segment st e1)
                (edge_table_segment st e2)
           && between st a c b <> between st a d b
        then
          result :=
            Some
              (Printf.sprintf
                 "layer ordering: creases (%d|%d) and (%d|%d) cross — taco-taco \
                  violation" a b c d)
      end
    done
  done;
  !result

(* Acyclicity of the [Above] relation over overlapping faces, then a check that
   every overlapping pair is decided (tortilla-tortilla: two strictly-overlapping
   uncreased faces must have one entirely above the other), then the two crease
   non-crossing guards (taco-tortilla, taco-taco). Returns the first violation as
   a message, or None. *)
let validity_error (st : t) : string option =
  let n = Array.length st.faces in
  let color = Array.make n 0 (* 0 white, 1 gray, 2 black *) in
  let cycle = ref None in
  let rec dfs i =
    color.(i) <- 1;
    List.iter
      (fun j ->
        if !cycle = None then
          if color.(j) = 1 then
            cycle := Some
              (Printf.sprintf
                 "layer ordering: stacking cycle through faces %d and %d (paper \
                  through paper)" i j)
          else if color.(j) = 0 then dfs j)
      (Layer_order.above_neighbors st.order i);
    color.(i) <- 2
  in
  for i = 0 to n - 1 do
    if color.(i) = 0 && !cycle = None then dfs i
  done;
  match !cycle with
  | Some _ as c -> c
  | None ->
      let bad = ref None in
      Layer_order.iter st.order (fun i j r ->
          if !bad = None && r = Apart then
            bad := Some
              (Printf.sprintf
                 "layer ordering: faces %d and %d overlap but have no order \
                  (tortilla-tortilla)" i j));
      (match !bad with
       | Some _ -> !bad
       | None -> (
           match taco_tortilla_error st with
           | Some _ as t -> t
           | None -> taco_taco_error st))

let init_square : t =
  let p x y = { Geom.x = Num.of_int x; y = Num.of_int y } in
  {
    faces =
      [| { paper = [| p 0 0; p 1 0; p 1 1; p 0 1 |]; iso = Isometry.identity } |];
    order = Layer_order.build [| [| p 0 0; p 1 0; p 1 1; p 0 1 |] |] (fun _ _ -> Apart);
    edges = [||];
    marks = [||];
  }

(* The edge incident to face [i] whose endpoints equal (pa,pb) in either order.
   Endpoints live in the global material (unfolded-paper) frame shared by every
   face, so equality against a face's paper polygon side is well defined. *)
let edge_between (st : t) (i : int) (pa : Geom.point) (pb : Geom.point) :
    edge option =
  Array.find_opt
    (fun e ->
      (e.left = i || e.right = i)
      && ((Geom.point_equal e.ea pa && Geom.point_equal e.eb pb)
         || (Geom.point_equal e.ea pb && Geom.point_equal e.eb pa)))
    st.edges

(* Face ids sharing an edge with face [i]. *)
let neighbors (st : t) (i : int) : int list =
  Array.fold_left
    (fun acc e ->
      if e.left = i && e.right >= 0 then e.right :: acc
      else if e.right = i then e.left :: acc
      else acc)
    [] st.edges

(* table-space endpoints of every piece of crease [cid] (via each piece's
   [left] face isometry; endpoints live in the shared paper frame). *)
let crease_table_endpoints (st : t) (cid : int) : Geom.point list =
  Array.fold_left
    (fun acc e ->
      if e.crease_id = cid then
        let iso = st.faces.(e.left).iso in
        Isometry.apply_point iso e.ea :: Isometry.apply_point iso e.eb :: acc
      else acc)
    [] st.edges

type crease_segment = {
  faces : int * int;
  ta : Geom.point;
  tb : Geom.point;
  pa : Geom.point;
  pb : Geom.point;
}

(* Every material segment of crease [cid]. [ta]/[tb] in table space via the
   left face isometry (the two faces coincide along the crease, so left is
   canonical); [pa]/[pb] in the shared paper frame. One entry per edge tagged
   [cid] with a real left face. Degenerate edges are dropped. *)
(* the distinct crease ids present in the current state (for selectors that must
   scan every existing crease, not one named bundle) *)
let all_crease_ids (st : t) : int list =
  let seen = Hashtbl.create 16 in
  Array.iter
    (fun e -> if e.crease_id >= 0 then Hashtbl.replace seen e.crease_id ())
    st.edges;
  Hashtbl.fold (fun k () acc -> k :: acc) seen []

let crease_segments (st : t) (cid : int) : crease_segment list =
  Array.fold_left
    (fun acc e ->
      if e.crease_id = cid && e.left >= 0 then
        let iso = st.faces.(e.left).iso in
        let ta = Isometry.apply_point iso e.ea
        and tb = Isometry.apply_point iso e.eb in
        if Geom.point_equal ta tb then acc
        else { faces = (e.left, e.right); ta; tb; pa = e.ea; pb = e.eb } :: acc
      else acc)
    [] st.edges

(* find two distinct points to define a line *)
let rec pick_two_distinct = function
  | a :: rest -> (
      match List.find_opt (fun b -> not (Geom.point_equal a b)) rest with
      | Some b -> Some (a, b)
      | None -> pick_two_distinct rest)
  | [] -> None

let crease_axis (st : t) (cid : int) (l_orig : Geom.line) :
    [ `Line of Geom.line | `Bent | `Empty ] =
  match crease_table_endpoints st cid with
  | [] -> `Empty
  | pts ->
      if List.for_all (fun p -> Geom.side_of_line l_orig p = 0) pts then
        `Line l_orig (* unmoved: byte-stable, common case *)
      else (
        match pick_two_distinct pts with
        | None -> `Empty
        | Some (a, b) ->
            let l = Geom.line_through a b in
            if List.for_all (fun p -> Geom.side_of_line l p = 0) pts then `Line l
            else `Bent)

(* The single PAPER-space line carrying every material segment of [cid], if
   one exists. Segments born on different layers are mirror-image scars on
   different paper lines -> [`Bent]; segments merely subdivided by later folds
   stay collinear in the paper. Endpoints live in the shared paper frame, so
   no isometry is involved. *)
let crease_paper_axis (st : t) (cid : int) :
    [ `Line of Geom.line | `Bent | `Empty ] =
  let pts =
    Array.fold_left
      (fun acc e -> if e.crease_id = cid then e.ea :: e.eb :: acc else acc)
      [] st.edges
  in
  match pick_two_distinct pts with
  | None -> `Empty
  | Some (a, b) ->
      let l = Geom.line_through a b in
      if List.for_all (fun p -> Geom.side_of_line l p = 0) pts then `Line l
      else `Bent

(* Component id per face: the graph whose nodes are faces and whose edges are
   interior adjacencies still assignment F (flat, unfolded). Two faces
   separated only by an F edge are the same flap; the instant that edge folds
   (F -> M/V) the flap splits there, exactly and only there (ADR 0017).
   Recomputed from the current F-edge set on every call — no incremental
   cache, so a future `unfold` (which merges clusters) needs no extra
   bookkeeping. O(faces + edges) per call. *)
let coplanar_clusters (st : t) : int array =
  let n = Array.length st.faces in
  let parent = Array.init n Fun.id in
  let rec find i = if parent.(i) = i then i else (
    let r = find parent.(i) in
    parent.(i) <- r;
    r)
  in
  let union a b =
    let ra = find a and rb = find b in
    if ra <> rb then parent.(ra) <- rb
  in
  Array.iter
    (fun (e : edge) ->
      if e.left >= 0 && e.right >= 0 && e.eassign = F then union e.left e.right)
    st.edges;
  Array.init n (fun i -> find i)

(* The unique flap (coplanar cluster, as its face-index list) whose union of
   paper polygons contains every point in [pts]. A point on a shared F edge
   belongs to both incident faces, but they're the same cluster, so that's
   still one id. `Zero if no cluster contains every point, `Ambiguous if more
   than one does. *)
let cluster_of_points (st : t) (pts : Geom.point list) :
    [ `Cluster of int list | `Zero | `Ambiguous ] =
  let cl = coplanar_clusters st in
  let n = Array.length st.faces in
  let ids_of_point p =
    let s = ref [] in
    for i = 0 to n - 1 do
      if Geom.in_convex_polygon st.faces.(i).paper p && not (List.mem cl.(i) !s)
      then s := cl.(i) :: !s
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
       | [ id ] -> `Cluster (List.filter (fun i -> cl.(i) = id) (List.init n Fun.id))
       | [] -> `Zero
       | _ -> `Ambiguous)

let flap_of_points (st : t) (pts : Geom.point list) :
    [ `Cluster of int list | `Zero | `Ambiguous ] =
  cluster_of_points st pts

(* on-paper material of a table-space line: its positive-length
   intersection with each face, table space. Stacked layers yield
   duplicate segments — fine for existence/sign tests, any future
   measure-based use must dedupe. *)
let line_material_segments (st : t) (l : Geom.line) :
    (Geom.point * Geom.point) list =
  List.filter_map
    (fun i -> Geom.clip_line_to_convex l (table_polygon_ccw st i))
    (List.init (Array.length st.faces) Fun.id)

(* the line actually creases some face (strict interior cut) *)
let line_cuts_paper (st : t) (l : Geom.line) : bool =
  List.exists
    (fun i -> Geom.line_cuts_polygon l (table_polygon_ccw st i))
    (List.init (Array.length st.faces) Fun.id)

type scope_target = TargetFace of int | TargetHinged of (int -> bool)

(* Moving-set selection for a scoped ("up to") simple fold: the outer-contiguous
   prefix of layers over the crease region ending at the target — the static
   shadow of a collision-free 180° rotation [demaine2007, §14.1]. "Outer" is
   top for valley, bottom for mountain. Candidates are the faces with a piece
   on the moving side; overlap is judged between those pieces (depth may vary
   along the crease). Errors are messages; the caller attaches the span. *)
let select_scope (st : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) ~(anchor : int) ~(target : scope_target) :
    (bool array, string) result =
  let n = Array.length st.faces in
  let cl = coplanar_clusters st in
  let piece =
    Array.init n (fun i ->
        let sub =
          Geom.clip_convex_halfplane axis move_side (table_polygon st i)
        in
        if Array.length sub >= 3 then Some sub else None)
  in
  let cand i = piece.(i) <> None in
  let overlap i j =
    match (piece.(i), piece.(j)) with
    | Some a, Some b -> Geom.convex_overlap a b
    | _ -> false
  in
  (* i lies strictly outside j over the crease region *)
  let outer i j =
    overlap i j
    && Layer_order.get st.order i j = (if valley then Above else Below)
  in
  if not (cand anchor) then
    Error "the moving flap has no material on the moving side of the fold axis"
  else
  let find_targets () : (int list, string) result =
    match target with
    | TargetFace t ->
        if not (cand t) then
          Error "`up to`: the target flap is not on the moving side of the fold"
        else Ok [ t ]
    | TargetHinged pred ->
        if pred anchor then Ok [ anchor ]
        else begin
          (* walk inward from the anchor, one stack level at a time; the first
             level containing a hinged flap ends the range (inclusive) *)
          let visited = Array.make n false in
          visited.(anchor) <- true;
          let result = ref None in
          while !result = None do
            let frontier = ref [] in
            for g = 0 to n - 1 do
              if (not visited.(g)) && cand g then begin
                let inward = ref false in
                for v = 0 to n - 1 do
                  if visited.(v) && outer v g then inward := true
                done;
                if !inward then frontier := g :: !frontier
              end
            done;
            match List.filter pred !frontier with
            | [] ->
                if !frontier = [] then
                  result :=
                    Some
                      (Error
                         "`up to`: no flap hinged on that crease is reachable \
                          from the anchor over the crease region")
                else List.iter (fun g -> visited.(g) <- true) !frontier
            | hits -> result := Some (Ok hits)
          done;
          Option.get !result
        end
  in
  match find_targets () with
  | Error e -> Error e
  | Ok targets ->
      let inm = Array.make n false in
      List.iter (fun t -> inm.(t) <- true) targets;
      (* closure: any candidate outside a moving flap over the region must
         move too — the moving set is an outer prefix by construction *)
      (* the moving set is closed under BOTH the existing outer-prefix rule
         AND cohesion: a candidate g in the same still-coplanar cluster as a
         moving m must move too — a fold may never tear an F-adjacent
         neighbourhood (ADR 0017, defect 2). The `cand g` guard is unchanged,
         so a face with no material on the moving side (the axis genuinely
         cuts the cluster there) is correctly left out. *)
      let changed = ref true in
      while !changed do
        changed := false;
        for g = 0 to n - 1 do
          if (not inm.(g)) && cand g then
            for m = 0 to n - 1 do
              if inm.(m) && (not inm.(g)) && (outer g m || cl.(g) = cl.(m)) then begin
                inm.(g) <- true;
                changed := true
              end
            done
        done
      done;
      if not inm.(anchor) then
        Error
          "`up to`: the target is not reachable from the anchor over the \
           crease region"
      else begin
        let buried = ref None in
        for m = 0 to n - 1 do
          if !buried = None && inm.(m) && m <> anchor && outer m anchor then
            buried := Some m
        done;
        match !buried with
        | Some m ->
            Error
              (Printf.sprintf
                 "a simple fold cannot move a buried flap: face %d covers the \
                  anchor in the crease region — include the covering flap \
                  (anchor the fold there) or fold less" m)
        | None -> Ok inm
      end

(* current table position of a material paper point: find the face whose paper
   polygon contains it, apply that face's isometry. Faces partition the paper,
   and isometries agree on shared crease edges, so any containing face works. *)
let table_position (st : t) (paper : Geom.point) : Geom.point =
  let n = Array.length st.faces in
  let rec find i =
    if i >= n then invalid_arg "Fold_state.table_position: point in no face"
    else if Geom.in_convex_polygon st.faces.(i).paper paper then
      Isometry.apply_point st.faces.(i).iso paper
    else find (i + 1)
  in
  find 0

let mark_rep_point (m : mark) : Geom.point =
  match m.mgeom with MSeg (a, _) -> a | MPoint p -> p

let add_mark (st : t) (m : mark) : t =
  { st with marks = Array.append st.marks [| m |] }

(* Paper-space chords (segment endpoints) of every MSeg mark carrying [cid].
   Point marks (MPoint) contribute no chord. Used by the meet operator to test
   that a marked line physically reaches a crossing. *)
let mark_chords (st : t) (cid : int) : (Geom.point * Geom.point) list =
  Array.to_list st.marks
  |> List.filter_map (fun m ->
         if m.mcrease_id = cid then
           match m.mgeom with MSeg (a, b) -> Some (a, b) | MPoint _ -> None
         else None)

(* The mark [cid]'s current TABLE-space axis, tracking folds/flips (its paper
   geometry is fold-invariant, so the current line is the paper chord mapped to
   the table). [`Bent] if a fold has bent the chord (its paper midpoint no
   longer maps onto the straight table chord) — the caller must pick a flap. *)
let mark_axis_current (st : t) (cid : int) :
    [ `Line of Geom.line | `Bent | `Empty ] =
  match mark_chords st cid with
  | [] -> `Empty
  | (a, b) :: _ ->
      let ta = table_position st a and tb = table_position st b in
      if Geom.point_equal ta tb then `Empty
      else
        let mid =
          { Geom.x = Num.div (Num.add a.Geom.x b.Geom.x) (Num.of_int 2);
            y = Num.div (Num.add a.Geom.y b.Geom.y) (Num.of_int 2) }
        in
        let tm = table_position st mid in
        let l = Geom.line_through ta tb in
        if Geom.side_of_line l tm = 0 then `Line l else `Bent

(* the face whose PAPER polygon contains the mark's representative point; paper
   coordinates partition the sheet, so this is unique in the interior (a point on
   a shared boundary may match several — first match wins, callers disambiguate). *)
let mark_face (st : t) (m : mark) : int option =
  let p = mark_rep_point m in
  let n = Array.length st.faces in
  let rec go i =
    if i >= n then None
    else if Geom.in_convex_polygon st.faces.(i).paper p then Some i
    else go (i + 1)
  in
  go 0

(* The segment where the table-space line [axis] crosses face [f]'s interior,
   returned in [f]'s paper coordinates. None if the axis misses the interior
   (touches at most one boundary point). *)
let axis_segment_in_face (f : face) (axis : Geom.line) :
    (Geom.point * Geom.point) option =
  let table = Array.map (Isometry.apply_point f.iso) f.paper in
  let n = Array.length table in
  let pts = ref [] in
  let add p =
    if not (List.exists (Geom.point_equal p) !pts) then pts := p :: !pts
  in
  for i = 0 to n - 1 do
    let a = table.(i) and b = table.((i + 1) mod n) in
    let sa = Geom.side_of_line axis a and sb = Geom.side_of_line axis b in
    if sa = 0 then add a
    else if sb <> 0 && sa <> sb then
      match Geom.intersection axis (Geom.line_through a b) with
      | Some r -> add r
      | None -> ()
  done;
  match !pts with
  | [ p; q ] ->
      let inv = Isometry.inverse f.iso in
      Some (Isometry.apply_point inv p, Isometry.apply_point inv q)
  | _ -> None

(* A mark's paper-space extent, classified against the flap (coplanar cluster)
   it lives on: does it subdivide the flap (a FULL CHORD — both endpoints on
   the flap's outer boundary, crossing only F edges in between), merely
   record (ANY endpoint strictly mid-face — the whole contiguous extent
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

(* The polygon edge (as its two vertices) of convex CCW [poly] that contains
   point [p], assumed to lie on the boundary. First match wins — at a vertex
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

(* Is the polygon edge of face [fi] passing through boundary point [p] a
   genuine flap boundary — a bare paper edge (no crease recorded at all) or a
   folded (M/V) crease? An F edge never counts: within one flap every internal
   edge is F by construction (coplanar clusters are exactly the F-connected
   components), so an F edge here always stays inside the flap. *)
let is_flap_boundary_at (st : t) (fi : int) (p : Geom.point) : bool =
  match polygon_edge_at st.faces.(fi).paper p with
  | None -> false (* [p] isn't even on this face's boundary *)
  | Some (v1, v2) -> (
      match edge_between st fi v1 v2 with
      | None -> true
      | Some e -> e.eassign <> F)

(* The flap face [p] is strictly interior to, if any. *)
let strictly_interior_to_flap_face (st : t) (flap : int list) (p : Geom.point)
    : int option =
  List.find_opt
    (fun fi ->
      let poly = st.faces.(fi).paper in
      Geom.in_convex_polygon poly p && not (point_on_polygon_boundary poly p))
    flap

(* [p] is "on the flap boundary" iff it is not strictly interior to any flap
   face and it lies on a true boundary edge (paper edge or M/V crease) of some
   flap face. *)
let endpoint_is_flap_boundary (st : t) (flap : int list) (p : Geom.point) :
    bool =
  match strictly_interior_to_flap_face st flap p with
  | Some _ -> false
  | None -> List.exists (fun fi -> is_flap_boundary_at st fi p) flap

(* For each face in [flap], the portion (as a parameter range over [a,b], with
   t=0 at [a] and t=1 at [b]) of [axis] clipped to that face's paper polygon
   AND to the extent [a,b] itself. Only positive-length overlaps are kept,
   sorted by increasing [lo]. *)
let flap_face_overlap (st : t) (flap : int list) (axis : Geom.line)
    (a : Geom.point) (b : Geom.point) : (int * Num.t * Num.t) list =
  List.filter_map
    (fun fi ->
      match Geom.clip_line_to_convex axis st.faces.(fi).paper with
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
let classify_seg (st : t) ~(flap : int list) ~(axis : Geom.line)
    (a : Geom.point) (b : Geom.point) : mark_class =
  let point_at t =
    {
      Geom.x = Num.add a.Geom.x (Num.mul t (Num.sub b.Geom.x a.Geom.x));
      y = Num.add a.Geom.y (Num.mul t (Num.sub b.Geom.y a.Geom.y));
    }
  in
  let segs = flap_face_overlap st flap axis a b in
  let fully_covers_axis =
    match segs with
    | [] -> false
    | (_, lo0, _) :: _ when Num.sign lo0 <> 0 -> false
    | _ ->
        let rec walk = function
          | (fi, _, hii) :: ((_fj, loj, _) :: _ as rest) ->
              if Num.compare hii loj <> 0 then false
              else begin
                match polygon_edge_at st.faces.(fi).paper (point_at hii) with
                | Some (v1, v2) -> (
                    match edge_between st fi v1 v2 with
                    | Some e when e.eassign <> F -> false
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
    let a_boundary = endpoint_is_flap_boundary st flap a in
    let b_boundary = endpoint_is_flap_boundary st flap b in
    if a_boundary && b_boundary then CSubdivide (a, b)
    else
      (* at least one endpoint strictly mid-face: the whole contiguous extent
         records as one stub, splitting nothing — even the faces it crosses
         boundary-to-boundary in the middle. *)
      CRecord (MSeg (a, b))

(* Does a mark's paper-space [extent_geom] subdivide [flap] (the coplanar
   cluster it lives on), merely record onto it, do both, or illegally cross a
   folded (M/V) crease? [axis] is the extent's own paper-space motion line
   (the line the segment/point lies on — e.g. the line a [between] extent was
   cut from). A full-extent mark never reaches here (the caller handles that
   as a plain [subdivide]).

   [MPoint] never subdivides and has no span to cross a fold with, so it
   always records. For [MSeg (a, b)]: walk the sub-segments of [axis] clipped
   to each flap face's paper polygon and to [a,b] itself; a gap, or an
   internal crossing over a non-F edge, means the extent leaves the flap
   (illegal — [CCrossesFold]); full coverage plus both endpoints on the
   flap's true boundary (a bare paper edge or an M/V crease, never an F edge)
   subdivides (a full chord); full coverage with at least one endpoint
   strictly mid-face records the whole contiguous extent as one stub,
   splitting nothing — even faces it crosses boundary-to-boundary in the
   middle. *)
let classify_mark_extent (st : t) ~(flap : int list) ~(axis : Geom.line)
    ~(extent_geom : mark_geom) : mark_class =
  match extent_geom with
  | MPoint p -> CRecord (MPoint p)
  | MSeg (a, b) -> classify_seg st ~flap ~axis a b

(* Split every face crossing [axis] into its two halves (both keep their
   isometry; nothing moves). Returns the new state; one F edge is created per
   face actually cut. *)
let subdivide ?crease_id ?(intent = V) (st : t) (axis : Geom.line)
    ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  let out = ref [] (* (child_face, parent_index), accumulated via prepend *) in
  (* seeds: (parent_index, a, b, crease_id) — one per face actually cut; the two
     children straddling the axis are the two entries of [parent] equal to
     parent_index, resolved after the final face order is fixed *)
  let edge_seeds = ref [] in
  Array.iteri
    (fun fi f ->
      let table = Array.map (Isometry.apply_point f.iso) f.paper in
      let inv = Isometry.inverse f.iso in
      let part keep =
        let sub = Geom.clip_convex_halfplane axis keep table in
        if Array.length sub >= 3 then
          Some { paper = Array.map (Isometry.apply_point inv) sub; iso = f.iso }
        else None
      in
      let plus = part 1 and minus = part (-1) in
      (match (plus, minus) with
      | Some _, Some _ -> (
          match axis_segment_in_face f axis with
          | Some (a, b) -> edge_seeds := (fi, a, b, cid) :: !edge_seeds
          | None -> ())
      | _ -> ());
      List.iter
        (function Some fc -> out := (fc, fi) :: !out | None -> ())
        [ plus; minus ])
    st.faces;
  let arr = Array.of_list (List.rev !out) in
  let faces = Array.map fst arr in
  let parent = Array.map snd arr in
  (* the (up to two) child indices descended from parent [fi], in face order *)
  let children_of fi =
    let acc = ref [] in
    Array.iteri (fun k p -> if p = fi then acc := k :: !acc) parent;
    List.rev !acc
  in
  let new_edges =
    List.rev_map
      (fun (fi, a, b, cid) ->
        let left, right =
          match children_of fi with
          | l :: r :: _ -> (l, r)
          | [ l ] -> (l, -1)
          | [] -> (-1, -1)
        in
        {
          ea = a;
          eb = b;
          left;
          right;
          eassign = F;
          eintent = intent;
          crease_id = cid;
          eprov = prov;
        })
      !edge_seeds
  in
  (* the child of parent [p] on side [s] of [axis]; a face split into two keeps
     its plus-side child (children_of order) for s>0 and minus for s<0; an
     uncut face has a single child returned for either side. *)
  let child_on p s =
    if p < 0 then -1
    else
      match children_of p with
      | [ c ] -> c
      | c_plus :: c_minus :: _ -> if s >= 0 then c_plus else c_minus
      | [] -> -1
  in
  let carried =
    List.concat_map
      (fun e ->
        let iso_l = st.faces.(e.left).iso in
        let a = Isometry.apply_point iso_l e.ea in
        let b = Isometry.apply_point iso_l e.eb in
        let sa = Geom.side_of_line axis a and sb = Geom.side_of_line axis b in
        if sa * sb >= 0 then
          (* wholly one side (or touching the axis): one child per incident face *)
          let s = if sa <> 0 then sa else sb in
          [ { e with left = child_on e.left s; right = child_on e.right s } ]
        else
          (* crosses the axis: split at the intersection into two collinear
             sub-edges sharing crease_id/eassign/eprov (#26 identity invariant) *)
          let p =
            match Geom.intersection axis (Geom.line_through a b) with
            | Some r -> Isometry.apply_point (Isometry.inverse iso_l) r
            | None -> e.ea
          in
          [
            { e with eb = p; left = child_on e.left sa; right = child_on e.right sa };
            { e with ea = p; left = child_on e.left sb; right = child_on e.right sb };
          ])
      (Array.to_list st.edges)
  in
  let edges = Array.of_list (new_edges @ carried) in
  let order =
    build_order faces (fun i j -> Layer_order.get st.order parent.(i) parent.(j))
  in
  { faces; order; edges; marks = st.marks }

(* Like [subdivide] but the cutting line is given in PAPER space and every face
   is clipped by its own paper polygon directly (no isometry) — so a line that
   bends across folds cuts each flap correctly in the material frame. Used to
   materialize a mark (fold-invariant paper geometry) into real creases on an
   already-folded sheet. *)
let subdivide_paper ?crease_id ?(intent = V) (st : t) (paper_axis : Geom.line)
    ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  let out = ref [] in
  let edge_seeds = ref [] in
  Array.iteri
    (fun fi f ->
      let part keep =
        let sub = Geom.clip_convex_halfplane paper_axis keep f.paper in
        if Array.length sub >= 3 then Some { paper = sub; iso = f.iso } else None
      in
      let plus = part 1 and minus = part (-1) in
      (match (plus, minus) with
      | Some _, Some _ -> (
          match Geom.clip_line_to_convex paper_axis f.paper with
          | Some (a, b) -> edge_seeds := (fi, a, b) :: !edge_seeds
          | None -> ())
      | _ -> ());
      List.iter
        (function Some fc -> out := (fc, fi) :: !out | None -> ())
        [ plus; minus ])
    st.faces;
  let arr = Array.of_list (List.rev !out) in
  let faces = Array.map fst arr in
  let parent = Array.map snd arr in
  let children_of fi =
    let acc = ref [] in
    Array.iteri (fun k p -> if p = fi then acc := k :: !acc) parent;
    List.rev !acc
  in
  let new_edges =
    List.rev_map
      (fun (fi, a, b) ->
        let left, right =
          match children_of fi with
          | l :: r :: _ -> (l, r)
          | [ l ] -> (l, -1)
          | [] -> (-1, -1)
        in
        { ea = a; eb = b; left; right; eassign = F; eintent = intent;
          crease_id = cid; eprov = prov })
      !edge_seeds
  in
  let child_on p s =
    if p < 0 then -1
    else
      match children_of p with
      | [ c ] -> c
      | c_plus :: c_minus :: _ -> if s >= 0 then c_plus else c_minus
      | [] -> -1
  in
  let carried =
    List.concat_map
      (fun e ->
        let sa = Geom.side_of_line paper_axis e.ea
        and sb = Geom.side_of_line paper_axis e.eb in
        if sa * sb >= 0 then
          let s = if sa <> 0 then sa else sb in
          [ { e with left = child_on e.left s; right = child_on e.right s } ]
        else
          let p =
            match Geom.intersection paper_axis (Geom.line_through e.ea e.eb) with
            | Some r -> r
            | None -> e.ea
          in
          [
            { e with eb = p; left = child_on e.left sa; right = child_on e.right sa };
            { e with ea = p; left = child_on e.left sb; right = child_on e.right sb };
          ])
      (Array.to_list st.edges)
  in
  let edges = Array.of_list (new_edges @ carried) in
  let order =
    build_order faces (fun i j -> Layer_order.get st.order parent.(i) parent.(j))
  in
  { faces; order; edges; marks = st.marks }

(* Like [simple_fold] but on-axis edges get their derived mountain/valley from
   the orientation-parity rule. *)
let fold_with_records ?crease_id ?moving_parents (st : t) ~(axis : Geom.line)
    ~(move_side : int) ~(valley : bool) ~(prov : State.provenance option) : t
    =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  let refl = Isometry.reflect_across_line axis in
  let moves fi =
    match moving_parents with None -> true | Some m -> m.(fi)
  in
  let stay = ref [] and mov = ref [] in
  (* each elt: (child_face, parent_index) *)
  (* seeds: (parent_index, a, b, crease_id) — one per face cut by the axis; the
     two straddling children (one stationary, one moved) are the two [parent]
     entries equal to parent_index, told apart by [moved_flag] once the final
     face order is fixed *)
  let edge_seeds = ref [] in
  Array.iteri
    (fun fi f ->
      if not (moves fi) then stay := (f, fi) :: !stay
      else begin
        let table = Array.map (Isometry.apply_point f.iso) f.paper in
        let inv = Isometry.inverse f.iso in
        let part keep iso =
          let sub = Geom.clip_convex_halfplane axis keep table in
          if Array.length sub >= 3 then
            Some { paper = Array.map (Isometry.apply_point inv) sub; iso }
          else None
        in
        let s = part (-move_side) f.iso in
        let m = part move_side (Isometry.compose refl f.iso) in
        let assign_of () = if valley <> (Isometry.det_sign f.iso < 0) then V else M in
        (match (s, m) with
        | Some _, Some _ -> (
            match axis_segment_in_face f axis with
            | Some (a, b) ->
                edge_seeds := (fi, a, b, assign_of (), cid) :: !edge_seeds
            | None -> ())
        | _ -> ());
        (match s with Some face -> stay := (face, fi) :: !stay | None -> ());
        match m with Some face -> mov := (face, fi) :: !mov | None -> ()
      end)
    st.faces;
  let stationary = List.rev !stay in
  let moved = !mov in
  (* keep the existing face-append order so fold_emit stays stable until Task 3 *)
  let ordered = if valley then stationary @ moved else moved @ stationary in
  let arr = Array.of_list ordered in
  let faces = Array.map fst arr in
  let parent = Array.map snd arr in
  (* a child is "moved" iff it came from the [mov] list; recover by membership *)
  let n_stay = List.length stationary in
  let moved_flag =
    if valley then Array.init (Array.length arr) (fun i -> i >= n_stay)
    else Array.init (Array.length arr) (fun i -> i < List.length moved)
  in
  let rel_of i j =
    let pi = parent.(i) and pj = parent.(j) in
    match (moved_flag.(i), moved_flag.(j)) with
    | false, false -> Layer_order.get st.order pi pj (* stationary vs stationary: preserved *)
    | true, true -> negate (Layer_order.get st.order pi pj) (* moved vs moved: reversed *)
    | true, false -> if valley then Above else Below (* moved i over/under stationary j *)
    | false, true -> if valley then Below else Above
  in
  (* left = the stationary child of a cut parent, right = its moved child *)
  let new_edges =
    List.rev_map
      (fun (fi, a, b, ea_assign, cid) ->
        let stationary_child = ref (-1) and moved_child = ref (-1) in
        Array.iteri
          (fun k p ->
            if p = fi then
              if moved_flag.(k) then moved_child := k else stationary_child := k)
          parent;
        {
          ea = a;
          eb = b;
          left = !stationary_child;
          right = !moved_child;
          eassign = ea_assign;
          eintent = ea_assign;
          crease_id = cid;
          eprov = prov;
        })
      !edge_seeds
  in
  (* the child of parent [p] on side [s] of [axis]: the moved child sits on
     [move_side], the stationary child on [-move_side]; an uncut face has a
     single child returned for either side. *)
  let child_on p s =
    if p < 0 then -1
    else begin
      let sc = ref (-1) and mc = ref (-1) in
      Array.iteri
        (fun k pp ->
          if pp = p then if moved_flag.(k) then mc := k else sc := k)
        parent;
      if s = move_side then if !mc >= 0 then !mc else !sc
      else if !sc >= 0 then !sc
      else !mc
    end
  in
  (* the fold's live M/V from a parent face's orientation parity (#27: this
     supersedes the stale F minted when a precrease was first scored) *)
  let assign_of_parent p =
    if valley <> (Isometry.det_sign st.faces.(p).iso < 0) then V else M
  in
  let has_moved_child p =
    let r = ref false in
    Array.iteri (fun k pp -> if pp = p && moved_flag.(k) then r := true) parent;
    !r
  in
  let carried =
    List.concat_map
      (fun e ->
        let iso_l = st.faces.(e.left).iso in
        let a = Isometry.apply_point iso_l e.ea in
        let b = Isometry.apply_point iso_l e.eb in
        let sa = Geom.side_of_line axis a and sb = Geom.side_of_line axis b in
        if sa = 0 && sb = 0 then begin
          (* the edge lies on the fold axis: this precrease is being folded now.
             Neither incident face is cut, so each maps to its single child; the
             assignment upgrades to the moving side's live M/V — but only if
             something incident actually moved (scoped folds can leave an
             on-axis precrease untouched, keeping its F). *)
          let moving_face =
            if has_moved_child e.left then Some e.left
            else if e.right >= 0 && has_moved_child e.right then Some e.right
            else None
          in
          match moving_face with
          | Some mf ->
              [
                {
                  e with
                  left = child_on e.left sa;
                  right = child_on e.right sa;
                  eassign = assign_of_parent mf;
                  eintent = assign_of_parent mf;
                };
              ]
          | None ->
              [ { e with left = child_on e.left sa; right = child_on e.right sa } ]
        end
        else if sa * sb >= 0 then
          let s = if sa <> 0 then sa else sb in
          [ { e with left = child_on e.left s; right = child_on e.right s } ]
        else
          let p =
            match Geom.intersection axis (Geom.line_through a b) with
            | Some r -> Isometry.apply_point (Isometry.inverse iso_l) r
            | None -> e.ea
          in
          [
            { e with eb = p; left = child_on e.left sa; right = child_on e.right sa };
            { e with ea = p; left = child_on e.left sb; right = child_on e.right sb };
          ])
      (Array.to_list st.edges)
  in
  let edges = Array.of_list (new_edges @ carried) in
  let order = build_order faces rel_of in
  let st' = { faces; order; edges; marks = st.marks } in
  (match validity_error st' with
  | Some msg ->
      let span =
        match prov with
        | Some p -> p.State.span
        | None -> (Lexing.dummy_pos, Lexing.dummy_pos)
      in
      Error.fail span msg
  | None -> ());
  st'

(* Distinct paper coordinates whose current table position is [tp] (one per
   overlapping layer covering that table point). *)
let paper_preimages (st : t) (tp : Geom.point) : Geom.point list =
  let acc = ref [] in
  Array.iter
    (fun f ->
      let pp = Isometry.apply_point (Isometry.inverse f.iso) tp in
      if
        Geom.in_convex_polygon f.paper pp
        && not (List.exists (Geom.point_equal pp) !acc)
      then acc := pp :: !acc)
    st.faces;
  List.rev !acc

(* Material point [pp] lies on the sheet: the faces partition the paper, so
   one of their paper polygons contains it (boundary counts). *)
let on_paper (st : t) (pp : Geom.point) : bool =
  Array.exists (fun f -> Geom.in_convex_polygon f.paper pp) st.faces

(* simple flat fold: reflect every layer-part on [move_side] of [axis] across it,
   then restack. valley → moved parts (reversed) on top; mountain → underneath. *)
let simple_fold (st : t) ~(axis : Geom.line) ~(move_side : int) ~(valley : bool)
    : t =
  fold_with_records st ~axis ~move_side ~valley ~prov:None

(* Turn the whole sheet over. Reflect every face across the footprint's vertical
   centerline (x = (minX+maxX)/2 over all face table vertices) — an internal,
   cosmetic axis: which line is irrelevant to the user (named points), only the
   substantive effect matters. The reflection flips each face's det_sign
   (front<->back); reversing the face array turns the stack top<->bottom. *)
let flip (st : t) : t =
  let n = Array.length st.faces in
  if n = 0 then st
  else begin
    let p0 = (table_polygon st 0).(0) in
    let lo = ref p0.Geom.x and hi = ref p0.Geom.x in
    Array.iteri
      (fun i _ ->
        Array.iter
          (fun (q : Geom.point) ->
            if Num.compare q.Geom.x !lo < 0 then lo := q.Geom.x;
            if Num.compare q.Geom.x !hi > 0 then hi := q.Geom.x)
          (table_polygon st i))
      st.faces;
    let cx = Num.div (Num.add !lo !hi) (Num.of_int 2) in
    let axis = { Geom.a = Num.one; b = Num.zero; c = cx } in
    let refl = Isometry.reflect_across_line axis in
    let flipped =
      Array.map (fun f -> { f with iso = Isometry.compose refl f.iso }) st.faces
    in
    let rev = Array.init n (fun i -> flipped.(n - 1 - i)) in
    let order = Layer_order.flip st.order n in
    let edges =
      Array.map
        (fun e ->
          {
            e with
            left = n - 1 - e.left;
            right = (if e.right >= 0 then n - 1 - e.right else -1);
          })
        st.edges
    in
    { faces = rev; order; edges; marks = st.marks }
  end
