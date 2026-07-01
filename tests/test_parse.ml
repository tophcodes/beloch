open Beloch

let[@warning "-32"] expect_error msg_substr thunk =
  try
    ignore (thunk ());
    Alcotest.fail ("expected error containing: " ^ msg_substr)
  with Error.Beloch_error (_, m) ->
    Alcotest.(check bool)
      ("error mentions " ^ msg_substr)
      true
      (try
         ignore (Str.search_forward (Str.regexp_string msg_substr) m 0);
         true
       with Not_found -> false)

(* ---- Error ---- *)

let test_error_roundtrip () =
  let pos =
    { Lexing.pos_fname = "x.bel"; pos_lnum = 3; pos_bol = 10; pos_cnum = 14 }
  in
  Alcotest.(check string)
    "span format" "x.bel:3:5"
    (Beloch.Error.span_to_string (pos, pos))

(* ---- Parse ---- *)

let test_parse_named_and_anon () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       --d1: through .a .c\n\
       map .b onto .d\n\
       .center: cross --d1 --d2\n"
  in
  Alcotest.(check int) "three statements" 3 (List.length prog);
  match prog with
  | [
   Ast.Crease (Some "d1", Ast.Through _, _, _);
   Ast.Crease (None, Ast.MapPoints _, _, _);
   Ast.Point ("center", Ast.Cross _, _);
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape"

let test_parse_syntax_error () =
  try
    ignore (Beloch.parse ~filename:"t.bel" "paper square\nmap .a\n");
    Alcotest.fail "expected a syntax error"
  with Error.Beloch_error (_, _) -> ()

let test_parse_perp () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d: through .a .c\nperp --d through .b\n"
  in
  match prog with
  | [
   Ast.Crease (Some "d", Ast.Through _, _, _);
   Ast.Crease
     ( None,
       Ast.Perp (Ast.PNamed { name = "b"; _ }, Ast.LNamed { cname = "d"; _ }),
       _,
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for perp"

let test_parse_inline_line () =
  match
    Beloch.parse ~filename:"t.bel" "paper square\nperp --(.a .b) through .c\n"
  with
  | [
   Ast.Crease
     (None, Ast.Perp (Ast.PNamed { name = "c"; _ }, Ast.LThrough _), _, _);
  ] ->
      ()
  | _ -> Alcotest.fail "expected an inline-line Perp operand"

let test_parse_inline_point_nested () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       --d1: through .a .c\n\
       --d2: through .b .d\n\
       perp --( .(--d1 --d2) .a ) through .b\n"
  with
  | [
   _;
   _;
   Ast.Crease
     (None, Ast.Perp (_, Ast.LThrough (Ast.PCross _, Ast.PNamed _, _)), _, _);
  ] ->
      ()
  | _ -> Alcotest.fail "expected a nested inline operand"

let test_parse_map_onto_line () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l1: through .a .b\n--l2: through .a .d\nmap .c onto --l1 perp --l2\n"
  in
  match prog with
  | [
   Ast.Crease (Some "l1", Ast.Through _, _, _);
   Ast.Crease (Some "l2", Ast.Through _, _, _);
   Ast.Crease
     ( None,
       Ast.MapOntoLine
         (Ast.PNamed { name = "c"; _ }, Ast.LNamed { cname = "l1"; _ },
          Ast.LNamed { cname = "l2"; _ }),
       _, _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for map-onto-line"

let test_parse_map_onto_line_inline () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l2: through .a .d\nmap .c onto --(.a .b) perp --l2\n"
  with
  | [
   _;
   Ast.Crease
     (None,
      Ast.MapOntoLine (Ast.PNamed { name = "c"; _ }, Ast.LThrough _,
                       Ast.LNamed { cname = "l2"; _ }), _, _);
  ] ->
      ()
  | _ -> Alcotest.fail "expected an inline target line in map-onto-line"

let test_parse_bisect () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       --v: map .a onto .b\n\
       --h: map .b onto .c\n\
       map --v onto --h toward .a\n"
  in
  match prog with
  | [
   _;
   _;
   Ast.Crease
     ( None,
       Ast.MapLines
         ( Ast.LNamed { cname = "v"; _ },
           Ast.LNamed { cname = "h"; _ },
           Some (Ast.PNamed { name = "a"; _ }) ),
       _,
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for bisect"

let test_parse_map_through () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d: through .a .b\nmap .c onto --d through .a\n"
  in
  match prog with
  | [
   Ast.Crease (Some "d", Ast.Through _, _, _);
   Ast.Crease
     ( None,
       Ast.MapThrough
         (Ast.PNamed { name = "c"; _ }, Ast.LNamed { cname = "d"; _ },
          Ast.PNamed { name = "a"; _ }, None),
       _, _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for map-through"

let test_parse_map_through_toward () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d: through .a .b\nmap .c onto --d through .a toward .b\n"
  in
  match prog with
  | [
   Ast.Crease (Some "d", Ast.Through _, _, _);
   Ast.Crease
     ( None,
       Ast.MapThrough
         (Ast.PNamed { name = "c"; _ }, Ast.LNamed { cname = "d"; _ },
          Ast.PNamed { name = "a"; _ }, Some (Ast.PNamed { name = "b"; _ })),
       _, _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for map-through-toward"

let test_parse_map_through_inline () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nmap .c onto --(.a .b) through .d\n"
  in
  match prog with
  | [
   Ast.Crease
     ( None,
       Ast.MapThrough
         ( Ast.PNamed { name = "c"; _ },
           Ast.LThrough (Ast.PNamed { name = "a"; _ }, Ast.PNamed { name = "b"; _ }, _),
           Ast.PNamed { name = "d"; _ }, None ),
       _, _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for map-through inline operand"

let test_parse_map_both () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nmap .a onto --d and .c onto --e\n"
  in
  match prog with
  | [ Ast.Crease (None, Ast.MapBoth (Ast.PNamed { name = "a"; _ },
                                      Ast.LNamed { cname = "d"; _ },
                                      Ast.PNamed { name = "c"; _ },
                                      Ast.LNamed { cname = "e"; _ },
                                      None), None, _) ] -> ()
  | _ -> Alcotest.fail "expected MapBoth without toward"

let test_parse_map_both_toward () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nmap .a onto --d and .c onto --e toward .b\n"
  in
  match prog with
  | [ Ast.Crease (None, Ast.MapBoth (_, _, _, _, Some _), None, _) ] -> ()
  | _ -> Alcotest.fail "expected MapBoth with toward"

let test_parse_fold_action () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n@map .a onto .c moving .a mountain\n"
  in
  match prog with
  | [
   Ast.Crease
     ( None,
       Ast.MapPoints _,
       Some
         {
           moving = Some (Ast.PNamed { name = "a"; _ });
           direction = Ast.Mountain;
         },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST for @map fold action"

let test_parse_fold_valley_default () =
  let prog = Beloch.parse ~filename:"t.bel" "paper square\n@map .a onto .c\n" in
  match prog with
  | [
   Ast.Crease
     (None, Ast.MapPoints _, Some { moving = None; direction = Ast.Valley }, _);
  ] ->
      ()
  | _ -> Alcotest.fail "default fold is valley with no moving"

let test_parse_precrease_no_foldspec () =
  let prog = Beloch.parse ~filename:"t.bel" "paper square\nmap .a onto .c\n" in
  match prog with
  | [ Ast.Crease (None, Ast.MapPoints _, None, _) ] -> ()
  | _ -> Alcotest.fail "bare axiom must carry no fold_spec"

let test_parse_flip () =
  match Beloch.parse ~filename:"t.bel" "paper square\nflip\n" with
  | [ Ast.Flip _ ] -> ()
  | _ -> Alcotest.fail "expected a single Flip statement"

let () =
  Alcotest.run "beloch-parse"
    [
      ("error", [ Alcotest.test_case "span format" `Quick test_error_roundtrip ]);
      ( "parse",
        [
          Alcotest.test_case "named and anonymous" `Quick
            test_parse_named_and_anon;
          Alcotest.test_case "syntax error" `Quick test_parse_syntax_error;
          Alcotest.test_case "perp parses" `Quick test_parse_perp;
          Alcotest.test_case "bisect parses" `Quick test_parse_bisect;
          Alcotest.test_case "fold action parses" `Quick test_parse_fold_action;
          Alcotest.test_case "fold valley default" `Quick
            test_parse_fold_valley_default;
          Alcotest.test_case "bare axiom has no fold_spec" `Quick
            test_parse_precrease_no_foldspec;
          Alcotest.test_case "flip parses" `Quick test_parse_flip;
          Alcotest.test_case "parse map onto line" `Quick test_parse_map_onto_line;
          Alcotest.test_case "parse map onto line inline" `Quick
            test_parse_map_onto_line_inline;
          Alcotest.test_case "parse map through" `Quick test_parse_map_through;
          Alcotest.test_case "parse map through toward" `Quick
            test_parse_map_through_toward;
          Alcotest.test_case "parse map through inline" `Quick
            test_parse_map_through_inline;
          Alcotest.test_case "parse map both" `Quick test_parse_map_both;
          Alcotest.test_case "parse map both toward" `Quick
            test_parse_map_both_toward;
          Alcotest.test_case "inline line operand" `Quick test_parse_inline_line;
          Alcotest.test_case "nested inline operand" `Quick
            test_parse_inline_point_nested;
        ] );
    ]
