# mark / fold — Slice 2 (partial marks / the pinch) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `mark` a non-subdividing partial extent (`between .a .b`, `at .p`) so a reference/pinch crease can end mid-face without splitting the rays it crosses — the fix the whole mark/fold redesign was for.

**Architecture:** A `mark` whose extent stays boundary-to-boundary within a flap keeps subdividing (standard `F` edges, as Slice 1). A `mark` that ends **mid-face** becomes a record in a new `marks : mark array` on `Fold_state.t` that is *not* a face-boundary edge — it splits no rays and is no flap boundary. Marks store **paper-space** geometry, which is fold-invariant, so they carry through `subdivide`/`fold`/`flip` unchanged; their table position is derived from the containing face's isometry at emit/render time. Records emit into a `beloch:marks` custom FOLD field; subdividing marks stay standard `F` edges.

**Tech Stack:** OCaml (dune, menhir parser `lib/parser.mly`, hand-written lexer `lib/lexer.ml`, alcotest in `tests/`), `Yojson` for FOLD emit, TypeScript renderer `render/render-svg/bin/fold2svg.ts`.

## Global Constraints

- **Exactness:** all mark geometry is exact rational (`Num.t`/`Geom.point`). No floats, no tolerance. Snapping is exact rational equality only (`Geom.point_equal`). Copied from spec §2.2.
- **Marks are not edges:** a mark must NOT participate in `subdivide`, the coplanar-cluster / flap graph (`fold_state.ml` `coplanar_clusters` ~:382), ray-splitting, or `Layer_order`. Spec §3.
- **#26 invariant intact:** every `edge` still borders faces or the paper edge; marks are not edges. Spec §3.
- **FOLD custom fields** use `namespace:key` (`refs/foldformat.md` §Custom Properties); the namespace is `beloch:`. Spec §5.
- **Behaviour-preserving for existing corpus** except the deliberately-migrated examples (Task 9). Full-chord `mark` subdivides exactly as today.
- **Conventional commits.** Build with `dune build`; test with `dune test` (alcotest). The devshell wrapper is `./scripts/snapshot-fold.sh` for golden regen (Task 9).

Spec: `docs/superpowers/specs/2026-07-10-mark-fold-slice2-design.md` (and parent `2026-07-09-mark-fold-crease-notation-design.md`).

---

## Task 1: Data model — `mark` type + `marks` field, fold-invariant carry-through

**Files:**
- Modify: `lib/fold_state.ml` (type `t` ~:27; paper-square init ~:248-251; `subdivide` return ~:688; `fold_with_records` return ~:849; `flip` return ~:923)
- Test: `tests/test_fold_state.ml`

