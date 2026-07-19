open Beloch

(* Task 4: `flatten` becomes bindable (`--r = flatten ...`), mirroring the
   `Fold`/`Mark` name slot. The bound name resolves to a selectable bundle of
   the given rays (validate mode) — the emergent-crease refinement of what
   the bundle contains is a later task. *)

let expect_error msg_substr thunk =
  try
    ignore (thunk ());
    Alcotest.fail ("expected error containing: " ^ msg_substr)
  with Error.Beloch_error (_, m) ->
    Alcotest.(check bool)
      ("error mentions " ^ msg_substr)
      true
      (try
         ignore (Str.search_forward (Str.regexp_string msg_substr) m 0);
         true
       with Not_found -> false)

(* same "+" vertex fixture as test_eval.ml's test_flatten_all_layers_ok:
   two full creases through the center, subdivided into 4 rays, flattened as
   one vertex. Here the flatten is bound to --r. *)
let vertex_src =
  "paper square\n\
   mark --h = map .a onto .d\n\
   mark --v = map .a onto .b\n\
   --r = flatten (--h & #[.b] mountain) (--v & #[.c]) (--h & #[.d] \
   mountain) (--v & #[.a] mountain)\n"

let test_flatten_bind_parses_and_evals () =
  let fd = Eval.eval_folded (Beloch.parse ~filename:"t.bel" vertex_src) in
  Alcotest.(check int) "vertex flatten still leaves 4 sector faces" 4
    (Array.length (Fold_state.faces fd.Eval.state))

