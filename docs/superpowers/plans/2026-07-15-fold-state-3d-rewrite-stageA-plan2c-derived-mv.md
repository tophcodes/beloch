# Fold_graph derived M/V + waterbomb invariant test — Implementation Plan (Stage A / Plan 2c)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** M/V becomes **derived** from the layer order + placements — `mv : t -> int -> mv option` per hinge — killing the stored-`eassign` pattern; plus the full-cycle invariant test the spec asks for: a waterbomb-style 8-fan constructed through `make`, asserting closure, non-crossing, placements, and Maekawa's theorem via the derived MV.

**Architecture:** The rule is the textbook definition [hullzakharevich2023, §2.1]: for a crease between faces U1, U2 where U1's orientation is preserved under the folding map, the crease is a **valley** iff U1 lies **below** U2 (the paper's λ(p,q)=1 means p below q). In `Fold_graph` terms: `V ⟺ above(fb, fa) = face_up(fa)` — orientation from the derived placement (`m22` sign; in-plane determinant equals `m22` since the 3D determinant is always +1 here), layer relation from the rank. The formula is side-symmetric (checked from fb it gives the same answer), so it is well-defined per hinge. It also agrees with the old evaluator's calibration (`fold_state.ml:1083`: `V ⟺ valley XOR reflected` with the mover stacked on top for valley). A hinge with `angle = 0` has no M/V → `None`.

**Tech Stack:** OCaml, `Num.t` exact, existing `Fold_graph` internals (`isos`, `rank`, `above`). Build/test: `direnv exec /home/toph/Projects/beloch-rewrite dune build|exec`.

## Global Constraints

- **Exact-only** `Num.t`; no floats.
- `Fold_graph` stays self-contained + green; no other module touched.
- MV is **derived, never stored** — no new field in `t`.
- Branch `feat/fold-state-invariants` (worktree `/home/toph/Projects/beloch-rewrite`); **verify branch with `git branch --show-current` before every commit**. Subagents: `cd /home/toph/Projects/beloch-rewrite` first — they start in the main checkout.
- Known pre-existing failures in full `dune test` (ignore): test_golden rabbit-ear/swivel-rabbit "syntax error", test_eval "found example files".

## File structure

| File | Responsibility |
|---|---|
| `lib/fold_graph.ml` | `type mv = M \| V`; `face_up`; `mv` |
| `lib/fold_graph.mli` | expose the three, with the refs-grounded doc |
| `tests/test_fold_graph.ml` | MV unit tests + waterbomb 8-fan invariant suite |

---

## Task 1: Derived M/V

**Files:**
- Modify: `lib/fold_graph.ml`, `lib/fold_graph.mli`, `tests/test_fold_graph.ml`

**Interfaces — Produces:**
- `type mv = M | V`
- `val face_up : t -> int -> bool` — face's derived placement preserves in-plane orientation
- `val mv : t -> int -> mv option` — hinge index → derived assignment; `None` for a flat hinge

**Interfaces — Consumes:** internal `t` record fields `isos`, `hinges`, plus `above` (Plan 2b). `Isometry3.t` record fields are public (no `.mli` on isometry3).

- [ ] **Step 1: Write the failing tests** — append to `tests/test_fold_graph.ml`, register suite `"derived-mv"`:

