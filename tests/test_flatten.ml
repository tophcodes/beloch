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
    ]