(* the bound name occupies the crease namespace like any other bind: a
   second bind of the same name is rejected exactly like
   test_eval_dup_crease_error's `mark --x` / `mark --x`. This is the same
   "is this name bound" proof the rest of the suite uses (no dedicated
   Env/has_bundle accessor exists — bind_crease's own dup-check is it).
   Rebinding via a bundle expr (`[--h]`) rather than `mark`/axiom keeps this
   test purely about namespace occupancy: bind_crease's dup-check fires
   before any geometry is evaluated, so it can't be confused with an
   unrelated axiom error. *)
let test_flatten_bind_registers_name () =
  expect_error "already bound" (fun () ->
      Eval.eval_folded
        (Beloch.parse ~filename:"t.bel" (vertex_src ^ "--r = [--h]\n")))

(* the bound name resolves as a genuine selectable bundle, not a dead label:
   filtering it down to one of its constituent rays (crease & flap, same
   two-level selector shape the flatten's own elements used) and crossing
   two such rays with `*` exercises the same bundle_segments/resolve_line
   path a directly-named crease would, proving --r isn't special-cased or
   inert. (A single #[...] flap filter alone is ambiguous here — two of the
   four rays border the same sector face — so the crease selector narrows
   it the same way the flatten statement itself did.) *)
let test_flatten_bind_selects_ray () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         (vertex_src ^ ".z = --r & --h & #[.b] * --r & --v & #[.a]\n"))
  in
  Alcotest.(check bool) "z bound via bound-bundle selection" true
    (List.exists (fun (n, _, _) -> n = "z") fd.Eval.named_points)

(* unbound `flatten ...` (no name) must keep parsing — the name is optional,
   not required. *)
let test_flatten_unbound_still_parses () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          mark --h = map .a onto .d\n\
          mark --v = map .a onto .b\n\
          flatten (--h & #[.b] mountain) (--v & #[.c]) (--h & #[.d] \
          mountain) (--v & #[.a] mountain)\n")
  in
  Alcotest.(check int) "unbound flatten still leaves 4 sector faces" 4
    (Array.length (Fold_state.faces fd.Eval.state))

(* flatten V2 (spec 2026-07-16): ONE pipeline for both parities — an ODD ray
   count adds an emergent-ray candidate ([Flatten.candidates]); the solver
   enumerates Maekawa-consistent M/V patterns ([Flatten.mv_patterns]) through
   [Collapse.collapse_all] and `{toward}` selects among the pooled
   realizations by the three-stage rule (position class, min-mountain canon,
   rank dipole). *)

(* `\` (Drop) must be accepted inside a flatten item exactly like `&` (Keep)
   — both are ordinary line_operand LFilter productions, not new grammar;
   this is the "first verify" parse-only smoke check the task calls for. *)
let test_flatten_item_accepts_backslash_filter () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       mark --h = map .a onto .d\n\
       mark --v = map .a onto .b\n\
       flatten (--h \\ #[.b]) (--v & #[.c]) (--h & #[.d] mountain) (--v & \
       #[.a] mountain)\n"
  in
  match List.rev prog with
  | Ast.Flatten (None, elems, [], None, None, _) :: _ ->
      Alcotest.(check int) "4 elements" 4 (List.length elems)
  | _ -> Alcotest.fail "expected --h \\ #[.b] to parse as a flatten item"

(* Direct unit test of the candidate GENERATOR (V2: Flatten.candidates no
   longer picks a winner — that's the caller's job now, spec 2026-07-16) on
   the exact spike vertex V = (1/2, √5−2) with the ALL-`\` surface (rays
   pointing AWAY from the two base corners + the down-spine, fars ≈25.3°,
   ≈154.7°, 270°). This is the proven configuration of
   tests/spike_flatten.ml. Fed those three fars, [candidates] must include
   the GENUINE emergent swivel crease among its results — a line
   axiom-unconstructible from the three givens — the ≈320.55° line meeting
   the base near x≈0.787 (verified empirically: `Flatten.candidates` returns
   3 entries here — this one, its ≈219.45°-mirror, and the up-spine
   opposite-ray reuse — matching 364660f's "tier 1 = {320.5°, 219.5°}"
   finding; this test only pins down the GENUINE one's properties, not the
   full set). *)
let test_flatten_derive_unit () =
  let mk x y = { Geom.x; y } in
  let half = Num.of_q (Q.of_ints 1 2) in
  let s5 = Num.sqrt (Num.of_int 5) in
  let v = mk half (Num.sub s5 (Num.of_int 2)) in
  let a = mk Num.zero Num.zero
  and b = mk Num.one Num.zero
  and m = mk half Num.one in
  (* fars AWAY from each landmark = 2·V − landmark (opposite ray through V) *)
  let refl p =
    mk
      (Num.sub (Num.mul (Num.of_int 2) v.Geom.x) p.Geom.x)
      (Num.sub (Num.mul (Num.of_int 2) v.Geom.y) p.Geom.y)
  in
  let fa = refl a and fb = refl b and fm = refl m in
  let es =
    [
      { Collapse.cid = 0; ea = v; eb = fa; valley = true };
      { Collapse.cid = 1; ea = v; eb = fb; valley = true };
      { Collapse.cid = 2; ea = v; eb = fm; valley = true };
    ]
  in
  let fixed = Collapse.sort_ccw v es in
  let cands = Flatten.candidates v ~fixed in
  (* the four-ray vertex (a candidate + the three givens) is Kawasaki-flat iff
     the reflection product over the CCW-sorted rays is the identity — exactly
     one of a candidate's two ends closes (closure is order-sensitive), so try
     both; a genuine candidate must also be distinct from all three given
     lines (spine x=1/2, bisector-a, bisector-b). *)
  let spine = Geom.line_through v m
  and bis_a = Geom.line_through v a
  and bis_b = Geom.line_through v b in
  let closes far =
    let all =
      [ (far, ()); (fa, ()); (fb, ()); (fm, ()) ]
      |> List.sort (fun (p, _) (q, _) -> Geom.ccw_compare ~center:v p q)
      |> Array.of_list
    in
    Collapse.closure_ok v all
  in
  match
    List.find_opt
      (fun (l, r, _tag) ->
        Geom.side_of_line l v = 0
        && (not (Geom.parallel l spine))
        && (not (Geom.parallel l bis_a))
        && (not (Geom.parallel l bis_b))
        && closes r)
      cands
  with
  | None ->
      Alcotest.failf "no genuine emergent candidate found among %d"
        (List.length cands)
  | Some (l, _, _) ->
      (* approximate coordinates matching the spike: meets base y=0 at
         x ≈ 0.787, i.e. the ≈320.55° crease *)
      let base_x = Num.to_float (Num.div l.Geom.c l.Geom.a) in
      Alcotest.(check (float 0.001)) "meets base near x=0.787" 0.7869 base_x

(* the classic rabbit-ear vertex end-to-end: incenter O of triangle a/b/m,
   two angle bisectors + the down-spine as the three GIVEN rays, all in the
   ALL-`\` (away-from-corner) surface so the emergent crease is genuinely new
   (not collinear with a given ray). Proves the full parse→derive→materialize
   →collapse pipeline reaches a valid flat state AND leaves a real emergent
   crease distinct from every given ray. *)
let rabbit_ear_derive_src =
  "paper square\n\
   mark --v = map .a onto .b\n\
   .m = --v * --cd\n\
   step precrease\n\
   mark --am = through .a .m\n\
   mark --bm = through .b .m\n\
   mark --ba = map --ab onto --am\n\
   mark --bb = map --ab onto --bm\n\
   --ear = flatten (--ba \\ .a) (--bb \\ .b) (--v \\ .m) {toward .d}\n"

let test_flatten_derive_e2e () =
  let fd =
    Eval.eval_folded (Beloch.parse ~filename:"t.bel" rabbit_ear_derive_src)
  in
  (* [Fold_state.t] is abstract and constructed only via [make], which enforces
     every state invariant — so [fd]'s successful evaluation already IS the
     validity proof (no separate [validity_error] probe exists on the new
     core; see the dictionary in the 3c port plan). *)
  (* prove a GENUINELY new crease was materialised: the incenter O and the
     three given lines (spine x=1/2 and the two bisectors through O) are known;
     assert some crease segment is incident to O in paper space on a line
     PARALLEL to none of them — i.e. the emergent swivel crease, not just a
     re-use of a given ray. *)
  let mk x y = { Geom.x; y } in
  let o = mk (Num.of_q (Q.of_ints 1 2))
            (Num.div (Num.sub (Num.sqrt (Num.of_int 5)) Num.one) (Num.of_int 4))
  in
  let given =
    [
      { Geom.a = Num.one; b = Num.zero; c = Num.of_q (Q.of_ints 1 2) };
      (* spine x=1/2 *)
      Geom.line_through o (mk Num.zero Num.zero);
      (* bisector-a: O–a *)
      Geom.line_through o (mk Num.one Num.zero);
      (* bisector-b: O–b *)
    ]
  in
  let st = fd.Eval.state in
  let emergent_exists =
    Fold_state.all_crease_ids st
    |> List.exists (fun cid ->
           Fold_state.crease_segments st cid
           |> List.exists (fun (s : Fold_state.crease_segment) ->
                  (* paper-space incidence to O and a NEW direction *)
                  (Geom.point_equal s.Fold_state.pa o
                  || Geom.point_equal s.Fold_state.pb o)
                  &&
                  let l = Geom.line_through s.Fold_state.pa s.Fold_state.pb in
                  not (List.exists (Geom.parallel l) given)))
  in
  Alcotest.(check bool)
    "a genuinely-distinct emergent crease is incident to O" true emergent_exists

(* --ear occupies the crease namespace exactly like the validate-mode bind
   (Task 4) — same dup-check proof, no dedicated Env/has_bundle accessor. *)
let test_flatten_derive_registers_name () =
  expect_error "already bound" (fun () ->
      Eval.eval_folded
        (Beloch.parse ~filename:"t.bel" (rabbit_ear_derive_src ^ "--ear = [--v]\n")))

(* Task 6: the bound name in DERIVE mode must resolve to the EMERGENT crease,
   not the given rays — so a meet-point selector against it (`.[--ear --da]`)
   finds the tip where the emergent crease reaches the paper edge. For
   rabbit_ear_derive_src's O = (1/2, (sqrt5-1)/4) ~= (0.5, 0.309017), the
   emergent ray (the genuinely-new crease test_flatten_derive_e2e already
   proves exists) runs to the LEFT edge --da (x=0), not the base --ab — a
   `.[--ear --ab]` meet is off the mark's chord and errors, which is how this
   was first verified. If --ear still bound the given rays (a Bundle of
   --ba/--bb/--v), `.[--ear --da]` would be ambiguous (3 segments, none of
   which reaches --da) instead of resolving to the one emergent tip. *)
let test_flatten_tip () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         (rabbit_ear_derive_src ^ ".tip = .[--ear --da]\n"))
  in
  match List.find_opt (fun (n, _, _) -> n = "tip") fd.Eval.named_points with
  | None -> Alcotest.fail ".tip was not bound"
  | Some (_, p, _) ->
      Alcotest.(check (float 0.001)) "tip lies on the left edge (x=0)" 0.0
        (Num.to_float p.Geom.x);
      Alcotest.(check (float 0.001)) "tip lands near y=0.059" 0.0590169944
        (Num.to_float p.Geom.y)

(* The fish-base vertex: O = incenter of triangle abd on the ac-diagonal; the
   true 4th ray is the diagonal's CONTINUATION O→c — collinear with the given
   a-ray, i.e. a tier-2 OPPOSITE-RAY completion under the two-tier rule. Both
   tier-1 (line-new) candidates fold a flap off the paper for EVERY Maekawa
   pattern, so the deciding set is tier-2's pooled realizations — 6 of them,
   all in ONE position class (placements depend only on ray LINES; verified
   by instrumentation, see .superpowers/sdd/toward-stacking-rule.md). The
   three-stage selection (amended spec 38bd69e) then works purely on
   STACKING: the min-mountain canon keeps the three 1-given-mountain
   realizations, and the rank-dipole stage picks the one laying the
   toward-side material on top. `{toward .b}` and `{toward .d}` therefore
   produce the two MIRROR realizations — same placements (every paper point
   lands at the same table position!) but mirrored layer order — the spec's
   whole point. The difference is observable in [Fold_state.rank], not in
   table positions. *)
let fish_base_src toward =
  Printf.sprintf
    "paper square\n\
     mark --diag = map .a onto .c\n\
     mark --ray = through .a .c\n\
     step left\n\
     mark --l1 = map --ab onto --diag\n\
     mark --l2 = map --da onto --diag\n\
     flatten (--l1 & .b) (--l2 & .d) (--ray & .a) {toward %s}\n" toward

let test_flatten_derive_opposite_ray_fish_base () =
  let result toward =
    let fd =
      Eval.eval_folded (Beloch.parse ~filename:"t.bel" (fish_base_src toward))
    in
    (Array.length (Fold_state.faces fd.Eval.state), Fold_state.rank fd.Eval.state)
  in
  let nf_b, rank_b = result ".b" in
  let nf_d, rank_d = result ".d" in
  Alcotest.(check int) "fish-base toward .b folds (6 faces)" 6 nf_b;
  Alcotest.(check int) "fish-base toward .d folds the same face count" 6 nf_d;
  Alcotest.(check bool)
    "toward .b and toward .d pick DIFFERENT realizations (mirror stackings)"
    false (rank_b = rank_d)

(* toward ON the vertex's reflective symmetry axis (fish: the ac-diagonal —
   the given-ray direction set is invariant under reflection across it, b↔d)
   cannot pick a side: the two flaps are genuinely indistinguishable there.
   The explicit symmetry guard (rule doc §Ties) must reject with
   e_toward_ambiguous rather than let the dipole's arbitrary null-direction
   produce a strict-but-meaningless argmax. *)
let test_flatten_fish_toward_on_axis_ambiguous () =
  expect_error "does not pick a side" (fun () ->
      Eval.eval_folded (Beloch.parse ~filename:"t.bel" (fish_base_src ".c")))

(* Unit test of the same-DIRECTION genuine-filter: the PLUS vertex
   O = (1/2,1/2) with given rays right (1,1/2), up (1/2,1), down (1/2,0).
   The only completion is the LEFT ray (0,1/2) — the OPPOSITE ray of the
   given right ray's own line (y = 1/2). The old same-LINE filter dropped it
   ("extend a line already drawn"); the direction filter must keep it. No
   line-new candidate exists at all here, so [candidates] returns exactly one
   entry, tagged `OppositeRay`. (V2: feasibility is no longer [Flatten]'s job
   — [candidates] is a pure generator now, spec 2026-07-16 — so the old
   `feasible`-before-`toward` unit test has no Flatten-module-level
   equivalent any more; its behavior is covered by the eval-level fish-base
   test below, where the two LineNew candidates fail via
   `Collapse.collapse_all` returning `Error` for every pattern.) *)
let test_flatten_derive_opposite_ray_unit () =
  let mk x y = { Geom.x; y } in
  let half = Num.of_q (Q.of_ints 1 2) in
  let o = mk half half in
  let es =
    [
      { Collapse.cid = 0; ea = o; eb = mk Num.one half; valley = true };
      { Collapse.cid = 1; ea = o; eb = mk half Num.one; valley = true };
      { Collapse.cid = 2; ea = o; eb = mk half Num.zero; valley = true };
    ]
  in
  let fixed = Collapse.sort_ccw o es in
  match Flatten.candidates o ~fixed with
  | [ (l, r, `OppositeRay) ] ->
      (* the horizontal line y = 1/2 ... *)
      Alcotest.(check bool) "emergent line is horizontal" true
        (Num.sign l.Geom.a = 0);
      Alcotest.(check int) "emergent line passes through O" 0
        (Geom.side_of_line l o);
      (* ... and the LEFT ray of it (x decreasing from O) *)
      Alcotest.(check bool) "emergent ray points left" true
        (Num.compare r.Geom.x o.Geom.x < 0)
  | cands ->
      Alcotest.failf "expected exactly one OppositeRay candidate, got %d"
        (List.length cands)

(* Conversely, a derive-mode vertex that DOES admit a proper in-bounds seating
   (the swivel rabbit ear) folds correctly: every folded face lands inside the
   unit-square paper silhouette. Guards the fix from over-rejecting and pins
   the natural (on-paper) fold sense. *)
let swivel_rabbit_src =
  "paper square\n\
   mark --v = map .a onto .b\n\
   .m = --v * --cd\n\
   step precrease\n\
   mark --_am = through .a .m\n\
   mark --_bm = through .b .m\n\
   mark --_ba = map --ab onto --_am\n\
   mark --_bb = map --ab onto --_bm\n\
   .o = --_ba * --_bb\n\
   .lowerp = --_ba * --_bm\n\
   mark --lowerh = perp --bc through .lowerp\n\
   mark --ba = through .a .[--bc --lowerh]\n\
   mark --bb = through .b .[--da --lowerh]\n\
   step ear\n\
   --ear = flatten (--ba \\ .a) (--bb \\ .b) (--v \\ .m) {toward .c}\n"

let test_flatten_derive_in_bounds () =
  let fd =
    Eval.eval_folded (Beloch.parse ~filename:"t.bel" swivel_rabbit_src)
  in
  (* [fd]'s successful evaluation already proves validity — see
     test_flatten_derive_e2e's comment. *)
  let st = fd.Eval.state in
  let nf = Array.length (Fold_state.faces st) in
  let all_in =
    Array.for_all
      (fun i -> Array.for_all Geom.in_unit_square (Fold_state.table_polygon st i))
      (Array.init nf Fun.id)
  in
  Alcotest.(check bool)
    "every folded face stays within the unit-square paper" true all_in

(* Task 3 step 1: [Flatten.candidates] unit on the fish-base vertex itself —
   O = incenter-on-diagonal (1 − √2/2, 1 − √2/2), given rays toward b, d, a
   (the geometry [fish_base_src] actually resolves to; verified by evaluating
   the marks up to just before the flatten and reading off named points).
   Must contain the opposite-ray candidate (O→c, the diagonal's continuation,
   tagged `OppositeRay`) and the two side candidates (tagged `LineNew`) —
   exactly the shape the brief names, independent of feasibility (feasibility
   is no longer this module's concern). *)
let test_flatten_candidates_fish_vertex () =
  let mk x y = { Geom.x; y } in
  let o_coord = Num.sub Num.one (Num.div (Num.sqrt (Num.of_int 2)) (Num.of_int 2)) in
  let o = mk o_coord o_coord in
  let a = mk Num.zero Num.zero
  and b = mk Num.one Num.zero
  and d = mk Num.zero Num.one in
  let es =
    [
      { Collapse.cid = 0; ea = o; eb = b; valley = true };
      { Collapse.cid = 1; ea = o; eb = d; valley = true };
      { Collapse.cid = 2; ea = o; eb = a; valley = true };
    ]
  in
  let fixed = Collapse.sort_ccw o es in
  let cands = Flatten.candidates o ~fixed in
  Alcotest.(check int) "3 candidates" 3 (List.length cands);
  let count tag = List.length (List.filter (fun (_, _, t) -> t = tag) cands) in
  Alcotest.(check int) "one OppositeRay (O→c)" 1 (count `OppositeRay);
  Alcotest.(check int) "two LineNew (the side candidates)" 2 (count `LineNew)

(* Task 3 step 1: the pure Maekawa-consistent M/V pattern enumerator
   ([Flatten.mv_patterns]). n=4: valid (M,V) splits are (3,1)/(1,3) —
   |diff|=2 — never (2,2)/(4,0)/(0,4). *)
let test_flatten_mv_patterns_all_free () =
  Alcotest.(check int) "4 free rays -> 8 Maekawa patterns" 8
    (List.length (Flatten.mv_patterns [ Ast.MvFree; Ast.MvFree; Ast.MvFree; Ast.MvFree ]))

let test_flatten_mv_patterns_one_pinned () =
  (* one pinned Mountain, 3 free: total M must be 3 (free contributes 1 more
     M, 3 ways) or 1 (impossible, ray 0 alone is already M) union total M=3
     via the OTHER free-V-count-3 case (all three free = Valley) -> 3 + 1 = 4. *)
  Alcotest.(check int) "one pinned Mountain, 3 free -> 4 patterns" 4
    (List.length
       (Flatten.mv_patterns [ Ast.MvMountain; Ast.MvFree; Ast.MvFree; Ast.MvFree ]))

let test_flatten_mv_patterns_beyond_maekawa () =
  (* all four pinned to the SAME polarity (Mountain): nm=4, nv=0, diff=4 ≠ 2
     — Maekawa-unsatisfiable regardless of free assignment (there is none;
     everything is pinned) -> 0 patterns. *)
  Alcotest.(check int) "four pinned Mountain (beyond Maekawa) -> 0 patterns" 0
    (List.length
       (Flatten.mv_patterns
          [ Ast.MvMountain; Ast.MvMountain; Ast.MvMountain; Ast.MvMountain ]))

(* A flat (angle 0) hinge is a tortilla: its two faces are one continuous
   sheet across the hinge segment. Where that segment lies collinear on a
   FOLDED hinge's crease (a taco), the sheet must stay on one side of the
   taco's mouth — one face ranked inside [taco.fa, taco.fb] and the other
   outside means paper passes through paper. Fixture: the two-ear fish base
   with BOTH ears {toward .d}; before the flat-hinge taco-tortilla check this
   emitted a ghost state (second wing seated under the stationary strip, its
   ear above it — physically impossible, spotted on the render). *)
let test_flatten_no_flat_hinge_splits_taco () =
  let src =
    "paper square\n\
     mark --diag = map .a onto .c\n\
     mark --ray = through .a .c\n\
     mark --l1 = map --ab onto --diag\n\
     mark --l2 = map --da onto --diag\n\
     flatten (--l1 & .b) (--l2 & .d) (--ray & .a) {toward .d}\n\
     mark --l3 = map --cd onto --diag\n\
     mark --l4 = map --bc onto --diag\n\
     flatten (--l3 & .d) (--l4 & .b) (--ray & .c) {toward .d}\n"
  in
  let fd = Eval.eval_folded (Beloch.parse ~filename:"t.bel" src) in
  let st = fd.Eval.state in
  let hs = Fold_state.hinges st in
  let rank = Fold_state.rank st in
  let between a c b =
    (rank.(a) < rank.(c) && rank.(c) < rank.(b))
    || (rank.(b) < rank.(c) && rank.(c) < rank.(a))
  in
  let m = Array.length hs in
  for i = 0 to m - 1 do
    for j = 0 to m - 1 do
      let hi = hs.(i) and hj = hs.(j) in
      if
        Num.sign hi.Fold_state.angle <> 0
        && Num.sign hj.Fold_state.angle = 0
        && hj.Fold_state.fb >= 0
        && hi.Fold_state.fa <> hj.Fold_state.fa
        && hi.Fold_state.fa <> hj.Fold_state.fb
        && hi.Fold_state.fb <> hj.Fold_state.fa
        && hi.Fold_state.fb <> hj.Fold_state.fb
        && Geom.segments_overlap_collinear
             (Fold_state.hinge_table_segment st i)
             (Fold_state.hinge_table_segment st j)
        && (between hi.Fold_state.fa hj.Fold_state.fa hi.Fold_state.fb
           || between hi.Fold_state.fa hj.Fold_state.fb hi.Fold_state.fb)
      then
        Alcotest.failf
          "flat hinge %d (faces %d/%d) splits taco hinge %d (faces %d/%d)" j
          hj.Fold_state.fa hj.Fold_state.fb i hi.Fold_state.fa
          hi.Fold_state.fb
    done
  done

let () =
  Alcotest.run "flatten bind"
    [
      ( "bind",
        [
          Alcotest.test_case "--r = flatten ... parses and evaluates" `Quick
            test_flatten_bind_parses_and_evals;
          Alcotest.test_case "--r occupies the crease namespace" `Quick
            test_flatten_bind_registers_name;
          Alcotest.test_case "--r selects a constituent ray" `Quick
            test_flatten_bind_selects_ray;
          Alcotest.test_case "unbound flatten still parses" `Quick
            test_flatten_unbound_still_parses;
        ] );
      ( "derive",
        [
          Alcotest.test_case "flatten item accepts \\ filter" `Quick
            test_flatten_item_accepts_backslash_filter;
          Alcotest.test_case "derive kernel: genuine 320.55 emergent crease"
            `Quick test_flatten_derive_unit;
          Alcotest.test_case "derive e2e: rabbit-ear vertex closes flat"
            `Quick test_flatten_derive_e2e;
          Alcotest.test_case "--ear occupies the crease namespace" `Quick
            test_flatten_derive_registers_name;
          Alcotest.test_case "--ear binds emergent crease; .tip meets base"
            `Quick test_flatten_tip;
          Alcotest.test_case "derive opposite-ray fallback folds fish-base"
            `Quick test_flatten_derive_opposite_ray_fish_base;
          Alcotest.test_case "fish: toward on the symmetry axis is ambiguous"
            `Quick test_flatten_fish_toward_on_axis_ambiguous;
          Alcotest.test_case "derive unit: opposite ray is a candidate (plus)"
            `Quick test_flatten_derive_opposite_ray_unit;
          Alcotest.test_case "derive in-paper fold accepted (swivel-rabbit)"
            `Quick test_flatten_derive_in_bounds;
          Alcotest.test_case "candidates: fish vertex (1 OppositeRay + 2 LineNew)"
            `Quick test_flatten_candidates_fish_vertex;
          Alcotest.test_case "mv_patterns: 4 free -> 8" `Quick
            test_flatten_mv_patterns_all_free;
          Alcotest.test_case "mv_patterns: one pinned Mountain -> 4" `Quick
            test_flatten_mv_patterns_one_pinned;
          Alcotest.test_case "mv_patterns: beyond Maekawa -> 0" `Quick
            test_flatten_mv_patterns_beyond_maekawa;
          Alcotest.test_case "no flat hinge splits a taco (two-ear fish)"
            `Quick test_flatten_no_flat_hinge_splits_taco;
        ] );
    ]
