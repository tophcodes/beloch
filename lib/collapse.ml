(** Single-vertex collapse: fold along n >= 4 material crease segments sharing
    one interior endpoint O — the flat end state of a multi-crease move
    (rabbit ear [hull2020, Thm 8.5]). Skips the 3D intermediate entirely:
    checks the end state exists (reflection closure = Kawasaki, Maekawa),
    assigns per-sector isometries, enumerates valid layer orders. *)

type elem = { cid : int; ea : Geom.point; eb : Geom.point; valley : bool }

(* --- error strings: spec §Errors table, verbatim ------------------------- *)
let e_no_vertex = "no common interior vertex"
let e_count = "count (hint: use `fold` for n = 2)"
let e_midpaper = "crease ends inside the sheet"
let e_kawasaki = "vertex not flat-foldable (angles)"
let e_maekawa = "Maekawa violated by the stated assignment"
let e_selfint = "assignment forces self-intersection"
let e_contra = "contradictory `over`"
let e_dup_ray = "duplicate ray in collapse"
let e_ambig k = Printf.sprintf "ambiguous stacking (%d orders)" k
let e_out_of_paper =
  "collapse folds a flap off the paper (no seating keeps it in the sheet)"

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

(* --- boundary predicates (unit-square paper) ------------------------------ *)

let on_unit_boundary (p : Geom.point) : bool =
  Geom.in_unit_square p
  && (Num.sign p.Geom.x = 0
     || Num.compare p.Geom.x Num.one = 0
     || Num.sign p.Geom.y = 0
     || Num.compare p.Geom.y Num.one = 0)

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

