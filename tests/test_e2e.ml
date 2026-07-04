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
       --d1 = through .a .c\n\
       --d2 = through .b .d\n\
       .m = cross --d1 --d2\n\
       map .a onto .m\n"
  in
  let inline =
    Beloch.fold_string ~filename:"t.bel"
      "paper square\n\
       --d1 = through .a .c\n\
       --d2 = through .b .d\n\
       map .a onto .(--d1 --d2)\n"
  in
  Alcotest.(check bool)
    "inline cross-point matches the named binding" true
    (geom named = geom inline)

let test_e2e_inline_error () =
  expect_error "same place" (fun () ->
      Beloch.fold_string ~filename:"t.bel"
        "paper square\nperp --(.a .a) through .b\n")

let test_e2e_diagonals () =
  let src = read_example "diagonals.bel" in
  let json = Beloch.fold_string ~filename:"diagonals.bel" src in
  let open Yojson.Safe.Util in
  Alcotest.(check int) "vertices" 5
    (json |> member "vertices_coords" |> to_list |> List.length);
  Alcotest.(check int) "edges" 8
    (json |> member "edges_vertices" |> to_list |> List.length)

let test_e2e_anti_parallel () =
  expect_error "parallel" (fun () ->
      Beloch.fold_string ~filename:"parallel.bel" (read_example "parallel.bel"))

let test_e2e_anti_dup () =
  expect_error "same place" (fun () ->
      Beloch.fold_string ~filename:"dup-point.bel"
        (read_example "dup-point.bel"))

let test_e2e_square_one_face () =
  let json =
    Beloch.fold_string ~filename:"square.bel" (read_example "square.bel")
  in
  let open Yojson.Safe.Util in
  Alcotest.(check int) "one face" 1
    (json |> member "faces_vertices" |> to_list |> List.length);
  Alcotest.(check int) "face has four vertices" 4
    (json |> member "faces_vertices" |> to_list |> List.hd |> to_list |> List.length)

let test_e2e_diagonals_four_faces () =
  let json =
    Beloch.fold_string ~filename:"diagonals.bel" (read_example "diagonals.bel")
  in
  let open Yojson.Safe.Util in
  Alcotest.(check int) "four faces" 4
    (json |> member "faces_vertices" |> to_list |> List.length)

let test_e2e_perp () =
  let json =
    Beloch.fold_string ~filename:"perp.bel" (read_example "perp.bel")
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
    Beloch.fold_string ~filename:"cube-root.bel" (read_example "cube-root.bel")
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
       (read_example "cube-root.bel"))

let test_e2e_def_diagonals () =
  let json =
    Beloch.fold_string ~filename:"def-diagonals.bel"
      (read_example "def-diagonals.bel")
  in
  let open Yojson.Safe.Util in
  let pts = json |> member "beloch:named_points" |> to_assoc in
  Alcotest.(check bool) "centre named" true (List.mem_assoc "m" pts)

let test_e2e_cube_root_temps_hidden () =
  let json =
    Beloch.fold_string ~filename:"cube-root.bel" (read_example "cube-root.bel")
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
    Beloch.fold_string ~filename:"bisect-a.bel" (read_example "bisect-a.bel")
  in
  let jb =
    Beloch.fold_string ~filename:"bisect-b.bel" (read_example "bisect-b.bel")
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

let test_e2e_bisect_parallel () =
  let json =
    Beloch.fold_string ~filename:"bisect-parallel.bel"
      (read_example "bisect-parallel.bel")
  in
  let open Yojson.Safe.Util in
  Alcotest.(check int) "two faces" 2
    (json |> member "faces_vertices" |> to_list |> List.length)

let test_eval_map_through_toward () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          --bottom = through .a .b\n\
          map .d onto --bottom through .a toward .b\n")
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
      Alcotest.(check bool) "axiom-6 crease through (0,0)" true (on (pt 0 0));
      Alcotest.(check bool) "axiom-6 crease through (1,1)" true (on (pt 1 1))

