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
       --d1 = through .a .c\n\
       map .b onto .d\n\
       .center = cross --d1 --d2\n"
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
      "paper square\n--d = through .a .c\nperp --d through .b\n"
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
       --d1 = through .a .c\n\
       --d2 = through .b .d\n\
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
      "paper square\n--l1 = through .a .b\n--l2 = through .a .d\nmap .c onto --l1 perp --l2\n"
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
      "paper square\n--l2 = through .a .d\nmap .c onto --(.a .b) perp --l2\n"
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
       --v = map .a onto .b\n\
       --h = map .b onto .c\n\
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
      "paper square\n--d = through .a .b\nmap .c onto --d through .a\n"
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
      "paper square\n--d = through .a .b\nmap .c onto --d through .a toward .b\n"
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
           moving = Some (Ast.FlapPoint (Ast.PNamed { name = "a"; _ }));
           up_to = None;
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
     ( None, Ast.MapPoints _,
       Some { moving = None; up_to = None; direction = Ast.Valley },
       _ );
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

let test_parse_eq_binding () =
  let prog = Beloch.parse ~filename:"t.bel"
    "paper square\n--d1 = through .a .c\n" in
  Alcotest.(check int) "one statement" 1 (List.length prog)

let test_parse_shorthand_rhs () =
  let prog = Beloch.parse ~filename:"t.bel"
    "paper square\n\
     --d = through .a .c\n\
     .m = .(--d --(.a .b))\n\
     --e = --(.a .c)\n" in
  Alcotest.(check int) "three statements" 3 (List.length prog);
  match prog with
  | [
      Ast.Crease (Some "d", Ast.Through _, _, _);
      Ast.Point ("m", Ast.Cross _, _);
      Ast.Crease (Some "e", Ast.Through _, _, _);
    ] -> ()
  | _ -> Alcotest.fail "unexpected AST shape"

(* ---- Def ---- *)

let test_parse_def () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       def petal(.p .q --base) {\n\
      \  @map .p onto .q moving .p\n\
      \  .tip = cross --(.p .q) --base\n\
       }\n"
  in
  match prog with
  | [ Ast.Def ("petal", params, body, _) ] ->
      Alcotest.(check int) "3 params" 3 (List.length params);
      Alcotest.(check int) "2 body stmts" 2 (List.length body);
      let p0 = List.nth params 0 and p2 = List.nth params 2 in
      Alcotest.(check string) "p0 name" "p" p0.Ast.pname;
      Alcotest.(check bool) "p0 is point" true (p0.Ast.pkind = `Point);
      Alcotest.(check bool) "p2 is line" true (p2.Ast.pkind = `Line)
  | _ -> Alcotest.fail "expected a single Def"

let test_parse_def_zero_params () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\ndef thirds() {\n  --pq = through .x .y\n}\n"
  with
  | [ Ast.Def ("thirds", [], [ _ ], _) ] -> ()
  | _ -> Alcotest.fail "expected zero-param Def"

let test_parse_def_in_def_rejected () =
  expect_error "syntax error" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\ndef a() {\n  def b() {\n  }\n}\n")

let test_parse_step_in_body_rejected () =
  expect_error "syntax error" (fun () ->
      Beloch.parse ~filename:"t.bel" "paper square\ndef a() {\n  step x\n}\n")

let test_parse_kebab_rejected () =
  expect_error "unexpected character" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\n--foo-bar = through .a .b\n")

(* ---- Apply ---- *)

let test_parse_apply_bound () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n$p1 = apply petal(.b .d --(.a .c))\n"
  with
  | [ Ast.Apply (Some "p1", "petal", [ _; _; _ ], _) ] -> ()
  | _ -> Alcotest.fail "expected bound Apply with 3 args"

let test_parse_apply_naked () =
  match Beloch.parse ~filename:"t.bel" "paper square\napply thirds()\n" with
  | [ Ast.Apply (None, "thirds", [], _) ] -> ()
  | _ -> Alcotest.fail "expected naked zero-arg Apply"

let test_parse_member_operands () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       @map .[$p1 tip] onto .[$p2 tip]\n\
       .x = cross --[$p1 pq] --[$p2 pq]\n"
  with
  | [
      Ast.Crease (None, Ast.MapPoints (Ast.PMember ("p1", "tip", _), _), _, _);
      Ast.Point ("x", Ast.Cross (Ast.LMember ("p1", "pq", _), _), _);
    ] ->
      ()
  | _ -> Alcotest.fail "expected member operands"

(* ---- Export ---- *)

