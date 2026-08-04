# Multifold Phase 1: Two-Fold Enumeration Machinery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the alignment-enumeration machinery in a new `packages/multifold` package and reproduce Alperin & Lang's counts: 7 one-fold axioms, 203 two-fold axioms without AL10, 489 with AL10.

**Architecture:** A pure-OCaml pipeline: (1) an alignment alphabet with an equation-count table, (2) a multiset generator producing candidate axiom combinations modulo a↔b fold swap with a structural separability filter, (3) a symbolic equation builder that turns a combination into 4 polynomials in the fold-line coordinates (X₁,Y₁,X₂,Y₂) over ℚ using Alperin-Lang's line representation Xx+Yy+1=0 with generic rational parameters, (4) a validity filter that calls `msolve` as a subprocess to test the system is 0-dimensional with ≥1 solution. The paper's printed 489-symbol list is parsed into a test fixture and used as a symbol-by-symbol oracle, not just a count.

**Tech Stack:** OCaml (dune, single root project), `beloch` core library (`Mpoly` sparse multivariate polynomials over ℚ, `zarith` `Q.t`), alcotest, `msolve` (external binary, subprocess), nix flake devShell.

## Global Constraints

- Everything in OCaml inside the existing dune project; external math tools (msolve, later PARI) are subprocesses, never linked (spec: "PARI called as a subprocess, not linked").
- No changes to Beloch's user-facing language semantics (spec non-goal).
- Citation discipline per `CLAUDE.md`: origami-math claims cite `refs/` by key + locator; `[alperin2006]` = the Dec-6-2006 preprint in `refs/alperin2006.txt`.
- Dev profile has `-warn-error +a`; code must be warning-clean. Format with `dune fmt`.
- Tests: alcotest, one `(test (name test_X))` stanza per file in `packages/multifold/tests/dune`.
- Conventional commits, concise messages.
- Reproduction anchors (must match exactly): k=1 → 7 axioms; k=2 without AL10 → 203; with AL10 → 489 [alperin2006, §2 Table 1, §4].
- On count mismatch: do NOT tweak until matching. Diff against the fixture symbol list, identify the class of disagreement, write it up in `notes/` (spec: "treat mismatches as findings, not failures"). First suspects, in order: separability rules, self-alignment equation counts, msolve genericity (retry with parameter set B), multiplicity handling (A-L's Jacobian-at-solutions test).

## File Structure

```
decisions/0020-multifold-research-package.md      ADR: package boundary
packages/multifold/lib/dune                        (library (name multifold) (libraries beloch zarith))
packages/multifold/lib/alignment.ml/.mli           alphabet, equation counts, symbols
packages/multifold/lib/combo.ml/.mli               multiset generator, canonicalization, separability
packages/multifold/lib/symeq.ml/.mli               reflection formulas, per-alignment equations (Mpoly)
packages/multifold/lib/msolve.ml/.mli              subprocess driver + output parser
packages/multifold/lib/pipeline.ml/.mli            enumerate → filter → count/list
packages/multifold/tests/dune
packages/multifold/tests/test_alignment.ml
packages/multifold/tests/test_combo.ml
packages/multifold/tests/test_symeq.ml
packages/multifold/tests/test_msolve.ml
packages/multifold/tests/test_pipeline.ml          the 7/203/489 anchors
packages/multifold/tests/fixtures/al489.txt        paper's symbol list (one per line)
packages/multifold/tools/extract_fixture.ml        one-shot: refs txt → fixture
```

New modules follow ADR 0018's spirit voluntarily: every lib module has an `.mli`, dependency order `Alignment → Combo → Symeq → Msolve → Pipeline`, acyclic.

---

### Task 1: ADR + package scaffold

**Files:**
- Create: `decisions/0020-multifold-research-package.md`
- Create: `packages/multifold/lib/dune`, `packages/multifold/lib/alignment.ml`, `packages/multifold/lib/alignment.mli`
- Create: `packages/multifold/tests/dune`, `packages/multifold/tests/test_alignment.ml`

**Interfaces:**
- Produces: dune library `multifold` depending on `beloch`; test harness pattern for all later tasks.

- [ ] **Step 1: Write the ADR**

`decisions/0020-multifold-research-package.md` (match the format of `decisions/0018-core-module-boundaries.md` — read it first for the template):

Content requirements: status Accepted; context = multifold research track (link the spec `docs/superpowers/specs/2026-08-03-multifold-axioms-research-design.md`); decision = new dune library `multifold` under `packages/multifold/`, depends on `beloch` core lib (for `Mpoly`, `Q` via zarith) and nothing else in core's internals it doesn't need; core never depends on `multifold`; external solvers are subprocesses; every module has an `.mli`. Consequence: research code stays out of the evaluator; deleting `packages/multifold/` must leave core building.

- [ ] **Step 2: Write the failing test**

`packages/multifold/tests/test_alignment.ml`:

```ocaml
open Multifold

let test_alphabet_size () =
  Alcotest.(check int) "17 two-fold symbols" 17 (List.length Alignment.all_twofold)

let () =
  Alcotest.run "multifold-alignment"
    [ ("alphabet", [ Alcotest.test_case "size" `Quick test_alphabet_size ]) ]
