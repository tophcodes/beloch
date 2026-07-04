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
               --h1 = through .a .b\n\
               --h2 = through .d .c\n\
               .x = cross --h1 --h2\n")))

let test_eval_bisect_errors () =
  expect_error "identical" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --x = through .a .c\n\
               --y = through .a .c\n\
               map --x onto --y toward .b\n")));
  expect_error "ambiguous" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --v = map .a onto .b\n\
               --h = map .b onto .c\n\
               map --v onto --h\n")));
  expect_error "on a fold line" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --d = through .a .c\n\
               --h = map .b onto .c\n\
               map --d onto --h toward .a\n")))

let test_eval_map_onto_line_parallel () =
  expect_error "parallel" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --l1 = through .a .b\n\
               --l2 = through .d .c\n\
               map .c onto --l1 perp --l2\n")))

let test_eval_map_onto_line_ok () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          --l1 = through .a .b\n\
          --l2 = through .a .d\n\
          map .c onto --l1 perp --l2\n")
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
               --bottom = through .a .b\n\
               map .d onto --bottom through .a\n")))

let test_eval_map_through_same_point () =
  expect_error "same point" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --bottom = through .a .b\n\
               map .a onto --bottom through .a\n")))

let test_axiom7_error_q_on_e () =
  expect_error "already lies on" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --top = through .d .c\n\
               --bot = through .a .b\n\
               map .a onto --bot and .d onto --top\n")))

let test_axiom7_error_parallel_directrices () =
  expect_error "parallel" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --bot = through .a .b\n\
               --top = through .d .c\n\
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
  Alcotest.(check int) "subdivide edges are U" 1 (count_assign Fold_state.U st)

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
   upgrade the abutting U crease to M/V — the fold cuts nothing, so the
   upgrade comes from the carried on-axis edge, not from a new cut. *)
let test_fold_precrease_upgrade () =
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st1 = Fold_state.subdivide Fold_state.init_square axis ~prov:None in
  let st2 =
    Fold_state.fold_with_records st1 ~axis ~move_side:1 ~valley:true ~prov:None
  in
  Alcotest.(check int) "folding a precrease yields one valley edge" 1
    (count_assign Fold_state.V st2);
  Alcotest.(check int) "the fold emits no stale U" 0
    (count_assign Fold_state.U st2)

(* #25: two fully-overlapping unit squares; face 0 is Above face 1 in `order`
   but comes first in the array, so array-position resolution would pick the
   bottom. topmost_preimage must consult `order` and return face 0's point. *)
let test_topmost_preimage_order () =
  let vline c = { Geom.a = Num.one; b = Num.zero; c = q c } in
  (* x -> x - 10, y unchanged: two reflections across vertical lines *)
  let tr10 =
    Isometry.compose
      (Isometry.reflect_across_line (vline (-5)))
      (Isometry.reflect_across_line (vline 0))
  in
  let unit_at dx = [| pt dx 0; pt (dx + 1) 0; pt (dx + 1) 1; pt dx 1 |] in
  let face0 = { Fold_state.paper = unit_at 0; iso = Isometry.identity } in
  let face1 = { Fold_state.paper = unit_at 10; iso = tr10 } in
  let st =
    {
      Fold_state.faces = [| face0; face1 |];
      order =
        Layer_order.build
          [| Fold_state.table_poly_of face0; Fold_state.table_poly_of face1 |]
          (fun _ _ -> Fold_state.Above);
      edges = [||];
    }
  in
  match Fold_state.topmost_preimage st { Geom.x = half; y = half } with
  | Some p ->
      Alcotest.(check bool) "topmost is face 0 (paper x < 1)" true
        (Geom.point_equal p { Geom.x = half; y = half })
  | None -> Alcotest.fail "expected a preimage"

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
         "paper square\n@map .b onto .a moving .b\n")
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
      (Beloch.parse ~filename:"t.bel" "paper square\nmap .a onto .c\n")
  in
  Alcotest.(check int) "two faces" 2
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "one U edge" 1
    (count_assign Fold_state.U fd.Eval.state)

