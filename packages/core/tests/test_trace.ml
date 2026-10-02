(* The trace of a construction's candidates (spec/FOLD.md, "The trace"):
   `beloch fold --trace` output, read as JSON the way a figure reads it. *)

open Yojson.Safe.Util

let fold_traced src =
  let json, failure = Beloch.fold_traced ~filename:"t.bel" src in
  (json, Option.is_some failure)

let triangle toward =
  "paper square\nmark (map .a onto .b) as --ef\nfold (map .d onto --ef through .a)"
  ^ toward ^ " as --s\n"

(* .d onto --ef through .q, where both landings of .d lie on --ef on the
   paper, mirrored in the line y = 2/5 that holds .q and .t *)
let kite items =
  "paper square\nmark (map .a onto .b) as --ef\n.q = free on --da from .a at 2/5\n\
   .t = free on --bc from .b at 2/5\nfold (map .d onto --ef through .q)"
  ^ items ^ " as --s\n"

let entries json = json |> member "beloch:trace" |> to_list
let candidates e = e |> member "candidates" |> to_list
let removed c = c |> member "removed_by" |> to_string_option
let selected c = c |> member "selected" |> to_bool
let count p l = List.length (List.filter p l)
let floats j = j |> to_list |> List.map to_number

let test_ambiguous_keeps_both () =
  let json, failed = fold_traced (kite "") in
  Alcotest.(check bool) "the program fails" true failed;
  let e = List.nth (entries json) 1 in
  Alcotest.(check string) "axiom" "axiom6" (e |> member "axiom" |> to_string);
  let cs = candidates e in
  Alcotest.(check int) "two candidates" 2 (List.length cs);
  Alcotest.(check int) "none removed" 2 (count (fun c -> removed c = None) cs);
  Alcotest.(check int) "none selected" 0 (count selected cs);
  Alcotest.(check (list (option string))) "a toward that keeps each alone"
    [ Some "(toward .a)"; Some "(toward .c)" ]
    (List.map (fun c -> c |> member "suggestion" |> to_string_option) cs);
  let err = json |> member "beloch:error" in
  Alcotest.(check bool) "error names the ambiguity" true
    (Str.string_match (Str.regexp ".*is ambiguous: 2 folds") (err |> member "message" |> to_string) 0);
  Alcotest.(check int) "error points at the failing statement" 3
    (err |> member "statement" |> to_int);
  let stmts = json |> member "beloch:statements" |> to_list in
  Alcotest.(check int) "the failing statement has its log entry" 4 (List.length stmts);
  Alcotest.(check int) "the error names that entry" 3 (e |> member "statement" |> to_int)

