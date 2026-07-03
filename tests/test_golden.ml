(* tests/test_golden.ml *)
open Beloch

let examples_dir = "../../../examples/"
let golden_dir = "golden/"

(* No exclusions: through.bel's historical full-FOLD hang (irrational coords
   in convex_overlap) was fixed by the FLINT qqbar kernel (#41) — it folds in
   well under a second now. *)
let excluded : string list = []

(* every .bel in examples/ that is a full program (skip README + excluded) *)
let example_names () =
  Sys.readdir examples_dir |> Array.to_list
  |> List.filter (fun n -> Filename.check_suffix n ".bel")
  |> List.filter (fun n -> not (List.mem n excluded))
  |> List.sort compare

let read path = In_channel.with_open_text path In_channel.input_all

(* Some examples (dup-point.bel, parallel.bel) intentionally error. Capture the
   Beloch error message as the golden so the refactor is proven to preserve
   error behavior, not only successful FOLD output. *)
let fold_of name =
  let src = read (examples_dir ^ name) in
  try Yojson.Safe.pretty_to_string (Beloch.fold_string ~filename:name src)
  with Error.Beloch_error (_, msg) -> "ERROR: " ^ msg

let golden_path name = golden_dir ^ Filename.chop_suffix name ".bel" ^ ".fold"

let test_one name () =
  let got = fold_of name in
  let gp = golden_path name in
  if not (Sys.file_exists gp) then
    Alcotest.failf "no golden for %s — run the regen step (Step 4)" name
  else
    Alcotest.(check string) (name ^ " FOLD unchanged") (read gp) got

let () =
  Alcotest.run "golden"
    [ ("examples",
       List.map (fun n -> Alcotest.test_case n `Quick (test_one n))
         (example_names ())) ]