```ocaml
let test_mv_single_fold_valley () =
  (* f1 folded on TOP of face-up f0: the crease is a valley — the calibration
     case (old evaluator: valley folds stack the mover above; fold_state.ml
     assign rule V ⟺ valley XOR reflected). *)
  let g =
    mk ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
      ~rank:[| 0; 1 |] ()
  in
  Alcotest.(check bool) "f0 is face-up" true (Fold_graph.face_up g 0);
  Alcotest.(check bool) "f1 is face-down" false (Fold_graph.face_up g 1);
  Alcotest.(check bool) "hinge 0 is V" true (Fold_graph.mv g 0 = Some Fold_graph.V)

let test_mv_single_fold_mountain () =
  (* same fold, f1 tucked UNDER f0: mountain *)
  let g =
    mk ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
      ~rank:[| 1; 0 |] ()
  in
  Alcotest.(check bool) "hinge 0 is M" true (Fold_graph.mv g 0 = Some Fold_graph.M)

let test_mv_side_symmetric () =
  (* swapping fa/fb in the hinge record must not change the derived MV *)
  let hinges = [| { Fold_graph.fa = 1; fb = 0; line = vline 1; angle = q 1 } |] in
  let g = mk ~faces:(single_fold_faces ()) ~hinges ~rank:[| 0; 1 |] () in
  Alcotest.(check bool) "still V with fa/fb swapped" true
    (Fold_graph.mv g 0 = Some Fold_graph.V)

let test_mv_flat_hinge_none () =
  (* two coplanar faces joined by an unfolded crease: no M/V *)
  let hinges = [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 0 } |] in
  let g = mk ~faces:(single_fold_faces ()) ~hinges ~rank:[| 0; 1 |] () in
  Alcotest.(check bool) "flat hinge has no MV" true (Fold_graph.mv g 0 = None)

let test_mv_accordion_zigzag () =
  (* accordion bottom-to-top f0,f1,f2: the two creases alternate V then M *)
  let faces = [| strip_face 0 1; strip_face 1 1; strip_face 2 1 |] in
  let hinges =
    [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 };
       { Fold_graph.fa = 1; fb = 2; line = vline 2; angle = q 1 } |]
  in
  let g = mk ~faces ~hinges ~rank:[| 0; 1; 2 |] () in
  Alcotest.(check bool) "hinge 0 is V" true (Fold_graph.mv g 0 = Some Fold_graph.V);
  Alcotest.(check bool) "hinge 1 is M" true (Fold_graph.mv g 1 = Some Fold_graph.M)
```

Register:

```ocaml
      ( "derived-mv",
        [ Alcotest.test_case "single fold valley" `Quick test_mv_single_fold_valley;
          Alcotest.test_case "single fold mountain" `Quick
            test_mv_single_fold_mountain;
          Alcotest.test_case "side-symmetric" `Quick test_mv_side_symmetric;
          Alcotest.test_case "flat hinge none" `Quick test_mv_flat_hinge_none;
          Alcotest.test_case "accordion zigzag V,M" `Quick test_mv_accordion_zigzag ] );
```

- [ ] **Step 2: Run, verify it fails** — `direnv exec /home/toph/Projects/beloch-rewrite dune build tests/test_fold_graph.exe 2>&1 | head`. Expected: `Unbound value Fold_graph.face_up` / `Fold_graph.mv`.

- [ ] **Step 3: Implement** — append to `lib/fold_graph.ml` (after `face_iso`):

```ocaml
type mv = M | V

(* Does face [i]'s derived placement preserve in-plane orientation? The
   motions here map the z=0 plane to itself with 3D determinant +1 (identity,
   half-turns about in-plane axes, and their products), so the in-plane
   determinant equals the m22 entry: +1 for an even number of folds crossed,
   -1 for odd (a reflected, face-down placement). *)
let face_up (g : t) (i : int) : bool = Num.sign g.isos.(i).I3.m22 > 0

(* Derived M/V of hinge [i] [hullzakharevich2023, §2.1]: for a crease between
   U1 and U2 with U1's orientation preserved, the crease is a valley iff U1
   lies below U2 (the paper's λ(p,q) = 1 reads "p below q"). Here: V ⟺
   above(fb, fa) = face_up(fa). Side-symmetric — a folded hinge flips exactly
   one of face_up/above when read from fb, so both sides agree. Flat hinges
   (angle = 0) carry no M/V. Derived, never stored: rank and placements are
   the only inputs, so MV cannot contradict the geometry. *)
let mv (g : t) (i : int) : mv option =
  let h = g.hinges.(i) in
  if Num.sign h.angle = 0 then None
  else Some (if above g h.fb h.fa = face_up g h.fa then V else M)
```

Append to `lib/fold_graph.mli` (at the end):

```ocaml
type mv = M | V

val face_up : t -> int -> bool
(** Face's derived placement preserves in-plane orientation (an even number
    of folds crossed from the root). *)