let test_toward_selects () =
  let json, failed = fold_traced (triangle " (toward .c)") in
  Alcotest.(check bool) "the program succeeds" false failed;
  let cs = candidates (List.nth (entries json) 1) in
  Alcotest.(check int) "one selected" 1 (count selected cs);
  Alcotest.(check int) "one removed by toward" 1
    (count (fun c -> removed c = Some "toward") cs);
  Alcotest.(check bool) "no error field" true (json |> member "beloch:error" = `Null);
  Alcotest.(check int) "the candidates are read on the state before the fold" 0
    (List.nth (entries json) 1 |> member "frame_index" |> to_int)

let test_conic () =
  let json, _ = fold_traced (triangle " (toward .c)") in
  let conics = List.nth (entries json) 1 |> member "conics" |> to_list in
  Alcotest.(check int) "one parabola" 1 (List.length conics);
  let c = List.hd conics in
  Alcotest.(check (list (float 1e-9))) "focus is .d" [ 0.; 1. ] (c |> member "focus" |> floats);
  (* --ef is x = 1/2 *)
  let d = c |> member "directrix" |> floats in
  let a, b, k = (List.nth d 0, List.nth d 1, List.nth d 2) in
  Alcotest.(check (float 1e-9)) "directrix is x = 1/2" 0.5 (k /. a);
  Alcotest.(check (float 1e-9)) "directrix is vertical" 0. b

let test_paper_filter () =
  let json, failed =
    fold_traced
      "paper square\nmark (map .a onto .d) as --ef\nfold (map .d onto --ef through .a) as --s\n"
  in
  Alcotest.(check bool) "the program succeeds" false failed;
  let cs = candidates (List.nth (entries json) 1) in
  Alcotest.(check int) "two candidates" 2 (List.length cs);
  Alcotest.(check int) "one removed by the paper" 1
    (count (fun c -> removed c = Some "paper") cs);
  Alcotest.(check int) "the other selected" 1 (count selected cs)

(* .a lies on --ab, so the cubic of axiom 7 has a root where .a lands on
   itself; its bisector 0·x + 0·y = 0 is no line and is no candidate, so the
   trace does not list it as one the paper removed. *)
let test_axiom7_point_on_line () =
  let json, failed =
    fold_traced "paper square\n--x = (map .a onto --ab and .c onto --da)\n"
  in
  Alcotest.(check bool) "the program succeeds" false failed;
  let e =
    List.find (fun e -> e |> member "axiom" |> to_string = "axiom7") (entries json)
  in
  let cs = candidates e in
  Alcotest.(check int) "one candidate" 1 (List.length cs);
  Alcotest.(check int) "none removed by the paper" 0
    (count (fun c -> removed c = Some "paper") cs);
  Alcotest.(check bool) "every candidate is a line" true
    (List.for_all
       (fun c ->
         match floats (c |> member "line") with
         | a :: b :: _ -> a <> 0. || b <> 0.
         | _ -> false)
       cs);
  Alcotest.(check int) "it is selected" 1 (count selected cs)

let test_single_solution () =
  let json, _ = fold_traced "paper square\nfold (map .a onto .c)\n" in
  match entries json with
  | [ e; _ ] ->
      Alcotest.(check string) "axiom" "axiom2" (e |> member "axiom" |> to_string);
      let cs = candidates e in
      Alcotest.(check int) "one candidate" 1 (List.length cs);
      Alcotest.(check int) "selected" 1 (count selected cs);
      Alcotest.(check bool) "no conics" true (e |> member "conics" = `Null)
  | es -> Alcotest.failf "expected two entries, got %d" (List.length es)

let test_axiom5_bind () =
  let json, failed =
    fold_traced
      "paper square\nmark (map --ab onto --cd) as --h\n.m = --h * --da\n\
       mark (through .m .c) as --mc\n--k = (map --h onto --mc)\n"
  in
  Alcotest.(check bool) "ambiguous without toward" true failed;
  let e = List.nth (entries json) 2 in
  Alcotest.(check string) "axiom" "axiom5" (e |> member "axiom" |> to_string);
  Alcotest.(check int) "both bisectors kept open" 2
    (count (fun c -> removed c = None) (candidates e))

(* ---- what each stage of the selection found ---- *)

(* the source text a one-line span "t.bel:L:C1-C2" covers *)
let spanned src sp =
  Scanf.sscanf sp "t.bel:%d:%d-%d" (fun l c1 c2 ->
      String.sub (List.nth (String.split_on_char '\n' src) (l - 1)) (c1 - 1) (c2 - c1))

let stage c = c |> member "removed_at" |> to_string_option

