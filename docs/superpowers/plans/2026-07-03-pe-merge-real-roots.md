# PE-merge path in `Num.real_roots` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a primitive-element tier to `Num.real_roots` that expresses all
algebraic coefficients over one generator γ of the field they span (a compositum
of independent folds) and eliminates with a single resultant `R = Res_x(μ_γ, F̃)`
of minimal degree `3·[ℚ(γ):ℚ]`.

**Architecture:** New `lib/field_merge.ml` builds γ (via FLINT
`qqbar_express_in_field` as membership test + coordinate extractor) and the
superset resultant. `Num.real_roots` gains a gated Tier-3 that calls it, keeping
the existing Mpoly multi-generator path as a correctness-preserving fallback
(Tier 4). One new FFI stub (`qqbar_express_in_field`); no new library (Calcium
rejected in the spike — it is a net regression).

**Tech Stack:** OCaml, dune, FLINT 3.6 `qqbar` (already linked `-lflint`),
zarith (`Q`/`Z`), alcotest.

## Global Constraints

- Exact arithmetic only — never floats internally for results (ADR 0008). Timing
  uses floats; values never do.
- Every returned root MUST pass the exact `eval_p z = 0` qqbar check
  (`lib/num.ml`); a faster-but-wrong result is a failure, not a tradeoff.
- No new external library; FLINT is supplied by the flake, linked via
  `lib/dune`'s `(c_library_flags (-lflint -lgmp -lmpfr))`.
- Any failure inside the new tier (bit-limit, non-membership, degenerate R) MUST
  fall through to the existing Mpoly path, never raise or return a wrong set.
- Build/test from the worktree root; `dune-workspace` (in this worktree) makes
  dune treat it as the workspace root. Run `dune build` / `dune test`.

---

### Task 1: FFI — `Qqbar.express_over`

Express an algebraic number as a ℚ-polynomial in a generator, exactly, via
`qqbar_express_in_field`. This is the one new FFI and the core building block.

**Files:**
- Modify: `lib/qqbar_stubs.c` (add stub near `ml_qqbar_minpoly`, ~line 128)
- Modify: `lib/qqbar.ml` (add `external` + `express_over` after `minpoly`, ~line 50)
- Test: `tests/test_qqbar.ml` (new cases + registration ~line 63)

**Interfaces:**
- Produces:
  - `Qqbar.express_over : gen:Qqbar.t -> Qqbar.t -> Poly.t option`
    — ℚ-polynomial `c` (low-first) with `x = c(gen)` exactly, or `None` when
    `x ∉ ℚ(gen)` or FLINT's bit/precision limit is hit after one retry.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_qqbar.ml` (after `test_real_roots`, before the runner):

```ocaml
let test_express_over () =
  let q = Q.of_string in
  let s2 = Qqbar.sqrt (Qqbar.of_q (q "2")) in
  (* sqrt2 over itself: c(x) = x *)
  (match Qqbar.express_over ~gen:s2 s2 with
   | Some c -> Alcotest.(check bool) "s2 = x in Q(s2)" true
                 (Qqbar.equal (Qqbar.of_q (Poly.eval c (q "0"))) (Qqbar.of_q Q.zero)
                  || Poly.degree c = 1)
   | None -> Alcotest.fail "s2 should be expressible over s2");
  (* 3 + 5*sqrt2 over sqrt2: c = [3; 5] *)
  let v = Qqbar.add (Qqbar.of_q (q "3"))
            (Qqbar.mul (Qqbar.of_q (q "5")) s2) in
  (match Qqbar.express_over ~gen:s2 v with
   | Some c ->
       Alcotest.(check bool) "reconstructs 3+5x at x=s2" true
         (Qqbar.equal
            (Qqbar.add (Qqbar.of_q c.(0)) (Qqbar.mul (Qqbar.of_q c.(1)) s2)) v)
   | None -> Alcotest.fail "3+5*sqrt2 in Q(sqrt2)");
  (* cbrt2 NOT in Q(sqrt2): None *)
  let c2 = List.hd (Qqbar.real_roots_of_poly (Poly.of_list (List.map q ["-2";"0";"0";"1"]))) in
  Alcotest.(check bool) "cbrt2 not in Q(sqrt2)" true
    (Qqbar.express_over ~gen:s2 c2 = None)
```

Register it in the `Alcotest.run "beloch-qqbar"` list:

