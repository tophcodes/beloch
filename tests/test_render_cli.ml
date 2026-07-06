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

let test_wants_help_flag () =
  Alcotest.(check bool) "--help" true (wants_help [ "--help" ]);
  Alcotest.(check bool) "-h" true (wants_help [ "-h" ]);
  Alcotest.(check bool)
    "mixed with other args" true
    (wants_help [ "f.bel"; "--legend"; "--help" ])

let test_wants_help_absent () =
  Alcotest.(check bool) "no help flag" false (wants_help [ "f.bel"; "--legend" ])

let contains_substring ~needle haystack =
  let nlen = String.length needle and hlen = String.length haystack in
  let rec loop i =
    if i + nlen > hlen then false
    else if String.sub haystack i nlen = needle then true
    else loop (i + 1)
  in
  nlen = 0 || loop 0

let test_render_help_mentions_flags () =
  List.iter
    (fun sub ->
      Alcotest.(check bool)
        (Printf.sprintf "render_help mentions %s" sub)
        true
        (contains_substring ~needle:sub render_help))
    [
      "beloch render";
      "--view cp|folded";
      "--flip";
      "--legend";
      "--step NAME|N";
      "--constructions";
      "--format svg|png";
      "--width";
      "--open";
    ]

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
      ( "wants_help",
        [
          Alcotest.test_case "recognizes --help/-h" `Quick test_wants_help_flag;
          Alcotest.test_case "false without a help flag" `Quick
            test_wants_help_absent;
        ] );
      ( "render_help",
        [
          Alcotest.test_case "mentions every flag" `Quick
            test_render_help_mentions_flags;
        ] );
    ]