let test_e2e_fold_half () =
  let json =
    Beloch.fold_string ~filename:"fold-half.bel" (read_example "fold-half.bel")
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
      (read_example "fold-quarter.bel")
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
         "paper square\nflip\n@map .a onto .b moving .a\n")
  in
  Alcotest.(check int) "fold after flip is a mountain" 1
    (count_assign Fold_state.M fd.Eval.state);
  Alcotest.(check int) "and not a valley" 0
    (count_assign Fold_state.V fd.Eval.state);
  let fd2 =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n@map .a onto .b moving .a\n")
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
    (counts "paper square\n--c = map .a onto .b\n"
    = counts "paper square\n--c = map .a onto .b\nflip\n")

let test_faceorders_stable_fold_quarter () =
  let json =
    Beloch.fold_string ~filename:"fq.bel" (read_example "fold-quarter.bel")
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
     --diag = through .a .c\n\
     --anti = through .b .d\n\
     map .a onto --anti and .d onto --diag toward .b\n"
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
         "paper square\n@map .b onto .a moving .b\n")
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
      (Beloch.parse ~filename:"t.bel" "paper square\n--m = map .a onto .c\n")
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

(* #28: bare reuse of a crease that's been bent by a subsequent fold must
   error, with a hint toward the #(...) flap escape hatch. *)
let test_bent_crease_bare_reuse_errors () =
  let src =
    "paper square\n\
     --b = through .a .c\n\
     --v = @map .c onto .b moving .c\n\
     .mid = cross --b --v\n"
    (* bare reuse of the now-bent --b *)
  in
  match Beloch.fold_string ~filename:"t.bel" src with
  | exception Error.Beloch_error (_, msg) ->
      Alcotest.(check bool)
        "mentions no longer straight" true
        (let re = Str.regexp_string "no longer straight" in
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
  | _ -> Alcotest.fail "expected a bent-crease error"

(* #28: naming the folded-flap piece of a bent crease via #(...) resolves and
   folds without error. *)
let test_flap_restriction_resolves () =
  let src =
    "paper square\n\
     --b = through .a .c\n\
     --v = @map .c onto .b moving .c\n\
     .mid = cross --( --b #(.c .d) ) --v\n"
    (* the folded-flap piece of --b *)
  in
  match Beloch.fold_string ~filename:"t.bel" src with
  | exception Error.Beloch_error (_, msg) ->
      Alcotest.failf "restriction should resolve, got error: %s" msg
  | _ -> ()

(* #42: one self-contained foldedForm frame per step snapshot, baseline
   included, each step-tagged. *)
let test_multiframe () =
  let src =
    "paper square\n\
     step a\n\
     --v = map .a onto .b\n\
     step b\n\
     map .d onto .c\n"
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
    Beloch.fold_string ~filename:"square.bel" (read_example "square.bel")
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
         "paper square\nmap .b onto .a\n@map .b onto .a moving .b\n")
  in
  let j = Fold_emit.to_json_folded fd in
  let assigns = j |> member "edges_assignment" |> to_list |> filter_string in
  Alcotest.(check bool) "no U assignment after folding a precrease" false
    (List.mem "U" assigns);
  Alcotest.(check bool) "the precrease folds as a valley" true
    (List.mem "V" assigns)

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
          Alcotest.test_case "bent crease bare reuse errors" `Quick
            test_bent_crease_bare_reuse_errors;
          Alcotest.test_case "flap restriction resolves" `Quick
            test_flap_restriction_resolves;
          Alcotest.test_case "one folded frame per step" `Quick
            test_multiframe;
          Alcotest.test_case "e2e faces_matrix + frame" `Quick
            test_e2e_faces_matrix_and_frame;
        ] );
      ( "emit_folded",
        [
          Alcotest.test_case "dual frames" `Quick test_emit_folded_frames;
          Alcotest.test_case "crease name preserved" `Quick
            test_emit_folded_crease_name;
        ] );
    ]