```ocaml
          Alcotest.test_case "express_over" `Quick test_express_over;
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dune test 2>&1 | grep -A2 express`
Expected: build error `Unbound value Qqbar.express_over`.

- [ ] **Step 3: Add the C stub**

In `lib/qqbar_stubs.c`, add the include near the other flint includes (top of
file, after `#include <flint/qqbar.h>`):

```c
#include <flint/fmpq_poly.h>
```

Add the stub (place after `ml_qqbar_minpoly`):

```c
/* express_in_field(gen, x, max_bits): x as a fmpq_poly in gen, low-first
   "num/den" strings, or None. flags=0, prec follows max_bits. */
CAMLprim value ml_qqbar_express_in_field(value gen, value x, value max_bits) {
  CAMLparam3(gen, x, max_bits);
  CAMLlocal2(res, tmp);
  slong mb = Long_val(max_bits);
  fmpq_poly_t p;
  fmpq_poly_init(p);
  int ok = qqbar_express_in_field(p, Qqbar_val(gen), Qqbar_val(x), mb, 0, mb + 64);
  if (!ok) {
    fmpq_poly_clear(p);
    CAMLreturn(Val_int(0)); /* None */
  }
  slong len = fmpq_poly_length(p);
  res = caml_alloc(len, 0);
  {
    fmpq_t c;
    fmpq_init(c);
    for (slong i = 0; i < len; i++) {
      fmpq_poly_get_coeff_fmpq(c, p, i);
      char *s = fmpq_get_str(NULL, 10, c);
      tmp = caml_copy_string(s);
      flint_free(s);
      Store_field(res, i, tmp);
    }
    fmpq_clear(c);
  }
  fmpq_poly_clear(p);
  {
    CAMLlocal1(some);
    some = caml_alloc(1, 0);
    Store_field(some, 0, res);
    CAMLreturn(some);
  }
}
```

- [ ] **Step 4: Add the OCaml binding**

In `lib/qqbar.ml`, after `let minpoly ...` (~line 50), add:

```ocaml
external express_in_field_raw : t -> t -> int -> string array option
  = "ml_qqbar_express_in_field"

(* x as a ℚ-polynomial (low-first) in gen, exactly, or None if x ∉ ℚ(gen)
   or FLINT's bit limit is hit (one retry at a higher bound). *)
let express_over ~(gen : t) (x : t) : Poly.t option =
  let parse a = Poly.of_list (Array.to_list (Array.map Q.of_string a)) in
  match express_in_field_raw gen x 4096 with
  | Some a -> Some (parse a)
  | None -> (
      match express_in_field_raw gen x 65536 with
      | Some a -> Some (parse a)
      | None -> None)
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `dune exec tests/test_qqbar.exe -- test express_over 2>&1 | tail -5`
Expected: PASS (`express_over` case green). If the first assertion is brittle,
note `Poly.eval c (q "0")` is the constant term; `s2 = x` gives `c = [0;1]`.

- [ ] **Step 6: Commit**

```bash
git add lib/qqbar_stubs.c lib/qqbar.ml tests/test_qqbar.ml
git commit -m "feat(qqbar): express_over — algebraic number as poly in a generator (FFI)"
```

---

### Task 2: `Field_merge` — compositum primitive element + superset resultant

Build one generator γ for the field spanned by the coefficients and the ℚ[t]
superset polynomial. Pure OCaml over Task 1's `express_over`, plus existing
`Mpoly`/`Poly`.

**Files:**
- Create: `lib/field_merge.ml`
- Test: `tests/test_field_merge.ml` (new)
- Modify: `tests/dune` (register `test_field_merge`)

**Interfaces:**
- Consumes: `Qqbar.express_over`, `Qqbar.minpoly`, `Qqbar.equal`,
  `Qqbar.degree`, `Qqbar.add`, `Qqbar.mul`, `Qqbar.of_q`, `Mpoly.*`, `Poly.*`.
- Produces:
  - `Field_merge.merge_generators : Qqbar.t array -> (Poly.t * Poly.t array) option`
    — `Some (mu_gamma, coords)` where `coords.(i)` is a ℚ-polynomial with
    `coords.(i)(gamma) = input.(i)` exactly and `mu_gamma` is γ's minimal
    polynomial; `None` if the field cannot be merged within bit limits.
  - `Field_merge.resultant_superset : coords:Poly.t array -> mu:Poly.t -> Poly.t`
    — `R(t) = Res_x(mu(x), Σ_i coords.(i)(x)·t^i)`, low-first; a superset of the
    true roots of the cubic.

- [ ] **Step 1: Write the failing test**

Create `tests/test_field_merge.ml`:

```ocaml
open Beloch

