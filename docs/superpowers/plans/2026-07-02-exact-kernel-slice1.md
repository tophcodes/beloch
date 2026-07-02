# Exact Kernel Slice 1 (#23) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `Num.equal`/`Num.compare` exact for arbitrarily close algebraic numbers and remove the `real_roots` isolation wall (issue #23).

**Architecture:** Three surgical changes to the real-algebraic kernel: (1) delete the width-1 zero-shortcut in `select_root` and let the isolating-interval loop decide zero exactly; (2) replace trial-division divisor enumeration in the rational-root search with continued-fraction "simplest rational in interval"; (3) replace Sturm-bisection root isolation with the Descartes/VCA 0-or-1 test. Spec: `docs/superpowers/specs/2026-07-02-exact-kernel-design.md` (Slice 1).

**Tech Stack:** OCaml, zarith (`Q`/`Z`), alcotest, dune.

## Global Constraints

- Kernel stays exact: no floating point anywhere except the existing `Num.to_float` (output-only).
- Public `Num` API unchanged (`equal`, `compare`, `sign`, `real_roots` signatures stay).
- `Poly.isolate_roots : t -> (Q.t * Q.t) list` keeps its signature and contract: disjoint open intervals, each containing exactly one simple root of the squarefree part, ascending order, endpoints are not roots.
- Existing test suite stays green: `dune runtest` after every task.
- Conventional commits, concise messages, no bodies.
- ε-ladder budget from the spec: each `real_roots` rung (ε = 5·10⁻⁸ … 5·10⁻²⁰) under 1 s.

## File Structure

- `lib/num.ml` — `select_root` fix (Task 1); `simplest_in` + `rational_roots_in` rewrite, `divisors` deleted (Task 2).
- `lib/poly.ml` — `sign_variations`, `reverse`, `descartes_test`, `isolate_roots` rewrite (Task 3).
- `tests/test_num.ml` — all new tests (Num and Poly suites both live here).
- `tests/dune` — `unix` added to the `test_num` stanza (timing asserts).

There are no `.mli` files in `lib/`; every function in `num.ml`/`poly.ml` is reachable from tests as `Num.foo`/`Poly.foo`.

---

### Task 1: `select_root` decides zero exactly

