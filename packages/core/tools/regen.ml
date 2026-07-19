(* Regenerate tests/golden/*.fold. Run from the repo root:
   dune exec tools/regen.exe *)
open Beloch

let dir = "examples/" and out = "tests/golden/"

(* every .bel in examples/, recursively, as a path relative to `dir` (e.g.
   "syntax/bisect-a.bel") — mirrors tests/test_golden.ml's walk. *)
let rec example_names prefix =
  let d = dir ^ prefix in
  Sys.readdir d |> Array.to_list
  |> List.concat_map (fun entry ->
         let rel = prefix ^ entry in
         if Sys.is_directory (d ^ entry) then example_names (rel ^ "/")
         else if Filename.check_suffix entry ".bel" then [ rel ]
         else [])

let rec mkdir_p d =
  if d <> "." && d <> "/" && not (Sys.file_exists d) then begin
    mkdir_p (Filename.dirname d);
    Sys.mkdir d 0o755
  end

let () =
  example_names "" |> List.iter (fun name ->
         let src = In_channel.with_open_text (dir ^ name) In_channel.input_all in
         let body =
           try
             Yojson.Safe.pretty_to_string
               (Beloch.fold_string ~filename:(Filename.basename name) src)
           with Error.Beloch_error (_, msg) -> "ERROR: " ^ msg
         in
         let path = out ^ Filename.chop_suffix name ".bel" ^ ".fold" in
         mkdir_p (Filename.dirname path);
         Out_channel.with_open_text path (fun oc ->
             Out_channel.output_string oc body))