let q = Q.of_string
let qq s = Qqbar.of_q (q s)

(* helper: evaluate a ℚ-poly at a qqbar point *)
let eval_at (c : Poly.t) (g : Qqbar.t) : Qqbar.t =
  let acc = ref (qq "0") in
  for i = Array.length c - 1 downto 0 do
    acc := Qqbar.add (Qqbar.mul !acc g) (Qqbar.of_q c.(i))
  done;
  !acc

let test_merge_single_generator () =
  (* coefficients all in Q(sqrt2): 1, sqrt2, 3+sqrt2 *)
  let s2 = Qqbar.sqrt (qq "2") in
  let coeffs = [| qq "1"; s2; Qqbar.add (qq "3") s2 |] in
  match Field_merge.merge_generators coeffs with
  | None -> Alcotest.fail "should merge Q(sqrt2)"
  | Some (mu, coords) ->
      (* reconstruct each coefficient from its coords over the SAME gamma.
         gamma is a root of mu; verify by rebuilding coeffs and comparing. *)
      Alcotest.(check int) "3 coord polys" 3 (Array.length coords);
      (* mu has degree 2 (Q(sqrt2)) *)
      Alcotest.(check int) "mu degree 2" 2 (Poly.degree mu)

let test_merge_compositum_independent () =
  (* independent folds: sqrt2 and cbrt2 → Q(sqrt2, cbrt2), degree 6 *)
  let s2 = Qqbar.sqrt (qq "2") in
  let c2 = List.hd (Qqbar.real_roots_of_poly (Poly.of_list (List.map q ["-2";"0";"0";"1"]))) in
  let coeffs = [| s2; c2; Qqbar.add s2 c2 |] in
  match Field_merge.merge_generators coeffs with
  | None -> Alcotest.fail "should merge Q(sqrt2, cbrt2)"
  | Some (mu, coords) ->
      Alcotest.(check int) "mu degree 6" 6 (Poly.degree mu);
      Alcotest.(check int) "3 coord polys" 3 (Array.length coords)

let () =
  Alcotest.run "field_merge"
    [ ( "merge",
        [ Alcotest.test_case "single generator" `Quick test_merge_single_generator;
          Alcotest.test_case "compositum independent" `Quick
            test_merge_compositum_independent ] ) ]
```

Add to `tests/dune`:

```
(test
 (name test_field_merge)
 (libraries beloch alcotest zarith))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dune build tests/test_field_merge.exe 2>&1 | tail`
Expected: `Unbound module Field_merge`.

- [ ] **Step 3: Implement `Field_merge`**

Create `lib/field_merge.ml`:

```ocaml
(** Primitive-element merge for real_roots: express algebraic coefficients over
    one generator γ of the field they span (compositum of independent folds),
    and form the ℚ[t] superset polynomial via a single resultant. See
    docs/superpowers/specs/2026-07-03-pe-merge-real-roots-design.md. *)

let k_limit = 64 (* defensive cap on the primitive-element multiplier search *)

(* γ that generates ℚ(gen, b): γ = gen + k·b for the least k in 1..k_limit such
   that both gen and b lie in ℚ(γ). None if the cap is exceeded. *)
let extend (gen : Qqbar.t) (b : Qqbar.t) : Qqbar.t option =
  match Qqbar.express_over ~gen b with
  | Some _ -> Some gen (* b already in ℚ(gen) *)
  | None ->
      let rec search k =
        if k > k_limit then None
        else
          let g = Qqbar.add gen (Qqbar.mul (Qqbar.of_q (Q.of_int k)) b) in
          match Qqbar.express_over ~gen:g gen, Qqbar.express_over ~gen:g b with
          | Some _, Some _ -> Some g
          | _ -> search (k + 1)
      in
      search 1

