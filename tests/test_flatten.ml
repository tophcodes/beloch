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
    (Array.length fd.Eval.state.Fold_state.faces)

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
    (Array.length fd.Eval.state.Fold_state.faces)

(* Task 5: derive-mode `flatten` — a trailing `toward` operand triggers
   Flatten.derive to solve the emergent crease completing an ODD set of
   given rays to a flat-foldable vertex, then folds the completed set via
   Collapse.collapse exactly like the validate path. *)

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

(* Direct unit test of the derive kernel on the exact spike vertex
   V = (1/2, √5−2) with the ALL-`\` surface (rays pointing AWAY from the two
   base corners + the down-spine, fars ≈25.3°, ≈154.7°, 270°). This is the
   proven configuration of tests/spike_flatten.ml. Fed those three fars,
   Flatten.derive must return the GENUINE emergent swivel crease — a line
   axiom-unconstructible from the three givens — the ≈320.55° line meeting
   the base near x≈0.787. `toward .c` (top-right corner) selects that gap —
   the emergent ray points down-right, toward .c; `toward .d` selects the
   down-left mirror. *)
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
  match Flatten.derive v ~fixed ~toward:(mk Num.one Num.one) with
  | Error msg -> Alcotest.failf "derive returned Error: %s" msg
  | Ok l ->
      (* passes exactly through V *)
      Alcotest.(check int) "emergent line passes through V" 0
        (Geom.side_of_line l v);
      (* GENUINELY distinct from all three given lines: not parallel to the
         spine (x=1/2), nor to bisector-a (V–a), nor bisector-b (V–b) *)
      let spine = Geom.line_through v m
      and bis_a = Geom.line_through v a
      and bis_b = Geom.line_through v b in
      Alcotest.(check bool) "distinct from spine" false (Geom.parallel l spine);
      Alcotest.(check bool) "distinct from bisector-a" false
        (Geom.parallel l bis_a);
      Alcotest.(check bool) "distinct from bisector-b" false
        (Geom.parallel l bis_b);
      (* the four-ray vertex (emergent ray + the three givens) is Kawasaki-flat:
         the reflection product over the CCW-sorted rays is the identity *)
      (* the derived line yields a flat completion: exactly one of its two rays
         from V — the ≈320.55° down-right one, not the ≈140.55° mirror — closes
         Kawasaki with the givens (closure is order-sensitive). The line's (a,b)
         orientation is arbitrary, so try both ends rather than assume one. *)
      let closes far =
        let all =
          [ (far, ()); (fa, ()); (fb, ()); (fm, ()) ]
          |> List.sort (fun (p, _) (q, _) -> Geom.ccw_compare ~center:v p q)
          |> Array.of_list
        in
        Collapse.closure_ok v all
      in
      let end_p = mk (Num.add v.Geom.x l.Geom.b) (Num.sub v.Geom.y l.Geom.a)
      and end_m = mk (Num.sub v.Geom.x l.Geom.b) (Num.add v.Geom.y l.Geom.a) in
      Alcotest.(check bool) "emergent + givens close (Kawasaki)" true
        (closes end_p || closes end_m);
      (* approximate coordinates matching the spike: meets base y=0 at
         x ≈ 0.787, i.e. the ≈320.55° crease, NOT the ≈39.45° mirror *)
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
   --ear = flatten (--ba \\ .a) (--bb \\ .b) (--v \\ .m) toward .d\n"

let test_flatten_derive_e2e () =
  let fd =
    Eval.eval_folded (Beloch.parse ~filename:"t.bel" rabbit_ear_derive_src)
  in
  Alcotest.(check (option string))
    "derived vertex is a valid flat state" None
    (Fold_state.validity_error fd.Eval.state);
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

(* Anchor / fold-sense guard: a derive-mode vertex whose only flat realisation
   folds a flap OFF the sheet must be REJECTED, not emitted with garbage
   (negative) coordinates. fish-base's completed vertex is Kawasaki-valid but
   its physically-staying background sector is orientation-reversing, so no
   proper (front-up) anchor seats every layer inside the paper — collapse
   returns [e_out_of_paper] and eval surfaces it (rather than the misleading
   "does not close the vertex"). *)
let fish_base_src =
  "paper square\n\
   mark --diag = map .a onto .c\n\
   mark --ray = through .a .c\n\
   step left\n\
   mark --l1 = map --ab onto --diag\n\
   mark --l2 = map --da onto --diag\n\
   flatten (--l1 & .b) (--l2 & .d) (--ray & .a) toward .d\n"

let test_flatten_derive_out_of_paper_rejected () =
  expect_error Collapse.e_out_of_paper (fun () ->
      Eval.eval_folded (Beloch.parse ~filename:"t.bel" fish_base_src))

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
   --ear = flatten (--ba \\ .a) (--bb \\ .b) (--v \\ .m) toward .c\n"

let test_flatten_derive_in_bounds () =
  let fd =
    Eval.eval_folded (Beloch.parse ~filename:"t.bel" swivel_rabbit_src)
  in
  Alcotest.(check (option string))
    "swivel-rabbit derived vertex is a valid flat state" None
    (Fold_state.validity_error fd.Eval.state);
  let all_in =
    Array.for_all
      (fun (f : Fold_state.face) ->
        Array.for_all Geom.in_unit_square (Fold_state.table_poly_of f))
      fd.Eval.state.Fold_state.faces
  in
  Alcotest.(check bool)
    "every folded face stays within the unit-square paper" true all_in

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
          Alcotest.test_case "derive off-paper fold is rejected (fish-base)"
            `Quick test_flatten_derive_out_of_paper_rejected;
          Alcotest.test_case "derive in-paper fold accepted (swivel-rabbit)"
            `Quick test_flatten_derive_in_bounds;
        ] );
    ]