val mv : t -> int -> mv option
(** Derived mountain/valley of hinge [i], from placements + rank
    [hullzakharevich2023, §2.1]: valley iff the orientation-preserved side
    lies below its neighbour. [None] for a flat hinge. Derived, never
    stored — it cannot contradict the geometry. *)
```

- [ ] **Step 4: Run, verify pass** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`. Expected: all pass (20 existing + 5 new).

- [ ] **Step 5: Commit**

```bash
git branch --show-current   # must print feat/fold-state-invariants
git add lib/fold_graph.ml lib/fold_graph.mli tests/test_fold_graph.ml
git commit -m "feat(foldgraph): derived M/V from rank + placements"
```

---

## Task 2: Waterbomb 8-fan invariant test

**Files:**
- Modify: `tests/test_fold_graph.ml` (tests only — no library change expected)

**Interfaces — Consumes:** `make`, `face_isos`, `mv`, `violation` (all shipped). This task is pure verification: an 8-face single-vertex fan (the waterbomb-base crease pattern) built through `make`, exercising every constructor check on a real model — the cycle closure over a Kawasaki-satisfying 8-cycle, the non-crossing checks on an 8-layer stack, and Maekawa's theorem falling out of the derived MV.

Geometry (all rational — exact in `Num`): unit square, centre `c = (½,½)`, corner/edge-midpoint ring walked CCW from `p0 = (1,½)`:

```
p0=(1,½) p1=(1,1) p2=(½,1) p3=(0,1) p4=(0,½) p5=(0,0) p6=(½,0) p7=(1,0)
```

Face k = triangle `(c, p_k, p_{k+1 mod 8})` (sector k). Hinge k joins faces k and k+1 (mod 8) along the line through `c` and `p_{k+1}`:

| hinge | faces | line |
|---|---|---|
| h0 | 0,1 | y=x (a=1,b=−1? — use `{a=1; b=-1; c=0}`… see below) |
| h1 | 1,2 | x=½ |
| h2 | 2,3 | x+y=1 |
| h3 | 3,4 | y=½ |
| h4 | 4,5 | y=x |
| h5 | 5,6 | x=½ |
| h6 | 6,7 | x+y=1 |
| h7 | 7,0 | y=½ |

`Geom.line` is `{a; b; c}` for `a·x + b·y = c` — check the convention in `lib/geom.ml` before writing the lines; with that convention: `y=x` → `{a=1; b=-1; c=0}`, `x=½` → `{a=1; b=0; c=½}`, `x+y=1` → `{a=1; b=1; c=1}`, `y=½` → `{a=0; b=1; c=½}`.