let test_spans () =
  let src = triangle " (.d toward .c) (moving .d)" in
  let json, _ = fold_traced src in
  let e = List.nth (entries json) 1 in
  let spans = e |> member "spans" in
  Alcotest.(check (list string)) "each alignment whole"
    [ ".d onto --ef"; "through .a" ]
    (spans |> member "alignments" |> to_list |> List.map (fun j -> spanned src (to_string j)));
  Alcotest.(check string) "the toward item" ".d toward .c"
    (spanned src (spans |> member "toward" |> to_string));
  Alcotest.(check string) "the moving item" "moving .d"
    (spanned src (spans |> member "moving" |> to_string));
  Alcotest.(check bool) "no heading" true (spans |> member "heading" = `Null);
  Alcotest.(check (option string)) "the subject" (Some ".d")
    (e |> member "subject" |> to_string_option);
  Alcotest.(check (option string)) "the toward" (Some ".c")
    (e |> member "toward_name" |> to_string_option);
  Alcotest.(check (list string)) "the operands, the through point included"
    [ ".d"; "--ef"; ".a" ]
    (e |> member "operands" |> to_list |> List.map (fun o -> o |> member "name" |> to_string));
  Alcotest.(check (list (float 1e-9))) "the moving anchor" [ 0.; 1. ]
    (e |> member "moving_point" |> floats);
  match e |> member "alignments" |> to_list with
  | [ a ] ->
      let names = a |> member "objects" |> to_list |> List.map (fun o -> o |> member "name" |> to_string) in
      Alcotest.(check (list string)) "the objects" [ ".d"; "--ef" ] names;
      Alcotest.(check string) "the onto alignment's span" ".d onto --ef"
        (spanned src (a |> member "span" |> to_string))
  | l -> Alcotest.failf "expected one onto alignment, got %d" (List.length l)

let test_heading_angle () =
  let src =
    "paper square\nmark (map .a onto .b) as --ef\n\
     fold (align (.d onto --ef) (through .a) (heading --ab)) as --s\n"
  in
  let json, _ = fold_traced src in
  let e = List.nth (entries json) 1 in
  Alcotest.(check string) "the heading item" "heading --ab"
    (spanned src (e |> member "spans" |> member "heading" |> to_string));
  let cs = candidates e in
  let angle c = c |> member "angle" |> to_number in
  (* .d lands at (1/2, ±√3/2), so the creases run at 15 and 75 degrees to --ab *)
  Alcotest.(check (list (float 1e-9))) "each angle" [ 15.; 75. ]
    (List.sort compare (List.map angle cs));
  let steep = List.find (fun c -> angle c > 45.) cs in
  Alcotest.(check (option string)) "the steeper one removed by heading" (Some "heading")
    (stage steep)

let test_side_from_toward () =
  let json, _ = fold_traced (triangle " (toward .c)") in
  let cs = candidates (List.nth (entries json) 1) in
  List.iter
    (fun c ->
      Alcotest.(check (option string)) "from toward" (Some "toward")
        (c |> member "side_from" |> to_string_option);
      let a = List.hd (c |> member "attempts" |> to_list) in
      Alcotest.(check int) "tried the side it folds" (c |> member "side" |> to_int)
        (a |> member "side" |> to_int))
    cs;
  (* the side opposite .c cannot carry .d onto --ef on one of them *)
  let lost = List.find (fun c -> not (selected c)) cs in
  Alcotest.(check (option string)) "removed at the moved-material stage" (Some "moved")
    (stage lost);
  Alcotest.(check bool) "with the alignment missed" true
    ((List.hd (lost |> member "attempts" |> to_list)) |> member "alignments" |> to_list
     = [ `Null ])

let test_landing_distance () =
  let json, _ = fold_traced (kite " (.d toward .t)") in
  let cs = candidates (List.nth (entries json) 1) in
  let ds = List.map (fun c -> c |> member "distance" |> to_number) cs in
  Alcotest.(check int) "both measured" 2 (List.length ds);
  Alcotest.(check (float 1e-9)) "equally near" (List.hd ds) (List.nth ds 1);
  List.iter
    (fun c ->
      Alcotest.(check int) "the landed .d is one point" 1
        (List.length (c |> member "landed" |> to_list));
      Alcotest.(check (option bool)) ".d folds over" (Some true)
        (c |> member "subject_folds" |> to_bool_option);
      (* the landed .d and .b itself, as far apart as the distance says *)
      match c |> member "nearest" |> to_list |> List.map floats with
      | [ [ x1; y1 ]; [ x2; y2 ] ] ->
          Alcotest.(check (list (float 1e-9))) "the toward end is .t" [ 1.; 0.4 ] [ x2; y2 ];
          Alcotest.(check (float 1e-9)) "the pair lies the distance apart"
            (c |> member "distance" |> to_number) (Float.hypot (x1 -. x2) (y1 -. y2))
      | _ -> Alcotest.fail "nearest is a pair of points")
    cs

(* (.a toward .b) measures where .a lands, so a fold that leaves .a where it
   is drops out at the landing stage, even with nothing left to compare *)
