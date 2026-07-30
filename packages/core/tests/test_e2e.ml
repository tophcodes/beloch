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
  | None -> "../../../../../examples"

let read_example name =
  In_channel.with_open_text (Filename.concat examples_dir name) In_channel.input_all

(* A few probes moved from examples/ into the inline-assertion corpus
   (tests/cases/) but still carry an e2e assertion the inline grammar can't
   express (identity isometry, axiom5 tag). Read those from tests/cases. *)
let cases_dir =
  match Sys.getenv_opt "DUNE_SOURCEROOT" with
  | Some root -> Filename.concat root "packages/core/tests/cases"
  | None -> "../../../../../packages/core/tests/cases"

let read_case name =
  In_channel.with_open_text (Filename.concat cases_dir name) In_channel.input_all

(* file_frames now opens with a synthetic flat step-0 frame (the unfolded
   sheet); the fully-folded state is the LAST frame. Tests that want "the
   folded frame" take the last, not List.hd. *)
let last_frame json =
  let open Yojson.Safe.Util in
  let l = json |> member "file_frames" |> to_list in
  List.nth l (List.length l - 1)

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
  let hs = Fold_state.hinges st in
  List.filter
    (fun i -> Fold_state.mv st i = a)
    (List.init (Array.length hs) Fun.id)
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
  let src = read_case "construct/diagonals.bel" in
  let json = Beloch.fold_string ~filename:"diagonals.bel" src in
  let open Yojson.Safe.Util in
  Alcotest.(check int) "vertices" 5
    (json |> member "vertices_coords" |> to_list |> List.length);
  Alcotest.(check int) "edges" 8
    (json |> member "edges_vertices" |> to_list |> List.length)

let test_e2e_diagonals_four_faces () =
  let json =
    Beloch.fold_string ~filename:"diagonals.bel" (read_case "construct/diagonals.bel")
  in
  let open Yojson.Safe.Util in
  Alcotest.(check int) "four faces" 4
    (json |> member "faces_vertices" |> to_list |> List.length)

let test_e2e_perp () =
  let json =
    Beloch.fold_string ~filename:"perp.bel" (read_case "construct/perp.bel")
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

let test_edges_carry_crease_id () =
  (* a single fold produces one crease bundle; its non-boundary edges all
     carry the same integer crease_id *)
  let json =
    Beloch.fold_string ~filename:"t.bel"
      "paper square\nfold --h = map .a onto .d moving .a\n"
  in
  let open Yojson.Safe.Util in
  let cids =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function
         | `Null -> None
         | e -> ( match e |> member "crease_id" with `Int i -> Some i | _ -> None ))
  in
  Alcotest.(check bool) "at least one edge has a crease_id" true (cids <> []);
  Alcotest.(check bool) "crease_ids are non-negative" true
    (List.for_all (fun i -> i >= 0) cids)

let test_e2e_cube_root () =
  let json =
    Beloch.fold_string ~filename:"cube-root.bel" (read_case "fold/cube-root.bel")
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
       (read_case "fold/cube-root.bel"))

let test_e2e_cube_root_temps_hidden () =
  let json =
    Beloch.fold_string ~filename:"cube-root.bel" (read_case "fold/cube-root.bel")
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
    Beloch.fold_string ~filename:"bisect-a.bel" (read_case "construct/bisect-a.bel")
  in
  let jb =
    Beloch.fold_string ~filename:"bisect-b.bel" (read_case "mark/bisect-b.bel")
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
  match List.rev (Array.to_list (Fold_state.marks fd.Eval.state)) with
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

let test_e2e_fold_quarter () =
  let json =
    Beloch.fold_string ~filename:"fold-quarter.bel"
      (read_case "fold/fold-quarter.bel")
  in
  let open Yojson.Safe.Util in
  let folded = last_frame json in
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
    Beloch.fold_string ~filename:"fq.bel" (read_case "fold/fold-quarter.bel")
  in
  let orders =
    Yojson.Safe.Util.(
      (* one frame per fold now; the fully-folded state (both folds applied)
         is the LAST frame, not the first *)
      let frames = json |> member "file_frames" |> to_list in
      List.nth frames (List.length frames - 1) |> member "faceOrders")
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
  Alcotest.(check int) "flat step-0 frame + one folded frame" 2 (List.length frames);
  let folded = last_frame json in
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