All 8 hinges `angle = 1`, `root = 0`, rank = the **spiral wrap** `[|0;1;2;3;4;5;6;7|]` (face k at height k). Why this rank is legal (hand-derived, for the implementer's understanding — the test asserts it): every hinge's table segment lies on one of sector 0's two boundary rays — even hinges on the `y=x` ray, odd hinges on the `y=½` ray. On the `y=x` ray the hinged pairs are `{0,1},{2,3},{4,5},{6,7}` — disjoint rank intervals; on `y=½` they are `{1,2},{3,4},{5,6},{7,0}` — `[1,2],[3,4],[5,6]` all nest inside `[0,7]` and are mutually disjoint. No interleave anywhere; face boundaries only touch the crease segments (no interior crossing), so taco-tortilla stays silent.

Expected derived MV (hand-derived): `face_up k ⟺ k even` (k reflections from the root), `above(k+1, k)` true for h0..h6, false for h7 — so h_k is V for even k, M for odd k, **except h7 which is V**:

```
[V; M; V; M; V; M; V; V]   → 5 valleys, 3 mountains, M − V = −2 (Maekawa)
```

Note h3 and h7 lie on the SAME line `y=½` yet get different assignments — the well-known symmetry-breaking half-crease of the waterbomb base, and the reason MV is per-hinge, not per-line.

- [ ] **Step 1: Write the tests** — append to `tests/test_fold_graph.ml`, register suite `"waterbomb"`:

```ocaml
(* Waterbomb-base 8-fan around the square's centre: sector faces
   (c, p_k, p_{k+1}), hinges through c, all folded; the classic
   Kawasaki-satisfying single-vertex cycle. All coordinates rational. *)
let half = Num.of_q (Q.of_ints 1 2)
let gph x y : Geom.point = { Geom.x = x; y }
let c2 = gph half half

let wb_ring =
  [| gph (q 1) half; gph (q 1) (q 1); gph half (q 1); gph (q 0) (q 1);
     gph (q 0) half; gph (q 0) (q 0); gph half (q 0); gph (q 1) (q 0) |]

let wb_faces () =
  Array.init 8 (fun k -> [| c2; wb_ring.(k); wb_ring.((k + 1) mod 8) |])

let wb_lines =
  (* line through c and p_{k+1}, k = 0..7: y=x, x=½, x+y=1, y=½, repeating *)
  [| { Geom.a = q 1; b = q (-1); c = q 0 };
     { Geom.a = q 1; b = q 0; c = half };
     { Geom.a = q 1; b = q 1; c = q 1 };
     { Geom.a = q 0; b = q 1; c = half };
     { Geom.a = q 1; b = q (-1); c = q 0 };
     { Geom.a = q 1; b = q 0; c = half };
     { Geom.a = q 1; b = q 1; c = q 1 };
     { Geom.a = q 0; b = q 1; c = half } |]

let wb_hinges () =
  Array.init 8 (fun k ->
      { Fold_graph.fa = k; fb = (k + 1) mod 8; line = wb_lines.(k); angle = q 1 })

let test_waterbomb_constructs () =
  (* the full 8-cycle passes closure (Kawasaki) and non-crossing (spiral wrap) *)
  let g =
    mk ~faces:(wb_faces ()) ~hinges:(wb_hinges ())
      ~rank:[| 0; 1; 2; 3; 4; 5; 6; 7 |] ()
  in
  (* every face lands on sector 0: p3=(0,1), three hinges from the root,
     must land on p1=(1,1) — trace: R(x+y=1)→(0,1); R(x=½)→(1,1); R(y=x)→(1,1) *)
  let isos = Fold_graph.face_isos g in
  Alcotest.(check bool) "p3 lands on (1,1)" true
    (i3eq
       (Isometry3.apply_point isos.(3)
          { Isometry3.x = q 0; y = q 1; z = q 0 })
       (p3 1 1 0));
  (* centre is fixed by every placement *)
  Alcotest.(check bool) "centre fixed under iso 5" true
    (i3eq
       (Isometry3.apply_point isos.(5)
          { Isometry3.x = half; y = half; z = q 0 })
       { Isometry3.x = half; y = half; z = q 0 })

let test_waterbomb_mv_maekawa () =
  let g =
    mk ~faces:(wb_faces ()) ~hinges:(wb_hinges ())
      ~rank:[| 0; 1; 2; 3; 4; 5; 6; 7 |] ()
  in
  let expected =
    [| Fold_graph.V; M; V; M; V; M; V; V |]
  in
  Array.iteri
    (fun i e ->
      Alcotest.(check bool)
        (Printf.sprintf "hinge %d assignment" i)
        true
        (Fold_graph.mv g i = Some e))
    expected;
  let m, v =
    Array.fold_left
      (fun (m, v) i ->
        match Fold_graph.mv g i with
        | Some Fold_graph.M -> (m + 1, v)
        | Some Fold_graph.V -> (m, v + 1)
        | None -> (m, v))
      (0, 0)
      (Array.init 8 (fun i -> i))
  in
  Alcotest.(check int) "Maekawa: |M - V| = 2" 2 (abs (m - v))

let test_waterbomb_bad_wrap_rejected () =
  (* swapping the heights of f1 and f2 interleaves tacos {0,1} and {2,3} on
     the y=x ray: rank intervals [0,2] and [1,3] cross — taco-taco *)
  expect_error "illegal wrap order"
    (function Fold_graph.Taco_taco _ -> true | _ -> false)
    ~faces:(wb_faces ()) ~hinges:(wb_hinges ())
    ~root:0 ~rank:[| 0; 2; 1; 3; 4; 5; 6; 7 |]

let test_waterbomb_tear_rejected () =
  (* unfolding one crease of the 8-cycle (angle 0 on h4) breaks Kawasaki
     closure: 7 folded creases at an interior vertex cannot close *)
  let hinges = wb_hinges () in
  hinges.(4) <- { (hinges.(4)) with Fold_graph.angle = q 0 };
  expect_error "7-of-8 folded tears"
    (function Fold_graph.Hinge_not_closed _ -> true | _ -> false)
    ~faces:(wb_faces ()) ~hinges ~root:0 ~rank:[| 0; 1; 2; 3; 4; 5; 6; 7 |]
```

Register:

```ocaml
      ( "waterbomb",
        [ Alcotest.test_case "8-cycle constructs (closure + wrap)" `Quick
            test_waterbomb_constructs;
          Alcotest.test_case "derived MV satisfies Maekawa" `Quick
            test_waterbomb_mv_maekawa;
          Alcotest.test_case "illegal wrap order rejected" `Quick
            test_waterbomb_bad_wrap_rejected;
          Alcotest.test_case "7-of-8 folded tears" `Quick
            test_waterbomb_tear_rejected ] );
```

Adapt small clashes with existing test-file helpers (e.g. if a `half` binding already exists locally in a function, the new top-level one is fine; if a top-level `half` already exists, reuse it) — but do NOT change any existing test.

- [ ] **Step 2: Run** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe 2>&1 | tail -20`.

These tests assert hand-derived expectations against already-shipped code, so they may pass immediately — that is the point (invariant pinning), not a broken TDD step. **If any case fails, STOP and debug the geometry against the tables above before touching anything**: the most likely causes are a line-convention mismatch (`Geom.line` sign of `b` for `y=x`) or a mis-indexed ring point, not a library bug. If tracing shows a genuine library bug, report BLOCKED with the trace — do not "fix" library code in this task.

- [ ] **Step 3: Full suite** — `direnv exec /home/toph/Projects/beloch-rewrite dune test` (expect only the two known pre-existing failures).

- [ ] **Step 4: Commit**

```bash
git branch --show-current   # must print feat/fold-state-invariants
git add tests/test_fold_graph.ml
git commit -m "test(foldgraph): waterbomb 8-fan invariants — closure, wrap order, Maekawa MV"
```

---

## Self-review

- **Spec coverage:** spec's "M/V is derived (`mv : t -> crease_id -> mv`) from the two face placements + their layer relation [hullzakharevich2023 §2.1]" ✓ (per-hinge index — crease ids arrive with Plan 3's construction; the waterbomb shows why per-hinge is right: h3/h7 share a line but differ). Spec's step-1 "own invariant tests — construct known folds (… waterbomb) and assert the invariants" ✓ Task 2. `eintent` storage is a Plan-3 concern (no surface layer exists here yet). Rabbit-ear parity rides on Plan 3's real construction path (irrational bisector coordinates hand-built in a test add boilerplate, no new check path).
- **Placeholder scan:** none — complete OCaml in every step. ✓
- **Type consistency:** `mv`/`face_up` names identical in .ml/.mli/tests; `above g fb fa` argument order matches Plan 2b's `above g i j = rank i > rank j` ("i above j"); `wb_lines` conventions stated with the `a·x + b·y = c` caveat and double-checked in Task 2 Step 1. ✓
- **Hand-verified math (while planning):** side-symmetry of the MV rule (folded hinge flips exactly one of face_up/above across sides); accordion zigzag V,M; waterbomb spiral-wrap legality (disjoint/nested rank intervals per ray); MV sequence [V;M;V;M;V;M;V;V] with h7 the symmetry-breaking half-crease; Maekawa |M−V| = 2. ✓

## Next plans (after this lands)

- **Plan 3 — construction + port + delete:** build the hinge graph from a crease pattern (replacing `subdivide`/`fold_with_records`); rewrite `Collapse` (the sector fan is exactly the waterbomb-style path product); port `eval`/`flatten`/`fold_emit`/render/tests (~159 sites); delete old `Fold_state`, `Layer_order` table, MV upgrade passes; rename `Fold_graph` → `Fold_state`. Carry `eintent` (user's CP colour) as the stored surface intent next to the derived MV.
