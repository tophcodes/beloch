(* tests/test_bel_assert.ml — runner for the `.bel` inline-assertion test
   format (docs/superpowers/specs/2026-07-14-beloch-inline-assertions-design.md).

   A test `.bel` file is a normal program followed by trailing `;`-comment
   assertions (`; assert ...` / `; expect error "..."`). The lexer already
   ignores `;` comments, so extraction reads the raw file text independent of
   parsing, and the program is evaluated verbatim (comments included). *)

open Beloch

(* Anchor to the source root of *this* build context, exactly like
   test_golden.ml — dune sets DUNE_SOURCEROOT to the absolute workspace root,
   so an in-repo worktree reads its own tests/cases/ rather than the main
   checkout's (#37). *)
let cases_dir =
  (match Sys.getenv_opt "DUNE_SOURCEROOT" with
   | Some root -> Filename.concat root "tests/cases"
   | None -> "../../../tests/cases")
  ^ "/"

(* every .bel under cases_dir (recursively); names are relative paths (e.g.
   "fold/basic-fold.bel") mirroring test_golden.ml's example_names walker. *)
let case_names () =
  let rec walk prefix =
    let dir = cases_dir ^ prefix in
    Sys.readdir dir |> Array.to_list
    |> List.concat_map (fun entry ->
           let rel = prefix ^ entry in
           if Sys.is_directory (dir ^ entry) then walk (rel ^ "/")
           else if Filename.check_suffix entry ".bel" then [ rel ]
           else [])
  in
  walk "" |> List.sort compare

let read path = In_channel.with_open_text path In_channel.input_all

(* ---- Extraction: raw-text lines matching ^\s*;\s*(assert|expect)\b ---- *)

let is_assert_line (line : string) : string option =
  let n = String.length line in
  let i = ref 0 in
  while !i < n && (line.[!i] = ' ' || line.[!i] = '\t') do incr i done;
  if !i >= n || line.[!i] <> ';' then None
  else begin
    incr i;
    while !i < n && (line.[!i] = ' ' || line.[!i] = '\t') do incr i done;
    let rest = String.sub line !i (n - !i) in
    let starts_with kw =
      let kn = String.length kw in
      String.length rest >= kn
      && String.sub rest 0 kn = kw
      && (String.length rest = kn || rest.[kn] = ' ' || rest.[kn] = '\t')
    in
    if starts_with "assert" || starts_with "expect" then Some rest else None
  end

let extract_assertions (src : string) : string list =
  String.split_on_char '\n' src |> List.filter_map is_assert_line

(* ---- Hand-rolled tokenizer (no Menhir — grammar is line-oriented, tiny) ---- *)

let tokenize (s : string) : string list =
  let n = String.length s in
  let toks = ref [] in
  let i = ref 0 in
  let is_punct c = c = '(' || c = ')' || c = ',' in
  let is_space c = c = ' ' || c = '\t' in
  while !i < n do
    let c = s.[!i] in
    if is_space c then incr i
    else if c = '"' then begin
      let j = ref (!i + 1) in
      while !j < n && s.[!j] <> '"' do incr j done;
      toks := String.sub s (!i + 1) (!j - !i - 1) :: !toks;
      i := !j + 1
    end
    else if is_punct c then begin
      toks := String.make 1 c :: !toks;
      incr i
    end
    else begin
      let j = ref !i in
      while !j < n && (not (is_space s.[!j])) && (not (is_punct s.[!j])) && s.[!j] <> '"' do
        incr j
      done;
      toks := String.sub s !i (!j - !i) :: !toks;
      i := !j
    end
  done;
  List.rev !toks

(* ---- Grammar (design doc "Assertion grammar (v1)") ---- *)

type space = Table | Paper

type value =
  | VPoint of string * space
  | VLine of string
  | VLit of Geom.point

type assign_kw = KMountain | KValley | KBoundary

type assertion =
  | AEq of value * value
  | AIncident of bool * value * value (* polarity; point operand; line|point target *)
  | AIs of string * assign_kw
  | ACount of string * int
  | ANamedStep of value * int (* named-step .p / --l = <int>: creation step *)
  | AExpectError of string

exception Harness_fail of string

let harness_fail fmt = Printf.ksprintf (fun s -> raise (Harness_fail s)) fmt

let parse_rat (toks : string list) : Num.t * string list =
  match toks with
  | tok :: rest -> (
      match String.index_opt tok '/' with
      | Some k -> (
          try
            let num = int_of_string (String.sub tok 0 k)
            and den =
              int_of_string (String.sub tok (k + 1) (String.length tok - k - 1))
            in
            (Num.of_q (Q.of_ints num den), rest)
          with _ -> harness_fail "malformed rational literal %S" tok)
      | None -> (
          try (Num.of_int (int_of_string tok), rest)
          with _ -> harness_fail "expected a rational number, got %S" tok))
  | [] -> harness_fail "expected a rational number"

let parse_literal (toks : string list) : Geom.point * string list =
  match toks with
  | "(" :: rest -> (
      let x, rest = parse_rat rest in
      match rest with
      | "," :: rest -> (
          let y, rest = parse_rat rest in
          match rest with
          | ")" :: rest -> ({ Geom.x; y }, rest)
          | _ -> harness_fail "expected ')' to close literal")
      | _ -> harness_fail "expected ',' in literal")
  | _ -> harness_fail "expected '(' to start a literal"

let parse_space_opt (toks : string list) : space * string list =
  match toks with
  | "table" :: rest -> (Table, rest)
  | "paper" :: rest -> (Paper, rest)
  | "flap" :: _ -> harness_fail "flap space is v2"
  | rest -> (Table, rest)

let parse_value (toks : string list) : value * string list =
  match toks with
  | tok :: rest when String.length tok > 0 && tok.[0] = '.' ->
      let name = String.sub tok 1 (String.length tok - 1) in
      let space, rest = parse_space_opt rest in
      (VPoint (name, space), rest)
  | tok :: rest when String.length tok >= 2 && String.sub tok 0 2 = "--" ->
      let name = String.sub tok 2 (String.length tok - 2) in
      (VLine name, rest)
  | "(" :: _ ->
      let lit, rest = parse_literal toks in
      (VLit lit, rest)
  | tok :: _ -> harness_fail "unrecognized value %S" tok
  | [] -> harness_fail "expected a value"

let parse_assign_kw (tok : string) : assign_kw =
  match tok with
  | "mountain" -> KMountain
  | "valley" -> KValley
  | "boundary" -> KBoundary
  | _ -> harness_fail "unknown assignment %S (want mountain/valley/boundary)" tok

let parse_assertion (toks : string list) : assertion =
  match toks with
  | "expect" :: "error" :: [ substr ] -> AExpectError substr
  | "expect" :: _ ->
      harness_fail "malformed 'expect' (want: expect error \"substr\")"
  | "assert" :: "faces" :: "=" :: [ n ] -> (
      try ACount ("faces", int_of_string n)
      with _ -> harness_fail "expected an int, got %S" n)
  | "assert" :: "steps" :: "=" :: [ n ] -> (
      try ACount ("steps", int_of_string n)
      with _ -> harness_fail "expected an int, got %S" n)
  | "assert" :: "named-step" :: rest -> (
      let v, rest = parse_value rest in
      match rest with
      | "=" :: [ n ] -> (
          try ANamedStep (v, int_of_string n)
          with _ -> harness_fail "expected an int, got %S" n)
      | _ -> harness_fail "malformed 'named-step' assertion (want: named-step <value> = <int>)")
  | "assert" :: rest -> (
      let v1, rest = parse_value rest in
      match rest with
      | "=" :: rest ->
          let v2, rest = parse_value rest in
          if rest <> [] then harness_fail "trailing tokens after '='";
          AEq (v1, v2)
      | [ "is"; kw ] -> (
          match v1 with
          | VLine name -> AIs (name, parse_assign_kw kw)
          | _ -> harness_fail "'is' requires a line operand (--name)")
      | "incident" :: rest ->
          let v2, rest = parse_value rest in
          if rest <> [] then harness_fail "trailing tokens after 'incident'";
          AIncident (true, v1, v2)
      | "not" :: "incident" :: rest ->
          let v2, rest = parse_value rest in
          if rest <> [] then harness_fail "trailing tokens after 'incident'";
          AIncident (false, v1, v2)
      | tok :: _ -> harness_fail "unexpected token %S after operand" tok
      | [] -> harness_fail "incomplete assertion")
  | tok :: _ -> harness_fail "assertion must start with 'assert' or 'expect', got %S" tok
  | [] -> harness_fail "empty assertion"

(* ---- Operand resolution against the evaluator's state ---- *)

(* A line is the same line as another, up to a nonzero scalar, iff the
   (a,b,c) triples are proportional — the 2x2 minors of the 2x3 matrix
   vanish. Geom has no line-equality helper, so this compares up to scalar
   multiple exactly (Num, no tolerances). *)
let line_equal (l1 : Geom.line) (l2 : Geom.line) : bool =
  let open Geom in
  Num.equal (Num.mul l1.a l2.b) (Num.mul l2.a l1.b)
  && Num.equal (Num.mul l1.a l2.c) (Num.mul l2.a l1.c)
  && Num.equal (Num.mul l1.b l2.c) (Num.mul l2.b l1.c)

(* v1 (non-goal note): boundary creases (the pristine paper edges) are never
   recorded as a Fold_state.hinge — Fold_state.init_square starts with
   `hinges = [||]` and hinges are only minted by fold/subdivide. fold_emit.ml's
   own FOLD serialization hits the same gap and works around it with a purely
   geometric test (`on_unit_boundary`) rather than a hinge lookup. We follow
   that established idiom: a "boundary" line is one that coincides (up to
   scalar) with one of the four paper-frame edges x=0/x=1/y=0/y=1 in PAPER
   space, checked directly against the resolved line — no hinge array lookup,
   since Fold_state.assign has no B constructor and never will (B is
   emit-time-only in fold_emit.ml). *)
let unit_boundary_lines : Geom.line list =
  let z = Num.zero and o = Num.one in
  [
    { Geom.a = o; b = z; c = z };
    (* x = 0 *)
    { Geom.a = o; b = z; c = o };
    (* x = 1 *)
    { Geom.a = z; b = o; c = z };
    (* y = 0 *)
    { Geom.a = z; b = o; c = o };
    (* y = 1 *)
  ]

let is_unit_boundary_line (l : Geom.line) : bool =
  List.exists (line_equal l) unit_boundary_lines

(* Eval.named_points/named_lines are (name, value, step) triples (step = the
   0-based creation step, task A1); look up by name, ignoring the step. *)
let assoc3 (name : string) (l : (string * 'a * int) list) : 'a option =
  List.find_map (fun (n, v, _) -> if n = name then Some v else None) l

let lookup_point (fd : Eval.folded) (name : string) : Geom.point =
  match assoc3 name fd.Eval.named_points with
  | Some p -> p
  | None -> harness_fail "unknown point .%s" name

let lookup_line (fd : Eval.folded) (name : string) : Geom.line =
  match assoc3 name fd.Eval.named_lines with
  | Some l -> l
  | None -> harness_fail "unknown line --%s" name

let lookup_named_step (fd : Eval.folded) (v : value) : string * int option =
  match v with
  | VPoint (name, _) ->
      ( Printf.sprintf ".%s" name,
        List.find_map (fun (n, _, s) -> if n = name then Some s else None)
          fd.Eval.named_points )
  | VLine name ->
      ( Printf.sprintf "--%s" name,
        List.find_map (fun (n, _, s) -> if n = name then Some s else None)
          fd.Eval.named_lines )
  | VLit _ -> harness_fail "'named-step' requires a point or line operand"

let check_named_step (fd : Eval.folded) (v : value) (n : int) : unit =
  let label, got = lookup_named_step fd v in
  match got with
  | None -> harness_fail "unknown name %s" label
  | Some s -> if s <> n then harness_fail "named-step %s = %d, expected %d" label s n

(* Table projection of a PAPER point: the face(s) whose paper polygon
   contains it, imaged through that face's isometry — the same idiom
   fold_emit.folded_frame_of_state uses (Isometry.apply_point f.iso p) to
   build vtable from vpaper. Ambiguity when containing faces disagree on the
   image (a point under multiple, differently-folded layers) is a harness
   error per the design doc; v1 has no flap space to disambiguate it. *)
let table_project (fd : Eval.folded) (p : Geom.point) : Geom.point =
  let st = fd.Eval.state in
  let faces = Fold_state.faces st in
  let containing =
    List.filter
      (fun i -> Geom.in_convex_polygon faces.(i) p)
      (List.init (Array.length faces) Fun.id)
  in
  match containing with
  | [] -> harness_fail "point not in any face"
  | is -> (
      let images =
        List.map (fun i -> Isometry.apply_point (Fold_state.face_iso2 st i) p) is
      in
      match images with
      | img0 :: rest when List.for_all (Geom.point_equal img0) rest -> img0
      | _ ->
          harness_fail
            "ambiguous table position (point lies in %d layers); flap space is v2"
            (List.length is))

type resolved = RPoint of Geom.point | RLine of Geom.line

let resolve_value (fd : Eval.folded) (v : value) : resolved =
  match v with
  | VLit p -> RPoint p
  | VLine name -> RLine (lookup_line fd name)
  | VPoint (name, Paper) -> RPoint (lookup_point fd name)
  | VPoint (name, Table) -> RPoint (table_project fd (lookup_point fd name))

let describe_value (v : value) : string =
  match v with
  | VLit _ -> "literal"
  | VLine name -> Printf.sprintf "--%s" name
  | VPoint (name, Table) -> Printf.sprintf ".%s" name
  | VPoint (name, Paper) -> Printf.sprintf ".%s paper" name

(* [=] : point=point / point=literal (both compared in the resolved space)
   or line=line (normalised, exact). Mismatched kinds (point vs line) are a
   harness error — the grammar never intends that combination. *)
let values_equal (fd : Eval.folded) (v1 : value) (v2 : value) : bool =
  match (resolve_value fd v1, resolve_value fd v2) with
  | RPoint p1, RPoint p2 -> Geom.point_equal p1 p2
  | RLine l1, RLine l2 -> line_equal l1 l2
  | RPoint _, RLine _ | RLine _, RPoint _ ->
      harness_fail "type mismatch: %s is a %s, %s is a %s" (describe_value v1)
        (match resolve_value fd v1 with RPoint _ -> "point" | RLine _ -> "line")
        (describe_value v2)
        (match resolve_value fd v2 with RPoint _ -> "point" | RLine _ -> "line")

let check_eq (fd : Eval.folded) (v1 : value) (v2 : value) : unit =
  if not (values_equal fd v1 v2) then
    harness_fail "%s = %s failed" (describe_value v1) (describe_value v2)

let check_incident (fd : Eval.folded) (polarity : bool) (v1 : value) (v2 : value) : unit =
  let name1 = match v1 with VPoint (n, _) -> n | _ -> harness_fail "'incident' requires a point operand" in
  match v2 with
  | VLine lname ->
      (* incidence is a construction relation: always paper space,
         regardless of any space qualifier written on the point. *)
      let l = lookup_line fd lname in
      let paper_p = lookup_point fd name1 in
      let on = Geom.side_of_line l paper_p = 0 in
      if on <> polarity then
        harness_fail "%s %sincident to --%s" (describe_value v1) (if polarity then "not " else "") lname
  | VPoint _ | VLit _ ->
      let eq = values_equal fd v1 v2 in
      if eq <> polarity then
        harness_fail "%s %sincident to %s" (describe_value v1) (if polarity then "not " else "")
          (describe_value v2)

let check_is (fd : Eval.folded) (name : string) (kw : assign_kw) : unit =
  let l = lookup_line fd name in
  match kw with
  | KBoundary ->
      if not (is_unit_boundary_line l) then harness_fail "--%s is not the paper boundary" name
  | KMountain | KValley ->
      let want = if kw = KMountain then Fold_state.M else Fold_state.V in
      let st = fd.Eval.state in
      let hs = Fold_state.hinges st in
      (* Prefer the crease's IDENTITY: named_lines' coefficients are the
         crease's CURRENT (table-space) line, which can coincide with another
         crease's line once folds move material (e.g. a flatten's emergent
         ray folded onto a mark's line) — a bare line filter then reads the
         wrong hinges. Line filtering (paper space) remains the fallback for
         [Frozen] names, which have no crease id. *)
      let on_line i =
        let a, b = Fold_state.hinge_segment st i in
        Geom.side_of_line l a = 0 && Geom.side_of_line l b = 0
      in
      let matching =
        match List.assoc_opt name fd.Eval.named_line_cids with
        | Some cid ->
            let by_cid =
              List.filter
                (fun i -> hs.(i).Fold_state.crease_id = cid)
                (List.init (Array.length hs) Fun.id)
            in
            (* a through-fold carries one cid across several layers whose
               derived letters alternate; the crease's user-facing letter is
               the REFERENCE layer's — the hinge still lying (paper-space) on
               the named line. A crease whose hinge moved entirely (e.g. a
               flatten's emergent ray) has no such hinge: judge all of them. *)
            (match List.filter on_line by_cid with [] -> by_cid | ref -> ref)
        | None -> List.filter on_line (List.init (Array.length hs) Fun.id)
      in
      (match matching with
       | [] -> harness_fail "--%s is not a material crease" name
       | is ->
           if not (List.for_all (fun i -> Fold_state.mv st i = want) is) then
             harness_fail "--%s is not %s" name
               (if kw = KMountain then "mountain" else "valley"))

let check_count (fd : Eval.folded) (kind : string) (n : int) : unit =
  let got =
    match kind with
    | "faces" -> Array.length (Fold_state.faces fd.Eval.state)
    | "steps" -> List.length fd.Eval.frames
    | _ -> assert false
  in
  if got <> n then harness_fail "%s = %d, expected %d" kind got n

let check_assertion (fd : Eval.folded) (a : assertion) : unit =
  match a with
  | AEq (v1, v2) -> check_eq fd v1 v2
  | AIncident (polarity, v1, v2) -> check_incident fd polarity v1 v2
  | AIs (name, kw) -> check_is fd name kw
  | ACount (kind, n) -> check_count fd kind n
  | ANamedStep (v, n) -> check_named_step fd v n
  | AExpectError _ -> assert false (* handled at the file level *)

(* Substring test (like test_e2e.ml's expect_error, without pulling in Str). *)
let contains_substring (haystack : string) (needle : string) : bool =
  let hn = String.length haystack and nn = String.length needle in
  if nn = 0 then true
  else
    let rec go i = i + nn <= hn && (String.sub haystack i nn = needle || go (i + 1)) in
    go 0

(* ---- Per-file test ---- *)

let test_one (name : string) () =
  let path = cases_dir ^ name in
  let src = read path in
  let lines = extract_assertions src in
  let parsed =
    List.map
      (fun line ->
        match parse_assertion (tokenize line) with
        | a -> (line, a)
        | exception Harness_fail msg -> Alcotest.failf "%s: %S: %s" name line msg)
      lines
  in
  let error_lines =
    List.filter (fun (_, a) -> match a with AExpectError _ -> true | _ -> false) parsed
  in
  match error_lines with
  | _ :: _ :: _ -> Alcotest.failf "%s: more than one 'expect error' assertion" name
  | [ (line, AExpectError substr) ] ->
      if List.length parsed <> 1 then
        Alcotest.failf "%s: 'expect error' must be the only assertion in the file" name
      else begin
        match Eval.eval_folded (Beloch.parse ~filename:(Filename.basename name) src) with
        | (_ : Eval.folded) ->
            Alcotest.failf "%s: %S: expected an error containing %S, but eval succeeded" name line substr
        | exception Error.Beloch_error (_, msg) ->
            if not (contains_substring msg substr) then
              Alcotest.failf "%s: %S: error message %S does not contain %S" name line msg substr
      end
  | [ (_, _) ] -> assert false (* error_lines only ever holds AExpectError elements *)
  | [] -> (
      match Eval.eval_folded (Beloch.parse ~filename:(Filename.basename name) src) with
      | fd ->
          List.iter
            (fun (line, a) ->
              try check_assertion fd a
              with Harness_fail msg -> Alcotest.failf "%s: %S: %s" name line msg)
            parsed
      | exception Error.Beloch_error (_, msg) ->
          Alcotest.failf "%s: unexpected evaluation error: %s" name msg)

let () =
  Alcotest.run "bel_assert"
    [ ("cases", List.map (fun n -> Alcotest.test_case n `Quick (test_one n)) (case_names ())) ]
