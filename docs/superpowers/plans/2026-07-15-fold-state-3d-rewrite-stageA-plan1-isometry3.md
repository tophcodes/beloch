# Isometry3 (3D rigid motion, flat-first) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an exact 3D rigid-motion module `Isometry3` — the foundation the 3D-native fold-state rewrite (#48, spec `docs/superpowers/specs/2026-07-15-fold-state-3d-rewrite-design.md`) derives every face placement from.

**Architecture:** Mirror the existing 2D `Isometry` (a matrix + translation over exact `Num.t`) in 3D. Flat-first: the only fold primitive needed now is a **half-turn** (rotation by π about a line) — which, for a line in the z=0 plane acting on z=0 points, *is* the 2D reflection. So `Isometry3` reproduces the current flat folds exactly, and generalises later (Stage B) to `rotation_about_axis θ` for `θ = rπ` (cyclotomic cos/sin) without changing this module's shape.

**Tech Stack:** OCaml, exact `Num.t` (`lib/num.ml`), Alcotest. Build/test: `direnv exec /home/toph/Projects/beloch-rewrite dune build|test`.

## Global Constraints
- **Exact-only:** every entry is `Num.t`; no floats anywhere. (`Num.of_int`, `mul`, `add`, `sub`, `neg`, `div`, `sign`, `equal`, `one`, `zero`.)
- **This module is self-contained and stays GREEN** — it has no consumers yet; the new `Fold_state` (a later plan) depends on it.
- Commit style: `feat(iso3): …`. Branch: `feat/fold-state-invariants` (worktree `/home/toph/Projects/beloch-rewrite` — verify `git branch --show-current` before committing).
- Mirror the 2D API names/shape (`lib/isometry.ml`): `identity`, `apply_point`, `compose`, `det_sign`, `inverse`.

## File structure
| File | Responsibility |
|---|---|
| `lib/isometry3.ml` (new) | `point` (3D), `t` (3×3 + translation), `identity`, `apply_point`, `compose`, `det_sign`, `inverse`, `half_turn_about_line` |
| `tests/test_isometry3.ml` (new) | unit tests incl. the flat-reflection equivalence to 2D `Isometry.reflect_across_line` |
| `tests/dune` | add the `test_isometry3` stanza |

---

## Task 1: Isometry3 core (type + identity + apply + compose + det + inverse)

**Files:**
- Create: `lib/isometry3.ml`
- Test: `tests/test_isometry3.ml`, add stanza to `tests/dune`

**Interfaces — Produces:**
- `Isometry3.point = { x : Num.t; y : Num.t; z : Num.t }`
- `Isometry3.t` (abstract-ish record: 3×3 `m00..m22` + `tx ty tz`)
- `identity : t`
- `apply_point : t -> point -> point`
- `compose : t -> t -> t`  (matrix product `a·b` + `a.trans + a.M·b.trans`, so `apply (compose a b) p = apply a (apply b p)`)
- `det_sign : t -> int`
- `inverse : t -> t`  (rigid: `M⁻¹ = Mᵀ` for orthogonal `M`; `t' = −Mᵀ·t`)

- [ ] **Step 1: Write the failing tests** (`tests/test_isometry3.ml`)

```ocaml
open Beloch
let q = Num.of_int
let p x y z = { Isometry3.x = q x; y = q y; z = q z }
let peq (a : Isometry3.point) (b : Isometry3.point) =
  Num.equal a.Isometry3.x b.Isometry3.x && Num.equal a.y b.y && Num.equal a.z b.z

let test_identity () =
  Alcotest.(check bool) "id fixes a point" true
    (peq (Isometry3.apply_point Isometry3.identity (p 3 (-2) 5)) (p 3 (-2) 5))

let test_compose_is_apply_after () =
  (* compose a b applied = a (b p); use two half-turns once that exists, here
     use identity-composed-identity as the associativity/shape check *)
  let i = Isometry3.identity in
  Alcotest.(check bool) "id∘id = id on a point" true
    (peq (Isometry3.apply_point (Isometry3.compose i i) (p 1 2 3)) (p 1 2 3))

let () =
  Alcotest.run "isometry3"
    [ ("core",
       [ Alcotest.test_case "identity" `Quick test_identity;
         Alcotest.test_case "compose" `Quick test_compose_is_apply_after ]) ]
```

- [ ] **Step 2: Run, verify it fails** — `direnv exec /home/toph/Projects/beloch-rewrite dune build tests/test_isometry3.exe 2>&1 | head`. Expected: `Unbound module Isometry3`.

- [ ] **Step 3: Implement `lib/isometry3.ml`**