```

`packages/multifold/tests/dune`:

```lisp
(test
 (name test_alignment)
 (libraries multifold alcotest))
```

`packages/multifold/lib/dune`:

```lisp
(library
 (name multifold)
 (libraries beloch zarith))
```

- [ ] **Step 3: Run test to verify it fails**

Run: `dune build @packages/multifold/all 2>&1 | head -20`
Expected: FAIL — `Unbound module Multifold` / `Alignment`.

- [ ] **Step 4: Minimal implementation**

`packages/multifold/lib/alignment.mli`:

```ocaml
(** The Alperin-Lang two-fold alignment alphabet [alperin2006, §4, Fig. 4]. *)

type kind = AL1 | AL2 | AL3 | AL4 | AL5 | AL6 | AL7 | AL8 | AL9 | AL10
type suffix = A | B | Sym  (** Sym for the symmetric kinds AL1, AL8, AL9 *)
type t = { kind : kind; suffix : suffix }

val all_twofold : t list
(** The 17 symbols: AL1, AL8, AL9 symmetric; AL2–AL7, AL10 in a/b variants. *)
```

`packages/multifold/lib/alignment.ml`:

```ocaml
type kind = AL1 | AL2 | AL3 | AL4 | AL5 | AL6 | AL7 | AL8 | AL9 | AL10
type suffix = A | B | Sym
type t = { kind : kind; suffix : suffix }

let symmetric = function AL1 | AL8 | AL9 -> true | _ -> false

let all_twofold =
  let kinds = [ AL1; AL2; AL3; AL4; AL5; AL6; AL7; AL8; AL9; AL10 ] in
  List.concat_map
    (fun kind ->
      if symmetric kind then [ { kind; suffix = Sym } ]
      else [ { kind; suffix = A }; { kind; suffix = B } ])
    kinds
```

- [ ] **Step 5: Run test to verify it passes**

Run: `dune test packages/multifold/tests/ 2>&1 | tail -5`
Expected: PASS (1 test).

- [ ] **Step 6: Commit**

```bash
git add decisions/0020-multifold-research-package.md packages/multifold
git commit -m "feat(multifold): research package scaffold + ADR 0020"
```

---

### Task 2: Equation-count table + symbol printing/parsing

**Files:**
- Modify: `packages/multifold/lib/alignment.ml`, `.mli`
- Modify: `packages/multifold/tests/test_alignment.ml`

**Interfaces:**
- Produces: `Alignment.equations : t -> int`, `Alignment.swap_ab : t -> t`, `Alignment.compare : t -> t -> int`, `Combo`-facing symbol printer/parser `Alignment.combo_to_symbol : t list -> string` and `Alignment.combo_of_symbol : string -> t list option` implementing the paper's notation (`AL6ab8` = AL6a, AL6b, AL8) [alperin2006, §4].

- [ ] **Step 1: Write the failing tests**

Append to `test_alignment.ml`:

```ocaml
let al k s = Alignment.{ kind = k; suffix = s }

let test_equation_counts () =
  (* [alperin2006, §4]: alignments yield 1 or 2 equations; a valid 2FA has
     2–4 alignments totalling exactly 4. Table: AL4, AL8, AL9 → 2; rest → 1. *)
  Alcotest.(check int) "AL1"  1 (Alignment.equations (al AL1 Sym));
  Alcotest.(check int) "AL2a" 1 (Alignment.equations (al AL2 A));
  Alcotest.(check int) "AL4a" 2 (Alignment.equations (al AL4 A));
  Alcotest.(check int) "AL8"  2 (Alignment.equations (al AL8 Sym));
  Alcotest.(check int) "AL9"  2 (Alignment.equations (al AL9 Sym));
  Alcotest.(check int) "AL10b" 1 (Alignment.equations (al AL10 B))

let test_symbol_roundtrip () =
  let cases = [ "AL6ab8"; "AL110aaa"; "AL2a3b10ab"; "AL4ab"; "AL10aaab" ] in
  List.iter
    (fun s ->
      match Alignment.combo_of_symbol s with
      | None -> Alcotest.failf "parse %s" s
      | Some c ->
          Alcotest.(check string) ("roundtrip " ^ s) s (Alignment.combo_to_symbol c))
    cases

let test_symbol_semantics () =
  (* AL6ab8 = AL6a + AL6b + AL8 *)
  match Alignment.combo_of_symbol "AL6ab8" with
  | Some [ x; y; z ] ->
      Alcotest.(check bool) "AL6a" true (x = al AL6 A);
      Alcotest.(check bool) "AL6b" true (y = al AL6 B);
      Alcotest.(check bool) "AL8" true (z = al AL8 Sym)
  | _ -> Alcotest.fail "expected 3 alignments"
```

(register the new cases in the runner list)

- [ ] **Step 2: Run to verify failure** — `dune test packages/multifold/tests/`; expected: compile error (missing functions).

- [ ] **Step 3: Implement**

In `alignment.ml` (and expose in `.mli`):

```ocaml
let equations t = match t.kind with AL4 | AL8 | AL9 -> 2 | _ -> 1

