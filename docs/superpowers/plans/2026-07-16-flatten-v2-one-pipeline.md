# flatten V2 one-pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace flatten's validate/derive mode split with one solver pipeline: hard constraints in `()` filter the realization space, `{toward .p}` selects from it, M/V is derived (bare element = unconstrained, `valley` joins `mountain` as a marker).

**Architecture:** Spec `docs/superpowers/specs/2026-07-16-flatten-derive-v2-design.md` is normative. Surface: `{toward}` becomes an item, trailing `toward` dies, AST element direction becomes a tri-state constraint. Kernel: `collapse_all` enumerates distinct-signature realizations; old `collapse` becomes a wrapper preserving its error strings. Evaluator: enumerate (emergent-ray candidate × Maekawa-consistent M/V pattern) → `collapse_all` → tier rule → |S| decision → area-weighted moved-material centroid metric for `{toward}`.

**Tech Stack:** OCaml (menhir parser, alcotest), exact `Num`; branch `feat/flatten-opposite-ray` in worktree `/home/toph/Projects/beloch-flatten-fix` (stacked on the fold-state rewrite; 364660f + spec commits present).

## Global Constraints

- Verify `git branch --show-current` = `feat/flatten-opposite-ray` before every commit. Build/test: `direnv exec /home/toph/Projects/beloch-flatten-fix dune build` / `… dune test`.
- Baseline suite state: all green except ONE documented main-side failure (`fold_state 14` example-scan). That exact state must hold after every task.
- **swivel-rabbit golden is the regression anchor**: `tests/golden/bases/swivel-rabbit.fold` must stay BYTE-IDENTICAL through every task. If the V2 metric picks a different realization for `{toward .c}`, STOP and report — never regenerate.
- Exact arithmetic only (`Num`); no floats.
- Old error strings that survive (`e_count`, `e_no_vertex`, `e_midpaper`, `e_dup_ray`, `e_kawasaki`, `e_maekawa`, `e_selfint`, `e_contra`, `e_ambig`, `e_out_of_paper`, `e_toward_ambiguous`) stay byte-identical.
- Redundancy is never an error (a `{toward}` on a |S|=1 statement is legal and ignored).

---

### Task 1: surface — `valley` marker, `{toward}` item, tri-state AST, corpus migration

**Files:**
- Modify: `lib/lexer.ml` (keyword table), `lib/parser.mly`, `lib/ast.ml`, `lib/eval.ml` (mechanical follow-through only), `lib/diagnostic.ml`/LSP hints only if they pattern-match the changed AST (grep `cdir`).
- Modify: `examples/bases/swivel-rabbit.bel`, `tests/cases/**` (flatten cases), delete `examples/bases/waterbomb.bel` + `tests/golden/bases/waterbomb.fold`.
- Test: `tests/test_parse.ml`.

**Interfaces:**
- Produces (Tasks 3–4 rely on): `Ast.mv_constraint = MvFree | MvMountain | MvValley`; `Ast.collapse_elem = { cline : line_operand; cdir : mv_constraint }`; `Ast.Flatten` unchanged shape otherwise (its `point_operand option` toward slot now filled from the `{toward …}` item).

- [ ] **Step 1: failing parse tests** — add to `tests/test_parse.ml` (mirror its existing assertion style; read the file first):
  - `flatten (--a & .p) (--b & .q valley) (--c & .r mountain) {toward .s}` parses; elem cdirs = [MvFree; MvValley; MvMountain]; toward = Some .s.
  - `{toward .s}` in any item position (first item) parses identically.
  - duplicate `{toward}` → parse error `only one {toward} per flatten`.
  - old trailing `toward .s` (unparenthesised, after items) → syntax error.
