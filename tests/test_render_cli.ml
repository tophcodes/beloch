open Render_cli

let test_which_found () =
  let dir = Filename.temp_file "render_cli_test" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o755;
  let path = Filename.concat dir "myprog" in
  let oc = open_out path in
  output_string oc "#!/bin/sh\nexit 0\n";
  close_out oc;
  Unix.chmod path 0o755;
  let saved_path = Sys.getenv_opt "PATH" in
  Unix.putenv "PATH" dir;
  let result = which "myprog" in
  (match saved_path with Some p -> Unix.putenv "PATH" p | None -> ());
  Sys.remove path;
  Unix.rmdir dir;
  Alcotest.(check bool) "found on PATH" true (result <> None)

let test_which_missing () =
  let dir = Filename.temp_file "render_cli_test" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o755;
  let saved_path = Sys.getenv_opt "PATH" in
  Unix.putenv "PATH" dir;
  let result = which "nonexistent-binary-xyz" in
  (match saved_path with Some p -> Unix.putenv "PATH" p | None -> ());
  Unix.rmdir dir;
  Alcotest.(check bool) "not found" true (result = None)

let test_dim_tty () =
  Alcotest.(check string) "dimmed" "\027[2mhint\027[0m" (dim ~is_tty:true "hint")

let test_dim_no_tty () =
  Alcotest.(check string) "plain" "hint" (dim ~is_tty:false "hint")

let () =
  Alcotest.run "render_cli"
    [
      ( "which",
        [
          Alcotest.test_case "found on PATH" `Quick test_which_found;
          Alcotest.test_case "not found" `Quick test_which_missing;
        ] );
      ( "dim",
        [
          Alcotest.test_case "tty wraps in ANSI dim" `Quick test_dim_tty;
          Alcotest.test_case "non-tty passes through" `Quick test_dim_no_tty;
        ] );
    ]