**Interfaces:**
- Produces:
  - `type mark_geom = MSeg of Geom.point * Geom.point | MPoint of Geom.point`
  - `type mark = { mgeom : mark_geom; mline : Geom.line; mintent : assign; mcrease_id : int }`
  - field `marks : mark array` on `Fold_state.t`
  - `val add_mark : t -> mark -> t`
  - `val mark_face : t -> mark -> int option` (index of the face whose **paper** polygon contains the mark's representative point; `None` if on no face)
  - `val mark_rep_point : mark -> Geom.point` (an endpoint for `MSeg`, the point for `MPoint`)

- [ ] **Step 1: Write the failing test**

Add to `tests/test_fold_state.ml` (which already opens `Beloch` and defines `q = Num.of_int`, `qf a b = Num.of_q (Q.of_ints a b)`). Add a point helper `let pt a b c d = { Geom.x = qf a b; y = qf c d }` near the top, then:

```ocaml
let test_marks_carry_through_fold () =
  (* add a dangling point mark at (1/4,1/4), fold the square in half along
     x=1/2, and assert the mark survives unchanged (paper coords fold-invariant). *)
  let p = pt 1 4 1 4 in
  let m =
    { Fold_state.mgeom = Fold_state.MPoint p;
      mline = Geom.line_through p (pt 3 4 1 4);
      mintent = Fold_state.V; mcrease_id = 999 }
  in
  let st = Fold_state.add_mark Fold_state.init_square m in
  let axis = { Geom.a = Num.one; b = Num.zero; c = qf 1 2 } in  (* x = 1/2, as elsewhere in this file *)
  let st' = Fold_state.fold_with_records st ~axis ~move_side:1 ~valley:true ~prov:None in
  Alcotest.(check int) "one mark preserved" 1 (Array.length st'.Fold_state.marks);
  let m' = st'.Fold_state.marks.(0) in
  (match m'.Fold_state.mgeom with
   | Fold_state.MPoint qp -> Alcotest.(check bool) "paper coord unchanged" true (Geom.point_equal p qp)
   | _ -> Alcotest.fail "geom kind changed");
  Alcotest.(check bool) "mark_face resolves to a face"
    true (Fold_state.mark_face st' m' <> None)
```

(Initial state is the value `Fold_state.init_square` (lib/fold_state.ml:246); the fold entry point is `fold_with_records … ~prov:None` (:692). There is no `Fold_state.fold` / `paper_square`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `dune test 2>&1 | head -30`
Expected: FAIL — `Unbound record field marks` / `Unbound constructor MPoint`.

- [ ] **Step 3: Add the types and field**

In `lib/fold_state.ml`, after `type assign = M | V | F` (~:10) add:

```ocaml
type mark_geom = MSeg of Geom.point * Geom.point | MPoint of Geom.point

(* A non-subdividing reference/pinch crease. [mgeom] is PAPER-space and therefore
   fold-invariant, so marks carry through subdivide/fold/flip unchanged; the
   current table position is derived at emit time from the containing face's
   isometry (see mark_face). [mline] is the underlying motion line, kept only to
   orient a point-mark's display tick. [mintent] is the crease-pattern colour;
   the mark is always flat (F) in the folded form. [mcrease_id] rides with the
   name's bundle, mirroring edge.crease_id. *)
type mark = {
  mgeom : mark_geom;
  mline : Geom.line;
  mintent : assign;
  mcrease_id : int;
}
```

Change `type t` (~:27) to add the field:

```ocaml
type t = { faces : face array; order : Layer_order.t; edges : edge array; marks : mark array }
```

- [ ] **Step 4: Thread the field through every `t` constructor**

Paper-square init (~:248-251): after `edges = [||];` add `marks = [||];`.

`subdivide` return (~:688) — change `{ faces; order; edges }` to:
```ocaml
{ faces; order; edges; marks = st.marks }
```

`fold_with_records` (~:848-849) — change `let st' = { faces; order; edges } in` to:
```ocaml
let st' = { faces; order; edges; marks = st.marks } in
```

`flip` return (~:923) — change `{ faces = rev; order; edges }` to:
```ocaml
{ faces = rev; order; edges; marks = st.marks }
```

Then add the helpers near `table_position` (~:558):

```ocaml
let mark_rep_point (m : mark) : Geom.point =
  match m.mgeom with MSeg (a, _) -> a | MPoint p -> p

let add_mark (st : t) (m : mark) : t =
  { st with marks = Array.append st.marks [| m |] }

(* the face whose PAPER polygon contains the mark's representative point; paper
   coordinates partition the sheet, so this is unique in the interior (a point on
   a shared boundary may match several — first match wins, callers disambiguate). *)
let mark_face (st : t) (m : mark) : int option =
  let p = mark_rep_point m in
  let n = Array.length st.faces in
  let rec go i =
    if i >= n then None
    else if Geom.in_convex_polygon st.faces.(i).paper p then Some i
    else go (i + 1)
  in
  go 0
```

- [ ] **Step 5: Run test to verify it passes**

Run: `dune test 2>&1 | tail -20`
Expected: PASS. (`dune build` must also be clean — the new field forces every `{ faces; order; edges }` literal to be updated; if the compiler flags one you missed, add `marks = ...` there.)

- [ ] **Step 6: Commit**

```bash
git add lib/fold_state.ml tests/test_fold_state.ml
git commit -m "feat(fold_state): marks array + mark type, fold-invariant carry-through"
```

---

## Task 2: Lexer + AST + grammar — extent, direction, and layer on `mark`

**Files:**
- Modify: `lib/lexer.ml` (keyword table ~:34)
- Modify: `lib/ast.ml` (add `extent`; change `Mark` constructor ~:94)
- Modify: `lib/parser.mly` (`%token` line ~:14; `body_stmt` mark rules ~:49-50; add `mark_clauses`/`extent_opt`/`layer_opt`)
- Test: `tests/test_eval.ml` or a parser test (match the file that already parses source — grep for `Parser.program`)

**Interfaces:**
- Produces:
  - `type extent = Full | Between of point_operand * point_operand | At of point_operand` in `Ast`
  - `Mark of string option * markable * extent * direction * flap_operand option * Error.span`

- [ ] **Step 1: Write the failing test**

Find how tests parse a program (grep `rg -n "Parser.program|parse_string|Lexer" tests/`). Add a parse test that feeds:

```
paper square
mark --l between .a .b
mark --l at .m mountain
mark --l #[.c]
mark --d = map .a onto .b at .m
```

and asserts each statement is a `Ast.Mark` with the expected `extent`, `direction`, and layer. Concretely (adapt the harness call to the existing spelling):

```ocaml
let test_mark_extent_parses () =
  let prog = parse "paper square\nmark --l between .a .b\nmark --l at .m mountain\n" in
  match prog with
  | [ Ast.Mark (None, Ast.MLine _, Ast.Between _, Ast.Valley, None, _);
      Ast.Mark (None, Ast.MLine _, Ast.At _, Ast.Mountain, None, _) ] -> ()
  | _ -> Alcotest.fail "mark extent/direction did not parse as expected"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dune test 2>&1 | head -20`
Expected: FAIL — `Between`/`At` unbound, or `Mark` arity mismatch.

- [ ] **Step 3: Add the AST**

In `lib/ast.ml`, after `type direction = Valley | Mountain` (~:62) add:

```ocaml
(* mark extent (spec §4). Full = the motion's whole chord (subdivides as before);
   Between/At are partial — record iff they end mid-face. *)
type extent =
  | Full
  | Between of point_operand * point_operand
  | At of point_operand
```

Change the `Mark` constructor (~:94-96) to:

```ocaml
  | Mark of string option * markable * extent * direction * flap_operand option * Error.span
      (* mark <motion|--l> [between .a .b | at .p] [mountain] [#[..]] ;
         flat crease. name_opt Some = `mark --l = <motion>` bind-and-materialise.
         Full extent subdivides (emits F); a mid-face extent records (no subdivide). *)
```

- [ ] **Step 4: Add tokens to the lexer**

In `lib/lexer.ml` keyword table (~:34, beside `| "mark" -> MARK`) add:

```ocaml
  | "between" -> BETWEEN
  | "at" -> AT
```

- [ ] **Step 5: Add tokens and grammar to the parser**

In `lib/parser.mly`, add `BETWEEN AT` to a `%token` line (e.g. append to line 16's `COLLAPSE OVER STANDING MARK`).

Replace the two mark rules in `body_stmt` (~:49-50):

```ocaml
  (* mark: flat crease; Full subdivides, partial extent may record *)
  | MARK markable mark_clauses
      { let (ext, dir, lay) = $3 in Mark (None, $2, ext, dir, lay, $loc) }
  | MARK CREASE EQ axiom mark_clauses
      { let (ext, dir, lay) = $5 in Mark (Some $2, MMotion $4, ext, dir, lay, $loc) }
```

Add these productions (near `fold_clauses`, ~:100):

```ocaml
mark_clauses:
  | extent_opt mountain_opt layer_opt
      { ($1, (if $2 then Mountain else Valley), $3) }

extent_opt:
  |                                     { Full }
  | BETWEEN point_operand point_operand { Between ($2, $3) }
  | AT point_operand                    { At $2 }

layer_opt:
  |              { None }
  | flap_operand { Some $1 }
```

(`flap_operand` = `FLAP_BRACKET point_operand_list RBRACKET` = `#[ .a .b ]`, already defined ~:186.)

- [ ] **Step 6: Fix the `Mark` match arm arity so it builds**

`lib/eval.ml:1148` currently matches `Ast.Mark (name_opt, m, span)`. Temporarily widen it to the new arity so the project builds (Task 4 rewrites the body):

```ocaml
    | Ast.Mark (name_opt, m, _ext, _dir, _lay, span) -> (
        match resolve_markable span name_opt None m with
        (* ... existing body unchanged ... *)
```

- [ ] **Step 7: Run build + test**

Run: `dune build 2>&1 | head -20 && dune test 2>&1 | tail -20`
Expected: build clean (no menhir shift/reduce conflicts reported as errors); parse test PASS.
If menhir reports a conflict on `layer_opt`/`extent_opt`, note it and reorder — but `BETWEEN`/`AT`/`MOUNTAIN`/`FLAP_BRACKET` are distinct leading tokens, so none is expected.

- [ ] **Step 8: Commit**

```bash
git add lib/lexer.ml lib/ast.ml lib/parser.mly lib/eval.ml tests/
git commit -m "feat(notation): mark extent (between/at), direction, and #[..] layer syntax"
```

---

## Task 3: Extent classifier — boundary-to-boundary vs dangling vs crosses-fold

**Files:**
- Modify: `lib/fold_state.ml` (new `classify_mark_extent` near `subdivide` ~:597)
- Test: `tests/test_fold_state.ml`

**Interfaces:**
- Consumes: `Geom.clip_line_to_convex`, `Geom.in_convex_polygon`, `Geom.point_equal`, `Geom.side_of_line`, `edge_between` (~:257), `coplanar_clusters` (~:382).
- Produces:
```ocaml
type mark_class =
  | CSubdivide of Geom.point * Geom.point   (* boundary-to-boundary: caller subdivides clipped to [a,b] *)
  | CRecord of mark_geom                     (* wholly mid-face: caller records, no subdivide *)
  | CMixed of Geom.point * Geom.point * mark_geom (* boundary part [a,x] subdivides; stub (x,b) records *)
  | CCrossesFold of Geom.point * Geom.point  (* extent leaves its flap across an M/V edge → caller errors *)

val classify_mark_extent :
  t -> flap:int list -> axis:Geom.line -> extent_geom:mark_geom -> mark_class
```
where the caller passes `extent_geom` already reduced to paper space: `MSeg (a,b)` for `between`, `MPoint p` for `at`. (Full extent is handled by the caller as plain `subdivide`, never reaching here.)

**Algorithm (implement exactly):**
1. `flap` is the coplanar cluster (list of face indices) the extent lives on.
2. For `MPoint p`: if `p` lies strictly inside some `flap` face's paper polygon (`in_convex_polygon`, and not equal to a polygon vertex) → `CRecord (MPoint p)`. If `p` equals an existing face vertex → still `CRecord (MPoint p)` (a point never subdivides). It cannot cross a fold (a point has no span).
3. For `MSeg (a,b)`:
   a. Collect, for each face `fi` in `flap`, the clip of the **axis** line to that face's paper polygon (`clip_line_to_convex axis st.faces.(fi).paper`), intersected with the segment `[a,b]`. Keep only sub-segments of positive length. Each carries its owning `fi`.
   b. Walk the sub-segments in order from `a` to `b`. At each internal boundary crossing between two flap faces `fi|fj`, look up `edge_between st fi pa pb` for the shared endpoint: if that edge's `eassign` is `M` or `V` → the extent leaves the flap → return `CCrossesFold (a, b)`. (Within a flap all internal edges are `F`; an `M`/`V` here means the geometry demands leaving it.)
   c. Determine whether each endpoint is **on a boundary** (lies on the flap's outer boundary or the paper edge: `a`/`b` equals a polygon vertex or lies on an edge that has no flap-interior face on the far side) or **mid-face** (strictly interior to a flap face). Use `in_convex_polygon` for interior and vertex/edge incidence for boundary.
   d. Cases:
      - both endpoints on boundary → `CSubdivide (a, b)`.
      - both endpoints mid-face in the **same** face → `CRecord (MSeg (a, b))`.
      - `a` on boundary, `b` mid-face → let `x` = the last boundary crossing before `b` → `CMixed (a, x, MSeg (x, b))`. Symmetric for `b` on boundary, `a` mid-face (return `CMixed (b, x, MSeg (x, a))`).

- [ ] **Step 1: Write failing tests**

Add to `tests/test_fold_state.ml` (reusing `pt a b c d` from Task 1; `let flap0 = [ 0 ]`). Single flap `[0]` before any fold:

```ocaml
let test_classify_interior_segment_records () =
  let a = pt 1 4 1 4 and b = pt 1 2 1 2 in
  let axis = Geom.line_through a b in
  (match Fold_state.classify_mark_extent Fold_state.init_square ~flap:flap0 ~axis
           ~extent_geom:(Fold_state.MSeg (a,b)) with
   | Fold_state.CRecord (Fold_state.MSeg _) -> ()
   | _ -> Alcotest.fail "interior segment should record")

let test_classify_boundary_to_boundary_subdivides () =
  let a = pt 0 1 1 2 and b = pt 1 1 1 2 in  (* left edge (0,1/2) to right edge (1,1/2) *)
  let axis = Geom.line_through a b in
  (match Fold_state.classify_mark_extent Fold_state.init_square ~flap:flap0 ~axis
           ~extent_geom:(Fold_state.MSeg (a,b)) with
   | Fold_state.CSubdivide _ -> ()
   | _ -> Alcotest.fail "chord should subdivide")

let test_classify_point_records () =
  let p = pt 1 3 1 3 in
  let axis = Geom.line_through p (pt 2 3 1 3) in
  (match Fold_state.classify_mark_extent Fold_state.init_square ~flap:flap0 ~axis
           ~extent_geom:(Fold_state.MPoint p) with
   | Fold_state.CRecord (Fold_state.MPoint _) -> ()
   | _ -> Alcotest.fail "point should record")
```

Now the two multi-face cases, built directly in OCaml (exact rationals, full control):

```ocaml
let test_classify_crosses_fold () =
  (* fold at x=1/2 -> 2 faces in DIFFERENT coplanar clusters, joined by a V edge.
     A horizontal extent (1/4,1/2)->(3/4,1/2) leaves the left flap across it. *)
  let axis = { Geom.a = Num.one; b = Num.zero; c = qf 1 2 } in
  let st = Fold_state.fold_with_records Fold_state.init_square ~axis ~move_side:1
             ~valley:true ~prov:None in
  let left = Option.get (Fold_state.mark_face st
              { Fold_state.mgeom = Fold_state.MPoint (pt 1 4 1 4);
                mline = axis; mintent = Fold_state.V; mcrease_id = 0 }) in
  let a = pt 1 4 1 2 and b = pt 3 4 1 2 in
  (match Fold_state.classify_mark_extent st ~flap:[ left ]
           ~axis:(Geom.line_through a b) ~extent_geom:(Fold_state.MSeg (a,b)) with
   | Fold_state.CCrossesFold _ -> ()
   | _ -> Alcotest.fail "extent across a folded crease must be CCrossesFold")

let test_classify_mixed () =
  (* subdivide along y=1/2 (an F edge; the halves stay ONE coplanar cluster).
     Vertical extent (1/2,1) [top boundary] -> (1/2,1/4) [interior of lower half]
     subdivides the upper part and records the dangling stub. *)
  let mid = Geom.line_through (pt 0 1 1 2) (pt 1 1 1 2) in
  let st = Fold_state.subdivide Fold_state.init_square mid ~prov:None in
  let flap = List.init (Array.length st.Fold_state.faces) Fun.id in (* one F-joined cluster *)
  let a = pt 1 2 1 1 and b = pt 1 2 1 4 in
  (match Fold_state.classify_mark_extent st ~flap
           ~axis:(Geom.line_through a b) ~extent_geom:(Fold_state.MSeg (a,b)) with
   | Fold_state.CMixed (_, _, Fold_state.MSeg _) -> ()
   | _ -> Alcotest.fail "boundary->interior across an F edge must be CMixed")
```

Register all five in the test suite list. (`pt a b c d = { Geom.x = qf a b; y = qf c d }`, `flap0 = [0]`.)

- [ ] **Step 2: Run to verify failure**

Run: `dune test 2>&1 | head -20`
Expected: FAIL — `classify_mark_extent` unbound.

- [ ] **Step 3: Implement `classify_mark_extent`**

Add `type mark_class` (above `subdivide`, ~:596) and the function per the Algorithm. Reuse the private helpers already in `fold_state.ml` (`axis_segment_in_face`, `clip_convex_halfplane`) where useful. Keep it total and exact (no floats). For the boundary-vs-interior endpoint test, a point is *on the flap boundary* iff it is not strictly interior to any flap face (i.e. it lies on some face edge or vertex, or on the paper border); *mid-face* iff `in_convex_polygon face.paper p` holds for exactly one flap face and `p` is not on that polygon's border.

- [ ] **Step 4: Run to verify pass**

Run: `dune test 2>&1 | tail -20`
Expected: the three classify tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/fold_state.ml tests/test_fold_state.ml
git commit -m "feat(fold_state): classify_mark_extent (subdivide/record/mixed/crosses-fold)"
```

---

## Task 4: Eval `mark` arm — extent + flap resolution, dispatch to classifier

**Files:**
- Modify: `lib/eval.ml` (`Ast.Mark` arm ~:1148; add extent/flap resolution helpers near `resolve_flap_cluster` ~:501)
- Test: `tests/test_e2e.ml` (or `tests/test_eval.ml` — whichever runs `.bel` end-to-end; grep `rg -n "eval_folded|to_json_folded" tests/`)

**Interfaces:**
- Consumes: `resolve_markable` (~:1095), `resolve_point`/`resolve_line` (~:276), `faces_containing` (~:488), `Fold_state.flap_of_points` (~:416), `Fold_state.coplanar_clusters` (~:382), `Fold_state.classify_mark_extent` (Task 3), `Fold_state.add_mark`, `Fold_state.subdivide`.
- Produces: rewritten `Ast.Mark` arm handling `extent`, `direction`, `layer_opt`, and the combined bind-and-write.

**Behaviour (implement exactly):**
1. Resolve the motion to `axis` via `resolve_markable` (`` `Fresh ``) or `resolve_line` (`` `Existing ``), exactly as the current arm does, obtaining `cid`, `prov`, `axis`.
2. **Extent geometry** (paper space):
   - `Full` → keep the current behaviour: `subdivide` along `axis`, bind `Material` if named. Done. (Full always spans boundary-to-boundary; never records.)
   - `Between (a, b)` → `pa = resolve_point a`, `pb = resolve_point b`; require both on `axis`: `if Geom.side_of_line axis pa <> 0 then Error.fail span "%s is not on the mark's line" (pstr a)` (same for `pb`); `extent_geom = MSeg (pa, pb)`.
   - `At p` → `pp = resolve_point p`; require on `axis` (same check); `extent_geom = MPoint pp`.
3. **Flap resolution** (only for partial extents):
   - if `layer_opt = Some (FByPoints (pts,_))` → `flap = ` (per `flap_of_points`, error on `` `Zero ``/`` `Ambiguous `` like `resolve_flap_cluster`).
   - else default = the **carrying flap**: take the extent's representative paper point (`pa`/`pp`), `faces_containing` it → map to coplanar clusters via `coplanar_clusters`; if exactly one cluster → its face list; if the point sits on a boundary shared by several clusters → `Error.fail span "the mark's endpoint lies on a crease shared by several flaps; name the flap with #[..]"`.
4. **Dispatch** `classify_mark_extent st ~flap ~axis ~extent_geom`:
   - `CSubdivide (a,b)` → `subdivide` along `axis` (clipped to `[a,b]`; if `subdivide` has no clip argument, subdivide along the full `axis` — the chord equals the extent here), `~crease_id:cid ~prov`, `~intent:direction` (Task 6). Bind `Material` if named.
   - `CRecord g` → `ctx.state := Fold_state.add_mark !(ctx.state) { mgeom = g; mline = axis; mintent = intent_of direction; mcrease_id = cid }`. Bind `Material` if named (a named record still lets `fold --d` fail cleanly later — a partial mark isn't foldable this slice; that path already errors on non-material lines).
   - `CMixed (a, x, g)` → `subdivide` the `[a,x]` part **and** `add_mark` the stub `g`.
   - `CCrossesFold (a, b)` → `Error.fail span "the mark's extent from %s to %s crosses a folded crease (it leaves its flap)" (pstr ...) (...)`.
5. Combined bind-and-write (`name_opt = Some n`) works uniformly: after materialising (subdivide) bind `Material (cid, axis)`; for a pure record, still bind `Material` so the name resolves. The `` `Existing `` promotion path (Frozen→Material) is unchanged from today for the `Full` case.

- [ ] **Step 1: Write failing e2e tests**

Add to the e2e test file. Use the existing helper that evals a `.bel` string (grep `rg -n "fold_string|eval_str|Beloch\." tests/test_e2e.ml` — the golden test uses `Beloch.fold_string ~filename src`; use the same, or a thin `eval_bel` returning `Eval.folded`). Assertions key off **edge count** (a record adds no edge). All geometry uses the real corpus idiom — prelude corners `.a`(0,0) `.b`(1,0) `.c`(1,1) `.d`(0,1), prelude edges `--ab --bc --cd --da`, meets via `*`, `map .a onto .b` for the vertical midline `x=1/2` and `map .a onto .d` for the horizontal midline `y=1/2` (no raw coordinate literals exist in the grammar):

```ocaml
(* Beloch.fold_string returns JSON; for state assertions go one step earlier:
   parse -> Eval.eval_folded gives the Eval.folded record with .state. *)
let eval_bel src = Eval.eval_folded (Beloch.parse ~filename:"t.bel" src)
let edges_of src = Array.length (eval_bel src).Eval.state.Fold_state.edges

(* an interior POINT mark records and adds no edge. Value-bind (no `mark`) the
   two midlines so they don't subdivide; their meet is the centre (1/2,1/2). *)
let interior_centre =
  "paper square\n\
   --vm = map .a onto .b\n\      (* value: vertical midline x=1/2, no subdivide *)
   --hm = map .a onto .d\n\      (* value: horizontal midline y=1/2 *)
   .ctr = --vm * --hm\n"         (* centre (1/2,1/2), interior *)

let test_point_mark_records_no_edge () =
  let src = interior_centre ^ "mark --r at .ctr\n" in
  Alcotest.(check int) "point mark adds no edge" 0 (edges_of src);
  Alcotest.(check int) "one mark recorded" 1
    (Array.length (eval_bel src).Eval.state.Fold_state.marks)

let test_full_mark_still_subdivides () =
  (* full chord map .a onto .b hits top+bottom edges: boundary-to-boundary *)
  let src = "paper square\nmark map .a onto .b\n" in
  Alcotest.(check int) "full mark subdivides (one edge)" 1 (edges_of src);
  Alcotest.(check int) "no record" 0
    (Array.length (eval_bel src).Eval.state.Fold_state.marks)

let test_mark_crosses_fold_errors () =
  (* fold left half onto right at x=1/2 (V edge). A value horizontal midline's
     extent between .a and .b spans x=1/2 -> leaves the flap across the fold. *)
  let src =
    "paper square\n\
     fold map .a onto .b moving .a\n\    (* valley fold, crease x=1/2 *)
     --hm = map .a onto .d\n\
     mark --hm between .a .b\n"          (* horizontal extent .a(0,0)->.b(1,0) crosses x=1/2 *)
  in
  Alcotest.check_raises "crosses folded crease"
    (Error.Beloch ("", "")) (fun () -> ignore (eval_bel src))
```

Match `Error.Beloch`'s real constructor shape (grep `rg -n "exception Beloch" lib/error.ml`); use `check_raises` with the right pattern or a `try/with` that asserts the message contains "crosses a folded crease". If `.a`/`.b` are moved by the fold so the extent no longer spans x=1/2 as written, substitute the two still-flat corners on the stationary side — the invariant to preserve is: a value line whose `between` extent provably crosses the V crease.

- [ ] **Step 2: Run to verify failure**

Run: `dune test 2>&1 | head -30`
Expected: FAIL — records not created / edges still added, or arm not yet rewritten.

- [ ] **Step 3: Rewrite the `Ast.Mark` arm**

Implement Behaviour 1-5 in `lib/eval.ml`, replacing the temporary widened arm from Task 2 Step 6. Factor extent+flap resolution into two `let` helpers above `eval_stmt` for readability. Keep the `` `Existing `` `Full` promotion path intact.

- [ ] **Step 4: Run to verify pass**

Run: `dune test 2>&1 | tail -30`
Expected: the new e2e tests PASS; the pre-existing suite stays green (full `mark` still subdivides).

- [ ] **Step 5: Commit**

```bash
git add lib/eval.ml tests/
git commit -m "feat(eval): mark extent dispatch — record mid-face, subdivide chords, error on fold-crossing"
```

---

## Task 5: Exact-incidence snapping

**Files:**
- Modify: `lib/eval.ml` (record-creation path in the `Ast.Mark` arm) OR `lib/fold_state.ml` `add_mark`
- Test: `tests/test_e2e.ml`

**Interface:**
- A record mark endpoint that is `Geom.point_equal` to an existing face vertex is kept as that exact vertex (no perturbation, no new coordinate). This is a no-op numerically (they are already equal) but pins the *incidence* so downstream `mark_face`/emission attach to the shared vertex rather than treating it as free. No tolerance, no float.

Because coordinates are exact rationals, "snapping" here is only a lookup: when building a `CRecord`/`CMixed` geom, if an endpoint equals an existing vertex, reuse that vertex value verbatim. In practice `resolve_point` already yields the canonical rational, so this task is a **guard + test** confirming the exact-equality behaviour and explicitly *not* introducing tolerance.

- [ ] **Step 1: Write the failing test**

```ocaml
let test_mark_endpoint_on_vertex_is_incident () =
  (* two full diagonals subdivide and create the centre (1/2,1/2) as a real
     vertex; a point mark at that centre shares the vertex, not a duplicate. *)
  let src =
    "paper square\n\
     mark map .a onto .c\n\    (* diagonal a-c full chord: subdivides *)
     mark map .b onto .d\n\    (* diagonal b-d: centre (1/2,1/2) becomes a vertex *)
     --ac = through .a .c\n\
     --bd = through .b .d\n\
     .ctr = --ac * --bd\n\     (* centre (1/2,1/2) *)
     mark --r at .ctr\n"
  in
  let st = (eval_bel src).Eval.state in
  let m = st.Fold_state.marks.(0) in
  let p = Fold_state.mark_rep_point m in
  let is_vertex =
    Array.exists (fun (f : Fold_state.face) ->
      Array.exists (Geom.point_equal p) f.Fold_state.paper) st.Fold_state.faces
  in
  Alcotest.(check bool) "point mark is incident to an existing vertex" true is_vertex
```

(`map .a onto .c` is axiom 2 — the perpendicular bisector of the a–c diagonal, which is the *other* diagonal b–d, not a–c. To score the actual diagonals use `through`: `mark --ac = through .a .c` then `mark --bd = through .b .d`. Adjust so the two scored full chords genuinely cross at the centre and create it as a vertex; the assertion only needs *some* existing vertex equal to the mark point.)

- [ ] **Step 2: Run to verify failure/pass**

Run: `dune test 2>&1 | head -20`
If it already passes (because `resolve_point` yields the canonical rational and equality holds), that confirms exact-incidence holds for free — keep the test as a regression guard and skip Step 3. If it fails (endpoint differs), implement Step 3.

- [ ] **Step 3: Add the incidence guard (only if needed)**

In the `CRecord`/`CMixed` construction, normalise each endpoint: if it equals an existing vertex, use the stored vertex value.

```ocaml
let snap_to_vertex st p =
  let hit = ref p in
  Array.iter (fun (f : Fold_state.face) ->
    Array.iter (fun v -> if Geom.point_equal v p then hit := v) f.Fold_state.paper)
    st.Fold_state.faces;
  !hit
```

Apply to record endpoints only. No tolerance — `point_equal` is exact.

- [ ] **Step 4: Run to verify pass; Step 5: Commit**

Run: `dune test 2>&1 | tail -20` → PASS.
```bash
git add lib/eval.ml tests/
git commit -m "feat(eval): exact-incidence snapping for mark endpoints (no tolerance)"
```

---

## Task 6: Direction / CP-frame intent (`eintent`)

**Files:**
- Modify: `lib/fold_state.ml` (`edge` type ~:17; `subdivide` edge build ~:645; `fold_with_records` edge builds ~:769,826)
- Modify: `lib/fold_emit.ml` (CP frame uses `eintent`, folded frames use `eassign`)
- Test: `tests/test_e2e.ml` (assert CP-frame vs folded-frame assignment)

**Interfaces:**
- Produces: field `eintent : assign` on `edge` = the crease-pattern colour. For a real fold `eintent = eassign` (M/V). For a flat `mark` `eassign = F` and `eintent = ` the mark's `M`/`V` (default `V`).
- `subdivide` gains `~intent:assign` (default `V`); it sets `eassign = F; eintent = intent`.

- [ ] **Step 1: Write the failing test**

```ocaml
let test_mark_mountain_cp_intent () =
  (* map .a onto .d = horizontal midline y=1/2, full chord (boundary-to-boundary
     -> subdivides), marked mountain *)
  let src = "paper square\nmark map .a onto .d mountain\n" in
  let json = Fold_emit.to_json_folded (eval_bel src) in
  (* top-level (creasePattern) edges_assignment contains "M" for the mark, and
     the foldedForm frame contains "F". *)
  Alcotest.(check bool) "CP frame colours the mark M"
    true (json_cp_assignments json |> List.mem "M");
  Alcotest.(check bool) "folded frame keeps the mark F"
    true (json_folded_assignments json |> List.mem "F")
```

Add the two small JSON-extraction helpers (`json_cp_assignments`, `json_folded_assignments`) that read `edges_assignment` from the top-level object and from `file_frames[0]` respectively (use `Yojson.Safe.Util`).

- [ ] **Step 2: Run to verify failure**

Run: `dune test 2>&1 | head -20`
Expected: FAIL — CP frame currently emits `F` for the mark (no intent), or `eintent` unbound.

- [ ] **Step 3: Add `eintent` and thread it**

`edge` type (~:17-25): add `eintent : assign;` after `eassign`.

`subdivide` (~:597): add labelled arg `?(intent = V)`; in the edge record (~:645) change to:
```ocaml
{ ea = a; eb = b; left; right; eassign = F; eintent = intent; crease_id = cid; eprov = prov }
```

`fold_with_records` edge builds (~:769, ~:826): set `eintent = ea_assign` / `eintent = assign_of_parent mf` (mirror whatever `eassign` is set to there — a fold's CP colour equals its fold colour).

`flip` (~:913-923) rebuilds edges by flipping assignment: flip `eintent` the same way it flips `eassign` (mountain↔valley), so an unfolded intent tracks a flip. Match the existing M↔V swap logic for `eassign`.

- [ ] **Step 4: Emit from the right frame**

`lib/fold_emit.ml`:
- `to_json_folded` (CP frame, ~:190-199): read `e.Fold_state.eintent` instead of `e.Fold_state.eassign` for the assignment string.
- `folded_frame_of_state` (~:62-71): keep reading `e.Fold_state.eassign` (folded dihedral: `F` for a flat mark).

- [ ] **Step 5: Thread `~intent` from the eval `mark` subdivide calls**

In `lib/eval.ml`, pass `~intent:(match direction with Ast.Valley -> Fold_state.V | Ast.Mountain -> Fold_state.M)` to the `subdivide` calls in the `CSubdivide`/`CMixed`/`Full` mark paths. Fold paths are unchanged (their subdivide already precedes an M/V fold).

- [ ] **Step 6: Run to verify pass; Step 7: Commit**

Run: `dune build && dune test 2>&1 | tail -20` → PASS. Fix any `{ ea = ...; eassign = ...}` literal the compiler flags for the missing `eintent`.
```bash
git add lib/fold_state.ml lib/fold_emit.ml lib/eval.ml tests/
git commit -m "feat(fold): eintent — CP-frame M/V intent distinct from folded F"
```

---

## Task 7: FOLD emission — `beloch:marks`

**Files:**
- Modify: `lib/fold_emit.ml` (`to_json_folded` top-level `Assoc`, ~:263-281)
- Test: `tests/test_e2e.ml`

**Interface:**
- Produces a `beloch:marks` key on the crease-pattern object: a JSON list, one entry per record mark:
```json
{ "kind": "seg", "a": [x,y], "b": [x,y], "line": [a,b,c], "intent": "M"|"V", "crease_id": n }
{ "kind": "point", "p": [x,y], "line": [a,b,c], "intent": "M"|"V", "crease_id": n }
```
Coordinates via `q_to_json` (exact rational → float only at the JSON boundary, as the rest of the file does).

- [ ] **Step 1: Write the failing test**

```ocaml
let test_beloch_marks_emitted () =
  let src =
    "paper square\n\
     --vm = map .a onto .b\n--hm = map .a onto .d\n.ctr = --vm * --hm\n\
     mark --r at .ctr\n"       (* interior centre point mark -> one record *)
  in
  let json = Fold_emit.to_json_folded (eval_bel src) in
  let marks = Yojson.Safe.Util.member "beloch:marks" json in
  match marks with
  | `List [ one ] ->
      Alcotest.(check string) "point kind" "point"
        (Yojson.Safe.Util.(member "kind" one |> to_string));
      Alcotest.(check string) "valley default" "V"
        (Yojson.Safe.Util.(member "intent" one |> to_string))
  | _ -> Alcotest.fail "expected exactly one point mark"
```

- [ ] **Step 2: Run to verify failure**

Run: `dune test 2>&1 | head -20`
Expected: FAIL — `beloch:marks` is `` `Null ``.

- [ ] **Step 3: Emit the field**

In `to_json_folded`, before the final `` `Assoc `` (~:263), build:

```ocaml
let assign_str = function Fold_state.M -> "M" | Fold_state.V -> "V" | Fold_state.F -> "F" in
let beloch_marks =
  Array.to_list fd.Eval.state.Fold_state.marks
  |> List.map (fun (m : Fold_state.mark) ->
      let line = let l = m.Fold_state.mline in
        `List [ q_to_json l.Geom.a; q_to_json l.Geom.b; q_to_json l.Geom.c ] in
      let common = [ ("line", line);
                     ("intent", `String (assign_str m.Fold_state.mintent));
                     ("crease_id", `Int m.Fold_state.mcrease_id) ] in
      match m.Fold_state.mgeom with
      | Fold_state.MSeg (a, b) ->
          `Assoc ((("kind", `String "seg")
                   :: ("a", `List [ q_to_json a.Geom.x; q_to_json a.Geom.y ])
                   :: ("b", `List [ q_to_json b.Geom.x; q_to_json b.Geom.y ])
                   :: common))
      | Fold_state.MPoint p ->
          `Assoc ((("kind", `String "point")
                   :: ("p", `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ])
                   :: common)))
in
```

and add `("beloch:marks", `List beloch_marks);` to the top-level `` `Assoc `` list.

