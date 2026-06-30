# Axiom 7 (cubic Beloch fold) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship axiom 7 — fold one point onto a line while simultaneously folding a second point onto a second line — the cubic Beloch fold, the last Huzita-Justin axiom, including the deferred algebraic-coefficient root finder it needs.

**Architecture:** Two slices in one branch. **Slice 1** completes `Num.real_roots` for irrational (`Alg`) coefficients via a new multivariate-polynomial elimination module (`Mpoly`): manufacture a ℚ-superset polynomial `R(z)` by eliminating each coefficient's algebraic generator with Sylvester resultants, isolate `R`'s real roots, then certify each candidate by evaluating the original polynomial exactly (`Num.sign = 0`). **Slice 2** adds the surface: an `and` keyword, an AST node, a geometry routine that builds the common-tangent cubic in a landing parameter and calls `real_roots`, and an eval arm mirroring axiom 6.

**Tech Stack:** OCaml, dune, Menhir (`lib/parser.mly`), sedlex (`lib/lexer.ml`), zarith (`Q`/`Z`), Alcotest (`tests/test_beloch.ml`).

## Global Constraints

- **Exactness:** all geometry/number code is exact — `Num.t` / `Q.t` / `Z.t` only. Floats appear **only** in `Num.to_float`, output-only. Never compare or branch on floats.
- **Axiom numbering:** classic Huzita-Justin [justin1986 §8.1]. This is **axiom 7** = Hull O7 [hull2020:990]; provenance tag string is exactly `"axiom7"`. Hull's low-number scramble does not affect 7 (Hull and classic coincide at 6 and 7).
- **Citation discipline:** ground origami-math/algorithm claims to `refs/` by key + locator; new sources go in `paper/references.bib` + `bibliography.md` in the same change. `bpr2006`, `hull2020`, `justin1986` are already present.
- **Commits:** conventional-commit style, concise subject, one per task (or per coherent step group). Branch `feat/axiom7` off `main`.
- **No regressions:** the full existing suite (`dune test`) must stay green at every task boundary. Current baseline before this work: all tests pass on `main`.

---

## File Structure

- **Create `lib/mpoly.ml`** — sparse multivariate polynomials over ℚ in a fixed number of variables; Sylvester resultant eliminating one variable (entries are `Mpoly.t`, determinant by division-free Laplace expansion); conversion to a univariate `Poly.t`. One responsibility: the multivariate elimination algebra `Num.real_roots` needs.
- **Modify `lib/num.ml`** — replace the `failwith` in `real_roots` (`num.ml:308-319`) with the `Alg`-coefficient path built on `Mpoly`; add a small exact-evaluation helper.
- **Modify `lib/lexer.ml`** — add keyword `"and" → AND`.
- **Modify `lib/parser.mly`** — declare `AND`; add two `axiom:` productions for axiom 7.
- **Modify `lib/ast.ml`** — add the `MapBoth` axiom constructor.
- **Modify `lib/geom.ml`** — add `beloch7_creases`.
- **Modify `lib/eval.ml`** — add the `MapBoth` arm to `axis_of`.
- **Modify `tests/test_beloch.ml`** — unit + parse + eval + e2e tests; register in the suite list.
- **Modify `spec/SPECIFICATION.md`** — axiom 7 section + grammar; move axiom 7 from deferred to landed.
- **Create `notes/2026-06-30-axiom7.md`** — design journal entry.
- **Create `examples/beloch.bel`** — a runnable axiom-7 example.
- **Modify `tools/fold2svg.mjs`** — add the `axiom7` legend label.

If `lib/beloch.ml` is a dune facade that re-exports modules (`module X = X`), add `module Mpoly = Mpoly` there so the new module is visible under the library namespace; check `lib/beloch.ml` and match the existing pattern (see `antipatterns.md` on the facade).

---

## SLICE 1 — `Num.real_roots` for algebraic coefficients

### Task 1: `Mpoly` — multivariate polynomials + variable elimination

**Files:**
- Create: `lib/mpoly.ml`
- Modify: `lib/beloch.ml` (add `module Mpoly = Mpoly` if the facade pattern is used)
- Test: `tests/test_beloch.ml` (new `mpoly` test group)

**Interfaces:**
- Consumes: `Poly` (`Poly.t = Q.t array`, low-first), `Q`, `Z` (zarith).
- Produces:
  - `type t` (abstract sparse multivariate poly over ℚ; variables are `0 .. nvars-1`).
  - `val zero : t`
  - `val const : int -> Q.t -> t` (`const nvars q`)
  - `val var : int -> int -> t` (`var nvars i` = the monomial `x_i`)
  - `val add : t -> t -> t`
  - `val mul : t -> t -> t`
  - `val pow : t -> int -> t`
  - `val is_zero : t -> bool`
  - `val resultant : t -> t -> int -> t` (`resultant a b v` eliminates variable `v`; result has zero exponent in `v`)
  - `val to_poly_in : t -> int -> Poly.t` (collect ℚ coefficients in variable `v`; raises if any other variable has nonzero exponent)

- [ ] **Step 1: Write `lib/mpoly.ml`**

Monomials are `int array` (exponent per variable, fixed length = `nvars`). A polynomial is an assoc list `(mono, coeff)` with unique monomials and no zero coefficients. The determinant is computed by Laplace (cofactor) expansion, which uses only ring `+`, `-`, `*` — no division — so it is valid over this non-field ring. Only roots of the resultant matter downstream (spurious roots are filtered by exact evaluation), so overall sign/constant factors are irrelevant.