let swap_ab t =
  match t.suffix with A -> { t with suffix = B } | B -> { t with suffix = A } | Sym -> t

let kind_index = function
  | AL1 -> 1 | AL2 -> 2 | AL3 -> 3 | AL4 -> 4 | AL5 -> 5
  | AL6 -> 6 | AL7 -> 7 | AL8 -> 8 | AL9 -> 9 | AL10 -> 10

let compare x y =
  match Int.compare (kind_index x.kind) (kind_index y.kind) with
  | 0 -> Stdlib.compare x.suffix y.suffix  (* A < B < Sym irrelevant: never mixed per kind *)
  | c -> c
```

Printer: sort the combo with `compare`; group by kind in ascending index; for each group emit the kind's number once, then the concatenated suffix letters (`a`/`b`, in a-before-b order, one letter per occurrence; symmetric kinds emit no letters but DO repeat nothing — a repeated symmetric kind would emit its number once per occurrence, which does not occur in valid combos). Parser: inverse — scan `AL`, then repeatedly read a number (greedy: `10` before `1`; disambiguation rule: try two-digit `10` first) followed by zero or more `a`/`b` letters; number with no letters = one symmetric occurrence; with letters = one occurrence per letter. **Watch out:** `AL110aaa` parses as kind 1 (no letters) then kind 10 with `aaa`; the greedy-10 rule must not swallow the leading `1`. Implement by trying, at each position, `10` first but backtracking to `1` if the remainder fails to parse; a 20-line recursive descent is fine.

- [ ] **Step 4: Run to verify pass** — `dune test packages/multifold/tests/`; expected: PASS.

- [ ] **Step 5: Commit** — `git add -A packages/multifold && git commit -m "feat(multifold): equation counts + A-L symbol notation"`

---

### Task 3: Fixture from the paper's printed list

**Files:**
- Create: `packages/multifold/tools/extract_fixture.ml`, `packages/multifold/tools/dune`
- Create: `packages/multifold/tests/fixtures/al489.txt`
- Modify: `packages/multifold/tests/test_alignment.ml`, `packages/multifold/tests/dune`

**Interfaces:**
- Produces: `tests/fixtures/al489.txt` — one symbol per line, exactly 489 lines, provenance header comment. Later tasks diff pipeline output against it.

- [ ] **Step 1: Write the extractor**

`packages/multifold/tools/extract_fixture.ml` — reads `refs/alperin2006.txt` (path via `Sys.argv.(1)`), extracts the symbol list [alperin2006, §4, pp. 12–14 of the preprint]: concatenate the lines of the printed list (they start with `AL` and are comma-separated, broken across lines and across the page break — strip page-number lines), split on `,`, trim, keep tokens matching `^AL[0-9ab]+$`, print one per line, sorted, deduplicated. `tools/dune`:

```lisp
(executable
 (name extract_fixture)
 (libraries multifold))
```

Validate each token with `Alignment.combo_of_symbol` (reject `None`) — this catches OCR damage.

- [ ] **Step 2: Run it, inspect, hand-fix**

```bash
dune exec packages/multifold/tools/extract_fixture.exe -- refs/alperin2006.txt \
  > packages/multifold/tests/fixtures/al489.txt
wc -l packages/multifold/tests/fixtures/al489.txt
```

Expected: 489 lines. If OCR broke tokens (likely a handful), fix by hand against `refs/alperin2006.pdf` and note each fix in a `#`-comment header of the fixture (the test skips `#` lines). Do not proceed until the count is 489 and every line parses.

- [ ] **Step 3: Write the fixture tests**

Append to `test_alignment.ml` (add `(deps (glob_files fixtures/*.txt))` to the test stanza):

```ocaml
let fixture () =
  let ic = open_in "fixtures/al489.txt" in
  let rec go acc =
    match input_line ic with
    | exception End_of_file -> close_in ic; List.rev acc
    | l when String.length l = 0 || l.[0] = '#' -> go acc
    | l -> go (l :: acc)
  in
  go []

let test_fixture_count () =
  Alcotest.(check int) "489 symbols" 489 (List.length (fixture ()))

let test_fixture_all_sum_to_four () =
  List.iter
    (fun s ->
      match Alignment.combo_of_symbol s with
      | None -> Alcotest.failf "unparseable %s" s
      | Some c ->
          let sum = List.fold_left (fun n a -> n + Alignment.equations a) 0 c in
          Alcotest.(check int) ("eqs of " ^ s) 4 sum;
          let n = List.length c in
          Alcotest.(check bool) ("2..4 alignments in " ^ s) true (n >= 2 && n <= 4))
    (fixture ())
```

- [ ] **Step 4: Run to verify pass** — `dune test packages/multifold/tests/`. This is a real oracle: if our equation-count table is wrong, some of the 489 printed symbols won't sum to 4.

- [ ] **Step 5: Commit** — `git add -A packages/multifold && git commit -m "feat(multifold): 489-symbol fixture from alperin2006 + oracle tests"`

---