```ocaml
(** Exact 3D rigid motion: a 3×3 orthogonal matrix (det ±1) plus a translation,
    all in [Num]. Places a face of the paper into 3-space. Flat folds use only
    [half_turn_about_line]; general rotation-by-θ (θ = rπ) is Stage B. *)

type point = { x : Num.t; y : Num.t; z : Num.t }

type t = {
  m00 : Num.t; m01 : Num.t; m02 : Num.t;
  m10 : Num.t; m11 : Num.t; m12 : Num.t;
  m20 : Num.t; m21 : Num.t; m22 : Num.t;
  tx : Num.t; ty : Num.t; tz : Num.t;
}

let identity : t =
  let o = Num.one and z = Num.zero in
  { m00 = o; m01 = z; m02 = z;
    m10 = z; m11 = o; m12 = z;
    m20 = z; m21 = z; m22 = o;
    tx = z; ty = z; tz = z }

let apply_point (i : t) (p : point) : point =
  let ( * ) = Num.mul and ( + ) = Num.add in
  { x = (i.m00 * p.x) + (i.m01 * p.y) + (i.m02 * p.z) + i.tx;
    y = (i.m10 * p.x) + (i.m11 * p.y) + (i.m12 * p.z) + i.ty;
    z = (i.m20 * p.x) + (i.m21 * p.y) + (i.m22 * p.z) + i.tz }

let compose (a : t) (b : t) : t =
  let ( * ) = Num.mul and ( + ) = Num.add in
  let r i0 i1 i2 j0 j1 j2 = (i0 * j0) + (i1 * j1) + (i2 * j2) in
  (* translation: a.M · b.t + a.t *)
  let tx = (a.m00 * b.tx) + (a.m01 * b.ty) + (a.m02 * b.tz) + a.tx in
  let ty = (a.m10 * b.tx) + (a.m11 * b.ty) + (a.m12 * b.tz) + a.ty in
  let tz = (a.m20 * b.tx) + (a.m21 * b.ty) + (a.m22 * b.tz) + a.tz in
  { m00 = r a.m00 a.m01 a.m02 b.m00 b.m10 b.m20;
    m01 = r a.m00 a.m01 a.m02 b.m01 b.m11 b.m21;
    m02 = r a.m00 a.m01 a.m02 b.m02 b.m12 b.m22;
    m10 = r a.m10 a.m11 a.m12 b.m00 b.m10 b.m20;
    m11 = r a.m10 a.m11 a.m12 b.m01 b.m11 b.m21;
    m12 = r a.m10 a.m11 a.m12 b.m02 b.m12 b.m22;
    m20 = r a.m20 a.m21 a.m22 b.m00 b.m10 b.m20;
    m21 = r a.m20 a.m21 a.m22 b.m01 b.m11 b.m21;
    m22 = r a.m20 a.m21 a.m22 b.m02 b.m12 b.m22;
    tx; ty; tz }

let det_sign (i : t) : int =
  let ( * ) = Num.mul and ( - ) = Num.sub and ( + ) = Num.add in
  let d =
    (i.m00 * ((i.m11 * i.m22) - (i.m12 * i.m21)))
    - (i.m01 * ((i.m10 * i.m22) - (i.m12 * i.m20)))
    + (i.m02 * ((i.m10 * i.m21) - (i.m11 * i.m20)))
  in
  Num.sign d

let inverse (i : t) : t =
  (* orthogonal M ⇒ M⁻¹ = Mᵀ; the motion q ↦ Mᵀ(q − t) *)
  let ( * ) = Num.mul and ( + ) = Num.add and neg = Num.neg in
  let tx = neg ((i.m00 * i.tx) + (i.m10 * i.ty) + (i.m20 * i.tz)) in
  let ty = neg ((i.m01 * i.tx) + (i.m11 * i.ty) + (i.m21 * i.tz)) in
  let tz = neg ((i.m02 * i.tx) + (i.m12 * i.ty) + (i.m22 * i.tz)) in
  { m00 = i.m00; m01 = i.m10; m02 = i.m20;
    m10 = i.m01; m11 = i.m11; m12 = i.m21;
    m20 = i.m02; m21 = i.m12; m22 = i.m22;
    tx; ty; tz }
```

Add to `tests/dune`:
```
(test
 (name test_isometry3)
 (libraries beloch alcotest zarith))
```

- [ ] **Step 4: Run, verify pass** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_isometry3.exe`. Expected: `Test Successful`.

- [ ] **Step 5: Commit** — `git add lib/isometry3.ml tests/test_isometry3.ml tests/dune && git commit -m "feat(iso3): 3D rigid-motion core (identity/apply/compose/det/inverse)"`

---

## Task 2: `half_turn_about_line` — the flat-fold primitive (= 2D reflection on z=0)

**Files:**
- Modify: `lib/isometry3.ml` (add `half_turn_about_line`)
- Test: `tests/test_isometry3.ml`

**Interfaces — Produces:**
- `half_turn_about_line : on:point -> dir:point -> t` — rotation by π about the line through `on` with direction `dir` (dir need not be unit; `dir·dir ≠ 0` required). Rodrigues at θ=π: `R = 2·(d dᵀ)/(d·d) − I`; translation `on − R·on`.

**Key fact this task proves:** for a line in the z=0 plane and z=0 input points, `half_turn_about_line` equals the 2D `Isometry.reflect_across_line` — so flat folds are reproduced exactly.

- [ ] **Step 1: Write the failing test** (append to `tests/test_isometry3.ml`, and add to the suite list)

```ocaml
(* a z=0 line ℓ: through (0,0) along (1,2). half_turn about it, on a z=0 point,
   must equal the 2D reflection across the same line. *)