let test_eval_folded_moving_required () =
  expect_error "moving" (fun () ->
      Eval.eval_folded
        (Beloch.parse ~filename:"t.bel"
           "paper square\n--d = through .a .c\n@perp --d through .b\n"))

let test_eval_folded_quarter_accordion () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n@map .b onto .a moving .b\n@map .d onto .a moving .d\n")
  in
  Alcotest.(check int) "four faces after quarter fold" 4
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "an accordion mountain appears" 1
    (count_assign Fold_state.M fd.Eval.state)

let test_eval_folded_cross_topmost () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          @map .c onto .a moving .c\n\
          --b = through .a .b\n\
          --v = map .b onto .a\n\
          .mid = cross --b --v\n")
  in
  Alcotest.(check int) "cross in a folded overlap resolves to the top layer" 4
    (Array.length fd.Eval.state.Fold_state.faces)

let test_scope_basic_lookup () =
  let r = Eval.eval_folded (Beloch.parse ~filename:"t.bel"
    "paper square\n\
     --d = through .a .c\n\
     .m = cross --d --(.a .b)\n") in
  let has_d = List.assoc_opt "d" r.Eval.named_lines <> None in
  let has_m = List.assoc_opt "m" r.Eval.named_points <> None in
  Alcotest.(check bool) "d defined" true has_d;
  Alcotest.(check bool) "m defined" true has_m

let eval_src src =
  Eval.eval_folded (Beloch.parse ~filename:"t.bel" ("paper square\n" ^ src))

let test_eval_dup_crease_error () =
  expect_error "already bound" (fun () ->
      eval_src "--x = through .a .b\n--x = through .a .c\n")

let test_eval_dup_point_error () =
  expect_error "already bound" (fun () ->
      eval_src
        "--h = through .a .b\n--v = through .a .d\n.x = cross --h --v\n\
         .x = cross --h --v\n")

let test_eval_corner_rebind_error () =
  expect_error "already bound" (fun () ->
      eval_src "--h = through .a .b\n--v = through .a .d\n.a = cross --h --v\n")

let test_eval_temp_rebind_ok () =
  let fd =
    eval_src
      "--h = through .a .b\n--v = through .a .d\n._x = cross --h --v\n\
       ._x = cross --v --h\n"
  in
  Alcotest.(check bool)
    "temp not in named_points" true
    (not (List.mem_assoc "_x" fd.Eval.named_points))

let test_eval_temp_crease_unnamed () =
  let fd = eval_src "--_t = through .a .c\n" in
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
      "def diag(.p .q) {\n  --d = through .p .q\n}\n$i = apply diag(.a .c)\n"
  in
  Alcotest.(check int) "one crease" 1
    (Array.length fd.Eval.state.Fold_state.edges)

let test_eval_apply_arity_error () =
  expect_error "argument" (fun () ->
      eval_src "def diag(.p .q) {\n  --d = through .p .q\n}\napply diag(.a)\n")

let test_eval_apply_kind_error () =
  expect_error "point argument" (fun () ->
      eval_src
        "def d(.p) {\n  --x = perp --(.a .b) through .p\n}\n\
         apply d(--(.a .b))\n")

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
    eval_src "def d(.p .q) {\n  --x = through .p .q\n}\n$i = apply d(.a .c)\n"
  in
  Alcotest.(check bool) "crease named i.x" true
    (List.mem "i.x" (prov_names fd))

let test_eval_naked_apply_unnamed () =
  let fd =
    eval_src "def d(.p .q) {\n  --x = through .p .q\n}\napply d(.a .c)\n"
  in
  Alcotest.(check int) "no named provenance" 0 (List.length (prov_names fd))

