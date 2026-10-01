(* tests/test_stdlib.ml: the standard library of sheets, packages/core/stdlib.
   Each shape is opened with a size and its trimmed sheet checked: the
   corners of the first frame and the names the sheet comes with. *)

open Beloch

let source_root =
  match Sys.getenv_opt "DUNE_SOURCEROOT" with
  | Some root -> root
  | None -> "../../../.."

let stdlib_path = Filename.concat source_root "packages/core/stdlib/shapes.bel"

let prelude =
  lazy
    (snd
       (Parse.library ~filename:"shapes.bel"
          (In_channel.with_open_text stdlib_path In_channel.input_all)))

let open_sheet (src : string) : Yojson.Safe.t =
  Beloch.parse ~filename:"t.bel" src
  |> Eval.eval_program ~prelude:(Lazy.force prelude)
  |> Fold_emit.to_json_folded

let corners json =
  let open Yojson.Safe.Util in
  json |> member "file_frames" |> to_list |> List.hd |> member "vertices_coords"
  |> to_list
  |> List.map (fun v -> List.map to_number (to_list v))

let names json =
  let open Yojson.Safe.Util in
  json |> member "beloch:named_points" |> to_assoc |> List.map fst

let r2 = Float.sqrt 2. and r3 = Float.sqrt 3.
let coords = Alcotest.(list (list (float 1e-12)))

let test_rectangle () =
  let json = open_sheet "paper rectangle 2 1\n" in
  Alcotest.check coords "corners"
    [ [ 0.; 0. ]; [ 2.; 0. ]; [ 2.; 1. ]; [ 0.; 1. ] ]
    (corners json);
  Alcotest.(check (list string)) "names" [ "a"; "b"; "p" ] (names json)

let test_silver () =
  let json = open_sheet "paper silver 2\n" in
  Alcotest.check coords "corners, height 2 / sqrt 2"
    [ [ 0.; 0. ]; [ 2.; 0. ]; [ 2.; r2 ]; [ 0.; r2 ] ]
    (corners json);
  Alcotest.(check (list string)) "names" [ "a"; "b" ] (names json)

let test_triangle () =
  let json = open_sheet "paper triangle 2\n" in
  Alcotest.check coords "corners, apex at height sqrt 3"
    [ [ 0.; 0. ]; [ 2.; 0. ]; [ 1.; r3 ] ]
    (corners json);
  Alcotest.(check (list string)) "names" [ "a"; "b"; "t" ] (names json)

let test_folds_on_a_shape () =
  (* the trimmed sheet folds like a square: its edges are bound *)
  let json = open_sheet "paper rectangle 2 1\nfold (map --ab onto --da) (moving .b)\n" in
  let open Yojson.Safe.Util in
  Alcotest.(check int) "two faces" 2
    (json |> member "faces_vertices" |> to_list |> List.length)

(* The rectangle as a page states it: the text from `shape rectangle(w h) {`
   to its closing brace. *)
let rectangle_in (rel : string) : string =
  let src = In_channel.with_open_text (Filename.concat source_root rel) In_channel.input_all in
  let start = "shape rectangle(w h) {" in
  let rec find i =
    if i + String.length start > String.length src then
      Alcotest.failf "%s states no rectangle" rel
    else if String.sub src i (String.length start) = start then i
    else find (i + 1)
  in
  let i = find 0 in
  let j = String.index_from src i '}' in
  String.sub src i (j - i + 1)

(* the language page and ADR 0046 state the rectangle of the library, and
   it evaluates *)
let test_documented_rectangle () =
  let library = rectangle_in "packages/core/stdlib/shapes.bel" in
  List.iter
    (fun rel ->
      let stated = rectangle_in rel in
      Alcotest.(check string) (rel ^ " states the library's rectangle") library stated;
      let json =
        Beloch.parse ~filename:"t.bel" (stated ^ "\npaper rectangle 2 1\n")
        |> Eval.eval_program ~prelude:[]
        |> Fold_emit.to_json_folded
      in
      Alcotest.check coords (rel ^ ": corners")
        [ [ 0.; 0. ]; [ 2.; 0. ]; [ 2.; 1. ]; [ 0.; 1. ] ]
        (corners json))
    [ "spec/BELOCH.md"; "decisions/0046-a-sheet-is-a-square-or-a-flap-cut-from-one.md" ]

let () =
  Alcotest.run "stdlib"
    [
      ( "shapes",
        [
          Alcotest.test_case "rectangle 2 1" `Quick test_rectangle;
          Alcotest.test_case "silver 2" `Quick test_silver;
          Alcotest.test_case "triangle 2" `Quick test_triangle;
          Alcotest.test_case "a fold on the rectangle" `Quick test_folds_on_a_shape;
          Alcotest.test_case "the rectangle the pages state" `Quick
            test_documented_rectangle;
        ] );
    ]