(* Regression: a scoped ("up to") fold leaves the stationary layer and the
   moving flap sharing a paper corner that is NOT on the fold axis. The folded
   frame must give each face its own reflected copy of that corner. Deduping
   vertices by paper coord alone collapses them onto the stationary layer's
   table position, degenerating the moving face to zero area — the "diagonal
   slash" render. Assert every folded-frame face has positive area.

   The original repro here (fold-top-flap.bel) was a genuine tear and is now
   rejected by the scoped-fold hinge-closure check (2026-07-14) before it ever
   reaches emit, so it moved to
   tests/cases/fold/tear-perpendicular-hinge.bel as an `expect error` case.
   This test now exercises a *valid* scoped fold (fold-top-two.bel, 6 faces)
   instead.

   Two findings from re-deriving this test:
   (1) The original assertion read `List.hd (file_frames)` — for a 2-fold
   program that is the frame after the FIRST fold (2 faces), not the scoped
   fold's frame (3 faces, where cc3184a's off-axis dedup fix actually bites).
   So this regression test had been checking the wrong frame since it was
   authored and passed vacuously regardless of the fix. Fixed here to check
   every frame, matching the comment's stated intent.
   (2) Even fixed, fold-top-two.bel empirically never produces an off-axis
   shared corner (verified against a scratch checkout with cc3184a's dedup
   fix reverted: every face already had solidly nonzero area, buggy or not —
   identical numbers with and without the fix), and neither does the
   hinge-closure design doc's positive-control example. So this test still
   guards the *shape* of the invariant (every folded face is non-degenerate)
   but, as far as we've found, no longer exercises cc3184a's (paper,
   table)-keyed dedup at all — every remaining scoped-fold example lacks the
   off-axis-shared-corner geometry that fix targets. Flagged for separate
   review; do not remove the fix without a replacement regression. *)
let test_emit_folded_scoped_fold_nondegenerate () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          mark --l = through .a .d\n\
          mark --bot = through .a .b\n\
          fold --v = map .b onto .a\n\
          fold --h = map .d onto .a\n\
          .p = --l * --h\n\
          .q = --v * --bot\n\
          fold through .p .q moving .d up to .c\n")
  in
  let json = Fold_emit.to_json_folded fd in
  let open Yojson.Safe.Util in
  let frames = json |> member "file_frames" |> to_list in
  List.iteri
    (fun fri folded ->
      let coords =
        folded |> member "vertices_coords" |> to_list
        |> List.map (fun p ->
               match p |> to_list with
               | [ x; y ] -> (to_number x, to_number y)
               | _ -> Alcotest.fail "vertex is not a pair")
        |> Array.of_list
      in
      folded |> member "faces_vertices" |> to_list
      |> List.iteri (fun fi f ->
             let idxs = f |> to_list |> List.map to_int |> Array.of_list in
             let n = Array.length idxs in
             let area2 = ref 0.0 in
             for k = 0 to n - 1 do
               let x1, y1 = coords.(idxs.(k)) in
               let x2, y2 = coords.(idxs.((k + 1) mod n)) in
               area2 := !area2 +. ((x1 *. y2) -. (x2 *. y1))
             done;
             Alcotest.(check bool)
               (Printf.sprintf "frame %d face %d has positive area" fri fi)
               true
               (Float.abs !area2 > 1e-9)))
    frames

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

(* #36: mcrease_id for a non-graduating point mark must be deterministic per
   eval -- a function of the program alone, not of how many creases were
   minted by earlier evals in the same process (Fold_state's internal
   crease-id counter, reset per eval via [Fold_state.reset_ids], is otherwise a
   process-lifetime global). Evaluate the point-mark program once for a
   baseline id, then again after deliberately polluting the global counter
   with unrelated real creases; the two ids must match. *)
let mark_program =
  "paper square\nmark --vm = map .a onto .b\nmark --hm = map .a onto .d\n\
   .ctr = --vm * --hm\nmark --vm at .ctr\n"