let test_subject_at_landing () =
  let json, failed =
    fold_traced
      "paper square\nmark (through .a .c) as --diag\nmark (through .b .d) as --anti\n\
       mark (map .a onto --anti and .d onto --diag) (.a toward .b)\n"
  in
  Alcotest.(check bool) "the program succeeds" false failed;
  let cs = candidates (List.nth (entries json) 2) in
  let out = List.filter (fun c -> not (selected c)) cs in
  Alcotest.(check (list (option string))) "removed at the landing stage" [ Some "landing" ]
    (List.map stage out);
  Alcotest.(check (option bool)) "for not folding .a over" (Some false)
    (List.hd out |> member "subject_folds" |> to_bool_option)

let test_default_side () =
  let json, _ =
    fold_traced
      "paper square\nmark (through .a .c) as --diag\nmark (through .b .d) as --anti\n\
       mark (map .a onto --anti and .d onto --diag)\n"
  in
  let cs = candidates (List.nth (entries json) 2) in
  List.iter
    (fun c ->
      if stage c <> Some "paper" then begin
        Alcotest.(check int) "both sides tried" 2 (List.length (c |> member "attempts" |> to_list));
        if stage c = None then
          Alcotest.(check bool) "alone or first" true
            (List.mem (c |> member "side_from" |> to_string) [ "alone"; "first" ])
      end)
    cs;
  (* every tried side reports each of the two alignments *)
  List.iter
    (fun c ->
      List.iter
        (fun a -> Alcotest.(check int) "two alignments" 2 (List.length (a |> member "alignments" |> to_list)))
        (c |> member "attempts" |> to_list))
    cs

let test_moving_meets () =
  let json, _ = fold_traced (triangle " (moving .d)") in
  let cs = candidates (List.nth (entries json) 1) in
  List.iter
    (fun c ->
      if stage c = None then
        let a = List.hd (c |> member "attempts" |> to_list) in
        Alcotest.(check (list int)) ".d folds onto --ef" [ 0 ]
          (a |> member "alignments" |> to_list |> List.map to_int))
    cs;
  Alcotest.(check bool) "every candidate from moving" true
    (List.for_all (fun c -> c |> member "side_from" |> to_string_option = Some "moving") cs)

(* ---- writes ---- *)

let write_entries json =
  List.filter (fun e -> e |> member "write" <> `Null) (entries json)

let only_write json =
  match write_entries json with
  | [ e ] -> e
  | es -> Alcotest.failf "expected one write entry, got %d" (List.length es)

let terms e = e |> member "terms"
let region j = j |> to_list |> List.map (fun p -> p |> to_list)
let placement e = terms e |> member "placement" |> to_string

let test_fold_terms () =
  let json, _ = fold_traced "paper square\nfold (map .a onto .c)\n" in
  let e = only_write json in
  Alcotest.(check string) "write" "fold" (e |> member "write" |> to_string);
  Alcotest.(check int) "statement" 0 (e |> member "statement" |> to_int);
  Alcotest.(check int) "read on the flat sheet" 0 (e |> member "frame_index" |> to_int);
  Alcotest.(check int) "the construction comes first" 1
    (List.length
       (List.filter (fun e -> e |> member "axiom" <> `Null) (entries json)));
  Alcotest.(check string) "placed on top" "top" (placement e);
  Alcotest.(check int) "the axis is a line" 3
    (List.length (terms e |> member "axis" |> to_list));
  let side = terms e |> member "side" |> to_int in
  Alcotest.(check bool) "side is a sign" true (side = 1 || side = -1);
  (* the half of the square with .a in it, one layer *)
  (match region (terms e |> member "moving") with
  | [ poly ] -> Alcotest.(check int) "a triangle" 3 (List.length poly)
  | r -> Alcotest.failf "expected one moving face, got %d" (List.length r));
  Alcotest.(check int) "a fold chooses no state" 0 (List.length (candidates e))

let test_fold_mountain () =
  let json, _ = fold_traced "paper square\nfold (map .a onto .c) (mountain)\n" in
  Alcotest.(check string) "placed at the bottom" "bottom" (placement (only_write json))