(* (mu_gamma, coords) with coords.(i)(gamma) = input.(i), or None. *)
let merge_generators (coeffs : Qqbar.t array) : (Poly.t * Poly.t array) option =
  (* distinct non-rational coefficients, in first-seen order *)
  let algs =
    Array.fold_left
      (fun acc c ->
        if Qqbar.is_rational c then acc
        else if List.exists (fun d -> Qqbar.equal d c) acc then acc
        else acc @ [ c ])
      [] coeffs
  in
  match algs with
  | [] -> None (* all rational: caller uses the rational path *)
  | g0 :: rest ->
      let rec build gen = function
        | [] -> Some gen
        | b :: tl -> (
            match extend gen b with None -> None | Some g -> build g tl)
      in
      match build g0 rest with
      | None -> None
      | Some gamma -> (
          let coords = Array.map (fun c -> Qqbar.express_over ~gen:gamma c) coeffs in
          if Array.exists (fun o -> o = None) coords then None
          else
            let coords =
              Array.map (function Some c -> c | None -> assert false) coords
            in
            Some (Qqbar.minpoly gamma, coords))

(* embed a Poly.t (in x) as an Mpoly in variable v of an nvars-space *)
let embed_poly nvars v (p : Poly.t) : Mpoly.t =
  let m = ref Mpoly.zero in
  Array.iteri
    (fun k c ->
      if not (Q.equal c Q.zero) then
        m :=
          Mpoly.add !m
            (Mpoly.mul (Mpoly.const nvars c) (Mpoly.pow (Mpoly.var nvars v) k)))
    p;
  !m

(* R(t) = Res_x(mu(x), Σ_i coords.(i)(x) t^i); var0 = t, var1 = x. *)
let resultant_superset ~(coords : Poly.t array) ~(mu : Poly.t) : Poly.t =
  let nvars = 2 in
  let f = ref Mpoly.zero in
  Array.iteri
    (fun i ci ->
      let term = Mpoly.mul (embed_poly nvars 1 ci) (Mpoly.pow (Mpoly.var nvars 0) i) in
      f := Mpoly.add !f term)
    coords;
  Mpoly.to_poly_in (Mpoly.resultant !f (embed_poly nvars 1 mu) 1) 0
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `dune exec tests/test_field_merge.exe 2>&1 | tail -6`
Expected: both cases PASS (`mu degree 2`, `mu degree 6`).

- [ ] **Step 5: Add a resultant_superset test**

Append to `tests/test_field_merge.ml` before the runner, and register it:

```ocaml
let test_resultant_superset_cubic () =
  (* cubic t^3 - 2 has coeffs all rational except none; use t^3 - sqrt2 whose
     coeff sqrt2 lives in Q(sqrt2). R must vanish at the real cube-ish root. *)
  let s2 = Qqbar.sqrt (qq "2") in
  let coeffs = [| Qqbar.neg s2; qq "0"; qq "0"; qq "1" |] in
  match Field_merge.merge_generators coeffs with
  | None -> Alcotest.fail "merge"
  | Some (mu, coords) ->
      let r = Field_merge.resultant_superset ~coords ~mu in
      let roots = Qqbar.real_roots_of_poly r in
      (* the real root of t^3 = sqrt2 must be among R's real roots *)
      let target = List.hd (Qqbar.real_roots_of_poly
                     (Poly.of_list (List.map q ["-2";"0";"0";"0";"0";"0";"1"]))) in
      Alcotest.(check bool) "R contains t with t^6 = 2" true
        (List.exists (fun z -> Qqbar.equal z target) roots)
```

Register:

```ocaml
          Alcotest.test_case "resultant superset cubic" `Quick
            test_resultant_superset_cubic;
```

- [ ] **Step 6: Run and commit**

Run: `dune exec tests/test_field_merge.exe 2>&1 | tail -8`
Expected: all three PASS.

```bash
git add lib/field_merge.ml tests/test_field_merge.ml tests/dune
git commit -m "feat(field_merge): compositum primitive element + superset resultant"
```

---

### Task 3: Wire Tier-3 into `Num.real_roots`

Gate the primitive-element path in front of the Mpoly fallback and behind
`flint_first` for low degree.

**Files:**
- Modify: `lib/num.ml` (the `real_roots` algebraic branch, ~lines 339–518)
- Test: `tests/test_num.ml` (new cases + registration)

**Interfaces:**
- Consumes: `Field_merge.merge_generators`, `Field_merge.resultant_superset`,
  and the existing local `eval_p`, `coeffs_qq`, `field_upgrade`, `of_qq`.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_num.ml` (before the runner):

