(** Derive-mode `flatten`: given an ODD set of material creases ("rays")
    sharing one interior vertex O, solve for the missing ("emergent") crease
    that completes the vertex to a flat-foldable arrangement — the rabbit-ear
    move [hull2020, Thm 8.5]. Verified single-insertion case in
    tests/spike_flatten.ml: for k given rays with reflections R_0..R_{k-1}
    (CCW order), splitting at gap j into `before` = R_0∘…∘R_{j-1} and `after`
    = R_j∘…∘R_{k-1}, the reflection R_ear = before^-1 ∘ after^-1 is exactly the
    one whose insertion at position j makes the full closure product the
    identity (Kawasaki). This module generalises that single insertion to
    every gap, keeping only the candidates whose axis genuinely falls in
    their own gap, and disambiguates remaining candidates by which side of
    the axis [toward] lands on. *)

let e_infeasible = "vertex not flat-foldable toward that side"

let e_toward_ambiguous =
  "`toward` does not pick a side — the point is collinear with a crease through \
   the vertex; aim it off the creases"

(* The +1-eigenvector direction of a reflection's linear part. A reflection
   fixing the origin is a symmetric orthogonal matrix (m01 = m10), so either
   off-diagonal entry gives the eigenvector directly; a zero off-diagonal
   means the matrix is already diagonal (axis along a coordinate direction). *)
let axis_direction (r : Isometry.t) : Num.t * Num.t =
  if Num.sign r.Isometry.m01 <> 0 then
    (r.Isometry.m01, Num.sub Num.one r.Isometry.m00)
  else if Num.sign (Num.sub r.Isometry.m00 Num.one) = 0 then (Num.one, Num.zero)
  else (Num.zero, Num.one)

(* Does point [q] (read as a direction from [o]) lie strictly between rays
   [lo] and [hi] going CCW from [lo] to [hi]? [lo]/[hi] are consecutive rays
   in a CCW-sorted array, so exactly one cyclic pair — the array's own seam —
   has [lo] sorting *after* [hi]; that is the wraparound gap, handled by the
   "or" branch instead of the ordinary "and" (Geom.ccw_compare's linear order
   has one cut, at the positive-x direction). *)
let in_gap (o : Geom.point) (lo : Geom.point) (hi : Geom.point) (q : Geom.point)
    : bool =
  if Geom.ccw_compare ~center:o lo hi < 0 then
    Geom.ccw_compare ~center:o lo q < 0 && Geom.ccw_compare ~center:o q hi < 0
  else
    Geom.ccw_compare ~center:o lo q < 0 || Geom.ccw_compare ~center:o q hi < 0

let derive (o : Geom.point) ~(fixed : (Geom.point * Collapse.elem) list)
    ~(toward : Geom.point) : (Geom.line, string) result =
  let sorted = Array.of_list (Collapse.sort_ccw o (List.map snd fixed)) in
  let k = Array.length sorted in
  let refl i =
    let far, _ = sorted.(i) in
    Isometry.reflect_across_line (Geom.line_through o far)
  in
  let compose_range lo hi =
    (* R_lo ∘ R_(lo+1) ∘ … ∘ R_(hi-1), identity if lo >= hi *)
    let acc = ref Isometry.identity in
    for i = lo to hi - 1 do
      acc := Isometry.compose !acc (refl i)
    done;
    !acc
  in
  (* Each candidate carries its emergent LINE *and* the actual emergent RAY
     endpoint (the axis end that lands in its own gap). The ray direction is
     geometrically fixed — chosen by [in_gap], a CCW test — unlike the
     eigenvector's sign, which is arbitrary; so [toward] can select on the ray
     rather than on the line's (arbitrarily-oriented) side. *)
  let candidates = ref [] in
  for j = 0 to k - 1 do
    let before = compose_range 0 j in
    let after = compose_range j k in
    let cand =
      Isometry.compose (Isometry.inverse before) (Isometry.inverse after)
    in
    if
      Isometry.det_sign cand < 0
      && Geom.point_equal (Isometry.apply_point cand o) o
    then begin
      let dx, dy = axis_direction cand in
      let plus = { Geom.x = Num.add o.Geom.x dx; y = Num.add o.Geom.y dy } in
      let minus = { Geom.x = Num.sub o.Geom.x dx; y = Num.sub o.Geom.y dy } in
      let lo_far, _ = sorted.((j - 1 + k) mod k) in
      let hi_far, _ = sorted.(j mod k) in
      let ray =
        if in_gap o lo_far hi_far plus then Some plus
        else if in_gap o lo_far hi_far minus then Some minus
        else None
      in
      match ray with
      | Some r -> candidates := (Geom.line_through o r, r) :: !candidates
      | None -> ()
    end
  done;
  (* Dedup coincident candidates by LINE: the same emergent axis can close two
     different gaps (both its rays fill a gap), landing twice. Two lines
     coincide iff parallel and one shares the other's point. *)
  let same (l1 : Geom.line) (l2 : Geom.line) =
    Geom.parallel l1 l2
    && Num.sign
         (Num.sub (Num.mul l1.Geom.a l2.Geom.c) (Num.mul l2.Geom.a l1.Geom.c)) = 0
    && Num.sign
         (Num.sub (Num.mul l1.Geom.b l2.Geom.c) (Num.mul l2.Geom.b l1.Geom.c)) = 0
  in
  (* Drop candidates collinear with a GIVEN ray: those are the degenerate
     "extend a line already drawn" completions (e.g. the spine's own axis), not
     the genuine emergent crease. All lines pass through O, so parallel ⟹
     coincident. *)
  let given_lines =
    Array.to_list
      (Array.map (fun (far, _) -> Geom.line_through o far) sorted)
  in
  let genuine (l, _) = not (List.exists (fun g -> Geom.parallel l g) given_lines) in
  let uniq =
    List.fold_left
      (fun acc (l, r) ->
        if (not (genuine (l, r))) || List.exists (fun (l', _) -> same l l') acc
        then acc
        else (l, r) :: acc)
      [] !candidates
  in
  match uniq with
  | [] -> Error e_infeasible
  | [ (l, _) ] -> Ok l
  | cands ->
      (* [toward] selects the completion whose emergent RAY points toward that
         point: maximise (ray − O)·(toward − O). Exact and orientation-free —
         `toward .c` (right corner) yields the right-swinging crease. If the top
         two candidates TIE (equal dot), [toward] fails to pick a side — it lies
         along a crease through the vertex (the candidates are mirror-symmetric
         about it), so reject rather than choose arbitrarily. *)
      let dot (_, r) =
        Num.add
          (Num.mul
             (Num.sub r.Geom.x o.Geom.x)
             (Num.sub toward.Geom.x o.Geom.x))
          (Num.mul
             (Num.sub r.Geom.y o.Geom.y)
             (Num.sub toward.Geom.y o.Geom.y))
      in
      let scored =
        List.map (fun c -> (dot c, fst c)) cands
        |> List.sort (fun (d1, _) (d2, _) -> Num.compare d2 d1)
      in
      match scored with
      | (d0, _) :: (d1, _) :: _ when Num.compare d0 d1 = 0 ->
          Error e_toward_ambiguous
      | (_, l) :: _ -> Ok l
      | [] -> Error e_infeasible