let test_fold_tuck () =
  let json, failed =
    fold_traced
      "paper square\nfold (map .a onto .d)\n.m = free on --bc from .b at 1/2\n\
       .n = free on --ab from .b at 1/2\n.p = free on --ab from .a at 1/4\n\
       fold (through .m .n) (moving .b) (up to .b) (under .p) as --t\n"
  in
  Alcotest.(check bool) "the program succeeds" false failed;
  let e = List.nth (write_entries json) 1 in
  Alcotest.(check string) "placed under" "under" (placement e);
  Alcotest.(check bool) "with a target region" true
    (region (terms e |> member "target") <> [])

let preliminary =
  "paper square\nfold (map .a onto .c) as --bd\nreverse (map .b onto .c) as --h\n\
   reverse (map .d onto .c) as --v\n"

let test_reverse () =
  let json, failed = fold_traced preliminary in
  Alcotest.(check bool) "the program succeeds" false failed;
  let e = List.nth (write_entries json) 1 in
  Alcotest.(check string) "write" "reverse" (e |> member "write" |> to_string);
  Alcotest.(check string) "inside" "inside" (terms e |> member "kind" |> to_string);
  Alcotest.(check bool) "a tip" true (region (terms e |> member "tip") <> []);
  let cs = candidates e in
  Alcotest.(check int) "one spine selected" 1 (count selected cs);
  let s = List.find selected cs in
  Alcotest.(check bool) "the selected spine has a frame" true
    (s |> member "frame" |> member "faces_vertices" <> `Null);
  Alcotest.(check int) "two halves" 2 (List.length (s |> member "halves" |> to_list));
  Alcotest.(check int) "two bodies" 2 (List.length (s |> member "bodies" |> to_list));
  Alcotest.(check int) "the spine is a segment" 2
    (List.length (s |> member "spine" |> to_list));
  List.iter
    (fun c ->
      if not (selected c) then begin
        Alcotest.(check bool) "a removed spine has a reason" true (removed c <> None);
        Alcotest.(check bool) "and no frame" true (c |> member "frame" = `Null)
      end)
    cs

let collapse toward =
  "paper square\nmark (through .a .c) as --ac\nmark (through .b .d) as --bd\n\
   mark (map --ab onto --cd) as --h\nmark (map --da onto --bc) as --v\n\
   .q = free on --ab from .a at 1/4\n.r = free on --ab from .b at 1/4\n\
   flatten (--h & --bc) (--v & --cd) (--h & --da) (--v & --ab) (--bd & .b) \
   (--bd & .d) (.q over .r)" ^ toward ^ "\n"

let test_flatten_even () =
  let json, failed = fold_traced (collapse " (toward .q)") in
  Alcotest.(check bool) "the program succeeds" false failed;
  let e = only_write json in
  Alcotest.(check string) "write" "flatten" (e |> member "write" |> to_string);
  Alcotest.(check (list (float 1e-9))) "the vertex is the center" [ 0.5; 0.5 ]
    (terms e |> member "point" |> floats);
  let cs = candidates e in
  Alcotest.(check int) "one selected" 1 (count selected cs);
  List.iter
    (fun c ->
      Alcotest.(check int) "six given rays" 6 (List.length (c |> member "rays" |> to_list));
      Alcotest.(check bool) "no emergent ray" true (c |> member "emergent" = `Null);
      Alcotest.(check int) "the stayer is bounded by two ray ends" 2
        (List.length (c |> member "stayer" |> to_list));
      Alcotest.(check bool) "every candidate is a state" true
        (c |> member "frame" |> member "faces_vertices" <> `Null);
      if not (selected c) then
        Alcotest.(check bool) "removed by a stage of the selection" true
          (List.mem (removed c) [ Some "toward"; Some "mountains"; Some "top" ]))
    cs

let test_flatten_ambiguous () =
  let json, failed = fold_traced (collapse "") in
  Alcotest.(check bool) "the program fails" true failed;
  let cs = candidates (only_write json) in
  Alcotest.(check int) "none selected" 0 (count selected cs);
  Alcotest.(check bool) "several stay open" true
    (count (fun c -> removed c = None) cs >= 2)

