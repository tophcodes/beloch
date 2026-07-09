open Beloch

let q = Num.of_int
let half = Num.of_q (Q.of_ints 1 2)
let pt x y = { Geom.x = q x; y = q y }

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

let count_assign a (st : Fold_state.t) =
  Array.to_list st.Fold_state.edges
  |> List.filter (fun (e : Fold_state.edge) -> e.Fold_state.eassign = a)
  |> List.length

(* ---- Eval: error cases ---- *)

let test_eval_identical_points () =
  expect_error "same place" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel" "paper square\nmark through .a .a\n")))

let test_eval_undefined_point () =
  expect_error "undefined" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel" "paper square\nmark map .a onto .z\n")))

let test_eval_parallel_cross () =
  expect_error "parallel" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --h1 = through .a .b\n\
               mark --h2 = through .d .c\n\
               .x = --h1 * --h2\n")))

let test_eval_bisect_errors () =
  expect_error "identical" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --x = through .a .c\n\
               mark --y = through .a .c\n\
               mark map --x onto --y toward .b\n")));
  expect_error "ambiguous" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --v = map .a onto .b\n\
               mark --h = map .b onto .c\n\
               mark map --v onto --h\n")));
  expect_error "names where the fold goes" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --d = through .a .c\n\
               mark --h = map .b onto .c\n\
               mark map --d onto --h toward .a\n")))

let test_eval_map_onto_line_parallel () =
  expect_error "parallel" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --l1 = through .a .b\n\
               mark --l2 = through .d .c\n\
               mark map .c onto --l1 perp --l2\n")))

let test_eval_map_onto_line_ok () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          mark --l1 = through .a .b\n\
          mark --l2 = through .a .d\n\
          mark map .c onto --l1 perp --l2\n")
  in
  match Array.to_list fd.Eval.state.Fold_state.edges with
  | [] -> Alcotest.fail "expected at least one crease edge"
  | cr :: _ ->
      let c = Geom.line_through cr.Fold_state.ea cr.Fold_state.eb in
      let on (p : Geom.point) =
        Num.equal
          (Num.add (Num.mul c.Geom.a p.Geom.x) (Num.mul c.Geom.b p.Geom.y))
          c.Geom.c
      in
      Alcotest.(check bool)
        "axiom-4 crease passes through (0,1/2)" true
        (on { Geom.x = q 0; y = half });
      Alcotest.(check bool)
        "axiom-4 crease passes through (1,1/2)" true
        (on { Geom.x = q 1; y = half })

let test_eval_map_through_ambiguous () =
  expect_error "toward" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --bottom = through .a .b\n\
               mark map .d onto --bottom through .a\n")))

let test_eval_map_through_same_point () =
  expect_error "same point" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --bottom = through .a .b\n\
               mark map .a onto --bottom through .a\n")))

let test_axiom7_error_q_on_e () =
  expect_error "already lies on" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --top = through .d .c\n\
               mark --bot = through .a .b\n\
               mark map .a onto --bot and .d onto --top\n")))

let test_axiom7_error_parallel_directrices () =
  expect_error "parallel" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --bot = through .a .b\n\
               mark --top = through .d .c\n\
               mark map .a onto --bot and .b onto --top\n")))

(* the migrated crease-flap-restrict scenario: select --b's piece on the upper
   flap with `at #(.c .d)` and cross it with --v — must evaluate cleanly. *)
let test_eval_at_flap () =
  ignore
    (Eval.eval_folded
       (Beloch.parse ~filename:"t.bel"
          "paper square\n\
           mark --b = through .a .c\n\
           fold --v = map .c onto .b moving .c\n\
           .mid = --b & #[.c .d] * --v\n\
           mark map .d onto .mid\n"))

(* cross is material: a crease bent on the TABLE by a later fold is still one
   straight scar in the paper, so the bare bundle crosses fine — no `at` *)
let test_eval_cross_table_bent_scar_ok () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          mark --b = through .a .c\n\
          fold --v = map .c onto .b moving .c\n\
          .mid = --b * --v\n\
          mark map .d onto .mid\n")
  in
  match List.assoc_opt "mid" fd.Eval.named_points with
  | Some p ->
      Alcotest.(check bool) "mid is the material centre" true
        (Geom.point_equal p { Geom.x = half; y = half })
  | None -> Alcotest.fail "expected .mid"

(* a selector that lands on no segment of the bundle is the 0-match error.
   NOTE: deviates from the brief's literal source, which selected --b at .b
   after folding .c onto .b — since that fold maps .c's endpoint of the
   diagonal exactly onto .b's table position, the selector coincidentally DID
   match (verified: it evaluates cleanly, .mid lands at (0.5,0.5)). .b is
   never on the unfolded diagonal --b = through .a .c (it's off that line
   entirely), so this source reaches the same code path without the
   coincidental fold. *)
let test_eval_at_no_match () =
  expect_error "no segment" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --b = through .a .c\n\
               mark --w = through .b .d\n\
               .mid = --b & .b * --w\n")))

