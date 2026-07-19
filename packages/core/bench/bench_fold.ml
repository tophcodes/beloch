(* End-to-end fold benchmark — the honest measure for the coordinate-arithmetic
   hot path (#57). bench_real_roots probes the root-finding tier; this one folds
   whole .bel programs, so it sees the ℚ(α) fast path that Num.add/Num.mul route
   through. A √2 base (fish, rabbit ear) does hundreds of thousands of in-field
   +/*; before the fix each factored a polynomial in generic qqbar.

   Prints a human line (stderr) and a machine-readable CSV line (stdout) so a
   run can be diffed across optimizations:

     dune exec packages/core/bench/bench_fold.exe > before.csv
     ...apply optimization, rebuild...
     dune exec packages/core/bench/bench_fold.exe > after.csv
     diff before.csv after.csv

   Usage: dune exec packages/core/bench/bench_fold.exe -- [case ...]   (default: all) *)

let root =
  match Sys.getenv_opt "DUNE_SOURCEROOT" with
  | Some r -> r
  | None ->
    Filename.concat (Filename.dirname Sys.executable_name) "../../../../.."

(* (name, path relative to repo root) — representative folds, √2-heavy first *)
let corpus =
  [ ("fish-base", "examples/bases/fish-base.bel");
    ("swivel-rabbit", "examples/bases/swivel-rabbit.bel");
    ("rabbit-ear", "packages/core/tests/cases/collapse/flatten-rabbit-ear-toward-a.bel");
    ("two-ear-fish", "packages/core/tests/cases/collapse/flatten-two-ears-sequential.bel");
    ("cube-root", "packages/core/tests/cases/fold/cube-root.bel") ]

let time f =
  let t0 = Unix.gettimeofday () in
  let r = f () in
  (r, Unix.gettimeofday () -. t0)

let run (name, rel) =
  let src =
    In_channel.with_open_text (Filename.concat root rel) In_channel.input_all
  in
  let _, secs = time (fun () -> Beloch.fold_string ~filename:rel src) in
  Printf.eprintf "%-16s | %8.3fs\n%!" name secs;
  Printf.printf "CSV,%s,%.4f\n%!" name secs

let () =
  let cases =
    if Array.length Sys.argv > 1 then
      let want = Array.to_list (Array.sub Sys.argv 1 (Array.length Sys.argv - 1)) in
      List.filter (fun (n, _) -> List.mem n want) corpus
    else corpus
  in
  print_string "# CSV,case,total_s\n";
  List.iter run cases
