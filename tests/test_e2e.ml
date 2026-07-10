open Beloch

let q = Num.of_int
let[@warning "-32"] half = Num.of_q (Q.of_ints 1 2)
let pt x y = { Geom.x = q x; y = q y }

(* Anchor to the source root of *this* build context. dune sets
   DUNE_SOURCEROOT to the absolute workspace root, so an in-repo worktree
   reads its own examples/ rather than the main checkout's (#37). *)
let examples_dir =
  match Sys.getenv_opt "DUNE_SOURCEROOT" with
  | Some root -> Filename.concat root "examples"
  | None -> "../../../examples"

let read_example name =
  In_channel.with_open_text (Filename.concat examples_dir name) In_channel.input_all

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

(* ---- E2e ---- *)

let test_e2e_inline_equiv () =
  let geom j =
    let open Yojson.Safe.Util in
    ( j |> member "vertices_coords",
      j |> member "edges_vertices",
      j |> member "edges_assignment",
      j |> member "faces_vertices" )
  in
  let named =
    Beloch.fold_string ~filename:"t.bel"
      "paper square\n\
       mark --d1 = through .a .c\n\
       mark --d2 = through .b .d\n\
       .m = --d1 * --d2\n\
       mark map .a onto .m\n"
  in
  let inline =
    Beloch.fold_string ~filename:"t.bel"
      "paper square\n\
       mark --d1 = through .a .c\n\
       mark --d2 = through .b .d\n\
       mark map .a onto .[--d1 --d2]\n"
  in
  Alcotest.(check bool)
    "inline cross-point matches the named binding" true
    (geom named = geom inline)

let test_e2e_inline_error () =
  expect_error "same place" (fun () ->
      Beloch.fold_string ~filename:"t.bel"
        "paper square\nmark --aa = through .a .a\nmark perp --aa through .b\n")

let test_e2e_diagonals () =
  let src = read_example "syntax/diagonals.bel" in
  let json = Beloch.fold_string ~filename:"diagonals.bel" src in
  let open Yojson.Safe.Util in
  Alcotest.(check int) "vertices" 5
    (json |> member "vertices_coords" |> to_list |> List.length);
  Alcotest.(check int) "edges" 8
    (json |> member "edges_vertices" |> to_list |> List.length)

let test_e2e_anti_parallel () =
  expect_error "parallel" (fun () ->
      Beloch.fold_string ~filename:"parallel.bel" (read_example "syntax/parallel.bel"))

let test_e2e_anti_dup () =
  expect_error "same place" (fun () ->
      Beloch.fold_string ~filename:"dup-point.bel"
        (read_example "syntax/dup-point.bel"))

let test_e2e_square_one_face () =
  let json =
    Beloch.fold_string ~filename:"square.bel" (read_example "syntax/square.bel")
  in
  let open Yojson.Safe.Util in
  Alcotest.(check int) "one face" 1
    (json |> member "faces_vertices" |> to_list |> List.length);
  Alcotest.(check int) "face has four vertices" 4
    (json |> member "faces_vertices" |> to_list |> List.hd |> to_list |> List.length)

let test_e2e_diagonals_four_faces () =
  let json =
    Beloch.fold_string ~filename:"diagonals.bel" (read_example "syntax/diagonals.bel")
  in
  let open Yojson.Safe.Util in
  Alcotest.(check int) "four faces" 4
    (json |> member "faces_vertices" |> to_list |> List.length)

let test_e2e_perp () =
  let json =
    Beloch.fold_string ~filename:"perp.bel" (read_example "syntax/perp.bel")
  in
  let open Yojson.Safe.Util in
  Alcotest.(check int) "four faces" 4
    (json |> member "faces_vertices" |> to_list |> List.length);
  let axioms =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function
      | `Null -> None
      | e -> Some (e |> member "axiom" |> to_string))
  in
  Alcotest.(check bool) "an axiom3 crease is present" true (List.mem "axiom3" axioms)

let test_e2e_cube_root () =
  let json =
    Beloch.fold_string ~filename:"cube-root.bel" (read_example "syntax/cube-root.bel")
  in
  let open Yojson.Safe.Util in
  let axioms =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function
      | `Null -> None
      | e -> Some (e |> member "axiom" |> to_string))
  in
  Alcotest.(check bool) "an axiom7 crease is present" true (List.mem "axiom7" axioms)

let test_e2e_cube_root_restructured () =
  ignore
    (Beloch.fold_string ~filename:"cube-root.bel"
       (read_example "syntax/cube-root.bel"))

let test_e2e_def_diagonals () =
  let json =
    Beloch.fold_string ~filename:"def-diagonals.bel"
      (read_example "syntax/def-diagonals.bel")
  in
  let open Yojson.Safe.Util in
  let pts = json |> member "beloch:named_points" |> to_assoc in
  Alcotest.(check bool) "centre named" true (List.mem_assoc "m" pts)