let test_parse_export_selective () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\nexport { .tip as .left_tip --pq .s! } $t\n"
  with
  | [ Ast.Export (Some [ e1; e2; e3 ], "t", _) ] ->
      Alcotest.(check string) "e1 src" "tip" e1.Ast.esrc;
      Alcotest.(check bool) "e1 renamed" true (e1.Ast.erename = Some "left_tip");
      Alcotest.(check bool) "e2 is line" true (e2.Ast.ekind = `Line);
      Alcotest.(check bool) "e3 shadow" true e3.Ast.eshadow
  | _ -> Alcotest.fail "expected selective Export with 3 entries"

let test_parse_export_all () =
  match Beloch.parse ~filename:"t.bel" "paper square\nexport $t\n" with
  | [ Ast.Export (None, "t", _) ] -> ()
  | _ -> Alcotest.fail "expected export-all"

let test_parse_export_kind_mismatch_rename () =
  expect_error "keep the kind" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nexport { .m as --m2 } $t\n")

(* ---- Step ---- *)

let test_parse_step_marker () =
  match Beloch.parse ~filename:"t.bel" "paper square\nstep thirds\nflip\n" with
  | [ Ast.StepMark ("thirds", _); Ast.Flip _ ] -> ()
  | _ -> Alcotest.fail "expected StepMark then Flip"

let test_parse_at_one_selector () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--b = through .a .c\nperp --b at .a through .c\n"
  in
  match prog with
  | [ Ast.Crease (Some "b", _, _, _);
      Ast.Crease
        (None, Ast.Perp (_, Ast.LAt (_, [ Ast.SelPoint _ ], _)), _, _) ] -> ()
  | _ -> Alcotest.fail "expected LAt with one point selector"

let test_parse_at_two_selectors () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--b = through .a .c\nperp --b at (.a and --b) through .c\n"
  in
  match prog with
  | [ _;
      Ast.Crease
        ( None,
          Ast.Perp (_, Ast.LAt (_, [ Ast.SelPoint _; Ast.SelLine _ ], _)),
          _, _ ) ] -> ()
  | _ -> Alcotest.fail "expected LAt with two selectors"

let test_parse_meet_stmt () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d1 = through .a .b\n--d2 = through .c .d\n.o = --d1 * --d2\n"
  in
  match List.rev prog with
  | Ast.Point ("o", Ast.Cross (Ast.LNamed a, Ast.LNamed b), _) :: _ ->
      Alcotest.(check string) "lhs" "d1" a.Ast.cname;
      Alcotest.(check string) "rhs" "d2" b.Ast.cname
  | _ -> Alcotest.fail "expected .o = Cross(d1, d2)"

let test_parse_meet_inline () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d1 = through .a .b\n--d2 = through .c .d\n\
       map (--d1 * --d2) onto .e\n"
  in
  match List.rev prog with
  | Ast.Crease (None, Ast.MapPoints (Ast.PCross _, Ast.PNamed _), _, _) :: _ -> ()
  | _ -> Alcotest.fail "expected map (PCross) onto .e"

(* ---- Spec corpus ---- *)

let spec_corpus =
  [
    ( "01_eq_binding",
      "paper square\n--rs = through .rs1 .rs2\n.s   = cross --rs --(.d .c)\n" );
    ( "02_shorthand_rhs",
      "paper square\n.s  = .(--rs --(.d .c))\n--e = --(.p1 .p2)\n" );
    ( "03_def_petal",
      "paper square\ndef petal(.p .q --base) {\n\
      \  @map .p onto .q moving .p\n\
      \  .tip = cross --(.p .q) --base\n\
       }\n" );
    ( "04_apply",
      "paper square\n$p1 = apply petal(.k1 .k2 --(.k1 .k3))\n\
       apply petal(.k2 .k4 --(.k2 .k1))\n" );
    ( "05_qualified",
      "paper square\n@map .[$p1 tip] onto .[$p2 tip]\n\
       --d = through .[$p1 tip] .[$p2 tip]\n\
       .x  = cross --[$p1 pq] --[$p2 pq]\n" );
    ( "06_export",
      "paper square\nexport { .tip --pq } $t\n\
       export { .tip as .left_tip } $t\nexport { .s! } $t\nexport $t\n" );
    ( "07_panels",
      "paper square\nstep thirds\n._mb = .(--vm --(.a .b))\n\
       --pq = through ._pq1 ._pq2\n\nstep beloch_fold\n\
       @map .c onto --(.a .b) and .s onto --pq\n" );
    ( "08_cube_root",
      "paper square\n\nstep vertical_middle\n--vm = map .a onto .b\n\n\
       step thirds\n._mb  = .(--vm --(.a .b))\n._mt  = .(--vm --(.d .c))\n\
       ._pq1 = cross --(.d ._mb) --(.a .c)\n\
       ._pq2 = cross --(.a ._mt) --(.d .b)\n--pq  = through ._pq1 ._pq2\n\
       ._rs1 = cross --(.c ._mb) --(.d .b)\n\
       ._rs2 = cross --(.b ._mt) --(.a .c)\n--rs  = through ._rs1 ._rs2\n\
       .s    = .(--rs --(.d .c))\n\nstep beloch_fold\n\
       @map .c onto --(.a .b) and .s onto --pq\n" );
    ( "09_petal_full",
      "paper square\n\ndef petal(.p .q --base) {\n\
      \  @map .p onto .q moving .p\n\
      \  .tip = cross --(.p .q) --base\n\
       }\n\nstep petal_folds\n$left  = apply petal(.a .c --(.b .d))\n\
       $right = apply petal(.b .d --(.a .c))\n\nstep join\n\
       @map .[$left tip] onto .[$right tip]\n" );
    ( "10_zero_params",
      "paper square\ndef thirds() {\n\
      \  ._mb = .(--vm --(.a .b))\n\
      \  --pq = through ._mb .x\n\
       }\n$t = apply thirds()\nexport $t\n" );
  ]

(* ---- Fold scope: up to / flap operands / @fold ---- *)

let test_parse_up_to () =
  match
    Beloch.parse ~filename:"t.bel" "paper square\n@map .c onto .d up to .c\n"
  with
  | [
   Ast.Crease
     ( None,
       Ast.MapPoints _,
       Some
         {
           moving = None;
           up_to = Some (Ast.FlapPoint (Ast.PNamed { name = "c"; _ }));
           direction = Ast.Valley;
         },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "expected an up-to fold_spec"

let test_parse_flap_forms () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n@perp --d through .p moving #(.a .b) up to --d mountain\n"
  with
  | [
   Ast.Crease
     ( None,
       Ast.Perp _,
       Some
         {
           moving = Some (Ast.FlapSpec _);
           up_to = Some (Ast.FlapLine (Ast.LNamed { cname = "d"; _ }));
           direction = Ast.Mountain;
         },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "expected flap-spec moving + crease up-to + mountain"

let test_parse_fold_along () =
  match Beloch.parse ~filename:"t.bel" "paper square\n@fold --m moving .c\n" with
  | [
   Ast.FoldAlong
     ( Ast.LNamed { cname = "m"; _ },
       { moving = Some (Ast.FlapPoint _); up_to = None; direction = Ast.Valley },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "expected an @fold statement"

(* ---- Collapse ---- *)

let test_parse_collapse_basic () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n@collapse --a and --b and --c and --e mountain\n"
  in
  match prog with
  | [ Ast.Collapse (elems, [], None, _) ] ->
      Alcotest.(check int) "4 elements" 4 (List.length elems);
      let dirs = List.map (fun (e : Ast.collapse_elem) -> e.Ast.cdir) elems in
      Alcotest.(check bool) "last is mountain, first is valley"
        true
        (List.nth dirs 3 = Ast.Mountain && List.nth dirs 0 = Ast.Valley)
  | _ -> Alcotest.fail "expected Collapse"

let test_parse_collapse_parens_at_over_standing () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       @collapse --a at .a and (--e at (.o and --(.a .b)) mountain) \
       and .b over .d and standing .m\n"
  in
  match prog with
  | [ Ast.Collapse ([ _; e2 ], [ (_, _) ], Some _, _) ] ->
      Alcotest.(check bool) "parenthesized elem is mountain"
        true (e2.Ast.cdir = Ast.Mountain)
  | _ -> Alcotest.fail "expected Collapse with over + standing"

let test_parse_collapse_followed_by_stmt () =
  (* regression: a bare @collapse must not swallow the next statement's
     leading .point/--crease as a phantom over clause *)
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n@collapse --a and --b mountain\n.x = cross --a --b\n"
  in
  match prog with
  | [ Ast.Collapse ([ _; _ ], [], None, _); Ast.Point ("x", _, _) ] -> ()
  | _ -> Alcotest.fail "expected Collapse then Point"

let test_parse_collapse_mixed_order () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n@collapse --a and .p over .q and --b and standing .r\n"
  in
  match prog with
  | [
   Ast.Collapse
     ( [
         { Ast.cline = Ast.LNamed { cname = "a"; _ }; _ };
         { Ast.cline = Ast.LNamed { cname = "b"; _ }; _ };
       ],
       [
         ( Ast.FlapPoint (Ast.PNamed { name = "p"; _ }),
           Ast.FlapPoint (Ast.PNamed { name = "q"; _ }) );
       ],
       Some (Ast.FlapPoint (Ast.PNamed { name = "r"; _ })),
       _ );
  ] ->
      ()
  | _ ->
      Alcotest.fail
        "expected Collapse with elems [a;b] in source order, over (.p, .q) \
         not swapped, standing .r"

let test_parse_collapse_double_standing_rejected () =
  let src = "paper square\n@collapse --a and standing .p and standing .q\n" in
  expect_error "only one standing" (fun () -> Beloch.parse ~filename:"t.bel" src);
  (* the error must point at the duplicate (second, source-order) `standing`,
     not the first *)
  let first_standing = Str.search_forward (Str.regexp_string "standing") src 0 in
  let second_standing =
    Str.search_forward (Str.regexp_string "standing") src (first_standing + 1)
  in
  match Beloch.parse ~filename:"t.bel" src with
  | _ -> Alcotest.fail "expected duplicate-standing error"
  | exception Error.Beloch_error ((start, _), _) ->
      Alcotest.(check int)
        "span points at the second `standing`, not the first"
        second_standing start.Lexing.pos_cnum

let test_parse_spec_corpus () =
  List.iter
    (fun (name, src) ->
      try ignore (Beloch.parse ~filename:(name ^ ".bel") src)
      with Error.Beloch_error (_, m) ->
        Alcotest.fail (Printf.sprintf "%s failed to parse: %s" name m))
    spec_corpus

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
          Alcotest.test_case "eq binding separator" `Quick test_parse_eq_binding;
          Alcotest.test_case "shorthand RHS .(l1 l2) and --(p1 p2)" `Quick
            test_parse_shorthand_rhs;
          Alcotest.test_case "parse def" `Quick test_parse_def;
          Alcotest.test_case "parse def zero params" `Quick test_parse_def_zero_params;
          Alcotest.test_case "parse def in def rejected" `Quick test_parse_def_in_def_rejected;
          Alcotest.test_case "parse step in body rejected" `Quick test_parse_step_in_body_rejected;
          Alcotest.test_case "parse kebab rejected" `Quick test_parse_kebab_rejected;
          Alcotest.test_case "at operator, one selector" `Quick
            test_parse_at_one_selector;
          Alcotest.test_case "at operator, two selectors" `Quick
            test_parse_at_two_selectors;
          Alcotest.test_case "meet operator, statement" `Quick
            test_parse_meet_stmt;
          Alcotest.test_case "meet operator, inline" `Quick
            test_parse_meet_inline;
          Alcotest.test_case "up to fold_spec" `Quick test_parse_up_to;
          Alcotest.test_case "flap operand forms" `Quick test_parse_flap_forms;
          Alcotest.test_case "@fold statement" `Quick test_parse_fold_along;
          Alcotest.test_case "collapse basic" `Quick test_parse_collapse_basic;
          Alcotest.test_case "collapse parens/at/over/standing" `Quick
            test_parse_collapse_parens_at_over_standing;
          Alcotest.test_case "collapse followed by stmt" `Quick
            test_parse_collapse_followed_by_stmt;
          Alcotest.test_case "collapse mixed item order" `Quick
            test_parse_collapse_mixed_order;
          Alcotest.test_case "collapse double standing rejected" `Quick
            test_parse_collapse_double_standing_rejected;
        ] );
      ( "export",
        [
          Alcotest.test_case "selective export" `Quick test_parse_export_selective;
          Alcotest.test_case "export all" `Quick test_parse_export_all;
          Alcotest.test_case "export kind mismatch rename" `Quick
            test_parse_export_kind_mismatch_rename;
        ] );
      ( "apply",
        [
          Alcotest.test_case "apply bound" `Quick test_parse_apply_bound;
          Alcotest.test_case "apply naked" `Quick test_parse_apply_naked;
          Alcotest.test_case "member operands" `Quick test_parse_member_operands;
        ] );
      ( "step",
        [
          Alcotest.test_case "step marker" `Quick test_parse_step_marker;
        ] );
      ( "spec_corpus",
        [
          Alcotest.test_case "all 10 spec examples parse" `Quick
            test_parse_spec_corpus;
        ] );
    ]
