(* Regenerate tests/golden/*.fold. Run from the repo root:
   dune exec scratch/regen.exe *)
open Beloch

let () =
  let dir = "examples/" and out = "tests/golden/" in
  Sys.readdir dir |> Array.to_list
  |> List.filter (fun n -> Filename.check_suffix n ".bel")
  |> List.iter (fun name ->
         let src = In_channel.with_open_text (dir ^ name) In_channel.input_all in
         let body =
           try Yojson.Safe.pretty_to_string (Beloch.fold_string ~filename:name src)
           with Error.Beloch_error (_, msg) -> "ERROR: " ^ msg
         in
         let path = out ^ Filename.chop_suffix name ".bel" ^ ".fold" in
         Out_channel.with_open_text path (fun oc ->
             Out_channel.output_string oc body))
