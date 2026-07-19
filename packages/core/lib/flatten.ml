(** flatten V2: one solver pipeline (spec 2026-07-16-flatten-derive-v2-design.md
    "The model"). Given a set of material creases ("rays") sharing one interior
    vertex O, an ODD ray count means one emergent ray is part of the solution
    space; [candidates] is the pure GENERATOR of the geometric completions that
    could close the vertex — same-direction filter, per-line dedup, two-tier
    (`LineNew`/`OppositeRay`) preference tag [364660f]. It does NOT check
    feasibility or M/V and does NOT pick a winner: the caller (lib/eval.ml)
    enumerates every Maekawa-consistent M/V pattern ([mv_patterns], pure and
    unit-testable) over each candidate's full ray set, tries each via
    [Collapse.collapse_all], pools the results, and disambiguates by tier then
    by `{toward}`'s moved-material-centroid score. This supersedes the old
    [derive], which bundled feasibility-filtering and `toward`-selection into
    this module; both now live in the caller because they need
    [Collapse.collapse_all] (Task 2) and [Ast.mv_constraint] (Task 1), neither
    of which this module should depend on beyond the generator's own
    geometry. *)

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

(* The candidate GENERATOR (spec step 1's odd branch): every geometric
   completion of the given rays that closes Kawasaki at [o], tagged by the
   two-tier preference [364660f] (§4.9: the emergent crease is "not
   constructible by any Huzita axiom" — a completion that only re-uses a
   given line's far side is the degenerate, `OppositeRay` case; a completion
   on a genuinely new line is `LineNew`). No feasibility check and no
   [toward] selection — both are the caller's job now, over the pooled
   realizations of every (candidate x M/V pattern). *)
let candidates (o : Geom.point) ~(fixed : (Geom.point * Collapse.elem) list) :
    (Geom.line * Geom.point * [ `LineNew | `OppositeRay ]) list =
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
     eigenvector's sign, which is arbitrary. *)
  let raw = ref [] in
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
      | Some r -> raw := (Geom.line_through o r, r) :: !raw
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
     genuinely new crease — so this filters by direction, not by line
     ([Geom.ccw_compare] = 0 iff same direction from O). *)
  let genuine (_, ray) =
    not (Array.exists (fun (far, _) -> Geom.ccw_compare ~center:o far ray = 0) sorted)
  in
  let uniq =
    List.fold_left
      (fun acc (l, r) ->
        if (not (genuine (l, r))) || List.exists (fun (l', _) -> same l l') acc
        then acc
        else (l, r) :: acc)
      [] !raw
  in
  let given_lines =
    Array.to_list (Array.map (fun (far, _) -> Geom.line_through o far) sorted)
  in
  let line_new (l, _) =
    not (List.exists (fun g -> Geom.parallel l g) given_lines)
  in
  List.map
    (fun (l, r) -> (l, r, if line_new (l, r) then `LineNew else `OppositeRay))
    uniq

(* Pure, unit-testable Maekawa-consistent M/V pattern enumerator (spec step
   3): given a per-ray constraint list, every [bool list] (parallel to the
   input, true = valley) honoring every pinned slot (`MvValley` -> true,
   `MvMountain` -> false) and satisfying Maekawa (|#M - #V| = 2) over the
   free slots. [] if no assignment satisfies both. *)
let mv_patterns (constraints : Ast.mv_constraint list) : bool list list =
  let n = List.length constraints in
  let base = Array.make n false in
  let free_idx = ref [] in
  List.iteri
    (fun i (c : Ast.mv_constraint) ->
      match c with
      | Ast.MvValley -> base.(i) <- true
      | Ast.MvMountain -> base.(i) <- false
      | Ast.MvFree -> free_idx := i :: !free_idx)
    constraints;
  let free_idx = List.rev !free_idx in
  let rec free_combos = function
    | [] -> [ [] ]
    | _ :: rest -> List.concat_map (fun t -> [ true :: t; false :: t ]) (free_combos rest)
  in
  free_combos free_idx
  |> List.filter_map (fun combo ->
         let arr = Array.copy base in
         List.iter2 (fun i v -> arr.(i) <- v) free_idx combo;
         let lst = Array.to_list arr in
         let nv = List.length (List.filter (fun v -> v) lst) in
         let nm = n - nv in
         if abs (nm - nv) = 2 then Some lst else None)
