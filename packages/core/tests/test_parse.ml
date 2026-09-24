open Beloch

let[@warning "-32"] expect_error msg_substr thunk =
  try
    ignore (thunk ());
    Alcotest.fail ("expected error containing: " ^ msg_substr)
  with Error.Beloch_error (_, m, _) ->
    Alcotest.(check bool)
      ("error mentions " ^ msg_substr)
      true
      (try
         ignore (Str.search_forward (Str.regexp_string msg_substr) m 0);
         true
       with Not_found -> false)

(* an error whose message contains [msg_substr] and whose hint is [hint] *)
let expect_error_hint msg_substr hint thunk =
  try
    ignore (thunk ());
    Alcotest.fail ("expected error containing: " ^ msg_substr)
  with Error.Beloch_error (_, m, h) ->
    Alcotest.(check bool)
      ("error mentions " ^ msg_substr)
      true
      (try
         ignore (Str.search_forward (Str.regexp_string msg_substr) m 0);
         true
       with Not_found -> false);
    Alcotest.(check (option string)) "hint" (Some hint) h

(* ---- Span-free renderings of the tree ----

   Items stand in any order, so two spellings of one statement differ in
   their spans and compare unequal structurally. Each rendering below prints
   the part of the tree a test asserts on, with spans dropped, so a
   permutation test is a string equality and a construction test reads as
   the alignment list itself. *)

let rec pstr (p : Ast.point_operand) : string =
  match p with
  | Ast.PNamed r -> "." ^ r.Ast.name
  | Ast.PSelect (ls, _) -> "(" ^ String.concat " * " (List.map lstr ls) ^ ")"

and lstr (l : Ast.line_operand) : string =
  match l with
  | Ast.LNamed r -> "--" ^ r.Ast.cname
  | Ast.LFilter (b, Ast.Keep s, _) -> lstr b ^ " & " ^ selstr s
  | Ast.LFilter (b, Ast.Drop s, _) -> lstr b ^ " \\ " ^ selstr s
  | Ast.LUnion (ls, _) -> "[" ^ String.concat " " (List.map lstr ls) ^ "]"
  | Ast.LSelect (ss, _) -> "--[" ^ String.concat " " (List.map selstr ss) ^ "]"

and selstr (s : Ast.selector) : string =
  match s with
  | Ast.SelPoint p -> pstr p
  | Ast.SelLine l -> lstr l
  | Ast.SelFlap f -> fostr f

and fostr (Ast.FByPoints (ps, _) : Ast.flap_operand) : string =
  "#[" ^ String.concat " " (List.map pstr ps) ^ "]"

let fastr (f : Ast.flap_arg) : string =
  match f with
  | Ast.FlapPoint p -> pstr p
  | Ast.FlapLine l -> lstr l
  | Ast.FlapSpec f -> fostr f

let ostr (o : Ast.align_object) : string =
  match o with Ast.AoPoint p -> pstr p | Ast.AoLine l -> lstr l

(* one alignment, with the fold-line prefixes it carries *)
let alstr (a : Ast.alignment) : string =
  let pre = function None -> "" | Some n -> "--" ^ n ^ " " in
  pre a.Ast.al_fold_line
  ^
  match a.Ast.al_kind with
  | Ast.AlOnto (x, y) -> ostr x ^ " onto " ^ pre a.Ast.al_fold_line2 ^ ostr y
  | Ast.AlThrough p -> "through " ^ pstr p
  | Ast.AlPerp l -> "perp " ^ lstr l

(* the alignment list in source order *)
let alignments (c : Ast.construction) : string list =
  List.map alstr c.Ast.c_alignments

(* the alignment multiset: what recognition reads, order dropped *)
let alignment_set (c : Ast.construction) : string list =
  List.sort compare (alignments c)

let cstr (c : Ast.construction) : string =
  (match c.Ast.c_fold_lines with
  | [] -> ""
  | ns -> String.concat " " (List.map (fun n -> "--" ^ n) ns) ^ " ")
  ^ String.concat "; " (alignments c)
  ^ match c.Ast.c_toward with None -> "" | Some p -> " toward " ^ pstr p

let mstr (m : Ast.markable) : string =
  match m with
  | Ast.MConstruction c -> "construction{" ^ cstr c ^ "}"
  | Ast.MLine l -> "line{" ^ lstr l ^ "}"

let outstr (o : Ast.output) : string =
  match o with
  | Ast.Anonymous -> "anon"
  | Ast.Named (n, false, _) -> "as --" ^ n
  | Ast.Named (n, true, _) -> "as --" ^ n ^ "!"
  | Ast.Into (n, _) -> "into --" ^ n

let optstr f = function None -> "-" | Some v -> f v

let mvstr (d : Ast.mv_constraint) : string =
  match d with
  | Ast.MvFree -> "free"
  | Ast.MvMountain -> "mountain"
  | Ast.MvValley -> "valley"