- [ ] **Step 4: Run to verify pass; Step 5: Commit**

Run: `dune test 2>&1 | tail -20` → PASS.
```bash
git add lib/fold_emit.ml tests/
git commit -m "feat(fold_emit): beloch:marks custom field for record marks"
```

---

## Task 8: Render `beloch:marks` in fold2svg

**Files:**
- Modify: `render/render-svg/bin/fold2svg.ts` (crease-pattern draw path)
- Test: whatever the renderer uses (grep `rg -n "test|expect" render/render-svg` ; if none, a smoke assertion that the SVG string contains the mark elements)

**Interface:**
- Reads `beloch:marks` from the FOLD JSON. For `kind: "seg"` draws a thin line `a→b` (distinct stroke, e.g. dashed / lighter). For `kind: "point"` draws a short **tick** centred on `p`, oriented along `line` (`[a,b,c]` = `a·x + b·y + c = 0`; direction vector `(b, -a)` normalised), fixed display length (e.g. `0.03` of the sheet). Marks render in paper space in the crease-pattern view.

- [ ] **Step 1: Read the renderer's FOLD-ingest + draw section**

Run: `rg -n "edges_vertices|edges_assignment|beloch:|creasePattern|<line|<path" render/render-svg/bin/fold2svg.ts`
Identify where CP edges are drawn; add the mark pass beside it.