(* --- the kernel: single-vertex collapse on the hinge-graph core (Plan 3b
   Task 5, issue #48; the old flat-record kernel this superseded was deleted
   in Plan 3c Task 6). Hinge angles and a total face rank are set directly;
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

let collapse (g : Fold_state.t) (es : elem list)
    ~(over : (int * int) list) : (Fold_state.t, string) result =
  let n = List.length es in
  match common_vertex es with
  | None -> Error e_no_vertex
  | Some o when not (strictly_interior o) -> Error e_no_vertex
  | Some o ->
      if n < 4 || n mod 2 = 1 then Error e_count
      else if List.exists (fun e -> not (on_unit_boundary (far_of o e))) es then
        Error e_midpaper
      else begin
        let rays = Array.of_list (sort_ccw o es) in
        if has_duplicate_ray o rays then Error e_dup_ray
        else if not (closure_ok o rays) then Error e_kawasaki
        else begin
          let nm = List.length (List.filter (fun e -> not e.valley) es) in
          let nv = n - nm in
          if abs (nm - nv) <> 2 then Error e_maekawa
          else begin
            let tsec = sector_isometries o rays in
            let faces = Fold_state.faces g in
            let nf = Array.length faces in
            (* sector of each face (fixed, independent of stacking) *)
            let sec =
              Array.init nf (fun i ->
                  sector_of_poly o rays (faces.(i), Fold_state.face_iso2 g i))
            in
            (* a representative pre-collapse 2D placement per sector, feeding
               [effective_valley] exactly as in [collapse] *)
            let sector_iso = Array.make n Isometry.identity in
            let sector_seen = Array.make n false in
            for i = 0 to nf - 1 do
              let s = sec.(i) in
              if not sector_seen.(s) then begin
                sector_seen.(s) <- true;
                sector_iso.(s) <- Fold_state.face_iso2 g i
              end
            done;
            (* hinge constraints, verbatim *)
            let constraints =
              List.init n (fun j ->
                  let l = (j - 1 + n) mod n in
                  let _, e = rays.(j) in
                  let eff = effective_valley e.valley tsec.(l) sector_iso.(l) in
                  if eff then (j, l) else (l, j))
            in
            let stackings = linear_extensions n constraints in
            let eff_of_ray j =
              let l = (j - 1 + n) mod n in
              let _, e = rays.(j) in
              effective_valley e.valley tsec.(l) sector_iso.(l)
            in
            let ray_assign =
              Array.init n (fun j ->
                  if eff_of_ray j then Fold_state.V else Fold_state.M)
            in
            (* new hinges: every hinge whose crease matches a ray gets angle 1
               + the ray's derived letter; others are carried unchanged *)
            let old_hinges = Fold_state.hinges g in
            let new_hinges =
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
                  match !hit with
                  | Some j ->
                      { h with Fold_state.angle = Num.one; intent = ray_assign.(j) }
                  | None -> h)
                old_hinges
            in
            let marks = Fold_state.marks g in
            (* total face rank from a sector stacking: sort by
               (srank.(sector), intra-sector order), tiebreak by index (never
               fires — g's rank is a permutation, so distinct within a sector,
               and srank is a permutation over sectors). *)
            let g_rank = Fold_state.rank g in
            let intra i =
              if Isometry.det_sign tsec.(sec.(i)) > 0 then g_rank.(i)
              else - g_rank.(i)
            in
            let build_face_rank (srank : int array) : int array =
              let idx = Array.init nf Fun.id in
              Array.sort
                (fun i j ->
                  compare
                    (srank.(sec.(i)), intra i, i)
                    (srank.(sec.(j)), intra j, j))
                idx;
              let rank = Array.make nf 0 in
              Array.iteri (fun h i -> rank.(i) <- h) idx;
              rank
            in
            let candidate_at ~root ~base rank =
              Fold_state.make ~base ~marks ~faces ~hinges:new_hinges ~root ~rank ()
            in
            (* Simplification (binding, per the task-5 brief): validity is
               rigid-motion invariant, so filtering may anchor at ANY proper
               (orientation-preserving) sector's representative face — the
               Kawasaki closure already checked guarantees [make]'s cycle
               closure holds regardless of which one. *)
            let rep =
              let found = ref (-1) in
              for i = 0 to nf - 1 do
                if !found < 0 && Isometry.det_sign tsec.(sec.(i)) > 0 then
                  found := i
              done;
              if !found < 0 then
                invalid_arg
                  "Collapse.collapse: no orientation-preserving sector \
                   (unreachable — sector parities alternate around O)";
              !found
            in
            let valid_srank =
              List.filter
                (fun srank ->
                  match
                    candidate_at ~root:rep ~base:(Fold_state.face_iso g rep)
                      (build_face_rank srank)
                  with
                  | Ok _ -> true
                  | Error _ -> false)
                stackings
            in
            if valid_srank = [] then Error e_selfint
            else begin
              (* over filter at the sector level, BEFORE face-rank expansion
                 (matches old order: valid -> over -> dedup) *)
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
                (* placements do not depend on rank, so any surviving
                   candidate's flat projections give the overlap set once *)
                let sample =
                  match
                    candidate_at ~root:rep ~base:(Fold_state.face_iso g rep)
                      (build_face_rank (List.hd filtered))
                  with
                  | Ok c -> c
                  | Error _ -> assert false
                in
                let overlaps =
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
                let signature fr =
                  List.map (fun (i, j) -> (i, j, fr.(i) > fr.(j))) overlaps
                in
                let distinct =
                  List.fold_left
                    (fun acc srank ->
                      let fr = build_face_rank srank in
                      let s = signature fr in
                      if List.exists (fun (s', _, _) -> s' = s) acc then acc
                      else (s, srank, fr) :: acc)
                    [] filtered
                in
                match distinct with
                | [] -> Error e_selfint (* unreachable: filtered <> [] *)
                | _ :: _ :: _ -> Error (e_ambig (List.length distinct))
                | [ (_, srank, fr) ] ->
                    (* anchor: proper sectors ascending by srank; prefer the
                       lowest, else the first in-bounds one (old preference
                       order — see [collapse]'s doc comment for the rationale) *)
                    let proper =
                      List.filter
                        (fun s -> Isometry.det_sign tsec.(s) > 0)
                        (List.init n Fun.id)
                      |> List.sort (fun a b -> compare srank.(a) srank.(b))
                    in
                    let first_face_in_sector bb =
                      let found = ref (-1) in
                      for i = 0 to nf - 1 do
                        if !found < 0 && sec.(i) = bb then found := i
                      done;
                      if !found < 0 then
                        invalid_arg
                          (Printf.sprintf
                             "Collapse.collapse: sector %d has no faces \
                              (unreachable — every sector holds >= 1 face)"
                             bb);
                      !found
                    in
                    let candidate_for bb =
                      let root_bb = first_face_in_sector bb in
                      candidate_at ~root:root_bb
                        ~base:(Fold_state.face_iso g root_bb) fr
                    in
                    let in_bounds gg =
                      let nfg = Array.length (Fold_state.faces gg) in
                      let ok = ref true in
                      for i = 0 to nfg - 1 do
                        if
                          not
                            (Array.for_all Geom.in_unit_square
                               (Fold_state.table_polygon gg i))
                        then ok := false
                      done;
                      !ok
                    in
                    let rec pick = function
                      | [] -> Error e_out_of_paper
                      | bb :: rest -> (
                          match candidate_for bb with
                          | Ok gg when in_bounds gg -> Ok gg
                          | _ -> pick rest)
                    in
                    pick proper
              end
            end
          end
        end
      end
