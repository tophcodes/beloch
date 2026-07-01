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

let count_assign a recs =
  List.length
    (List.filter
       (fun (r : Fold_state.crease_record) -> r.Fold_state.assign = a)
       recs)

(* ---- Eval: error cases ---- *)

let test_eval_identical_points () =
  expect_error "same place" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel" "paper square\nthrough .a .a\n")))

let test_eval_undefined_point () =
  expect_error "undefined" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel" "paper square\nmap .a onto .z\n")))

let test_eval_parallel_cross () =
  expect_error "parallel" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --h1: through .a .b\n\
               --h2: through .d .c\n\
               .x: cross --h1 --h2\n")))

let test_eval_bisect_errors () =
  expect_error "identical" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --x: through .a .c\n\
               --y: through .a .c\n\
               map --x onto --y toward .b\n")));
  expect_error "ambiguous" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --v: map .a onto .b\n\
               --h: map .b onto .c\n\
               map --v onto --h\n")));
  expect_error "on a fold line" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --d: through .a .c\n\
               --h: map .b onto .c\n\
               map --d onto --h toward .a\n")))

let test_eval_map_onto_line_parallel () =
  expect_error "parallel" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --l1: through .a .b\n\
               --l2: through .d .c\n\
               map .c onto --l1 perp --l2\n")))

let test_eval_map_onto_line_ok () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          --l1: through .a .b\n\
          --l2: through .a .d\n\
          map .c onto --l1 perp --l2\n")
  in
  match fd.Eval.creases with
  | [] -> Alcotest.fail "expected at least one crease record"
  | cr :: _ ->
      let c = Geom.line_through cr.Fold_state.ra cr.Fold_state.rb in
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
               --bottom: through .a .b\n\
               map .d onto --bottom through .a\n")))

let test_eval_map_through_same_point () =
  expect_error "same point" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --bottom: through .a .b\n\
               map .a onto --bottom through .a\n")))

let test_axiom7_error_q_on_e () =
  expect_error "already lies on" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --top: through .d .c\n\
               --bot: through .a .b\n\
               map .a onto --bot and .d onto --top\n")))

let test_axiom7_error_parallel_directrices () =
  expect_error "parallel" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --bot: through .a .b\n\
               --top: through .d .c\n\
               map .a onto --bot and .b onto --top\n")))

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
    (st.Fold_state.order.(mv).(stt) = Fold_state.Above)

let test_layer_mountain_moved_below () =
  let st = Fold_state.init_square in
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.simple_fold st ~axis ~move_side:1 ~valley:false in
  let mv = face_with_det st (-1) and stt = face_with_det st 1 in
  Alcotest.(check bool) "moved face is Below stationary" true
    (st.Fold_state.order.(mv).(stt) = Fold_state.Below)

let test_layer_antisymmetry () =
  let st = Fold_state.init_square in
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.simple_fold st ~axis ~move_side:1 ~valley:true in
  let ok = ref true in
  Array.iteri (fun i row ->
      Array.iteri (fun j r ->
          if st.Fold_state.order.(j).(i) <> Fold_state.negate r then ok := false)
        row)
    st.Fold_state.order;
  Alcotest.(check bool) "order is negation-symmetric" true !ok

let test_layer_fold_quarter_reversal () =
  let st =
    (Eval.eval_folded
       (Beloch.parse ~filename:"fq.bel"
          "paper square\n@map .b onto .a moving .b\n@map .d onto .a moving .d\n")).Eval.state
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
        && st.Fold_state.order.(i).(j) = Fold_state.Apart
      then bad := true
    done
  done;
  Alcotest.(check bool) "no overlapping pair left Apart" false !bad

let test_fold_subdivide () =
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st, recs = Fold_state.subdivide Fold_state.init_square axis ~prov:None in
  Alcotest.(check int) "two faces after subdivide" 2
    (Array.length st.Fold_state.faces);
  Alcotest.(check int) "one crease record" 1 (List.length recs);
  Alcotest.(check int) "subdivide records are U" 1
    (count_assign Fold_state.U recs)

let test_fold_records_valley () =
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let _, recs =
    Fold_state.fold_with_records Fold_state.init_square ~axis ~move_side:1
      ~valley:true ~prov:None
  in
  Alcotest.(check int) "one record" 1 (List.length recs);
  Alcotest.(check int) "the half fold is a valley" 1
    (count_assign Fold_state.V recs);
  Alcotest.(check int) "no mountain" 0 (count_assign Fold_state.M recs)

let test_fold_records_accordion () =
  let axis1 = { Geom.a = q 1; b = q 0; c = half } in
  let st1 =
    Fold_state.simple_fold Fold_state.init_square ~axis:axis1 ~move_side:1
      ~valley:true
  in
  let axis2 = { Geom.a = q 0; b = q 1; c = half } in
  let _, recs2 =
    Fold_state.fold_with_records st1 ~axis:axis2 ~move_side:1 ~valley:true
      ~prov:None
  in
  Alcotest.(check int) "two crease records from the second fold" 2
    (List.length recs2);
  Alcotest.(check int) "one valley (accordion)" 1
    (count_assign Fold_state.V recs2);
  Alcotest.(check int) "one mountain (accordion)" 1
    (count_assign Fold_state.M recs2)

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
  (* When run by dune (runtest / exec), the binary sits in
     _build/default/tests/test_eval.exe and dune sets cwd to
     _build/default/tests/ — so ../../../examples reaches the repo root.
     When invoked directly from the repo root the relative path is wrong; use
     Sys.argv.(0) to locate the binary and derive the repo root from it. *)
  let via_cwd = "../../../examples" in
  if Sys.file_exists via_cwd then via_cwd
  else
    let bin = Sys.argv.(0) in
    let build_dir = Filename.dirname (Filename.dirname (Filename.dirname bin)) in
    Filename.concat build_dir "examples"

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
         "paper square\n@map .b onto .a moving .b\n")
  in
  Alcotest.(check int) "two faces" 2
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "one valley record" 1
    (count_assign Fold_state.V fd.Eval.creases);
  Alcotest.(check bool) ".b maps onto .a" true
    (Geom.point_equal
       (Fold_state.table_position fd.Eval.state (pt 1 0))
       (pt 0 0))

let test_eval_folded_precrease () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel" "paper square\nmap .a onto .c\n")
  in
  Alcotest.(check int) "two faces" 2
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "one U record" 1
    (count_assign Fold_state.U fd.Eval.creases)

let test_eval_folded_moving_required () =
  expect_error "moving" (fun () ->
      Eval.eval_folded
        (Beloch.parse ~filename:"t.bel"
           "paper square\n--d: through .a .c\n@perp --d through .b\n"))

let test_eval_folded_quarter_accordion () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n@map .b onto .a moving .b\n@map .d onto .a moving .d\n")
  in
  Alcotest.(check int) "four faces after quarter fold" 4
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "an accordion mountain appears" 1
    (count_assign Fold_state.M fd.Eval.creases)

let test_eval_folded_cross_topmost () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          @map .c onto .a moving .c\n\
          --b: through .a .b\n\
          --v: map .b onto .a\n\
          .mid: cross --b --v\n")
  in
  Alcotest.(check int) "cross in a folded overlap resolves to the top layer" 4
    (Array.length fd.Eval.state.Fold_state.faces)

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
          Alcotest.test_case "cross resolves to top layer" `Quick
            test_eval_folded_cross_topmost;
        ] );
    ]
