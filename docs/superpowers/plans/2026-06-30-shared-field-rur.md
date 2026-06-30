# Shared-field RUR `Field` representation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make exact arithmetic among algebraic numbers that share a field cheap, so folding the paper along an irrational axiom-7 crease (∛2 doubling the cube, trisection) completes in milliseconds instead of exploding to multi-minute resultant chains.

**Architecture:** Add a `Field { gen; coords }` constructor to `Num.t` representing `coords(α)` for a shared generator α carrying its **irreducible** minimal polynomial μ. Arithmetic on two `Field`s with the same generator stays in ℚ(α) (polynomial ops mod μ — no resultants, bounded degree); everything else falls back to the existing proven `Alg` resultant path. `real_roots` returns factorable roots as `Field`. The `Geom`/`Fold_state`/`eval` layer is untouched.

**Tech Stack:** OCaml, dune, zarith (`Q`/`Z`), `Poly` (`lib/poly.ml`, `Q.t array` low-first), `Num` (`lib/num.ml`), Alcotest (`tests/test_beloch.ml`).

## Global Constraints

- **Exactness:** all values are exact `Q`/`Z`. Floats appear ONLY in `Num.to_float` (output-only). No float influences a value or a branch.
- **Safety invariant:** `Field` is a value-preserving FAST PATH over the proven `Alg` resultant path. Correctness must never depend on the fast path firing — mixed/cross-field/uncertain cases fall back to `Alg`. A fast-path bug may be slow, never wrong.
- **Irreducible μ:** a `Field`'s `gen.mu` is always the *irreducible* minimal polynomial of α (degree ≥ 2; α irrational). Rational/zero values are never `Field` — they canonicalize to `Rat` (via the `mk_field` smart constructor).
- **Reduced coords invariant:** `coords` is always kept reduced mod μ (`deg coords < deg μ`). The smart constructor enforces canonical form.
- **No regressions; pristine output:** the project builds with **fatal warnings** — a non-exhaustive match or an unused binding fails the build. Adding the `Field` constructor makes every `match` on `Num.t` non-exhaustive until a `Field` arm is added. Full existing suite stays green at every task boundary.
- **Branch:** `feat/axiom7` (this work builds on `real_roots` from the axiom-7 slice). Conventional commits, one per task.

---

## File Structure

- **`lib/poly.ml`** — add `inv_mod : t -> t -> t` (polynomial inverse modulo an irreducible polynomial, via extended Euclid). One small, pure addition.
- **`lib/num.ml`** — the bulk: the `gen` type and `Field` constructor; the smart constructor `mk_field`; `same_gen`; the `Field → Alg` fallback `to_alg`; `Field` arms on every function matching `Num.t` (`neg`, `sign`, `add`, `sub`, `mul`, `inv`, `div`, `to_float`, `enclosure`, `enclosure_tight`, `defpoly`); the interval-evaluation helper `poly_interval`; the factorization helper `minimal_poly_in`; and wiring `real_roots` to upgrade factorable roots to `Field`.
- **`tests/test_beloch.ml`** — unit tests (field arithmetic, sign/inv, factorization, interop), the no-blowup geometry guard, and the end-to-end doubling-the-cube fold.
- **Everything else unchanged** — `Geom`, `Fold_state`, `Fold_emit`, `eval` consume `Num` through its preserved interface.

A note on `num.ml` structure: `neg`, `sign`, `add`, `sub`, `mul`, `inv`, `div` are currently separate top-level `let`s. The `Field → Alg` fallback `to_alg` must call `add`/`mul`, and `add`/`mul`'s fallback arms must call `to_alg` — a cycle. Resolve it by grouping these into ONE mutually-recursive block: `let rec neg … and sign … and add … and sub … and mul … and inv … and div … and to_alg …`. `mk_field`, `same_gen`, `poly_interval` are pure/earlier-dependency-only and stay plain `let`s before the group.

---

## SLICE — `Field` representation

### Task 1: `Field` type + same-field add/sub/mul/neg + fallback wiring

**Files:**
- Modify: `lib/num.ml` (type `t`; new `gen` type; `mk_field`; `same_gen`; restructure the arithmetic into a `let rec … and …` group with `to_alg`; `Field` arms on all `Num.t` matches)
- Test: `tests/test_beloch.ml` (new `field` group)