```ocaml
(** Sparse multivariate polynomials over ℚ in a fixed number of variables
    (indices 0 .. nvars-1). Built for Num.real_roots: it manufactures, by
    Sylvester-resultant elimination of each algebraic coefficient's generator, a
    ℚ-polynomial in the root variable whose real roots are a SUPERSET of the true
    roots (spurious conjugate roots are removed later by exact evaluation). Only
    the root set matters, so sign/constant factors are not tracked. Determinants
    use division-free Laplace expansion (the ring is not a field).
    Algorithms: [bpr2006 §4.2]. *)

type mono = int array (* exponents, length = nvars *)
type t = (mono * Q.t) list (* unique monomials, no zero coeffs *)

let mono_equal (a : mono) (b : mono) : bool =
  Array.length a = Array.length b
  && (let ok = ref true in
      Array.iteri (fun i e -> if e <> b.(i) then ok := false) a;
      !ok)

let zero : t = []
let is_zero (p : t) : bool = p = []

let const (nvars : int) (q : Q.t) : t =
  if Q.equal q Q.zero then [] else [ (Array.make nvars 0, q) ]

let var (nvars : int) (i : int) : t =
  let m = Array.make nvars 0 in
  m.(i) <- 1;
  [ (m, Q.one) ]

(* insert (m, c) into a polynomial, merging like monomials, dropping zeros *)
let add_term (p : t) (m : mono) (c : Q.t) : t =
  if Q.equal c Q.zero then p
  else
    let rec go = function
      | [] -> [ (m, c) ]
      | (m', c') :: rest ->
          if mono_equal m m' then
            let s = Q.add c' c in
            if Q.equal s Q.zero then rest else (m', s) :: rest
          else (m', c') :: go rest
    in
    go p

let add (p : t) (q : t) : t = List.fold_left (fun acc (m, c) -> add_term acc m c) p q
let neg (p : t) : t = List.map (fun (m, c) -> (m, Q.neg c)) p
let sub (p : t) (q : t) : t = add p (neg q)

let mul (p : t) (q : t) : t =
  List.fold_left
    (fun acc (mp, cp) ->
      List.fold_left
        (fun acc (mq, cq) ->
          let m = Array.mapi (fun i e -> e + mq.(i)) mp in
          add_term acc m (Q.mul cp cq))
        acc q)
    [] p

let one_of (nvars : int) : t = const nvars Q.one

let pow (p : t) (k : int) : t =
  (* requires k >= 0; p^0 needs an nvars to build `one`, so derive from p *)
  if k = 0 then
    match p with
    | (m, _) :: _ -> one_of (Array.length m)
    | [] -> [] (* 0^0 unused here *)
  else begin
    let r = ref p in
    for _ = 2 to k do
      r := mul !r p
    done;
    !r
  end

let degree_in (p : t) (v : int) : int =
  List.fold_left (fun acc (m, _) -> max acc m.(v)) 0 p

(* coefficients of p viewed as a univariate polynomial in variable v:
   result.(k) is the Mpoly coefficient of x_v^k, with x_v stripped. *)
let coeffs_in (p : t) (v : int) : t array =
  let d = degree_in p v in
  let out = Array.make (d + 1) zero in
  List.iter
    (fun (m, c) ->
      let k = m.(v) in
      let m' = Array.copy m in
      m'.(v) <- 0;
      out.(k) <- add_term out.(k) m' c)
    p;
  out

(* determinant of a square matrix of Mpoly by Laplace expansion along row 0.
   Division-free: valid over the (non-field) polynomial ring. n is small here. *)
let rec det (mat : t array array) : t =
  let n = Array.length mat in
  if n = 0 then [] (* unused *)
  else if n = 1 then mat.(0).(0)
  else begin
    let acc = ref zero in
    for j = 0 to n - 1 do
      let minor =
        Array.init (n - 1) (fun r ->
            Array.init (n - 1) (fun c ->
                mat.(r + 1).(if c < j then c else c + 1)))
      in
      let term = mul mat.(0).(j) (det minor) in
      acc := if j land 1 = 0 then add !acc term else sub !acc term
    done;
    !acc
  end

(* Sylvester resultant of a and b with respect to variable v. Mirrors the dense
   Sylvester layout of Poly.resultant, but matrix entries are Mpoly (in the
   remaining variables). Result has exponent 0 in v. *)
let resultant (a : t) (b : t) (v : int) : t =
  let ca = coeffs_in a v and cb = coeffs_in b v in
  let da = Array.length ca - 1 and db = Array.length cb - 1 in
  if da < 0 || db < 0 then zero
  else if da = 0 then pow ca.(0) db
  else if db = 0 then pow cb.(0) da
  else begin
    let n = da + db in
    (* ca/cb are low-first; Poly.resultant indexes high-first as p.(dp - j) *)
    let hi (c : t array) (deg : int) (k : int) : t = c.(deg - k) in
    let m = Array.make_matrix n n zero in
    for i = 0 to db - 1 do
      for j = 0 to da do
        m.(i).(i + j) <- hi ca da j
      done
    done;
    for i = 0 to da - 1 do
      for j = 0 to db do
        m.(db + i).(i + j) <- hi cb db j
      done
    done;
    det m
  end

(* Extract the univariate ℚ-polynomial in variable v; every other variable must
   have exponent 0 in every monomial. *)
let to_poly_in (p : t) (v : int) : Poly.t =
  let d = degree_in p v in
  let arr = Array.make (d + 1) Q.zero in
  List.iter
    (fun (m, c) ->
      Array.iteri
        (fun i e -> if i <> v && e <> 0 then invalid_arg "Mpoly.to_poly_in: residual variable")
        m;
      arr.(m.(v)) <- Q.add arr.(m.(v)) c)
    p;
  Poly.of_list (Array.to_list arr)
```

- [ ] **Step 2: Write failing tests in `tests/test_beloch.ml`** (new functions, registered in a `"mpoly"` group)

Add near the other `Poly`/`Num` tests. `q` (= `Num.of_int`) exists at the top of the file; for raw `Q` use `Q.of_int`.