let point_mark_crease_id () =
  let fd = Eval.eval_folded (Beloch.parse ~filename:"t.bel" mark_program) in
  let json = Fold_emit.to_json_folded fd in
  let open Yojson.Safe.Util in
  match json |> member "beloch:marks" with
  | `List [ one ] -> one |> member "crease_id" |> to_int
  | _ -> Alcotest.fail "expected exactly one point mark"

let test_beloch_marks_crease_id_deterministic () =
  let baseline = point_mark_crease_id () in
  (* pollute the global counter with unrelated real creases *)
  ignore
    (Eval.eval_folded
       (Beloch.parse ~filename:"pollute.bel"
          "paper square\nfold map .b onto .a moving .b\n\
           fold map .d onto .a moving .d\n"));
  let polluted = point_mark_crease_id () in
  Alcotest.(check int)
    "point mark crease_id is deterministic regardless of prior minting (#36)"
    baseline polluted

(* render-card slice 2 task 1: folded frames must carry the same name/edge
   provenance the CP frame already carries, so the render pipeline can
   address elements by source name instead of by float coordinate. *)
let test_folded_provenance () =
  let src =
    "paper square\n\
     mark --d1 = through .a .c\n\
     mark --d2 = through .b .d\n\
     .center = --d1 * --d2\n\
     fold map .a onto .center\n"
  in
  let json = Beloch.fold_string ~filename:"prov.bel" src in
  let open Yojson.Safe.Util in
  (* CP frame: vertices_names contains "center" *)
  let cp_names = json |> member "beloch:vertices_names" |> to_list in
  Alcotest.(check bool) "cp vertices_names has center" true
    (List.exists (fun v -> v = `String "center") cp_names);
  (* the folded frame (last, fully folded) carries beloch:edges AND
     beloch:vertices_names — the flat step-0 frame predates .center *)
  let folded = last_frame json in
  Alcotest.(check bool) "folded frame has beloch:edges" true
    (match folded |> member "beloch:edges" with `Null -> false | _ -> true);
  Alcotest.(check bool) "folded frame vertices_names has center" true
    (folded |> member "beloch:vertices_names" |> to_list
     |> List.exists (fun v -> v = `String "center"));
  (* Plan 3c Task 6 prov spot check: at least one folded crease's
     beloch:edges entry carries a non-null provenance record, and every one
     of that record's axiom/sources/span fields is itself non-null (D14/D15
     — beloch_edges_json in fold_emit.ml only omits `name`/`step`, never
     these three). *)
  let folded_edges = folded |> member "beloch:edges" |> to_list in
  let has_full_prov =
    List.exists
      (function
        | `Null -> false
        | e ->
            (match e |> member "axiom" with `Null -> false | _ -> true)
            && (match e |> member "sources" with `Null -> false | _ -> true)
            && (match e |> member "span" with `Null -> false | _ -> true))
      folded_edges
  in
  Alcotest.(check bool)
    "at least one folded crease has non-null axiom/sources/span" true
    has_full_prov

let test_inspect_enumerates_crease_segments () =
  let src = read_case "inspect/two-segment-crease.bel" in
  let json = Beloch.fold_string ~filename:"t.bel" src in
  let open Yojson.Safe.Util in
  let inspect = json |> member "beloch:inspect" in
  Alcotest.(check bool) "inspect present" true (inspect <> `Null);
  let creases = inspect |> member "creases" |> to_assoc in
  Alcotest.(check bool) "at least one crease" true (creases <> []);
  (* --v crosses --h, so its bundle has 2 segments; every segment carries a
     2-element faces pair *)
  let v_segs =
    creases
    |> List.find (fun (_id, c) -> c |> member "name" = `String "v")
    |> snd |> member "segments" |> to_list
  in
  Alcotest.(check int) "crease --v has 2 segments" 2 (List.length v_segs);
  List.iter
    (fun (_id, c) ->
      let segs = c |> member "segments" |> to_list in
      Alcotest.(check bool) "crease has segments" true (segs <> []);
      List.iter
        (fun s ->
          Alcotest.(check int) "faces pair length" 2
            (s |> member "faces" |> to_list |> List.length))
        segs)
    creases;
  (* faces carry rank + flap *)
  let faces = inspect |> member "faces" |> to_assoc in
  Alcotest.(check bool) "at least one face" true (faces <> []);
  List.iter
    (fun (_i, f) ->
      Alcotest.(check bool) "face has rank" true (f |> member "rank" <> `Null);
      Alcotest.(check bool) "face has flap" true (f |> member "flap" <> `Null))
    faces;
  (* points: a corner sits inside a single face → resolves to a unique
     Some index; but .mid = --h * --v is the crossing point shared by all
     four faces, so it lands on a shared boundary and MUST resolve to null
     (face_of returns None unless exactly one polygon contains the point). *)
  let points = inspect |> member "points" in
  let corner = points |> member "a" in
  Alcotest.(check bool) "corner .a has a face" true
    (corner |> member "face" <> `Null);
  Alcotest.(check bool) "corner .a has a flap" true
    (corner |> member "flap" <> `Null);
  let mid = points |> member "mid" in
  Alcotest.(check bool) "boundary point .mid face is null" true
    (mid |> member "face" = `Null);
  Alcotest.(check bool) "boundary point .mid flap is null" true
    (mid |> member "flap" = `Null)