### Task 4: Combination generator + canonicalization + separability

**Files:**
- Create: `packages/multifold/lib/combo.ml`, `.mli`
- Create: `packages/multifold/tests/test_combo.ml` (+ dune stanza)

**Interfaces:**
- Consumes: `Alignment.t`, `equations`, `swap_ab`, `compare`, `combo_to_symbol`.
- Produces:
  - `Combo.t = Alignment.t list` (sorted with `Alignment.compare`)
  - `Combo.candidates : unit -> Combo.t list` — all multisets of 2–4 symbols from `Alignment.all_twofold`, equation sum exactly 4, canonical under global a↔b swap, non-separable.
  - `Combo.canonical : Combo.t -> Combo.t` — min (lex, via `Alignment.compare` list order) of the combo and its `swap_ab` image, both sorted.
  - `Combo.separable : Combo.t -> bool` [alperin2006, Def. 10].

- [ ] **Step 1: Write the failing tests**

`test_combo.ml`:

```ocaml
open Multifold
let al k s = Alignment.{ kind = k; suffix = s }

let test_canonical_swap () =
  (* AL2b+AL3a+AL10b sorted, swapped = AL2a+AL3b+AL10a — canonical picks the swap-min *)
  let c = [ al AL2 B; al AL3 A; al AL10 B ] in
  let cc = Combo.canonical c in
  Alcotest.(check string) "canonical symbol" "AL2a3b10a" (Alignment.combo_to_symbol cc)

let test_separable () =
  (* AL2a+AL3a determine fold a alone (2 one-fold-style equations on fold a);
     paired with AL2b+AL3b this is two independent 1FAs → separable. *)
  Alcotest.(check bool) "separable" true
    (Combo.separable [ al AL2 A; al AL3 A; al AL2 B; al AL3 B ]);
  (* AL6ab8 is in the paper's list → non-separable *)
  Alcotest.(check bool) "AL6ab8 stays" false
    (Combo.separable [ al AL6 A; al AL6 B; al AL8 Sym ])

let test_candidates_contain_fixture () =
  (* Every printed 489 symbol must appear among raw candidates (superset check). *)
  let cands =
    Combo.candidates ()
    |> List.map Alignment.combo_to_symbol
    |> List.sort_uniq String.compare
  in
  let missing =
    List.filter (fun s -> not (List.mem s cands)) (Test_fixture.fixture ())
  in
  Alcotest.(check (list string)) "no fixture symbol missing" [] missing
```

(Extract the `fixture ()` reader from Task 3 into a small shared test helper module `test_fixture.ml` in the tests dir, referenced from both test stanzas via `(modules ...)`; adjust the Task-3 test accordingly.)

- [ ] **Step 2: Run to verify failure** — compile error.

- [ ] **Step 3: Implement**

`combo.ml` core:

```ocaml
type t = Alignment.t list

let sort = List.sort Alignment.compare

let canonical c =
  let a = sort c in
  let b = sort (List.map Alignment.swap_ab c) in
  if List.compare Alignment.compare a b <= 0 then a else b

(* Which fold lines does an alignment's equation system mention?
   [alperin2006, Fig. 4]: AL2, AL3, AL6 mention one fold line (their suffix);
   AL1, AL4, AL5, AL7, AL8, AL9, AL10 mention both. *)
let folds_mentioned (a : Alignment.t) : [ `One_a | `One_b | `Both ] =
  match a.kind with
  | AL2 | AL3 | AL6 -> (match a.suffix with A -> `One_a | B -> `One_b | Sym -> assert false)
  | _ -> `Both

let separable c =
  (* Separable iff the multiset splits into two groups, each mentioning only
     one distinct fold line, each summing to 2 equations (i.e. each is a 1FA). *)
  let one_a = List.filter (fun a -> folds_mentioned a = `One_a) c in
  let one_b = List.filter (fun a -> folds_mentioned a = `One_b) c in
  let both = List.filter (fun a -> folds_mentioned a = `Both) c in
  let sum l = List.fold_left (fun n a -> n + Alignment.equations a) 0 l in
  both = [] && sum one_a = 2 && sum one_b = 2

let candidates () =
  let alphabet = Array.of_list Alignment.all_twofold in
  let n = Array.length alphabet in
  let out = ref [] in
  (* multisets as non-decreasing index sequences, length 2..4, pruned on eq sum *)
  let rec go start acc eqs len =
    if eqs = 4 && len >= 2 then out := List.rev acc :: !out;
    if eqs < 4 && len < 4 then
      for i = start to n - 1 do
        let a = alphabet.(i) in
        let e = Alignment.equations a in
        if eqs + e <= 4 then go i (a :: acc) (eqs + e) (len + 1)
      done
  in
  go 0 [] 0 0;
  !out
  |> List.filter (fun c -> not (separable c))
  |> List.map canonical
  |> List.sort_uniq (List.compare Alignment.compare)