let test_eval_temp_instance_unnamed () =
  let fd =
    eval_src "def d(.p .q) {\n  --x = through .p .q\n}\n$_i = apply d(.a .c)\n"
  in
  Alcotest.(check int) "no named provenance" 0 (List.length (prov_names fd))

let test_eval_nested_instance_names () =
  let fd =
    eval_src
      "def inner(.p .q) {\n  --pq = through .p .q\n}\n\
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
      "def inner(.p .q) {\n  --l = through .p .q\n}\n\
       def outer(.p .q) {\n  apply inner(.p .q)\n}\n\
       apply outer(.a .c)\n"
  in
  Alcotest.(check int) "one crease" 1
    (Array.length fd.Eval.state.Fold_state.edges)

let test_eval_member_point_access () =
  let fd =
    eval_src
      "--h = through .a .b\n\
       def d(.p .q --base) {\n\
      \  --l = through .p .q\n\
      \  .m = cross --l --base\n\
       }\n\
       $i = apply d(.d .b --h)\n\
       --thru = through .[$i m] .c\n"
  in
  Alcotest.(check bool) "crease thru exists" true
    (List.mem_assoc "thru" fd.Eval.named_lines)

let test_eval_member_line_access () =
  let fd =
    eval_src
      "def d(.p .q) {\n  --l = through .p .q\n}\n\
       $i = apply d(.a .c)\n\
       .x = cross --[$i l] --(.a .b)\n"
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
      "step first\n--x = through .a .c\nstep second\n--y = through .b .d\n"
  in
  Alcotest.(check bool) "first tagged" true (List.mem "first" (prov_steps fd));
  Alcotest.(check bool) "second tagged" true
    (List.mem "second" (prov_steps fd))

(* one crease stmt can yield several records (one per crossed face) — assert tag partition, not counts *)
let test_eval_before_first_panel_untagged () =
  let fd = eval_src "--x = through .a .c\nstep p\n--y = through .b .d\n" in
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
      "def d(.p .q) {\n  --l = through .p .q\n}\n\
       step body\n$i = apply d(.a .c)\n"
  in
  Alcotest.(check bool) "tagged body" true (List.mem "body" (prov_steps fd))

let test_eval_member_unknown () =
  expect_error "no point member" (fun () ->
      eval_src
        "def d(.p .q) {\n  --l = through .p .q\n}\n\
         $i = apply d(.a .c)\n--z = through .[$i nope] .b\n")

let test_eval_member_kind_mismatch () =
  expect_error "no point member" (fun () ->
      eval_src
        "def d(.p .q) {\n  --l = through .p .q\n}\n\
         $i = apply d(.a .c)\n--z = through .[$i l] .b\n")

let test_eval_member_undefined_instance () =
  expect_error "undefined instance" (fun () ->
      eval_src "--z = through .[$ghost m] .b\n")

let def_d =
  "def d(.p .q .r) {\n\
  \  --l1 = through .p .q\n\
  \  --l2 = through .p .r\n\
  \  .m = cross --l1 --(.q .r)\n\
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
      eval_src ("--l1 = through .a .b\n" ^ def_d ^ "export { --l1 } $i\n"))

let test_eval_export_bang_shadows () =
  let fd =
    eval_src ("--l1 = through .a .b\n" ^ def_d ^ "export { --l1! } $i\n")
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

let test_step_frames () =
  let src =
    "paper square\n\
     step a\n\
     --v = map .a onto .b\n\
     step b\n\
     map .d onto .c\n"
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
          Alcotest.test_case "precrease upgrades U to V" `Quick
            test_fold_precrease_upgrade;
          Alcotest.test_case "topmost preimage via order" `Quick
            test_topmost_preimage_order;
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
          Alcotest.test_case "member unknown" `Quick
            test_eval_member_unknown;
          Alcotest.test_case "member kind mismatch" `Quick
            test_eval_member_kind_mismatch;
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
        ] );
    ]