**Interfaces:**
- Produces (internal to `Num`, used by later tasks):
  - `type gen = { mu : Poly.t; lo : Q.t; hi : Q.t }`
  - `t` gains `| Field of { gen : gen; coords : Poly.t }`
  - `val mk_field : gen -> Poly.t -> t` (smart constructor; canonicalizes to `zero`/`Rat`/`Field`)
  - `val same_gen : gen -> gen -> bool`
  - `to_alg : t -> t` (Field→Alg fallback; identity on Rat/Alg) — inside the rec group
- The public signature of `Num` is otherwise unchanged.

- [ ] **Step 1: Write failing tests** in `tests/test_beloch.ml` (new `"field"` group). These construct `Field` values directly via a small local helper. Since `gen`/`Field` are not exposed in a `.mli` (check: if `lib/num.mli` exists and hides the constructor, these tests can't build `Field` directly — in that case test via `real_roots` in Task 3 instead and make Task 1's tests assert through public ops; first run `ls lib/num.mli` and read it. If no `.mli`, the constructor is accessible as `Num.Field`).

Assuming no restrictive `.mli` (the project has none for `Num` historically — verify):
```ocaml
let test_field_mul_cube () =
  (* α = ∛2 : root of x³−2 in (1,2). α·α·α canonicalizes to Rat 2. *)
  let mu = Poly.of_list [ Q.of_int (-2); Q.zero; Q.zero; Q.one ] in
  let gen = { Num.mu; lo = Q.one; hi = Q.of_int 2 } in
  let alpha = Num.Field { gen; coords = Poly.of_list [ Q.zero; Q.one ] } in
  let a2 = Num.mul alpha alpha in
  (* α² is still a Field with coords x² *)
  Alcotest.(check bool) "α² is irrational" true (Num.sign (Num.sub a2 (Num.of_int 1)) <> 0);
  let a3 = Num.mul a2 alpha in
  Alcotest.(check bool) "α³ = 2 exactly" true (Num.equal a3 (Num.of_int 2))

let test_field_add_canonicalizes () =
  let mu = Poly.of_list [ Q.of_int (-2); Q.zero; Q.zero; Q.one ] in
  let gen = { Num.mu; lo = Q.one; hi = Q.of_int 2 } in
  let alpha = Num.Field { gen; coords = Poly.of_list [ Q.zero; Q.one ] } in
  (* α + (−α) = 0 (canonicalizes to Rat 0) *)
  Alcotest.(check bool) "α−α = 0" true (Num.equal (Num.sub alpha alpha) Num.zero);
  (* α + 1 then − 1 = α *)
  Alcotest.(check bool) "α+1−1 = α" true
    (Num.equal (Num.sub (Num.add alpha Num.one) Num.one) alpha)
```

- [ ] **Step 2: Run, expect FAIL** — `dune test 2>&1 | head -20` → `Unbound constructor Num.Field` / `Unbound record field mu`.

- [ ] **Step 3: Add the `gen` type and `Field` constructor** in `lib/num.ml`. Change the `type t` declaration (top of file, currently `type t = Rat of Q.t | Alg of { poly; lo; hi }`) to:

```ocaml
type t =
  | Rat of Q.t
  | Alg of { poly : Poly.t; lo : Q.t; hi : Q.t }
  | Field of { gen : gen; coords : Poly.t }

and gen = { mu : Poly.t; lo : Q.t; hi : Q.t }
```

- [ ] **Step 4: Add `mk_field` and `same_gen`** (plain `let`s, after `zero`/`one`/`of_q`, before the arithmetic group). `mk_field` canonicalizes; `same_gen` is conservative structural equality.

```ocaml
(* generators are equal iff their (irreducible) μ and isolating interval match.
   Distinct roots of the same μ have distinct intervals, so are never merged. *)
let same_gen (a : gen) (b : gen) : bool =
  Q.equal a.lo b.lo && Q.equal a.hi b.hi
  && Array.length a.mu = Array.length b.mu
  && Array.for_all2 Q.equal a.mu b.mu

(* smart constructor: a Field value is canonical only when irrational, so a value
   that reduces to a constant collapses to Rat (and 0 to Rat 0). coords is
   normalized (trailing zeros dropped); callers guarantee it is already reduced
   mod μ (degree < deg μ). *)
let mk_field (gen : gen) (coords : Poly.t) : t =
  let c = Poly.normalize coords in
  match Poly.degree c with
  | d when d < 0 -> zero
  | 0 -> Rat c.(0)
  | _ -> Field { gen; coords = c }
```