```

- [ ] **Step 4: Run to verify pass**, and print the candidate count once (`dune exec` a tiny probe or temporary test log): record the raw candidate count in the commit message body — it is the crude upper bound at k=2 (spec's early milestone: same generator later reports the k=3 bound).

- [ ] **Step 5: Commit** — `git commit -m "feat(multifold): candidate generator, canonicalization, separability (raw k=2 count: <N>)"`

---

### Task 5: One-fold warm-up — reproduce the 7 HJAs structurally

**Files:**
- Modify: `packages/multifold/lib/combo.ml`, `.mli`
- Modify: `packages/multifold/tests/test_combo.ml`

**Interfaces:**
- Produces: `Combo.onefold_candidates : unit -> string list` — the analogous generator over the one-fold alphabet A1–A5 [alperin2006, §2, Fig. 2]: A1 (2 eq), A2 (2 eq), A3–A5 (1 eq each); combos summing to exactly 2 equations; invalid pair {A3,A3} (two lines folded onto themselves) excluded [alperin2006, Table 1]; returns canonical names.

- [ ] **Step 1: Write the failing test**

```ocaml
let test_onefold_seven () =
  let expected = [ "A1"; "A2"; "A3+A4"; "A3+A5"; "A4+A4"; "A4+A5"; "A5+A5" ] in
  Alcotest.(check (list string)) "the 7 HJAs" expected (Combo.onefold_candidates ())
```

Mapping to the classical names, as a comment in the test: A1=O2, A2=O3, {A3,A4}=O7, {A3,A5}=O4, {A4,A4}=O6, {A4,A5}=O5, {A5,A5}=O1 [alperin2006, Table 1].

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement** — a small enum `onefold = OA1 | OA2 | OA3 | OA4 | OA5` inside `combo.ml` with its own equation table (A1,A2→2; A3,A4,A5→1), the same multiset recursion (length 1–2, sum 2), and the single structural exclusion `{A3,A3}` with a citation comment. No fold-swap needed (one fold line).

- [ ] **Step 4: Run to verify pass.** This validates the generator logic end-to-end on ground truth before any symbolic algebra exists.

- [ ] **Step 5: Commit** — `git commit -m "feat(multifold): one-fold generator reproduces the 7 HJAs"`

---

### Task 6: Symbolic layer — reflections and per-alignment equations

**Files:**
- Create: `packages/multifold/lib/symeq.ml`, `.mli`
- Create: `packages/multifold/tests/test_symeq.ml` (+ dune stanza)

**Interfaces:**
- Consumes: `Beloch.Mpoly` (`var`, `const`, `add`, `sub`, `mul`, `pow`, `specialize`, `is_zero`), `Q.t`; `Alignment.t`; `Combo.t`.
- Produces:
  - Variables: fold line i ∈ {0,1} has coordinates `x_i = Mpoly.var ~nvars 2i`, `y_i = var (2i+1)`; `nvars = 4` for two-fold work (and 2 for the one-fold pipeline reuse).
  - `Symeq.params` — a record of the generic given objects an alignment consumes: points as `Q.t * Q.t`, lines as `Q.t * Q.t` (A-L representation `(X,Y)` meaning `Xx+Yy+1=0` [alperin2006, Def. 2]). Two hardcoded generic parameter streams `Symeq.stream_a` / `Symeq.stream_b` (distinct fixed rationals with large mixed numerators/denominators, e.g. drawn from `17/13, -29/7, 41/23, …`; each alignment pulls fresh values so no two alignments share objects, matching A-L's "assumed distinct").
  - `Symeq.reflect_point : fold:int -> Q.t * Q.t -> rat2` — folded image of a *given* point across fold line `i`, as a pair of (numerator `Mpoly.t`, shared denominator `Mpoly.t = x_i² + y_i²`), implementing [alperin2006, eq. (1)].
  - `Symeq.equations_of : nvars:int -> stream:param_stream -> Combo.t -> Mpoly.t list` — the polynomial system (denominators cleared) for a combination.

- [ ] **Step 1: Write the failing tests**

`test_symeq.ml` — three groups:

```ocaml
(* 1. Reflection correctness: specialize fold-line vars to a concrete line and
   compare against Beloch's exact geometry. Line (X,Y)=(0,-1/2) is y=2, i.e.
   0·x + (-1/2)·y + 1 = 0. Reflecting (3,5) across y=2 gives (3,-1). *)
let test_reflect_matches_geom () =
  let num_x, num_y, den = Symeq.reflect_point_raw ~nvars:2 ~fold:0 (q "3", q "5") in
  let at p = Mpoly.specialize p [| q "0"; q "-1/2" |] in
  Alcotest.(check bool) "x" true Q.(equal (at num_x / at den) (q "3"));
  Alcotest.(check bool) "y" true Q.(equal (at num_y / at den) (q "-1"))

(* 2. Equation counts per alignment match the Task-2 table, for all 17 symbols. *)
let test_equation_counts_symbolic () =
  List.iter
    (fun a ->
      let eqs = Symeq.equations_of ~nvars:4 ~stream:Symeq.stream_a [ a ] in
      Alcotest.(check int)
        (Alignment.combo_to_symbol [ a ])
        (Alignment.equations a) (List.length eqs))
    Alignment.all_twofold