let test_half_turn_is_2d_reflection () =
  let on = p 0 0 0 and dir = p 1 2 0 in
  let h = Isometry3.half_turn_about_line ~on ~dir in
  let l = Geom.line_through { Geom.x = q 0; y = q 0 } { Geom.x = q 1; y = q 2 } in
  let refl2d = Isometry.reflect_across_line l in
  let src2 = { Geom.x = q 3; y = q (-1) } in
  let r2 = Isometry.apply_point refl2d src2 in
  let r3 = Isometry3.apply_point h (p 3 (-1) 0) in
  Alcotest.(check bool) "half-turn on z=0 = 2D reflection" true
    (Num.equal r3.Isometry3.x r2.Geom.x
     && Num.equal r3.y r2.Geom.y
     && Num.sign r3.z = 0)

let test_half_turn_is_involution () =
  let h = Isometry3.half_turn_about_line ~on:(p 0 0 0) ~dir:(p 1 2 0) in
  let hh = Isometry3.compose h h in
  Alcotest.(check bool) "h∘h = id on a point" true
    (peq (Isometry3.apply_point hh (p 5 7 (-3))) (p 5 7 (-3)))
```
(Add both cases to the `"core"` list — or a new `"half_turn"` group — in `Alcotest.run`.)

- [ ] **Step 2: Run, verify it fails** — `Unbound value Isometry3.half_turn_about_line`.

- [ ] **Step 3: Implement `half_turn_about_line`** (add to `lib/isometry3.ml`)

```ocaml
let half_turn_about_line ~(on : point) ~(dir : point) : t =
  let ( * ) = Num.mul and ( + ) = Num.add and ( - ) = Num.sub in
  let dd = (dir.x * dir.x) + (dir.y * dir.y) + (dir.z * dir.z) in
  (* R = 2 (d dᵀ)/(d·d) − I ; entry (i,j) = 2 d_i d_j / dd − [i=j] *)
  let two = Num.of_int 2 in
  let e di dj diag =
    Num.sub (Num.div (Num.mul two (Num.mul di dj)) dd)
      (if diag then Num.one else Num.zero)
  in
  let m00 = e dir.x dir.x true  and m01 = e dir.x dir.y false and m02 = e dir.x dir.z false
  and m10 = e dir.y dir.x false and m11 = e dir.y dir.y true  and m12 = e dir.y dir.z false
  and m20 = e dir.z dir.x false and m21 = e dir.z dir.y false and m22 = e dir.z dir.z true in
  (* translation so [on] is fixed: t = on − R·on *)
  let rx = (m00 * on.x) + (m01 * on.y) + (m02 * on.z) in
  let ry = (m10 * on.x) + (m11 * on.y) + (m12 * on.z) in
  let rz = (m20 * on.x) + (m21 * on.y) + (m22 * on.z) in
  { m00; m01; m02; m10; m11; m12; m20; m21; m22;
    tx = on.x - rx; ty = on.y - ry; tz = on.z - rz }
```

- [ ] **Step 4: Run, verify pass** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_isometry3.exe`. Expected: `Test Successful` (4 cases). Also `dune build` clean.

- [ ] **Step 5: Commit** — `git add lib/isometry3.ml tests/test_isometry3.ml && git commit -m "feat(iso3): half_turn_about_line — flat fold = 2D reflection on z=0"`

---

## Self-review
- **Spec coverage:** delivers the `Isometry3` (3D rigid motion) the spec's model + clean-rewrite step 1 require; flat-first (`half_turn` only) reproduces flat folds exactly; general `rotation_about_axis θ` is explicitly Stage B (not here). ✓
- **Placeholder scan:** none — every step has complete OCaml. ✓
- **Type consistency:** `point`/`t` field names (`m00..m22`, `tx/ty/tz`, `x/y/z`) used identically across tasks; `half_turn_about_line ~on ~dir` matches its test. ✓
- **Exactness:** all `Num`; `half_turn` uses `d·d` division (no sqrt/normalisation) — exact. ✓

## Next plans (Stage A, written after this lands)
- **Plan 2 — new `Fold_state` core:** hinge graph (faces + hinges with `angle : Rat·π`, flat-first `{0,±π}`), derived `face_iso : t -> int -> Isometry3.t` (memoised reflection-path product from a root), rank order, derived MV, smart constructor `make` (taco + half-plane) — with its own invariant tests (single fold / rabbit ear / waterbomb) proven in isolation. Coexists with the old `Fold_state` (green).
- **Plan 3 — port + delete:** rewrite `Collapse` + fold construction onto the new core; port `eval`/`flatten`/`fold_emit`/render bridge/tests (~159 sites); delete old `Fold_state` internals, `Layer_order` relation table, MV upgrade passes.
