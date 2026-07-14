(* tests/test_golden.ml *)
open Beloch

(* Anchor to the source root of *this* build context. dune sets
   DUNE_SOURCEROOT to the absolute workspace root, so an in-repo worktree
   reads its own examples/ rather than the main checkout's (#37). *)
let examples_dir =
  (match Sys.getenv_opt "DUNE_SOURCEROOT" with
   | Some root -> Filename.concat root "examples"
   | None -> "../../../examples")
  ^ "/"

let golden_dir = "golden/"

(* No exclusions: through.bel's historical full-FOLD hang (irrational coords
   in convex_overlap) was fixed by the FLINT qqbar kernel (#41) — it folds in
   well under a second now. *)
let excluded : string list = []

(* every .bel in examples/ (recursively) that is a full program (skip README +
   excluded). Names are relative paths (e.g. "syntax/bisect-a.bel") so the
   golden path can mirror the directory — needed because two different
   examples are both named multiple-folds.bel (top-level vs syntax/). *)
let example_names () =
  let rec walk prefix =
    let dir = examples_dir ^ prefix in
    Sys.readdir dir |> Array.to_list
    |> List.concat_map (fun entry ->
           let rel = prefix ^ entry in
           if Sys.is_directory (dir ^ entry) then walk (rel ^ "/")
           else if Filename.check_suffix entry ".bel" && not (List.mem rel excluded)
           then [ rel ]
           else [])
  in
  walk "" |> List.sort compare

let read path = In_channel.with_open_text path In_channel.input_all

(* Should any example ever intentionally error, capture the Beloch error
   message as the golden so the refactor is proven to preserve error behavior,
   not only successful FOLD output. (The intentional-error probes now live in
   tests/cases/ with `; expect error` assertions, not here.) *)
let fold_of name =
  let src = read (examples_dir ^ name) in
  (* Spans in goldens are basename-relative (e.g. "bisect-a.bel:3:1"); pass the
     basename here even though `name` (used for reading + golden lookup) is a
     relative path with subdirectory, or golden bytes would drift. *)
  try
    Yojson.Safe.pretty_to_string
      (Beloch.fold_string ~filename:(Filename.basename name) src)
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