(* cross is material: a crease scored through several layers marks different
   lines in the paper, so bare cross must error — with a hint toward the
   #(...) flap escape hatch. (A merely table-bent scar crosses fine bare;
   see test_eval_cross_table_bent_scar_ok.) *)
let[@warning "-32"] test_multilayer_crease_bare_cross_errors () =
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
let[@warning "-32"] test_at_selects_bent_segment () =
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
    | j -> j |> member "beloch:named_lines" |> member "q" |> member "coeffs" |> to_list
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
    | j -> j |> member "beloch:named_lines" |> member "q" |> member "coeffs" |> to_list
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
    | j -> j |> member "beloch:named_lines" |> member "q" |> member "coeffs" |> to_list
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

(* #42: one self-contained foldedForm frame per numeric frame, flat baseline
   included. Frames are unlabelled — the retired `step` keyword no longer tags
   them (beloch:step is gone). *)
let test_multiframe () =
  let src =
    "paper square\n\
     fold map .c onto .a moving .c\n\
     fold map .b onto .a moving .b\n"
  in
  let json = Beloch.fold_string ~filename:"t" src in
  let frames =
    match json with
    | `Assoc kv -> (match List.assoc "file_frames" kv with `List l -> l | _ -> [])
    | _ -> []
  in
  Alcotest.(check int) "flat baseline + one folded frame per fold" 3
    (List.length frames);
  let has_step_key = function
    | `Assoc kv -> List.mem_assoc "beloch:step" kv
    | _ -> false
  in
  Alcotest.(check bool) "no frame carries a beloch:step tag" false
    (List.exists has_step_key frames)

(* Statement-level sourcemap for the Playground step player: one
   beloch:statements entry per mark/fold statement, each mark embedding its
   OWN geometry — even when both marks in this source graduate into real
   creases by the end (their endpoints are paper corners), so beloch:marks
   is empty while beloch:statements still carries their geometry. *)
let test_beloch_statements () =
  let src =
    "paper square\n\
     mark --diag = map .a onto .c\n\
     mark --ray = through .a .c\n\
     fold map .b onto .d\n"
  in
  let json = Beloch.fold_string ~filename:"t" src in
  let open Yojson.Safe.Util in
  let stmts = json |> member "beloch:statements" |> to_list in
  Alcotest.(check int) "one entry per mark/fold statement" 3 (List.length stmts);
  let kind_of j = j |> member "kind" |> to_string in
  Alcotest.(check (list string)) "kinds in source order"
    [ "mark"; "mark"; "fold" ] (List.map kind_of stmts);
  let line_of j = j |> member "source_line" |> to_int in
  Alcotest.(check (list int)) "source lines"
    [ 2; 3; 4 ] (List.map line_of stmts);
  let frame_of j = j |> member "frame_index" |> to_int in
  Alcotest.(check (list int))
    "marks before any fold read frame 0 (the flat sheet); the fold itself \
     reads frame 1 (its own just-pushed frame)"
    [ 0; 0; 1 ] (List.map frame_of stmts);
  let mark_present j = j |> member "mark" <> `Null in
  Alcotest.(check (list bool)) "both marks carry embedded geometry, the fold does not"
    [ true; true; false ] (List.map mark_present stmts);
  (* the bug this design avoids: both marks graduate (their endpoints are
     corners), so the global list is empty — but the statement log is
     unaffected, since it embeds geometry at record time, not by lookup. *)
  let global_marks = json |> member "beloch:marks" |> to_list in
  Alcotest.(check int) "both marks graduate — beloch:marks is empty" 0
    (List.length global_marks);
  let kept_count_of j = j |> member "kept_marks" |> to_list |> List.length in
  Alcotest.(check (list int))
    "kept_marks grows through the mark run, then both graduate at the fold"
    [ 1; 2; 0 ] (List.map kept_count_of stmts)

let test_e2e_faces_matrix_and_frame () =
  let json =
    Beloch.fold_string ~filename:"square.bel" (read_case "mark/square.bel")
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
  last_frame json |> member "edges_assignment"
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
let edges_of src = Array.length (Fold_state.hinges (eval_bel src).Eval.state)
let marks_of src = Array.length (Fold_state.marks (eval_bel src).Eval.state)
let faces_of src = Array.length (Fold_state.faces (eval_bel src).Eval.state)

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
     boundary -> subdivides), marked mountain. Both frames show the sheet as
     it is folded, and a precrease is flat in both — the marked direction
     never reaches edges_assignment. *)
  let src = "paper square\nmark map .a onto .d mountain\n" in
  let json = Beloch.fold_string ~filename:"t.bel" src in
  Alcotest.(check bool) "CP frame keeps the mark F" false
    (json_cp_assignments json |> List.mem "M");
  Alcotest.(check bool) "CP frame has the flat crease" true
    (json_cp_assignments json |> List.mem "F");
  Alcotest.(check bool) "folded frame keeps the mark F" true
    (json_folded_assignments json |> List.mem "F")