```ocaml
let test_mpoly_resultant_constant_free () =
  (* Res_y(x - y, y^2 - 2) eliminates y; the result must vanish at x = ±√2,
     i.e. equal a nonzero scalar multiple of x^2 - 2. *)
  let nvars = 2 in
  (* variables: 0 = x, 1 = y *)
  let x = Mpoly.var nvars 0 and y = Mpoly.var nvars 1 in
  let a = Mpoly.sub x y in (* x - y *)
  let b = Mpoly.sub (Mpoly.mul y y) (Mpoly.const nvars (Q.of_int 2)) in (* y^2 - 2 *)
  let r = Mpoly.resultant a b 1 in
  let p = Mpoly.to_poly_in r 0 in
  (* p is c*(x^2 - 2) for some nonzero rational c; check its roots are ±√2 by
     evaluating sign at rationals bracketing √2 ≈ 1.4142 *)
  Alcotest.(check int) "deg 2" 2 (Poly.degree p);
  Alcotest.(check bool) "sign change across √2" true
    (Poly.sign_at p (Q.of_string "7/5") * Poly.sign_at p (Q.of_string "3/2") < 0)

let test_mpoly_two_var_elim () =
  (* Eliminate two independent generators y (y^2=2) and w (w^2=3) from
     P(x) = x - y - w. The result must vanish at x = √2 + √3 ≈ 3.146. *)
  let nvars = 3 in (* 0=x, 1=y, 2=w *)
  let x = Mpoly.var nvars 0 and y = Mpoly.var nvars 1 and w = Mpoly.var nvars 2 in
  let p = Mpoly.sub (Mpoly.sub x y) w in
  let my = Mpoly.sub (Mpoly.mul y y) (Mpoly.const nvars (Q.of_int 2)) in
  let mw = Mpoly.sub (Mpoly.mul w w) (Mpoly.const nvars (Q.of_int 3)) in
  let r1 = Mpoly.resultant p my 1 in
  let r2 = Mpoly.resultant r1 mw 2 in
  let poly = Mpoly.to_poly_in r2 0 in
  Alcotest.(check bool) "sign change across √2+√3" true
    (Poly.sign_at poly (Q.of_string "31/10") * Poly.sign_at poly (Q.of_string "32/10") < 0)
```

- [ ] **Step 3: Run tests, expect FAIL** (module/functions undefined)

Run: `dune test 2>&1 | head -40`
Expected: compile error / `Unbound module Mpoly` until `lib/mpoly.ml` and the facade entry exist; then the two tests run.

- [ ] **Step 4: Make them pass**

Implement `lib/mpoly.ml` (Step 1), add the facade entry if needed, register the two tests in the suite (`Alcotest.test_case` entries under a `"mpoly"` group added to the `Alcotest.run "beloch"` list).

Run: `dune test 2>&1 | tail -20`
Expected: PASS (all green, no regressions).

- [ ] **Step 5: Commit**

```bash
git add lib/mpoly.ml lib/beloch.ml tests/test_beloch.ml
git commit -m "feat(num): Mpoly — multivariate polynomials with Sylvester resultant elimination"
```

---

### Task 2: `Num.real_roots` — algebraic-coefficient path

**Files:**
- Modify: `lib/num.ml:308-319` (the `real_roots` function)
- Test: `tests/test_beloch.ml` (num group)

**Interfaces:**
- Consumes: `Mpoly` (Task 1), existing `Poly`, existing `Num` internals (`make`, `sign`, `compare`, `add`, `mul`, `defpoly`).
- Produces: `real_roots : Num.t array -> Num.t list` now total — handles `Alg` coefficients; signature unchanged.

The current body (`num.ml:308-319`) handles only rational coefficients and `failwith`s on `Alg`. Replace it. The rational fast-path is preserved (when every coefficient is `Rat`).

- [ ] **Step 1: Write failing tests** in `tests/test_beloch.ml` (num group)

```ocaml
let test_real_roots_one_generator () =
  (* z^3 - √2 = 0  → one real root (√2)^(1/3); cube it back to 2. *)
  let s2 = Num.sqrt (Num.of_int 2) in
  let roots = Num.real_roots [| Num.neg s2; Num.zero; Num.zero; Num.one |] in
  Alcotest.(check int) "one real root" 1 (List.length roots);
  let v = List.hd roots in
  let v6 = Num.mul (Num.mul v v) (Num.mul (Num.mul v v) (Num.mul v v)) in
  (* v^3 = √2  ⟹  v^6 = 2 *)
  Alcotest.(check bool) "v^6 = 2" true (Num.equal v6 (Num.of_int 2))

let test_real_roots_two_generators () =
  (* z - √2 - √3 = 0 → root √2+√3; verify (z - √2)^2 = 3 exactly. *)
  let s2 = Num.sqrt (Num.of_int 2) and s3 = Num.sqrt (Num.of_int 3) in
  let c0 = Num.neg (Num.add s2 s3) in
  let roots = Num.real_roots [| c0; Num.one |] in
  Alcotest.(check int) "one root" 1 (List.length roots);
  let v = List.hd roots in
  let t = Num.sub v s2 in
  Alcotest.(check bool) "(v-√2)^2 = 3" true (Num.equal (Num.mul t t) (Num.of_int 3))

let test_real_roots_casus_irreducibilis_irrational () =
  (* (z^3 - 3z - 1) scaled by √2: coefficients are irrational but the three real
     roots are unchanged (≈ -1.532, -0.347, 1.879). *)
  let s2 = Num.sqrt (Num.of_int 2) in
  let c k = Num.mul s2 (Num.of_int k) in
  let roots = Num.real_roots [| c (-1); c (-3); Num.zero; c 1 |] in
  Alcotest.(check int) "three real roots" 3 (List.length roots);
  (* ascending; check each satisfies z^3 - 3z - 1 = 0 exactly *)
  List.iter
    (fun z ->
      let z3 = Num.mul z (Num.mul z z) in
      let f = Num.sub (Num.sub z3 (Num.mul (Num.of_int 3) z)) Num.one in
      Alcotest.(check bool) "root of z^3-3z-1" true (Num.equal f Num.zero))
    roots;
  (* strictly ascending *)
  (match roots with
   | [ a; b; c ] ->
       Alcotest.(check bool) "ordered" true (Num.compare a b < 0 && Num.compare b c < 0)
   | _ -> Alcotest.fail "expected 3 roots")

let test_real_roots_rational_cube_root () =
  (* rational fast-path still works: z^3 - 2 → ∛2, and (∛2)^3 = 2. *)
  let roots = Num.real_roots [| Num.of_int (-2); Num.zero; Num.zero; Num.one |] in
  Alcotest.(check int) "one real root" 1 (List.length roots);
  let v = List.hd roots in
  Alcotest.(check bool) "v^3 = 2" true (Num.equal (Num.mul v (Num.mul v v)) (Num.of_int 2))
```

