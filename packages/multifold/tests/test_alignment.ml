open Multifold

let test_alphabet_size () =
  Alcotest.(check int)
    "17 two-fold symbols" 17
    (List.length Alignment.all_twofold)

let () =
  Alcotest.run "multifold-alignment"
    [ ("alphabet", [ Alcotest.test_case "size" `Quick test_alphabet_size ]) ]