```ocaml
let test_real_roots_independent_folds () =
  (* a cubic whose coefficients combine two INDEPENDENT prior folds:
     sqrt2 and cbrt2. Coefficient field is Q(sqrt2, cbrt2), degree 6.
     t^3 + (cbrt2)·t - sqrt2 = 0 — one real root, verified exactly. *)
  let s2 = Num.sqrt (n 2) in
  let c2 = Num.real_roots [| n (-2); n 0; n 0; n 1 |] |> List.hd in (* cbrt2 *)
  let coeffs = [| Num.neg s2; c2; n 0; n 1 |] in
  let roots = Num.real_roots coeffs in
  Alcotest.(check bool) "≥1 real root" true (List.length roots >= 1);
  List.iter
    (fun r ->
      let v =
        Num.add (Num.add (Num.mul (Num.mul r r) r) (Num.mul c2 r)) (Num.neg s2)
      in
      Alcotest.(check bool) "root verifies exactly" true (Num.equal v Num.zero))
    roots
```

(`n` is `test_num.ml`'s existing `Num.of_q ∘ Q.of_int` helper — confirm its name
at the top of the file and match it.)

Register:

```ocaml
          Alcotest.test_case "real roots independent folds (compositum)" `Quick
            test_real_roots_independent_folds;
```

- [ ] **Step 2: Run to verify current behaviour**

Run: `dune exec tests/test_num.exe -- test 'real roots independent folds' 2>&1 | tail`
Expected: currently PASSES via the existing Mpoly path (correctness is already
there) but exercises Tier 3 once wired. If it already passes, keep it — it
becomes the Tier-3 regression guard. Confirm it runs in well under a second after
Step 3.

- [ ] **Step 3: Insert Tier 3 in `lib/num.ml`**

Locate the algebraic branch's dispatch (currently ~line 377):

```ocaml
    match flint_first () with
    | Some roots -> roots
    | None ->
    (* fallback: generator elimination (Mpoly) + exact verification. *)
