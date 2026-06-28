let test_error_roundtrip () =
  let pos = { Lexing.pos_fname = "x.bel"; pos_lnum = 3; pos_bol = 10; pos_cnum = 14 } in
  Alcotest.(check string) "span format" "x.bel:3:5" (Beloch.Error.span_to_string (pos, pos))

let () =
  Alcotest.run "beloch"
    [ ("error", [ Alcotest.test_case "span format" `Quick test_error_roundtrip ]) ]
