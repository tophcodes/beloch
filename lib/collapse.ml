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
   [Fold_state.fold_with_records]: a stored/effective valley is the user's
   valley XORed with the parity of the stayer face's *final* orientation —
   [sec_transform ∘ face_iso]. Folding in [face_iso] (not just the sector
   transform) is what makes a prior `flip` invert M/V relative to the original
   front (spec §4.7): every pre-collapse face is orientation-reversed, so every
   effective valley flips. Shared by the hinge-constraint and eassign sites. *)
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

(* 4. sector membership of a face. Interior representative = vertex average
   (convex ⇒ interior), placed on the table via the face iso. After closure
   every sector angle < π, so p is in sector k iff (p−O) is strictly CCW of ray
   k and strictly CW of ray k+1. Faces were subdivided along every ray, so a
   representative is never exactly on a ray (asserted). *)
let sector_of (o : Geom.point) (rays : (Geom.point * 'a) array)
    (f : Fold_state.face) : int =
  let n = Array.length rays in
  let sumx = ref Num.zero and sumy = ref Num.zero in
  Array.iter
    (fun (p : Geom.point) ->
      let tp = Isometry.apply_point f.Fold_state.iso p in
      sumx := Num.add !sumx tp.Geom.x;
      sumy := Num.add !sumy tp.Geom.y)
    f.Fold_state.paper;
  let m = Num.of_int (Array.length f.Fold_state.paper) in
  let rep = { Geom.x = Num.div !sumx m; y = Num.div !sumy m } in
  let ocoord = (o.Geom.x, o.Geom.y) in
  let repc = (rep.Geom.x, rep.Geom.y) in
  let found = ref (-1) in
  for k = 0 to n - 1 do
    let rk, _ = rays.(k) and rk1, _ = rays.((k + 1) mod n) in
    let c0 = cross ocoord (rk.Geom.x, rk.Geom.y) repc in
    let c1 = cross ocoord (rk1.Geom.x, rk1.Geom.y) repc in
    (* strictly CCW of rk: cross(rk, rep) > 0; strictly CW of rk1:
       cross(rk1, rep) < 0 *)
    if Num.sign c0 > 0 && Num.sign c1 < 0 then found := k
  done;
  if !found < 0 then
    invalid_arg "Collapse.sector_of: representative not strictly inside a sector";
  !found

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

(* --- the kernel ----------------------------------------------------------- *)

let collapse (st : Fold_state.t) (es : elem list) ~(over : (int * int) list) :
    (Fold_state.t, string) result =
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
            (* sector of each face (fixed, independent of stacking) *)
            let sec =
              Array.map (fun f -> sector_of o rays f) st.Fold_state.faces
            in
            (* a representative pre-collapse face iso per sector — its
               orientation (front-up vs flipped) feeds the parity helper so a
               prior `flip` inverts M/V. All layers of a sector share one
               orientation in the states collapse accepts (single-layer or a
               uniformly-flipped stack). *)
            let sector_iso = Array.make n Isometry.identity in
            let sector_seen = Array.make n false in
            Array.iteri
              (fun i (f : Fold_state.face) ->
                let s = sec.(i) in
                if not sector_seen.(s) then begin
                  sector_seen.(s) <- true;
                  sector_iso.(s) <- f.Fold_state.iso
                end)
              st.Fold_state.faces;
            (* folded faces: iso' = T_sector ∘ f.iso (fixed for all stackings) *)
            let folded =
              Array.mapi
                (fun i (f : Fold_state.face) ->
                  {
                    Fold_state.paper = f.Fold_state.paper;
                    iso = Isometry.compose tsec.(sec.(i)) f.Fold_state.iso;
                  })
                st.Fold_state.faces
            in
            (* hinge constraints. Crease at ray j separates left sector
               l=(j-1) and right sector j. effective_valley accounts for the
               left sector's placement parity (fold_with_records convention).
               effective_valley ⇒ sector j Above sector l; else Below. *)
            let constraints =
              List.init n (fun j ->
                  let l = (j - 1 + n) mod n in
                  let _, e = rays.(j) in
                  let eff = effective_valley e.valley tsec.(l) sector_iso.(l) in
                  if eff then (j, l) else (l, j))
            in
            let stackings = linear_extensions n constraints in
            (* build a candidate face-order relation for a rank array *)
            let rel_of rank i j =
              let si = sec.(i) and sj = sec.(j) in
              if si = sj then
                let base = Layer_order.get st.Fold_state.order i j in
                if Isometry.det_sign tsec.(si) < 0 then Layer_order.negate base
                else base
              else if rank.(si) > rank.(sj) then Layer_order.Above
              else Layer_order.Below
            in
            let valid =
              List.filter
                (fun rank ->
                  let order = Fold_state.build_order folded (rel_of rank) in
                  let cand =
                    {
                      Fold_state.faces = folded;
                      order;
                      edges = st.Fold_state.edges;
                      marks = st.Fold_state.marks;
                    }
                  in
                  Fold_state.validity_error cand = None)
                stackings
            in
            if valid = [] then Error e_selfint
            else begin
              (* over filter: sector(upper) must be above sector(lower). Same
                 sector → no-op (silently consistent). *)
              let over_ok rank =
                List.for_all
                  (fun (up, lo) ->
                    let su = sec.(up) and sl = sec.(lo) in
                    su = sl || rank.(su) > rank.(sl))
                  over
              in
              let filtered = List.filter over_ok valid in
              if filtered = [] then Error e_contra
              else begin
                (* dedupe by observable signature: the Above/Below of every
                   overlapping face pair. Distinct signatures = distinct
                   solutions. *)
                let overlaps =
                  let n_f = Array.length folded in
                  let acc = ref [] in
                  for i = 0 to n_f - 1 do
                    for j = i + 1 to n_f - 1 do
                      if
                        Geom.convex_overlap
                          (Fold_state.table_poly_of folded.(i))
                          (Fold_state.table_poly_of folded.(j))
                      then acc := (i, j) :: !acc
                    done
                  done;
                  List.rev !acc
                in
                let signature rank =
                  List.map
                    (fun (i, j) ->
                      (i, j, rel_of rank i j = Layer_order.Above))
                    overlaps
                in
                let distinct =
                  List.fold_left
                    (fun acc rank ->
                      let s = signature rank in
                      if List.exists (fun (s', _) -> s' = s) acc then acc
                      else (s, rank) :: acc)
                    [] filtered
                in
                match distinct with
                | [] -> Error e_selfint (* unreachable: filtered <> [] *)
                | _ :: _ :: _ -> Error (e_ambig (List.length distinct))
                | [ (_, rank) ] ->
                    (* normalize: the LOWEST-RANKED orientation-PRESERVING
                       sector keeps the identity (the lowest face-up sector
                       sits identity on the table). Sector parities alternate
                       around O (det tsec.(k) = (-1)^k), so a proper sector
                       always exists — sector 0 (identity) at worst. Anchoring
                       on a proper sector keeps tb_inv orientation-preserving,
                       so the emitted geometry is NOT the global M/V mirror of
                       the declared collapse (final-review C2). *)
                    let b = ref (-1) in
                    for s = 0 to n - 1 do
                      if
                        Isometry.det_sign tsec.(s) > 0
                        && (!b < 0 || rank.(s) < rank.(!b))
                      then b := s
                    done;
                    let tb_inv = Isometry.inverse tsec.(!b) in
                    let faces_final =
                      Array.mapi
                        (fun i (f : Fold_state.face) ->
                          {
                            Fold_state.paper = f.Fold_state.paper;
                            iso =
                              Isometry.compose tb_inv
                                (Isometry.compose tsec.(sec.(i))
                                   f.Fold_state.iso);
                          })
                        st.Fold_state.faces
                    in
                    (* eassign upgrade: each elem's ray edges get V/M by the
                       hinge parity. Segments of the same bundle beyond the
                       ray keep their mark. *)
                    let eff_of_ray j =
                      let l = (j - 1 + n) mod n in
                      let _, e = rays.(j) in
                      effective_valley e.valley tsec.(l) sector_iso.(l)
                    in
                    let ray_assign =
                      Array.init n (fun j ->
                          if eff_of_ray j then Fold_state.V else Fold_state.M)
                    in
                    let edges_final =
                      Array.map
                        (fun (e : Fold_state.edge) ->
                          if e.Fold_state.left < 0 then e
                          else
                          let iso_l =
                            st.Fold_state.faces.(e.Fold_state.left).Fold_state
                            .iso
                          in
                          let ta = Isometry.apply_point iso_l e.Fold_state.ea in
                          let tb = Isometry.apply_point iso_l e.Fold_state.eb in
                          let hit = ref None in
                          for j = 0 to n - 1 do
                            let far, elem = rays.(j) in
                            if
                              elem.cid = e.Fold_state.crease_id
                              && Geom.on_segment (o, far) ta
                              && Geom.on_segment (o, far) tb
                            then hit := Some j
                          done;
                          match !hit with
                          | Some j ->
                              { e with Fold_state.eassign = ray_assign.(j) }
                          | None -> e)
                        st.Fold_state.edges
                    in
                    let order =
                      Fold_state.build_order faces_final (rel_of rank)
                    in
                    Ok
                      {
                        Fold_state.faces = faces_final;
                        order;
                        edges = edges_final;
                        marks = st.Fold_state.marks;
                      }
              end
            end
          end
        end
      end