- [ ] **Step 2: Write a failing render assertion**

If a test harness exists, assert the SVG for `mark --r at (1/3,1/3)` contains a tick element with the mark's class. If none exists, add a minimal script test under `render/render-svg` that runs the CLI on a fixture `.fold` (emit one with the OCaml pipeline first) and greps the SVG for `class="mark"`.

- [ ] **Step 3: Implement the mark pass**

Parse `json["beloch:marks"] ?? []`. For each:
```ts
for (const m of marks) {
  if (m.kind === "seg") {
    line(m.a, m.b, { className: "mark", dash: true });
  } else { // point tick
    const [A, B] = m.line; // a x + b y + c = 0 ; direction (B, -A)
    const dir = normalize([B, -A]);
    const L = 0.03;
    const p = m.p;
    line([p[0] - dir[0]*L, p[1] - dir[1]*L],
         [p[0] + dir[0]*L, p[1] + dir[1]*L], { className: "mark-tick" });
  }
}
```
Match the file's existing coordinate transform (paper→SVG) and drawing helpers; do not invent a new one.

- [ ] **Step 4: Verify visually**

Run the renderer on `examples/syntax/cube-root.bel`'s FOLD output after Task 9's rewrite; confirm reference marks appear as ticks/thin lines, not full chords. Command (adapt to the repo's render entrypoint): `dune exec bin/beloch -- examples/syntax/cube-root.bel --fold | node render/render-svg/bin/fold2svg.ts > /tmp/cube-root.svg` then open it.

- [ ] **Step 5: Commit**

```bash
git add render/render-svg/bin/fold2svg.ts render/render-svg
git commit -m "feat(render): draw beloch:marks (seg lines + point ticks) in CP view"
```

---

## Task 9: Acceptance — clean cube-root's CP with partial marks

**Files:**
- Modify: `examples/syntax/cube-root.bel` (the `TODO(pinch)` scaffolds)
- Modify: golden `tests/golden/syntax/cube-root.fold` (regen)
- Also rewrite any interim-`through` scaffolds flagged in `[[beloch-sightline-to-pinch-interim]]` that are pure locators
- Test: `tests/test_golden.ml`

**Reality check (verified during planning):** `examples/iteration/*.bel` **do not exist** — `tests/golden/iteration/00{3,4}.fold` are stale orphan error-goldens (`ERROR: no common interior vertex`) left by a past cutover; the golden harness only checks `.bel` files present under `examples/`, so those goldens are dead and untested. The concrete, live acceptance target is **`cube-root.bel`**, which already carries explicit `TODO(pinch)` markers on the scaffolds to convert. (The orphan iteration goldens are handled in Step 5, and whether to author fresh iteration examples is deferred — see Step 6.)

**The cube-root scaffolds** (`examples/syntax/cube-root.bel`): `--ac --db --d_mb --a_mt --c_mb --b_mt` are marked full chords used ONLY to locate the meet points `._pq1 ._pq2 ._rs1 ._rs2`. Because a mark's meet operand uses its underlying *line* (`mline`), the meets still resolve if these become either value bindings (no `mark`) or partial marks. `--pq`/`--rs` are the actual third-lines; `.s = --rs * --cd` needs `--rs` to reach the top edge.

- [ ] **Step 1: Capture the current folded landing (the invariant)**

Run the current file and save the folded frame — the ∛2 landing must not change:
```bash
dune exec bin/beloch -- examples/syntax/cube-root.bel --fold > /tmp/cube-root.before.fold
```
(adapt the binary/flag to the repo's entrypoint — grep `bin/dune` for the exe name.)

- [ ] **Step 2: Convert pure point-locators to value bindings**

The six diagonal/landmark scaffolds only feed meets. Drop `mark ` so they score nothing (Slice-1 `BindLine`): e.g. `mark --ac = through .a .c` → `--ac = through .a .c`. Do this for `--ac --db --d_mb --a_mt --c_mb --b_mt`. The meet lines (`._pq1 = --d_mb * --ac`, …) are unchanged and still resolve (value lines meet fine).

- [ ] **Step 3: Score the thirds as partial marks**

`--pq` and `--rs` represent the physical third-creases. Keep them scored, but as partial marks between the exact points they connect:
```
mark --pq between ._pq1 ._pq2      ; left third, x=1/3, between its two computed points
mark --rs between ._rs1 ._rs2      ; right third, x=2/3
```
If `.s = --rs * --cd` then needs `--rs` to reach `y=1` (beyond `._rs2`), keep `--rs` as a value binding for the meet and add a separate partial `mark --rs between ._rs1 .s` for the physical crease — or bind `.s` from a value line. Choose whichever keeps `.s` resolving; verify in Step 4. Remove the stale `TODO(pinch)` comments you resolve; update the header NOTE paragraph (lines 12-15) to say the landmarks are now pinch/value scaffolds.

- [ ] **Step 4: Verify the landing is unchanged**

```bash
dune exec bin/beloch -- examples/syntax/cube-root.bel --fold > /tmp/cube-root.after.fold
```
Compare the `foldedForm` frame's landing point between before/after (the ∛2 position on AB). The folded coordinates must be identical; only the crease-pattern frame changes (fewer full-chord diagonals, new `beloch:marks`). If the landing moved, a scaffold was mis-converted — revert that one to a value binding.

- [ ] **Step 5: Remove the dead orphan goldens**

`tests/golden/iteration/00{1,2,3,4,5}.fold` have no sources under `examples/`. Confirm no `.bel` references them:
```bash
fd -e bel . examples | xargs -r grep -l iteration ; ls examples/iteration 2>/dev/null || echo "no examples/iteration"
```
If confirmed dead, `git rm tests/golden/iteration/*.fold` (they are untested clutter that misrepresents state). If any turn out live, leave them.

- [ ] **Step 6: (Deferred decision — do NOT author blind) fresh iteration examples**

The handoff wanted `iteration/003,004` to demonstrate partial marks fixing a `collapse` ray-split. Their exact construction is lost with the sources. **Do not fabricate them.** Leave a one-line note in the PR/commit that authoring fresh `examples/iteration/*` collapse-with-partial-marks demos is a follow-up to raise with Toph — the cube-root acceptance already proves the ray-non-splitting behaviour end-to-end.

- [ ] **Step 7: Regenerate goldens + run the suite**

Run: `./scripts/snapshot-fold.sh` then `dune test 2>&1 | tail -20`
Expected: all green. The `cube-root.fold` golden diff shows: CP loses the six full-chord landmark diagonals, `--pq`/`--rs` become short marks, `beloch:marks` present; the folded frame's landing is byte-identical to before.

- [ ] **Step 8: Commit**

```bash
git add examples/syntax/cube-root.bel tests/golden
git commit -m "feat(examples): cube-root landmarks -> value/partial marks; drop dead iteration goldens"
```

---

## Task 10: Docs, spec sync, memory

**Files:**
- Modify: `spec/SPECIFICATION.md` (§4 mark surface — add extent/direction/layer)
- Modify: `docs/superpowers/specs/2026-07-10-mark-fold-slice2-design.md` (mark Status → shipped) — optional
- Memory: update `[[beloch-mark-fold-notation-design]]` (Slice 2 shipped), `[[beloch-sightline-to-pinch-interim]]` (interim `through` list resolved)

- [ ] **Step 1: Update the specification**

In `spec/SPECIFICATION.md` §4, document `mark <motion> [between .a .b | at .p] [mountain|valley] [#[..]]`, the record-vs-subdivide rule (boundary-incidence), the crosses-fold error, and the `beloch:marks` emission. Match the section's existing prose style.

- [ ] **Step 2: Update memory**

Append to `[[beloch-mark-fold-notation-design]]`: "Slice 2 SHIPPED — partial marks (between/at) record mid-face, subdivide boundary-to-boundary; beloch:marks field; eintent CP colour; iteration/003,004 fixed." Update `[[beloch-sightline-to-pinch-interim]]`: interim `through` scaffolds rewritten to partial marks (done).

- [ ] **Step 3: Commit**

```bash
git add spec/SPECIFICATION.md
git commit -m "docs(spec): document mark extent/direction/layer and beloch:marks"
```

---

## Self-Review notes (for the executor)

- **Spec coverage:** partial marks/records (T1,T3,T4) · extent syntax between/at (T2) · exact-incidence snapping, fuzzy deferred (T5) · mark direction → CP intent (T6) · layer `#[..]` + default carrying flap (T4) · combined bind-and-write (T2,T4) · `beloch:marks` emission (T7) + render (T8) · acceptance cube-root CP cleanup (T9) · spec/memory (T10). All spec §1 deliverables mapped. (Acceptance note: the handoff's `iteration/003,004` are dead orphan goldens — sources removed in a past cutover; cube-root is the live end-to-end target, T9 Step 6 defers authoring fresh iteration demos to Toph.)
- **Deferred (must NOT appear):** fuzzy/tolerance snapping, `fold` moving-inference, set-valued `#[.c .d]`, partial `fold`, history→CP intent. If a task tempts you toward these, stop — they are out of scope (spec §8).
- **Type consistency:** `mark`/`mark_geom`/`mark_class` and `classify_mark_extent`'s constructors (`CSubdivide`/`CRecord`/`CMixed`/`CCrossesFold`) are used verbatim across T1→T7. `eintent` (T6) is read by emit in T7-adjacent code. `subdivide`'s new `?intent` is optional so pre-existing callers are unaffected.
- **Corpus idiom (no raw coordinates):** the grammar has NO coordinate literals — points come from prelude corners `.a`(0,0)/`.b`(1,0)/`.c`(1,1)/`.d`(0,1), prelude edges `--ab --bc --cd --da`, and meets (`--x * --y`). All test `.bel` in this plan already use that idiom; `map .a onto .b` = vertical midline x=1/2, `map .a onto .d` = horizontal midline y=1/2. Before running, confirm the eval-helper spelling (`Beloch.eval_folded`/`fold_string`) against `tests/test_e2e.ml` and `tests/test_golden.ml`.