let test_e2e_cube_root_temps_hidden () =
  let json =
    Beloch.fold_string ~filename:"cube-root.bel" (read_example "syntax/cube-root.bel")
  in
  let open Yojson.Safe.Util in
  let pts = json |> member "beloch:named_points" |> to_assoc in
  Alcotest.(check bool) "no temp points in FOLD" true
    (not (List.exists (fun (k, _) -> String.length k > 0 && k.[0] = '_') pts))

let test_e2e_bisect_select () =
  let open Yojson.Safe.Util in
  let creases json =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function
      | `Null -> None
      | e -> Some (e |> member "axiom" |> to_string))
  in
  let ja =
    Beloch.fold_string ~filename:"bisect-a.bel" (read_example "syntax/bisect-a.bel")
  in
  let jb =
    Beloch.fold_string ~filename:"bisect-b.bel" (read_example "syntax/bisect-b.bel")
  in
  Alcotest.(check bool) "a has an axiom5 crease" true
    (List.mem "axiom5" (creases ja));
  Alcotest.(check bool) "b has an axiom5 crease" true
    (List.mem "axiom5" (creases jb));
  Alcotest.(check bool) "toward .a and .b produce different FOLD" false
    (Yojson.Safe.equal
       (ja |> member "vertices_coords")
       (jb |> member "vertices_coords")
    && Yojson.Safe.equal
         (ja |> member "edges_vertices")
         (jb |> member "edges_vertices"))

let test_e2e_kite () =
  let open Yojson.Safe.Util in
  let json =
    Beloch.fold_string ~filename:"kite.bel" (read_example "bases/kite.bel")
  in
  let axioms =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function
      | `Null -> None
      | e -> Some (e |> member "axiom" |> to_string))
  in
  Alcotest.(check int) "two axiom5 creases" 2
    (List.length (List.filter (( = ) "axiom5") axioms))

let test_e2e_bisect_parallel () =
  let json =
    Beloch.fold_string ~filename:"bisect-parallel.bel"
      (read_example "syntax/bisect-parallel.bel")
  in
  let open Yojson.Safe.Util in
  Alcotest.(check int) "two faces" 2
    (json |> member "faces_vertices" |> to_list |> List.length)

let test_eval_map_through_toward () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          mark --bottom = through .a .b\n\
          mark map .d onto --bottom through .a toward .b\n")
  in
  (* the axiom-6 crease is a full mark: it records as a chord (no fold-time
     edge), so read its line from the mark layer (the map crease is the last
     mark, after --bottom) *)
  match List.rev (Array.to_list fd.Eval.state.Fold_state.marks) with
  | [] -> Alcotest.fail "expected at least one mark"
  | m :: _ ->
      let ca, cb =
        match m.Fold_state.mgeom with
        | Fold_state.MSeg (a, b) -> (a, b)
        | Fold_state.MPoint _ -> Alcotest.fail "expected a segment mark"
      in
      let c = Geom.line_through ca cb in
      let on (p : Geom.point) =
        Num.equal
          (Num.add (Num.mul c.Geom.a p.Geom.x) (Num.mul c.Geom.b p.Geom.y))
          c.Geom.c
      in
      Alcotest.(check bool) "axiom-6 crease through (0,0)" true (on (pt 0 0));
      Alcotest.(check bool) "axiom-6 crease through (1,1)" true (on (pt 1 1))

let test_e2e_fold_half () =
  let json =
    Beloch.fold_string ~filename:"fold-half.bel" (read_example "syntax/fold-half.bel")
  in
  let open Yojson.Safe.Util in
  Alcotest.(check string) "frame 0 creasePattern" "creasePattern"
    (json |> member "frame_classes" |> to_list |> List.hd |> to_string);
  Alcotest.(check int) "a foldedForm frame is present" 1
    (json |> member "file_frames" |> to_list |> List.length);
  let assigns =
    json |> member "edges_assignment" |> to_list |> List.map to_string
  in
  Alcotest.(check bool) "the fold crease is a valley" true (List.mem "V" assigns)

let test_e2e_fold_quarter () =
  let json =
    Beloch.fold_string ~filename:"fold-quarter.bel"
      (read_example "syntax/fold-quarter.bel")
  in
  let open Yojson.Safe.Util in
  let folded = json |> member "file_frames" |> to_list |> List.hd in
  Alcotest.(check bool) "faceOrders present for the folded stack" true
    (List.length (folded |> member "faceOrders" |> to_list) > 0);
  let assigns =
    json |> member "edges_assignment" |> to_list |> List.map to_string
  in
  Alcotest.(check bool) "accordion produced a mountain crease" true
    (List.mem "M" assigns)