- [ ] **Step 2: Run, expect FAIL**

Run: `dune test 2>&1 | grep -A3 real_roots | head -30`
Expected: `test_real_roots_one_generator` etc. fail with the current `failwith "...deferred to the axiom 7 slice"`.

- [ ] **Step 3: Replace `real_roots` in `lib/num.ml`**

Replace the whole function at `num.ml:308-319` with:

```ocaml
(* Horner evaluation of Σ coeffs.(i)·zⁱ in exact Num arithmetic. *)
let eval_num (coeffs : t array) (z : t) : t =
  let acc = ref zero in
  for i = Array.length coeffs - 1 downto 0 do
    acc := add (mul !acc z) coeffs.(i)
  done;
  !acc

(* real roots, ascending, of Σ coeffs.(i)·zⁱ. Rational-coefficient fast path
   keeps axioms 1–6 cheap. For algebraic (Alg) coefficients: manufacture a
   ℚ-superset polynomial R(z) by eliminating each distinct Alg coefficient's
   generator with a Sylvester resultant (Mpoly), isolate R's real roots, then
   keep only those that are genuine roots of the original polynomial — certified
   by exact evaluation, sign = 0. [bpr2006 §§4.2, 10.2–10.3] *)
let real_roots (coeffs : t array) : t list =
  (* drop leading zero coefficients to find the true degree *)
  let n = ref (Array.length coeffs) in
  while !n > 0 && sign coeffs.(!n - 1) = 0 do
    decr n
  done;
  let coeffs = Array.sub coeffs 0 !n in
  let n = Array.length coeffs in
  if n <= 1 then [] (* zero polynomial or nonzero constant: no isolated roots *)
  else if Array.for_all (function Rat _ -> true | Alg _ -> false) coeffs then begin
    (* rational fast path (unchanged behaviour) *)
    let q_of = function Rat q -> q | Alg _ -> assert false in
    let p = Poly.of_list (Array.to_list (Array.map q_of coeffs)) in
    Poly.isolate_roots p |> List.map (fun (lo, hi) -> make p lo hi) |> List.sort compare
  end
  else begin
    (* assign a fresh generator variable to each distinct Alg coefficient.
       Variable 0 is z; generators are 1.. . Structurally-identical Alg values
       (same poly contents + same interval) share a variable to limit blow-up;
       treating them independently would also be correct (still a superset). *)
    let gens = ref [] (* (coeff, var_index, min_poly) in discovery order *) in
    let same a b =
      match (a, b) with
      | Alg x, Alg y ->
          Q.equal x.lo y.lo && Q.equal x.hi y.hi
          && Array.length x.poly = Array.length y.poly
          && Array.for_all2 Q.equal x.poly y.poly
      | _ -> false
    in
    Array.iter
      (fun c ->
        match c with
        | Rat _ -> ()
        | Alg a ->
            if not (List.exists (fun (c', _, _) -> same c c') !gens) then
              gens := !gens @ [ (c, 1 + List.length !gens, a.poly) ])
      coeffs;
    let nvars = 1 + List.length !gens in
    let var_of (c : t) : int =
      match List.find_opt (fun (c', _, _) -> same c c') !gens with
      | Some (_, v, _) -> v
      | None -> assert false
    in
    (* build P as an Mpoly: Σ_i (coeff_i) · z^i *)
    let z = Mpoly.var nvars 0 in
    let p_mpoly = ref Mpoly.zero in
    for i = 0 to n - 1 do
      let coeff_m =
        match coeffs.(i) with
        | Rat q -> Mpoly.const nvars q
        | Alg _ -> Mpoly.var nvars (var_of coeffs.(i))
      in
      p_mpoly := Mpoly.add !p_mpoly (Mpoly.mul coeff_m (Mpoly.pow z i))
    done;
    (* eliminate each generator against its minimal polynomial *)
    let w = ref !p_mpoly in
    List.iter
      (fun (_, v, minpoly) ->
        let m_mpoly = ref Mpoly.zero in
        Array.iteri
          (fun k q ->
            m_mpoly :=
              Mpoly.add !m_mpoly (Mpoly.mul (Mpoly.const nvars q) (Mpoly.pow (Mpoly.var nvars v) k)))
          minpoly;
        w := Mpoly.resultant !w !m_mpoly v)
      !gens;
    let r = Mpoly.to_poly_in !w 0 in
    if Poly.degree r < 1 then []
    else
      (* isolate R's real roots; keep those that are true roots of P *)
      Poly.isolate_roots r
      |> List.filter_map (fun (lo, hi) ->
             let z = make r lo hi in
             if sign (eval_num coeffs z) = 0 then Some z else None)
      |> List.sort compare
  end
```

Note: `eval_num` must be defined *before* `real_roots`. Place both where `real_roots` currently sits (after `sqrt`? — no: `real_roots` is currently at `num.ml:308`, before `sqrt`; `eval_num` uses `add`/`mul` which are defined earlier at lines 205/240, so placing both at the current `real_roots` location is fine). `Array.for_all2` requires equal lengths — the guard `Array.length x.poly = Array.length y.poly` precedes it, so it is safe.

- [ ] **Step 4: Run, expect PASS** (and no regressions)

Run: `dune test 2>&1 | tail -20`
Expected: all green, including the four new `real_roots` tests.

- [ ] **Step 5: Register tests + commit**

Register the four tests in the suite list (num group). Then:

```bash
git add lib/num.ml tests/test_beloch.ml
git commit -m "feat(num): real_roots over algebraic coefficients via resultant elimination + exact-eval certification"
```

---

## SLICE 2 — the axiom 7 surface

### Task 3: Syntax — `and` keyword, parser production, `MapBoth` AST node

