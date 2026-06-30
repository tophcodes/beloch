# Real-Algebraic Number Kernel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `Num`'s quadratic `Ext` tower with an exact real-algebraic number kernel (defining polynomial + isolating rational interval) so Beloch can represent the degree-3 (and higher) numbers axiom 7 needs, including the casus irreducibilis — with no `.bel` behaviour change.

**Architecture:** A new `lib/poly.ml` provides dense univariate polynomials over ℚ (arithmetic, resultant via Sylvester determinant, Euclidean gcd/squarefree, Sturm sequences, real-root isolation). `lib/num.ml` is rewritten: a number is either `Rat of Q.t` (fast-path) or `Alg {poly; lo; hi}` — the unique real root of a squarefree ℚ-polynomial inside an open rational interval. Arithmetic builds the result's defining polynomial by **resultant via evaluation+Lagrange-interpolation** (numeric determinants only — no symbolic polynomial determinants), then isolates the result's interval. Sign/compare refine the interval; equality is `sign (a−b) = 0`. The public `Num` interface is preserved so `geom`/`isometry`/`fold_state`/`eval` compile unchanged; one constructor, `real_roots`, is added for axiom 7 (slice 2).

**Tech Stack:** OCaml, dune 3.0, zarith (`Q`, `Z`), alcotest. No new dependencies.

## Global Constraints

- **Exactness:** no floats in computation. `float` appears only in `Num.to_float`, output-only (FOLD JSON), never fed back. [ADR 0008, ADR 0010, ADR 0012]
- **Number representation:** `Z`/`Q` from zarith only. Polynomials are `Q.t array`, low coefficient first, no trailing zeros (zero polynomial = `[||]`).
- **Public `Num` interface is frozen:** `zero one of_q of_int neg add sub mul inv div sqrt sign compare equal to_float` keep their current signatures. New additions only: `real_roots`. Removing `Ext`/`compare_struct`/`ext` is internal to `num.ml`.
- **Tests:** one executable, `tests/test_beloch.ml`; register every new case in the `Alcotest.run "beloch" [...]` block. Run with `dune test`.
- **Citations:** algorithms ground to `[bpr2006]` (`refs/bpr2006.{pdf,txt}`); field theory to `[justin1986 §8.4d]` / `[hull2020]`. Conventional commits.
- **Acceptance gate for the whole slice:** the entire pre-existing suite (axioms 1–6, fold-state, FOLD emit, parse, eval, e2e, isometry, num) passes unchanged.

---

## File Structure

- **Create** `lib/poly.ml` — univariate ℚ-polynomials + real-root algorithms. One responsibility: polynomial algebra. No geometry, no "interval as a number".
- **Rewrite** `lib/num.ml` — the real-algebraic number type. Depends on `Poly`. Keeps the frozen interface.
- **Modify** `tests/test_beloch.ml` — add a `"poly"` suite and extend the `"num"` cases; register all in the run block.
- **Create** `decisions/0012-real-algebraic-number-kernel.md`; **modify** `decisions/0010-constructible-real-numbers.md` (mark Superseded).
- **Modify** `paper/references.bib`, `bibliography.md` (add `bpr2006`), `spec/SPECIFICATION.md` (numbering note), `notes/2026-06-30-real-algebraic-kernel.md` (new journal entry).

`lib/dune` needs **no change** — dune compiles every `.ml` in `lib/` into the `beloch` library automatically. `Poly` becomes `Beloch.Poly`, `Num` stays `Beloch.Num`.

> **Note on task atomicity:** `num.ml` is rewritten in a single task (Task 4). OCaml compiles `lib/` as a whole and `geom`/`eval`/etc. call the full `Num` interface, so a partially-rewritten `num.ml` cannot compile. Task 4 therefore swaps the module wholesale, with internal TDD checkpoints that run once the module compiles. Tasks 1–3 (`poly.ml`, a new leaf module) are independently compilable and follow strict per-function TDD.

---

### Task 1: `Poly` — type and core arithmetic

**Files:**
- Create: `lib/poly.ml`
- Test: `tests/test_beloch.ml` (new `"poly"` suite)

**Interfaces:**
- Produces: `type Poly.t = Q.t array` (low-first, normalized); `of_list : Q.t list -> t`; `zero : t`; `is_zero : t -> bool`; `degree : t -> int` (−1 for zero); `leading : t -> Q.t`; `eval : t -> Q.t -> Q.t`; `add sub : t -> t -> t`; `neg : t -> t`; `scale : Q.t -> t -> t`; `mul : t -> t -> t`; `derivative : t -> t`; `compose : t -> t -> t`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_beloch.ml`, add (the existing file `open Beloch`, so `Poly`/`Num`/`Q` resolve):

```ocaml
(* ---- Poly: core arithmetic ---- *)
let qp l = Poly.of_list (List.map Q.of_int l)

let test_poly_eval () =
  (* p = 1 + 2x + 3x²; p(2) = 1 + 4 + 12 = 17 *)
  Alcotest.(check bool) "eval" true (Q.equal (Poly.eval (qp [1;2;3]) (Q.of_int 2)) (Q.of_int 17))

let test_poly_add_mul () =
  let p = qp [1;1] and q = qp [-1;1] in       (* (x+1)(x-1) = x²-1 *)
  Alcotest.(check bool) "mul" true (Poly.eval (Poly.mul p q) (Q.of_int 3) |> Q.equal (Q.of_int 8));
  Alcotest.(check bool) "add" true (Poly.eval (Poly.add p q) (Q.of_int 5) |> Q.equal (Q.of_int 10));
  Alcotest.(check int) "degree of x²-1" 2 (Poly.degree (Poly.mul p q))

let test_poly_derivative () =
  (* d/dx (1 + 2x + 3x²) = 2 + 6x *)
  let d = Poly.derivative (qp [1;2;3]) in
  Alcotest.(check bool) "deriv@1=8" true (Q.equal (Poly.eval d Q.one) (Q.of_int 8))

let test_poly_compose () =
  (* a = x², g = x+1; a∘g = (x+1)² ; (a∘g)(2) = 9 *)
  let a = qp [0;0;1] and g = qp [1;1] in
  Alcotest.(check bool) "compose" true (Q.equal (Poly.eval (Poly.compose a g) (Q.of_int 2)) (Q.of_int 9))

let test_poly_normalize_zero () =
  Alcotest.(check int) "zero degree -1" (-1) (Poly.degree Poly.zero);
  Alcotest.(check bool) "trailing zeros trimmed" true (Poly.degree (qp [1;2;0;0]) = 1)
