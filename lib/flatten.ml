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
    their own gap, filters those down to the ones that are actually
    collapse-feasible (a caller-supplied oracle — Kawasaki-closing isn't
    enough; a candidate can still fold a flap off the paper), prefers
    line-new completions over opposite-ray reuses of a given line (see the
    two-tier comment in [derive]), and disambiguates the remaining
    candidates by which one's emergent ray [toward] points closest to. *)

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
    ~(feasible : Geom.line -> Geom.point -> bool) ~(toward : Geom.point) :
    (Geom.line * Geom.point, string) result =
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
  (* Drop candidates whose emergent RAY points in the same direction as a
     GIVEN ray: that is the degenerate "extend a line already drawn"
     completion. The OPPOSITE ray of a given line is NOT degenerate — it is a
     genuinely new crease (the fish-base vertex's emergent completion is
     exactly the spine's far side) — so this filters by direction, not by
     line: [Geom.ccw_compare] = 0 iff two points sit in the same half-plane
     AND are collinear with O, i.e. same direction from O (the same test
     [Collapse.has_duplicate_ray] uses). *)
  let genuine (_, ray) =
    not (Array.exists (fun (far, _) -> Geom.ccw_compare ~center:o far ray = 0) sorted)
  in
  let uniq =
    List.fold_left
      (fun acc (l, r) ->
        if (not (genuine (l, r))) || List.exists (fun (l', _) -> same l l') acc
        then acc
        else (l, r) :: acc)
      [] !candidates
  in
  (* Kawasaki-closing is necessary but not sufficient: a candidate can still
     be geometrically unrealisable (e.g. it forces a flap off the paper), so
     the caller's [feasible] oracle filters further before [toward] picks
     among what's actually left. *)
  let viable = List.filter (fun (l, r) -> feasible l r) uniq in
  (* Two-tier preference among the FEASIBLE candidates. §4.9 defines the
     emergent crease as "not constructible by any Huzita axiom — it exists
     only because flat-foldability forces it"; a completion that merely folds
     the far side of an already-given line is constructible (the line exists)
     and is therefore the DEGENERATE completion — admissible only when no
     genuinely new crease closes the vertex. So: tier 1 = LINE-NEW (the
     candidate's line is collinear with no given ray's line — all lines pass
     through O, so parallel ⟹ coincident); tier 2 = OPPOSITE-RAY (collinear
     with a given line; necessarily the opposite direction, since
     same-direction candidates were already dropped above). [toward] chooses
     among tier 1 whenever any tier-1 candidate survived feasibility; tier 2
     is the fallback iff tier 1 is empty AFTER feasibility — the fish-base
     vertex is exactly that case: both line-new candidates fold off the
     paper, and the spine's far side (tier 2) is the only physical
     completion, so any toward point picks it. *)
  let given_lines =
    Array.to_list (Array.map (fun (far, _) -> Geom.line_through o far) sorted)
  in
  let line_new (l, _) =
    not (List.exists (fun g -> Geom.parallel l g) given_lines)
  in
  let tier1, tier2 = List.partition line_new viable in
  let deciding = if tier1 <> [] then tier1 else tier2 in
  match deciding with
  | [] -> Error e_infeasible
  | [ (l, r) ] -> Ok (l, r)
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
        List.map (fun c -> (dot c, c)) cands
        |> List.sort (fun (d1, _) (d2, _) -> Num.compare d2 d1)
      in
      match scored with
      | (d0, _) :: (d1, _) :: _ when Num.compare d0 d1 = 0 ->
          Error e_toward_ambiguous
      | (_, (l, r)) :: _ -> Ok (l, r)
      | [] -> Error e_infeasible