- [ ] **Step 2: run — expect failures** (`dune build` unbound constructor / parse mismatch).
- [ ] **Step 3: implement.**
  - `lib/lexer.ml`: add `| "valley" -> VALLEY` to the keyword table; declare the token in `parser.mly` (`%token VALLEY`).
  - `lib/ast.ml`: `type mv_constraint = MvFree | MvMountain | MvValley`; `collapse_elem.cdir : mv_constraint`. Delete `direction` if flatten was its only consumer (grep first — fold's own valley/mountain flags are separate; if `direction` is shared, leave it and only change `cdir`'s type).
  - `lib/parser.mly`:
    ```
    (* mv constraint marker: bare = solver-assigned (V2) *)
    mv_opt:
      |          { MvFree }
      | MOUNTAIN { MvMountain }
      | VALLEY   { MvValley }

    collapse_item:
      | LPAREN collapse_item_inner RPAREN     { $2 }
      | LBRACE TOWARD point_operand RBRACE    { CToward $3 }

    collapse_item_inner:
      | line_operand mv_opt      { CElem { cline = $1; cdir = $2 } }
      | over_flap OVER over_flap { COver ($1, $3) }
      | STANDING flap_arg        { CStanding ($2, $loc) }
    ```
    Remove `flatten_toward_opt` and its uses; the statement builder collects at most one `CToward` from the item list into the existing toward slot (second occurrence → `Error.fail … "only one {toward} per flatten"`, matching the existing duplicate-`standing` parse-error mechanism — read how `CStanding` dedup works and mirror it).
  - `lib/eval.ml` mechanical follow-through ONLY (semantics unchanged this task): where elems are converted to `Collapse.elem`, map `MvValley -> true`, `MvMountain -> false`, `MvFree -> true (* TEMPORARY: V1 default-valley; Task 3 replaces this with solver enumeration *)`. This keeps every existing behavior and golden bit-identical until Task 3.
  - Corpus: `swivel-rabbit.bel`: `toward .c` → `{toward .c}` (same line, no line-count change — the golden's `beloch:source_line` fields depend on line numbers). `tests/cases/**`: same syntax migration for any flatten with trailing toward (grep `^flatten|= flatten`). Delete `examples/bases/waterbomb.bel` and `tests/golden/bases/waterbomb.fold` (spec: obsolete; golden runner discovers cases by directory scan, so deletion is clean — verify no other test names waterbomb).
- [ ] **Step 4: run** — parse tests pass; full `dune test` = baseline (swivel golden byte-identical; waterbomb gone from the golden run).
- [ ] **Step 5: commit** — `feat(flatten): {toward} item + valley marker + tri-state elem constraint (surface only)`.

---

### Task 2: kernel — `collapse_all`

**Files:**
- Modify: `lib/collapse.ml`
- Test: `tests/test_collapse.ml`

**Interfaces:**
- Produces: `Collapse.collapse_all : Fold_state.t -> elem list -> over:(int * int) list -> (Fold_state.t list, string) result` — every distinct-signature realization of the GIVEN concrete elems (elem stays `{ …; valley : bool }`; pattern enumeration is the evaluator's job, Task 3). `Collapse.collapse` (same signature as today) becomes a wrapper: `Ok [st] -> Ok st`, `Ok sts -> Error (e_ambig (List.length sts))`, `Error e -> Error e`.

- [ ] **Step 1: failing tests** — in `tests/test_collapse.ml` (reuse its `+`-vertex fixture):
  - the over-ambiguity fixture WITHOUT `over`: `collapse_all` returns `Ok` with length 4 (the count today's `e_ambig` names: "ambiguous stacking (4 orders)").
  - with `over` narrowing to one: `Ok [st]` and `st` equals (check_parity-style face/rel assertions or a representative table-position probe) the state `collapse` returns.
  - error passthrough: the `e_count` fixture → `collapse_all` = same `Error` string as `collapse`.
- [ ] **Step 2: run — expect unbound `collapse_all`.**
- [ ] **Step 3: implement.** Restructure the tail of the existing kernel: after the `over` filter and signature dedup, today's code takes the single distinct rank and errors on `_ :: _ :: _`. Instead: for EVERY distinct-signature rank, run the anchor selection (in-bounds proper anchor; if none for that rank, that realization is dropped — it has no front-up in-bounds realization) and build its final state. Collect: `[]` after all filtering → keep today's error precedence exactly (`e_selfint` when validity killed everything; `e_contra` when `over` did; `e_out_of_paper` when only the anchor guard did — preserve the existing decision points by keeping the early-exit structure and only replacing the final single-choice block). `collapse` wrapper as specified. Note: today's `e_ambig` fires BEFORE anchoring; the wrapper must preserve that observable order (ambiguity is decided on dedup count, not on anchored count) — implement `collapse_all` to return anchored states but compute the wrapper's `e_ambig` count from the dedup count; simplest faithful shape: `collapse_all` returns the anchored state per distinct rank and the wrapper errors when the DEDUP count (equal to the returned list length unless anchoring dropped some) exceeds 1 — verify against the existing over-test expectations and keep their strings green; if anchoring can drop a rank (making wrapper behavior differ from today), STOP and report rather than guessing.
- [ ] **Step 4: run** — new tests + all existing collapse tests green (old strings intact).
- [ ] **Step 5: commit** — `feat(collapse): collapse_all — enumerate distinct realizations; collapse becomes wrapper`.

---

### Task 3: evaluator — the one pipeline

**Files:**
- Modify: `lib/flatten.ml`, `lib/eval.ml`
- Test: `tests/test_flatten.ml`

**Interfaces:**
- Consumes: `Collapse.collapse_all` (Task 2), `Ast.mv_constraint` (Task 1), the 364660f helpers in eval (`try_ray`-style materialization, one pre-minted cid).
- Produces: `Flatten.candidates : Geom.point -> fixed:(Geom.point * Collapse.elem) list -> (Geom.line * Geom.point * [ `LineNew | `OppositeRay ]) list` — the candidate generator ONLY (same-direction filter, per-line dedup, tier tag). The old `derive` (feasible/toward logic) is DELETED from flatten.ml — selection now lives in eval. `e_infeasible`/`e_toward_ambiguous` strings move with their uses (keep them exported from `Flatten` so tests/messages stay stable).

**Normative pipeline (implements spec §"The model"):**

1. Resolve elems (unchanged) → rays with `mv_constraint`s. `n_given` rays; odd → candidates from `Flatten.candidates` (each = one emergent ray, constraint `MvFree`); even → one pseudo-candidate `None`.
2. Per candidate: materialize the emergent ray if any (existing helper: pre-minted cid, local state `st'`, no ctx mutation), producing the full ray list (given ++ emergent) over `st'`.
3. Enumerate M/V patterns over the full ray list: assignments `valley : bool` per ray such that (a) every `MvValley` ray is true, every `MvMountain` false, `MvFree` free; (b) Maekawa: `|#M − #V| = 2`. (Total rays is even here by construction.)
4. Per (candidate, pattern): `Collapse.collapse_all st' elems' ~over` → `Ok sts` contributes realizations `{ state; tier; candidate; pattern }`; `Error` contributes its message to an error pool (for |S| = 0 differentiation).
5. S = all realizations. Deciding set: tier-1 (`LineNew`, and the even-ray pseudo-candidate counts as tier-1) if non-empty, else tier-2.
6. |deciding| = 0 → error: if the pool contains `e_out_of_paper`, fail with it; else if every pattern failed closure, fail `"the derived crease does not close the vertex"` (odd case) / the pool's dominant kernel error (even case: prefer the first non-`e_selfint` message, else `e_selfint`) — preserve 364660f's differentiation behavior for the odd case verbatim.
7. |deciding| = 1 → commit it (toward, if present, is redundant — no error, no warning).
8. |deciding| > 1: no `{toward}` → `Error.fail span (Printf.sprintf "flatten is ambiguous: %d realizations; add {toward .p} to pick the fold direction" k)`. With `{toward .p}`: score each realization by the **area-weighted centroid of moved material**:
   - For each face `f` of the realization's state: paper polygon `P_f`, paper centroid `c_f`, area `a_f` (exact shoelace over `Num`). Moved ⟺ `table_position st_pre c_f ≠ apply (face_iso2 st_post f) c_f` — i.e. the face's material sits elsewhere than before the flatten (st_pre = the statement's entry state; for emergent candidates compare against `st'`'s placement, which equals st_pre's placement — subdivision never moves material).
   - `centroid = (Σ a_f · pos_f) / (Σ a_f)` over moved faces, `pos_f` = the face's post-state table centroid (`apply (face_iso2 st_post f) c_f`).
   - Score = `(centroid − O) · (toward − O)` (Num dot). Max wins; top-two tie → `Error.fail span Flatten.e_toward_ambiguous`.
9. Commit winner: `ctx.state := winner.state`; `emergent_bind` = winner's (cid, line) when a candidate ray was materialized (cid = the pre-minted/reused cid — keep 364660f's collinear-reuse handling: the winning realization's emergent crease id is found the same way as today).

- [ ] **Step 1: failing tests** — `tests/test_flatten.ml`:
  - `Flatten.candidates` unit: the fish 3-ray vertex → contains the opposite-ray candidate tagged `` `OppositeRay `` and the two side candidates tagged `` `LineNew ``.
  - Pattern enumeration unit (if factored as a pure function — factor it into `Flatten` or a small exposed helper so it IS unit-testable): 4 rays, all free → 8 patterns; one pinned `MvMountain` → 4; two pinned same-polarity beyond Maekawa → 0.
  - The end-to-end fish assertions move to Task 4's .bel cases; here keep OCaml-level: fish vertex via eval on a constructed program string (reuse the existing fish-base unit from 364660f, now asserting `{toward .b}` and `{toward .d}` produce DIFFERENT folded states — compare a probe point's table position between the two results).
- [ ] **Step 2: run — expect failures.**
- [ ] **Step 3: implement** per the normative pipeline. Delete flatten.ml's `derive` (candidates + moved strings remain). In eval, the 364660f block (`Flatten.derive` call through the winner commit) is replaced wholesale by the pipeline; `try_ray` generalizes to "materialize candidate, return st'" + the attempts logic dissolves into steps 3–4 (patterns now come from the enumerator, not `[true; false]` on the emergent alone — note today's `[true;false]`×candidates loop IS the degenerate all-given-valley case of the enumerator).
- [ ] **Step 4: run** — new tests green; swivel golden byte-identical (`{toward .c}` still picks the right swivel: tier-1 candidates exist there, and among tier-1 realizations the material metric must reproduce the old dot-max choice — if it does not, STOP per Global Constraints); full suite = baseline.
- [ ] **Step 5: commit** — `feat(flatten): one solver pipeline — M/V derived, {toward} selects by moved-material direction`.

---

### Task 4: acceptance, spec prose, cleanup

**Files:**
- Modify: `tests/cases/collapse/flatten-opposite-ray-toward-{b,d}.bel` (rename/extend), `spec/SPECIFICATION.md` (§4.9), `lib/flatten.ml`/`lib/eval.ml` doc comments if stale.
- Test: `tests/test_bel_assert.ml` corpus (no runner change expected).

- [ ] **Step 1:** Rewrite the two fish .bel cases: `flatten (--l1 & .b) (--l2 & .d) (--ray & .a) {toward .b}` and `… {toward .d}` — assertions must PIN THE DIFFERENCE: assert a named point's folded table position (read test_bel_assert's assertion vocabulary first; if point-position assertions aren't supported, assert via `faces=` plus a distinguishing selector outcome, and note the limitation) so the two cases demonstrably produce mirror realizations. Also one case with NO toward on an |S|=1 vertex (e.g. the rabbit-ear-style fixture from test_collapse as .bel if cheap, else a fish case with a pinned `mountain` making S unique) proving toward is optional when unambiguous.
- [ ] **Step 2:** `spec/SPECIFICATION.md` §4.9 rewrite per the design spec's Syntax + Model sections: one pipeline, `()` = hard constraints (rays, `mountain`/`valley`, `over`, `standing`), `{}` = selection (`{toward .p}`, at most one), bare = solver-assigned, Maekawa/Kawasaki as oracle, |S| decision table, error messages, `{}`/#46 note. Match the surrounding prose voice; update the grammar block to Task 1's actual grammar.
- [ ] **Step 3:** Full suite = baseline; swivel golden byte-identical. Commit — `docs(spec)+test: flatten V2 acceptance — {toward} picks mirror realizations; §4.9 one-pipeline`.

---

### Task 5: final review

- [ ] Dispatch the final code reviewer (most capable model) over the whole V2 range (spec commits + Tasks 1–4); fix Criticals/Importants; ledger the outcome in `.superpowers/sdd/progress-v2.md`.