let test_flatten_odd () =
  let json, failed =
    fold_traced
      "paper square\nmark (map .a onto .c) as --diag\nmark (through .a .c) as --ray\n\
       mark (map --ab onto --diag) as --l1\nmark (map --da onto --diag) as --l2\n\
       flatten (--l1) (--l2) (--ray) (toward .d)\n"
  in
  Alcotest.(check bool) "the program succeeds" false failed;
  let cs = candidates (only_write json) in
  let s = List.find selected cs in
  Alcotest.(check int) "three given rays" 3 (List.length (s |> member "rays" |> to_list));
  Alcotest.(check int) "an emergent ray" 2 (List.length (s |> member "emergent" |> to_list))

(* .d lands at (1/2, ±√3/2); every point of y = 0 is as near to one landing
   as to the other, so `toward .b` selects nothing *)
let test_landing () =
  let json, _ = fold_traced (triangle " (toward .c)") in
  let lands =
    candidates (List.nth (entries json) 1) |> List.map (fun c -> c |> member "landing" |> floats)
  in
  (* .d = (0, 1) folded through .a lands on x = 1/2 at distance 1 from .a *)
  List.iter
    (fun l -> Alcotest.(check (float 1e-9)) "on --ef" 0.5 (List.hd l)) lands;
  Alcotest.(check (list (float 1e-9))) "one above, one below" [ -0.8660254037844386; 0.8660254037844386 ]
    (List.sort compare (List.map (fun l -> List.nth l 1) lands))

let test_toward_tie () =
  let json, failed = fold_traced (kite " (.d toward .t)") in
  Alcotest.(check bool) "the program fails" true failed;
  let cs = candidates (List.nth (entries json) 1) in
  Alcotest.(check int) "both stay open" 2 (count (fun c -> removed c = None) cs);
  Alcotest.(check int) "none selected" 0 (count selected cs);
  let err = json |> member "beloch:error" in
  Alcotest.(check bool) "the error names the tie" true
    (Str.string_match (Str.regexp ".*as near") (err |> member "message" |> to_string) 0);
  Alcotest.(check bool) "with a hint" true (err |> member "hint" <> `Null)

(* After a tie of a bare toward, a suggestion names what goes toward it: the
   objects of the alignments in the order the program writes them. *)
let test_tie_suggests_subject () =
  let json, failed =
    fold_traced
      "paper square\nmark (map .a onto .b) as --v\nmark (map .a onto .d) as --h\n\
       .u = free on --ab from .b at 1/5\nfold (map --v onto --h) (toward .u)\n"
  in
  Alcotest.(check bool) "the program fails" true failed;
  let cs = candidates (List.nth (entries json) 2) in
  Alcotest.(check (list (option string))) "--v measured alone keeps the first"
    [ Some "(--v toward .u)"; None ]
    (List.map (fun c -> c |> member "suggestion" |> to_string_option) cs)

(* A program with one candidate left carries no suggestion. *)
let test_no_suggestion_when_decided () =
  let json, _ = fold_traced (kite " (toward .c)") in
  let cs = candidates (List.nth (entries json) 1) in
  Alcotest.(check int) "none" 0
    (count (fun c -> c |> member "suggestion" <> `Null) cs)

(* Axiom 6 records its circle, and each side tried records what moves and
   where it lands. *)
