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

(* The classic rabbit-ear vertex [hull2020, Thm 8.5]: incenter O of triangle
   a/b/m, angle bisectors --ba/--bb from the base corners through O, and the
   spine --v (map .a onto .b, the line x=1/2) through both O and the apex m.
   A valid rabbit-ear fold needs all 4 rays at O: --ba toward .a, --bb toward
   .b, --v's UP ray toward .m, and --v's DOWN ray to the base. Giving 3 of
   them (both bisectors + the spine's DOWN ray) and asking derive mode to
   find the 4th exercises exactly the single-insertion case verified
   directly (with this construction's actual numbers) in
   tests/spike_flatten.ml: the missing ray is Kawasaki-forced to be the
   spine's own UP continuation. *)
let rabbit_ear_derive_src =
  "paper square\n\
   mark --v = map .a onto .b\n\
   .m = --v * --cd\n\
   step precrease\n\
   mark --am = through .a .m\n\
   mark --bm = through .b .m\n\
   mark --ba = map --ab onto --am\n\
   mark --bb = map --ab onto --bm\n\
   --ear = flatten (--ba & .a) (--bb & .b) (--v \\ .m mountain) toward .c\n"

let test_flatten_derive_e2e () =
  let fd =
    Eval.eval_folded (Beloch.parse ~filename:"t.bel" rabbit_ear_derive_src)
  in
  (* the oracle: Collapse.collapse on the completed (given + derived) set
     already had to return Ok for eval_folded to reach here without raising;
     this re-confirms the resulting state is self-consistent (unlike the
     simple orthogonal "+"-cross fixture used elsewhere, this triangle
     construction's 3 non-orthogonal bisector/spine lines subdivide the
     WHOLE paper — not just the vertex's fan — so the face count isn't a
     meaningful invariant here). *)
  Alcotest.(check (option string))
    "derived vertex is a valid flat state" None
    (Fold_state.validity_error fd.Eval.state)

(* --ear occupies the crease namespace exactly like the validate-mode bind
   (Task 4) — same dup-check proof, no dedicated Env/has_bundle accessor. *)
let test_flatten_derive_registers_name () =
  expect_error "already bound" (fun () ->
      Eval.eval_folded
        (Beloch.parse ~filename:"t.bel" (rabbit_ear_derive_src ^ "--ear = [--v]\n")))

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
          Alcotest.test_case "derive e2e: rabbit-ear vertex closes flat"
            `Quick test_flatten_derive_e2e;
          Alcotest.test_case "--ear occupies the crease namespace" `Quick
            test_flatten_derive_registers_name;
        ] );
    ]