(* every part of a statement a permutation test compares, spans dropped *)
let stmt_shape (s : Ast.stmt) : string =
  match s with
  | Ast.BindLine (n, c, _) -> Printf.sprintf "bind --%s = (%s)" n (cstr c)
  | Ast.BindBundle (n, l, _) -> Printf.sprintf "bundle --%s = %s" n (lstr l)
  | Ast.Mark (out, m, ext, dir, layer, _) ->
      Printf.sprintf "mark %s %s extent=%s intent=%s on=%s" (outstr out)
        (mstr m)
        (match ext with
        | Ast.Full -> "full"
        | Ast.Between (a, b) -> "between " ^ pstr a ^ " " ^ pstr b
        | Ast.At p -> "at " ^ pstr p)
        (match dir with Ast.Mountain -> "mountain" | Ast.Valley -> "valley")
        (optstr fastr layer)
  | Ast.Fold (out, m, fs, _) ->
      Printf.sprintf "fold %s %s moving=%s upto=%s dir=%s place=%s"
        (outstr out) (mstr m)
        (optstr fastr fs.Ast.moving)
        (optstr fastr fs.Ast.up_to)
        (match fs.Ast.direction with
        | Ast.Mountain -> "mountain"
        | Ast.Valley -> "valley")
        (optstr
           (fun (d, f) ->
             (match d with Ast.PlaceOver -> "over " | Ast.PlaceUnder -> "under ")
             ^ fastr f)
           fs.Ast.place)
  | Ast.Reverse (out, m, rs, _) ->
      Printf.sprintf "reverse %s %s moving=%s outside=%b" (outstr out) (mstr m)
        (optstr fastr rs.Ast.rmoving)
        rs.Ast.outside
  | Ast.Flatten (out, elems, overs, staying, toward, _) ->
      Printf.sprintf "flatten %s rays=[%s] overs=[%s] staying=%s toward=%s"
        (outstr out)
        (String.concat " "
           (List.map
              (fun (e : Ast.collapse_elem) ->
                lstr e.Ast.cline ^ ":" ^ mvstr e.Ast.cdir)
              elems))
        (String.concat " "
           (List.map (fun (u, l) -> fastr u ^ ">" ^ fastr l) overs))
        (optstr fastr staying) (optstr pstr toward)
  | Ast.Flip _ -> "flip"
  | Ast.Point (n, _, _) -> "point ." ^ n
  | Ast.Def (n, _, _, _) -> "def " ^ n
  | Ast.Apply (_, n, _, _) -> "apply " ^ n
  | Ast.Export (_, i, _) -> "export $" ^ i

let parse1 (src : string) : Ast.stmt =
  match Beloch.parse ~filename:"t.bel" ("paper square\n" ^ src ^ "\n") with
  | [ s ] -> s
  | _ -> Alcotest.fail ("expected exactly one statement: " ^ src)

let shape1 (src : string) : string = stmt_shape (parse1 src)

