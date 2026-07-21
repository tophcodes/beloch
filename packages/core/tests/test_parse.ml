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
    "span format" "x.bel:3:5-5"
    (Beloch.Error.span_to_string (pos, pos))

(* ---- Parse ---- *)

let test_parse_named_and_anon () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       --d1 = through .a .c\n\
       mark map .b onto .d\n\
       .center = --d1 * --d2\n"
  in
  Alcotest.(check int) "three statements" 3 (List.length prog);
  match prog with
  | [
   Ast.BindLine ("d1", Ast.Through _, _);
   Ast.Mark (None, Ast.MMotion (Ast.MapPoints _), Ast.Full, Ast.Valley, None, _);
   Ast.Point ("center", Ast.PsExpr (Ast.PSelect _), _);
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape"

let test_parse_syntax_error () =
  try
    ignore (Beloch.parse ~filename:"t.bel" "paper square\nmark map .a\n");
    Alcotest.fail "expected a syntax error"
  with Error.Beloch_error (_, _) -> ()

let test_parse_perp () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d = through .a .c\nmark perp --d through .b\n"
  in
  match prog with
  | [
   Ast.BindLine ("d", Ast.Through _, _);
   Ast.Mark
     ( None,
       Ast.MMotion
         (Ast.Perp (Ast.PNamed { name = "b"; _ }, Ast.LNamed { cname = "d"; _ })), Ast.Full, Ast.Valley, None,
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for perp"

let test_parse_parenthesized_axiom () =
  (* parenthesising an axiom is purely syntactic: same AST as the bare form *)
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nmark (map .a onto .b) at .c\n"
  in
  match prog with
  | [
   Ast.Mark
     ( None,
       Ast.MMotion (Ast.MapPoints _),
       Ast.At (Ast.PNamed { name = "c"; _ }),
       Ast.Valley,
       None,
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for parenthesized axiom"

let test_parse_map_onto_line () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l1 = through .a .b\n--l2 = through .a .d\nmark map .c onto --l1 perp --l2\n"
  in
  match prog with
  | [
   Ast.BindLine ("l1", Ast.Through _, _);
   Ast.BindLine ("l2", Ast.Through _, _);
   Ast.Mark
     ( None,
       Ast.MMotion
         (Ast.MapOntoLine
            (Ast.PNamed { name = "c"; _ }, Ast.LNamed { cname = "l1"; _ },
             Ast.LNamed { cname = "l2"; _ })), Ast.Full, Ast.Valley, None,
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for map-onto-line"

let test_parse_bisect () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       --v = map .a onto .b\n\
       --h = map .b onto .c\n\
       mark map --v onto --h toward .a\n"
  in
  match prog with
  | [
   _;
   _;
   Ast.Mark
     ( None,
       Ast.MMotion
         (Ast.MapLines
            ( Ast.LNamed { cname = "v"; _ },
              Ast.LNamed { cname = "h"; _ },
              Some (Ast.PNamed { name = "a"; _ }) )), Ast.Full, Ast.Valley, None,
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for bisect"

let test_parse_map_through () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d = through .a .b\nmark map .c onto --d through .a\n"
  in
  match prog with
  | [
   Ast.BindLine ("d", Ast.Through _, _);
   Ast.Mark
     ( None,
       Ast.MMotion
         (Ast.MapThrough
            (Ast.PNamed { name = "c"; _ }, Ast.LNamed { cname = "d"; _ },
             Ast.PNamed { name = "a"; _ }, None)), Ast.Full, Ast.Valley, None,
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for map-through"

let test_parse_map_through_toward () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d = through .a .b\nmark map .c onto --d through .a toward .b\n"
  in
  match prog with
  | [
   Ast.BindLine ("d", Ast.Through _, _);
   Ast.Mark
     ( None,
       Ast.MMotion
         (Ast.MapThrough
            (Ast.PNamed { name = "c"; _ }, Ast.LNamed { cname = "d"; _ },
             Ast.PNamed { name = "a"; _ }, Some (Ast.PNamed { name = "b"; _ }))), Ast.Full, Ast.Valley, None,
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for map-through-toward"

let test_parse_map_both () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nmark map .a onto --d and .c onto --e\n"
  in
  match prog with
  | [ Ast.Mark (None, Ast.MMotion (Ast.MapBoth (Ast.PNamed { name = "a"; _ },
                                      Ast.LNamed { cname = "d"; _ },
                                      Ast.PNamed { name = "c"; _ },
                                      Ast.LNamed { cname = "e"; _ },
                                      None)), Ast.Full, Ast.Valley, None, _) ] -> ()
  | _ -> Alcotest.fail "expected MapBoth without toward"

let test_parse_map_both_toward () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nmark map .a onto --d and .c onto --e toward .b\n"
  in
  match prog with
  | [ Ast.Mark (None, Ast.MMotion (Ast.MapBoth (_, _, _, _, Some _)), Ast.Full, Ast.Valley, None, _) ] -> ()
  | _ -> Alcotest.fail "expected MapBoth with toward"

let test_parse_fold_action () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nfold map .a onto .c moving .a mountain\n"
  in
  match prog with
  | [
   Ast.Fold
     ( None,
       Ast.MMotion (Ast.MapPoints _),
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
  let prog = Beloch.parse ~filename:"t.bel" "paper square\nfold map .a onto .c\n" in
  match prog with
  | [
   Ast.Fold
     ( None, Ast.MMotion (Ast.MapPoints _),
       { moving = None; up_to = None; direction = Ast.Valley },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "default fold is valley with no moving"

let test_parse_precrease_no_foldspec () =
  let prog = Beloch.parse ~filename:"t.bel" "paper square\nmark map .a onto .c\n" in
  match prog with
  | [ Ast.Mark (None, Ast.MMotion (Ast.MapPoints _), Ast.Full, Ast.Valley, None, _) ] -> ()
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
     .m = --d * --ab\n\
     --e = through .a .c\n" in
  Alcotest.(check int) "three statements" 3 (List.length prog);
  match prog with
  | [
      Ast.BindLine ("d", Ast.Through _, _);
      Ast.Point ("m", Ast.PsExpr (Ast.PSelect _), _);
      Ast.BindLine ("e", Ast.Through _, _);
    ] -> ()
  | _ -> Alcotest.fail "unexpected AST shape"

(* ---- Def ---- *)

let test_parse_def () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       def petal(.p .q --base) {\n\
      \  fold map .p onto .q moving .p\n\
      \  .tip = .p * .q * --base\n\
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

let test_parse_kebab_rejected () =
  expect_error "unexpected character" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\n--foo-bar = through .a .b\n")

(* ---- Apply ---- *)

let test_parse_apply_bound () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n$p1 = apply petal(.b .d .a * .c)\n"
  with
  | [ Ast.Apply (Some "p1", "petal", [ _; _; _ ], _) ] -> ()
  | _ -> Alcotest.fail "expected bound Apply with 3 args"

let test_parse_apply_naked () =
  match Beloch.parse ~filename:"t.bel" "paper square\napply thirds()\n" with
  | [ Ast.Apply (None, "thirds", [], _) ] -> ()
  | _ -> Alcotest.fail "expected naked zero-arg Apply"

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

let test_parse_at_one_selector () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--b = through .a .c\nmark perp --b & .a through .c\n"
  in
  match prog with
  | [ Ast.BindLine ("b", _, _);
      Ast.Mark
        (None, Ast.MMotion (Ast.Perp (_, Ast.LFilter (Ast.LNamed _, Ast.Keep (Ast.SelPoint _), _))), Ast.Full, Ast.Valley, None,
         _) ] -> ()
  | _ -> Alcotest.fail "expected --b & .a (LFilter, one point selector)"

let test_parse_at_two_selectors () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--b = through .a .c\nmark perp --b & .a & --b through .c\n"
  in
  match prog with
  | [ _;
      Ast.Mark
        ( None,
          Ast.MMotion
            (Ast.Perp
               (_,
                Ast.LFilter
                  (Ast.LFilter (Ast.LNamed _, Ast.Keep (Ast.SelPoint _), _),
                   Ast.Keep (Ast.SelLine _), _))), Ast.Full, Ast.Valley, None,
          _ ) ] -> ()
  | _ -> Alcotest.fail "expected --b & .a & --b (nested LFilter)"

let test_parse_meet_stmt () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d1 = through .a .b\n--d2 = through .c .d\n.o = --d1 * --d2\n"
  in
  match List.rev prog with
  | Ast.Point ("o", Ast.PsExpr (Ast.PSelect ([ Ast.LNamed a; Ast.LNamed b ], _)), _) :: _ ->
      Alcotest.(check string) "lhs" "d1" a.Ast.cname;
      Alcotest.(check string) "rhs" "d2" b.Ast.cname
  | _ -> Alcotest.fail "expected .o = Cross(d1, d2)"

let test_parse_meet_inline () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d1 = through .a .b\n--d2 = through .c .d\n\
       mark map (--d1 * --d2) onto .e\n"
  in
  match List.rev prog with
  | Ast.Mark (None, Ast.MMotion (Ast.MapPoints (Ast.PSelect _, Ast.PNamed _)), Ast.Full, Ast.Valley, None, _) :: _ -> ()
  | _ -> Alcotest.fail "expected map (PSelect) onto .e"

(* ---- Spec corpus ---- *)

let spec_corpus =
  [
    ( "01_eq_binding",
      "paper square\n--rs = through .rs1 .rs2\n.s   = --rs * --cd\n" );
    ( "02_shorthand_rhs",
      "paper square\n.s  = --rs * --cd\n--e = through .p1 .p2\n" );
    ( "03_def_petal",
      "paper square\ndef petal(.p .q --base) {\n\
      \  fold map .p onto .q moving .p\n\
      \  .tip = .p * .q * --base\n\
       }\n" );
    ( "04_apply",
      "paper square\n$p1 = apply petal(.k1 .k2 .k1 * .k3)\n\
       apply petal(.k2 .k4 .k2 * .k1)\n" );
    ( "05_qualified",
      "paper square\n\
       export { .tip as .p1tip --pq as --p1pq } $p1\n\
       export { .tip as .p2tip --pq as --p2pq } $p2\n\
       fold map .p1tip onto .p2tip\n\
       --d = through .p1tip .p2tip\n\
       .x  = --p1pq * --p2pq\n" );
    ( "06_export",
      "paper square\nexport { .tip --pq } $t\n\
       export { .tip as .left_tip } $t\nexport { .s! } $t\nexport $t\n" );
    ( "07_panels",
      "paper square\n._mb = --vm * --ab\n\
       --pq = through ._pq1 ._pq2\n\
       fold map .c onto --ab and .s onto --pq\n" );
    ( "08_cube_root",
      "paper square\n\n--vm = map .a onto .b\n\n\
       ._mb  = --vm * --ab\n._mt  = --vm * --cd\n\
       --ac = through .a .c\n--db = through .d .b\n\
       --d_mb = through .d ._mb\n--a_mt = through .a ._mt\n\
       --c_mb = through .c ._mb\n--b_mt = through .b ._mt\n\
       ._pq1 = --d_mb * --ac\n\
       ._pq2 = --a_mt * --db\n--pq  = through ._pq1 ._pq2\n\
       ._rs1 = --c_mb * --db\n\
       ._rs2 = --b_mt * --ac\n--rs  = through ._rs1 ._rs2\n\
       .s    = --rs * --cd\n\n\
       fold map .c onto --ab and .s onto --pq\n" );
    ( "09_petal_full",
      "paper square\n\ndef petal(.p .q --base) {\n\
      \  fold map .p onto .q moving .p\n\
      \  .tip = .p * .q * --base\n\
       }\n\n$left  = apply petal(.a .c .b * .d)\n\
       $right = apply petal(.b .d .a * .c)\n\n\
       export { .tip as .lefttip } $left\n\
       export { .tip as .righttip } $right\n\
       fold map .lefttip onto .righttip\n" );
    ( "10_zero_params",
      "paper square\ndef thirds() {\n\
      \  ._mb = --vm * --ab\n\
      \  --pq = through ._mb .x\n\
       }\n$t = apply thirds()\nexport $t\n" );
  ]

(* ---- Fold scope: up to / flap operands / @fold ---- *)

let test_parse_up_to () =
  match
    Beloch.parse ~filename:"t.bel" "paper square\nfold map .c onto .d up to .c\n"
  with
  | [
   Ast.Fold
     ( None,
       Ast.MMotion (Ast.MapPoints _),
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
      "paper square\nfold perp --d through .p moving #[.a .b] up to --d mountain\n"
  with
  | [
   Ast.Fold
     ( None,
       Ast.MMotion (Ast.Perp _),
       {
         moving = Some (Ast.FlapSpec _);
         up_to = Some (Ast.FlapLine (Ast.LNamed { cname = "d"; _ }));
         direction = Ast.Mountain;
       },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "expected flap-spec moving + crease up-to + mountain"

let test_parse_flap_bracket () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\nfold perp --d through .p moving #[.a .b]\n"
  with
  | [ Ast.Fold (None, Ast.MMotion (Ast.Perp _),
        { moving = Some (Ast.FlapSpec (Ast.FByPoints (pts, _))); _ }, _) ] ->
      Alcotest.(check int) "two constraint points" 2 (List.length pts)
  | _ -> Alcotest.fail "expected moving #[.a .b]"

let test_parse_filter_chain () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l = through .a .b\nfold map .p onto .q up to --l & .c & --m\n"
  in
  match prog with
  | [ _; Ast.Fold (None, _, { up_to = Some (Ast.FlapLine
        (Ast.LFilter (Ast.LFilter (Ast.LNamed _, Ast.Keep (Ast.SelPoint _), _),
                      Ast.Keep (Ast.SelLine _), _))); _ }, _) ] -> ()
  | _ -> Alcotest.fail "expected up to --l & .c & --m (nested LFilter, Keep)"

let test_parse_diff () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l = through .a .b\nfold map .p onto .q up to --l \\ .c\n"
  in
  match prog with
  | [ _; Ast.Fold (None, _, { up_to = Some (Ast.FlapLine
        (Ast.LFilter (Ast.LNamed _, Ast.Drop _, _))); _ }, _) ] -> ()
  | _ -> Alcotest.fail "expected up to --l \\ .c (LFilter Drop)"

let test_parse_union () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--x = through .a .b\n--y = through .c .d\n\
       fold map .p onto .q up to [--x --y]\n"
  in
  match prog with
  | [ _; _; Ast.Fold (None, _, { up_to = Some (Ast.FlapLine
        (Ast.LUnion ([ Ast.LNamed _; Ast.LNamed _ ], _))); _ }, _) ] -> ()
  | _ -> Alcotest.fail "expected up to [--x --y] (LUnion of 2)"

let test_parse_bind_bundle () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l = through .a .b\n--seg = --l & .c\n"
  in
  match List.rev prog with
  | Ast.BindBundle ("seg", Ast.LFilter (Ast.LNamed _, Ast.Keep _, _), _) :: _ ->
      ()
  | _ -> Alcotest.fail "expected --seg = --l & .c (BindBundle LFilter)"

let test_parse_fold_along () =
  match Beloch.parse ~filename:"t.bel" "paper square\nfold --m moving .c\n" with
  | [
   Ast.Fold
     ( None, Ast.MLine (Ast.LNamed { cname = "m"; _ }),
       { moving = Some (Ast.FlapPoint _); up_to = None; direction = Ast.Valley },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "expected an @fold statement"

(* ---- Flatten ---- *)

let test_parse_flatten_basic () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nflatten (--a) (--b) (--c) (--e mountain)\n"
  in
  match prog with
  | [ Ast.Flatten (None, elems, [], None, None, _) ] ->
      Alcotest.(check int) "4 elements" 4 (List.length elems);
      let dirs = List.map (fun (e : Ast.collapse_elem) -> e.Ast.cdir) elems in
      Alcotest.(check bool) "last is mountain, first is free (unconstrained)"
        true
        (List.nth dirs 3 = Ast.MvMountain && List.nth dirs 0 = Ast.MvFree)
  | _ -> Alcotest.fail "expected Flatten"

let test_parse_flatten_parens_at_over_staying () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       flatten (--a & .a) (--e & .o & --ab mountain) \
       (.b over .d) (staying .m)\n"
  in
  match prog with
  | [ Ast.Flatten (None, [ _; e2 ], [ (_, _) ], Some _, None, _) ] ->
      Alcotest.(check bool) "parenthesized elem is mountain"
        true (e2.Ast.cdir = Ast.MvMountain)
  | _ -> Alcotest.fail "expected Flatten with over + staying"

let test_parse_flatten_followed_by_stmt () =
  (* regression: a bare @flatten must not swallow the next statement's
     leading .point/--crease as a phantom over clause *)
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nflatten (--a) (--b mountain)\n.x = --a * --b\n"
  in
  match prog with
  | [ Ast.Flatten (None, [ _; _ ], [], None, None, _); Ast.Point ("x", _, _) ] -> ()
  | _ -> Alcotest.fail "expected Flatten then Point"

let test_parse_flatten_mixed_order () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nflatten (--a) (.p over .q) (--b) (staying .r)\n"
  in
  match prog with
  | [
   Ast.Flatten
     ( None,
       [
         { Ast.cline = Ast.LNamed { cname = "a"; _ }; _ };
         { Ast.cline = Ast.LNamed { cname = "b"; _ }; _ };
       ],
       [
         ( Ast.FlapPoint (Ast.PNamed { name = "p"; _ }),
           Ast.FlapPoint (Ast.PNamed { name = "q"; _ }) );
       ],
       Some (Ast.FlapPoint (Ast.PNamed { name = "r"; _ })),
       None,
       _ );
  ] ->
      ()
  | _ ->
      Alcotest.fail
        "expected Flatten with elems [a;b] in source order, over (.p, .q) \
         not swapped, staying .r"

let test_parse_flatten_double_staying_rejected () =
  let src =
    "paper square\nflatten (--a) (staying .p) (staying .q)\n"
  in
  expect_error "only one staying" (fun () -> Beloch.parse ~filename:"t.bel" src);
  (* the error must point at the duplicate (second, source-order) `staying`,
     not the first *)
  let first_staying = Str.search_forward (Str.regexp_string "staying") src 0 in
  let second_staying =
    Str.search_forward (Str.regexp_string "staying") src (first_staying + 1)
  in
  match Beloch.parse ~filename:"t.bel" src with
  | _ -> Alcotest.fail "expected duplicate-staying error"
  | exception Error.Beloch_error ((start, _), _) ->
      Alcotest.(check int)
        "span points at the second `staying`, not the first"
        second_staying start.Lexing.pos_cnum

let test_parse_flatten_paren_items () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       flatten (--ac & .a) (--ac & .c) (--bd & .b) (--bd & .d)\n"
  in
  match prog with
  | [ Ast.Flatten (None, elems, [], None, None, _) ] ->
      Alcotest.(check int) "4 elements" 4 (List.length elems)
  | _ -> Alcotest.fail "expected Flatten with paren items"

let test_parse_flatten_toward_item () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       flatten (--a & .p) (--b & .q valley) (--c & .r mountain) {toward .s}\n"
  in
  match prog with
  | [
   Ast.Flatten
     (None, elems, [], None, Some (Ast.PNamed { name = "s"; _ }), _);
  ] ->
      let dirs = List.map (fun (e : Ast.collapse_elem) -> e.Ast.cdir) elems in
      Alcotest.(check bool)
        "cdirs = [free; valley; mountain]" true
        (dirs = [ Ast.MvFree; Ast.MvValley; Ast.MvMountain ])
  | _ ->
      Alcotest.fail "expected Flatten with {toward} item and tri-state cdirs"

let test_parse_flatten_toward_item_first_position () =
  (* {toward .s} parses identically in any item position, here first. *)
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       flatten {toward .s} (--a & .p) (--b & .q valley) (--c & .r mountain)\n"
  in
  match prog with
  | [
   Ast.Flatten
     (None, elems, [], None, Some (Ast.PNamed { name = "s"; _ }), _);
  ] ->
      let dirs = List.map (fun (e : Ast.collapse_elem) -> e.Ast.cdir) elems in
      Alcotest.(check bool)
        "cdirs = [free; valley; mountain]" true
        (dirs = [ Ast.MvFree; Ast.MvValley; Ast.MvMountain ])
  | _ ->
      Alcotest.fail "expected Flatten with {toward} in first item position"

let test_parse_flatten_double_toward_rejected () =
  let src = "paper square\nflatten (--a) {toward .p} {toward .q}\n" in
  expect_error "only one {toward} per flatten" (fun () ->
      Beloch.parse ~filename:"t.bel" src)

let test_parse_flatten_old_trailing_toward_rejected () =
  (* the old unparenthesised trailing `toward` is gone; only the `{toward}`
     item survives (spec 2026-07-16-flatten-derive-v2-design.md). *)
  expect_error "syntax error" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nflatten (--a) (--b) toward .c\n")

let test_parse_spec_corpus () =
  List.iter
    (fun (name, src) ->
      try ignore (Beloch.parse ~filename:(name ^ ".bel") src)
      with Error.Beloch_error (_, m) ->
        Alcotest.fail (Printf.sprintf "%s failed to parse: %s" name m))
    spec_corpus

let test_parse_line_select () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nfold map .d onto .a up to --[.a .b]\n"
  in
  match prog with
  | [
      Ast.Fold
        ( None, _,
            { up_to =
                Some
                  (Ast.FlapLine
                     (Ast.LSelect ([ Ast.SelPoint _; Ast.SelPoint _ ], _)));
              _ },
          _ );
    ] ->
      ()
  | _ -> Alcotest.fail "expected up to --[.a .b] (LSelect of 2 points)"

let test_parse_point_select () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--x = through .a .b\n--y = through .c .d\n.o = .[--x --y]\n"
  in
  match List.rev prog with
  | Ast.Point
      ("o", Ast.PsExpr (Ast.PSelect ([ Ast.LNamed _; Ast.LNamed _ ], _)), _)
    :: _ ->
      ()
  | _ -> Alcotest.fail "expected .o = .[--x --y] (PSelect of 2 lines)"

let test_parse_join_star () =
  let prog =
    Beloch.parse ~filename:"t.bel" "paper square\nfold map .d onto .a up to .a * .b\n"
  in
  match prog with
  | [
      Ast.Fold
        ( None, _,
            { up_to =
                Some
                  (Ast.FlapLine
                     (Ast.LSelect ([ Ast.SelPoint _; Ast.SelPoint _ ], _)));
              _ },
          _ );
    ] ->
      ()
  | _ -> Alcotest.fail "expected up to .a * .b (LSelect join of 2 points)"

(* & binds tighter than * : --l & .a * --s parses as (--l & .a) * --s, so the
   filtered crease resolves to one line before meet consumes it *)
let test_parse_filter_binds_before_meet () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l = through .a .c\n--s = through .b .d\n.o = --l & .a * --s\n"
  in
  match List.rev prog with
  | Ast.Point
      ("o", Ast.PsExpr (Ast.PSelect ([ Ast.LFilter _; Ast.LNamed _ ], _)), _)
    :: _ ->
      ()
  | _ -> Alcotest.fail "expected (--l & .a) * --s : PSelect[LFilter, LNamed]"

(* ---- Notation cutover: mark/fold/flatten verbs replace @/bare-axiom (#24) ---- *)

let test_parse_new_value_binding () =
  match Beloch.parse ~filename:"t.bel" "paper square\n--l = map .a onto .c\n" with
  | [ Ast.BindLine ("l", Ast.MapPoints _, _) ] -> ()
  | _ -> Alcotest.fail "expected --l = map .a onto .c : BindLine"

let test_parse_new_mark_bare () =
  match Beloch.parse ~filename:"t.bel" "paper square\nmark map .a onto .c\n" with
  | [ Ast.Mark (None, Ast.MMotion (Ast.MapPoints _), Ast.Full, Ast.Valley, None, _) ] -> ()
  | _ -> Alcotest.fail "expected mark map .a onto .c : Mark (None, MMotion)"

let test_parse_new_mark_named () =
  match
    Beloch.parse ~filename:"t.bel" "paper square\nmark --d = map .a onto .c\n"
  with
  | [ Ast.Mark (Some "d", Ast.MMotion (Ast.MapPoints _), Ast.Full, Ast.Valley, None, _) ] -> ()
  | _ -> Alcotest.fail "expected mark --d = map .a onto .c : Mark (Some \"d\", MMotion)"

let test_parse_mark_extent_direction_layer () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       mark --l between .a .b\n\
       mark --l at .m mountain\n\
       mark --l #[.c]\n\
       mark --d = map .a onto .b at .m\n"
  in
  match prog with
  | [
   Ast.Mark
     ( None, Ast.MLine (Ast.LNamed { cname = "l"; _ }),
       Ast.Between (Ast.PNamed { name = "a"; _ }, Ast.PNamed { name = "b"; _ }),
       Ast.Valley, None, _ );
   Ast.Mark
     ( None, Ast.MLine (Ast.LNamed { cname = "l"; _ }),
       Ast.At (Ast.PNamed { name = "m"; _ }), Ast.Mountain, None, _ );
   Ast.Mark
     ( None, Ast.MLine (Ast.LNamed { cname = "l"; _ }), Ast.Full, Ast.Valley,
       Some (Ast.FByPoints ([ Ast.PNamed { name = "c"; _ } ], _)), _ );
   Ast.Mark
     ( Some "d", Ast.MMotion (Ast.MapPoints _),
       Ast.At (Ast.PNamed { name = "m"; _ }), Ast.Valley, None, _ );
  ] ->
      ()
  | _ -> Alcotest.fail "mark extent/direction/layer did not parse as expected"

let test_parse_new_fold_motion () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\nfold map .a onto .c moving .a\n"
  with
  | [
   Ast.Fold
     ( None,
       Ast.MMotion (Ast.MapPoints _),
       { moving = Some (Ast.FlapPoint (Ast.PNamed { name = "a"; _ }));
         up_to = None; direction = Ast.Valley },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "expected fold map .a onto .c moving .a : Fold (None, MMotion, _)"

let test_parse_new_fold_named () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\nfold --d = map .a onto .c moving .a\n"
  with
  | [
   Ast.Fold
     ( Some "d",
       Ast.MMotion (Ast.MapPoints _),
       { moving = Some (Ast.FlapPoint (Ast.PNamed { name = "a"; _ }));
         up_to = None; direction = Ast.Valley },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "expected fold --d = map .a onto .c moving .a : Fold (Some \"d\", MMotion, _)"

let test_parse_new_fold_along () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d = map .a onto .c\nmark --d\nfold --d moving .a\n"
  with
  | [
   Ast.BindLine ("d", Ast.MapPoints _, _);
   Ast.Mark (None, Ast.MLine (Ast.LNamed { cname = "d"; _ }), Ast.Full, Ast.Valley, None, _);
   Ast.Fold
     ( None,
       Ast.MLine (Ast.LNamed { cname = "d"; _ }),
       { moving = Some (Ast.FlapPoint (Ast.PNamed { name = "a"; _ }));
         up_to = None; direction = Ast.Valley },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "expected --d = ...; mark --d; fold --d moving .a"

let test_parse_new_flatten_no_at () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\nflatten (--a) (--b) (--c) (--e mountain)\n"
  with
  | [ Ast.Flatten (None, elems, [], None, None, _) ] ->
      Alcotest.(check int) "4 elements" 4 (List.length elems)
  | _ -> Alcotest.fail "expected flatten (no @) to parse as Ast.Flatten"

let test_parse_at_retired () =
  (* `@` is no longer a token at all (AT retired): it's an unrecognised
     character, so the lexer rejects it before the parser ever sees it. *)
  expect_error "unexpected character" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\n@map .a onto .c moving .a\n");
  expect_error "unexpected character" (fun () ->
      Beloch.parse ~filename:"t.bel" "paper square\n@fold --d moving .a\n");
  expect_error "unexpected character" (fun () ->
      Beloch.parse ~filename:"t.bel" "paper square\n@flatten --a and --b\n")

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
          Alcotest.test_case "parenthesized axiom parses" `Quick
            test_parse_parenthesized_axiom;
          Alcotest.test_case "bisect parses" `Quick test_parse_bisect;
          Alcotest.test_case "fold action parses" `Quick test_parse_fold_action;
          Alcotest.test_case "fold valley default" `Quick
            test_parse_fold_valley_default;
          Alcotest.test_case "bare axiom has no fold_spec" `Quick
            test_parse_precrease_no_foldspec;
          Alcotest.test_case "flip parses" `Quick test_parse_flip;
          Alcotest.test_case "parse map onto line" `Quick test_parse_map_onto_line;
          Alcotest.test_case "parse map through" `Quick test_parse_map_through;
          Alcotest.test_case "parse map through toward" `Quick
            test_parse_map_through_toward;
          Alcotest.test_case "parse map both" `Quick test_parse_map_both;
          Alcotest.test_case "parse map both toward" `Quick
            test_parse_map_both_toward;
          Alcotest.test_case "eq binding separator" `Quick test_parse_eq_binding;
          Alcotest.test_case "shorthand RHS .(l1 l2) and --(p1 p2)" `Quick
            test_parse_shorthand_rhs;
          Alcotest.test_case "parse def" `Quick test_parse_def;
          Alcotest.test_case "parse def zero params" `Quick test_parse_def_zero_params;
          Alcotest.test_case "parse def in def rejected" `Quick test_parse_def_in_def_rejected;
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
          Alcotest.test_case "flap bracket #[]" `Quick test_parse_flap_bracket;
          Alcotest.test_case "filter chain & " `Quick test_parse_filter_chain;
          Alcotest.test_case "diff \\" `Quick test_parse_diff;
          Alcotest.test_case "union []" `Quick test_parse_union;
          Alcotest.test_case "bind bundle" `Quick test_parse_bind_bundle;
          Alcotest.test_case "@fold statement" `Quick test_parse_fold_along;
          Alcotest.test_case "flatten basic" `Quick test_parse_flatten_basic;
          Alcotest.test_case "flatten parens/at/over/staying" `Quick
            test_parse_flatten_parens_at_over_staying;
          Alcotest.test_case "flatten followed by stmt" `Quick
            test_parse_flatten_followed_by_stmt;
          Alcotest.test_case "flatten mixed item order" `Quick
            test_parse_flatten_mixed_order;
          Alcotest.test_case "flatten double staying rejected" `Quick
            test_parse_flatten_double_staying_rejected;
          Alcotest.test_case "flatten paren-juxtaposition items" `Quick
            test_parse_flatten_paren_items;
          Alcotest.test_case "flatten {toward} item, tri-state cdirs" `Quick
            test_parse_flatten_toward_item;
          Alcotest.test_case "flatten {toward} item in first position" `Quick
            test_parse_flatten_toward_item_first_position;
          Alcotest.test_case "flatten double {toward} rejected" `Quick
            test_parse_flatten_double_toward_rejected;
          Alcotest.test_case "flatten old trailing toward rejected" `Quick
            test_parse_flatten_old_trailing_toward_rejected;
        ] );
      ( "notation_cutover",
        [
          Alcotest.test_case "value binding --l = <motion>" `Quick
            test_parse_new_value_binding;
          Alcotest.test_case "mark bare motion" `Quick test_parse_new_mark_bare;
          Alcotest.test_case "mark named" `Quick test_parse_new_mark_named;
          Alcotest.test_case "mark extent/direction/layer" `Quick
            test_parse_mark_extent_direction_layer;
          Alcotest.test_case "fold motion" `Quick test_parse_new_fold_motion;
          Alcotest.test_case "fold named" `Quick test_parse_new_fold_named;
          Alcotest.test_case "fold along existing crease" `Quick
            test_parse_new_fold_along;
          Alcotest.test_case "flatten without @" `Quick
            test_parse_new_flatten_no_at;
          Alcotest.test_case "@ is retired" `Quick test_parse_at_retired;
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
          Alcotest.test_case "line select --[.a .b]" `Quick
            test_parse_line_select;
          Alcotest.test_case "point select .[--x --y]" `Quick
            test_parse_point_select;
          Alcotest.test_case "join .a * .b" `Quick test_parse_join_star;
          Alcotest.test_case "& binds tighter than *" `Quick
            test_parse_filter_binds_before_meet;
        ] );
      ( "spec_corpus",
        [
          Alcotest.test_case "all 10 spec examples parse" `Quick
            test_parse_spec_corpus;
        ] );
    ]