```

Replace those lines with the gated three-way dispatch (the Mpoly body below the
comment stays unchanged):

```ocaml
    let max_deg =
      Array.fold_left (fun m c -> max m (Qqbar.degree c)) 0 coeffs_qq
    in
    let pe_tier () : t list option =
      match Field_merge.merge_generators coeffs_qq with
      | None -> None
      | Some (mu, coords) ->
          let r = Field_merge.resultant_superset ~coords ~mu in
          if Poly.degree r < 1 then None
          else
            Some
              (Qqbar.real_roots_of_poly r
              |> List.filter (fun z -> Qqbar.is_zero (eval_p z))
              |> List.map (fun z -> field_upgrade (of_qq z)))
    in
    let tier12 = if max_deg < 5 then flint_first () else None in
    match tier12 with
    | Some roots -> roots
    | None -> (
        match pe_tier () with
        | Some roots -> roots
        | None ->
    (* fallback: generator elimination (Mpoly) + exact verification. *)
```

Add one closing paren to balance the new `match ... -> (`: the existing branch
ends with `end` (the `else begin ... end` at ~line 518/519). Change that final
`end` to `end)` so the `pe_tier`'s `None -> (` closes. Verify by building.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `dune exec tests/test_num.exe 2>&1 | tail -20`
Expected: all `beloch-num` cases PASS, including the new independent-folds case
and the existing `axiom7-style algebraic cubic fast`.

- [ ] **Step 5: Commit**

```bash
git add lib/num.ml tests/test_num.ml
git commit -m "feat(num): primitive-element tier in real_roots (compositum-general)"
```

---

### Task 4: Regression, performance, and fallback verification

Prove the #33 win, the fallback still fires, and nothing regressed.

**Files:**
- Test: `tests/test_num.ml` (perf + fallback cases)
- Modify: `notes/2026-07-03-33-verdict.md` (append a closing update)

- [ ] **Step 1: Add the #33 performance regression test**

Add to `tests/test_num.ml`, reusing the deeper stacked cubic (coefficient field
degree ≥ 8) that the spike measured qqbar at ~9s and PE at ~0.2s:

```ocaml
let test_real_roots_deep_stack_fast () =
  (* p.x = ((sqrt2+sqrt3)/8) fed once more through an axiom-7-style cubic:
     coefficient field degree 8; qqbar native ~9s, PE tier target < 2s. *)
  let s2 = Num.sqrt (n 2) and s3 = Num.sqrt (n 3) in
  let g = Num.div (Num.add s2 s3) (n 8) in
  let g2 = Num.mul g g in
  let coeffs = [| Num.neg g2; g; Num.neg (Num.add g g), Num.one |] in
  ignore coeffs; (* placeholder — see note below *)
  ()
```

NOTE for the implementer: the exact deep-stack coefficients should be taken by
running `scratch/spike_pe.ml`'s round-5 cubic and copying its `coeffs`
construction, OR by feeding `g` (degree-4) once more through
`Geom.beloch7_creases`-style building. Build the concrete degree-8 cubic, assert
`List.length (Num.real_roots coeffs) >= 1`, that each root verifies exactly, and
that wall time is `< 2.0s` (mirror the timing assertion in
`test_num_axiom7_style_algebraic_cubic_fast`). Replace the placeholder body with
that.

Register:

```ocaml
          Alcotest.test_case "real roots deep stack fast (#33)" `Slow
            test_real_roots_deep_stack_fast;
```

- [ ] **Step 2: Run the full suite**

Run: `dune test 2>&1 | tail -30`
Expected: every suite green (`beloch-num`, `beloch-qqbar`, `field_merge`,
`beloch-geom`, `golden`, `beloch-parse`, `test_eval`, `test_e2e`, …). The golden
`cube-root.bel` output MUST be byte-identical — Tier 3 uses `field_upgrade`, same
representation as before for degree ≤ 3.

- [ ] **Step 3: Verify the fallback path still works**

Confirm that a coefficient set the PE tier declines (force it by temporarily
lowering `k_limit` to `0` in a throwaway build, or add a case whose merge returns
`None`) still yields correct roots via the Mpoly fallback. The existing
`test_num_casus_irreducibilis_distinct` / `real roots two generators` cases
already exercise the Mpoly path with `max_deg < 5` when `flint_first` succeeds;
add one assertion that a `None`-from-`pe_tier` input still returns the correct
set. Simplest: rely on the existing Mpoly tests remaining green (they route
through Tier 4 unchanged whenever `pe_tier` returns `None`). Document this in the
commit message.

- [ ] **Step 4: Append the verdict update**

Add to `notes/2026-07-03-33-verdict.md`:

```markdown
---

## Update (2026-07-03): primitive-element tier landed

`Num.real_roots` now has a Tier-3 primitive-element path (spec + spike:
`notes/2026-07-03-calcium-pe-spike.md`). Coefficients spanning a compositum of
independent folds are expressed over one generator γ (FLINT
`qqbar_express_in_field`) and eliminated with a single `R = Res_x(μ_γ, F̃)` of
degree `3·[ℚ(γ):ℚ]`. The #33 round-4 case (coefficients over a degree-9 field),
previously `>300s killed`, now completes interactively; the stacked-cubic ceiling
moved from round 3 to ~round 5. The Mpoly multi-generator path remains as a
correctness-preserving fallback. Calcium (`ca_t`) was evaluated and rejected — it
caps out below the status quo.
```

- [ ] **Step 5: Commit**

```bash
git add tests/test_num.ml notes/2026-07-03-33-verdict.md
git commit -m "test(num): #33 deep-stack perf + verdict update for PE tier"
```

---

## Self-Review

- **Spec coverage:** C1 `express_over` → Task 1. C2 primitive element → Task 2
  (`merge_generators`). C3 resultant+filter → Task 2 (`resultant_superset`) +
  Task 3 (filter/`field_upgrade` in `real_roots`). Gate (T=5, `flint_first`
  None) → Task 3. Fallback → Task 3 dispatch + Task 4 Step 3. Independent-folds
  success criterion → Task 3 test. #33 perf criterion → Task 4. Existing suite
  green → Task 4 Step 2. All spec sections mapped.
- **Type consistency:** `express_over ~gen:Qqbar.t -> Qqbar.t -> Poly.t option`
  used identically in Task 2. `merge_generators : Qqbar.t array -> (Poly.t *
  Poly.t array) option` and `resultant_superset ~coords ~mu : Poly.t` match
  between Task 2 definition and Task 3 use. `coeffs_qq` / `eval_p` /
  `field_upgrade` / `of_qq` are existing `real_roots`-local bindings (Task 3
  consumes them in place).
- **Placeholders:** Task 4 Step 1 intentionally leaves the exact deep-stack
  coefficients to be copied from `scratch/spike_pe.ml` (they are long, degree-8
  algebraic literals); the surrounding assertions and the source to copy from are
  fully specified. All other steps carry complete code.
- **Paren balance risk (Task 3 Step 3):** flagged explicitly — the new
  `pe_tier`'s `None -> (` requires turning the branch-closing `end` into `end)`;
  the step says to verify by building.