The bug (#23): `select_root` (`lib/num.ml:213-234`) returns `zero` whenever the
defining polynomial has 0 as a root and a **fixed width-1** enclosure straddles
0. For `sub x y` with x, y roots of the same polynomial the resultant always
has the root 0, so any two distinct values closer than ~1 collapse to `zero` —
`Num.equal` reports distinct roots as equal. Fix: delete the shortcut. The
existing `pick` loop already refines the enclosure until it overlaps exactly
one isolating interval, and `make` already collapses a rational root (including
0) to `Rat`. Zero is just another root candidate.

**Files:**
- Modify: `lib/num.ml:213-234` (`select_root`)
- Test: `tests/test_num.ml`

**Interfaces:**
- Consumes: `Poly.isolate_roots`, `make` (both existing, unchanged).
- Produces: `select_root : Poly.t -> (Q.t -> Q.t * Q.t) -> t` — same signature,
  now returns `Rat Q.zero` (via `make`'s collapse) only when the value really
  is 0. Tasks 2–4 rely on `Num.equal`/`Num.compare` being exact.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_num.ml`, next to the other `test_num_*` functions:

```ocaml
let test_num_close_roots_distinct () =
  (* #23 repro: x⁴ − 5x² + ε with ε = 5·10⁻⁸ has two roots ≈ ±10⁻⁴.
     They are distinct; equal/compare must say so. *)
  let eps = Num.of_q (Q.of_string "1/20000000") in
  let coeffs = [| eps; Num.zero; Num.of_int (-5); Num.zero; Num.one |] in
  match Num.real_roots coeffs with
  | [ _; y; x; _ ] ->
      Alcotest.(check bool) "close roots not equal" false (Num.equal x y);
      Alcotest.(check int) "compare x y = 1" 1 (Num.compare x y);
      Alcotest.(check int) "compare y x = -1" (-1) (Num.compare y x)
  | roots -> Alcotest.failf "expected 4 roots, got %d" (List.length roots)
```

Register it in the `Alcotest.run` list in the num section:

```ocaml
Alcotest.test_case "close roots distinct (#23)" `Quick
  test_num_close_roots_distinct;
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dune exec tests/test_num.exe -- test 'num' 2>&1 | tail -20` (or `dune runtest` and read the failure)
Expected: FAIL on "close roots not equal" — `Num.equal` currently returns `true`.
(Note: the two near-zero roots may come back in either order because `compare`
currently reports 0 between them; the pattern match still binds 4 roots.)

- [ ] **Step 3: Replace `select_root`**

In `lib/num.ml`, replace the whole `select_root` definition (lines 210–234, including the comment) with:

```ocaml
(* Given the result's defining polynomial R and a procedure that returns an
   arbitrarily tight rational enclosure of the true result value, refine the
   enclosure until it overlaps exactly one isolating interval of R's
   squarefree part, then build the value there. A rational value — including
   0 — collapses to Rat inside [make]; there is no separate zero shortcut
   (#23: a fixed-width straddle test collapsed distinct close values to 0).
   Terminates because distinct roots have positive separation. *)
let select_root (r : Poly.t) (enclose : Q.t -> Q.t * Q.t) : t =
  let s = Poly.squarefree_part r in
  let intervals = Poly.isolate_roots s in
  let two = Q.of_int 2 in
  let rec pick width =
    let lo, hi = enclose width in
    let hits =
      List.filter (fun (a, b) -> Q.compare a hi < 0 && Q.compare lo b < 0) intervals
    in
    match hits with
    | [ (a, b) ] ->
        let lo = Q.max lo a and hi = Q.min hi b in
        make s lo hi
    | _ -> pick (Q.div width two)
  in
  pick (Q.of_int 1)
```

- [ ] **Step 4: Run tests to verify all pass**

Run: `dune runtest 2>&1 | tail -5`
Expected: all suites pass, including the new case (the close roots now
separate at enclosure width < ~2·10⁻⁴) and the existing zero-collapse cases
(`sqrt8 = 2 sqrt2` exercises `sub → 0` through the new path).

- [ ] **Step 5: Commit**

```bash
git add lib/num.ml tests/test_num.ml
git commit -m "fix(num): select_root decides zero via isolating intervals (#23)"
```

---

### Task 2: rational-root search without trial division

The wall (#23 timing ladder): `divisors` (`lib/num.ml:68-82`) trial-divides up
to √n; clearing denominators of the ε-quartic at ε = 5·10⁻²⁰ gives a leading
coefficient ~2·10¹⁹ → ~4.5·10⁹ divisions. Replacement: a rational root in
lowest terms p/q of the integer-cleared polynomial has q | aₙ, and two distinct
rationals with denominators ≤ aₙ differ by ≥ 1/aₙ². So per isolating interval:
bisect below that separation, then the **simplest rational in the interval**
(continued-fraction descent) is the only possible rational root — verify by
exact evaluation. O(log aₙ) steps instead of O(√aₙ) divisions.

**Files:**
- Modify: `lib/num.ml:68-111` (`divisors` deleted, `rational_roots_in` rewritten, `simplest_in` added)
- Modify: `tests/dune` (add `unix` to `test_num`)
- Test: `tests/test_num.ml`

**Interfaces:**
- Consumes: `Poly.isolate_roots`, `Poly.squarefree_part`, `Poly.eval`, `Poly.sign_at` (existing).
- Produces: `Num.simplest_in : Q.t -> Q.t -> Q.t` (simplest rational in a
  closed interval [lo,hi], lo ≤ hi); `Num.rational_roots_in : Poly.t -> Q.t ->
  Q.t -> Q.t list` — same signature and contract as before (all rational roots
  of p in [lo,hi], ascending, deduplicated). `make` and `minimal_poly_in`
  call it unchanged.

- [ ] **Step 1: Add `unix` to the test stanza**

In `tests/dune`, change the `test_num` stanza to:

```dune
(test
 (name test_num)
 (libraries beloch alcotest zarith unix))
```

- [ ] **Step 2: Write the failing tests**

Add to `tests/test_num.ml`:

```ocaml
let test_simplest_in () =
  let q = Q.of_string in
  Alcotest.(check bool) "1/2 in [2/5, 3/5]" true
    (Q.equal (Num.simplest_in (q "2/5") (q "3/5")) (q "1/2"));
  Alcotest.(check bool) "0 in [-1/3, 1/4]" true
    (Q.equal (Num.simplest_in (q "-1/3") (q "1/4")) Q.zero);
  Alcotest.(check bool) "3 in [5/2, 7/2]" true
    (Q.equal (Num.simplest_in (q "5/2") (q "7/2")) (Q.of_int 3));
  Alcotest.(check bool) "-1/2 in [-3/5, -2/5]" true
    (Q.equal (Num.simplest_in (q "-3/5") (q "-2/5")) (q "-1/2"));
  Alcotest.(check bool) "point interval" true
    (Q.equal (Num.simplest_in (q "3/7") (q "3/7")) (q "3/7"))

let test_rational_roots_big_denominator () =
  (* the #23 wall: integer-cleared leading coefficient ~2·10¹⁹; the old
     divisor enumeration trial-divided to √(2·10¹⁹). Must now be instant. *)
  let eps = Q.of_string "1/20000000000000000000" in
  let p = Poly.of_list [ eps; Q.zero; Q.of_int (-5); Q.zero; Q.one ] in
  let t0 = Unix.gettimeofday () in
  let roots = Num.rational_roots_in p (Q.of_int (-3)) (Q.of_int 3) in
  let dt = Unix.gettimeofday () -. t0 in
  Alcotest.(check int) "quartic has no rational roots" 0 (List.length roots);
  Alcotest.(check bool) (Printf.sprintf "under 1s (took %.2fs)" dt) true (dt < 1.0)

let test_rational_roots_finds_roots () =
  (* (7x − 3)(x − 2)(x² − 2) : rational roots 3/7 and 2, irrational ±√2 *)
  let p =
    Poly.mul
      (Poly.mul
         (Poly.of_list [ Q.of_int (-3); Q.of_int 7 ])
         (Poly.of_list [ Q.of_int (-2); Q.one ]))
      (Poly.of_list [ Q.of_int (-2); Q.zero; Q.one ])
  in
  let roots = Num.rational_roots_in p (Q.of_int (-3)) (Q.of_int 3) in
  Alcotest.(check int) "two rational roots" 2 (List.length roots);
  Alcotest.(check bool) "3/7 found" true
    (List.exists (Q.equal (Q.of_string "3/7")) roots);
  Alcotest.(check bool) "2 found" true
    (List.exists (Q.equal (Q.of_int 2)) roots);
  (* range clipping: only 3/7 within [0, 1] *)
  let clipped = Num.rational_roots_in p Q.zero Q.one in
  Alcotest.(check int) "clipped to [0,1]" 1 (List.length clipped)
```

Register in the num section of `Alcotest.run`:

```ocaml
Alcotest.test_case "simplest rational in interval" `Quick test_simplest_in;
Alcotest.test_case "rational roots: big denominator fast (#23)" `Quick
  test_rational_roots_big_denominator;
Alcotest.test_case "rational roots: found and clipped" `Quick
  test_rational_roots_finds_roots;
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `dune runtest 2>&1 | tail -20`
Expected: compile error — `Num.simplest_in` is not defined. (The
big-denominator test would hang for minutes on the old code; the missing
function fails faster.)

- [ ] **Step 4: Implement `simplest_in`, rewrite `rational_roots_in`, delete `divisors`**

In `lib/num.ml`, replace everything from the `(* integer divisors … *)`
comment (line 68) through the end of the old `rational_roots_in` (line 111)
with:

```ocaml
(* Simplest rational (smallest denominator; among those, closest to 0) in the
   closed interval [lo, hi], lo ≤ hi. Continued-fraction / Stern–Brocot
   descent: strip the integer part, recurse on the inverted fractional part.
   Terminates in the continued-fraction depth of the endpoints. *)
let rec simplest_in (lo : Q.t) (hi : Q.t) : Q.t =
  if Q.compare lo hi > 0 then invalid_arg "Num.simplest_in: lo > hi"
  else if Q.sign lo <= 0 && Q.sign hi >= 0 then Q.zero
  else if Q.sign hi < 0 then Q.neg (simplest_in (Q.neg hi) (Q.neg lo))
  else begin
    (* 0 < lo ≤ hi *)
    let fl = Z.fdiv (Q.num lo) (Q.den lo) in
    if Q.equal (Q.of_bigint fl) lo then lo
    else if Q.compare (Q.of_bigint (Z.succ fl)) hi <= 0 then
      Q.of_bigint (Z.succ fl)
    else
      let lo' = Q.sub lo (Q.of_bigint fl) and hi' = Q.sub hi (Q.of_bigint fl) in
      Q.add (Q.of_bigint fl) (Q.inv (simplest_in (Q.inv hi') (Q.inv lo')))
  end

(* Rational roots of a ℚ-polynomial lying in [lo,hi]. A rational root in
   lowest terms has denominator dividing the integer-cleared leading
   coefficient aₙ, and two distinct rationals with denominators ≤ aₙ differ
   by at least 1/aₙ². So: isolate the real roots, bisect each isolating
   interval below that separation — then at most one rational with
   denominator ≤ aₙ remains inside, and it is the simplest rational there.
   Verify by exact evaluation. Replaces divisor enumeration by trial
   division, the #23 real_roots wall. *)
let rational_roots_in (p : Poly.t) (lo : Q.t) (hi : Q.t) : Q.t list =
  if Poly.degree p < 1 then []
  else begin
    let s = Poly.squarefree_part p in
    let l = Array.fold_left (fun acc c -> Z.lcm acc (Q.den c)) Z.one s in
    let an = Z.abs (Q.num (Q.mul (Poly.leading s) (Q.of_bigint l))) in
    let sep = Q.make Z.one (Z.mul an an) in
    Poly.isolate_roots s
    |> List.filter_map (fun (a, b) ->
           (* endpoints of isolating intervals are never roots; the single
              root inside is bracketed by a sign change of s. *)
           let rec refine a b =
             if Q.compare (Q.sub b a) sep < 0 then simplest_in a b
             else
               let m = Q.div (Q.add a b) two_q in
               if Poly.sign_at s m = 0 then m
               else if Poly.sign_at s a * Poly.sign_at s m < 0 then refine a m
               else refine m b
           in
           let r = refine a b in
           if Q.equal (Poly.eval s r) Q.zero then Some r else None)
    |> List.filter (fun r -> Q.compare lo r <= 0 && Q.compare r hi <= 0)
    |> List.sort_uniq Q.compare
  end
```

Note `two_q` must already be in scope at this point in the file — it is
defined near the top of `num.ml`; if it sits below line 68, move its
definition above `simplest_in`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `dune runtest 2>&1 | tail -5`
Expected: all pass. The big-denominator case runs in milliseconds. Existing
collapse tests (`sqrt4 = 2`, real_roots suites) exercise the rewritten
function through `make`/`minimal_poly_in`.

- [ ] **Step 6: Commit**

```bash
git add lib/num.ml tests/test_num.ml tests/dune
git commit -m "perf(num): continued-fraction rational-root search, drop trial division (#23)"
```

---

### Task 3: Descartes-based root isolation

`Poly.isolate_roots` currently bisects with Sturm-chain sign counts at every
node. Replace the per-node test with the Descartes/VCA 0-or-1 test: the number
of sign variations of the Möbius-transformed coefficient sequence bounds the
root count in the interval and equals it when 0 or 1 [bpr2006, Ch. 2, 10]. No
Sturm chain is built during isolation (the chain's coefficient growth is what
hurts at higher degrees, which Slice 2's joins will produce). `sturm_sequence`
and `count_roots_in` stay — `make` and `real_roots` still use them for
counting in externally supplied intervals.

**Files:**
- Modify: `lib/poly.ml:208-230` (`isolate_roots`), additions above it
- Test: `tests/test_num.ml` (poly section)

**Interfaces:**
- Consumes: `compose`, `normalize`, `sign_at`, `squarefree_part`, `cauchy_bound` (existing).
- Produces: `Poly.sign_variations : t -> int`, `Poly.reverse : t -> t`,
  `Poly.descartes_test : t -> Q.t -> Q.t -> int`, and `Poly.isolate_roots`
  with its unchanged signature/contract (see Global Constraints).

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_num.ml` in the poly test group:

```ocaml
let test_poly_sign_variations () =
  Alcotest.(check int) "x²-3x+2 has 2 variations" 2
    (Poly.sign_variations (qp [ 2; -3; 1 ]));
  Alcotest.(check int) "x²+x+1 has 0 variations" 0
    (Poly.sign_variations (qp [ 1; 1; 1 ]));
  Alcotest.(check int) "zeros skipped: x³-1" 1
    (Poly.sign_variations (qp [ -1; 0; 0; 1 ]))

let test_poly_descartes_test () =
  (* p = (x−1)(x−2) on various intervals *)
  let p = qp [ 2; -3; 1 ] in
  Alcotest.(check int) "no root in (3,4)" 0
    (Poly.descartes_test p (Q.of_int 3) (Q.of_int 4));
  Alcotest.(check int) "one root in (1/2,3/2)" 1
    (Poly.descartes_test p (Q.of_string "1/2") (Q.of_string "3/2"))

let test_poly_isolate_close_roots () =
  (* ε-quartic at the hardest rung: two roots ~3·10⁻¹⁰ apart *)
  let eps = Q.of_string "1/20000000000000000000" in
  let p = Poly.of_list [ eps; Q.zero; Q.of_int (-5); Q.zero; Q.one ] in
  let iv = Poly.isolate_roots p in
  Alcotest.(check int) "four isolated roots" 4 (List.length iv)
```

Register in the poly section of `Alcotest.run`:

```ocaml
Alcotest.test_case "sign variations" `Quick test_poly_sign_variations;
Alcotest.test_case "descartes 0/1 test" `Quick test_poly_descartes_test;
Alcotest.test_case "isolate close roots (#23)" `Quick
  test_poly_isolate_close_roots;
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `dune runtest 2>&1 | tail -20`
Expected: compile error — `Poly.sign_variations` is not defined.

- [ ] **Step 3: Implement**

In `lib/poly.ml`, insert directly above `isolate_roots`:

```ocaml
(* Number of sign variations in the coefficient sequence, zeros skipped.
   Descartes' law of signs: bounds the number of positive real roots and
   agrees with it modulo 2 [bpr2006, Ch. 2]. *)
let sign_variations (p : t) : int =
  let last = ref 0 and count = ref 0 in
  Array.iter
    (fun c ->
      let s = Q.sign c in
      if s <> 0 then begin
        if !last <> 0 && s <> !last then incr count;
        last := s
      end)
    p;
  !count

(* Coefficient reversal: x^n · p(1/x) for p of degree n. *)
let reverse (p : t) : t =
  let n = Array.length p in
  normalize (Array.init n (fun i -> p.(n - 1 - i)))

(* Descartes/VCA test for the open interval (a,b), a < b, neither endpoint a
   root: the sign-variation count of (1+x)^n · q(1/(1+x)) where q maps (0,1)
   to (a,b). Result 0 means no root in (a,b); 1 means exactly one; ≥ 2 means
   undecided (split further) [bpr2006, Ch. 10]. *)
let descartes_test (p : t) (a : Q.t) (b : Q.t) : int =
  let q = compose p (of_list [ a; Q.sub b a ]) in
  sign_variations (compose (reverse q) (of_list [ Q.one; Q.one ]))
```

Then replace the body of `isolate_roots` (keep its doc comment, adjust the
mention of Sturm):

```ocaml
(* Disjoint open intervals each holding exactly one simple real root, ascending.
   Works on the squarefree part so every root is simple. Descartes/VCA
   bisection: the 0/1 sign-variation test decides leaf intervals without
   building Sturm chains. *)
let isolate_roots (p : t) : (Q.t * Q.t) list =
  let p = squarefree_part p in
  if degree p < 1 then []
  else begin
    let b = cauchy_bound p in
    let two = Q.of_int 2 in
    let rec go lo hi acc =
      match descartes_test p lo hi with
      | 0 -> acc
      | 1 -> (lo, hi) :: acc
      | _ ->
          let m = Q.div (Q.add lo hi) two in
          (* a root exactly at the split point would be lost to both halves;
             nudge, as before (squarefree ⇒ finitely many roots). *)
          let m = if sign_at p m = 0 then Q.div (Q.add lo m) two else m in
          go lo m (go m hi acc)
    in
    go (Q.neg b) b []
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `dune runtest 2>&1 | tail -5`
Expected: all pass — including the pre-existing `isolate roots` case and
everything that routes through `make`, `select_root`, `real_roots`, and
Task 2's `rational_roots_in` (they all call `isolate_roots`).

- [ ] **Step 5: Commit**

```bash
git add lib/poly.ml tests/test_num.ml
git commit -m "perf(poly): Descartes/VCA root isolation replaces Sturm bisection (#23)"
```

---

### Task 4: ε-ladder regression + integration check

The end-to-end guarantee from the spec: `Num.real_roots` on the close-roots
quartic stays under 1 s per rung down to ε = 5·10⁻²⁰ (previously: 3.47 s at
5·10⁻¹⁶, timeout >150 s at 5·10⁻²⁰), and the roots come back strictly ordered
and pairwise distinct — which leans on all three fixes at once.

**Files:**
- Test: `tests/test_num.ml`

**Interfaces:**
- Consumes: `Num.real_roots : Num.t array -> Num.t list` (existing),
  exact `Num.compare` (Task 1).

- [ ] **Step 1: Write the test**

Add to `tests/test_num.ml`:

```ocaml
let test_real_roots_epsilon_ladder () =
  (* #23: previously 0.07s → 0.39s → 3.47s → >150s down this ladder. *)
  let rec strictly_ascending = function
    | a :: (b :: _ as r) -> Num.compare a b < 0 && strictly_ascending r
    | _ -> true
  in
  List.iter
    (fun (name, eps) ->
      let coeffs =
        [| Num.of_q (Q.of_string eps); Num.zero; Num.of_int (-5);
           Num.zero; Num.one |]
      in
      let t0 = Unix.gettimeofday () in
      let roots = Num.real_roots coeffs in
      let dt = Unix.gettimeofday () -. t0 in
      Alcotest.(check int) (name ^ ": four roots") 4 (List.length roots);
      Alcotest.(check bool) (name ^ ": strictly ascending") true
        (strictly_ascending roots);
      Alcotest.(check bool)
        (Printf.sprintf "%s: under 1s (took %.2fs)" name dt)
        true (dt < 1.0))
    [ ("eps=5e-8", "1/20000000");
      ("eps=5e-12", "1/200000000000");
      ("eps=5e-16", "1/2000000000000000");
      ("eps=5e-20", "1/20000000000000000000") ]
```

Register it (the ladder does real work — mark it `Slow` so `-q` runs skip it):

```ocaml
Alcotest.test_case "real_roots epsilon ladder (#23)" `Slow
  test_real_roots_epsilon_ladder;
```

- [ ] **Step 2: Run the full suite**

Run: `dune runtest 2>&1 | tail -5`
Expected: all pass, ladder well under budget on every rung.

- [ ] **Step 3: Integration sanity — the probe baseline is unchanged**

Run: `timeout 30 dune exec scratch/probe.exe 2>&1 | head -1`
Expected: `axiom7, rational coords: 0.000s, 1 creases` (the rational fast path
did not regress; the algebraic-input cases still time out — that is Slice 2's
job, do not wait for them: Ctrl-C/timeout is fine).

- [ ] **Step 4: Commit**

```bash
git add tests/test_num.ml
git commit -m "test(num): epsilon-ladder regression for close-root isolation (#23)"
```

---

## Out of scope (Slice 2, planned separately)

Squarefree-generator `Field` invariant, subresultant PRS for `Poly.gcd`/
`Poly.inv_mod`, pairwise memoized field joins, Alg ≅ Field routing, and the
#33 benchmark verdict — see the spec's Slice 2 sections.