let test_motions_and_circle () =
  let json, _ = fold_traced (kite "") in
  let e = List.nth (entries json) 1 in
  let circle = e |> member "circle" in
  Alcotest.(check (list (float 1e-9))) "the center is .q" [ 0.; 0.4 ]
    (circle |> member "center" |> floats);
  Alcotest.(check (list (float 1e-9))) "through .d" [ 0.; 1. ]
    (circle |> member "through" |> floats);
  List.iter
    (fun c ->
      let landing = c |> member "landing" |> floats in
      List.iter
        (fun a ->
          match a |> member "motions" |> to_list with
          | [ m ] when m <> `Null -> (
              match
                ( m |> member "source" |> to_list |> List.map (fun sg -> sg |> to_list |> List.map floats),
                  m |> member "image" |> to_list |> List.map (fun sg -> sg |> to_list |> List.map floats) )
              with
              | [ [ src; _ ] ], [ [ img; _ ] ] ->
                  (* .d onto --ef, or --ef onto .d: the place of --ef that
                     lands on .d is where .d would land *)
                  let d = [ 0.; 1. ] in
                  let moved, landed =
                    if (a |> member "alignments" |> to_list) = [ `Int 0 ] then (src, img)
                    else (img, src)
                  in
                  Alcotest.(check (list (float 1e-9))) ".d" d moved;
                  Alcotest.(check (list (float 1e-9))) "the landing" landing landed
              | _ -> Alcotest.fail "one place moves")
          | _ -> ())
        (c |> member "attempts" |> to_list))
    (candidates e)

let test_untraced_unchanged () =
  let src = triangle " (toward .c)" in
  let plain = Beloch.fold_string ~filename:"t.bel" src in
  Alcotest.(check bool) "no trace field without --trace" true
    (plain |> member "beloch:trace" = `Null);
  let traced, _ = fold_traced src in
  let strip = function
    | `Assoc kv -> `Assoc (List.filter (fun (k, _) -> k <> "beloch:trace") kv)
    | j -> j
  in
  Alcotest.(check string) "every other field is the same"
    (Yojson.Safe.to_string plain) (Yojson.Safe.to_string (strip traced))

let () =
  Alcotest.run "trace"
    [
      ( "constructions",
        [
          Alcotest.test_case "an ambiguous construction keeps both" `Quick
            test_ambiguous_keeps_both;
          Alcotest.test_case "toward selects, the other is removed" `Quick
            test_toward_selects;
          Alcotest.test_case "axiom 6 carries its parabola" `Quick test_conic;
          Alcotest.test_case "the paper filter is recorded" `Quick test_paper_filter;
          Alcotest.test_case "axiom 7 with the point on its line lists no non-line" `Quick
            test_axiom7_point_on_line;
          Alcotest.test_case "a single solution is one selected candidate" `Quick
            test_single_solution;
          Alcotest.test_case "axiom 5 in a binding" `Quick test_axiom5_bind;
          Alcotest.test_case "axiom 6 records where the point lands" `Quick test_landing;
          Alcotest.test_case "a toward point on the boundary selects nothing" `Quick
            test_toward_tie;
          Alcotest.test_case "without --trace nothing changes" `Quick
            test_untraced_unchanged;
          Alcotest.test_case "a tie suggests a subject" `Quick test_tie_suggests_subject;
          Alcotest.test_case "a decided selection suggests nothing" `Quick
            test_no_suggestion_when_decided;
          Alcotest.test_case "motions and the circle of axiom 6" `Quick test_motions_and_circle;
        ] );
      ( "stages",
        [
          Alcotest.test_case "the spans of the alignments and side items" `Quick test_spans;
          Alcotest.test_case "heading records each angle" `Quick test_heading_angle;
          Alcotest.test_case "toward fixes the side" `Quick
            test_side_from_toward;
          Alcotest.test_case "the landing stage measures each distance" `Quick
            test_landing_distance;
          Alcotest.test_case "the subject of toward is checked at the landing stage" `Quick
            test_subject_at_landing;
          Alcotest.test_case "without side items both sides are tried" `Quick test_default_side;
          Alcotest.test_case "moving: which object folds onto which" `Quick test_moving_meets;
        ] );
      ( "writes",
        [
          Alcotest.test_case "a fold's terms" `Quick test_fold_terms;
          Alcotest.test_case "a mountain fold is placed at the bottom" `Quick
            test_fold_mountain;
          Alcotest.test_case "a tuck has a target" `Quick test_fold_tuck;
          Alcotest.test_case "a reverse fold's spines" `Quick test_reverse;
          Alcotest.test_case "an even flatten's states" `Quick test_flatten_even;
          Alcotest.test_case "an ambiguous flatten keeps its states" `Quick
            test_flatten_ambiguous;
          Alcotest.test_case "an odd flatten's emergent ray" `Quick test_flatten_odd;
        ] );
    ]