(* the construction of a one-statement program whose verb carries a motion *)
let construction1 (src : string) : Ast.construction =
  match parse1 src with
  | Ast.Mark (_, Ast.MConstruction c, _, _, _, _)
  | Ast.Fold (_, Ast.MConstruction c, _, _)
  | Ast.Reverse (_, Ast.MConstruction c, _, _)
  | Ast.BindLine (_, c, _) ->
      c
  | _ -> Alcotest.fail ("expected a construction in: " ^ src)

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
       --d1 = (through .a .c)\n\
       mark (map .b onto .d)\n\
       .center = --d1 * --d2\n"
  in
  Alcotest.(check int) "three statements" 3 (List.length prog);
  match prog with
  | [
   Ast.BindLine ("d1", _, _);
   Ast.Mark (Ast.Anonymous, Ast.MConstruction _, Ast.Full, Ast.Valley, None, _);
   Ast.Point ("center", Ast.PsExpr (Ast.PSelect _), _);
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape"

let test_parse_syntax_error () =
  try
    ignore (Beloch.parse ~filename:"t.bel" "paper square\nmark (map .a)\n");
    Alcotest.fail "expected a syntax error"
  with Error.Beloch_error (_, _, _) -> ()

let test_parse_perp () =
  Alcotest.(check (list string))
    "perp alignments" [ "perp --d"; "through .b" ]
    (alignments (construction1 "mark (perp --d through .b)"))

(* A parenthesised operand is that operand, so a grouping the reader adds
   for clarity parses as the ungrouped form does. The meet already required
   the parentheses in operand position; these give the other operands the
   same freedom. *)
let test_parse_grouped_operand () =
  Alcotest.(check (list string))
    "grouping a filtered line leaves the alignments alone" [ "perp --d & .a"; "through .b" ]
    (alignments (construction1 "mark (perp (--d & .a) through .b)"));
  Alcotest.(check (list string))
    "a doubly grouped crease is that crease" [ "through .a"; "through .b" ]
    (alignments (construction1 "mark (align (through ((.a))) (through .b))"))

let test_parse_map_onto_line () =
  Alcotest.(check (list string))
    "map onto line, perp" [ ".c onto --l1"; "perp --l2" ]
    (alignments (construction1 "mark (map .c onto --l1 perp --l2)"))

let test_parse_bisect () =
  Alcotest.(check string)
    "line onto line with toward" "--v onto --h toward .a"
    (cstr (construction1 "mark (map --v onto --h toward .a)"))

let test_parse_map_through () =
  Alcotest.(check string)
    "map through" ".c onto --d; through .a"
    (cstr (construction1 "mark (map .c onto --d through .a)"))

let test_parse_map_through_toward () =
  Alcotest.(check string)
    "map through toward" ".c onto --d; through .a toward .b"
    (cstr (construction1 "mark (map .c onto --d through .a toward .b)"))

let test_parse_map_both () =
  Alcotest.(check string)
    "map both" ".a onto --d; .c onto --e"
    (cstr (construction1 "mark (map .a onto --d and .c onto --e)"))

let test_parse_map_both_toward () =
  Alcotest.(check string)
    "map both toward" ".a onto --d; .c onto --e toward .b"
    (cstr (construction1 "mark (map .a onto --d and .c onto --e toward .b)"))

let test_parse_fold_action () =
  Alcotest.(check string)
    "fold with anchor and mountain"
    "fold anon construction{.a onto .c} moving=.a upto=- dir=mountain place=-"
    (shape1 "fold (map .a onto .c) (moving .a) (mountain)")

let test_parse_fold_valley_default () =
  Alcotest.(check string)
    "no items beyond the axis"
    "fold anon construction{.a onto .c} moving=- upto=- dir=valley place=-"
    (shape1 "fold (map .a onto .c)")

let test_parse_precrease_no_foldspec () =
  Alcotest.(check string)
    "a mark carries no fold spec"
    "mark anon construction{.a onto .c} extent=full intent=valley on=-"
    (shape1 "mark (map .a onto .c)")

let test_parse_flip () =
  match Beloch.parse ~filename:"t.bel" "paper square\nflip\n" with
  | [ Ast.Flip _ ] -> ()
  | _ -> Alcotest.fail "expected a single Flip statement"

let test_parse_eq_binding () =
  let prog =
    Beloch.parse ~filename:"t.bel" "paper square\n--d1 = (through .a .c)\n"
  in
  Alcotest.(check int) "one statement" 1 (List.length prog)

let test_parse_shorthand_rhs () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       --d = (through .a .c)\n\
       .m = --d * --ab\n\
       --e = (through .a .c)\n"
  in
  Alcotest.(check int) "three statements" 3 (List.length prog);
  match prog with
  | [
      Ast.BindLine ("d", _, _);
      Ast.Point ("m", Ast.PsExpr (Ast.PSelect _), _);
      Ast.BindLine ("e", _, _);
    ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape"

(* ---- Def ---- *)

let test_parse_def () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       def petal(.p .q --base) {\n\
      \  fold (map .p onto .q) (moving .p)\n\
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
      "paper square\ndef thirds() {\n  --pq = (through .x .y)\n}\n"
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
        "paper square\n--foo-bar = (through .a .b)\n")

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
  Alcotest.(check (list string))
    "filtered line in a perp" [ "perp --b & .a"; "through .c" ]
    (alignments (construction1 "mark (perp --b & .a through .c)"))

let test_parse_at_two_selectors () =
  Alcotest.(check (list string))
    "chained filter" [ "perp --b & .a & --b"; "through .c" ]
    (alignments (construction1 "mark (perp --b & .a & --b through .c)"))

let test_parse_meet_stmt () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       --d1 = (through .a .b)\n\
       --d2 = (through .c .d)\n\
       .o = --d1 * --d2\n"
  in
  match List.rev prog with
  | Ast.Point ("o", Ast.PsExpr (Ast.PSelect ([ Ast.LNamed a; Ast.LNamed b ], _)), _)
    :: _ ->
      Alcotest.(check string) "lhs" "d1" a.Ast.cname;
      Alcotest.(check string) "rhs" "d2" b.Ast.cname
  | _ -> Alcotest.fail "expected .o = Cross(d1, d2)"

let test_parse_meet_inline () =
  Alcotest.(check (list string))
    "meet as a construction operand" [ "(--d1 * --d2) onto .e" ]
    (alignments (construction1 "mark (map (--d1 * --d2) onto .e)"))

(* ---- Spec corpus ---- *)

let spec_corpus =
  [
    ( "01_eq_binding",
      "paper square\n--rs = (through .rs1 .rs2)\n.s   = --rs * --cd\n" );
    ( "02_shorthand_rhs",
      "paper square\n.s  = --rs * --cd\n--e = (through .p1 .p2)\n" );
    ( "03_def_petal",
      "paper square\ndef petal(.p .q --base) {\n\
      \  fold (map .p onto .q) (moving .p)\n\
      \  .tip = .p * .q * --base\n\
       }\n" );
    ( "04_apply",
      "paper square\n$p1 = apply petal(.k1 .k2 .k1 * .k3)\n\
       apply petal(.k2 .k4 .k2 * .k1)\n" );
    ( "05_qualified",
      "paper square\n\
       export { .tip as .p1tip --pq as --p1pq } $p1\n\
       export { .tip as .p2tip --pq as --p2pq } $p2\n\
       fold (map .p1tip onto .p2tip)\n\
       --d = (through .p1tip .p2tip)\n\
       .x  = --p1pq * --p2pq\n" );
    ( "06_export",
      "paper square\nexport { .tip --pq } $t\n\
       export { .tip as .left_tip } $t\nexport { .s! } $t\nexport $t\n" );
    ( "07_panels",
      "paper square\n._mb = --vm * --ab\n\
       --pq = (through ._pq1 ._pq2)\n\
       fold (map .c onto --ab and .s onto --pq)\n" );
    ( "08_cube_root",
      "paper square\n\n--vm = (map .a onto .b)\n\n\
       ._mb  = --vm * --ab\n._mt  = --vm * --cd\n\
       --ac = (through .a .c)\n--db = (through .d .b)\n\
       --d_mb = (through .d ._mb)\n--a_mt = (through .a ._mt)\n\
       --c_mb = (through .c ._mb)\n--b_mt = (through .b ._mt)\n\
       ._pq1 = --d_mb * --ac\n\
       ._pq2 = --a_mt * --db\n--pq  = (through ._pq1 ._pq2)\n\
       ._rs1 = --c_mb * --db\n\
       ._rs2 = --b_mt * --ac\n--rs  = (through ._rs1 ._rs2)\n\
       .s    = --rs * --cd\n\n\
       fold (map .c onto --ab and .s onto --pq)\n" );
    ( "09_petal_full",
      "paper square\n\ndef petal(.p .q --base) {\n\
      \  fold (map .p onto .q) (moving .p)\n\
      \  .tip = .p * .q * --base\n\
       }\n\n$left  = apply petal(.a .c .b * .d)\n\
       $right = apply petal(.b .d .a * .c)\n\n\
       export { .tip as .lefttip } $left\n\
       export { .tip as .righttip } $right\n\
       fold (map .lefttip onto .righttip)\n" );
    ( "10_zero_params",
      "paper square\ndef thirds() {\n\
      \  ._mb = --vm * --ab\n\
      \  --pq = (through ._mb .x)\n\
       }\n$t = apply thirds()\nexport $t\n" );
  ]

(* the write statements of BELOCH.md ("Write statements", "Constructions")
   and of the design's Examples, each a program of its own *)
let reference_writes =
  [
    "fold    (map .a onto .c) (moving .a)";
    "fold    (map .a onto .c) (moving .a) (mountain)";
    "fold    (through .m .n) (moving .b) (under .p)";
    "fold    (map .c onto .b) (up to .d)";
    "fold    (--d) (moving .b) (up to .c)";
    "fold    (--d) (moving .b) (up to .c) into --d";
    "fold    (map .a onto .c) (moving .a) as --f";
    "reverse (map .b onto .c)";
    "reverse (map .b onto .c) (outside)";
    "mark    (through .a .c)";
    "mark    (map --ab onto --cd) (on #[.c]) (between .a .m) (mountain)";
    "mark    (map .a onto .c) (between .a .m) as --p";
    "mark    (--p) into --p";
    "flatten (--h & --bc) (--v & --cd) (.q over .r) (staying .a) (toward .q)";
    "flatten (--ea) (--ec) (--eb) (toward .a) as --ear";
    "flatten (--ba \\ .a) (--bc \\ .c) as --r";
    "flip";
    "--l = (map --a onto --b toward .p)";
    "--x = [--ea --eb] & .a";
    "fold (align (.a onto .c)) (moving .a)";
    "fold (align (through .m) (through .n)) (moving .b) (under .p)";
    "mark (align (--ab onto --cd)) (on #[.c]) (between .a .m) (mountain)";
    "mark (align (through .a) (through .b))";
    "mark (align (perp --l) (through .p))";
    "mark (align (.p onto --l) (through .q))";
    "mark (align (.p onto --l) (perp --m))";
    "mark (align (--l onto --m) toward .p)";
    "mark (align (.p onto --l) (.q onto --m))";
    "mark (align --a --b (--a .p onto --l) (--b .q onto --m) (--a .r onto --b .s))";
  ]

let test_parse_reference_writes () =
  List.iter
    (fun src ->
      try ignore (parse1 src)
      with Error.Beloch_error (_, m, _) ->
        Alcotest.fail (Printf.sprintf "%s failed to parse: %s" src m))
    reference_writes

let test_parse_spec_corpus () =
  List.iter
    (fun (name, src) ->
      try ignore (Beloch.parse ~filename:(name ^ ".bel") src)
      with Error.Beloch_error (_, m, _) ->
        Alcotest.fail (Printf.sprintf "%s failed to parse: %s" name m))
    spec_corpus

(* ---- Flap operands and bundle reads ---- *)

let test_parse_up_to () =
  Alcotest.(check string)
    "up to as its own item"
    "fold anon construction{.c onto .d} moving=- upto=.c dir=valley place=-"
    (shape1 "fold (map .c onto .d) (up to .c)")

let test_parse_flap_forms () =
  Alcotest.(check string)
    "flap spec, crease and mountain"
    "fold anon construction{perp --d; through .p} moving=#[.a .b] upto=--d \
     dir=mountain place=-"
    (shape1 "fold (perp --d through .p) (moving #[.a .b]) (up to --d) (mountain)")

let test_parse_flap_bracket () =
  match parse1 "fold (perp --d through .p) (moving #[.a .b])" with
  | Ast.Fold (_, _, { moving = Some (Ast.FlapSpec (Ast.FByPoints (pts, _))); _ }, _)
    ->
      Alcotest.(check int) "two constraint points" 2 (List.length pts)
  | _ -> Alcotest.fail "expected moving #[.a .b]"

let test_parse_filter_chain () =
  match parse1 "fold (map .p onto .q) (up to --l & .c & --m)" with
  | Ast.Fold
      ( _, _,
        { up_to =
            Some
              (Ast.FlapLine
                 (Ast.LFilter
                    ( Ast.LFilter (Ast.LNamed _, Ast.Keep (Ast.SelPoint _), _),
                      Ast.Keep (Ast.SelLine _), _ )));
          _ },
        _ ) ->
      ()
  | _ -> Alcotest.fail "expected up to --l & .c & --m (nested LFilter, Keep)"

let test_parse_diff () =
  match parse1 "fold (map .p onto .q) (up to --l \\ .c)" with
  | Ast.Fold
      (_, _, { up_to = Some (Ast.FlapLine (Ast.LFilter (Ast.LNamed _, Ast.Drop _, _))); _ }, _)
    ->
      ()
  | _ -> Alcotest.fail "expected up to --l \\ .c (LFilter Drop)"

let test_parse_union () =
  match parse1 "fold (map .p onto .q) (up to [--x --y])" with
  | Ast.Fold
      ( _, _,
        { up_to = Some (Ast.FlapLine (Ast.LUnion ([ Ast.LNamed _; Ast.LNamed _ ], _)));
          _ },
        _ ) ->
      ()
  | _ -> Alcotest.fail "expected up to [--x --y] (LUnion of 2)"

let test_parse_bind_bundle () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l = (through .a .b)\n--seg = --l & .c\n"
  in
  match List.rev prog with
  | Ast.BindBundle ("seg", Ast.LFilter (Ast.LNamed _, Ast.Keep _, _), _) :: _ ->
      ()
  | _ -> Alcotest.fail "expected --seg = --l & .c (BindBundle LFilter)"

let test_parse_fold_along () =
  Alcotest.(check string)
    "an existing crease as the axis"
    "fold anon line{--m} moving=.c upto=- dir=valley place=-"
    (shape1 "fold (--m) (moving .c)")

let test_parse_line_select () =
  match parse1 "fold (map .d onto .a) (up to --[.a .b])" with
  | Ast.Fold
      ( _, _,
        { up_to =
            Some (Ast.FlapLine (Ast.LSelect ([ Ast.SelPoint _; Ast.SelPoint _ ], _)));
          _ },
        _ ) ->
      ()
  | _ -> Alcotest.fail "expected up to --[.a .b] (LSelect of 2 points)"

let test_parse_point_select () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--x = (through .a .b)\n--y = (through .c .d)\n.o = .[--x --y]\n"
  in
  match List.rev prog with
  | Ast.Point ("o", Ast.PsExpr (Ast.PSelect ([ Ast.LNamed _; Ast.LNamed _ ], _)), _)
    :: _ ->
      ()
  | _ -> Alcotest.fail "expected .o = .[--x --y] (PSelect of 2 lines)"

let test_parse_join_star () =
  match parse1 "fold (map .d onto .a) (up to .a * .b)" with
  | Ast.Fold
      ( _, _,
        { up_to =
            Some (Ast.FlapLine (Ast.LSelect ([ Ast.SelPoint _; Ast.SelPoint _ ], _)));
          _ },
        _ ) ->
      ()
  | _ -> Alcotest.fail "expected up to .a * .b (LSelect join of 2 points)"

(* & binds tighter than * : --l & .a * --s parses as (--l & .a) * --s, so the
   filtered crease resolves to one line before meet consumes it *)
let test_parse_filter_binds_before_meet () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       --l = (through .a .c)\n\
       --s = (through .b .d)\n\
       .o = --l & .a * --s\n"
  in
  match List.rev prog with
  | Ast.Point ("o", Ast.PsExpr (Ast.PSelect ([ Ast.LFilter _; Ast.LNamed _ ], _)), _)
    :: _ ->
      ()
  | _ -> Alcotest.fail "expected (--l & .a) * --s : PSelect[LFilter, LNamed]"

(* ---- Flatten ---- *)

let test_parse_flatten_basic () =
  Alcotest.(check string)
    "four rays, the last pinned"
    "flatten anon rays=[--a:free --b:free --c:free --e:mountain] overs=[] \
     staying=- toward=-"
    (shape1 "flatten (--a) (--b) (--c) (--e mountain)")

let test_parse_flatten_over_staying () =
  Alcotest.(check string)
    "filtered rays, an order and a stayer"
    "flatten anon rays=[--a & .a:free --e & .o & --ab:mountain] overs=[.b>.d] \
     staying=.m toward=-"
    (shape1
       "flatten (--a & .a) (--e & .o & --ab mountain) (.b over .d) (staying .m)")

let test_parse_flatten_followed_by_stmt () =
  (* regression: a flatten must not swallow the next statement's leading
     .point/--crease as a phantom over item *)
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nflatten (--a) (--b mountain)\n.x = --a * --b\n"
  in
  match prog with
  | [ Ast.Flatten (Ast.Anonymous, [ _; _ ], [], None, None, _); Ast.Point ("x", _, _) ]
    ->
      ()
  | _ -> Alcotest.fail "expected Flatten then Point"

let test_parse_flatten_toward_item () =
  Alcotest.(check string)
    "toward is an item like the others"
    "flatten anon rays=[--a & .p:free --b & .q:valley --c & .r:mountain] \
     overs=[] staying=- toward=.s"
    (shape1 "flatten (--a & .p) (--b & .q valley) (--c & .r mountain) (toward .s)")

let test_parse_flatten_double_staying_rejected () =
  let src = "paper square\nflatten (--a) (staying .p) (staying .q)\n" in
  expect_error "only one staying item per flatten" (fun () ->
      Beloch.parse ~filename:"t.bel" src);
  (* the error must point at the duplicate (second, source-order) `staying`,
     not the first *)
  let first_staying = Str.search_forward (Str.regexp_string "staying") src 0 in
  let second_staying =
    Str.search_forward (Str.regexp_string "staying") src (first_staying + 1)
  in
  match Beloch.parse ~filename:"t.bel" src with
  | _ -> Alcotest.fail "expected duplicate-staying error"
  | exception Error.Beloch_error ((start, _), _, _) ->
      Alcotest.(check int)
        "span points at the second `staying`, not the first"
        second_staying start.Lexing.pos_cnum

let test_parse_flatten_double_toward_rejected () =
  expect_error "only one toward item per flatten" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nflatten (--a) (toward .p) (toward .q)\n")

let test_parse_flatten_brace_item_retired () =
  (* braces are blocks, never items: `{toward .s}` is gone with the rest of
     the brace items *)
  expect_error "syntax error" (fun () ->
      Beloch.parse ~filename:"t.bel" "paper square\nflatten (--a) {toward .c}\n")

let test_parse_flatten_trailing_toward_rejected () =
  expect_error "syntax error" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nflatten (--a) (--b) toward .c\n")

(* ---- Items stand in any order (Acceptance 2) ---- *)

let permutations (xs : string list) : string list list =
  let rec perms = function
    | [] -> [ [] ]
    | l ->
        List.concat_map
          (fun x -> List.map (fun p -> x :: p) (perms (List.filter (( <> ) x) l)))
          l
  in
  perms xs

let check_permutations (what : string) (verb : string) (items : string list) =
  let shapes =
    List.map
      (fun order -> shape1 (verb ^ " " ^ String.concat " " order))
      (permutations items)
  in
  let expected = List.hd shapes in
  Alcotest.(check int)
    (what ^ ": every order tried")
    (List.length shapes)
    (List.length (permutations items));
  List.iteri
    (fun i s ->
      Alcotest.(check string)
        (Printf.sprintf "%s: permutation %d parses the same" what i)
        expected s)
    shapes

let test_items_any_order_fold () =
  check_permutations "fold" "fold"
    [ "(map .a onto .c)"; "(moving .a)"; "(mountain)" ]

let test_items_any_order_mark () =
  check_permutations "mark" "mark"
    [ "(map --ab onto --cd)"; "(on #[.c])"; "(between .a .m)"; "(mountain)" ]

let test_items_any_order_reverse () =
  check_permutations "reverse" "reverse"
    [ "(map .b onto .c)"; "(moving .b)"; "(outside)" ]

let test_items_any_order_flatten () =
  (* the ray items keep source order; everything else moves freely *)
  let rays = "(--h & --bc) (--v & --cd)" in
  let others = [ "(.q over .r)"; "(staying .a)"; "(toward .q)" ] in
  List.iter
    (fun order ->
      Alcotest.(check string)
        "flatten items in any order, rays in source order"
        (shape1 ("flatten " ^ rays ^ " " ^ String.concat " " others))
        (shape1 ("flatten " ^ rays ^ " " ^ String.concat " " order)))
    (permutations others);
  (* and the ray order itself is semantic: swapping two rays is a different
     statement *)
  Alcotest.(check bool)
    "swapping two rays changes the statement" false
    (shape1 "flatten (--h) (--v) (staying .a)"
    = shape1 "flatten (--v) (--h) (staying .a)")

(* ---- Constructions: prose and align ---- *)

(* axiom, prose spelling, align spelling, the alignment list the prose form
   fixes. The two spellings agree as multisets, which is what recognition
   reads (ADR 0022). *)
let construction_pairs =
  [
    ( "axiom 1",
      "mark (through .a .b)",
      "mark (align (through .a) (through .b))",
      [ "through .a"; "through .b" ] );
    ( "axiom 2",
      "mark (map .a onto .c)",
      "mark (align (.a onto .c))",
      [ ".a onto .c" ] );
    ( "axiom 3",
      "mark (perp --l through .p)",
      "mark (align (perp --l) (through .p))",
      [ "perp --l"; "through .p" ] );
    ( "axiom 4",
      "mark (map .p onto --l perp --m)",
      "mark (align (.p onto --l) (perp --m))",
      [ ".p onto --l"; "perp --m" ] );
    ( "axiom 5",
      "mark (map --l onto --m toward .p)",
      "mark (align (--l onto --m) toward .p)",
      [ "--l onto --m" ] );
    ( "axiom 6",
      "mark (map .p onto --l through .q)",
      "mark (align (.p onto --l) (through .q))",
      [ ".p onto --l"; "through .q" ] );
    ( "axiom 7",
      "mark (map .p onto --l and .q onto --m)",
      "mark (align (.p onto --l) (.q onto --m))",
      [ ".p onto --l"; ".q onto --m" ] );
  ]

let test_prose_alignments () =
  List.iter
    (fun (name, prose, _, expected) ->
      Alcotest.(check (list string))
        (name ^ ": prose alignments")
        expected
        (alignments (construction1 prose)))
    construction_pairs

let test_align_alignments () =
  List.iter
    (fun (name, _, align, expected) ->
      Alcotest.(check (list string))
        (name ^ ": align alignments")
        expected
        (alignments (construction1 align)))
    construction_pairs

let test_prose_and_align_agree_as_sets () =
  List.iter
    (fun (name, prose, align, _) ->
      Alcotest.(check (list string))
        (name ^ ": same alignment multiset")
        (alignment_set (construction1 prose))
        (alignment_set (construction1 align)))
    construction_pairs

let test_align_alignment_order_is_free () =
  (* the two orders are one multiset; source order fixes operand order only
     where a kind repeats *)
  Alcotest.(check (list string))
    "axiom 6 written the other way round"
    (alignment_set (construction1 "mark (align (.p onto --l) (through .q))"))
    (alignment_set (construction1 "mark (align (through .q) (.p onto --l))"))

let test_align_toward_is_kept () =
  Alcotest.(check string)
    "toward belongs to the construction" "--l onto --m toward .p"
    (cstr (construction1 "mark (align (--l onto --m) toward .p)"))

let test_align_named_fold_lines_kept () =
  (* AL6ab8, the two-fold construction of BELOCH.md: the names in the head
     and the fold line in front of each folded object are parsed and kept *)
  let c =
    construction1
      "mark (align --a --b (--a .p onto --l) (--b .q onto --m) (--a .r onto --b .s))"
  in
  Alcotest.(check (list string)) "fold-line names" [ "a"; "b" ] c.Ast.c_fold_lines;
  Alcotest.(check (list string))
    "alignments keep their prefixes"
    [ "--a .p onto --l"; "--b .q onto --m"; "--a .r onto --b .s" ]
    (alignments c)

let test_bind_line_takes_a_construction () =
  Alcotest.(check string)
    "a line binding is a construction in parentheses"
    "bind --l = (.a onto .c)"
    (shape1 "--l = (map .a onto .c)")

let test_bind_line_align () =
  Alcotest.(check string)
    "a line binding in canonical form" "bind --l = (--a onto --b toward .p)"
    (shape1 "--l = (align (--a onto --b) toward .p)")

(* ---- The output clause ---- *)

let test_output_clause_forms () =
  Alcotest.(check string)
    "as a new name"
    "fold as --f construction{.a onto .c} moving=.a upto=- dir=valley place=-"
    (shape1 "fold (map .a onto .c) (moving .a) as --f");
  Alcotest.(check string)
    "as with the rebind bang"
    "fold as --f! construction{.a onto .c} moving=.a upto=- dir=valley place=-"
    (shape1 "fold (map .a onto .c) (moving .a) as --f!");
  Alcotest.(check string)
    "into an existing crease"
    "mark into --p line{--p} extent=full intent=valley on=-"
    (shape1 "mark (--p) into --p");
  Alcotest.(check string)
    "no clause leaves the crease anonymous"
    "reverse anon construction{.b onto .c} moving=- outside=true"
    (shape1 "reverse (map .b onto .c) (outside)");
  Alcotest.(check string)
    "flatten scores under a name"
    "flatten as --ear rays=[--ea:free --ec:free --eb:free] overs=[] staying=- \
     toward=.a"
    (shape1 "flatten (--ea) (--ec) (--eb) (toward .a) as --ear")

let test_mark_items () =
  Alcotest.(check string)
    "every mark item at once"
    "mark as --p construction{--ab onto --cd} extent=between .a .m intent=mountain \
     on=#[.c]"
    (shape1 "mark (map --ab onto --cd) (on #[.c]) (between .a .m) (mountain) as --p");
  Alcotest.(check string)
    "the layer slot takes a bare point"
    "mark anon line{--l} extent=at .m intent=valley on=.c"
    (shape1 "mark (--l) (at .m) (on .c)")

let test_fold_placed () =
  Alcotest.(check string)
    "a placed fold"
    "fold anon construction{through .m; through .n} moving=.b upto=- dir=valley \
     place=under .p"
    (shape1 "fold (through .m .n) (moving .b) (under .p)")

(* ---- Item classification errors ---- *)

let test_err_head_the_verb_does_not_take () =
  expect_error "fold takes no (outside) item" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nfold (map .a onto .c) (outside)\n")

let test_err_items_on_flip () =
  expect_error "flip takes no items" (fun () ->
      Beloch.parse ~filename:"t.bel" "paper square\nflip (moving .a)\n")

let test_err_second_item_of_one_type () =
  expect_error "only one moving item per fold" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nfold (map .a onto .c) (moving .a) (moving .b)\n")

let test_err_second_extent () =
  expect_error "only one extent item per mark" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nmark (--l) (between .a .b) (at .m)\n")

let test_err_second_selection () =
  expect_error "only one toward item per flatten" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nflatten (--a) (--b) (toward .p) (toward .q)\n")

let test_err_second_staying () =
  expect_error "only one staying item per flatten" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nflatten (--a) (staying .p) (staying .q)\n")

let test_err_no_axis_item () =
  expect_error "fold needs an axis item: a construction or a crease" (fun () ->
      Beloch.parse ~filename:"t.bel" "paper square\nfold (moving .a)\n")

let test_err_no_ray_item () =
  expect_error "flatten needs at least one ray item" (fun () ->
      Beloch.parse ~filename:"t.bel" "paper square\nflatten (staying .a)\n")

let test_err_letter_on_an_axis_item () =
  expect_error_hint "an axis item takes no mountain or valley"
    "write (mountain) as its own item" (fun () ->
      Beloch.parse ~filename:"t.bel" "paper square\nfold (--d mountain) (moving .a)\n")

let test_err_placed_fold_rejects_mountain () =
  expect_error_hint "a placed fold derives its direction" "drop mountain"
    (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nfold (through .m .n) (moving .b) (over .p) (mountain)\n");
  (* and in the other order, since items carry no position *)
  expect_error_hint "a placed fold derives its direction" "drop mountain"
    (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nfold (through .m .n) (mountain) (over .p)\n")

let test_err_placed_fold_rejects_up_to () =
  expect_error
    "a placed fold moves the anchor flap only; up to is not supported here"
    (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nfold (through .m .n) (moving .b) (up to .c) (under .p)\n")

let test_err_clause_on_flip () =
  expect_error "flip scores no crease, so it takes no as or into" (fun () ->
      Beloch.parse ~filename:"t.bel" "paper square\nflip as --f\n")

(* ---- Notation cutover: the bare-keyword argument forms are gone ---- *)

let test_bare_keyword_arguments_retired () =
  (* An unparenthesised argument is a syntax error; the `verb --name =` bind
     reaches the verb with an empty item list, so it is refused for the axis
     it never gave. *)
  List.iter
    (fun (src, msg) ->
      expect_error msg (fun () ->
          Beloch.parse ~filename:"t.bel" ("paper square\n" ^ src ^ "\n")))
    [
      ("fold map .a onto .c moving .a", "syntax error");
      ("mark map .a onto .c", "syntax error");
      ("flatten --a --b", "flatten needs at least one ray item");
      ("--r = flatten (--a) (--b)", "syntax error");
      ("mark --d = map .a onto .c", "mark needs an axis item");
      ("fold --d = map .a onto .c moving .a", "fold needs an axis item");
      ( "reverse --h = map .b onto .c moving .b outside",
        "reverse needs an axis item" );
    ]

let test_parse_at_retired () =
  (* `@` is no longer a token at all: it's an unrecognised character, so the
     lexer rejects it before the parser ever sees it. *)
  expect_error "unexpected character" (fun () ->
      Beloch.parse ~filename:"t.bel" "paper square\n@map .a onto .c moving .a\n");
  expect_error "unexpected character" (fun () ->
      Beloch.parse ~filename:"t.bel" "paper square\n@fold --d moving .a\n")

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
          Alcotest.test_case "grouped operand" `Quick test_parse_grouped_operand;
          Alcotest.test_case "bisect parses" `Quick test_parse_bisect;
          Alcotest.test_case "fold action parses" `Quick test_parse_fold_action;
          Alcotest.test_case "fold valley default" `Quick
            test_parse_fold_valley_default;
          Alcotest.test_case "placed fold" `Quick test_fold_placed;
          Alcotest.test_case "bare axiom has no fold_spec" `Quick
            test_parse_precrease_no_foldspec;
          Alcotest.test_case "flip parses" `Quick test_parse_flip;
          Alcotest.test_case "parse map onto line" `Quick
            test_parse_map_onto_line;
          Alcotest.test_case "parse map through" `Quick test_parse_map_through;
          Alcotest.test_case "parse map through toward" `Quick
            test_parse_map_through_toward;
          Alcotest.test_case "parse map both" `Quick test_parse_map_both;
          Alcotest.test_case "parse map both toward" `Quick
            test_parse_map_both_toward;
          Alcotest.test_case "eq binding separator" `Quick test_parse_eq_binding;
          Alcotest.test_case "shorthand RHS" `Quick test_parse_shorthand_rhs;
          Alcotest.test_case "parse def" `Quick test_parse_def;
          Alcotest.test_case "parse def zero params" `Quick
            test_parse_def_zero_params;
          Alcotest.test_case "parse def in def rejected" `Quick
            test_parse_def_in_def_rejected;
          Alcotest.test_case "parse kebab rejected" `Quick
            test_parse_kebab_rejected;
          Alcotest.test_case "at operator, one selector" `Quick
            test_parse_at_one_selector;
          Alcotest.test_case "at operator, two selectors" `Quick
            test_parse_at_two_selectors;
          Alcotest.test_case "meet operator, statement" `Quick
            test_parse_meet_stmt;
          Alcotest.test_case "meet operator, inline" `Quick
            test_parse_meet_inline;
          Alcotest.test_case "up to item" `Quick test_parse_up_to;
          Alcotest.test_case "flap operand forms" `Quick test_parse_flap_forms;
          Alcotest.test_case "flap bracket #[]" `Quick test_parse_flap_bracket;
          Alcotest.test_case "filter chain &" `Quick test_parse_filter_chain;
          Alcotest.test_case "diff \\" `Quick test_parse_diff;
          Alcotest.test_case "union []" `Quick test_parse_union;
          Alcotest.test_case "bind bundle" `Quick test_parse_bind_bundle;
          Alcotest.test_case "fold along an existing crease" `Quick
            test_parse_fold_along;
          Alcotest.test_case "line select --[.a .b]" `Quick
            test_parse_line_select;
          Alcotest.test_case "point select .[--x --y]" `Quick
            test_parse_point_select;
          Alcotest.test_case "join .a * .b" `Quick test_parse_join_star;
          Alcotest.test_case "& binds tighter than *" `Quick
            test_parse_filter_binds_before_meet;
          Alcotest.test_case "flatten basic" `Quick test_parse_flatten_basic;
          Alcotest.test_case "flatten over and staying" `Quick
            test_parse_flatten_over_staying;
          Alcotest.test_case "flatten followed by stmt" `Quick
            test_parse_flatten_followed_by_stmt;
          Alcotest.test_case "flatten toward item" `Quick
            test_parse_flatten_toward_item;
          Alcotest.test_case "flatten double staying rejected" `Quick
            test_parse_flatten_double_staying_rejected;
          Alcotest.test_case "flatten double toward rejected" `Quick
            test_parse_flatten_double_toward_rejected;
          Alcotest.test_case "flatten brace item retired" `Quick
            test_parse_flatten_brace_item_retired;
          Alcotest.test_case "flatten trailing toward rejected" `Quick
            test_parse_flatten_trailing_toward_rejected;
        ] );
      ( "items",
        [
          Alcotest.test_case "fold items in any order" `Quick
            test_items_any_order_fold;
          Alcotest.test_case "mark items in any order" `Quick
            test_items_any_order_mark;
          Alcotest.test_case "reverse items in any order" `Quick
            test_items_any_order_reverse;
          Alcotest.test_case "flatten items in any order, rays in order" `Quick
            test_items_any_order_flatten;
          Alcotest.test_case "every mark item" `Quick test_mark_items;
          Alcotest.test_case "output clause forms" `Quick
            test_output_clause_forms;
          Alcotest.test_case "bare keyword arguments retired" `Quick
            test_bare_keyword_arguments_retired;
          Alcotest.test_case "@ is retired" `Quick test_parse_at_retired;
        ] );
      ( "constructions",
        [
          Alcotest.test_case "prose alignments" `Quick test_prose_alignments;
          Alcotest.test_case "align alignments" `Quick test_align_alignments;
          Alcotest.test_case "prose and align agree as sets" `Quick
            test_prose_and_align_agree_as_sets;
          Alcotest.test_case "alignment order is free" `Quick
            test_align_alignment_order_is_free;
          Alcotest.test_case "toward is kept" `Quick test_align_toward_is_kept;
          Alcotest.test_case "named fold lines are kept" `Quick
            test_align_named_fold_lines_kept;
          Alcotest.test_case "a line binding takes a construction" `Quick
            test_bind_line_takes_a_construction;
          Alcotest.test_case "a line binding in canonical form" `Quick
            test_bind_line_align;
        ] );
      ( "item_errors",
        [
          Alcotest.test_case "head the verb does not take" `Quick
            test_err_head_the_verb_does_not_take;
          Alcotest.test_case "any item on flip" `Quick test_err_items_on_flip;
          Alcotest.test_case "a second item of one type" `Quick
            test_err_second_item_of_one_type;
          Alcotest.test_case "a second extent on mark" `Quick
            test_err_second_extent;
          Alcotest.test_case "a second selection item" `Quick
            test_err_second_selection;
          Alcotest.test_case "a second staying" `Quick test_err_second_staying;
          Alcotest.test_case "no axis item" `Quick test_err_no_axis_item;
          Alcotest.test_case "no ray item on flatten" `Quick
            test_err_no_ray_item;
          Alcotest.test_case "mountain on an axis item" `Quick
            test_err_letter_on_an_axis_item;
          Alcotest.test_case "placed fold rejects mountain" `Quick
            test_err_placed_fold_rejects_mountain;
          Alcotest.test_case "placed fold rejects up to" `Quick
            test_err_placed_fold_rejects_up_to;
          Alcotest.test_case "a clause on flip" `Quick test_err_clause_on_flip;
        ] );
      ( "export",
        [
          Alcotest.test_case "selective export" `Quick
            test_parse_export_selective;
          Alcotest.test_case "export all" `Quick test_parse_export_all;
          Alcotest.test_case "export kind mismatch rename" `Quick
            test_parse_export_kind_mismatch_rename;
        ] );
      ( "apply",
        [
          Alcotest.test_case "apply bound" `Quick test_parse_apply_bound;
          Alcotest.test_case "apply naked" `Quick test_parse_apply_naked;
        ] );
      ( "spec_corpus",
        [
          Alcotest.test_case "all 10 spec examples parse" `Quick
            test_parse_spec_corpus;
          Alcotest.test_case "the reference write statements parse" `Quick
            test_parse_reference_writes;
        ] );
    ]