- [ ] **Step 5: Add the interval-eval helper `poly_interval`** (plain `let`, before the group; used by `sign`/`to_float` in Task 2 but harmless to add now — if fatal-unused-warning fires because nothing uses it yet, instead add it in Task 2; prefer adding it in Task 2 to avoid an unused-value error). **Skip in Task 1.**

- [ ] **Step 6: Restructure the arithmetic into a recursive group and add `Field` arms.** Convert the existing separate `let neg`, `let rec sign`, `let add`, `let sub`, `let mul`, `let inv`, `let div` into one `let rec … and …` block and add `to_alg`. Add `Field` arms:

```ocaml
let rec neg (x : t) : t =
  match x with
  | Rat q -> Rat (Q.neg q)
  | Field { gen; coords } -> mk_field gen (Poly.neg coords)
  | Alg { poly; lo; hi } ->
      (* root of poly(−x); interval is the reflection  (EXISTING BODY, unchanged) *)
      let n = Array.length poly in
      let p' =
        Poly.of_list
          (List.init n (fun i -> if i mod 2 = 0 then poly.(i) else Q.neg poly.(i)))
      in
      make p' (Q.neg hi) (Q.neg lo)

and sign (x : t) : int =
  match x with
  | Rat q -> Q.sign q
  | Field _ -> sign (to_alg x)            (* fallback in Task 1; fast path in Task 2 *)
  | Alg { poly; lo; hi } ->
      if Q.sign lo > 0 then 1
      else if Q.sign hi < 0 then -1
      else let lo, hi = refine_alg poly lo hi in sign (Alg { poly; lo; hi })

and add (x : t) (y : t) : t =
  match (x, y) with
  | Rat a, Rat b -> Rat (Q.add a b)
  | Field a, Field b when same_gen a.gen b.gen ->
      mk_field a.gen (Poly.add a.coords b.coords)
  | Field a, Rat q | Rat q, Field a ->
      mk_field a.gen (Poly.add a.coords (Poly.const q))
  | (Field _, _) | (_, Field _) -> add (to_alg x) (to_alg y)   (* cross-field/mixed fallback *)
  | Alg a, Rat q | Rat q, Alg a -> shift_alg a.poly a.lo a.hi q
  | Alg _, Alg _ ->
      let r = defpoly_sum x y in
      let enclose w =
        let xl, xh = enclosure_tight x (Q.div w two_q) in
        let yl, yh = enclosure_tight y (Q.div w two_q) in
        (Q.add xl yl, Q.add xh yh)
      in
      select_root r enclose

and sub (x : t) (y : t) : t = add x (neg y)

and mul (x : t) (y : t) : t =
  (* product_enclose / even_poly_half stay as today; only the dispatch gains Field arms *)
  let product_enclose x y w = (* EXISTING body unchanged *) ... in
  match (x, y) with
  | Rat a, Rat b -> Rat (Q.mul a b)
  | _ when sign x = 0 || sign y = 0 -> zero
  | Field a, Field b when same_gen a.gen b.gen ->
      mk_field a.gen (Poly.rem (Poly.mul a.coords b.coords) a.gen.mu)
  | Field a, Rat q | Rat q, Field a -> mk_field a.gen (Poly.scale q a.coords)
  | (Field _, _) | (_, Field _) -> mul (to_alg x) (to_alg y)
  | Alg a, Rat q | Rat q, Alg a -> scale_alg a.poly a.lo a.hi q
  | Alg ax, Alg ay when (* EXISTING squaring-shortcut guard, unchanged *) ... -> (* EXISTING *) ...
  | _ -> let r = defpoly_prod x y in select_root r (product_enclose x y)

and inv (x : t) : t =
  match x with
  | Rat q -> if Q.equal q Q.zero then invalid_arg "Num.inv: zero" else Rat (Q.inv q)
  | Field _ -> inv (to_alg x)              (* fallback in Task 1; fast path in Task 2 *)
  | Alg _ -> (* EXISTING body unchanged *) ...

and div (x : t) (y : t) : t = mul x (inv y)

(* Field → Alg: evaluate coords at α (an Alg built from μ + interval) using the
   existing resultant arithmetic. The slow fallback; correctness baseline. *)
and to_alg (x : t) : t =
  match x with
  | Field { gen; coords } ->
      let alpha = make gen.mu gen.lo gen.hi in
      let acc = ref zero in
      for i = Poly.degree coords downto 0 do
        acc := add (mul !acc alpha) (of_q coords.(i))
      done;
      !acc
  | _ -> x
```