**Files:**
- Modify: `lib/lexer.ml:13-23` (keyword block)
- Modify: `lib/parser.mly:5` (token decl) and `:36-46` (axiom rule)
- Modify: `lib/ast.ml:17-26` (axiom type)
- Test: `tests/test_beloch.ml` (parse group)

**Interfaces:**
- Produces: AST constructor
  `MapBoth of point_operand * line_operand * point_operand * line_operand * point_operand option`
  (`.p`, `--d`, `.q`, `--e`, optional `toward .x`).

- [ ] **Step 1: Write a failing parse test** in `tests/test_beloch.ml` (parse group)

Match the existing parse-test style (parse a source string, assert the AST shape). Use the existing parse helper in the file (e.g. `parse_program` / whatever `test_parse_map_through` uses — mirror it exactly).

```ocaml
let test_parse_map_both () =
  let prog = parse_program "paper square\nmap .a onto --d and .c onto --e\n" in
  match prog with
  | [ Ast.Crease (None, Ast.MapBoth (p, d, q, e, None), None, _) ] ->
      Alcotest.(check string) "p" ".a" (point_operand_src p);
      Alcotest.(check string) "d" "--d" (line_operand_src d);
      Alcotest.(check string) "q" ".c" (point_operand_src q);
      Alcotest.(check string) "e" "--e" (line_operand_src e)
  | _ -> Alcotest.fail "expected MapBoth without toward"

let test_parse_map_both_toward () =
  let prog = parse_program "paper square\nmap .a onto --d and .c onto --e toward .b\n" in
  match prog with
  | [ Ast.Crease (None, Ast.MapBoth (_, _, _, _, Some _), None, _) ] -> ()
  | _ -> Alcotest.fail "expected MapBoth with toward"
```

If the file has no `point_operand_src`/`line_operand_src` helpers, use whatever the neighbouring axiom-6 parse test uses to inspect operands (mirror `test_parse_map_through`); do not invent helpers.

- [ ] **Step 2: Run, expect FAIL**

Run: `dune test 2>&1 | head -30`
Expected: compile error (`MapBoth` / `AND` unbound).

- [ ] **Step 3: Add the AST constructor** in `lib/ast.ml` after `MapThrough` (`:23-25`):

```ocaml
  | MapBoth of
      point_operand * line_operand * point_operand * line_operand * point_operand option
    (* axiom 7: fold .p onto --d AND .q onto --e simultaneously, optional toward *)
```

- [ ] **Step 4: Add the lexer keyword** in `lib/lexer.ml`, among the keyword arms (e.g. after `"map" -> MAP` at `:16`):

```ocaml
  | "and" -> AND
```

- [ ] **Step 5: Declare the token and add productions** in `lib/parser.mly`.

Add `AND` to the `%token` line at `:5` (append to the keyword list):

```
%token PAPER SQUARE THROUGH MAP ONTO CROSS COLON EOF PERP TOWARD AT MOVING MOUNTAIN FLIP LINE_OPEN POINT_OPEN RPAREN AND
```

Add two productions to the `axiom:` rule (after the `MapThrough` productions at `:40-43`):

```
  | MAP point_operand ONTO line_operand AND point_operand ONTO line_operand
      { MapBoth ($2, $4, $6, $8, None) }
  | MAP point_operand ONTO line_operand AND point_operand ONTO line_operand TOWARD point_operand
      { MapBoth ($2, $4, $6, $8, Some $10) }
```

`point_operand` and `line_operand` have disjoint FIRST sets (`POINT`/`POINT_OPEN` vs `CREASE`/`LINE_OPEN`), and `AND` is a distinct lookahead after `MAP point_operand ONTO line_operand`, so these are conflict-free.

- [ ] **Step 6: Run, expect PASS** (and `dune build` reports no new Menhir conflicts)

Run: `dune build 2>&1 | grep -i conflict; dune test 2>&1 | tail -20`
Expected: no conflict lines; all tests green including the two new parse tests.

- [ ] **Step 7: Commit**

```bash
git add lib/lexer.ml lib/parser.mly lib/ast.ml tests/test_beloch.ml
git commit -m "feat(syntax): axiom 7 surface — `map .p onto --d and .q onto --e [toward .x]`"
```

---

### Task 4: `Geom.beloch7_creases` — the common-tangent cubic

**Files:**
- Modify: `lib/geom.ml` (add after `beloch_creases`, `:89`)
- Test: `tests/test_beloch.ml` (geom group)

**Interfaces:**
- Consumes: `Num`, `Num.real_roots`, existing `Geom` helpers (`perpendicular_bisector`, `reflect_point`, `side_of_line`).
- Produces: `beloch7_creases : point -> line -> point -> line -> line list` — 0, 1, or 3 creases, each folding `p` onto `d` while folding `q` onto `e`.