```

Register a new suite in the `Alcotest.run "beloch"` list:

```ocaml
      ( "poly",
        [
          Alcotest.test_case "eval" `Quick test_poly_eval;
          Alcotest.test_case "add/mul" `Quick test_poly_add_mul;
          Alcotest.test_case "derivative" `Quick test_poly_derivative;
          Alcotest.test_case "compose" `Quick test_poly_compose;
          Alcotest.test_case "normalize zero" `Quick test_poly_normalize_zero;
        ] );
```

- [ ] **Step 2: Run to verify failure**

Run: `dune test 2>&1 | head -30`
Expected: compile error — `Unbound module Poly`.

- [ ] **Step 3: Implement `lib/poly.ml`**

```ocaml
(** Dense univariate polynomials over ℚ, low coefficient first.
    Invariant: no trailing-zero coefficients; the zero polynomial is [||]. *)
type t = Q.t array

let normalize (a : Q.t array) : t =
  let n = ref (Array.length a) in
  while !n > 0 && Q.equal a.(!n - 1) Q.zero do
    decr n
  done;
  Array.sub a 0 !n

let of_list (l : Q.t list) : t = normalize (Array.of_list l)
let zero : t = [||]
let is_zero (p : t) : bool = Array.length p = 0
let degree (p : t) : int = Array.length p - 1
let leading (p : t) : Q.t = p.(Array.length p - 1)
let const (c : Q.t) : t = if Q.equal c Q.zero then zero else [| c |]

let eval (p : t) (x : Q.t) : Q.t =
  let acc = ref Q.zero in
  for i = Array.length p - 1 downto 0 do
    acc := Q.add (Q.mul !acc x) p.(i)
  done;
  !acc

let add (p : t) (q : t) : t =
  let n = max (Array.length p) (Array.length q) in
  normalize
    (Array.init n (fun i ->
         let a = if i < Array.length p then p.(i) else Q.zero in
         let b = if i < Array.length q then q.(i) else Q.zero in
         Q.add a b))

let neg (p : t) : t = Array.map Q.neg p
let sub (p : t) (q : t) : t = add p (neg q)
let scale (c : Q.t) (p : t) : t =
  if Q.equal c Q.zero then zero else Array.map (Q.mul c) p

let mul (p : t) (q : t) : t =
  if is_zero p || is_zero q then zero
  else begin
    let r = Array.make (Array.length p + Array.length q - 1) Q.zero in
    Array.iteri
      (fun i a -> Array.iteri (fun j b -> r.(i + j) <- Q.add r.(i + j) (Q.mul a b)) q)
      p;
    normalize r
  end

let derivative (p : t) : t =
  if Array.length p <= 1 then zero
  else
    normalize
      (Array.init (Array.length p - 1) (fun i ->
           Q.mul (Q.of_int (i + 1)) p.(i + 1)))

(* a ∘ g, by Horner over the polynomial ring *)
let compose (a : t) (g : t) : t =
  let acc = ref zero in
  for i = Array.length a - 1 downto 0 do
    acc := add (mul !acc g) (const a.(i))
  done;
  !acc
```

- [ ] **Step 4: Run to verify pass**

Run: `dune test 2>&1 | tail -20`
Expected: the `poly` suite passes (existing suites still pass).

- [ ] **Step 5: Commit**

```bash
git add lib/poly.ml tests/test_beloch.ml
git commit -m "feat(poly): univariate ℚ-polynomials — core arithmetic + compose"
```

---

### Task 2: `Poly` — division, resultant, gcd, squarefree

**Files:**
- Modify: `lib/poly.ml`
- Test: `tests/test_beloch.ml` (extend `"poly"` suite)

**Interfaces:**
- Consumes: everything from Task 1.
- Produces: `divmod : t -> t -> t * t` (quotient, remainder over ℚ; raises `Division_by_zero` on zero divisor); `rem : t -> t -> t`; `monic : t -> t`; `det : Q.t array array -> Q.t`; `resultant : t -> t -> Q.t`; `gcd : t -> t -> t` (monic); `squarefree_part : t -> t` (monic).

- [ ] **Step 1: Write the failing tests**

```ocaml
(* ---- Poly: division / resultant / squarefree ---- *)
let test_poly_divmod () =
  (* (x²-1) / (x-1) = x+1, remainder 0 *)
  let q, r = Poly.divmod (qp [-1;0;1]) (qp [-1;1]) in
  Alcotest.(check bool) "quotient x+1" true (Poly.eval q (Q.of_int 4) |> Q.equal (Q.of_int 5));
  Alcotest.(check bool) "remainder 0" true (Poly.is_zero r)

let test_poly_resultant () =
  (* Res(x²-2, x²-3) = ∏(±√2 ∓ √3) = 1 ; Res(P,P) = 0 *)
  Alcotest.(check bool) "Res(x²-2,x²-3)=1" true (Q.equal (Poly.resultant (qp [-2;0;1]) (qp [-3;0;1])) Q.one);
  Alcotest.(check bool) "Res(P,P)=0" true (Q.equal (Poly.resultant (qp [-2;0;1]) (qp [-2;0;1])) Q.zero)

let test_poly_squarefree () =
  (* (x-1)²(x+2) -> squarefree (x-1)(x+2) = x²+x-2 ; root multiplicity gone *)
  let p = Poly.mul (qp [1;-2;1]) (qp [2;1]) in   (* (x-1)² * (x+2) *)
  let s = Poly.squarefree_part p in
  Alcotest.(check int) "squarefree degree 2" 2 (Poly.degree s);
  Alcotest.(check bool) "monic" true (Q.equal (Poly.leading s) Q.one);
  Alcotest.(check bool) "still vanishes at 1" true (Q.equal (Poly.eval s Q.one) Q.zero)
```

Register:

```ocaml
          Alcotest.test_case "divmod" `Quick test_poly_divmod;
          Alcotest.test_case "resultant" `Quick test_poly_resultant;
          Alcotest.test_case "squarefree" `Quick test_poly_squarefree;
```

- [ ] **Step 2: Run to verify failure**

Run: `dune test 2>&1 | head -20`
Expected: compile error — `Unbound value Poly.divmod` / `resultant` / `squarefree_part`.

- [ ] **Step 3: Implement (append to `lib/poly.ml`)**

```ocaml
(* p = quo*d + rem, deg rem < deg d, over the field ℚ. *)
let divmod (p : t) (d : t) : t * t =
  if is_zero d then raise Division_by_zero;
  let dd = degree d and ld = leading d in
  let r = ref (Array.copy p) in
  let quo = Array.make (max 1 (Array.length p - dd)) Q.zero in
  while Array.length !r - 1 >= dd && not (is_zero !r) do
    let dr = Array.length !r - 1 in
    let c = Q.div !r.(dr) ld in
    quo.(dr - dd) <- c;
    let nr = Array.copy !r in
    for i = 0 to dd do
      nr.(dr - dd + i) <- Q.sub nr.(dr - dd + i) (Q.mul c d.(i))
    done;
    r := normalize nr
  done;
  (normalize quo, !r)

let rem (p : t) (d : t) : t = snd (divmod p d)
let monic (p : t) : t = if is_zero p then p else scale (Q.inv (leading p)) p

(* Determinant of a square ℚ-matrix by Gaussian elimination. *)
let det (m : Q.t array array) : Q.t =
  let n = Array.length m in
  if n = 0 then Q.one
  else begin
    let a = Array.map Array.copy m in
    let d = ref Q.one in
    (try
       for col = 0 to n - 1 do
         let piv = ref col in
         while !piv < n && Q.equal a.(!piv).(col) Q.zero do
           incr piv
         done;
         if !piv = n then begin
           d := Q.zero;
           raise Exit
         end;
         if !piv <> col then begin
           let tmp = a.(col) in
           a.(col) <- a.(!piv);
           a.(!piv) <- tmp;
           d := Q.neg !d
         end;
         d := Q.mul !d a.(col).(col);
         for row = col + 1 to n - 1 do
           let f = Q.div a.(row).(col) a.(col).(col) in
           for k = col to n - 1 do
             a.(row).(k) <- Q.sub a.(row).(k) (Q.mul f a.(col).(k))
           done
         done
       done;
       !d
     with Exit -> Q.zero)
  end

(* Sylvester resultant of p and q (both nonzero). Constants handled directly. *)
let rec resultant (p : t) (q : t) : Q.t =
  if is_zero p || is_zero q then Q.zero
  else
    let dp = degree p and dq = degree q in
    if dp = 0 then qpow p.(0) dq
    else if dq = 0 then qpow q.(0) dp
    else begin
      let n = dp + dq in
      let m = Array.make_matrix n n Q.zero in
      for i = 0 to dq - 1 do
        for j = 0 to dp do
          m.(i).(i + j) <- p.(dp - j)
        done
      done;
      for i = 0 to dp - 1 do
        for j = 0 to dq do
          m.(dq + i).(i + j) <- q.(dq - j)
        done
      done;
      det m
    end

and qpow (c : Q.t) (k : int) : Q.t =
  let r = ref Q.one in
  for _ = 1 to k do
    r := Q.mul !r c
  done;
  !r

let rec gcd (p : t) (q : t) : t =
  if is_zero q then monic p else gcd q (rem p q)

(* Squarefree part = p / gcd(p, p'), monic. *)
let squarefree_part (p : t) : t =
  if degree p < 1 then monic p
  else
    let g = gcd p (derivative p) in
    monic (fst (divmod p g))
```

- [ ] **Step 4: Run to verify pass**

Run: `dune test 2>&1 | tail -20`
Expected: `poly` suite passes.

- [ ] **Step 5: Commit**

```bash
git add lib/poly.ml tests/test_beloch.ml
git commit -m "feat(poly): divmod, Sylvester resultant, gcd, squarefree part"
```

---

### Task 3: `Poly` — Sturm sequences, root counting, isolation

**Files:**
- Modify: `lib/poly.ml`
- Test: `tests/test_beloch.ml` (extend `"poly"` suite)

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: `sturm_sequence : t -> t list`; `sign_changes : t list -> Q.t -> int`; `count_roots_in : t list -> Q.t -> Q.t -> int` (roots in `(lo, hi]`); `cauchy_bound : t -> Q.t`; `isolate_roots : t -> (Q.t * Q.t) list` (disjoint open intervals, one simple root each, ascending); `sign_at : t -> Q.t -> int`.

- [ ] **Step 1: Write the failing tests**

```ocaml
(* ---- Poly: Sturm / isolation ---- *)
let test_poly_sturm_count () =
  (* x³ - 3x - 1 has 3 real roots (≈ -1.532, -0.347, 1.879) *)
  let p = qp [-1;-3;0;1] in
  let seq = Poly.sturm_sequence p in
  Alcotest.(check int) "3 real roots in (-10,10]" 3 (Poly.count_roots_in seq (Q.of_int (-10)) (Q.of_int 10));
  (* x² + 1 has none *)
  let seq2 = Poly.sturm_sequence (qp [1;0;1]) in
  Alcotest.(check int) "0 real roots" 0 (Poly.count_roots_in seq2 (Q.of_int (-10)) (Q.of_int 10))

let test_poly_isolate () =
  let p = qp [-1;-3;0;1] in                 (* x³ - 3x - 1 *)
  let iv = Poly.isolate_roots p in
  Alcotest.(check int) "three isolating intervals" 3 (List.length iv);
  (* each interval brackets a sign change of p *)
  List.iter
    (fun (lo, hi) ->
      Alcotest.(check bool) "sign change in interval" true
        (Poly.sign_at p lo * Poly.sign_at p hi <= 0))
    iv;
  (* intervals are ascending and disjoint *)
  let rec ordered = function
    | (_, h1) :: ((l2, _) :: _ as r) -> Q.compare h1 l2 <= 0 && ordered r
    | _ -> true
  in
  Alcotest.(check bool) "ascending disjoint" true (ordered iv)
```

Register:

```ocaml
          Alcotest.test_case "sturm count" `Quick test_poly_sturm_count;
          Alcotest.test_case "isolate roots" `Quick test_poly_isolate;
```

- [ ] **Step 2: Run to verify failure**

Run: `dune test 2>&1 | head -20`
Expected: `Unbound value Poly.sturm_sequence` / `isolate_roots`.

- [ ] **Step 3: Implement (append to `lib/poly.ml`)**

```ocaml
let sign_at (p : t) (x : Q.t) : int = Q.sign (eval p x)

(* Standard Sturm chain: s0 = p, s1 = p', s_{k+1} = -rem(s_{k-1}, s_k). *)
let sturm_sequence (p : t) : t list =
  let s0 = p and s1 = derivative p in
  let rec aux acc a b =
    if is_zero b then List.rev acc else aux (b :: acc) b (neg (rem a b))
  in
  aux [ s0 ] s0 s1

let sign_changes (seq : t list) (x : Q.t) : int =
  let signs =
    List.filter_map
      (fun s ->
        let v = sign_at s x in
        if v = 0 then None else Some v)
      seq
  in
  let rec count = function
    | a :: (b :: _ as r) -> (if a <> b then 1 else 0) + count r
    | _ -> 0
  in
  count signs

(* Number of distinct real roots in (lo, hi]. *)
let count_roots_in (seq : t list) (lo : Q.t) (hi : Q.t) : int =
  sign_changes seq lo - sign_changes seq hi

(* 1 + max|a_i|/|a_n| bounds the absolute value of every real root. *)
let cauchy_bound (p : t) : Q.t =
  let an = Q.abs (leading p) in
  let m = Array.fold_left (fun acc c -> Q.max acc (Q.abs c)) Q.zero p in
  Q.add Q.one (Q.div m an)

(* Disjoint open intervals each holding exactly one simple real root, ascending.
   Works on the squarefree part so every root is simple. *)
let isolate_roots (p : t) : (Q.t * Q.t) list =
  let p = squarefree_part p in
  if degree p < 1 then []
  else begin
    let seq = sturm_sequence p in
    let b = cauchy_bound p in
    let two = Q.of_int 2 in
    let rec go lo hi acc =
      match count_roots_in seq lo hi with
      | 0 -> acc
      | 1 -> (lo, hi) :: acc
      | _ ->
          let m = Q.div (Q.add lo hi) two in
          (* a rational root exactly at m would sit in (lo,m]; nudge so each
             reported interval is open around a single root. squarefree => the
             midpoint is a root only finitely often; perturb when it happens. *)
          let m = if sign_at p m = 0 then Q.div (Q.add lo m) two else m in
          go lo m (go m hi acc)
    in
    go (Q.neg b) b []
  end
```

- [ ] **Step 4: Run to verify pass**

Run: `dune test 2>&1 | tail -20`
Expected: `poly` suite passes.

- [ ] **Step 5: Commit**

```bash
git add lib/poly.ml tests/test_beloch.ml
git commit -m "feat(poly): Sturm sequences, real-root counting and isolation"
```

---

### Task 4: Rewrite `Num` as a real-algebraic kernel

**Files:**
- Rewrite: `lib/num.ml` (replace the `Rat | Ext` implementation wholesale)
- Test: `tests/test_beloch.ml` (extend `"num"` cases)

**Interfaces:**
- Consumes: all of `Poly` (Tasks 1–3).
- Produces (frozen + one addition):
  `type t`; `zero one : t`; `of_q : Q.t -> t`; `of_int : int -> t`; `neg add sub mul div : t -> t -> t` (`sub`/`div` derived); `inv : t -> t`; `sqrt : t -> t`; `sign : t -> int`; `compare equal`; `to_float : t -> float`; **new** `real_roots : t array -> t list` (real roots, ascending, of the polynomial whose coefficients — low-first — are these `Num` values; coefficients may themselves be irrational).

- [ ] **Step 1: Write/extend the failing tests**

Keep the existing `test_num_*` functions — they are the regression guard and must keep passing against the new kernel. Add:

```ocaml
(* ---- Num: real-algebraic kernel ---- *)
let test_num_real_roots_cubic () =
  (* x³ - 3x - 1 : three real roots ≈ -1.532, -0.347, 1.879, ascending *)
  let coeffs = [| Num.of_int (-1); Num.of_int (-3); Num.zero; Num.one |] in
  let roots = Num.real_roots coeffs in
  Alcotest.(check int) "three real roots" 3 (List.length roots);
  (* ascending *)
  let rec asc = function
    | a :: (b :: _ as r) -> Num.compare a b < 0 && asc r
    | _ -> true
  in
  Alcotest.(check bool) "ascending" true (asc roots);
  (* each is an actual root: evaluating x³-3x-1 gives 0 *)
  List.iter
    (fun x ->
      let v =
        Num.sub
          (Num.sub (Num.mul x (Num.mul x x)) (Num.mul (Num.of_int 3) x))
          Num.one
      in
      Alcotest.(check int) "root vanishes" 0 (Num.sign v))
    roots;
  (* float check on the largest root *)
  let largest = List.nth roots 2 in
  Alcotest.(check bool) "largest ≈ 1.8794" true
    (Float.abs (Num.to_float largest -. 1.8793852) < 1e-6)

let test_num_casus_irreducibilis_distinct () =
  (* the three roots are pairwise distinct (sign of differences nonzero) *)
  let coeffs = [| Num.of_int (-1); Num.of_int (-3); Num.zero; Num.one |] in
  match Num.real_roots coeffs with
  | [ a; b; c ] ->
      Alcotest.(check bool) "a≠b" false (Num.equal a b);
      Alcotest.(check bool) "b≠c" false (Num.equal b c);
      Alcotest.(check bool) "a≠c" false (Num.equal a c)
  | _ -> Alcotest.fail "expected three roots"
```

> Note: `real_roots` with **irrational** coefficients (e.g. `x² − (1+√2)`) is
> *not* tested here — that path is deferred to the axiom 7 slice (slice 2), the
> only caller that needs it. Slice 1's `real_roots` handles rational
> coefficients (the cubic above); `sqrt` of an algebraic argument does *not* go
> through `real_roots` (see the `sqrt` implementation). The existing
> `test_num_nested_radical` (`(√(1+√2))² = 1+√2`) is the gate for algebraic
> `sqrt` and must keep passing.

Register in the `"num"` suite of the run block:

```ocaml
          Alcotest.test_case "real roots cubic" `Quick test_num_real_roots_cubic;
          Alcotest.test_case "casus irreducibilis distinct" `Quick
            test_num_casus_irreducibilis_distinct;
```

- [ ] **Step 2: Run to verify failure**

Run: `dune test 2>&1 | head -20`
Expected: compile error — `Unbound value Num.real_roots`.

- [ ] **Step 3: Rewrite `lib/num.ml`**

Replace the entire file with:

```ocaml
(** Exact real algebraic numbers. A value is either an exact rational [Rat q]
    (fast-path: axioms 1–4 never leave ℚ) or [Alg {poly; lo; hi}] — the unique
    real root of the squarefree ℚ-polynomial [poly] inside the open interval
    [(lo, hi)]. Invariants for [Alg]: [poly] is squarefree, has exactly one root
    in [(lo, hi)], and that root is irrational (so it is never 0). Arithmetic
    builds the result's defining polynomial by resultant-via-interpolation and
    re-isolates; sign/compare refine the interval; [equal x y] is
    [sign (sub x y) = 0]. [to_float] is the only float, output-only.
    Algorithms: [bpr2006]. Field theory: [justin1986 §8.4d], [hull2020]. *)

type t = Rat of Q.t | Alg of { poly : Poly.t; lo : Q.t; hi : Q.t }

let zero : t = Rat Q.zero
let one : t = Rat Q.one
let of_q (q : Q.t) : t = Rat q
let of_int (i : int) : t = Rat (Q.of_int i)
let two_q = Q.of_int 2

(* defining polynomial of a value (x − q for a rational). *)
let defpoly (x : t) : Poly.t =
  match x with
  | Rat q -> Poly.of_list [ Q.neg q; Q.one ]
  | Alg a -> a.poly

(* a rational enclosure [lo,hi] of the value; tight for rationals. *)
let enclosure (x : t) : Q.t * Q.t =
  match x with Rat q -> (q, q) | Alg a -> (a.lo, a.hi)

(* refine an Alg interval once, keeping the unique root by the sign change. *)
let refine_alg (poly : Poly.t) (lo : Q.t) (hi : Q.t) : Q.t * Q.t =
  let m = Q.div (Q.add lo hi) two_q in
  let sl = Poly.sign_at poly lo and sm = Poly.sign_at poly m in
  if sm = 0 then (m, m) (* rational root hit exactly; caller collapses *)
  else if sl * sm < 0 then (lo, m)
  else (m, hi)

(* integer divisors of |n| (n ≠ 0). *)
let divisors (n : Z.t) : Z.t list =
  let n = Z.abs n in
  let rec go i acc =
    if Z.gt (Z.mul i i) n then acc
    else
      let acc =
        if Z.equal (Z.rem n i) Z.zero then
          let j = Z.div n i in
          if Z.equal i j then i :: acc else i :: j :: acc
        else acc
      in
      go (Z.succ i) acc
  in
  go Z.one []

(* rational roots of a ℚ-polynomial lying in [lo,hi], via the rational-root
   theorem after clearing denominators to ℤ. *)
let rational_roots_in (p : Poly.t) (lo : Q.t) (hi : Q.t) : Q.t list =
  if Poly.degree p < 1 then []
  else begin
    (* clear denominators: multiply by lcm of all denominators *)
    let l = Array.fold_left (fun acc c -> Z.lcm acc (Q.den c)) Z.one p in
    let ip = Array.map (fun c -> Q.num (Q.mul c (Q.of_bigint l))) p in
    let a0 = ip.(0) and an = ip.(Array.length ip - 1) in
    let cand =
      if Z.equal a0 Z.zero then [ Q.zero ]
      else
        let ps = divisors a0 and qs = divisors an in
        List.concat_map
          (fun pnum ->
            List.concat_map
              (fun qden ->
                let r = Q.make pnum qden in
                [ r; Q.neg r ])
              qs)
          ps
    in
    List.filter
      (fun r ->
        Q.compare lo r <= 0 && Q.compare r hi <= 0 && Q.equal (Poly.eval p r) Q.zero)
      cand
    |> List.sort_uniq Q.compare
  end

(* Build a value from a defining polynomial and an interval that brackets the
   intended root. Collapses to Rat when the root is rational (critically, 0). *)
let make (poly : Poly.t) (lo : Q.t) (hi : Q.t) : t =
  let s = Poly.squarefree_part poly in
  match rational_roots_in s lo hi with
  | r :: _ -> Rat r
  | [] ->
      (* refine until the interval isolates exactly one root of s and excludes
         0 (the value is irrational here, so this terminates). *)
      let seq = Poly.sturm_sequence s in
      let rec tighten lo hi =
        if Poly.count_roots_in seq lo hi <= 1 then (lo, hi)
        else
          let m = Q.div (Q.add lo hi) two_q in
          if Poly.count_roots_in seq lo m >= 1 then tighten lo m
          else tighten m hi
      in
      let lo, hi = tighten lo hi in
      Alg { poly = s; lo; hi }

let rec sign (x : t) : int =
  match x with
  | Rat q -> Q.sign q
  | Alg { poly; lo; hi } ->
      if Q.sign lo > 0 then 1
      else if Q.sign hi < 0 then -1
      else
        let lo, hi = refine_alg poly lo hi in
        sign (Alg { poly; lo; hi })

let neg (x : t) : t =
  match x with
  | Rat q -> Rat (Q.neg q)
  | Alg { poly; lo; hi } ->
      (* root of poly(−x); interval is the reflection *)
      let n = Array.length poly in
      let p' =
        Poly.of_list
          (List.init n (fun i ->
               if i mod 2 = 0 then poly.(i) else Q.neg poly.(i)))
      in
      make p' (Q.neg hi) (Q.neg lo)

(* enclosure refined to width < w *)
let enclosure_tight (x : t) (w : Q.t) : Q.t * Q.t =
  match x with
  | Rat q -> (q, q)
  | Alg { poly; lo; hi } ->
      let rec go lo hi =
        if Q.compare (Q.sub hi lo) w < 0 then (lo, hi)
        else
          let lo, hi = refine_alg poly lo hi in
          go lo hi
      in
      go lo hi

(* Given the result's defining polynomial R and a procedure that returns an
   arbitrarily tight rational enclosure of the true result value, select the
   matching root of R and return the value. *)
let select_root (r : Poly.t) (enclose : Q.t -> Q.t * Q.t) : t =
  let s = Poly.squarefree_part r in
  (* 0 is the value iff s(0)=0 and the enclosure straddles 0 *)
  let lo0, hi0 = enclose Q.one in
  if Poly.sign_at s Q.zero = 0 && Q.compare lo0 Q.zero <= 0 && Q.compare Q.zero hi0 <= 0
  then zero
  else begin
    let intervals = Poly.isolate_roots s in
    let two = Q.of_int 2 in
    let rec pick width =
      let lo, hi = enclose width in
      let hits =
        List.filter (fun (a, b) -> Q.compare a hi <= 0 && Q.compare lo b <= 0) intervals
      in
      match hits with
      | [ (a, b) ] ->
          let lo = Q.max lo a and hi = Q.min hi b in
          make s lo hi
      | _ -> pick (Q.div width two)
    in
    pick (Q.of_int 1)
  end

(* Resultant_y(A(x−y), B(y)) as a ℚ[x]-polynomial, by evaluation+interpolation:
   sample at x = 0..D, take numeric resultants, Lagrange-interpolate. *)
let res_interp (combine : Q.t -> Poly.t) (b : Poly.t) (dbound : int) : Poly.t =
  let pts =
    List.init (dbound + 1) (fun k ->
        let xk = Q.of_int k in
        (xk, Poly.resultant (combine xk) b))
  in
  Poly.interpolate pts

let defpoly_sum (a : t) (b : t) : Poly.t =
  let pa = defpoly a and pb = defpoly b in
  let d = Poly.degree pa * Poly.degree pb in
  (* A(x−y) at x=k is A(k−y): compose A with (k − y) *)
  let combine k = Poly.compose pa (Poly.of_list [ k; Q.neg Q.one ]) in
  res_interp combine pb d

let defpoly_prod (a : t) (b : t) : Poly.t =
  let pa = defpoly a and pb = defpoly b in
  let da = Poly.degree pa in
  let d = da * Poly.degree pb in
  (* y^{da} · A(k/y) at x=k : coefficient a_i k^i sits on y^{da−i} *)
  let combine k =
    Poly.of_list
      (List.init (da + 1) (fun j ->
           let i = da - j in
           Q.mul pa.(i) (Poly.qpow k i)))
  in
  res_interp combine pb d

(* fast path: shift an Alg by a rational — poly(x−q), interval shifted. *)
let shift_alg (poly : Poly.t) (lo : Q.t) (hi : Q.t) (q : Q.t) : t =
  let p' = Poly.compose poly (Poly.of_list [ Q.neg q; Q.one ]) in
  make p' (Q.add lo q) (Q.add hi q)

(* fast path: scale an Alg by a nonzero rational — poly(x/q), interval scaled. *)
let scale_alg (poly : Poly.t) (lo : Q.t) (hi : Q.t) (q : Q.t) : t =
  let p' = Poly.compose poly (Poly.of_list [ Q.zero; Q.inv q ]) in
  if Q.sign q > 0 then make p' (Q.mul q lo) (Q.mul q hi)
  else make p' (Q.mul q hi) (Q.mul q lo)

let add (x : t) (y : t) : t =
  match (x, y) with
  | Rat a, Rat b -> Rat (Q.add a b)
  | Alg a, Rat q | Rat q, Alg a -> shift_alg a.poly a.lo a.hi q
  | Alg _, Alg _ ->
      let r = defpoly_sum x y in
      let enclose w =
        let xl, xh = enclosure_tight x (Q.div w two_q) in
        let yl, yh = enclosure_tight y (Q.div w two_q) in
        (Q.add xl yl, Q.add xh yh)
      in
      select_root r enclose

let sub (x : t) (y : t) : t = add x (neg y)

let mul (x : t) (y : t) : t =
  match (x, y) with
  | Rat a, Rat b -> Rat (Q.mul a b)
  | _ when sign x = 0 || sign y = 0 -> zero
  | Alg a, Rat q | Rat q, Alg a -> scale_alg a.poly a.lo a.hi q
  | _ ->
      let r = defpoly_prod x y in
      (* enclosure of a product from operand enclosures (sign-aware) *)
      let enclose w =
        let xl, xh = enclosure_tight x w in
        let yl, yh = enclosure_tight y w in
        let prods = [ Q.mul xl yl; Q.mul xl yh; Q.mul xh yl; Q.mul xh yh ] in
        ( List.fold_left Q.min (List.hd prods) (List.tl prods),
          List.fold_left Q.max (List.hd prods) (List.tl prods) )
      in
      select_root r enclose

let inv (x : t) : t =
  match x with
  | Rat q -> if Q.equal q Q.zero then invalid_arg "Num.inv: zero" else Rat (Q.inv q)
  | Alg _ ->
      if sign x = 0 then invalid_arg "Num.inv: zero";
      (* root of the reversed polynomial; enclosure is 1/[lo,hi] *)
      let p = defpoly x in
      let rev = Poly.of_list (List.rev (Array.to_list p)) in
      let enclose w =
        let lo, hi = enclosure_tight x w in
        (* x is bounded away from 0 (sign≠0); both ends share its sign *)
        (Q.inv hi, Q.inv lo)
      in
      select_root rev enclose

let div (x : t) (y : t) : t = mul x (inv y)
let compare (x : t) (y : t) : int = sign (sub x y)
let equal (x : t) (y : t) : bool = sign (sub x y) = 0

(* real roots, ascending, of the polynomial whose low-first coefficients are the
   given Num values. SLICE 1: rational coefficients only — the kernel demo and
   the foundation axiom 7 (slice 2) builds on. The irrational-coefficient case
   (eliminating coefficient generators by resultant) is deferred to the axiom 7
   slice, its only caller. *)
let real_roots (coeffs : t array) : t list =
  let n = Array.length coeffs in
  if n = 0 then []
  else begin
    let q_of c = match c with Rat q -> q | Alg _ ->
      failwith "Num.real_roots: algebraic coefficients deferred to the axiom 7 slice"
    in
    let p = Poly.of_list (Array.to_list (Array.map q_of coeffs)) in
    Poly.isolate_roots p
    |> List.map (fun (lo, hi) -> make p lo hi)
    |> List.sort compare
  end

(* √x, exact for rational *and* algebraic x: √x is a root of x's defining
   polynomial composed with (·)², i.e. poly(y²); the positive one is bracketed by
   exact sign tests of (m² − x). No dependency on real_roots. *)
let sqrt (x : t) : t =
  if sign x < 0 then invalid_arg "Num.sqrt: negative argument";
  if sign x = 0 then zero
  else begin
    let p = defpoly x in
    let p2 = Poly.compose p (Poly.of_list [ Q.zero; Q.zero; Q.one ]) in
    let _, hi = enclosure x in
    (* bracket √x in (lo_s, hi_s) with lo_s² ≤ x ≤ hi_s², tightened until the
       squared bracket sits strictly inside x's own isolating window so only √x
       (no other positive root of p2) lives in it. *)
    let lo_x, hi_x = enclosure x in
    let cmp_sq m = sign (sub (Rat (Q.mul m m)) x) in  (* sign of m² − x *)
    let rec go lo_s hi_s =
      let m = Q.div (Q.add lo_s hi_s) two_q in
      let lo_s, hi_s = if cmp_sq m <= 0 then (m, hi_s) else (lo_s, m) in
      let inside =
        Q.compare (Q.mul lo_s lo_s) lo_x >= 0
        && Q.compare (Q.mul hi_s hi_s) hi_x <= 0
      in
      if inside || Q.compare (Q.sub hi_s lo_s) (Q.of_ints 1 1000000000) < 0 then
        (lo_s, hi_s)
      else go lo_s hi_s
    in
    let lo_s, hi_s = go Q.zero (Q.add hi Q.one) in
    make p2 lo_s hi_s
  end

let rec to_float (x : t) : float =
  match x with
  | Rat q -> Q.to_float q
  | Alg { poly; lo; hi } ->
      let w = Q.of_ints 1 1000000000000 in
      let lo, hi = enclosure_tight (Alg { poly; lo; hi }) w in
      Q.to_float (Q.div (Q.add lo hi) two_q)
```

> **Implementation note for the executor:** the resultant-via-interpolation
> machinery (`defpoly_sum`/`defpoly_prod`/`res_interp`/`select_root`) is only
> reached by `Alg + Alg` and `Alg × Alg` (e.g. `√2 + √3`). The common mixed
> cases (`Alg ± Rat`, `Alg × Rat`) take the cheap `shift_alg`/`scale_alg`
> paths, and `sqrt` is independent of `real_roots` — so the existing geometry
> tests exercise mostly the fast paths. If an `Alg+Alg`/`Alg×Alg` case in
> Task 5 stalls, check `select_root`'s `pick` halves `width` each retry and that
> `res_interp`'s sample count `dbound+1` matches the result degree.

Also add `Poly.interpolate` and expose `Poly.qpow` — append to `lib/poly.ml`:

```ocaml
(* Lagrange interpolation through points with distinct x-coordinates. *)
let interpolate (pts : (Q.t * Q.t) list) : t =
  let xs = List.map fst pts in
  List.fold_left
    (fun acc (xi, yi) ->
      (* basis polynomial L_i(x) = ∏_{j≠i} (x − xj)/(xi − xj) *)
      let li =
        List.fold_left
          (fun p xj ->
            if Q.equal xj xi then p
            else
              let denom = Q.sub xi xj in
              mul p (of_list [ Q.div (Q.neg xj) denom; Q.div Q.one denom ]))
          (of_list [ Q.one ]) xs
      in
      add acc (scale yi li))
    zero pts
```

(`qpow` is already defined in Task 2 as part of `resultant`; ensure it is a top-level `let qpow` — if it was written `and qpow` inside the `resultant` group, that is fine, it stays callable as `Poly.qpow`.)

- [ ] **Step 4: Run to verify pass**

Run: `dune test 2>&1 | tail -40`
Expected: all `num` cases (existing + new) pass. If a long-running case stalls, it indicates an interval-refinement loop not terminating — check `select_root`'s `pick` shrinks `width` and that `make` collapses rationals (0 in particular).

- [ ] **Step 5: Commit**

```bash
git add lib/num.ml lib/poly.ml tests/test_beloch.ml
git commit -m "feat(num): real-algebraic kernel — poly+interval, retire the Ext tower"
```

---

### Task 5: Integration gate — full suite green

**Files:**
- Possibly modify: `lib/geom.ml`, `lib/isometry.ml`, `lib/fold_state.ml`, `lib/fold_emit.ml`, `lib/eval.ml` (only if the build surfaces a removed-symbol reference — none expected, since `Ext`/`compare_struct` were `num.ml`-internal).
- Test: run everything.

**Interfaces:**
- Consumes: the rewritten `Num` (Task 4).
- Produces: a fully green build + test run; no API changes.

- [ ] **Step 1: Build the library alone**

Run: `dune build 2>&1 | head -40`
Expected: clean build. If an error names `Num.Ext` or `compare_struct`, that file pattern-matched the old representation — replace the match with the public interface (`sign`/`compare`/`equal`/arithmetic). Record any such site here before fixing.

- [ ] **Step 2: Run the entire suite**

Run: `dune test 2>&1 | tail -40`
Expected: every suite green — `error`, `geom` (incl. axioms 1–6: bisector, project, circle-line, beloch through-point), `fold_clip`, `parse`, `eval`, `e2e`, `poly`, `num`, isometry, angle-bisector, parallel-midline. This is the migration's acceptance gate (no behaviour change, only a slower irrational path).

- [ ] **Step 3: Sanity-check an irrational end-to-end fold**

Run an existing axiom-5/6 example to confirm FOLD emission (which calls `Num.to_float`) still produces finite coordinates:

Run: `dune exec -- beloch examples/<an-axiom5-or-6-example>.bel 2>&1 | head -20`
(Substitute a real example path from `examples/`; if none exercises axiom 5/6, skip and rely on the test suite.)
Expected: valid FOLD JSON, numeric vertex coordinates.

- [ ] **Step 4: Commit (only if any source file needed a fix)**

```bash
git add -A
git commit -m "refactor(core): migrate geometry callers to the real-algebraic Num"
```

If no source change was needed beyond Task 4, skip the commit and note "integration green, no caller changes required".

---

### Task 6: Docs — ADR 0012, references, spec, journal

**Files:**
- Create: `decisions/0012-real-algebraic-number-kernel.md`
- Modify: `decisions/0010-constructible-real-numbers.md` (Status line)
- Modify: `paper/references.bib`, `bibliography.md`
- Modify: `spec/SPECIFICATION.md` (numbering / cube-root note)
- Create: `notes/2026-06-30-real-algebraic-kernel.md`

**Interfaces:** none (documentation).

- [ ] **Step 1: Write ADR 0012**

Create `decisions/0012-real-algebraic-number-kernel.md`:

```markdown
# 0012 — Real-algebraic number kernel

**Status:** Accepted (supersedes [0010](0010-constructible-real-numbers.md))

## Context

[ADR 0010](0010-constructible-real-numbers.md) gave `Num` a quadratic-extension
tower (`Rat | Ext(a,b,d)` = a+b√d) — the constructible reals, enough for axioms
1–6 (square roots only) — and explicitly deferred the degree-3 kernel until
axioms 6/7 forced it.

Axiom 7 (Justin ⑦, the Beloch fold) forces it. Its crease is a common tangent to
two parabolas, i.e. a root of a general cubic `[justin1986 §2–3]` with 1 or 3
real roots `[justin1986 §4, remark]`. When there are three real roots the *casus
irreducibilis* applies: the real roots cannot be written with real radicals
(Cardano routes through complex cube roots). A `Cbrt` generator is therefore
provably insufficient. Justin names the target field exactly: K₃ is the smallest
real field closed under the real roots of `x³ + px + q = 0` `[justin1986 §8.4d]`;
`[hull2020]` characterises origami numbers by their minimal polynomials.

## Decision

Represent every Beloch number as a **real algebraic number** in the standard
isolating-interval form `[bpr2006 Ch. 10]`:

    type t = Rat of Q.t | Alg of { poly : Poly.t; lo : Q.t; hi : Q.t }

`Alg` is the unique real root of the squarefree ℚ-polynomial `poly` inside the
open interval `(lo, hi)`; the root is irrational (rationals collapse to `Rat`).

- **Arithmetic** builds the result's defining polynomial by resultant, computed
  via evaluation + Lagrange interpolation (numeric Sylvester determinants only,
  no symbolic polynomial determinants) `[bpr2006 Ch. 4]`, then re-isolates the
  result interval.
- **Sign / compare** refine the interval (`compare x y = sign (x−y)`); **equal**
  is `sign (x−y) = 0`. Sturm sequences count and isolate roots
  `[bpr2006 Ch. 2, 9, 10]`.
- **Rational fast-path** (`Rat`) keeps axioms 1–4 in ℚ with no resultant cost.
- New constructor `real_roots` returns the real roots (ascending) of a
  polynomial with `Num` coefficients — what axiom 7 calls.

The elegant `Ext` tower is **retired**: one representation for all irrationals.

## Alternatives considered

- **`Cbrt` generator.** Rejected: casus irreducibilis — real radicals cannot
  express the 3-real-root case, which is exactly trisection / heptagon.
- **Keep `Ext` as a quadratic fast-path under the algebraic layer.** Rejected
  now (YAGNI): reintroduces the dual-irrational-path complexity we are
  collapsing; revisit only if profiling demands it.
- **Thom encoding** instead of isolating intervals. Deferred: intervals suffice
  `[bpr2006 Ch. 10]`.

## Consequences

- √-heavy axioms 5/6 lose the closed-form `a+b√d` speed (resultants are
  heavier); deep nesting grows defining-polynomial degree. Accepted —
  correctness over speed, the same bargain as ADR 0010, now paid in full. The
  `Rat` fast-path keeps the common case free.
- The public `Num` interface is unchanged (plus `real_roots`), so the geometry
  core migrated without API churn.
- `to_float` stays the only float, output-only.
- Unblocks axiom 7 (Justin ⑦) with no further kernel change.
```

- [ ] **Step 2: Mark ADR 0010 superseded**

In `decisions/0010-constructible-real-numbers.md`, change the status line:

```markdown
**Status:** Superseded by [0012](0012-real-algebraic-number-kernel.md)
```

- [ ] **Step 3: Add the reference**

Append to `paper/references.bib`:

```bibtex
@book{bpr2006,
  author    = {Basu, Saugata and Pollack, Richard and Roy, Marie-Fran\c{c}oise},
  title     = {Algorithms in Real Algebraic Geometry},
  edition   = {2},
  series    = {Algorithms and Computation in Mathematics},
  volume    = {10},
  publisher = {Springer},
  year      = {2006},
}
```

Add a note to `bibliography.md` (match the file's existing entry format):

```markdown
- **bpr2006** — Basu, Pollack, Roy, *Algorithms in Real Algebraic Geometry*
  (2nd ed., Springer 2006). Source for the real-algebraic number kernel:
  resultants/subresultants (Ch. 4, 8), Sturm sequences and real-root counting
  (Ch. 2, 9), real-root isolation (Ch. 10). Grounds ADR 0012 and `lib/poly.ml`.
```

- [ ] **Step 4: Update the spec numbering note**

In `spec/SPECIFICATION.md`, find the line stating cube roots do not arise until
axiom 7, and add a sentence that the **number kernel now represents them** (real
algebraic numbers, ADR 0012) while the axiom 7 *surface* is still pending:

```markdown
As of the real-algebraic kernel (ADR 0012), `Num` represents arbitrary real
algebraic numbers (cube roots and the casus-irreducibilis cubics included);
axioms 1–6 are unchanged in behaviour. The axiom 7 statement surface itself is
the next slice.
```

- [ ] **Step 5: Write the journal entry**

Create `notes/2026-06-30-real-algebraic-kernel.md`:

```markdown
# 2026-06-30 — Real-algebraic number kernel (slice 1 of axiom 7)

Retired the quadratic `Ext` tower (ADR 0010) for a real-algebraic kernel
(ADR 0012): a number is `Rat q` or the unique real root of a squarefree
ℚ-polynomial in an isolating interval. New `lib/poly.ml` (ℚ-polynomials,
Sylvester resultant, Euclidean gcd/squarefree, Sturm, isolation). `lib/num.ml`
rewritten; public interface frozen (+ `real_roots`), so the geometry core
migrated with no API churn.

## Why the rewrite, not a Cbrt bolt-on

Axiom 7's crease is a common tangent to two parabolas → a general cubic with 1 or
3 real roots `[justin1986 §2–3, §4]`. The 3-root case is the casus irreducibilis:
real roots that are not real radicals. So `Cbrt` is provably too weak; we need
roots of arbitrary integer polynomials. Field target: K₃, closed under real roots
of x³+px+q `[justin1986 §8.4d]`.

## How

Arithmetic builds the result's defining polynomial by resultant via
evaluation+interpolation (numeric determinants only), then re-isolates; sign by
interval refinement; equal = sign(diff)=0; rationals collapse (0 critically).
Algorithms grounded to `[bpr2006]`. Cost: slower √-heavy axioms (resultants vs
a+b√d), accepted — the `Rat` fast-path keeps axioms 1–4 free.

## Next

Axiom 7 surface (`map .p onto --d and .q onto --e [toward .x]`) on top of this,
its own slice; parabola algebra pinned to `[hull2020]` then.
```

- [ ] **Step 6: Update the roadmap memory**

Update the memory note `beloch-workflow-and-roadmap.md` so the roadmap reflects
that the real-algebraic kernel shipped and axiom 7's surface is the next slice
(the executor should do this via the memory mechanism, not by editing repo files).

- [ ] **Step 7: Commit**

```bash
git add decisions/0012-real-algebraic-number-kernel.md decisions/0010-constructible-real-numbers.md paper/references.bib bibliography.md spec/SPECIFICATION.md notes/2026-06-30-real-algebraic-kernel.md
git commit -m "docs(num): ADR 0012 real-algebraic kernel, bpr2006, spec + journal"
```

---

## Self-Review

**Spec coverage:**
- Representation (Rat | Alg, poly+interval) → Task 4. ✓
- `lib/poly.ml` (resultant, Sturm, isolation, gcd/squarefree) → Tasks 1–3. ✓
- Rational fast-path kept → `Rat` branch in every op (Task 4); guarded by `test_num_rational`. ✓
- `real_roots` (rational coeffs) → Task 4, guarded by the cubic test; `sqrt` is independent of it (root of `poly(y²)`, exact bracket), guarded by `test_num_sqrt` + `test_num_nested_radical`. Irrational-coefficient `real_roots` is explicitly deferred to slice 2 (raises a clear failure if hit). ✓
- Sign/compare/equal via refinement → Task 4. ✓
- Migration, interface frozen, full suite green → Task 5. ✓
- ADR 0012 ⊃ 0010, `bpr2006` in bib/bibliography, spec note, journal → Task 6. ✓
- Tests: resultant value, Sturm count, isolation, rational fast-path, sqrt collapse, nested radical, casus-irreducibilis 3-root ordering, to_float → Tasks 2–4. ✓ (Spec named separate `test_poly.ml`/`test_num.ml`; plan folds them into the existing single `test_beloch.ml` per the codebase's established one-executable pattern — deliberate, noted in File Structure.)

**Placeholder scan:** No scaffold/dead code remains — `real_roots`'s irrational branch is a deliberate `failwith` (deferred to slice 2), not a placeholder. No `TODO`/`TBD`. Example path in Task 5 Step 3 is marked "substitute a real path / skip" — acceptable, an optional sanity check guarded by the test suite.

**Type consistency:** `Poly.t = Q.t array` used uniformly; `make`, `select_root`, `defpoly_sum/prod`, `res_interp`, `enclosure_tight`, `shift_alg`, `scale_alg` signatures consistent across call sites; `Poly.interpolate`/`qpow`/`resultant`/`isolate_roots`/`sturm_sequence`/`count_roots_in`/`squarefree_part`/`sign_at`/`compose` names match between definition (Tasks 1–3) and use (Task 4). `real_roots : t array -> t list` consistent between the Interfaces block, the cubic test, and (no longer) `sqrt`. `sqrt` now depends only on `defpoly`/`Poly.compose`/`make`.
