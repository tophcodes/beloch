# flatten generalizes collapse — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename `collapse` → `flatten`, make it bindable, adopt parenthesised-juxtaposition item notation, and add a single-emergent-ray *derive* mode that solves the flat-foldability-forced crease no Huzita axiom constructs.

**Architecture:** `flatten` is one write-verb with two modes chosen by operand set. Validate mode = today's `collapse` kernel verbatim. Derive mode = a new `Flatten.derive` that, given an **odd** set of fixed rays sharing vertex O plus a `toward` side, constructs the one emergent ray by composing the known reflections and inverting (their product `P` is a reflection whose axis is the emergent crease), then hands the completed ray set to the existing `Collapse.collapse` kernel. Everything downstream of a complete ray set is reused unchanged.

**Tech Stack:** OCaml + dune; exact real-algebraic kernel (`lib/num.ml`, qqbar/FLINT, ADR 0012/0013); menhir parser (`lib/parser.mly`); the shipped collapse kernel (`lib/collapse.ml`) and isometry/geometry libs (`lib/isometry.ml`, `lib/geom.ml`).

## Global Constraints

- **Exact-only kernel** — no floats anywhere; all geometry is `Num.t` (rationals/algebraics). Verified via `Geom.point_equal`, `Num.compare`, etc.
- **Refs-grounded math** — the derive rests on Kawasaki [hull2020, §5.3, Thm 5.17]; `closure_ok` (reflection product = identity) IS Kawasaki. Do not introduce origami-math claims from memory.
- **Conventional commits** (personal repo): `feat(flatten): …`, `refactor(flatten): …`, `test(flatten): …`, `docs(spec): …`.
- **Spec of record:** `docs/superpowers/specs/2026-07-15-flatten-generalizes-collapse-design.md`.
- **`#[…]` stays constructed-space** — the derive surface uses only constructed-space ray-naming (`--ba \ .a`). The generative `#{…}` selector and `stays` sugar are **out of scope** (issue #46).

---

## ⚠️ Gate: Task 1 (math spike) precedes all derive tasks

The exact emergent-ray algorithm and the true v1 surface depend on one open
fact: **for a concrete swivel rabbit, how many emergent creases does the moving
flap force, and is the given ray set odd?** Task 1 resolves this empirically
(self-verifying — the oracle is `Collapse.closure_ok` + no self-intersection on
the completed set, so no pre-known answer is required). Tasks 5–7 (derive
kernel/surface/example) are finalised against Task 1's finding. Tasks 2–4
(rename, notation, binding) are independent of the math and proceed regardless.

---

## File structure

| File | Responsibility | Change |
|---|---|---|
| `lib/lexer.ml` | keyword table | `COLLAPSE`→`FLATTEN` token (`:31`) |
| `lib/parser.mly` | grammar | rename rules; `and`→paren-juxtaposition items; add `toward` + name slot |
| `lib/ast.ml` | AST | `Collapse`→`Flatten`, add `string option` name + `toward` operand (`:120`) |
| `lib/eval.ml` | evaluator | rename handler (`:1722`); bind result; dispatch validate vs derive |
| `lib/collapse.ml` | validate kernel + reusable machinery | unchanged internally (module keeps name); add nothing |
| `lib/flatten.ml` | **new** — `Flatten.derive` (emergent-ray solver) | create |
| `tests/test_collapse.ml` | validate-mode tests | keyword/notation updates |
| `tests/test_flatten.ml` | **new** — derive + binding tests | create |
| `examples/bases/rabbit-ear.bel`, `waterbomb.bel` | showcase | keyword + paren notation |
| `spec/SPECIFICATION.md` | language spec | §4.9/§4.10 rename + derive |

---

## Task 1: Math spike — resolve the emergent-ray algorithm (GATE)

**Files:**
- Create: `lib/flatten.ml`
- Test: `tests/test_flatten.ml`
- Note: append findings to the spec's `## Slicing` under a `### Spike result` line.

**Interfaces:**
- Consumes: `Collapse.elem` (`{cid; ea; eb; valley}`), `Collapse.closure_ok`, `Collapse.sort_ccw`, `Collapse.far_of`, `Isometry.{reflect_across_line, compose, inverse, det_sign, identity, apply_point}`, `Geom.{line_through, point_equal, side_of_line}`, `Num.t`.
- Produces: `Flatten.derive : Geom.point -> fixed:(Geom.point * Collapse.elem) list -> toward:Geom.point -> (Geom.line, string) result` — the emergent crease *line* through O (later tasks turn it into an elem + segment).

**Hypothesis to verify (the single-emergent, odd-given case):** with fixed rays sorted CCW around O, for each angular gap insert the emergent ray; the product of the other reflections `P` must satisfy `R_emergent = P⁻¹`; `P⁻¹` is a reflection (det −1) iff the given count is odd; its axis (a line through O) is the emergent crease; keep only insertions where the axis direction actually falls in that gap; pick among survivors by `toward` side.

**Ground-truth oracle (Toph's rabbit MV — the spike MUST reproduce it):**
- given folding rays (odd, 3): `--ba \ .a` → **V**, `--bb \ .b` → **V**, `--v \ .m` (lower v) → **V**
- derived: `--ear` → **M**
- **not** a flatten element: `--v & .m` (upper v, the spine) stays **U** — it lies on the non-moving apex flap (spec §, "non-moving layers keep their flat mark").

This assignment also probes the anchor rule: the apex flap that stays is the **large/reflex** region held flat by the U spine, **not** a convex sector. If the spike can only produce this by treating the stayer as reflex-held-flat, update the design's "Anchor rule" accordingly and STOP to report before Tasks 5–7.

- [ ] **Step 1: Write the self-verifying failing test.** Build a concrete odd ray set from the rabbit — vertex O, the two corner hinges, and the spine (3 given rays) — omitting the ear; derive the ear; assert the completed 4-ray set closes flat.

```ocaml
(* tests/test_flatten.ml *)
let test_derive_rabbit_ear () =
  (* O and three fixed rays taken from examples/bases/rabbit-ear.bel geometry:
     hinges toward a=(0,0) and b=(1,0), spine toward m=(1/2,1). Coordinates
     built exactly with Num; O is their common vertex. Fill in from the running
     construction (dune exec on the .bel, or Eval) — do NOT hardcode the ear. *)
  let o = (* incenter, exact *) Rabbit_fixture.o in
  let fixed = Rabbit_fixture.three_rays in          (* (far, elem) list, len 3 *)
  match Flatten.derive o ~fixed ~toward:Rabbit_fixture.corner_c with
  | Error e -> Alcotest.failf "derive failed: %s" e
  | Ok ell ->
    (* oracle: adding the emergent ray closes Kawasaki exactly *)
    let ear = Rabbit_fixture.ray_on o ell in         (* elem on line ell *)
    let rays = Collapse.sort_ccw o (ear :: Rabbit_fixture.three_elems)
               |> Array.of_list in
    Alcotest.(check bool) "closes flat" true (Collapse.closure_ok o rays)
```

- [ ] **Step 2: Run it, verify it fails** (`Flatten` undefined).

Run: `dune test 2>&1 | head`
Expected: build error — `Unbound module Flatten`.

- [ ] **Step 3: Implement `Flatten.derive` per the hypothesis.**

```ocaml
(* lib/flatten.ml *)
(* Reflection axis of a reflection isometry [r] fixing O: for any probe p not on
   the axis, p and (r p) are mirror-symmetric across it, so (p + r p)/2 and O
   span the axis. Exact. *)
let reflection_axis (o : Geom.point) (r : Isometry.t) : Geom.line option =
  if Isometry.det_sign r >= 0 then None
  else
    let probe = { Geom.x = Num.add o.Geom.x Num.one; y = o.Geom.y } in
    let rp = Isometry.apply_point r probe in
    let mid = { Geom.x = Num.div (Num.add probe.Geom.x rp.Geom.x) (Num.of_int 2);
                y = Num.div (Num.add probe.Geom.y rp.Geom.y) (Num.of_int 2) } in
    if Geom.point_equal mid o then Some (Geom.line_through o probe)  (* probe on axis *)
    else Some (Geom.line_through o mid)

let derive (o : Geom.point) ~(fixed : (Geom.point * Collapse.elem) list)
    ~(toward : Geom.point) : (Geom.line, string) result =
  let rays = Collapse.sort_ccw o (List.map snd fixed) |> Array.of_list in
  let n = Array.length rays in
  if n land 1 = 0 then Error "flatten derives one crease from an odd ray set"
  else begin
    let refl far = Isometry.reflect_across_line (Geom.line_through o far) in
    (* candidate per insertion gap k: R_e = (prod_{i<k})^{-1} (prod_{i>=k})^{-1} *)
    let candidates = List.filter_map (fun k ->
      let before = ref Isometry.identity and after = ref Isometry.identity in
      Array.iteri (fun i (far, _) ->
        if i < k then before := Isometry.compose !before (refl far)
        else after := Isometry.compose !after (refl far)) rays;
      let re = Isometry.compose (Isometry.inverse !before) (Isometry.inverse !after) in
      match reflection_axis o re with
      | None -> None
      | Some ell ->
        (* consistency: axis must fall in gap k (between ray k-1 and ray k) *)
        if Flatten_geom.axis_in_gap o rays k ell then Some ell else None)
      (List.init n (fun k -> k)) in
    match candidates with
    | [] -> Error "vertex not flat-foldable toward that side"
    | cs ->
      (* pick by toward side of the swing axis; deterministic tie-break by CCW *)
      Ok (Flatten_geom.pick_toward o toward cs)
  end
```

*(`Flatten_geom.axis_in_gap` and `pick_toward` are small exact helpers written
alongside; `axis_in_gap` reuses `Geom.ccw_compare`, `pick_toward` reuses
`Geom.side_of_line` on the line O→toward. If the hypothesis is wrong, iterate
here until Step 4 passes — that is the spike.)*

- [ ] **Step 4: Run the test until it passes.**

Run: `dune test 2>&1 | tail`
Expected: PASS — `closes flat` is `true`.

- [ ] **Step 5: Record the finding.** Append to the spec: the confirmed ray count (odd-given → 1 emergent), whether the rabbit needs the spine as a third given ray, and thus the true v1 surface. If the rabbit turns out to force 2 emergent creases, STOP and report — the surface changes.

- [ ] **Step 6: Commit.**

```bash
git add lib/flatten.ml lib/flatten_geom.ml tests/test_flatten.ml docs/superpowers/specs/2026-07-15-flatten-generalizes-collapse-design.md
git commit -m "feat(flatten): emergent-ray derive spike (single-crease, odd ray set)"
```

---

## Task 2: Rename `collapse` → `flatten` (validate mode intact)

**Files:**
- Modify: `lib/lexer.ml:31`, `lib/parser.mly:16,62-80,208-225`, `lib/ast.ml:120-125`, `lib/eval.ml:1722`
- Test: `tests/test_collapse.ml`

**Interfaces:**
- Produces: `Ast.Flatten of collapse_elem list * (flap_arg * flap_arg) list * flap_arg option * Error.span` (name slot + toward added in Task 4/5). Token `FLATTEN`. Keyword `flatten`.

- [ ] **Step 1: Update the existing validate-mode test to the new keyword.** In `tests/test_collapse.ml`, change one canonical case's source from `collapse …` to `flatten …` (keep `& .a and …` for now — notation changes in Task 3).

- [ ] **Step 2: Run it, verify it fails** (`flatten` lexes to nothing / parse error).

Run: `dune test 2>&1 | grep -i flatten | head`
Expected: FAIL — unexpected token.

- [ ] **Step 3: Rename across lexer/parser/ast/eval.** `"collapse" -> FLATTEN` in `lib/lexer.ml`; `%token FLATTEN` and the `FLATTEN collapse_items` rule head in `lib/parser.mly`; `Collapse`→`Flatten` constructor in `lib/ast.ml` and its match arm in `lib/eval.ml`. Internal module `Collapse` (in `lib/collapse.ml`) keeps its name — only the *language keyword* changes.

- [ ] **Step 4: Run the full suite, verify green.**

Run: `dune test`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/lexer.ml lib/parser.mly lib/ast.ml lib/eval.ml tests/test_collapse.ml
git commit -m "refactor(flatten): rename collapse keyword to flatten"
```

---

## Task 3: Parenthesised-juxtaposition item notation

**Files:**
- Modify: `lib/parser.mly:208-225` (collapse_items/collapse_elem)
- Test: `tests/test_parse.ml`

**Interfaces:**
- Consumes: existing `collapse_elem`, `over`, `standing` items.
- Produces: item list parsed from whitespace-separated parenthesised items; `AND` no longer used in the flatten rule (still used by axiom-6 map).

- [ ] **Step 1: Write the failing parse test** for the paren form.

```ocaml
(* tests/test_parse.ml *)
let test_flatten_paren_items () =
  let src = "paper square\nflatten (--ac & .a) (--ac & .c) (--bd & .b) (--bd & .d)" in
  match Parse.program src with
  | Ok _ -> ()
  | Error e -> Alcotest.failf "paren items should parse: %s" e
```

- [ ] **Step 2: Run it, verify it fails.**

Run: `dune test 2>&1 | grep -i paren`
Expected: FAIL — parse error at `(`.

- [ ] **Step 3: Change the item list to juxtaposition.** In `lib/parser.mly`, replace `collapse_item (AND collapse_item)*` with a whitespace-separated `collapse_item+`, where each `collapse_item` is either a parenthesised group `LPAREN … RPAREN` or a bare single operand. Keep `over`/`standing` recognisable as parenthesised items. Leave the axiom-6 `AND` rule untouched.

- [ ] **Step 4: Run parse + full suite green.**

Run: `dune test`
Expected: PASS (Task 2's `flatten … and …` test is updated to paren form here).

- [ ] **Step 5: Commit.**

```bash
git add lib/parser.mly tests/test_parse.ml tests/test_collapse.ml
git commit -m "feat(flatten): parenthesised-juxtaposition item list (drop and)"
```

---

## Task 4: AST name slot + bindable validate mode

**Files:**
- Modify: `lib/ast.ml:120` (add `string option`), `lib/parser.mly` (bind rule `line_operand EQ flatten_stmt`), `lib/eval.ml:1722-1832` (return a bound bundle)
- Test: `tests/test_flatten.ml`

**Interfaces:**
- Produces: `--r = flatten …` binds `--r` to the bundle of the rays this flatten acted on (validate mode: the given rays). Return plumbing reused by Task 6 for the emergent bundle.

- [ ] **Step 1: Write the failing binding test.**

```ocaml
let test_flatten_bind_validate () =
  let src = "paper square\n\
    mark --v = map .a onto .b\n\
    ... (a full validate-mode rabbit) ...\n\
    --r = flatten (--ba & .a) (--bb & .b) (--v & .m) (--v & --ab mountain)" in
  match Eval.run src with
  | Ok env -> Alcotest.(check bool) "--r bound" true (Env.has_bundle env "--r")
  | Error e -> Alcotest.failf "bind failed: %s" e
```

- [ ] **Step 2: Run it, verify it fails** (grammar rejects `--r = flatten`).

Run: `dune test 2>&1 | grep -i bind`
Expected: FAIL.

- [ ] **Step 3: Add the name slot + bind path.** Add `string option` to `Ast.Flatten`; add the `line_operand EQ` production feeding the flatten statement; in `lib/eval.ml`, on success bind the name to a bundle of the acted-on ray segments (mirror how `Fold`/`Mark` bind, `lib/ast.ml:101,105`).

- [ ] **Step 4: Run green.**

Run: `dune test`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/ast.ml lib/parser.mly lib/eval.ml tests/test_flatten.ml
git commit -m "feat(flatten): bindable statement + AST name slot"
```

---

## Task 5: Derive surface — `toward` operand + ray-naming trigger *(finalise against Task 1)*

**Files:**
- Modify: `lib/parser.mly` (add trailing `TOWARD point_operand` to the flatten rule), `lib/ast.ml` (add `toward` operand to `Flatten`), `lib/eval.ml` (dispatch: `toward` present → call `Flatten.derive` with the named rays as `fixed`)
- Test: `tests/test_flatten.ml`

**Interfaces:**
- Consumes: `Flatten.derive` (Task 1). The named hinge rays resolve to `Collapse.elem`s via the existing `resolve_elem` (`lib/eval.ml:1741-1790`); pass them as `~fixed`.
- Produces: derive-mode `flatten` that materialises the emergent crease and folds via `Collapse.collapse` on the completed set.

- [ ] **Step 1: Write the failing end-to-end derive test** using the odd-given surface Task 1 confirmed (e.g. two hinges + spine, `toward .c`), asserting the fold reaches a flat state and the emergent crease exists.

```ocaml
let test_flatten_derive_e2e () =
  let src = "paper square\n… construction …\n\
    --ear = flatten (--ba \\ .a) (--bb \\ .b) (--v & .m) toward .c" in
  match Eval.run src with
  | Ok env ->
    Alcotest.(check bool) "flat" true (Fold_state.is_flat (Env.state env));
    Alcotest.(check bool) "--ear bound" true (Env.has_bundle env "--ear")
  | Error e -> Alcotest.failf "%s" e
```

- [ ] **Step 2: Run it, verify it fails.**

Run: `dune test 2>&1 | grep -i derive`
Expected: FAIL — `toward` unexpected / derive not wired.

- [ ] **Step 3: Wire `toward` + dispatch.** Add `TOWARD point_operand` (trailing, not `and`-joined) to the flatten rule and a `toward` field to `Ast.Flatten`. In `lib/eval.ml`, when `toward` is present: resolve the named rays, call `Flatten.derive o ~fixed ~toward`, materialise the returned line as a crease segment, append its `Collapse.elem`, then call `Collapse.collapse` on the full set. Without `toward`, keep the validate path.

- [ ] **Step 4: Run green.**

Run: `dune test`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/parser.mly lib/ast.ml lib/eval.ml tests/test_flatten.ml
git commit -m "feat(flatten): derive mode — toward operand + emergent-crease wiring"
```

---

## Task 6: Emergent-crease return + tip point

**Files:**
- Modify: `lib/eval.ml` (bind the emergent bundle; expose the tip), `lib/flatten.ml` (return the tip)
- Test: `tests/test_flatten.ml`

**Interfaces:**
- Produces: `--ear` binds the emergent crease bundle; the tip point (emergent crease ∩ base) is selectable, e.g. `.tip = .[--ear, --ab]`.

- [ ] **Step 1: Write the failing tip test.**

```ocaml
let test_flatten_tip () =
  let src = "paper square\n… derive …\n\
    --ear = flatten (--ba \\ .a) (--bb \\ .b) (--v & .m) toward .c\n\
    .tip = .[--ear, --ab]" in
  match Eval.run src with
  | Ok env -> Alcotest.(check bool) ".tip resolves" true (Env.has_point env ".tip")
  | Error e -> Alcotest.failf "%s" e
```

- [ ] **Step 2: Run it, verify it fails.**

Run: `dune test 2>&1 | grep -i tip`
Expected: FAIL — `--ear` not a selectable bundle yet.

- [ ] **Step 3: Bind the emergent bundle + tip.** On derive success, bind the name to the emergent crease segment(s) (not the given rays) so `.[--ear, --ab]` meets them.

- [ ] **Step 4: Run green.**

Run: `dune test`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/eval.ml lib/flatten.ml tests/test_flatten.ml
git commit -m "feat(flatten): bind emergent crease bundle + expose tip point"
```

---

## Task 7: Migrate examples + spec

**Files:**
- Modify: `examples/bases/rabbit-ear.bel`, `examples/bases/waterbomb.bel`, `spec/SPECIFICATION.md` §4.9/§4.10
- Create: `examples/bases/swivel-rabbit.bel` (derive-mode showcase, per Task 1's surface)
- Test: the example-corpus test that folds every `.bel` (`tests/test_e2e.ml` / whatever runs examples)

- [ ] **Step 1: Run the example suite to confirm current green baseline.**

Run: `dune test 2>&1 | tail`
Expected: PASS (before edits).

- [ ] **Step 2: Migrate both examples** to `flatten` + paren notation (keyword + `( … )` items, drop `and`).

- [ ] **Step 3: Add `swivel-rabbit.bel`** — the derive-mode example binding `--ear`, using the odd-given surface Task 1 confirmed. It must be load-bearing (the derived crease is not axiom-constructible).

- [ ] **Step 4: Update spec §4.9/§4.10** — rename, paren notation, derive mode, the errors table, and a note that `#{…}`/`stays` are deferred (issue #46).

- [ ] **Step 5: Run the example suite green.**

Run: `dune test`
Expected: PASS — all examples fold, including `swivel-rabbit.bel`.

- [ ] **Step 6: Commit.**

```bash
git add examples/bases/*.bel spec/SPECIFICATION.md
git commit -m "docs(spec): migrate examples + spec to flatten; add swivel-rabbit derive example"
```

---

## Self-review notes

- **Spec coverage:** rename (T2), paren notation (T3), bindable (T4), derive kernel (T1) + surface (T5) + tip (T6), migration (T7), `#{…}`/`stays` explicitly out (issue #46). Validate mode = untouched `Collapse.collapse`. Multi-emergent + `onto`/petal + `standing` remain deferred per spec.
- **Gate risk:** if Task 1 finds the rabbit forces 2 emergent creases, Tasks 5–7's surface changes — Task 1 Step 5 says STOP and report. This is the one place the plan bends to an empirical result.
- **Type consistency:** `Flatten.derive : point -> fixed:(point*elem) list -> toward:point -> (line, string) result` is used identically in T1 and T5. `Collapse.{closure_ok, sort_ccw, far_of, elem}` names match `lib/collapse.ml`. Verify `Env`/`Fold_state` helper names (`has_bundle`, `has_point`, `is_flat`) against the actual test harness before use; substitute the real accessors if they differ.