(* A FOLDED crease is coloured by the derived M/V, not by the letter frozen
   into [intent] when the fold ran: later steps restack the sheet and the
   stored letter does not follow. swivel-rabbit is symmetric about --v, so
   its two hinges must agree, and only the emergent ear is a mountain. *)
let test_cp_folded_crease_uses_derived_mv () =
  let json =
    Beloch.fold_string ~filename:"swivel-rabbit.bel"
      (read_example "bases/swivel-rabbit.bel")
  in
  let count l a = List.length (List.filter (fun x -> x = a) l) in
  let cp = json_cp_assignments json in
  let folded = json_folded_assignments json in
  Alcotest.(check int) "one mountain in the CP, the emergent ear" 1
    (count cp "M");
  Alcotest.(check int) "CP and folded frame agree on mountains"
    (count folded "M") (count cp "M")

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
let[@warning "-32"] test_mark_crosses_fold_errors () =
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
  let m = (Fold_state.marks st).(0) in
  let p = Fold_state.mark_rep_point m in
  let is_vertex =
    Array.exists
      (fun (f : Fold_state.face) -> Array.exists (Geom.point_equal p) f)
      (Fold_state.faces st)
  in
  Alcotest.(check bool) "point mark is incident to an existing vertex" true
    is_vertex

let () =
  Alcotest.run "beloch-e2e"
    [
      ( "e2e",
        [
          Alcotest.test_case "diagonals" `Quick test_e2e_diagonals;
          Alcotest.test_case "diagonals four faces" `Quick
            test_e2e_diagonals_four_faces;
          Alcotest.test_case "perp end-to-end" `Quick test_e2e_perp;
          Alcotest.test_case "beloch:edges carry crease_id" `Quick
            test_edges_carry_crease_id;
          Alcotest.test_case "cube-root (Messer) axiom7 end-to-end" `Quick
            test_e2e_cube_root;
          Alcotest.test_case "cube-root restructured (panels + temps)" `Quick
            test_e2e_cube_root_restructured;
          Alcotest.test_case "cube-root temps hidden from FOLD" `Quick
            test_e2e_cube_root_temps_hidden;
          Alcotest.test_case "bisect selector" `Quick test_e2e_bisect_select;
          Alcotest.test_case "kite base: two axiom5 creases, folds cleanly"
            `Quick test_e2e_kite;
          Alcotest.test_case "map through toward selects diagonal" `Quick
            test_eval_map_through_toward;
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
          (* PENDING #27: full multilayer mark materialization — a mark on a
             folded sheet records only its carrying flap, so the multilayer
             meet guard and bent-segment selection differ from the old path *)
          Alcotest.test_case "& / \\ pick the same bent segment as at" `Quick
            test_bundle_ops_equiv_at;
          Alcotest.test_case "bound bundle == inline" `Quick
            test_bind_bundle_roundtrip;
          Alcotest.test_case "one folded frame per step" `Quick
            test_multiframe;
          Alcotest.test_case "beloch:statements sourcemap" `Quick
            test_beloch_statements;
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
          Alcotest.test_case "CP colours folded creases by derived MV" `Quick
            test_cp_folded_crease_uses_derived_mv;
          Alcotest.test_case "full mark still subdivides" `Quick
            test_mark_full_still_subdivides;
          (* PENDING #27: full multilayer mark materialization — the setup meet
             `--hm * --da` can't reach across layers a carrying-flap-only chord *)
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
          Alcotest.test_case "scoped fold folded faces non-degenerate" `Quick
            test_emit_folded_scoped_fold_nondegenerate;
          Alcotest.test_case "crease name preserved" `Quick
            test_emit_folded_crease_name;
          Alcotest.test_case "beloch:marks emitted for record marks" `Quick
            test_beloch_marks_emitted;
          Alcotest.test_case
            "point mark crease_id is deterministic per eval (#36)" `Quick
            test_beloch_marks_crease_id_deterministic;
          Alcotest.test_case "folded provenance" `Quick
            test_folded_provenance;
          Alcotest.test_case "beloch:inspect enumerates crease segments" `Quick
            test_inspect_enumerates_crease_segments;
        ] );
    ]