(* 3. Variable occurrence: AL2a's equation mentions only fold-a vars. *)
let test_var_occurrence () =
  let eqs = Symeq.equations_of ~nvars:4 ~stream:Symeq.stream_a [ al AL2 A ] in
  List.iter
    (fun e ->
      Alcotest.(check int) "no x2" 0 (Mpoly.degree_in e 2);
      Alcotest.(check int) "no y2" 0 (Mpoly.degree_in e 3))
    eqs
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement**

Formulas, all with denominators cleared at the end (`equations_of` multiplies through; denominators `x_i²+y_i²` and the folded-line denominator are generically nonzero — record this as a code comment with the citation):

- Folded point of given `(px,py)` across fold `i` [alperin2006, eq. (1)]:
  `num_x = px·(y_i² − x_i²) − 2·x_i·(1 + py·y_i)`, `num_y = py·(x_i² − y_i²) − 2·y_i·(1 + px·x_i)`, `den = x_i² + y_i²`.
- Folded line: do **not** transcribe eq. (2) from the OCR text (garbled). Derive it: a line `(XL,YL)` folded across fold `i` is the line through the folded images of two sample points of `(XL,YL)`; implement `line_through_two_rat2` on numerator/denominator pairs, or equivalently derive the closed form once on paper and verify with the involution test below. Add test: folding any line twice across the same fold returns it (`F∘F = id`), specialized at 3 random rational fold lines.
- Per-alignment equations (fold indices from suffix; given objects pulled from the stream):
  - AL1 (`F_a(L_b) ↔ L_b`): fold b's line is invariant under fold a ⇔ perpendicularity ⇔ `x_a·x_b + y_a·y_b = 0` — 1 eq. (Justify in comment: reflection fixes a line ≠ axis iff the line is perpendicular to the axis.)
  - AL2a (`F_a(L) ↔ L`): `x_a·X_L + y_a·Y_L = 0` — 1 eq (same lemma, given line).
  - AL3a (`L_a ↔ P`): `x_a·px + y_a·py + 1 = 0` — 1 eq.
  - AL4a (`F_a(L) ↔ L_b`): folded given line equals fold line b, componentwise on the `(X,Y)` representation — 2 eqs (cross-multiplied).
  - AL5a (`F_a(P) ↔ L_b`): folded point lies on fold line b: `x_b·num_x + y_b·num_y + den = 0` — 1 eq.
  - AL6a (`F_a(P) ↔ L`): `X_L·num_x + Y_L·num_y + den = 0` — 1 eq.
  - AL7a (`F_a(P) ↔ F_b(L)`): incidence of point folded by a with line folded by b — 1 eq (clear both denominators).
  - AL8 (`F_a(P₁) ↔ F_b(P₂)`): componentwise equality — 2 eqs.
  - AL9 (`F_a(L₁) ↔ F_b(L₂)`): componentwise equality of folded lines — 2 eqs.
  - AL10a (`F_b(P_{L_a,L₁}) ↔ L₂`): virtual point = intersection of fold line a with given line L₁ (rational in `x_a,y_a`), folded by b, incident with L₂ — 1 eq [alperin2006, §4, AL10 discussion].

- [ ] **Step 4: Run to verify pass.** All three groups + involution.

- [ ] **Step 5: Commit** — `git commit -m "feat(multifold): symbolic alignment equations over Mpoly"`

---

### Task 7: msolve subprocess driver

**Files:**
- Create: `packages/multifold/lib/msolve.ml`, `.mli`
- Create: `packages/multifold/tests/test_msolve.ml` (+ dune stanza, `(libraries multifold beloch alcotest unix)`)
- Modify: `flake.nix` (devShell + checks inputs: add `msolve`)

**Interfaces:**
- Consumes: `Mpoly.t` systems, variable count.
- **Saturation obligation (from Task 6 review):** clearing denominators enlarges the zero set by spurious loci where an image leaves the Def. 2 chart (e.g. AL9's two folded-line denominators vanish on a 2-dimensional locus where both equations hold vacuously). The solver call must exclude these: `Symeq.equations_of` also returns the list of cleared denominator polynomials, and the msolve system is extended by one Rabinowitsch variable `w` with the extra equation `w · (∏ denominators) − 1 = 0` (nvars+1 variables). This removes every spurious solution exactly; classification then proceeds on the extended system.
- Produces: `Msolve.classify : nvars:int -> denoms:Mpoly.t list -> Mpoly.t list -> [ \`Zero_dim of { count : int; multiplicity_free : bool } | \`Positive_dim | \`No_solutions ]` — dimension of the ideal's variety; when 0-dimensional, `count` = degree of the eliminant f₀ from msolve's rational parametrization (= number of DISTINCT complex solutions; msolve's RUR is computed on the radical, so f₀ is squarefree by construction — an earlier gcd(f₀,f₀′) design was a tautology, discovered empirically in Task 7), and `multiplicity_free` = (msolve's reported multiplicity-weighted ideal degree = deg f₀). Rationale: weighted degree > deg f₀ means some solution is degenerate/multiple — the exact analogue of A-L's Jacobian-singularity rejection [alperin2006, §4 step 5], without numerics. This distinction is load-bearing for k=3, where no 489-style oracle exists to catch an over-accepting filter.

- [ ] **Step 1: Add msolve to the flake**

In `flake.nix`, add `pkgs.msolve` to `devShell.buildInputs` and to the check derivation's `nativeCheckInputs`. Verify availability: `nix develop -c msolve -h | head -3` — expected: usage text. If `msolve` is missing from nixpkgs on this channel, STOP and surface to the user (fallback candidates: `pkgs.singular`; do not silently switch).

- [ ] **Step 2: Write the failing tests**

```ocaml
(* x² − 2 = 0, y − 1 = 0  → zero-dimensional, 2 solutions *)
let test_zero_dim () =
  let x = Mpoly.var ~nvars:2 0 and y = Mpoly.var ~nvars:2 1 in
  let sys = [ Mpoly.(sub (mul x x) (const ~nvars:2 (q "2"))); Mpoly.(sub y (const ~nvars:2 (q "1"))) ] in
  match Msolve.classify ~nvars:2 sys with
  | `Zero_dim n -> Alcotest.(check int) "2 sols" 2 n
  | _ -> Alcotest.fail "expected zero-dimensional"

(* x + y = 0 alone in 2 vars → positive-dimensional *)
let test_positive_dim () = ...  (* analogous *)

(* x = 0, x = 1 → empty *)
let test_empty () = ...  (* expects `No_solutions *)
```

- [ ] **Step 3: Run to verify failure.**

- [ ] **Step 4: Implement**

`msolve.ml`: write the system to a temp file in msolve's input format —
line 1: comma-separated variable names (`x0,y0,x1,y1`), line 2: characteristic `0`, then one polynomial per line, comma-terminated except the last, in standard `+`/`-`/`*`/`^` syntax (Mpoly → string printer needed; write `Msolve.poly_to_string`). Run `msolve -f in.ms -o out.ms` via `Unix.create_process` (imitate `packages/core/bin/main.ml:120`), wait, parse `out.ms`: msolve emits `[-1]:` for no solutions, a dimension marker for positive-dimensional ideals, and for 0-dim a rational-parametrization block whose eliminant degree = solution count. Parse defensively; on unparseable output raise with the raw text included. Temp files under `Filename.temp_file "multifold" ".ms"`, cleaned in all paths.

**Note for the implementer:** verify the exact output syntax against the installed msolve version's `-h`/README (`nix develop -c msolve -h`) before writing the parser; pin what you find as parser unit tests with literal output samples captured from the three test systems.

- [ ] **Step 5: Run to verify pass.**

- [ ] **Step 6: Commit** — `git commit -m "feat(multifold): msolve subprocess driver + flake dep"`

---

### Task 8: Pipeline — k=1 end-to-end, then k=2 without AL10 → 203

**Files:**
- Create: `packages/multifold/lib/pipeline.ml`, `.mli`
- Create: `packages/multifold/tests/test_pipeline.ml` (+ dune stanza)

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `Pipeline.run_twofold : with_al10:bool -> stream:Symeq.param_stream -> string list` — candidate combos → equations → strict filter (keep `\`Zero_dim { count; multiplicity_free }` with `count ≥ 1 && multiplicity_free`) → canonical symbols, sorted.
  - `Pipeline.run_twofold_lax : ...` — same but ignoring `multiplicity_free`. The pipeline logs the set difference (combos accepted lax-only) to stderr and Task 10's report records it: at k=2 this measured difference is the evidence for which filter semantics A-L's 489 actually corresponds to, and it must be known before trusting any k=3 count.
  - `Pipeline.run_onefold : unit -> string list` — same filter over the one-fold generator on 2 variables (validates algebra + msolve on ground truth: still exactly 7).

- [ ] **Step 1: Write the failing tests**

```ocaml
let test_onefold_pipeline () =
  Alcotest.(check int) "7 survive the algebraic filter" 7
    (List.length (Pipeline.run_onefold ()))

let test_twofold_no_al10 () =
  let syms = Pipeline.run_twofold ~with_al10:false ~stream:Symeq.stream_a in
  Alcotest.(check int) "203" 203 (List.length syms);
  (* symbol-by-symbol against fixture, restricted to symbols without AL10 *)
  let expected =
    Test_fixture.fixture ()
    |> List.filter (fun s ->
           match Alignment.combo_of_symbol s with
           | Some c -> not (List.exists (fun (a : Alignment.t) -> a.kind = AL10) c)
           | None -> false)
    |> List.sort String.compare
  in
  Alcotest.(check (list string)) "exact symbol set" expected syms
```

Mark the k=2 test `` `Slow `` (alcotest quick/slow distinction) — it shells out to msolve a few thousand times. Quick suite stays fast.

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement `pipeline.ml`** — thin composition, ~40 lines. `with_al10:false` filters candidates containing AL10 before the expensive step. Log progress to stderr every 100 combos (count, kept-so-far) so long runs are observable.

- [ ] **Step 4: Run k=1, then k=2**

Run: `dune test packages/multifold/tests/ 2>&1 | tail -20` (quick), then the slow suite: `ALCOTEST_QUICK_TESTS=0 dune exec packages/multifold/tests/test_pipeline.exe -- -e` (check alcotest CLI for running slow tests; adjust flag).
Expected: k=1 → 7. k=2/no-AL10 → **203, and the exact symbol set**.

**If 203 fails:** follow the Global Constraints mismatch protocol. The fixture diff tells you which symbols we have extra/missing; classify the difference (separability? a self-alignment eq count? an msolve `Zero_dim 0` edge?), re-run the disputed combos with `stream_b` to rule out parameter non-genericity, and write the finding to `notes/2026-XX-XX-multifold-203-mismatch.md` before changing any rule. Never special-case individual symbols to force the count.

- [ ] **Step 5: Commit** — `git commit -m "feat(multifold): enumeration pipeline reproduces 203 (k=2, no AL10)"`

---

### Task 9: AL10 equations live → 489

**Files:**
- Modify: `packages/multifold/lib/symeq.ml` (AL10 already implemented in Task 6 — this task turns it on end-to-end), `packages/multifold/tests/test_pipeline.ml`

- [ ] **Step 1: Write the failing test**

```ocaml
let test_twofold_full () =
  let syms = Pipeline.run_twofold ~with_al10:true ~stream:Symeq.stream_a in
  Alcotest.(check int) "489" 489 (List.length syms);
  Alcotest.(check (list string)) "exact symbol set"
    (List.sort String.compare (Test_fixture.fixture ())) syms
```

(`` `Slow ``.)

- [ ] **Step 2: Run to verify current state** — with AL10 candidates flowing, expect either PASS or a fixture diff; treat a diff per the mismatch protocol (AL10's virtual point is the most delicate equation — the a/b variety semantics [alperin2006, §4] is the first thing to re-read on failure).

- [ ] **Step 3: Cross-validate with the second parameter stream**

Add (slow) test: `run_twofold ~with_al10:true ~stream:Symeq.stream_b` returns the identical symbol set. Genericity guard.

- [ ] **Step 4: Commit** — `git commit -m "feat(multifold): full two-fold enumeration reproduces 489"`

---

### Task 10: Results artifact + notes + upper-bound milestone

**Files:**
- Create: `packages/multifold/data/twofold-axioms.txt` (generated: the 489 canonical symbols, one per line, with generation header)
- Create: `notes/2026-XX-XX-multifold-phase1-reproduction.md` (fill actual date)
- Modify: `packages/multifold/lib/pipeline.ml` (a `dune exec`-able `tools/report.ml` or a `Pipeline.report` entry point printing: raw candidate counts k=1/k=2, post-separability counts, post-filter counts 7/203/489, and the same raw-candidate computation run at k=3 alphabet size TBD — printing only what the current generator can say: the k=2 numbers; the k=3 alphabet is Phase 2 work and explicitly out of scope here)

- [ ] **Step 1: Generate the artifact** — `dune exec packages/multifold/tools/report.exe > packages/multifold/data/twofold-axioms.txt`; verify `wc -l` matches 489 + header lines.

- [ ] **Step 2: Write the notes entry** — what was reproduced (7/203/489, symbol-exact), the equation-count table with its per-symbol oracle, every deviation/judgment call made vs. the paper (separability structural rule, AL1/AL2 perpendicularity lemma, derived folded-line formula, msolve as the 0-dim filter vs. A-L's Jacobian), open questions carried to Phase 2 (3-fold alphabet derivation; nested reflections decision; Jacobian-at-solutions multiplicity semantics if any mismatch was seen). Cite `[alperin2006]` by section throughout.

- [ ] **Step 3: Run the full test suite** — `dune test` (whole repo) — expected: all green, including core's existing tests (proves the new package didn't disturb core). Then `dune fmt`.

- [ ] **Step 4: Commit** — `git commit -m "docs(multifold): phase-1 reproduction artifact + notes"`

---

## Self-Review Notes

- **Spec coverage:** Phase 1 scope = "Two-fold machinery. Formalize alignments; enumerate; reproduce 489" + early upper-bound milestone. Tasks 2–4 formalize + enumerate, 8–9 reproduce both counts, Task 4 Step 4 + Task 10 record the raw-count upper-bound data. The k=3 alphabet is explicitly out (Phase 2), matching the spec's phase boundary.
- **Known judgment calls encoded:** structural separability (Def. 10 interpreted via fold-mention partition), AL1/AL2 as perpendicularity (1 eq), folded-line formula derived not transcribed (OCR), msolve replaces A-L's Jacobian test (difference documented; multiplicity edge in the mismatch protocol).
- **Type consistency:** `Alignment.t` record shape, `Combo.t = Alignment.t list`, `Mpoly` var indexing (x_i=2i, y_i=2i+1), `classify` polymorphic variant — used consistently across tasks; test helper `Test_fixture.fixture` introduced in Task 4 and referenced in 8–9.
- **Honest risk:** msolve input/output format is pinned by the implementer against the installed version (Task 7 note) rather than transcribed here from memory — deliberate, per the repo's don't-guess rule.