**Derivation** (so the code is checkable): parametrize `p`'s landing on directrix `d = {a;b;c}` by a rational parameter `t` along `d`'s direction `(b, −a)` from the foot `d0 = (a·c/n2, b·c/n2)`, `n2 = a²+b²`:
`p*(t) = (d0x + t·b, d0y − t·a)`. The candidate crease is `A·x + B·y = C` with
`A = p*.x − p.x`, `B = p*.y − p.y`, `C = A·mx + B·my`, `mx,my` the midpoint of `p,p*`
(this is exactly `perpendicular_bisector p p*`). Reflecting `q` across this crease
and requiring the image to lie on `e = {ea;eb;ec}` gives, after clearing the
reflection denominator `n2c = A²+B²`:
`F(t) = S·n2c − 2·dd·(ea·A + eb·B) = 0`, where `S = ea·q.x + eb·q.y − ec` and
`dd = A·q.x + B·q.y − C`. `F` is a **cubic in t**. Its roots are the landing
parameters; each maps back to a crease via `perpendicular_bisector p p*(t)`.
[justin1986:11 ("tangentes communes à deux paraboles … équation du troisième
degré"); hull2020 §2.4.]

- [ ] **Step 1: Write a failing geometry test** in `tests/test_beloch.ml` (geom group)

A configuration with a hand-verifiable simultaneous fold. Use: `p = (0,1)` (= corner d of the unit square), `d : y = 0` (the bottom edge, `{0;1;0}`), `q = (1,1)` (= corner c), `e : x = 0` (the left edge, `{1;0;0}`). Assert every returned crease folds `p` onto `d` and `q` onto `e` — checked exactly with `reflect_point` + `side_of_line = 0`.

```ocaml
let test_beloch7_lands_on_both () =
  let p = pt (q 0) (q 1) and qq = pt (q 1) (q 1) in
  let d = { Geom.a = q 0; b = q 1; c = q 0 } in   (* y = 0 *)
  let e = { Geom.a = q 1; b = q 0; c = q 0 } in   (* x = 0 *)
  let creases = Geom.beloch7_creases p d qq e in
  Alcotest.(check bool) "at least one crease" true (List.length creases >= 1);
  List.iter
    (fun c ->
      let pim = Geom.reflect_point c p and qim = Geom.reflect_point c qq in
      Alcotest.(check int) "p lands on d" 0 (Geom.side_of_line d pim);
      Alcotest.(check int) "q lands on e" 0 (Geom.side_of_line e qim))
    creases
```

(`pt`, `q` are the helpers at the top of `tests/test_beloch.ml`.)

- [ ] **Step 2: Run, expect FAIL** (`beloch7_creases` undefined)

Run: `dune test 2>&1 | head -20`
Expected: `Unbound value Geom.beloch7_creases`.

- [ ] **Step 3: Implement `beloch7_creases`** in `lib/geom.ml` (after `:89`).

Use a tiny local polynomial-in-`t` arithmetic over `Num.t` arrays (low-first) to build `F` exactly, then `Num.real_roots`:

```ocaml
(* axiom 7 (Justin ⑦): the crease(s) that simultaneously fold p onto line d and
   q onto line e — a common tangent to the two parabolas (focus p, directrix d)
   and (focus q, directrix e). Parametrize p's landing along d by t; the
   "lands q on e" condition is a cubic F(t); each real root is a crease (the
   perpendicular bisector of p and its landing). 0, 1, or 3 creases.
   [justin1986 §2–3; hull2020 §2.4] *)
let beloch7_creases (p : point) (d : line) (q : point) (e : line) : line list =
  (* polynomials in t as Num.t arrays, low-first *)
  let padd a b =
    let n = max (Array.length a) (Array.length b) in
    Array.init n (fun i ->
        let x = if i < Array.length a then a.(i) else Num.zero in
        let y = if i < Array.length b then b.(i) else Num.zero in
        Num.add x y)
  in
  let pscale (s : Num.t) a = Array.map (fun c -> Num.mul s c) a in
  let pmul a b =
    let r = Array.make (Array.length a + Array.length b - 1) Num.zero in
    Array.iteri
      (fun i ca -> Array.iteri (fun j cb -> r.(i + j) <- Num.add r.(i + j) (Num.mul ca cb)) b)
      a;
    r
  in
  let psub a b = padd a (pscale (Num.of_int (-1)) b) in
  let n2 = Num.add (Num.mul d.a d.a) (Num.mul d.b d.b) in
  let d0x = Num.div (Num.mul d.a d.c) n2 and d0y = Num.div (Num.mul d.b d.c) n2 in
  let two = Num.of_int 2 in
  (* p*(t) = (d0x + t·d.b, d0y − t·d.a) *)
  (* A(t) = p*.x − p.x = (d0x − p.x) + t·d.b *)
  let aA = [| Num.sub d0x p.x; d.b |] in
  (* B(t) = p*.y − p.y = (d0y − p.y) + t·(−d.a) *)
  let bB = [| Num.sub d0y p.y; Num.neg d.a |] in
  (* mx(t) = (p.x + p*.x)/2,  my(t) = (p.y + p*.y)/2 *)
  let mx = [| Num.div (Num.add p.x d0x) two; Num.div d.b two |] in
  let my = [| Num.div (Num.add p.y d0y) two; Num.div (Num.neg d.a) two |] in
  (* C(t) = A·mx + B·my *)
  let cC = padd (pmul aA mx) (pmul bB my) in
  (* n2c(t) = A² + B² *)
  let n2c = padd (pmul aA aA) (pmul bB bB) in
  (* dd(t) = A·q.x + B·q.y − C *)
  let dd = psub (padd (pscale q.x aA) (pscale q.y bB)) cC in
  (* L(t) = e.a·A + e.b·B *)
  let lL = padd (pscale e.a aA) (pscale e.b bB) in
  (* S = e.a·q.x + e.b·q.y − e.c   (constant) *)
  let s = Num.sub (Num.add (Num.mul e.a q.x) (Num.mul e.b q.y)) e.c in
  (* F(t) = S·n2c − 2·dd·L *)
  let fF = psub (pscale s n2c) (pscale two (pmul dd lL)) in
  Num.real_roots fF
  |> List.map (fun t ->
         let pstar = { x = Num.add d0x (Num.mul t d.b); y = Num.sub d0y (Num.mul t d.a) } in
         perpendicular_bisector p pstar)
```

- [ ] **Step 4: Run, expect PASS**

Run: `dune test 2>&1 | tail -20`
Expected: green, including `test_beloch7_lands_on_both`.

- [ ] **Step 5: Commit**

```bash
git add lib/geom.ml tests/test_beloch.ml
git commit -m "feat(geom): beloch7_creases — common tangent to two parabolas via the landing-parameter cubic"
```

---

### Task 5: Eval arm, degeneracy guards, golden + e2e tests

**Files:**
- Modify: `lib/eval.ml` (add a `MapBoth` arm to `axis_of`, after the `MapThrough` arm at `:139-185`)
- Test: `tests/test_beloch.ml` (eval + e2e groups)

**Interfaces:**
- Consumes: `Geom.beloch7_creases` (Task 4), existing eval helpers (`table_of`, `resolve_line`, `pstr`, `lstr`, `Geom.reflect_point`, `Num.compare`, `Geom.parallel`, `Geom.side_of_line`).
- Produces: `axis_of` handles `Ast.MapBoth`, tag `"axiom7"`, sources `[pstr p; lstr d; pstr q; lstr e]` (+ `pstr x` when `toward` is present). The `@`-fold moving side defaults to `.p` (handled wherever `MapThrough`'s default is — mirror it).

- [ ] **Step 1: Write failing tests** in `tests/test_beloch.ml`.

(a) eval-level (single-crease selection by `toward`, and degeneracy errors); (b) the headline exactness tests on the number/geometry layer; (c) one full-pipeline e2e.

```ocaml
let test_eval_map_both_selects () =
  (* p=(0,1) onto d:y=0, q=(1,1) onto e:x=0 — multiple creases; `toward` picks one *)
  let folded =
    Beloch.eval_folded
      (parse_program
         "paper square\nmap .d onto --bot and .c onto --left toward .a\n\
          ; with --bot, --left, .a/.c/.d as defined below\n")
  in
  ignore folded
(* NOTE: replace the source with a valid program once crease bindings exist;
   see the e2e test for the concrete, runnable form. This placeholder is removed
   in Step 3 — keep only the runnable e2e + the geom-level exactness tests. *)

let test_axiom7_doubles_the_cube () =
  (* Headline: the doubling-the-cube cubic z^3 - 2 = 0 yields ∛2 exactly through
     the same root finder axiom 7 calls. [hull2020 §2.4] *)
  let v =
    match Num.real_roots [| Num.of_int (-2); Num.zero; Num.zero; Num.one |] with
    | [ v ] -> v
    | _ -> Alcotest.fail "expected one real root"
  in
  Alcotest.(check bool) "(∛2)^3 = 2" true
    (Num.equal (Num.mul v (Num.mul v v)) (Num.of_int 2))

let test_axiom7_trisection_cubic () =
  (* Angle trisection reduces to 4t^3 - 3t - m = 0 where m = cos θ (or the tan
     form, [justin1986 §4.2]). For θ = π/3, m = cos(π/3) = 1/2: 4t^3 - 3t - 1/2 = 0
     has t = cos(π/9) ≈ 0.9397 among its roots. Verify a root satisfies the
     identity exactly. *)
  let roots =
    Num.real_roots
      [| Num.div (Num.of_int (-1)) (Num.of_int 2); Num.of_int (-3); Num.zero; Num.of_int 4 |]
  in
  Alcotest.(check bool) "three real roots" true (List.length roots = 3);
  List.iter
    (fun t ->
      let f =
        Num.sub
          (Num.sub (Num.mul (Num.of_int 4) (Num.mul t (Num.mul t t))) (Num.mul (Num.of_int 3) t))
          (Num.div (Num.of_int 1) (Num.of_int 2))
      in
      Alcotest.(check bool) "4t^3-3t-1/2 = 0" true (Num.equal f Num.zero))
    roots
```

For the e2e, build a runnable program: precrease the two directrices as named creases through corners, then axiom 7. Concretely (bottom edge `a→b`, left edge `a→d`):

```ocaml
let test_e2e_axiom7_fold_emit () =
  let src =
    "paper square\n\
     --bot: through .a .b\n\
     --left: through .a .d\n\
     map .d onto --bot and .c onto --left toward .a\n"
  in
  let json = Beloch.fold_string src in
  (* the emitted FOLD records an axiom7 crease *)
  Alcotest.(check bool) "axiom7 tag present" true
    (let re = Str.regexp_string "axiom7" in
     try ignore (Str.search_forward re json 0); true with Not_found -> false)
```

Use whatever the existing e2e tests use to assert on emitted FOLD (mirror the axiom-6 e2e test at `tests/test_beloch.ml:1536`; if they inspect the parsed JSON rather than a substring, match that style instead of `Str`).

- [ ] **Step 2: Run, expect FAIL**

Run: `dune test 2>&1 | head -30`
Expected: failures (no `MapBoth` arm → `eval_folded` raises/`Match_failure`, or compile error on the test).

- [ ] **Step 3: Implement the eval arm** in `lib/eval.ml`, inside `axis_of`, after the `MapThrough` arm (`:185`). Mirror axiom 6's structure (`[]` / `[c]` / `≥2 with toward`), add the two degeneracy guards.

```ocaml
    | Ast.MapBoth (p, d, q, e, x_opt) -> (
        let pp = table_of p and dd = resolve_line d in
        let qq = table_of q and ee = resolve_line e in
        let base = [ pstr p; lstr d; pstr q; lstr e ] in
        (* degeneracy guards [justin1986 §8.4a] *)
        if Geom.side_of_line ee qq = 0 then
          Error.fail span
            (Printf.sprintf
               "map %s onto %s and %s onto %s: %s already lies on %s — use axiom 6 \
                (fold %s onto %s through a point) then axiom 4"
               (pstr p) (lstr d) (pstr q) (lstr e) (pstr q) (lstr e) (pstr p) (lstr d));
        if Geom.parallel dd ee then
          Error.fail span
            (Printf.sprintf
               "map %s onto %s and %s onto %s: %s and %s are parallel — degenerate, \
                no general cubic fold"
               (pstr p) (lstr d) (pstr q) (lstr e) (lstr d) (lstr e));
        match Geom.beloch7_creases pp dd qq ee with
        | [] ->
            Error.fail span
              (Printf.sprintf
                 "cannot fold %s onto %s and %s onto %s: out of reach (no common tangent)"
                 (pstr p) (lstr d) (pstr q) (lstr e))
        | [ c ] -> (c, "axiom7", base)
        | creases -> (
            match x_opt with
            | None ->
                Error.fail span
                  (Printf.sprintf
                     "%d folds place %s onto %s and %s onto %s; add 'toward .x'"
                     (List.length creases) (pstr p) (lstr d) (pstr q) (lstr e))
            | Some xo ->
                let xt = table_of xo in
                (* nearest landing of the FIRST point p, exact squared distance *)
                let dist2 (c : Geom.line) =
                  let im = Geom.reflect_point c pp in
                  let ex = Num.sub im.Geom.x xt.Geom.x
                  and ey = Num.sub im.Geom.y xt.Geom.y in
                  Num.add (Num.mul ex ex) (Num.mul ey ey)
                in
                let best =
                  List.fold_left
                    (fun acc c ->
                      match acc with
                      | None -> Some c
                      | Some b -> if Num.compare (dist2 c) (dist2 b) < 0 then Some c else acc)
                    None creases
                in
                match best with Some c -> (c, "axiom7", base @ [ pstr xo ]) | None -> assert false))
```

If the `@`-fold moving-default for point-axioms is set in a separate place (where `MapThrough` defaults `moving` to `.p`), add `MapBoth` there too, defaulting to `p`. Grep for how `MapThrough` is treated for the `moving` default and mirror it.

- [ ] **Step 4: Replace the placeholder eval test** (remove `test_eval_map_both_selects`'s placeholder; the e2e test `test_e2e_axiom7_fold_emit` covers selection through the real pipeline). Keep `test_axiom7_doubles_the_cube`, `test_axiom7_trisection_cubic`, `test_e2e_axiom7_fold_emit`.

- [ ] **Step 5: Run, expect PASS**

Run: `dune test 2>&1 | tail -20`
Expected: all green.

- [ ] **Step 6: Register tests + commit**

Register the kept tests in the suite list (eval + e2e groups). Then:

```bash
git add lib/eval.ml tests/test_beloch.ml
git commit -m "feat(eval): axiom 7 — common-tangent fold with toward-selection and degeneracy guards"
```

---

### Task 6: Docs, journal, example, renderer label

**Files:**
- Modify: `spec/SPECIFICATION.md` (axiom 7 section + grammar/EBNF + Appendix B move)
- Create: `notes/2026-06-30-axiom7.md`
- Create: `examples/beloch.bel`
- Modify: `tools/fold2svg.mjs` (axiom7 legend label)

- [ ] **Step 1: Spec.** Add an axiom-7 subsection after axiom 6's (find axiom 6's section, e.g. `§4.5b`, and add `§4.5c`). Document: surface `map .p onto --d and .q onto --e [toward .x]`; classic Justin ⑦ = Hull O7; the common-tangent-to-two-parabolas cubic; 1 or 3 solutions; `toward` selects by nearest landing of the first point; degeneracies (`q∈e`, `d∥e`). Add the two productions to the grammar/EBNF mirror (matching the axiom-6 entry). Move axiom 7 from the Appendix B deferred list to the landed list. Bump the version field if the spec tracks one (match what axiom 6 did).

- [ ] **Step 2: Journal.** Write `notes/2026-06-30-axiom7.md`: what shipped, the superset-manufacture + exact-eval-certify design for `real_roots`, the landing-parameter cubic, the numbering resolution, refs (`bpr2006 §§4.2,10.2-10.3`, `hull2020 §2.4`, `justin1986`). Concise, match the style of `notes/2026-06-30-axiom6.md`.

- [ ] **Step 3: Example.** Create `examples/beloch.bel` — a runnable axiom-7 program (the e2e form from Task 5 is a good basis). Verify it runs:

Run: `dune exec -- beloch examples/beloch.bel > /tmp/axiom7.fold 2>&1; head -c 200 /tmp/axiom7.fold`
(Use the project's actual CLI entrypoint — check `bin/` or how other examples are run; mirror `examples/through.bel`'s invocation.)
Expected: valid FOLD JSON, no error.

- [ ] **Step 4: Renderer label.** In `tools/fold2svg.mjs`, add `axiom7` to the per-axiom legend map (find where `axiom6` is labelled and add the sibling entry with an appropriate label, e.g. `"axiom7": "map onto + onto"`).

- [ ] **Step 5: Commit.**

```bash
git add spec/SPECIFICATION.md notes/2026-06-30-axiom7.md examples/beloch.bel tools/fold2svg.mjs
git commit -m "docs(spec): axiom 7 — section, grammar, journal, example, renderer label"
```

---

## Self-Review (completed)

**Spec coverage:** Slice 1 §"manufacture R" → Task 1 (`Mpoly`) + Task 2 (`real_roots`); Slice 1 tests (1-gen, 2-gen, casus-irreducibilis-irrational, rational fast-path) → Task 2 Step 1. Slice 2 syntax → Task 3; geometry `beloch7_creases` → Task 4; eval arm + degeneracy guards + `toward` selection → Task 5; golden ∛2 + trisection + e2e → Task 5; docs/ADR-or-journal/example/label → Task 6. The spec mentioned an optional ADR 0013 — downgraded to a journal note (Task 6 Step 2), since the design decisions are already recorded in the committed design doc; if the reviewer judges an ADR warranted, add `decisions/0013-axiom-7.md` mirroring ADR 0012's structure.

**Placeholder scan:** one intentional placeholder (`test_eval_map_both_selects`) is explicitly created in Task 5 Step 1 and removed in Step 4 — it exists only to make the TDD red/green visible; the runnable coverage is the e2e test. No other placeholders.

**Type consistency:** `beloch7_creases : point -> line -> point -> line -> line list` used identically in Task 4 (def) and Task 5 (call). `real_roots : Num.t array -> Num.t list` consistent across Task 2 and Task 4's geometry. `Mpoly.resultant a b v` / `Mpoly.to_poly_in p v` consistent between Task 1 def and Task 2 use. `MapBoth`'s 5-tuple arity identical in Ast (Task 3), parser (Task 3), and eval (Task 5).

**Known soft spots to verify during execution** (call out, don't hide): (1) the exact parse-test helper names in `tests/test_beloch.ml` (`parse_program`, operand inspectors) — mirror the axiom-6 parse test rather than assuming; (2) how e2e tests assert on emitted FOLD (`Str` substring vs parsed JSON) — mirror the axiom-6 e2e test; (3) the `@`-fold `moving` default location for point-axioms — grep `MapThrough` and mirror; (4) the dune facade `module Mpoly = Mpoly` — only if `lib/beloch.ml` uses the re-export pattern.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-30-axiom-7-cubic-beloch-fold.md`.