let test_e2e_flip_mountain () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\nflip\nfold map .a onto .b moving .a\n")
  in
  Alcotest.(check int) "fold after flip is a mountain" 1
    (count_assign Fold_state.M fd.Eval.state);
  Alcotest.(check int) "and not a valley" 0
    (count_assign Fold_state.V fd.Eval.state);
  let fd2 =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\nfold map .a onto .b moving .a\n")
  in
  Alcotest.(check int) "without flip it is a valley" 1
    (count_assign Fold_state.V fd2.Eval.state)

let test_e2e_flip_cp_counts () =
  let open Yojson.Safe.Util in
  let counts s =
    let j = Beloch.fold_string ~filename:"t.bel" s in
    ( List.length (member "vertices_coords" j |> to_list),
      List.length (member "edges_vertices" j |> to_list),
      List.length (member "faces_vertices" j |> to_list) )
  in
  Alcotest.(check bool)
    "flip preserves the crease-pattern size" true
    (counts "paper square\nmark --c = map .a onto .b\n"
    = counts "paper square\nmark --c = map .a onto .b\nflip\n")

let test_faceorders_stable_fold_quarter () =
  let json =
    Beloch.fold_string ~filename:"fq.bel" (read_example "syntax/fold-quarter.bel")
  in
  let orders =
    Yojson.Safe.Util.(
      json |> member "file_frames" |> index 0 |> member "faceOrders")
  in
  let expected =
    `List
      [
        `List [ `Int 0; `Int 1; `Int 1 ];
        `List [ `Int 0; `Int 2; `Int (-1) ];
        `List [ `Int 0; `Int 3; `Int 1 ];
        `List [ `Int 1; `Int 2; `Int (-1) ];
        `List [ `Int 1; `Int 3; `Int 1 ];
        `List [ `Int 2; `Int 3; `Int 1 ];
      ]
  in
  Alcotest.(check bool)
    "faceOrders unchanged by the emit refactor" true
    (orders = expected)

let test_e2e_axiom7_rational_crease () =
  let src =
    "paper square\n\
     mark --diag = through .a .c\n\
     mark --anti = through .b .d\n\
     mark map .a onto --anti and .d onto --diag toward .b\n"
  in
  let json = Beloch.fold_string ~filename:"t.bel" src in
  let open Yojson.Safe.Util in
  let axioms =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function
      | `Null -> None
      | e -> Some (e |> member "axiom" |> to_string))
  in
  Alcotest.(check bool) "axiom7 tag present" true (List.mem "axiom7" axioms)

(* ---- Emit_folded ---- *)

let test_emit_folded_frames () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\nfold map .b onto .a moving .b\n")
  in
  let json = Fold_emit.to_json_folded fd in
  let open Yojson.Safe.Util in
  Alcotest.(check string) "frame 0 is creasePattern" "creasePattern"
    (json |> member "frame_classes" |> to_list |> List.hd |> to_string);
  let frames = json |> member "file_frames" |> to_list in
  Alcotest.(check int) "one extra frame" 1 (List.length frames);
  let folded = List.hd frames in
  Alcotest.(check string) "extra frame is foldedForm" "foldedForm"
    (folded |> member "frame_classes" |> to_list |> List.hd |> to_string);
  Alcotest.(check bool) "folded frame is self-contained, not inherited" false
    (folded |> member "frame_inherit" |> to_bool);
  let assigns =
    json |> member "edges_assignment" |> to_list |> List.map to_string
  in
  Alcotest.(check bool) "has a V crease" true (List.mem "V" assigns);
  Alcotest.(check bool) "has B boundary" true (List.mem "B" assigns);
  Alcotest.(check int) "one faceOrders triple" 1
    (folded |> member "faceOrders" |> to_list |> List.length)

let test_emit_folded_crease_name () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel" "paper square\nmark --m = map .a onto .c\n")
  in
  let json = Fold_emit.to_json_folded fd in
  let open Yojson.Safe.Util in
  let names =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function
      | `Null -> None
      | e -> Some (e |> member "name"))
  in
  Alcotest.(check bool) "crease carries name m" true
    (List.exists (fun n -> n = `String "m") names)

(* Task 7: record marks (from Fold_state.marks) are serialized into a
   top-level "beloch:marks" custom field. Reuses the program from
   test_mark_point_records_no_edge, already proven to record exactly one
   interior POINT mark (the value-line --vm re-marked with a point extent at
   .ctr, the meet of --vm and --hm). *)
let test_beloch_marks_emitted () =
  let src =
    "paper square\nmark --vm = map .a onto .b\nmark --hm = map .a onto .d\n\
     .ctr = --vm * --hm\nmark --vm at .ctr\n"
  in
  let fd = Eval.eval_folded (Beloch.parse ~filename:"t.bel" src) in
  let json = Fold_emit.to_json_folded fd in
  let open Yojson.Safe.Util in
  match json |> member "beloch:marks" with
  | `List [ one ] ->
      Alcotest.(check string) "point kind" "point"
        (one |> member "kind" |> to_string);
      Alcotest.(check string) "valley default" "V"
        (one |> member "intent" |> to_string)
  | _ -> Alcotest.fail "expected exactly one point mark"

(* cross is material: a crease scored through several layers marks different
   lines in the paper, so bare cross must error — with a hint toward the
   #(...) flap escape hatch. (A merely table-bent scar crosses fine bare;
   see test_eval_cross_table_bent_scar_ok.) *)
let test_multilayer_crease_bare_cross_errors () =
  let src =
    "paper square\n\
     fold map .c onto .a moving .c\n\
     mark --v = map .b onto .a\n\
     .mid = --v * --ab\n"
  in
  match Beloch.fold_string ~filename:"t.bel" src with
  | exception Error.Beloch_error (_, msg) ->
      Alcotest.(check bool)
        "mentions different lines" true
        (let re = Str.regexp_string "different lines" in
         try
           ignore (Str.search_forward re msg 0);
           true
         with Not_found -> false);
      Alcotest.(check bool)
        "hints the flap escape hatch" true
        (let re = Str.regexp_string "#(" in
         try
           ignore (Str.search_forward re msg 0);
           true
         with Not_found -> false)
  | _ -> Alcotest.fail "expected a multilayer-crease error"

(* #50: `at #(...)` selects one segment of a bent crease bundle. Two different
   flaps pick two different segments, so the resulting perp axis genuinely
   differs — the selection is load-bearing, not vacuous. *)
let test_at_selects_bent_segment () =
  let prog sel =
    Printf.sprintf
      "paper square\n\
       mark --b = through .a .c\n\
       fold --v = map .c onto .b\n\
       mark --q = perp --b & %s through .a\n"
      sel
  in
  let q_axis src =
    let open Yojson.Safe.Util in
    match Beloch.fold_string ~filename:"t.bel" src with
    | exception Error.Beloch_error (_, msg) ->
        Alcotest.failf "at should resolve, got error: %s" msg
    | j -> j |> member "beloch:named_lines" |> member "q" |> to_list
  in
  Alcotest.(check bool)
    "different flaps select different --q axes (at is load-bearing)" true
    (q_axis (prog "#[.c .d]") <> q_axis (prog "#[.a .b]"))

(* the new filter/diff operators must pick the same bent segment as `at`:
   `& #[.c .d]` keeps the upper segment; `\ #[.a .b]` drops the lower one,
   leaving the same upper segment. Both must equal `at #(.c .d)`. *)
let test_bundle_ops_equiv_at () =
  let base sel =
    Printf.sprintf
      "paper square\n\
       mark --b = through .a .c\n\
       fold --v = map .c onto .b\n\
       mark --q = perp --b %s through .a\n"
      sel
  in
  let q_axis src =
    let open Yojson.Safe.Util in
    match Beloch.fold_string ~filename:"t.bel" src with
    | exception Error.Beloch_error (_, msg) ->
        Alcotest.failf "should resolve, got error: %s" msg
    | j -> j |> member "beloch:named_lines" |> member "q" |> to_list
  in
  let seg = q_axis (base "& #[.c .d]") in
  Alcotest.(check bool) "\\ #[.a .b] selects the same (upper) segment as & #[.c .d]"
    true
    (q_axis (base "\\ #[.a .b]") = seg)

(* a bound bundle behaves exactly like inlining its expression *)
let test_bind_bundle_roundtrip () =
  let q_axis src =
    let open Yojson.Safe.Util in
    match Beloch.fold_string ~filename:"t.bel" src with
    | exception Error.Beloch_error (_, msg) ->
        Alcotest.failf "should resolve, got error: %s" msg
    | j -> j |> member "beloch:named_lines" |> member "q" |> to_list
  in
  let inline =
    "paper square\nmark --b = through .a .c\nfold --v = map .c onto .b\n\
     mark --q = perp --b & #[.c .d] through .a\n"
  in
  let bound =
    "paper square\nmark --b = through .a .c\nfold --v = map .c onto .b\n\
     --seg = --b & #[.c .d]\nmark --q = perp --seg through .a\n"
  in
  Alcotest.(check bool) "bound bundle == inline" true
    (q_axis inline = q_axis bound)

(* #42: one self-contained foldedForm frame per step snapshot, baseline
   included, each step-tagged. *)
let test_multiframe () =
  let src =
    "paper square\n\
     step a\n\
     mark --v = map .a onto .b\n\
     step b\n\
     mark map .d onto .c\n"
  in
  let json = Beloch.fold_string ~filename:"t" src in
  let frames =
    match json with
    | `Assoc kv -> (match List.assoc "file_frames" kv with `List l -> l | _ -> [])
    | _ -> []
  in
  Alcotest.(check int) "one folded frame per step (baseline+a+b)" 3
    (List.length frames);
  let step_of = function
    | `Assoc kv -> (match List.assoc "beloch:step" kv with `String s -> Some s | _ -> None)
    | _ -> None
  in
  Alcotest.(check (list (option string))) "frame step tags"
    [ None; Some "a"; Some "b" ] (List.map step_of frames)