**Important:** preserve the EXISTING bodies of the `Alg` arms exactly (the `...` above marks where today's code stays). Only the dispatch gains `Field` arms and the functions join the `let rec … and …` group. `Poly.const` must exist (`poly.ml:17` — it does).

- [ ] **Step 7: Add `Field` fallback arms to the remaining `Num.t` matches** so the build stays exhaustive: `enclosure`, `enclosure_tight`, `defpoly`, `to_float`. Each gets `| Field _ -> <f> (to_alg x)`:
  - `enclosure`: `| Field _ -> enclosure (to_alg x)`
  - `enclosure_tight`: `| Field _ -> enclosure_tight (to_alg x) w`
  - `defpoly`: `| Field _ -> defpoly (to_alg x)`
  - `to_float`: `| Field _ -> to_float (to_alg x)` (fast path in Task 2)
  `compare`/`equal` are defined as `sign (sub …)`, so they need no new arm. Grep for any other `match … with` / `function` on a `Num.t` value and add a `Field _ -> … (to_alg x)` arm; the build's fatal non-exhaustive-match error will point you at any you missed.

- [ ] **Step 8: Run, expect PASS** — `dune test 2>&1 | tail -20` → green incl. the two field tests; no regressions; pristine.

- [ ] **Step 9: Register tests + commit**
```bash
git add lib/num.ml tests/test_beloch.ml
git commit -m "feat(num): Field representation — exact same-field add/sub/mul over a shared generator"
```

---

### Task 2: fast `sign`, `inv`/`div`, `to_float` for `Field`; `Poly.inv_mod`

**Files:**
- Modify: `lib/poly.ml` (add `inv_mod`)
- Modify: `lib/num.ml` (add `poly_interval`; replace the `Field` fallback arms of `sign`, `inv`, `to_float` with fast field versions)
- Test: `tests/test_beloch.ml` (`field` group)

**Interfaces:**
- Consumes: Task 1's `gen`/`Field`/`mk_field`/`same_gen`.
- Produces: `Poly.inv_mod : t -> t -> t`; fast `Num.sign`/`inv`/`div`/`to_float` on `Field` (no `to_alg` conversion).

- [ ] **Step 1: Write failing tests** (`field` group):
```ocaml
let test_field_sign_and_inv () =
  (* α = ∛2 ≈ 1.2599 : sign(α−1) = +, sign(α−2) = −, α·α⁻¹ = 1. *)
  let mu = Poly.of_list [ Q.of_int (-2); Q.zero; Q.zero; Q.one ] in
  let gen = { Num.mu; lo = Q.one; hi = Q.of_int 2 } in
  let alpha = Num.Field { gen; coords = Poly.of_list [ Q.zero; Q.one ] } in
  Alcotest.(check int) "sign(α−1)" 1 (Num.sign (Num.sub alpha Num.one));
  Alcotest.(check int) "sign(α−2)" (-1) (Num.sign (Num.sub alpha (Num.of_int 2)));
  Alcotest.(check bool) "α·α⁻¹ = 1" true (Num.equal (Num.mul alpha (Num.inv alpha)) Num.one);
  Alcotest.(check (float 1e-9)) "to_float α" 1.2599210498948732 (Num.to_float alpha)

let test_field_compare () =
  (* β = 2−√3 ≈ 0.2679 (root of t²−4t+1 in (0,1)); compare with 1/4 and 1/3. *)
  let mu = Poly.of_list [ Q.one; Q.of_int (-4); Q.one ] in
  let gen = { Num.mu; lo = Q.zero; hi = Q.one } in
  let beta = Num.Field { gen; coords = Poly.of_list [ Q.zero; Q.one ] } in
  Alcotest.(check bool) "β > 1/4" true (Num.compare beta (Num.of_q (Q.of_ints 1 4)) > 0);
  Alcotest.(check bool) "β < 1/3" true (Num.compare beta (Num.of_q (Q.of_ints 1 3)) < 0)
```

- [ ] **Step 2: Run, expect FAIL/PASS-via-fallback** — these may already PASS via Task 1's `to_alg` fallback (the fallback is correct, just slow). That's fine: the point of Task 2 is to make them fast and direct. To get a real RED, first add `Poly.inv_mod` usage; otherwise treat Step 2 as "confirm they pass (possibly slowly) then make them fast and still green." Run `dune test 2>&1 | tail -20`.

- [ ] **Step 3: Add `Poly.inv_mod`** in `lib/poly.ml` (after `gcd`/`squarefree_part`):
```ocaml
(* inverse of a modulo m, where m is irreducible over ℚ and a ≢ 0 (mod m):
   the unique u with deg u < deg m and u·a ≡ 1 (mod m). Extended Euclid:
   maintain (r, s) with s·a ≡ r (mod m); gcd is a nonzero constant since m is
   irreducible and a ≢ 0. *)
let inv_mod (a : t) (m : t) : t =
  let rec ext r0 s0 r1 s1 =
    if is_zero r1 then (r0, s0)
    else
      let q, r = divmod r0 r1 in
      ext r1 s1 r (sub s0 (mul q s1))
  in
  let g, s = ext m zero a (of_list [ Q.one ]) in
  rem (scale (Q.inv (leading g)) s) m
```

- [ ] **Step 4: Add `poly_interval`** (plain `let` in `num.ml`, before the arithmetic group):
```ocaml
(* rational enclosure of p over x ∈ [lo,hi], by interval Horner. *)
let poly_interval (p : Poly.t) (lo : Q.t) (hi : Q.t) : Q.t * Q.t =
  let imul (a, b) (c, d) =
    let xs = [ Q.mul a c; Q.mul a d; Q.mul b c; Q.mul b d ] in
    (List.fold_left Q.min (List.hd xs) (List.tl xs),
     List.fold_left Q.max (List.hd xs) (List.tl xs))
  in
  let iadd (a, b) (c, d) = (Q.add a c, Q.add b d) in
  let acc = ref (Q.zero, Q.zero) in
  for i = Poly.degree p downto 0 do
    acc := iadd (imul !acc (lo, hi)) (p.(i), p.(i))
  done;
  !acc
```

- [ ] **Step 5: Replace the `Field` arms** of `sign`, `inv`, `to_float` with fast versions.

`sign` (a canonical `Field` is always nonzero ⇒ refinement terminates):
```ocaml
  | Field { gen; coords } ->
      let rec go lo hi =
        let vlo, vhi = poly_interval coords lo hi in
        if Q.sign vlo > 0 then 1
        else if Q.sign vhi < 0 then -1
        else let lo, hi = refine_alg gen.mu lo hi in go lo hi
      in
      go gen.lo gen.hi
```
`inv` (value ≠ 0 guaranteed):
```ocaml
  | Field { gen; coords } -> mk_field gen (Poly.inv_mod coords gen.mu)
```
`to_float`:
```ocaml
  | Field { gen; coords } ->
      let w = Q.of_ints 1 1000000000000 in
      let rec narrow lo hi =
        if Q.compare (Q.sub hi lo) w < 0 then (lo, hi)
        else let lo, hi = refine_alg gen.mu lo hi in narrow lo hi
      in
      let lo, hi = narrow gen.lo gen.hi in
      Q.to_float (Poly.eval coords (Q.div (Q.add lo hi) two_q))
```

- [ ] **Step 6: Run, expect PASS** — `dune test 2>&1 | tail -20` → green incl. the two new tests; no regressions; pristine.

- [ ] **Step 7: Register tests + commit**
```bash
git add lib/poly.ml lib/num.ml tests/test_beloch.ml
git commit -m "feat(num): fast Field sign/inv/to_float via arithmetic mod the minimal polynomial"
```

---

### Task 3: factorization + `real_roots` returns `Field`

**Files:**
- Modify: `lib/num.ml` (`minimal_poly_in`; upgrade each `real_roots` result)
- Test: `tests/test_beloch.ml` (`field` group)

**Interfaces:**
- Consumes: Task 1/2 `Field`. Existing `rational_roots_in`, `Poly.cauchy_bound`, `Poly.divmod`, `Poly.monic`, `make`.
- Produces: `real_roots` returns `Field` for roots with an obtainable irreducible μ; `Rat`/`Alg` otherwise (values + ordering unchanged).

- [ ] **Step 1: Write failing tests** (`field` group):
```ocaml
let test_real_roots_returns_field_cube () =
  (* z³−2 → the single real root is ∛2, now a Field; (∛2)³ = 2 fast. *)
  match Num.real_roots [| Num.of_int (-2); Num.zero; Num.zero; Num.one |] with
  | [ v ] ->
      Alcotest.(check bool) "is Field" true (match v with Num.Field _ -> true | _ -> false);
      Alcotest.(check bool) "v³ = 2" true (Num.equal (Num.mul v (Num.mul v v)) (Num.of_int 2))
  | _ -> Alcotest.fail "expected one real root"

let test_real_roots_field_and_rat () =
  (* t³−3t²−3t+1 = (t+1)(t²−4t+1): roots −1 (Rat), 2−√3, 2+√3 (Field, μ=t²−4t+1). *)
  let roots = Num.real_roots [| Num.one; Num.of_int (-3); Num.of_int (-3); Num.one |] in
  Alcotest.(check int) "three roots" 3 (List.length roots);
  (match roots with
   | [ a; b; c ] ->
       Alcotest.(check bool) "−1 is Rat" true (match a with Num.Rat _ -> true | _ -> false);
       Alcotest.(check bool) "first = −1" true (Num.equal a (Num.of_int (-1)));
       Alcotest.(check bool) "2−√3 is Field" true (match b with Num.Field _ -> true | _ -> false);
       Alcotest.(check bool) "2+√3 is Field" true (match c with Num.Field _ -> true | _ -> false);
       (* each irrational root satisfies t²−4t+1 = 0 *)
       List.iter (fun t ->
         let f = Num.add (Num.sub (Num.mul t t) (Num.mul (Num.of_int 4) t)) Num.one in
         Alcotest.(check bool) "root of t²−4t+1" true (Num.equal f Num.zero)) [ b; c ]
   | _ -> Alcotest.fail "expected 3 roots")
```

- [ ] **Step 2: Run, expect FAIL** — roots come back as `Alg`, so the `match … Field` assertions fail.

- [ ] **Step 3: Add `minimal_poly_in`** (plain `let` in `num.ml`, after `rational_roots_in`, before `make` is fine since it only uses `Poly` + `rational_roots_in`):
```ocaml
(* The irreducible minimal polynomial of the unique root of squarefree p in
   (lo,hi), when it can be produced elementarily: divide out rational-root linear
   factors; what remains, if degree 2 or 3 with no rational root, is irreducible
   (a quadratic/cubic with no rational root has no ℚ-factorization). Returns None
   for a composite remainder of degree ≥ 4 (caller keeps the root as Alg). *)
let minimal_poly_in (p : Poly.t) (_lo : Q.t) (_hi : Q.t) : Poly.t option =
  let b = Poly.cauchy_bound p in
  let rats = rational_roots_in p (Q.neg b) b in
  let rest =
    List.fold_left
      (fun acc r -> fst (Poly.divmod acc (Poly.of_list [ Q.neg r; Q.one ])))
      p rats
  in
  let rest = Poly.monic rest in
  let d = Poly.degree rest in
  if d = 2 || d = 3 then Some rest else None
```

- [ ] **Step 4: Upgrade `real_roots` results to `Field`.** In `real_roots` (`lib/num.ml`), define a local `upgrade` and map it over the returned roots in BOTH branches (the rational fast path and the algebraic-coefficient path):
```ocaml
  let upgrade (v : t) : t =
    match v with
    | Alg { poly; lo; hi } -> (
        match minimal_poly_in poly lo hi with
        | Some mu -> Field { gen = { mu; lo; hi }; coords = Poly.of_list [ Q.zero; Q.one ] }
        | None -> v)
    | _ -> v
  in
```
Apply it where each branch builds its result list — wrap the final `|> List.map (fun (lo, hi) -> make p lo hi)` / the `filter_map … make r lo hi` outputs with `|> List.map upgrade` (place `upgrade` AFTER the existing `List.sort compare`, or map before sorting — `upgrade` preserves values so order is unaffected; mapping before the sort is fine). Both branches must apply it.

Rationale notes for the implementer: `make` already returns `Rat` for rational roots, so `upgrade` only ever sees `Alg` (irrational); the interval `(lo,hi)` that isolated the root against the squarefree `poly` still isolates the single root of the factor `mu` (μ's roots ⊆ poly's roots), so it is a valid `gen` interval.

- [ ] **Step 5: Run, expect PASS** — `dune test 2>&1 | tail -20` → green incl. the two new tests; no regressions. **Watch the runtime:** the existing `real_roots` tests (e.g. casus-irreducibilis, ~33–89s) should not get slower — `upgrade` is cheap (one factorization). If any got slower, investigate.

- [ ] **Step 6: Register tests + commit**
```bash
git add lib/num.ml tests/test_beloch.ml
git commit -m "feat(num): real_roots upgrades factorable roots to the Field representation"
```

---

### Task 4: interop + cross-field fallback correctness

**Files:**
- Test: `tests/test_beloch.ml` (`field` group)
- (No production code expected — this task verifies the Task 1 fallback paths. If a test fails, fix the relevant `Field` arm in `lib/num.ml`.)

**Interfaces:** consumes everything above.

- [ ] **Step 1: Write tests** proving mixed/cross-field operations equal the all-`Alg` computation:
```ocaml
let test_field_interop_matches_alg () =
  (* ∛2 (Field) and √2 (Alg) live in different fields → mul/add must fall back and
     match the value computed entirely via Alg arithmetic. *)
  let cbrt2 = match Num.real_roots [| Num.of_int (-2); Num.zero; Num.zero; Num.one |] with
    | [ v ] -> v | _ -> Alcotest.fail "cbrt2" in
  let sqrt2 = Num.sqrt (Num.of_int 2) in
  (* product ∛2·√2 and sum ∛2+√2, via the public ops (Field×Alg → fallback) *)
  let prod = Num.mul cbrt2 sqrt2 and sum = Num.add cbrt2 sqrt2 in
  (* cross-check: (∛2·√2)^6 = 2²·2³ = 4·8 = 32; ((∛2+√2)−√2) = ∛2 *)
  let p6 = let p2 = Num.mul prod prod in Num.mul p2 (Num.mul p2 p2) in
  Alcotest.(check bool) "(∛2·√2)^6 = 32" true (Num.equal p6 (Num.of_int 32));
  Alcotest.(check bool) "(∛2+√2)−√2 = ∛2" true (Num.equal (Num.sub sum sqrt2) cbrt2)

let test_field_plus_rat () =
  let cbrt2 = match Num.real_roots [| Num.of_int (-2); Num.zero; Num.zero; Num.one |] with
    | [ v ] -> v | _ -> Alcotest.fail "cbrt2" in
  (* (∛2 + 3 − 3) = ∛2 stays in the same field (Field + Rat fast path) *)
  Alcotest.(check bool) "Field+Rat round-trips" true
    (Num.equal (Num.sub (Num.add cbrt2 (Num.of_int 3)) (Num.of_int 3)) cbrt2)
```

- [ ] **Step 2: Run** — `dune test 2>&1 | tail -20`. Expect PASS (the fallback was built in Task 1). If `(∛2+√2)−√2 = ∛2` fails, the cross-field fallback isn't round-tripping — debug the `Field`/`Alg` mixed arms of `add`/`mul`.

- [ ] **Step 3: Commit**
```bash
git add tests/test_beloch.ml
git commit -m "test(num): interop — Field with Alg/Rat matches the Alg-only computation"
```

---

### Task 5: the payoff — no-blowup geometry + end-to-end doubling-the-cube fold

**Files:**
- Test: `tests/test_beloch.ml` (`geom` + `e2e` groups)
- Create: `examples/double-cube.bel`
- (No production code — `Geom`/`eval` are unchanged; this proves the speedup.)

**Interfaces:** consumes the whole slice through the public `Num`/`Geom`/`Beloch` APIs.

- [ ] **Step 1: Write the no-blowup geometry guard.** Use the configuration that previously did NOT finish in 25 minutes (`p=(0,1), d:y=0, q=(1,1), e:x=0` → an irrational crease) and assert it now completes and the crease satisfies both fold conditions exactly. Because `real_roots` now returns the landing parameter as a `Field`, `beloch7_creases`' `perpendicular_bisector` produces crease coords in ℚ(t), and `reflect_point`/`side_of_line` stay in ℚ(t) — fast.
```ocaml
let test_axiom7_irrational_crease_folds_fast () =
  let p = pt (q 0) (q 1) and qq = pt (q 1) (q 1) in
  let d = { Geom.a = q 0; b = q 1; c = q 0 } in   (* y = 0 *)
  let e = { Geom.a = q 1; b = q 0; c = q 0 } in   (* x = 0 *)
  let creases = Geom.beloch7_creases p d qq e in
  Alcotest.(check bool) "≥1 crease" true (List.length creases >= 1);
  List.iter (fun c ->
    Alcotest.(check int) "p lands on d" 0 (Geom.side_of_line d (Geom.reflect_point c p));
    Alcotest.(check int) "q lands on e" 0 (Geom.side_of_line e (Geom.reflect_point c qq)))
    creases
```
Keep this test `Quick`. If it does not complete in well under a second, the `Field` fast path is not engaging for the crease coordinates — investigate (likely a generator-identity mismatch so `same_gen` never fires, or a coordinate that fell back to `Alg`). Do NOT mark it `Slow` to hide a regression.

- [ ] **Step 2: Run, expect PASS fast** — `dune exec tests/test_beloch.exe -- test geom 2>&1 | tail` (or the focused Alcotest selector the suite uses). Confirm it finishes immediately. Then the trisection/cube configurations as a number check is already covered; this is the geometry-level proof.

- [ ] **Step 3: Write the end-to-end doubling-the-cube example.** Create `examples/double-cube.bel`. Use a corner config whose axiom-7 cubic encodes ∛2 and whose crease is irrational, expressed with unit-square corners/edges. A workable precrease form (verify it runs):
```
; doubling the cube — the cubic Beloch fold (axiom 7) yields an irrational crease
; in ℚ(∛2); with the shared-field kernel this folds in milliseconds.
paper square
--bot: through .a .b      ; y = 0
--left: through .a .d     ; x = 0
map .d onto --bot and .c onto --left
```
(If this exact config is degenerate or multi-crease-needing-`toward`, adjust the lines/points so it is a single irrational crease; the goal is one runnable irrational-crease axiom-7 fold. Find a working form empirically — run it through the CLI.)

- [ ] **Step 4: Write the e2e test** asserting it parses, evaluates, and emits fast with the `axiom7` tag (mirror the axiom-6 e2e assertion style):
```ocaml
let test_e2e_double_cube_folds () =
  let json = Beloch.fold_string ~filename:"double-cube.bel" (read_example "double-cube.bel") in
  Alcotest.(check bool) "axiom7 emitted" true
    (try ignore (Str.search_forward (Str.regexp_string "axiom7") json 0); true with Not_found -> false)
```
(Use whatever JSON/substring assertion the existing e2e tests use — check `test_e2e_*` around `tests/test_beloch.ml:357`.)

- [ ] **Step 5: Run, expect PASS fast** — `dune test 2>&1 | tail -20`. The whole suite stays green; the new e2e completes quickly (no multi-minute hang). Confirm the example runs from the CLI: `dune exec -- beloch examples/double-cube.bel | head -c 200` (use the project's real entrypoint).

- [ ] **Step 6: Register tests + commit**
```bash
git add tests/test_beloch.ml examples/double-cube.bel
git commit -m "test(geom): irrational axiom-7 crease folds in ℚ(α) — doubling the cube end to end"
```

---

## Self-Review (completed)

**Spec coverage:** `Field`/`gen` type + same-field add/sub/mul/neg + canonicalization → Task 1; fast sign/inv/div/to_float + `inv_mod` → Task 2; factorization (μ) + `real_roots` returns `Field` → Task 3; interop/fallback safety invariant → Tasks 1 (impl) + 4 (verification); the no-blowup payoff + e2e → Task 5; geometry layer untouched → no task modifies `Geom`/`eval` (Task 5 only reads them). Out-of-scope items (general factorization, D5, cross-field primitive element) are explicitly deferred.

**Placeholder scan:** the `...` markers in Task 1 Step 6 mean "keep the existing Alg-arm body verbatim" and are explicitly labelled as such — they are not new code to invent. Every new function (`mk_field`, `same_gen`, `to_alg`, `poly_interval`, `inv_mod`, `minimal_poly_in`, the `Field` arms, `upgrade`) is given in full. No TBD/TODO.

**Type consistency:** `gen = { mu; lo; hi }` and `Field of { gen; coords }` used identically across Tasks 1–5. `mk_field : gen -> Poly.t -> t`, `same_gen : gen -> gen -> bool`, `to_alg : t -> t`, `Poly.inv_mod : t -> t -> t`, `minimal_poly_in : Poly.t -> Q.t -> Q.t -> Poly.t option` are consistent between definition and use. `coords` is low-first `Poly.t` throughout.

**Known verification points for the implementer** (call out, don't hide): (1) whether `lib/num.mli` exists and hides the `Field` constructor (Task 1 Step 1 — if it does, direct-construction tests must instead route through `real_roots`, and the `.mli` needs the new public surface); (2) the exact `Field`-arm insertion points in `mul` (preserve the squaring-shortcut and `product_enclose`); (3) any additional `Num.t` match elsewhere in `num.ml` the fatal-non-exhaustive build flags (Task 1 Step 7); (4) the e2e `.bel` config may need empirical adjustment to a single irrational crease (Task 5 Step 3).

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-30-shared-field-rur.md`.