(* @fold --d ≡ re-stating the axiom: same faces, same M/V, no stale F (#27) *)
let test_fold_along_matches_restatement () =
  let via_fold =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\nmark --d = map .b onto .a\nfold --d moving .b\n")
  in
  let via_axiom =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\nmark map .b onto .a\nfold map .b onto .a moving .b\n")
  in
  Alcotest.(check int) "same face count"
    (Array.length via_axiom.Eval.state.Fold_state.faces)
    (Array.length via_fold.Eval.state.Fold_state.faces);
  Alcotest.(check int) "same V count"
    (count_assign Fold_state.V via_axiom.Eval.state)
    (count_assign Fold_state.V via_fold.Eval.state);
  Alcotest.(check int) "no stale F" 0
    (count_assign Fold_state.F via_fold.Eval.state)

(* crease all layers, @fold some: the unmoved layer keeps its flat F mark *)
let test_crease_all_fold_some () =
  let scoped =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          fold map .d onto .a\n\
          mark --m = map .c onto .d\n\
          fold --m moving .c up to .c\n")
  in
  Alcotest.(check int) "unmoved layer keeps F" 1
    (count_assign Fold_state.F scoped.Eval.state);
  Alcotest.(check int) "4 faces" 4
    (Array.length scoped.Eval.state.Fold_state.faces);
  let all_layers =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          fold map .d onto .a\n\
          mark --m = map .c onto .d\n\
          fold --m moving .c\n")
  in
  Alcotest.(check int) "all-layers upgrades every F" 0
    (count_assign Fold_state.F all_layers.Eval.state)

let test_fold_along_needs_moving () =
  expect_error "needs `moving" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\nmark --d = map .b onto .a\nfold --d\n")))

let test_fold_along_not_material () =
  expect_error "existing crease" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\nfold .a * .c moving .b\n")))

(* globally bent bundle without `at` → the existing PR2/at error *)
let test_fold_along_bent () =
  expect_error "no longer straight" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --b = through .a .c\n\
               fold --v = map .c onto .b\n\
               fold --b moving .a\n")))

(* bent under the moving set: axis picked via `at`, but a moving flap carries
   an off-axis segment of the same bundle *)
let test_fold_along_bent_under_moving () =
  expect_error "bent under" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --b = through .a .c\n\
               fold --v = map .c onto .b\n\
               fold --b & #[.c .d] moving .a\n")))

(* ---- @collapse ---- *)

let test_collapse_standing_unsupported () =
  expect_error "standing folds are not yet supported" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --d = through .a .c\n\
               collapse --d and standing .a\n")))

(* n = 2: two diagonals through the same center point, each named as a single
   `at`-selected segment — a real fold, not a collapse; hint toward @fold *)
let test_collapse_count_two () =
  expect_error "use `fold`" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --d1 = through .a .c\n\
               mark --d2 = through .b .d\n\
               collapse --d1 & .a and --d2 & .b\n")))

let test_collapse_not_material () =
  expect_error "collapse folds along existing creases" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel" "paper square\ncollapse .a * .c\n")))

(* all-layers congruence guard, happy path: a single flat sheet precreased
   along both perpendicular bisectors (the classic "+" vertex, same shape as
   test_collapse.ml's eassign-parity fixture, reached through named corners
   via #(...) flap selectors instead of raw coordinates). Every face the
   guard inspects borders an edge of the very crease it's checking, so it
   must stay silent; the 3-mountain/1-valley assignment is the one the
   kernel fixture already proved folds to a unique order. *)
let test_collapse_all_layers_ok () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          mark --h = map .a onto .d\n\
          mark --v = map .a onto .b\n\
          collapse --h & #[.b] mountain and --v & #[.c] and --h & #[.d] \
          mountain and --v & #[.a] mountain\n")
  in
  Alcotest.(check int) "vertex collapse leaves 4 sector faces" 4
    (Array.length fd.Eval.state.Fold_state.faces)

(* ---- Fold_state ---- *)

let test_fold_state_init () =
  let st = Fold_state.init_square in
  Alcotest.(check int) "one face" 1 (Array.length st.Fold_state.faces);
  Alcotest.(check bool)
    "corner .a at (0,0) on the table" true
    (Geom.point_equal (Fold_state.table_position st (pt 0 0)) (pt 0 0))

let test_fold_state_half () =
  let st = Fold_state.init_square in
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.simple_fold st ~axis ~move_side:1 ~valley:true in
  Alcotest.(check int) "two faces after one fold" 2
    (Array.length st.Fold_state.faces);
  Alcotest.(check bool) ".b maps onto .a" true
    (Geom.point_equal (Fold_state.table_position st (pt 1 0)) (pt 0 0));
  let all_left =
    Array.for_all
      (fun i ->
        Array.for_all
          (fun p -> Num.compare p.Geom.x half <= 0)
          (Fold_state.table_polygon st i))
      [| 0; 1 |]
  in
  Alcotest.(check bool) "folded footprint is the left half" true all_left

(* index of the single face with the given det_sign in a 2-face state *)
let face_with_det (st : Fold_state.t) (d : int) : int =
  let idxs = List.filter
    (fun i -> Isometry.det_sign st.Fold_state.faces.(i).Fold_state.iso = d)
    [ 0; 1 ] in
  match idxs with [ i ] -> i | _ -> Alcotest.fail "expected exactly one such face"

let test_layer_valley_moved_above () =
  let st = Fold_state.init_square in
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.simple_fold st ~axis ~move_side:1 ~valley:true in
  let mv = face_with_det st (-1) and stt = face_with_det st 1 in
  Alcotest.(check bool) "moved face is Above stationary" true
    (Layer_order.get st.Fold_state.order mv stt = Fold_state.Above)

let test_layer_mountain_moved_below () =
  let st = Fold_state.init_square in
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.simple_fold st ~axis ~move_side:1 ~valley:false in
  let mv = face_with_det st (-1) and stt = face_with_det st 1 in
  Alcotest.(check bool) "moved face is Below stationary" true
    (Layer_order.get st.Fold_state.order mv stt = Fold_state.Below)

let test_layer_antisymmetry () =
  let st = Fold_state.init_square in
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.simple_fold st ~axis ~move_side:1 ~valley:true in
  let ok = ref true in
  Layer_order.iter st.Fold_state.order (fun i j r ->
      if Layer_order.get st.Fold_state.order j i <> Fold_state.negate r then
        ok := false);
  Alcotest.(check bool) "order is negation-symmetric" true !ok

let test_layer_fold_quarter_reversal () =
  let st =
    (Eval.eval_folded
       (Beloch.parse ~filename:"fq.bel"
          "paper square\nfold map .b onto .a moving .b\nfold map .d onto .a moving .d\n")).Eval.state
  in
  Alcotest.(check int) "four faces" 4 (Array.length st.Fold_state.faces);
  let n = Array.length st.Fold_state.faces in
  let bad = ref false in
  for i = 0 to n - 1 do
    for j = i + 1 to n - 1 do
      if
        Geom.convex_overlap
          (Fold_state.table_polygon st i)
          (Fold_state.table_polygon st j)
        && Layer_order.get st.Fold_state.order i j = Fold_state.Apart
      then bad := true
    done
  done;
  Alcotest.(check bool) "no overlapping pair left Apart" false !bad

let test_fold_subdivide () =
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.subdivide Fold_state.init_square axis ~prov:None in
  Alcotest.(check int) "two faces after subdivide" 2
    (Array.length st.Fold_state.faces);
  Alcotest.(check int) "one crease edge" 1 (Array.length st.Fold_state.edges);
  Alcotest.(check int) "subdivide edges are F" 1 (count_assign Fold_state.F st)

let test_fold_records_valley () =
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st =
    Fold_state.fold_with_records Fold_state.init_square ~axis ~move_side:1
      ~valley:true ~prov:None
  in
  Alcotest.(check int) "one edge" 1 (Array.length st.Fold_state.edges);
  Alcotest.(check int) "the half fold is a valley" 1
    (count_assign Fold_state.V st);
  Alcotest.(check int) "no mountain" 0 (count_assign Fold_state.M st)

(* Edges accumulate across folds (#26): to isolate the creases freshly cut by
   the second fold (as opposed to the first fold's crease carried/split
   forward), filter st2's edges to those whose crease_id wasn't already
   present in st1 — fresh cuts mint a fresh crease_id, carried/split edges
   keep their parent's. *)
let new_edges_since (before : Fold_state.t) (after : Fold_state.t) =
  let old_ids =
    Array.to_list before.Fold_state.edges
    |> List.map (fun (e : Fold_state.edge) -> e.Fold_state.crease_id)
  in
  Array.to_list after.Fold_state.edges
  |> List.filter (fun (e : Fold_state.edge) ->
         not (List.mem e.Fold_state.crease_id old_ids))

let count_assign_in a edges =
  List.length
    (List.filter (fun (e : Fold_state.edge) -> e.Fold_state.eassign = a) edges)

let test_fold_records_accordion () =
  let axis1 = { Geom.a = q 1; b = q 0; c = half } in
  let st1 =
    Fold_state.simple_fold Fold_state.init_square ~axis:axis1 ~move_side:1
      ~valley:true
  in
  let axis2 = { Geom.a = q 0; b = q 1; c = half } in
  let st2 =
    Fold_state.fold_with_records st1 ~axis:axis2 ~move_side:1 ~valley:true
      ~prov:None
  in
  let fresh = new_edges_since st1 st2 in
  Alcotest.(check int) "two crease edges from the second fold" 2
    (List.length fresh);
  Alcotest.(check int) "one valley (accordion)" 1
    (count_assign_in Fold_state.V fresh);
  Alcotest.(check int) "one mountain (accordion)" 1
    (count_assign_in Fold_state.M fresh)

let test_fold_paper_preimages () =
  let flat = Fold_state.paper_preimages Fold_state.init_square (pt 1 0) in
  Alcotest.(check int) "one preimage when flat" 1 (List.length flat);
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st =
    Fold_state.simple_fold Fold_state.init_square ~axis ~move_side:1
      ~valley:true
  in
  let folded =
    Fold_state.paper_preimages st { Geom.x = Num.of_q (Q.of_ints 1 4); y = q 0 }
  in
  Alcotest.(check int) "two preimages in the folded overlap" 2 (List.length folded)

(* #27: folding along a precrease (subdivide, then fold on the same axis) must
   upgrade the abutting F crease to M/V — the fold cuts nothing, so the
   upgrade comes from the carried on-axis edge, not from a new cut. *)
let test_fold_precrease_upgrade () =
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st1 = Fold_state.subdivide Fold_state.init_square axis ~prov:None in
  let st2 =
    Fold_state.fold_with_records st1 ~axis ~move_side:1 ~valley:true ~prov:None
  in
  Alcotest.(check int) "folding a precrease yields one valley edge" 1
    (count_assign Fold_state.V st2);
  Alcotest.(check int) "the fold emits no stale F" 0
    (count_assign Fold_state.F st2)

let test_fold_state_flip () =
  let st =
    Fold_state.simple_fold Fold_state.init_square
      ~axis:{ Geom.a = q 1; b = q 0; c = half }
      ~move_side:1 ~valley:true
  in
  let n = Array.length st.Fold_state.faces in
  let det_before =
    Array.map
      (fun (f : Fold_state.face) -> Isometry.det_sign f.Fold_state.iso)
      st.Fold_state.faces
  in
  let fl = Fold_state.flip st in
  Alcotest.(check int) "face count preserved" n
    (Array.length fl.Fold_state.faces);
  Array.iteri
    (fun i (f : Fold_state.face) ->
      Alcotest.(check int)
        "det flipped and order reversed"
        (-det_before.(n - 1 - i))
        (Isometry.det_sign f.Fold_state.iso))
    fl.Fold_state.faces

let test_fold_state_flip_involution () =
  let st =
    Fold_state.simple_fold Fold_state.init_square
      ~axis:{ Geom.a = q 1; b = q 0; c = half }
      ~move_side:1 ~valley:true
  in
  let twice = Fold_state.flip (Fold_state.flip st) in
  Alcotest.(check bool)
    "flip twice restores .a's table position" true
    (Geom.point_equal
       (Fold_state.table_position st (pt 0 0))
       (Fold_state.table_position twice (pt 0 0)))

let test_layer_valid_examples_ok () =
  let st = Fold_state.init_square in
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.simple_fold st ~axis ~move_side:1 ~valley:true in
  Alcotest.(check bool) "a simple valley fold is valid" true
    (Fold_state.validity_error st = None)

let read_file path =
  let ic = open_in path in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic; s

(* Examples excluded from the validity property test.
   - Files whose first line starts with "; status: anti" are expected to raise
     errors (the evaluator should reject them).
   - Files whose first line contains "; bench: slow" are known-slow (e.g. they
     trigger expensive irrational-coordinate arithmetic) and are skipped until
     the underlying performance issue is fixed.  Tag a file with that marker to
     opt it out of this suite without hard-coding its name here. *)
let first_line path =
  try
    let ic = open_in path in
    let line = input_line ic in
    close_in ic; line
  with End_of_file | Sys_error _ -> ""

let contains_substring line sub =
  let ll = String.length line and sl = String.length sub in
  sl = 0
  || (let stop = ll - sl in
      let rec loop i = if i > stop then false
                       else if String.sub line i sl = sub then true
                       else loop (i + 1) in
      loop 0)

let skip_example _name path =
  let line = first_line path in
  let has sub = contains_substring line sub in
  has "; bench: slow" || has "; status: anti"

let examples_dir () =
  (* Anchor to the source root of *this* build context. dune sets
     DUNE_SOURCEROOT to the absolute workspace root, so an in-repo worktree
     reads its own examples/ rather than the main checkout's (#37). *)
  match Sys.getenv_opt "DUNE_SOURCEROOT" with
  | Some root -> Filename.concat root "examples"
  | None -> "../../../examples"

let test_layer_all_examples_valid () =
  let dir = examples_dir () in
  let files =
    Sys.readdir dir |> Array.to_list
    |> List.filter (fun f -> Filename.check_suffix f ".bel")
    |> List.sort compare
  in
  Alcotest.(check bool) "found example files" true (List.length files > 0);
  List.iter
    (fun f ->
      let path = Filename.concat dir f in
      if not (skip_example f path) then
        match
          try `Ok (Beloch.fold_string ~filename:path (read_file path))
          with Error.Beloch_error (_, m) -> `Err m
        with
        | `Err m -> Alcotest.failf "example %s failed to evaluate: %s" f m
        | `Ok _ -> ())
    files

(* ---- Eval_folded ---- *)

let test_eval_folded_half () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\nfold map .b onto .a moving .b\n")
  in
  Alcotest.(check int) "two faces" 2
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "one valley edge" 1
    (count_assign Fold_state.V fd.Eval.state);
  Alcotest.(check bool) ".b maps onto .a" true
    (Geom.point_equal
       (Fold_state.table_position fd.Eval.state (pt 1 0))
       (pt 0 0))

let test_eval_folded_precrease () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel" "paper square\nmark map .a onto .c\n")
  in
  Alcotest.(check int) "two faces" 2
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "one F edge" 1
    (count_assign Fold_state.F fd.Eval.state)

let test_eval_folded_moving_required () =
  expect_error "moving" (fun () ->
      Eval.eval_folded
        (Beloch.parse ~filename:"t.bel"
           "paper square\nmark --d = through .a .c\nfold perp --d through .b\n"))

let test_eval_folded_quarter_accordion () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\nfold map .b onto .a moving .b\nfold map .d onto .a moving .d\n")
  in
  Alcotest.(check int) "four faces after quarter fold" 4
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "an accordion mountain appears" 1
    (count_assign Fold_state.M fd.Eval.state)

(* a crease scored through two layers marks two DIFFERENT lines in the paper
   (mirror-image scars) — bare cross must refuse and point at `at` *)
let test_eval_cross_multilayer_needs_at () =
  expect_error "different lines" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               fold map .c onto .a moving .c\n\
               mark --v = map .b onto .a\n\
               .mid = --v * --ab\n")))

(* same setup, `at #(.a)` picks the bottom layer's scar: the crossing is the
   material point (1/2, 0), independent of the folded state *)
let test_eval_cross_multilayer_with_at () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          fold map .c onto .a moving .c\n\
          mark --v = map .b onto .a\n\
          .mid = --v & #[.a] * --ab\n")
  in
  match List.assoc_opt "mid" fd.Eval.named_points with
  | Some p ->
      Alcotest.(check bool) "mid is the bottom scar's foot" true
        (Geom.point_equal p { Geom.x = half; y = q 0 })
  | None -> Alcotest.fail "expected .mid"

(* paper is opaque: lines crossing beyond the marks' extent is not a crossing *)
let test_eval_cross_mark_does_not_reach () =
  expect_error "does not reach" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               fold map .c onto .a moving .c\n\
               mark --v = map .b onto .a\n\
               .x = --v & #[.a] * --cd\n")))

let test_scope_basic_lookup () =
  let r = Eval.eval_folded (Beloch.parse ~filename:"t.bel"
    "paper square\n\
     mark --d = through .a .c\n\
     .m = --d * --ab\n") in
  let has_d = List.assoc_opt "d" r.Eval.named_lines <> None in
  let has_m = List.assoc_opt "m" r.Eval.named_points <> None in
  Alcotest.(check bool) "d defined" true has_d;
  Alcotest.(check bool) "m defined" true has_m

let eval_src src =
  Eval.eval_folded (Beloch.parse ~filename:"t.bel" ("paper square\n" ^ src))

let test_eval_dup_crease_error () =
  expect_error "already bound" (fun () ->
      eval_src "mark --x = through .a .b\nmark --x = through .a .c\n")

let test_eval_dup_point_error () =
  expect_error "already bound" (fun () ->
      eval_src
        "mark --h = through .a .b\nmark --v = through .a .d\n.x = --h * --v\n\
         .x = --h * --v\n")

let test_eval_corner_rebind_error () =
  expect_error "already bound" (fun () ->
      eval_src "mark --h = through .a .b\nmark --v = through .a .d\n.a = --h * --v\n")

let test_eval_temp_rebind_ok () =
  let fd =
    eval_src
      "mark --h = through .a .b\nmark --v = through .a .d\n._x = --h * --v\n\
       ._x = --v * --h\n"
  in
  Alcotest.(check bool)
    "temp not in named_points" true
    (not (List.mem_assoc "_x" fd.Eval.named_points))

let test_eval_temp_crease_unnamed () =
  let fd = eval_src "mark --_t = through .a .c\n" in
  Alcotest.(check bool)
    "temp line not in named_lines" true
    (not (List.mem_assoc "_t" fd.Eval.named_lines));
  Alcotest.(check bool)
    "temp crease provenance unnamed" true
    (Array.for_all
       (fun (e : Fold_state.edge) ->
         match e.Fold_state.eprov with
         | Some p -> p.State.name = None
         | None -> true)
       fd.Eval.state.Fold_state.edges)

let test_eval_def_never_runs () =
  let fd = eval_src "def bad() {\n  --x = through .a .a\n}\n" in
  Alcotest.(check int) "no edges" 0 (Array.length fd.Eval.state.Fold_state.edges)

let test_eval_apply_closed_scope () =
  expect_error "undefined point .a" (fun () ->
      eval_src "def d() {\n  --x = through .a .b\n}\napply d()\n")

let test_eval_apply_binds_params () =
  let fd =
    eval_src
      "def diag(.p .q) {\n  mark --d = through .p .q\n}\n$i = apply diag(.a .c)\n"
  in
  Alcotest.(check int) "one crease" 1
    (Array.length fd.Eval.state.Fold_state.edges)

let test_eval_apply_arity_error () =
  expect_error "argument" (fun () ->
      eval_src "def diag(.p .q) {\n  --d = through .p .q\n}\napply diag(.a)\n")

let test_eval_apply_kind_error () =
  expect_error "point argument" (fun () ->
      eval_src
        "def d(.p) {\n  --x = perp --ab through .p\n}\n\
         apply d(--ab)\n")

let test_eval_apply_undefined_def () =
  expect_error "undefined def" (fun () -> eval_src "apply nope()\n")

let test_eval_dup_def_error () =
  expect_error "already defined" (fun () ->
      eval_src "def d() {\n}\ndef d() {\n}\n")

let test_eval_dup_param_error () =
  expect_error "duplicate parameter" (fun () ->
      eval_src "def d(.p .p) {\n}\n")

let test_eval_dup_instance_error () =
  expect_error "already bound" (fun () ->
      eval_src
        "def d(.p .q) {\n  --x = through .p .q\n}\n\
         $i = apply d(.a .c)\n$i = apply d(.b .d)\n")

let prov_names (fd : Eval.folded) =
  Array.to_list fd.Eval.state.Fold_state.edges
  |> List.filter_map (fun (e : Fold_state.edge) ->
         match e.Fold_state.eprov with Some p -> p.State.name | None -> None)

let test_eval_instance_fold_names () =
  let fd =
    eval_src "def d(.p .q) {\n  mark --x = through .p .q\n}\n$i = apply d(.a .c)\n"
  in
  Alcotest.(check bool) "crease named i.x" true
    (List.mem "i.x" (prov_names fd))

let test_eval_naked_apply_unnamed () =
  let fd =
    eval_src "def d(.p .q) {\n  mark --x = through .p .q\n}\napply d(.a .c)\n"
  in
  Alcotest.(check int) "no named provenance" 0 (List.length (prov_names fd))

let test_eval_temp_instance_unnamed () =
  let fd =
    eval_src "def d(.p .q) {\n  mark --x = through .p .q\n}\n$_i = apply d(.a .c)\n"
  in
  Alcotest.(check int) "no named provenance" 0 (List.length (prov_names fd))

let test_eval_nested_instance_names () =
  let fd =
    eval_src
      "def inner(.p .q) {\n  mark --pq = through .p .q\n}\n\
       def outer(.p .q) {\n  $in = apply inner(.p .q)\n}\n\
       $o = apply outer(.a .c)\n"
  in
  Alcotest.(check bool) "nested name o.in.pq" true
    (List.mem "o.in.pq" (prov_names fd))

let test_eval_self_recursion_rejected () =
  expect_error "not defined before" (fun () ->
      eval_src "def d() {\n  apply d()\n}\napply d()\n")

let test_eval_later_def_invisible () =
  expect_error "not defined before" (fun () ->
      eval_src
        "def outer() {\n  apply inner()\n}\n\
         def inner(.p) {\n}\n\
         apply outer()\n")

let test_eval_earlier_def_visible () =
  let fd =
    eval_src
      "def inner(.p .q) {\n  mark --l = through .p .q\n}\n\
       def outer(.p .q) {\n  apply inner(.p .q)\n}\n\
       apply outer(.a .c)\n"
  in
  Alcotest.(check int) "one crease" 1
    (Array.length fd.Eval.state.Fold_state.edges)

let test_eval_member_point_access () =
  let fd =
    eval_src
      "mark --h = through .a .b\n\
       def d(.p .q --base) {\n\
      \  mark --l = through .p .q\n\
      \  .m = --l * --base\n\
       }\n\
       $i = apply d(.d .b --h)\n\
       export { .m as .im } $i\n\
       mark --thru = through .im .c\n"
  in
  Alcotest.(check bool) "crease thru exists" true
    (List.mem_assoc "thru" fd.Eval.named_lines)

let test_eval_member_line_access () =
  let fd =
    eval_src
      "def d(.p .q) {\n  mark --l = through .p .q\n}\n\
       $i = apply d(.a .c)\n\
       export { --l as --il } $i\n\
       .x = --il * --ab\n"
  in
  Alcotest.(check bool) "point x exists" true
    (List.mem_assoc "x" fd.Eval.named_points)

let prov_steps (fd : Eval.folded) =
  Array.to_list fd.Eval.state.Fold_state.edges
  |> List.filter_map (fun (e : Fold_state.edge) ->
         match e.Fold_state.eprov with Some p -> p.State.step | None -> None)

let test_eval_panel_tags_creases () =
  let fd =
    eval_src
      "step first\nmark --x = through .a .c\nstep second\nmark --y = through .b .d\n"
  in
  Alcotest.(check bool) "first tagged" true (List.mem "first" (prov_steps fd));
  Alcotest.(check bool) "second tagged" true
    (List.mem "second" (prov_steps fd))

(* one crease stmt can yield several records (one per crossed face) — assert tag partition, not counts *)
let test_eval_before_first_panel_untagged () =
  let fd = eval_src "mark --x = through .a .c\nstep p\nmark --y = through .b .d\n" in
  let tagged = prov_steps fd in
  Alcotest.(check bool) "all tagged with p" true
    (tagged <> [] && List.for_all (fun s -> s = "p") tagged);
  let untagged =
    Array.to_list fd.Eval.state.Fold_state.edges
    |> List.filter (fun (e : Fold_state.edge) ->
           match e.Fold_state.eprov with
           | Some p -> p.State.step = None
           | None -> true)
  in
  Alcotest.(check bool) "some untagged (before first step)" true
    (untagged <> [])

let test_eval_dup_panel_error () =
  expect_error "already used" (fun () -> eval_src "step a\nstep a\n")

let test_eval_apply_folds_land_in_panel () =
  let fd =
    eval_src
      "def d(.p .q) {\n  mark --l = through .p .q\n}\n\
       step body\n$i = apply d(.a .c)\n"
  in
  Alcotest.(check bool) "tagged body" true (List.mem "body" (prov_steps fd))

let test_eval_member_undefined_instance () =
  expect_error "undefined instance" (fun () -> eval_src "export $ghost\n")

let def_d =
  "def d(.p .q .r) {\n\
  \  mark --l1 = through .p .q\n\
  \  --l2 = through .p .r\n\
  \  mark --qr = through .q .r\n\
  \  .m = --l1 * --qr\n\
   }\n\
   $i = apply d(.a .c .b)\n"

let test_eval_export_selective () =
  let fd = eval_src (def_d ^ "export { .m --l1 } $i\n") in
  Alcotest.(check bool) "m landed" true
    (List.mem_assoc "m" fd.Eval.named_points);
  Alcotest.(check bool) "l1 landed" true
    (List.mem_assoc "l1" fd.Eval.named_lines);
  Alcotest.(check bool) "l2 not landed" true
    (not (List.mem_assoc "l2" fd.Eval.named_lines))

let test_eval_export_all () =
  let fd = eval_src (def_d ^ "export $i\n") in
  Alcotest.(check bool) "l2 landed too" true
    (List.mem_assoc "l2" fd.Eval.named_lines)

let test_eval_export_rename () =
  let fd = eval_src (def_d ^ "export { .m as .mid } $i\n") in
  Alcotest.(check bool) "mid landed" true
    (List.mem_assoc "mid" fd.Eval.named_points);
  Alcotest.(check bool) "m not landed" true
    (not (List.mem_assoc "m" fd.Eval.named_points))

let test_eval_export_collision_needs_bang () =
  expect_error "use ! to shadow" (fun () ->
      eval_src ("mark --l1 = through .a .b\n" ^ def_d ^ "export { --l1 } $i\n"))

let test_eval_export_bang_shadows () =
  let fd =
    eval_src ("mark --l1 = through .a .b\n" ^ def_d ^ "export { --l1! } $i\n")
  in
  Alcotest.(check bool) "l1 present" true
    (List.mem_assoc "l1" fd.Eval.named_lines)

let test_eval_export_bang_without_conflict () =
  expect_error "nothing to shadow" (fun () ->
      eval_src (def_d ^ "export { --l1! } $i\n"))

let test_eval_export_unknown_member () =
  expect_error "no point member" (fun () ->
      eval_src (def_d ^ "export { .ghost } $i\n"))

let test_eval_export_all_collision () =
  expect_error "use ! to shadow" (fun () ->
      eval_src (def_d ^ "$j = apply d(.a .c .b)\nexport $i\nexport $j\n"))

(* A temp landing name rebinds freely: no [!] needed and no collision even
   when exported onto twice; the landed temp stays unnamed in output (§5a.5). *)
let test_eval_export_temp_target () =
  let fd =
    eval_src (def_d ^ "export { .m as ._t } $i\nexport { .m as ._t } $i\n")
  in
  Alcotest.(check bool) "temp target not named" true
    (not (List.mem_assoc "_t" fd.Eval.named_points))

(* up to = anchor: only the top flap of a 2-layer stack folds → 3 faces *)
let test_eval_up_to_top_flap () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\nfold map .d onto .a\nfold map .c onto .d up to .c\n")
  in
  Alcotest.(check int) "3 faces" 3 (Array.length fd.Eval.state.Fold_state.faces)

(* same fold without up to: all-layers cuts both → 4 faces *)
let test_eval_all_layers_differs () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\nfold map .d onto .a\nfold map .c onto .d\n")
  in
  Alcotest.(check int) "4 faces" 4 (Array.length fd.Eval.state.Fold_state.faces)

(* four-layer stack, fold the top two: 6 faces (all-layers would be 8).
   --l/--bot are boundary reference creases and MUST be bound before the folds
   (afterwards .a/.b and .a/.d coincide on the table → "same place" error) *)
let quarter_stack_prefix =
  "paper square\n\
   mark --l = through .a .d\n\
   mark --bot = through .a .b\n\
   fold --v = map .b onto .a\n\
   fold --h = map .d onto .a\n\
   .p = --l * --h\n\
   .q = --v * --bot\n"

let test_eval_up_to_range () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         (quarter_stack_prefix ^ "fold through .p .q moving .d up to .c\n"))
  in
  Alcotest.(check int) "6 faces" 6 (Array.length fd.Eval.state.Fold_state.faces)

(* anchoring below a covering flap is a buried-anchor error *)
let test_eval_buried_anchor () =
  expect_error "cover" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              (quarter_stack_prefix ^ "fold through .p .q moving .c up to .b\n"))))

(* target flap entirely off the moving side. --m0 is precreased flat so
   .m = (1/2, 0) is a material crossing (the scar of the later --v fold lives
   only on the top flap and never reaches the bottom edge). Under ADR 0017 the
   point/flap target resolves through TargetHinged (a flap is a coplanar
   cluster, possibly several faces), so the walk-based "no flap hinged ...
   reachable" message now covers this case too — same message used when a
   `--crease` target can't be reached (test_eval_up_to_crease_unreachable) —
   rather than the old TargetFace-only "not on the moving side" wording. *)
let test_eval_up_to_wrong_side () =
  expect_error "no flap hinged" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --m0 = map .b onto .a\n\
               fold --h = map .d onto .a\n\
               fold --v = map .c onto .d up to .c\n\
               mark --bot = through .a .b\n\
               .m = --m0 * --bot\n\
               fold map .b onto .m up to .c\n")))

(* up to --crease with no reachable hinged flap *)
let test_eval_up_to_crease_unreachable () =
  expect_error "no flap hinged" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\nmark --l = through .a .d\nfold map .d onto .a up to --l\n")))

(* up to --crease: the anchor itself is hinged on it → range = anchor alone *)
let test_eval_up_to_crease_target () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         (quarter_stack_prefix ^ "fold through .p .q moving .d up to --h\n"))
  in
  Alcotest.(check int) "5 faces (top flap only)" 5
    (Array.length fd.Eval.state.Fold_state.faces)

(* moving --d: a hinge has two sides → multi-match error. Under ADR 0017,
   --d's two faces must be GENUINELY different flaps (different coplanar
   clusters) to be ambiguous — a bare precrease alone no longer suffices,
   since both faces would still be one still-flat flap. So fold ON --d's own
   line first (`@map .b onto .a moving .b`), upgrading its edge F -> V and
   splitting the two faces into different clusters, before testing the
   multi-flap error on a second, unrelated fold. *)
let test_eval_moving_line_multimatch () =
  expect_error "flaps" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               mark --d = map .b onto .a\n\
               fold map .b onto .a moving .b\n\
               fold through .a .c moving --d\n")))

(* an explicit flap that straddles the axis cannot anchor *)
let test_eval_moving_flap_straddles () =
  expect_error "straddles" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\nfold map .b onto .a moving #[.a .b]\n")))

(* ---- axiom 5: `toward` = direction semantics + paper-incidence filter ----
   Square corners a=(0,0), b=(1,0), c=(1,1), d=(0,1). *)

(* kite: left edge onto the a–c diagonal, no `toward`, no `moving` — the paper
   filter drops the −22.5° candidate (it only touches corner .a); .d lands at
   (√2⁄2, √2⁄2) via the 67.5° crease *)
let test_ax5_kite_filter () =
  let fd = eval_src "mark --ac = through .a .c\nfold map --da onto --ac\n" in
  let p = Fold_state.table_position fd.Eval.state (pt 0 1) in
  Alcotest.(check bool) ".d lands on the diagonal (x=y)" true
    (Num.equal p.Geom.x p.Geom.y);
  Alcotest.(check bool) ".d lands at x^2 = 1/2" true
    (Num.equal (Num.mul p.Geom.x p.Geom.x) half)

(* same kite selected by `toward .b`, with and without `moving .d` — both must
   land .d at the same place as the filtered fold above *)
let test_ax5_kite_toward () =
  let landing src =
    Fold_state.table_position (eval_src src).Eval.state (pt 0 1)
  in
  let p1 = landing "mark --ac = through .a .c\nfold map --da onto --ac toward .b\n" in
  let p2 =
    landing "mark --ac = through .a .c\nfold map --da onto --ac toward .b moving .d\n"
  in
  Alcotest.(check bool) "toward and toward+moving agree" true
    (Geom.point_equal p1 p2);
  Alcotest.(check bool) ".d lands at x=y, x^2=1/2" true
    (Num.equal p1.Geom.x p1.Geom.y
    && Num.equal (Num.mul p1.Geom.x p1.Geom.x) half)

(* straddle (diagonal onto anti-diagonal, hinge = sheet centre): `moving .c`
   disambiguates to the horizontal crease; .c swings onto (1,0) *)
let test_ax5_straddle_moving_unique () =
  let fd =
    eval_src
      "mark --ac = through .a .c\nmark --bd = through .b .d\n\
       fold map --ac onto --bd toward .b moving .c\n"
  in
  Alcotest.(check bool) ".c lands on (1,0)" true
    (Geom.point_equal (Fold_state.table_position fd.Eval.state (pt 1 1)) (pt 1 0))

(* .d lies in both swinging flaps of the straddle → genuinely ambiguous *)
let test_ax5_straddle_moving_both () =
  expect_error "both swinging flaps" (fun () ->
      eval_src
        "mark --ac = through .a .c\nmark --bd = through .b .d\n\
         fold map --ac onto --bd toward .b moving .d\n")

(* straddle without `moving`: both bisectors move material toward .b *)
let test_ax5_straddle_no_moving () =
  expect_error "straddles the crossing" (fun () ->
      eval_src
        "mark --ac = through .a .c\nmark --bd = through .b .d\n\
         fold map --ac onto --bd toward .b\n")

(* moving .b: neither candidate swings .b's flap toward .b *)
let test_ax5_no_viable () =
  expect_error "no fold of" (fun () ->
      eval_src
        "mark --ac = through .a .c\nmark --bd = through .b .d\n\
         fold map --ac onto --bd toward .b moving .b\n")

(* `toward .b` names a point ON l2 (bottom edge) — legal now; --k binds the
   y=x diagonal (through a and c, off the (1,0) corner) *)
let test_ax5_bind_x_on_l2 () =
  let fd = eval_src "mark --k = map --da onto --ab toward .b\n" in
  match List.assoc_opt "k" fd.Eval.named_lines with
  | Some k ->
      Alcotest.(check bool) "--k passes through (0,0)" true
        (Geom.side_of_line k (pt 0 0) = 0);
      Alcotest.(check bool) "--k passes through (1,1)" true
        (Geom.side_of_line k (pt 1 1) = 0);
      Alcotest.(check bool) "--k misses (1,0)" true
        (Geom.side_of_line k (pt 1 0) <> 0)
  | None -> Alcotest.fail "expected --k"

(* hinge at a segment endpoint: `toward .a` and `toward .b` bind different
   creases (x+y=1/2 vs x−y=1/2 — opposite sides of (1,1)) *)
let test_ax5_bind_endpoint_directions () =
  let k src =
    match List.assoc_opt "k" (eval_src src).Eval.named_lines with
    | Some k -> k
    | None -> Alcotest.fail "expected --k"
  in
  let ka = k "mark --v = map .a onto .b\nmark --k = map --v onto --ab toward .a\n" in
  let kb = k "mark --v = map .a onto .b\nmark --k = map --v onto --ab toward .b\n" in
  Alcotest.(check bool) "toward .a and toward .b differ" true
    (Geom.side_of_line ka (pt 1 1) <> Geom.side_of_line kb (pt 1 1))

(* bind, hinge at the sheet centre (two midlines crossing): both candidates
   swing material toward .b → E5-bind, hinting `at` *)
let test_ax5_bind_center_ambiguous () =
  expect_error "with `at`" (fun () ->
      eval_src
        "mark --v = map .a onto .b\n\
         mark --h = map .b onto .c\n\
         mark --k = map --v onto --h toward .b\n")

(* `toward .c` names a point ON l1 (the a–c diagonal) → E1 *)
let test_ax5_toward_on_l1 () =
  expect_error "names where the fold goes" (fun () ->
      eval_src
        "mark --ac = through .a .c\nmark --bd = through .b .d\n\
         fold map --ac onto --bd toward .c\n")

(* kite, `up to` with no `moving` and no implied anchor (axiom-5 folds have no
   implied anchor point — only line operands): the paper-incidence filter
   picks the one viable candidate silently, but `up to` still needs an
   explicit `moving` to anchor the flap range *)
let test_ax5_up_to_needs_moving () =
  expect_error "needs `moving" (fun () ->
      eval_src
        "mark --ac = through .a .c\nfold map --da onto --ac up to .c\n")

(* NOTE: E3 (no bisector lands on the paper) and E7 (implied-moving material
   straddles the crease) are geometrically unreachable on the flat square —
   both need an off-paper hinge — so they have no positive test here; the
   branches stay in eval.ml as defensive guards.

   The `toward`-given, `moving`-omitted "no fold ... moves its material
   toward" branch (the empty-viables case in select_axiom5_fold's `Some x`
   arm) is also unreachable here: the two candidate bisectors of an
   intersecting `l1`/`l2` pair always send l1's material to *opposite* rays
   of l2 (one bisector preserves the traversal order from the hinge, the
   other reverses it), and those two rays sit on opposite sides of l1. So for
   any off-l1 `toward` target, exactly one candidate always matches — the
   branch would need a degenerate hinge (material grazing a bisector exactly,
   side 0) to fire, which — like E3/E7 — needs geometry off the flat square.
   Confirmed by brute-force CLI sweep over all edge/diagonal l1×l2 pairs and
   corner `toward` targets (including derived bisector lines as l1/l2): no
   combination reached this branch. *)

let test_step_frames () =
  let src =
    "paper square\n\
     step a\n\
     mark --v = map .a onto .b\n\
     step b\n\
     mark map .d onto .c\n"
  in
  let prog = Beloch.parse ~filename:"t" src in
  let fd = Beloch.Eval.eval_folded prog in
  let tags = List.map fst fd.Beloch.Eval.frames in
  (* baseline (None) + step a + step b *)
  Alcotest.(check (list (option string))) "step tags"
    [ None; Some "a"; Some "b" ] tags;
  (* last frame state is the final state *)
  Alcotest.(check bool) "last frame is final" true
    (snd (List.nth fd.frames (List.length fd.frames - 1)) == fd.state)

(* the join selector --[.a .b] finds the same bottom edge as the prelude --ab *)
let test_select_edge () =
  let base = "paper square\nmark --v = map .a onto .b\n" in
  let fold body =
    let j = Yojson.Safe.to_string (Beloch.fold_string ~filename:"t.bel" body) in
    Str.global_replace (Str.regexp_string "--[.a .b]") "EDGE"
      (Str.global_replace (Str.regexp_string "--ab") "EDGE" j)
  in
  Alcotest.(check string) "--[.a .b] == --ab"
    (fold (base ^ "mark map --v onto --ab toward .a\n"))
    (fold (base ^ "mark map --v onto --[.a .b] toward .a\n"))

(* --[.a .c] names the diagonal, on which no crease or edge exists → error
   (no sight-lines) *)
let test_select_no_sightline () =
  expect_error "incident" (fun () ->
      ignore
        (Beloch.fold_string ~filename:"t.bel"
           "paper square\nmark --v = map .a onto .b\nmark map --v onto --[.a .c] toward .a\n"))

(* ---- Notation cutover: mark/fold/collapse verbs replace @/bare-axiom (#24) ---- *)

(* --l = <motion> is a pure value binding: no subdivide, no material *)
let test_new_value_binding_no_material () =
  let fd = eval_src "--l = map .a onto .c\n" in
  Alcotest.(check int) "one face: no subdivide happened" 1
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "no edges: no material crease" 0
    (Array.length fd.Eval.state.Fold_state.edges)

let test_new_mark_precrease () =
  let fd = eval_src "mark map .a onto .c\n" in
  Alcotest.(check int) "two faces" 2
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "one F edge" 1 (count_assign Fold_state.F fd.Eval.state)

let test_new_mark_named () =
  let fd = eval_src "mark --d = map .a onto .c\n" in
  Alcotest.(check bool) "named crease bound" true
    (List.mem_assoc "d" fd.Eval.named_lines);
  Alcotest.(check int) "one F edge" 1 (count_assign Fold_state.F fd.Eval.state)

let test_new_fold_motion () =
  let fd = eval_src "fold map .b onto .a moving .b\n" in
  Alcotest.(check int) "two faces" 2
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "one valley edge" 1 (count_assign Fold_state.V fd.Eval.state)

let test_new_fold_named () =
  let fd = eval_src "fold --d = map .b onto .a moving .b\n" in
  Alcotest.(check bool) "named crease bound" true
    (List.mem_assoc "d" fd.Eval.named_lines);
  Alcotest.(check int) "one valley edge" 1 (count_assign Fold_state.V fd.Eval.state)

(* fold along an existing material crease: --d = <motion> (value) then mark
   it (materialise), then fold along it (the old @fold path) *)
let test_new_fold_along () =
  let fd = eval_src "--d = map .b onto .a\nmark --d\nfold --d moving .b\n" in
  Alcotest.(check int) "one valley edge" 1 (count_assign Fold_state.V fd.Eval.state)

(* collapse without @, same "+" vertex fixture as test_collapse_all_layers_ok,
   with the two supporting creases materialised via `mark` instead of the
   old bare-axiom precrease *)
let test_new_collapse_no_at () =
  let fd =
    eval_src
      "mark --h = map .a onto .d\n\
       mark --v = map .a onto .b\n\
       collapse --h & #[.b] mountain and --v & #[.c] and --h & #[.d] \
       mountain and --v & #[.a] mountain\n"
  in
  Alcotest.(check int) "vertex collapse leaves 4 sector faces" 4
    (Array.length fd.Eval.state.Fold_state.faces)

let test_new_at_is_gone () =
  expect_error "syntax error" (fun () -> eval_src "@map .a onto .c moving .a\n")

(* `mark --ab` on a prelude edge must NOT promote it to Material: that would
   leak the boundary edge into beloch:named_lines (violating the documented
   invariant that prelude edges are never emitted) and give it stale-snapshot
   semantics. promote_crease is guarded to fire only on a prior Frozen
   binding (from `--d = <motion>`), never on Edge/Bundle/Material. *)
let test_new_mark_edge_does_not_leak () =
  let j =
    Beloch.fold_string ~filename:"t.bel"
      "paper square\nmark --ab\nmark map .a onto .b\n"
  in
  let open Yojson.Safe.Util in
  let named_lines = j |> member "beloch:named_lines" |> to_assoc in
  Alcotest.(check bool) "--ab is not promoted into named_lines" false
    (List.mem_assoc "ab" named_lines)

let () =
  Alcotest.run "beloch-eval"
    [
      ( "eval",
        [
          Alcotest.test_case "identical points" `Quick test_eval_identical_points;
          Alcotest.test_case "undefined point" `Quick test_eval_undefined_point;
          Alcotest.test_case "parallel cross" `Quick test_eval_parallel_cross;
          Alcotest.test_case "bisect errors" `Quick test_eval_bisect_errors;
          Alcotest.test_case "map through ambiguous" `Quick
            test_eval_map_through_ambiguous;
          Alcotest.test_case "map through same point" `Quick
            test_eval_map_through_same_point;
          Alcotest.test_case "axiom7 q already on e" `Quick
            test_axiom7_error_q_on_e;
          Alcotest.test_case "axiom7 parallel directrices" `Quick
            test_axiom7_error_parallel_directrices;
          Alcotest.test_case "map onto line parallel error" `Quick
            test_eval_map_onto_line_parallel;
          Alcotest.test_case "map onto line evaluates" `Quick
            test_eval_map_onto_line_ok;
          Alcotest.test_case "at operator selects flap piece" `Quick
            test_eval_at_flap;
          Alcotest.test_case "cross on table-bent scar works bare" `Quick
            test_eval_cross_table_bent_scar_ok;
          Alcotest.test_case "at operator no match errors" `Quick
            test_eval_at_no_match;
          Alcotest.test_case "@fold matches axiom restatement" `Quick
            test_fold_along_matches_restatement;
          Alcotest.test_case "crease all layers, @fold some" `Quick
            test_crease_all_fold_some;
          Alcotest.test_case "@fold needs moving" `Quick
            test_fold_along_needs_moving;
          Alcotest.test_case "@fold requires a material crease" `Quick
            test_fold_along_not_material;
          Alcotest.test_case "@fold on a globally bent bundle" `Quick
            test_fold_along_bent;
          Alcotest.test_case "@fold bent under the moving flaps" `Quick
            test_fold_along_bent_under_moving;
          Alcotest.test_case "@collapse standing not yet supported" `Quick
            test_collapse_standing_unsupported;
          Alcotest.test_case "@collapse n=2 hints @fold" `Quick
            test_collapse_count_two;
          Alcotest.test_case "@collapse requires a material crease" `Quick
            test_collapse_not_material;
          Alcotest.test_case "@collapse all-layers guard happy path" `Quick
            test_collapse_all_layers_ok;
          Alcotest.test_case "ax5 kite paper-incidence filter" `Quick
            test_ax5_kite_filter;
          Alcotest.test_case "ax5 kite toward + moving agree" `Quick
            test_ax5_kite_toward;
          Alcotest.test_case "ax5 straddle moving unique" `Quick
            test_ax5_straddle_moving_unique;
          Alcotest.test_case "ax5 straddle moving both flaps" `Quick
            test_ax5_straddle_moving_both;
          Alcotest.test_case "ax5 straddle no moving" `Quick
            test_ax5_straddle_no_moving;
          Alcotest.test_case "ax5 no viable candidate" `Quick
            test_ax5_no_viable;
          Alcotest.test_case "ax5 bind toward point on l2" `Quick
            test_ax5_bind_x_on_l2;
          Alcotest.test_case "ax5 bind endpoint hinge directions" `Quick
            test_ax5_bind_endpoint_directions;
          Alcotest.test_case "ax5 bind centre ambiguous" `Quick
            test_ax5_bind_center_ambiguous;
          Alcotest.test_case "ax5 toward point on l1" `Quick
            test_ax5_toward_on_l1;
          Alcotest.test_case "ax5 up to needs moving" `Quick
            test_ax5_up_to_needs_moving;
        ] );
      ( "fold_state",
        [
          Alcotest.test_case "init square" `Quick test_fold_state_init;
          Alcotest.test_case "half fold geometry" `Quick test_fold_state_half;
          Alcotest.test_case "valley moved above" `Quick test_layer_valley_moved_above;
          Alcotest.test_case "mountain moved below" `Quick test_layer_mountain_moved_below;
          Alcotest.test_case "order antisymmetry" `Quick test_layer_antisymmetry;
          Alcotest.test_case "fold quarter no Apart overlap" `Quick test_layer_fold_quarter_reversal;
          Alcotest.test_case "subdivide" `Quick test_fold_subdivide;
          Alcotest.test_case "fold records valley" `Quick test_fold_records_valley;
          Alcotest.test_case "fold records accordion" `Quick
            test_fold_records_accordion;
          Alcotest.test_case "paper preimages" `Quick test_fold_paper_preimages;
          Alcotest.test_case "precrease upgrades F to V" `Quick
            test_fold_precrease_upgrade;
          Alcotest.test_case "flip det + layer reversal" `Quick test_fold_state_flip;
          Alcotest.test_case "flip is an involution" `Quick
            test_fold_state_flip_involution;
          Alcotest.test_case "valid fold has no violation" `Quick
            test_layer_valid_examples_ok;
          Alcotest.test_case "all examples evaluate without violations" `Quick
            test_layer_all_examples_valid;
        ] );
      ( "eval_folded",
        [
          Alcotest.test_case "half fold" `Quick test_eval_folded_half;
          Alcotest.test_case "precrease subdivide" `Quick test_eval_folded_precrease;
          Alcotest.test_case "moving required" `Quick
            test_eval_folded_moving_required;
          Alcotest.test_case "quarter accordion" `Quick
            test_eval_folded_quarter_accordion;
          Alcotest.test_case "cross on multilayer crease needs at" `Quick
            test_eval_cross_multilayer_needs_at;
          Alcotest.test_case "cross multilayer with at" `Quick
            test_eval_cross_multilayer_with_at;
          Alcotest.test_case "cross beyond the marks errors" `Quick
            test_eval_cross_mark_does_not_reach;
          Alcotest.test_case "scope basic lookup" `Quick test_scope_basic_lookup;
          Alcotest.test_case "dup crease errors" `Quick
            test_eval_dup_crease_error;
          Alcotest.test_case "dup point errors" `Quick test_eval_dup_point_error;
          Alcotest.test_case "corner rebind errors" `Quick
            test_eval_corner_rebind_error;
          Alcotest.test_case "temp point rebind ok" `Quick
            test_eval_temp_rebind_ok;
          Alcotest.test_case "temp crease unnamed" `Quick
            test_eval_temp_crease_unnamed;
          Alcotest.test_case "def never runs" `Quick test_eval_def_never_runs;
          Alcotest.test_case "apply closed scope" `Quick
            test_eval_apply_closed_scope;
          Alcotest.test_case "apply binds params" `Quick
            test_eval_apply_binds_params;
          Alcotest.test_case "apply arity error" `Quick
            test_eval_apply_arity_error;
          Alcotest.test_case "apply kind error" `Quick
            test_eval_apply_kind_error;
          Alcotest.test_case "apply undefined def" `Quick
            test_eval_apply_undefined_def;
          Alcotest.test_case "dup def errors" `Quick test_eval_dup_def_error;
          Alcotest.test_case "dup param errors" `Quick
            test_eval_dup_param_error;
          Alcotest.test_case "dup instance errors" `Quick
            test_eval_dup_instance_error;
          Alcotest.test_case "instance fold names" `Quick
            test_eval_instance_fold_names;
          Alcotest.test_case "naked apply unnamed" `Quick
            test_eval_naked_apply_unnamed;
          Alcotest.test_case "temp instance unnamed" `Quick
            test_eval_temp_instance_unnamed;
          Alcotest.test_case "nested instance names" `Quick
            test_eval_nested_instance_names;
          Alcotest.test_case "self recursion rejected" `Quick
            test_eval_self_recursion_rejected;
          Alcotest.test_case "later def invisible" `Quick
            test_eval_later_def_invisible;
          Alcotest.test_case "earlier def visible" `Quick
            test_eval_earlier_def_visible;
          Alcotest.test_case "member point access" `Quick
            test_eval_member_point_access;
          Alcotest.test_case "member line access" `Quick
            test_eval_member_line_access;
          Alcotest.test_case "member undefined instance" `Quick
            test_eval_member_undefined_instance;
          Alcotest.test_case "export selective" `Quick
            test_eval_export_selective;
          Alcotest.test_case "export all" `Quick test_eval_export_all;
          Alcotest.test_case "export rename" `Quick test_eval_export_rename;
          Alcotest.test_case "export collision needs bang" `Quick
            test_eval_export_collision_needs_bang;
          Alcotest.test_case "export bang shadows" `Quick
            test_eval_export_bang_shadows;
          Alcotest.test_case "export bang without conflict" `Quick
            test_eval_export_bang_without_conflict;
          Alcotest.test_case "export unknown member" `Quick
            test_eval_export_unknown_member;
          Alcotest.test_case "export all collision" `Quick
            test_eval_export_all_collision;
          Alcotest.test_case "export temp target" `Quick
            test_eval_export_temp_target;
          Alcotest.test_case "panel tags creases" `Quick
            test_eval_panel_tags_creases;
          Alcotest.test_case "before first panel untagged" `Quick
            test_eval_before_first_panel_untagged;
          Alcotest.test_case "dup panel error" `Quick
            test_eval_dup_panel_error;
          Alcotest.test_case "apply folds land in panel" `Quick
            test_eval_apply_folds_land_in_panel;
          Alcotest.test_case "step frames" `Quick test_step_frames;
          Alcotest.test_case "up to = anchor: top flap only" `Quick
            test_eval_up_to_top_flap;
          Alcotest.test_case "all-layers differs from up-to" `Quick
            test_eval_all_layers_differs;
          Alcotest.test_case "up to range: fold top two of four" `Quick
            test_eval_up_to_range;
          Alcotest.test_case "buried anchor errors" `Quick
            test_eval_buried_anchor;
          Alcotest.test_case "up to wrong side errors" `Quick
            test_eval_up_to_wrong_side;
          Alcotest.test_case "up to crease unreachable errors" `Quick
            test_eval_up_to_crease_unreachable;
          Alcotest.test_case "up to crease target" `Quick
            test_eval_up_to_crease_target;
          Alcotest.test_case "moving line multimatch errors" `Quick
            test_eval_moving_line_multimatch;
          Alcotest.test_case "moving flap straddles errors" `Quick
            test_eval_moving_flap_straddles;
          Alcotest.test_case "select --[.a .b] == --ab" `Quick test_select_edge;
          Alcotest.test_case "select diagonal errors (no sight-line)" `Quick
            test_select_no_sightline;
        ] );
      ( "notation_cutover",
        [
          Alcotest.test_case "value binding: no material" `Quick
            test_new_value_binding_no_material;
          Alcotest.test_case "mark: precrease" `Quick test_new_mark_precrease;
          Alcotest.test_case "mark: named" `Quick test_new_mark_named;
          Alcotest.test_case "fold: motion" `Quick test_new_fold_motion;
          Alcotest.test_case "fold: named" `Quick test_new_fold_named;
          Alcotest.test_case "fold: along existing crease" `Quick
            test_new_fold_along;
          Alcotest.test_case "collapse: without @" `Quick
            test_new_collapse_no_at;
          Alcotest.test_case "@ is retired" `Quick test_new_at_is_gone;
          Alcotest.test_case "mark on prelude edge does not leak" `Quick
            test_new_mark_edge_does_not_leak;
        ] );
    ]