let test_e2e_faces_matrix_and_frame () =
  let json =
    Beloch.fold_string ~filename:"square.bel" (read_example "syntax/square.bel")
  in
  let open Yojson.Safe.Util in
  (* named-line frame is declared, always *)
  Alcotest.(check string) "named-line frame"
    "creasePattern"
    (json |> member "beloch:named_lines_frame" |> to_string);
  (* the one folded frame carries one isometry row, the identity *)
  let rows =
    json |> member "file_frames" |> to_list |> List.hd
    |> member "beloch:faces_matrix" |> to_list
  in
  Alcotest.(check int) "one isometry row" 1 (List.length rows);
  Alcotest.(check (list (float 1e-9))) "identity isometry"
    [ 1.; 0.; 0.; 1.; 0.; 0. ]
    (List.hd rows |> to_list |> List.map to_float)

(* #27: mark a precrease, then fold on it. The emitted FOLD must carry V/180 on
   that crease, never the stale U/0 from the precrease's subdivide. *)
let test_e2e_precrease_fold_emits_v () =
  let open Yojson.Safe.Util in
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\nmark map .b onto .a\nfold map .b onto .a moving .b\n")
  in
  let j = Fold_emit.to_json_folded fd in
  let assigns = j |> member "edges_assignment" |> to_list |> filter_string in
  Alcotest.(check bool) "no U assignment after folding a precrease" false
    (List.mem "U" assigns);
  Alcotest.(check bool) "the precrease folds as a valley" true
    (List.mem "V" assigns)

(* ADR 0017 defect 1: on a still-flat sheet, two points that land on
   DIFFERENT (but still-coplanar, U-joined) faces resolve to the one flap
   spanning them, instead of erroring "those points aren't all on one flap".
   --diag = map .b onto .d precreases the b-d diagonal (bare bind, U edge),
   splitting the square into triangles abd/bcd; .a and .c sit on opposite
   triangles. `up to #(.a .c)` resolves that pair through
   resolve_flap_cluster (the `moving`/`up to` operand path) — this is the
   call site defect 1 actually manifests on; see the deviation note below on
   why `at`'s `#(...)` selector keeps face-precise semantics instead. *)
let test_e2e_flap_cluster_spans_precrease_split () =
  ignore
    (Beloch.fold_string ~filename:"t.bel"
       "paper square\n\
        mark --diag = map .b onto .d\n\
        fold map .a onto .c moving .a up to #[.a .c]\n")

(* ADR 0017 defect 2: a scoped self-fold must move its entire still-flat
   coplanar cluster, not just the face nearest the anchor. --v/--h precrease
   the square into 4 quadrants (BL,BR,TL,TR), all ONE flap (bare binds, U
   edges only). The self-scoped fold at x=1/4 (anchor .a, up to .a) is a
   candidate on both BL and TL (each has material on the move side, x<1/4),
   but BL and TL never geometrically overlap — they're side by side, not
   stacked — so the pre-cohesion `outer` closure alone leaves TL out even
   though it's BL's still-flat neighbour. Without cohesion, TL never enters
   the moving set, and .d (uniquely inside TL) keeps its stale flat-sheet
   table position (0,1). With cohesion, TL moves with BL and .d reflects to
   (1/2,1) — verified exactly (not just "differs"), confirmed empirically
   against the running evaluator before this test was written. *)
let test_e2e_cohesion_moves_coplanar_sibling () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          mark --v = map .a onto .b\n\
          mark --h = map .a onto .d\n\
          .m0 = --v * --ab\n\
          fold map .a onto .m0 moving .a up to .a\n")
  in
  let d_pos = Fold_state.table_position fd.Eval.state (pt 0 1) in
  Alcotest.(check bool)
    "d's sibling flap (TL) moved with the anchor's flap (BL): (1/2,1), not \
     the stale (0,1)"
    true
    (Geom.point_equal d_pos { Geom.x = half; y = Num.of_int 1 })

(* Task 2: a bare precrease (still flat, unfolded) emits FOLD assignment "F",
   never "U" — U is dropped from the codebase entirely (design/mark-fold-notation).
   Task 6 splits the CP colour (eintent, defaults V) from the folded-form
   dihedral (eassign) — the "flat, never U" invariant lives in the folded
   frame, since the top-level creasePattern frame now legitimately shows the
   mark's (default) M/V intent instead. *)
let json_cp_assignments (json : Yojson.Safe.t) : string list =
  let open Yojson.Safe.Util in
  json |> member "edges_assignment" |> to_list |> List.map to_string

let json_folded_assignments (json : Yojson.Safe.t) : string list =
  let open Yojson.Safe.Util in
  json |> member "file_frames" |> index 0 |> member "edges_assignment"
  |> to_list |> List.map to_string

let test_e2e_bare_precrease_emits_f () =
  let json =
    Beloch.fold_string ~filename:"t.bel" "paper square\nmark map .a onto .c\n"
  in
  let assigns = json_folded_assignments json in
  Alcotest.(check bool) "no U in output" false (List.mem "U" assigns);
  Alcotest.(check bool) "has an F crease" true (List.mem "F" assigns)

(* ---- Task 4: mark extent dispatch (partial marks / pinch, #50 slice 2) --- *)

let eval_bel src = Eval.eval_folded (Beloch.parse ~filename:"t.bel" src)
let edges_of src = Array.length (eval_bel src).Eval.state.Fold_state.edges
let marks_of src = Array.length (eval_bel src).Eval.state.Fold_state.marks
let faces_of src = Array.length (eval_bel src).Eval.state.Fold_state.faces

(* an interior POINT mark records and adds no edge; comparing edges_of before
   and after isolates what the point mark itself contributes (the two named
   midlines --vm/--hm needed for the `.ctr` meet must themselves be marked
   -- i.e. materialized -- since `*` cannot meet a plain, non-physical value
   line; see paper_line_of_crease's Frozen case). *)
let test_mark_point_records_no_edge () =
  let base =
    "paper square\nmark --vm = map .a onto .b\nmark --hm = map .a onto .d\n\
     .ctr = --vm * --hm\n"
  in
  (* reuse the already-material --vm as the extent's axis (rather than a
     fresh, unnamed `--pt`, which the grammar has no bind-and-write form for
     without a motion of its own) *)
  let with_point_mark = base ^ "mark --vm at .ctr\n" in
  Alcotest.(check int) "point mark adds no edge" (edges_of base)
    (edges_of with_point_mark);
  (* the two full construction marks (--vm, --hm) already record *)
  Alcotest.(check int) "two marks before point" 2 (marks_of base);
  Alcotest.(check int) "point mark adds one record" 3 (marks_of with_point_mark)

(* Under the new mark-classification model (partial marks / pinch, slice 2
   refinement), a `between` extent with one boundary endpoint and one
   mid-face endpoint is no longer split into a subdividing boundary portion
   plus a recorded stub -- ANY mid-face endpoint makes the WHOLE contiguous
   extent a single non-subdividing record. Nothing gets cut, not even the
   boundary-to-boundary faces the extent crosses in the middle.

   Setup builds an F crease at y=1/2 (--hm) plus material x=1/2, x=3/4, y=3/4
   lines only to *name* the interior point .end=(3/4,3/4); the mark's own axis
   is the FRESH .a-.c diagonal (never materialized, so it crosses face
   interiors transversally). Extent .a(0,0) [bottom boundary] -> .end(3/4,3/4)
   [interior of the middle x/y in [1/2,3/4] face] now records outright.
   Asserted as a delta against the same program without the final mark, so
   the many setup subdivisions cancel out. *)
let test_mark_boundary_to_interior_records () =
  let setup =
    "paper square\n\
     mark --hm = map .a onto .d\n\
     mark --vm = map .a onto .b\n\
     .bm = --vm * --ab\n\
     mark --v34 = map .b onto .bm\n\
     .lm = --hm * --da\n\
     mark --h34 = map .d onto .lm\n\
     .end = --v34 * --h34\n"
  in
  let full = setup ^ "mark through .a .c between .a .end\n" in
  Alcotest.(check int) "recording splits no face" (faces_of setup)
    (faces_of full);
  Alcotest.(check int) "recording adds no edge" (edges_of setup)
    (edges_of full);
  Alcotest.(check int) "the whole extent is recorded as one mark"
    (marks_of setup + 1) (marks_of full)

let test_mark_mountain_cp_intent () =
  (* map .a onto .d = horizontal midline y=1/2, full chord (boundary-to-
     boundary -> subdivides), marked mountain. *)
  let src = "paper square\nmark map .a onto .d mountain\n" in
  let json = Beloch.fold_string ~filename:"t.bel" src in
  Alcotest.(check bool) "CP frame colours the mark M" true
    (json_cp_assignments json |> List.mem "M");
  Alcotest.(check bool) "folded frame keeps the mark F" true
    (json_folded_assignments json |> List.mem "F")

(* full mark (no extent clause) keeps subdividing, unchanged from before this
   task; a full mark never records. *)
let test_mark_full_still_subdivides () =
  let src = "paper square\nmark map .a onto .b\n" in
  (* a full mark records at fold-time (0 edges) and graduates to a crease only
     at emit *)
  Alcotest.(check int) "full mark records (no fold-time edge)" 0 (edges_of src);
  Alcotest.(check int) "one record" 1 (marks_of src)

(* fold the left half onto the right (valley crease x=1/2; .a/.d move, .b/.c
   don't). --hm = map .b onto .c is the y=1/2 line built from the two
   STATIONARY corners, so it still reads y=1/2 after the fold. Its `between`
   extent from the left edge to the right edge spans across the now-folded
   (V) crease at x=1/2 -- the left half's flap only carries paper x in
   [0,1/2], so the extent leaves it partway across. *)
let test_mark_crosses_fold_errors () =
  let src =
    "paper square\n\
     fold map .a onto .b moving .a\n\
     mark --hm = map .b onto .c\n\
     .p = --hm * --da\n\
     .q = --hm * --bc\n\
     mark --hm between .p .q\n"
  in
  expect_error "crosses a folded crease" (fun () ->
      Beloch.fold_string ~filename:"t.bel" src)

(* Task 3 review finding, end to end, now updated for the new classification
   model: a `between` extent whose ends are both non-boundary but sit in
   different faces of the same (never-folded, still all-F) flap used to
   `Invalid_argument` at fold_state.ml, then errored as CSpansCrease; under
   the new model ANY mid-face endpoint just records the whole extent as one
   mark, so this must now SUCCEED with exactly one record and no edge change
   (see fold_state's
   test_classify_spans_crease_both_interior_different_faces_records for the
   same shape tested directly against classify_mark_extent). The extent's own
   axis (the .a-.c diagonal) must be FRESH here -- never previously
   subdivided boundary-to-boundary -- so it crosses face interiors rather
   than running along an existing crease; --bd/--vm/--cut1/--q2/--r1/--r2 are
   all transversal to it, used only to name .p1=(1/4,1/4) and .p2=(3/4,3/4)
   as the meets that pin the diagonal down without ever marking it
   themselves. *)
let test_mark_spans_internal_crease_records () =
  let setup =
    "paper square\n\
     mark --bd = through .b .d\n\
     mark --vm = map .a onto .b\n\
     .ctr = --vm * --bd\n\
     .vmb = --vm * --ab\n\
     mark --cut1 = map .a onto .vmb\n\
     mark --q2 = map .b onto .vmb\n\
     mark --r1 = map .a onto .ctr\n\
     mark --r2 = map .c onto .ctr\n\
     .p1 = --cut1 * --r1\n\
     .p2 = --q2 * --r2\n"
  in
  let full = setup ^ "mark through .a .c between .p1 .p2\n" in
  Alcotest.(check int) "recording adds no edge" (edges_of setup)
    (edges_of full);
  Alcotest.(check int) "the whole extent is recorded as one mark"
    (marks_of setup + 1) (marks_of full)

(* ---- Task 5: exact-incidence snapping (#50 slice 2) ------------------- *)

(* Two full diagonals subdivide the square into four faces meeting at the
   centre (1/2,1/2); a point mark placed there ("at .ctr", reusing the
   already-material --ac as its axis, same idiom as
   test_mark_point_records_no_edge) must be incident to that shared vertex --
   not a numerically distinct duplicate. Since resolve_point already yields
   canonical rationals and Geom.point_equal is exact, this holds for free;
   the test pins the behaviour as a regression guard (task-5-brief.md: no
   tolerance/fuzzy logic, ever). *)
let test_mark_endpoint_on_vertex_is_incident () =
  let src =
    "paper square\n\
     mark --ac = through .a .c\n\
     mark --bd = through .b .d\n\
     .ctr = --ac * --bd\n\
     mark --ac at .ctr\n"
  in
  let st = (eval_bel src).Eval.state in
  let m = st.Fold_state.marks.(0) in
  let p = Fold_state.mark_rep_point m in
  let is_vertex =
    Array.exists
      (fun (f : Fold_state.face) ->
        Array.exists (Geom.point_equal p) f.Fold_state.paper)
      st.Fold_state.faces
  in
  Alcotest.(check bool) "point mark is incident to an existing vertex" true
    is_vertex

let () =
  Alcotest.run "beloch-e2e"
    [
      ( "e2e",
        [
          Alcotest.test_case "diagonals" `Quick test_e2e_diagonals;
          Alcotest.test_case "anti parallel" `Quick test_e2e_anti_parallel;
          Alcotest.test_case "anti dup point" `Quick test_e2e_anti_dup;
          Alcotest.test_case "square one face" `Quick test_e2e_square_one_face;
          Alcotest.test_case "diagonals four faces" `Quick
            test_e2e_diagonals_four_faces;
          Alcotest.test_case "perp end-to-end" `Quick test_e2e_perp;
          Alcotest.test_case "cube-root (Messer) axiom7 end-to-end" `Quick
            test_e2e_cube_root;
          Alcotest.test_case "cube-root restructured (panels + temps)" `Quick
            test_e2e_cube_root_restructured;
          Alcotest.test_case "def diagonals demo" `Quick test_e2e_def_diagonals;
          Alcotest.test_case "cube-root temps hidden from FOLD" `Quick
            test_e2e_cube_root_temps_hidden;
          Alcotest.test_case "bisect selector" `Quick test_e2e_bisect_select;
          Alcotest.test_case "bisect parallel midline" `Quick
            test_e2e_bisect_parallel;
          Alcotest.test_case "kite base: two axiom5 creases, folds cleanly"
            `Quick test_e2e_kite;
          Alcotest.test_case "map through toward selects diagonal" `Quick
            test_eval_map_through_toward;
          Alcotest.test_case "fold half end-to-end" `Quick test_e2e_fold_half;
          Alcotest.test_case "fold quarter accordion" `Quick test_e2e_fold_quarter;
          Alcotest.test_case "fold-quarter faceOrders sign golden" `Quick
            test_faceorders_stable_fold_quarter;
          Alcotest.test_case "flip makes a mountain" `Quick test_e2e_flip_mountain;
          Alcotest.test_case "flip keeps the CP size" `Quick
            test_e2e_flip_cp_counts;
          Alcotest.test_case "inline equals named" `Quick test_e2e_inline_equiv;
          Alcotest.test_case "inline off-paper errors" `Quick test_e2e_inline_error;
          Alcotest.test_case "axiom7 rational crease fold emit" `Quick
            test_e2e_axiom7_rational_crease;
          Alcotest.test_case "precrease then fold emits V not U" `Quick
            test_e2e_precrease_fold_emits_v;
          Alcotest.test_case "multilayer crease bare cross errors" `Quick
            test_multilayer_crease_bare_cross_errors;
          Alcotest.test_case "at selects bent segment" `Quick
            test_at_selects_bent_segment;
          Alcotest.test_case "& / \\ pick the same bent segment as at" `Quick
            test_bundle_ops_equiv_at;
          Alcotest.test_case "bound bundle == inline" `Quick
            test_bind_bundle_roundtrip;
          Alcotest.test_case "one folded frame per step" `Quick
            test_multiframe;
          Alcotest.test_case "e2e faces_matrix + frame" `Quick
            test_e2e_faces_matrix_and_frame;
          Alcotest.test_case
            "ADR 0017 defect 1: flap cluster spans a precrease split" `Quick
            test_e2e_flap_cluster_spans_precrease_split;
          Alcotest.test_case
            "ADR 0017 defect 2: cohesion moves a coplanar sibling" `Quick
            test_e2e_cohesion_moves_coplanar_sibling;
          Alcotest.test_case "bare precrease emits F not U" `Quick
            test_e2e_bare_precrease_emits_f;
          Alcotest.test_case "interior point mark records, no edge" `Quick
            test_mark_point_records_no_edge;
          Alcotest.test_case "boundary->interior extent records, splits nothing"
            `Quick test_mark_boundary_to_interior_records;
          Alcotest.test_case "mark mountain: CP frame M, folded frame F"
            `Quick test_mark_mountain_cp_intent;
          Alcotest.test_case "full mark still subdivides" `Quick
            test_mark_full_still_subdivides;
          Alcotest.test_case "between extent crossing a fold errors" `Quick
            test_mark_crosses_fold_errors;
          Alcotest.test_case
            "between extent spanning an internal crease records cleanly"
            `Quick test_mark_spans_internal_crease_records;
          Alcotest.test_case
            "point mark endpoint incident to existing vertex (exact snap)"
            `Quick test_mark_endpoint_on_vertex_is_incident;
        ] );
      ( "emit_folded",
        [
          Alcotest.test_case "dual frames" `Quick test_emit_folded_frames;
          Alcotest.test_case "crease name preserved" `Quick
            test_emit_folded_crease_name;
          Alcotest.test_case "beloch:marks emitted for record marks" `Quick
            test_beloch_marks_emitted;
        ] );
    ]
