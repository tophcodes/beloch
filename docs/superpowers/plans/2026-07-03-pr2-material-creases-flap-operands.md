# PR 2 — Material Creases & Flap Operands (#28 + areas) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make named creases *material* — a named crease `--d` resolves against its current edge-pieces (tracking through folds and `flip`), erroring when a later fold has bent it — and ship the escape-hatch syntax `#(.a .b .c)` / `--( --d #(.a .b .c) )` in the same PR.

**Architecture:** A named crease binds to `Material of (int * Geom.line)` — the operation's stable `crease_id` (introduced in PR1) plus its original axis line — instead of a frozen `Geom.line`. Resolution gathers the edges carrying that `crease_id`, maps them to table space via each edge's `left` face isometry, and: returns the stored line if the pieces still lie on it (the common, byte-stable case), recomputes the line if a rigid move/flip relocated them, or errors if they were bent apart. Two new operands (`#(...)` flap, `--( --d #(...) )` line-restricted-to-flap) give the escape hatch. `subdivide`/`fold_with_records` mint **one** `crease_id` per operation (via a new `?crease_id` param) so a named crease's pieces share an id.

**Tech Stack:** OCaml, dune, Menhir, sedlex, Alcotest, Zarith, Yojson. Exact-rational/real-algebraic `Num` kernel — **not touched**.

## Global Constraints

- **No `Num`/kernel surface.** Do not add to or modify `lib/num.ml`, `lib/poly.ml`, `lib/mpoly.ml`. Geometry goes only through `Geom`/`Isometry` (`side_of_line`, `in_convex_polygon`, `line_through`, `apply_point`, `equal`/`compare`/`sign`). Orthogonal to the FLINT migration — keep it that way.
- **Geometry output stays byte-stable.** Every existing `.bel` in `examples/` must emit a byte-identical *folded geometry* (`vertices_coords`, `edges_vertices`, `edges_assignment`, `edges_foldAngle`, `faces_vertices`, `beloch:edges`, `faceOrders`, `beloch:named_points`) — the sole exception is `multiple-folds.bel`, which legitimately now needs the escape hatch (Task 3) and is regenerated. The golden net (from PR1, `tests/test_golden.ml`) is the gate: **never hand-edit a golden to make it pass.** If a geometry array changes for any *other* example, that is a bug in resolution — fix the code.
- **`named_lines` emission stays frozen in this PR.** The `beloch:named_lines` JSON continues to emit each named crease's *original* line (`l_orig`). Making that emission material is deferred (out of scope, §8-analog below). This keeps the debug section byte-stable too.
- **Crease-name → pieces is via `crease_id`.** A named crease resolves against `state.edges` filtered by `crease_id`. Do not reintroduce a `Geom.line` side-list or geometric re-matching.
- Follow existing style: records with explicit field types, polymorphic-variant results for tri-state resolution, no new deps. Commit after each task (conventional commits).

**Reviewer's note on granularity:** Task 3 is the central semantic change (the `crease_val` ripple + material resolution + the one forced example rewrite). It is one cohesive unit guarded by the golden net; its body edits are localized against exact line refs and every step has a concrete gate. This mirrors PR1's Task-2/3 pattern and is deliberate, not a placeholder.

## File structure

- `lib/ast.ml` — add `LRestrict` line-operand variant + `flap_operand` type. (Syntax.)
- `lib/lexer.ml` — add the `#(` → `FLAP_OPEN` token. (Syntax.)
- `lib/parser.mly` — `FLAP_OPEN` token; `flap_operand` rule; `LRestrict` production. (Syntax.)
- `lib/fold_state.ml` — `?crease_id` param on `subdivide`/`fold_with_records`; add `crease_axis`, `flap_of_points`, `crease_piece_on_face`. (Entity accessors.)
- `lib/eval.ml` — `crease_val` type; `scope.lines`/`instance.ilines` carry it; material resolution in `resolve_line`; `Crease` binds `Material`; `named_lines` emits the stored line. (Semantics.)
- `examples/multiple-folds.bel` — rewrite to the escape hatch (its precrease `--b` is bent by the `--v` fold). Regenerate its golden.
- `examples/crease-bent-error.bel`, `examples/crease-flap-restrict.bel`, `examples/crease-flip-reuse.bel` — **new** showcase examples + goldens.
- `tests/test_parse.ml` — parse cases for the new operands.
- `tests/test_fold_state.ml` — unit tests for `crease_axis` (flat/moved/bent), `flap_of_points` (unique/zero/multi), flip tracking.
- `tests/test_e2e.ml` — end-to-end: bent→error, escape-hatch→resolves.

---

### Task 1: New operand syntax (AST + lexer + parser + parse tests)

Add the flap operand and the line-restricted-to-flap operand to the grammar and AST. **No semantics yet** — `eval` gets a temporary "not implemented" arm so the build stays green and every existing golden still passes (named creases still resolve frozen).

**Files:**
- Modify: `lib/ast.ml:24-27` (extend `line_operand`, add `flap_operand`)
- Modify: `lib/lexer.ml:37-38` (add `FLAP_OPEN`)
- Modify: `lib/parser.mly` (token decl line 6; `line_operand` rule ~line 118; new `flap_operand` rule)
- Modify: `lib/eval.ml:110-115` (`lstr` render) and `:137-157` (`resolve_line` temporary arm)
- Test: `tests/test_parse.ml`

**Interfaces:**
- Produces (add to `ast.ml`):
```ocaml
and line_operand =
  | LNamed of crease_ref
  | LThrough of point_operand * point_operand * Error.span
  | LMember of string * string * Error.span
  | LRestrict of crease_ref * flap_operand * Error.span  (* --( --d #(.a .b .c) ) *)

and flap_operand = FByPoints of point_operand list * Error.span  (* #(.a .b .c) *)
```
- Consumes: existing `point_operand`, `crease_ref`.

- [ ] **Step 1: Write the failing parse test**

Append to `tests/test_parse.ml` (register the two cases in its existing test list — match the file's `Alcotest.test_case` style):
```ocaml
let test_flap_restrict_parses () =
  let src =
    "paper square\n--d = through .a .c\nperp --( --d #(.a .c .b) ) through .b\n"
  in
  match Beloch.parse ~filename:"t.bel" src with
  | [ _;
      Ast.Crease
        ( None,
          Ast.Perp (_, Ast.LRestrict (cr, Ast.FByPoints (pts, _), _)),
          None,
          _ ) ] ->
      Alcotest.(check string) "restricted crease name" "d" cr.Ast.cname;
      Alcotest.(check int) "flap point count" 3 (List.length pts)
  | _ -> Alcotest.fail "expected a Perp axiom carrying LRestrict/FByPoints"
```

- [ ] **Step 2: Run it, confirm it fails to compile/parse**

Run: `dune test tests/test_parse.exe 2>&1 | head`
Expected: FAIL — `Unbound constructor Ast.LRestrict` (types not added yet).

- [ ] **Step 3: Extend the AST**

In `lib/ast.ml`, replace the `line_operand` block (lines 24-27) with:
```ocaml
and line_operand =
  | LNamed of crease_ref
  | LThrough of point_operand * point_operand * Error.span
  | LMember of string * string * Error.span
  | LRestrict of crease_ref * flap_operand * Error.span
    (* --( --d #(.a .b .c) ): the straight piece of crease --d on the flap *)

and flap_operand = FByPoints of point_operand list * Error.span
  (* #(.a .b .c): the unique current flat flap containing all listed points *)
```

- [ ] **Step 4: Add the lexer token**

In `lib/lexer.ml`, immediately after the `".(" -> POINT_OPEN` line (line 38), add:
```ocaml
  | "#(" -> FLAP_OPEN
```

- [ ] **Step 5: Add the grammar rule and token**

In `lib/parser.mly`:
- Add `FLAP_OPEN` to the `%token` line that declares `LINE_OPEN POINT_OPEN` (line 6).
- In the `line_operand` rule, add a production after the `LThrough` one:
```
line_operand:
  | crease_ref { LNamed $1 }
  | LINE_OPEN point_operand point_operand RPAREN { LThrough ($2, $3, $loc) }
  | LINE_OPEN crease_ref flap_operand RPAREN     { LRestrict ($2, $3, $loc) }
  | LINE_MEMBER_OPEN INSTANCE IDENT RBRACKET     { LMember ($2, $3, $loc) }
```
- Add a new rule (place it after `line_operand`):
```
flap_operand:
  | FLAP_OPEN point_operand_list RPAREN { FByPoints ($2, $loc) }

point_operand_list:
  | point_operand                    { [ $1 ] }
  | point_operand point_operand_list { $1 :: $2 }
```
(LR(1) is unambiguous: after `LINE_OPEN`, a `CREASE` lookahead selects `LRestrict`, while `POINT`/`POINT_OPEN`/`POINT_MEMBER_OPEN` select `LThrough` — disjoint FIRST sets.)

- [ ] **Step 6: Keep `eval` compiling — render + temporary resolution arm**

In `lib/eval.ml` `lstr` (after line 114, the `LMember` arm), add:
```ocaml
    | Ast.LRestrict (cr, Ast.FByPoints (pts, _), _) ->
        Printf.sprintf "--( --%s #(%s) )" cr.Ast.cname
          (String.concat " " (List.map pstr pts))
```
In `resolve_line` (after the `LMember` arm ending at line 156), add a **temporary** arm (replaced in Task 3):
```ocaml
    | Ast.LRestrict (_, _, span) ->
        Error.fail span "flap-restricted crease not yet implemented"
```

- [ ] **Step 7: Run the parse test green + build clean (no grammar conflicts)**

Run: `dune build 2>&1 | rg -i 'conflict|warning' ; dune test tests/test_parse.exe`
Expected: no Menhir conflict lines; parse test PASS.

- [ ] **Step 8: Existing goldens still green (frozen resolution unchanged)**

Run: `dune test tests/test_golden.exe`
Expected: PASS — no example uses the new syntax yet; named creases still resolve frozen.

- [ ] **Step 9: Commit**

```bash
git add lib/ast.ml lib/lexer.ml lib/parser.mly lib/eval.ml tests/test_parse.ml
git commit -m "feat(syntax): #(...) flap operand and --( --d #(...) ) restriction (#28)"
```

---

### Task 2: Fold_state material-crease accessors + shared crease id

Give `Fold_state` the three query functions material resolution needs, and switch edge minting to one `crease_id` per operation so a named crease's pieces share an id. **No `eval` change** — resolution stays frozen until Task 3, so all geometry goldens stay byte-identical (the new minting is inert: `crease_id` is never serialized or compared in fold logic).

**Files:**
- Modify: `lib/fold_state.ml` (add `?crease_id` to `subdivide:186` and `fold_with_records:280`; add three accessors)
- Test: `tests/test_fold_state.ml`

**Interfaces:**
- Produces (add to `fold_state.ml`, exact signatures):
```ocaml
val subdivide : t -> Geom.line -> ?crease_id:int -> prov:State.provenance option -> t
val fold_with_records :
  t -> axis:Geom.line -> move_side:int -> valley:bool -> ?crease_id:int ->
  prov:State.provenance option -> t

(* the current straight line of crease [cid], preferring [l_orig] when the
   pieces still lie on it (byte-stable). `Bent when a later fold split them
   apart; `Empty when no piece carries [cid]. *)
val crease_axis : t -> int -> Geom.line -> [ `Line of Geom.line | `Bent | `Empty ]

(* the unique face whose paper polygon contains every listed material paper
   point; `Zero / `Ambiguous otherwise. A "flat flap" is a face. *)
val flap_of_points : t -> Geom.point list -> [ `Face of int | `Zero | `Ambiguous ]

(* the straight line of crease [cid]'s piece lying on face [fi] (its edge in
   table space), or None if [cid] has no piece there. *)
val crease_piece_on_face : t -> int -> int -> Geom.line option
```
- Consumes: `edge` fields (`crease_id`, `ea`, `eb`, `left`, `right`), `st.faces.(_).iso`, `st.faces.(_).paper`, `Geom.side_of_line`, `Geom.in_convex_polygon`, `Geom.line_through`, `Geom.point_equal`, `Isometry.apply_point`.

- [ ] **Step 1: Write failing accessor tests**

Append to `tests/test_fold_state.ml` and register in its test list. (Uses the existing `q`/`line` helpers already at the top of that file from PR1; if absent, add `let q = Num.of_int` and `let pt x y = { Geom.x = q x; y = q y }`.)
```ocaml
(* a diagonal precrease is straight; after flip it tracks to the OTHER diagonal *)
let test_crease_axis_flat_and_flip () =
  let pt x y = { Geom.x = Num.of_int x; y = Num.of_int y } in
  let l_orig = Geom.line_through (pt 0 0) (pt 1 1) in  (* diagonal a-c *)
  let cid = Fold_state.fresh_crease_id () in
  let st = Fold_state.subdivide Fold_state.init_square l_orig ~crease_id:cid ~prov:None in
  (match Fold_state.crease_axis st cid l_orig with
   | `Line l ->
       Alcotest.(check bool) "flat crease returns its own line"
         true (Geom.side_of_line l (pt 0 0) = 0 && Geom.side_of_line l (pt 1 1) = 0)
   | _ -> Alcotest.fail "flat crease should resolve to a line");
  let stf = Fold_state.flip st in
  (match Fold_state.crease_axis stf cid l_orig with
   | `Line l ->
       (* the flipped diagonal passes through b(1,0) and d(0,1), not a(0,0)/c(1,1) *)
       Alcotest.(check bool) "flip tracked crease to the other diagonal"
         true (Geom.side_of_line l (pt 1 0) = 0 && Geom.side_of_line l (pt 0 1) = 0)
   | _ -> Alcotest.fail "flipped flat crease should still resolve to a line")

(* flap_of_points: the a-c split square has triangles; {a,b,c} picks exactly one *)
let test_flap_of_points_unique_zero_multi () =
  let pt x y = { Geom.x = Num.of_int x; y = Num.of_int y } in
  let l = Geom.line_through (pt 0 0) (pt 1 1) in
  let cid = Fold_state.fresh_crease_id () in
  let st = Fold_state.subdivide Fold_state.init_square l ~crease_id:cid ~prov:None in
  (match Fold_state.flap_of_points st [ pt 0 0; pt 1 0; pt 1 1 ] with
   | `Face _ -> ()
   | _ -> Alcotest.fail "{a,b,c} should pick a unique flap");
  (match Fold_state.flap_of_points st [ pt 0 0; pt 1 1 ] with
   | `Ambiguous -> ()  (* both triangles contain the shared diagonal endpoints *)
   | _ -> Alcotest.fail "{a,c} lie on both flaps → ambiguous");
  (match Fold_state.flap_of_points st [ pt 1 0; pt 0 1 ] with
   | `Zero -> ()  (* b and d are on opposite triangles → no single flap *)
   | _ -> Alcotest.fail "{b,d} share no flap → zero")
```

- [ ] **Step 2: Run, confirm failure**

Run: `dune test tests/test_fold_state.exe 2>&1 | head`
Expected: FAIL — `Unbound value Fold_state.crease_axis` / `flap_of_points`, and `subdivide` rejects `~crease_id`.

- [ ] **Step 3: Add `?crease_id` to `subdivide`**

In `lib/fold_state.ml`, change the `subdivide` signature (line 186) to:
```ocaml
let subdivide (st : t) (axis : Geom.line) ?crease_id
    ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
```
and replace the per-face mint at line 208 (`edge_seeds := (fi, a, b, fresh_crease_id ()) :: !edge_seeds`) with:
```ocaml
              edge_seeds := (fi, a, b, cid) :: !edge_seeds
```

- [ ] **Step 4: Add `?crease_id` to `fold_with_records`**

Change the signature (line 280-281) to add `?crease_id` before `~prov`:
```ocaml
let fold_with_records (st : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) ?crease_id ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
```
and replace the per-face mint at line 307 (`... assign_of (), fresh_crease_id ()) :: !edge_seeds`) with:
```ocaml
              edge_seeds := (fi, a, b, assign_of (), cid) :: !edge_seeds
```
(`simple_fold` at line 471 calls `fold_with_records` without `~crease_id`, so it defaults to one fresh id — unchanged behavior.)

- [ ] **Step 5: Add the three accessors**

Add after `neighbors` (after line 139) in `lib/fold_state.ml`:
```ocaml
(* table-space endpoints of every piece of crease [cid] (via each piece's
   [left] face isometry; endpoints live in the shared paper frame). *)
let crease_table_endpoints (st : t) (cid : int) : Geom.point list =
  Array.fold_left
    (fun acc e ->
      if e.crease_id = cid then
        let iso = st.faces.(e.left).iso in
        Isometry.apply_point iso e.ea :: Isometry.apply_point iso e.eb :: acc
      else acc)
    [] st.edges

let crease_axis (st : t) (cid : int) (l_orig : Geom.line) :
    [ `Line of Geom.line | `Bent | `Empty ] =
  match crease_table_endpoints st cid with
  | [] -> `Empty
  | pts ->
      if List.for_all (fun p -> Geom.side_of_line l_orig p = 0) pts then
        `Line l_orig (* unmoved: byte-stable, common case *)
      else
        (* find two distinct endpoints to define the current line *)
        let rec pick = function
          | a :: rest -> (
              match List.find_opt (fun b -> not (Geom.point_equal a b)) rest with
              | Some b -> Some (a, b)
              | None -> pick rest)
          | [] -> None
        in
        (match pick pts with
         | None -> `Empty
         | Some (a, b) ->
             let l = Geom.line_through a b in
             if List.for_all (fun p -> Geom.side_of_line l p = 0) pts then `Line l
             else `Bent)

let flap_of_points (st : t) (pts : Geom.point list) :
    [ `Face of int | `Zero | `Ambiguous ] =
  let contains i =
    List.for_all (fun p -> Geom.in_convex_polygon st.faces.(i).paper p) pts
  in
  let hits = ref [] in
  Array.iteri (fun i _ -> if contains i then hits := i :: !hits) st.faces;
  match !hits with [ i ] -> `Face i | [] -> `Zero | _ -> `Ambiguous

let crease_piece_on_face (st : t) (cid : int) (fi : int) : Geom.line option =
  Array.find_map
    (fun e ->
      if e.crease_id = cid && (e.left = fi || e.right = fi) then
        let iso = st.faces.(fi).iso in
        let a = Isometry.apply_point iso e.ea
        and b = Isometry.apply_point iso e.eb in
        if Geom.point_equal a b then None else Some (Geom.line_through a b)
      else None)
    st.edges
```

- [ ] **Step 6: Run the accessor tests green**

Run: `dune test tests/test_fold_state.exe`
Expected: PASS (flat/flip crease_axis + flap_of_points unique/zero/multi).

- [ ] **Step 7: Geometry goldens still byte-identical**

Run: `dune test tests/test_golden.exe`
Expected: PASS — minting one shared `crease_id` per op is inert; `eval` still resolves creases frozen.

- [ ] **Step 8: Commit**

```bash
git add lib/fold_state.ml tests/test_fold_state.ml
git commit -m "feat(fold-state): crease_axis/flap_of_points/crease_piece_on_face + shared crease id (#28)"
```

---

### Task 3: Material crease resolution in `eval`

> **Correction (applied during execution):** this section's premise that
> `multiple-folds.bel` bends `--b` is geometrically **false** — `--b = through .a .b`
> is a boundary crease that never materializes, and interior horizontal creases stay
> collinear across a perpendicular fold. **No existing example breaks; `multiple-folds.bel`
> is unchanged and all 20 goldens are byte-identical.** Two real adjustments landed:
> (a) `crease_axis` returning `` `Empty `` (a crease with no material pieces, e.g. a boundary
> reference line) resolves to `l_orig`, **not** an error — Step 4's `materialize_crease`
> `` `Empty `` arm returns `l_orig` instead of failing; (b) Steps 8-10 (the "rewrite" and
> golden regen) do **not** apply. The bent-crease + escape-hatch coverage lives entirely in
> Task 4's new examples.

Bind named creases to `Material (crease_id, l_orig)`; resolve them against current pieces (flat→line, moved→recomputed, bent→error, no-pieces→`l_orig`); implement `LRestrict`. All geometry goldens stay byte-identical (every example references its creases while flat, resolving to `l_orig`).

**Files:**
- Modify: `lib/eval.ml` (`crease_val` type; `scope.lines`/`instance.ilines` types; `lookup_crease`/`bind_crease`; `resolve_line` LNamed/LMember/LRestrict; `Crease` handler; `named_lines`)
- Modify: `examples/multiple-folds.bel` (escape hatch) + regenerate `tests/golden/multiple-folds.fold`

**Interfaces:**
- Produces (in `eval.ml`):
```ocaml
type crease_val =
  | Material of int * Geom.line  (* crease_id, original axis line *)
  | Frozen of Geom.line          (* derived line (def-param, LThrough-at-bind) *)
```
- Consumes: `Fold_state.crease_axis`, `Fold_state.flap_of_points`, `Fold_state.crease_piece_on_face`, `Fold_state.fresh_crease_id`, and the `?crease_id` params from Task 2.

- [ ] **Step 1: Baseline — geometry goldens green before touching eval**

Run: `dune test tests/test_golden.exe`
Expected: PASS (Task 2 left it green).

- [ ] **Step 2: Add `crease_val`; retype scope/instance line tables**

In `lib/eval.ml`, add after the `instance` type (after line 24), before `scope`:
```ocaml
type crease_val =
  | Material of int * Geom.line
  | Frozen of Geom.line
```
Change `instance.ilines` (line 23) and `scope.lines` (line 28) types from `(string, Geom.line) Hashtbl.t` to `(string, crease_val) Hashtbl.t`.

- [ ] **Step 3: Retype `lookup_crease`/`bind_crease`**

Replace `lookup_crease` (lines 56-59) return type — it now yields a `crease_val`:
```ocaml
let lookup_crease (ctx : ctx) (cr : Ast.crease_ref) : crease_val =
  match List.find_map (fun s -> Hashtbl.find_opt s.lines cr.Ast.cname) ctx.scopes with
  | Some cv -> cv
  | None -> Error.fail cr.Ast.cspan (Printf.sprintf "undefined crease --%s" cr.Ast.cname)
```
Change `bind_crease`'s last parameter (lines 79-86) from `(l : Geom.line)` to `(cv : crease_val)` and store `cv`:
```ocaml
let bind_crease (ctx : ctx) (name : string) (span : Error.span) (cv : crease_val) =
  let s = List.hd ctx.scopes in
  if (not (is_temp name)) && Hashtbl.mem s.lines name then
    Error.fail span
      (Printf.sprintf "crease --%s is already bound; only _-prefixed temps rebind" name);
  Hashtbl.replace s.lines name cv
```

- [ ] **Step 4: Material resolution helper + `resolve_line` arms**

Inside `eval_folded`, just before `resolve_point` (before line 118), add a materializer that closes over `ctx`:
```ocaml
  let materialize_crease ~(name : string) (span : Error.span) (cv : crease_val) :
      Geom.line =
    match cv with
    | Frozen l -> l
    | Material (cid, l_orig) -> (
        match Fold_state.crease_axis !(ctx.state) cid l_orig with
        | `Line l -> l
        | `Empty -> Error.fail span (Printf.sprintf "crease --%s has no pieces" name)
        | `Bent ->
            Error.fail span
              (Printf.sprintf
                 "--%s is no longer straight after folding; pick a flap, e.g. \
                  --( --%s #(.a .b .c) )"
                 name name))
  in
```
(`pstr`/`lstr`/`resolve_point`/`resolve_line` are defined with `let rec ... and ...`; place `materialize_crease` *before* that `let rec` so both can call it — it only needs `ctx`, not `resolve_*`. If the borrow checker of definition order bites, hoist it above `pstr` as shown.)

Replace the `LNamed` arm of `resolve_line` (line 139) with:
```ocaml
    | Ast.LNamed cr -> materialize_crease ~name:cr.Ast.cname cr.Ast.cspan (lookup_crease ctx cr)
```
Replace the `LMember` arm (lines 150-156) so instance lines materialize too:
```ocaml
    | Ast.LMember (iname, mem, span) -> (
        let inst = lookup_instance ctx iname span in
        match Hashtbl.find_opt inst.ilines mem with
        | Some cv -> materialize_crease ~name:mem span cv
        | None ->
            Error.fail span
              (Printf.sprintf "instance $%s has no line member %s" iname mem))
```
Replace the temporary `LRestrict` arm (added in Task 1 Step 6) with:
```ocaml
    | Ast.LRestrict (cr, Ast.FByPoints (pts, _), span) -> (
        let cid =
          match lookup_crease ctx cr with
          | Material (cid, _) -> cid
          | Frozen _ ->
              Error.fail span
                (Printf.sprintf "--%s is not a physical crease, so it has no flaps"
                   cr.Ast.cname)
        in
        let paper_pts = List.map resolve_point pts in
        match Fold_state.flap_of_points !(ctx.state) paper_pts with
        | `Zero -> Error.fail span "those points aren't all on one flap"
        | `Ambiguous -> Error.fail span "ambiguous flap; add another point"
        | `Face fi -> (
            match Fold_state.crease_piece_on_face !(ctx.state) cid fi with
            | Some l -> l
            | None ->
                Error.fail span
                  (Printf.sprintf "--%s does not lie on that flap" cr.Ast.cname)))
```

- [ ] **Step 5: `Crease` handler — mint id, fold, bind `Material`**

Rewrite the `Ast.Crease` arm body (lines 330-378). Mint one `crease_id`, pass it into the fold, bind the name to `Material (cid, axis)` *after* folding:
```ocaml
    | Ast.Crease (name_opt, ax, fold_opt, span) -> (
        let axis, axiom, sources = axis_of span ax in
        let cid = Fold_state.fresh_crease_id () in
        let prov_name =
          match name_opt with
          | Some n when not (is_temp n) -> (
              match ctx.name_ctx with
              | Root -> Some n
              | InInstance i -> Some (i ^ "." ^ n)
              | Anon -> None)
          | _ -> None
        in
        let prov : State.provenance option =
          Some { State.axiom; sources; span; name = prov_name; step = ctx.panel }
        in
        (match fold_opt with
        | None -> ctx.state := Fold_state.subdivide !(ctx.state) axis ~crease_id:cid ~prov
        | Some fs ->
            let move_side =
              match fs.Ast.moving with
              | Some po ->
                  let s = Geom.side_of_line axis (table_of po) in
                  if s = 0 then Error.fail span "the moving point lies on the fold axis";
                  s
              | None -> (
                  match ax with
                  | Ast.MapPoints (p, _)
                  | Ast.MapThrough (p, _, _, _)
                  | Ast.MapBoth (p, _, _, _, _) ->
                      let s = Geom.side_of_line axis (table_of p) in
                      if s = 0 then Error.fail span "the moving point lies on the fold axis";
                      s
                  | _ -> Error.fail span "this fold needs `moving .p` to choose the side")
            in
            let valley = fs.Ast.direction = Ast.Valley in
            ctx.state :=
              Fold_state.fold_with_records !(ctx.state) ~axis ~move_side ~valley
                ~crease_id:cid ~prov);
        match name_opt with
        | Some n -> bind_crease ctx n span (Material (cid, axis))
        | None -> ())
```

- [ ] **Step 6: Def line-params + `named_lines` emission**

Def line-param binding (line 418) freezes the resolved line:
```ocaml
            | `Line, Ast.ALine lo ->
                Hashtbl.replace body_scope.lines p.Ast.pname (Frozen (resolve_line lo))
```
The instance-build and export copies (lines 457-459, 488-490) already move `crease_val`s verbatim — no change (materiality is preserved through export; def-param inputs freeze, which is fine for this PR).

`named_lines` output (lines 522-526) extracts each `crease_val`'s stored line (frozen emission — see Global Constraints):
```ocaml
  let named_lines =
    Hashtbl.fold
      (fun k cv acc ->
        if is_temp k then acc
        else
          match cv with
          | Frozen l -> (k, l) :: acc
          | Material (_, l_orig) -> (k, l_orig) :: acc)
      root_scope.lines []
  in
```

- [ ] **Step 7: Build + run non-golden suites**

Run: `dune build && dune test tests/test_parse.exe tests/test_fold_state.exe tests/test_eval.exe`
Expected: PASS (compilation clean; unit/eval suites green).

- [ ] **Step 8: Run goldens — expect ONLY `multiple-folds` to break**

Run: `dune test tests/test_golden.exe 2>&1 | rg -i 'FAIL|multiple-folds' `
Expected: exactly one failure — `multiple-folds` now errors `--b is no longer straight after folding ...` (its `--b` precrease is folded across by `--v`, then referenced by `cross --b --v`). **If any *other* example's golden differs, STOP** — that is a resolution bug (a flat crease must return `l_orig`); fix `crease_axis`/`eval`, do not touch goldens.

- [ ] **Step 9: Rewrite `multiple-folds.bel` to the escape hatch**

Replace `examples/multiple-folds.bel` with (the top layer after the two folds is the flap carrying `.a`/`.b`; name it via its corner points — verify the exact point set against the error/geometry when you run it):
```
; status: works — diagonal fold then a half fold; --b is bent by the --v fold,
; so cross the top-layer PIECE of --b (via the flap operand) with --v (#28)
paper square

@map .c onto .a moving .c
--b = through .a .b
--v = @map .b onto .a
.mid = cross --( --b #(.a .b) ) --v
map .d onto .mid
```
Run and confirm it folds (adjust the `#(...)` point set if `flap_of_points` reports `Zero`/`Ambiguous` — pick corner points that uniquely identify the top flap holding the wanted `--b` piece):
Run: `dune exec bin/main.exe -- fold examples/multiple-folds.bel | rg -i 'error' ; echo done`
Expected: no error line; `done`.

- [ ] **Step 10: Regenerate ONLY the `multiple-folds` golden**

Use the throwaway-regen pattern (PR1 Task 1 Step 4): run it, copy only `tests/golden/multiple-folds.fold`, confirm `git status` shows no other golden changed, remove the throwaway stanza.
Run: `git status --short tests/golden/`
Expected: only `tests/golden/multiple-folds.fold` modified.

- [ ] **Step 11: Full suite green**

Run: `dune test`
Expected: PASS — all suites, including the regenerated `multiple-folds` golden.

- [ ] **Step 12: Commit**

```bash
git add lib/eval.ml examples/multiple-folds.bel tests/golden/multiple-folds.fold
git commit -m "feat(eval): material named creases — per-flap resolution, bent→error, flap restriction (#28)"
```

---

### Task 4: Showcase examples + end-to-end tests for the three PR2 behaviors

Lock the new semantics with dedicated examples and e2e assertions: bare reuse of a bent crease errors with the hint; the `--( --d #(...) )` restriction resolves and folds; a fold-then-`flip` program that reuses a still-flat crease resolves to the *tracked* line.

**Files:**
- Create: `examples/crease-flap-restrict.bel`, `examples/crease-flip-reuse.bel` (+ their goldens)
- Modify: `tests/test_e2e.ml` (bent-error + restriction-resolves cases)

**Interfaces:**
- Consumes: `Beloch.fold_string ~filename` (raises `Error.Beloch_error (_, msg)` on the bent-crease case), the golden harness (auto-discovers new `examples/*.bel`).

- [ ] **Step 1: e2e test — bare reuse of a bent crease errors with the hint**

Append to `tests/test_e2e.ml` (match its existing helper/assert style; it already catches `Error.Beloch_error`):
```ocaml
let test_bent_crease_bare_reuse_errors () =
  let src =
    "paper square\n\
     --b = through .a .c\n\
     --v = @map .c onto .b moving .c\n\
     .mid = cross --b --v\n"  (* bare reuse of the now-bent --b *)
  in
  match Beloch.fold_string ~filename:"t.bel" src with
  | exception Error.Beloch_error (_, msg) ->
      Alcotest.(check bool) "mentions no longer straight" true
        (let re = Str.regexp_string "no longer straight" in
         (try ignore (Str.search_forward re msg 0); true with Not_found -> false));
      Alcotest.(check bool) "hints the flap escape hatch" true
        (let re = Str.regexp_string "#(" in
         (try ignore (Str.search_forward re msg 0); true with Not_found -> false))
  | _ -> Alcotest.fail "expected a bent-crease error"
```

- [ ] **Step 2: e2e test — the restriction resolves and folds**

```ocaml
let test_flap_restriction_resolves () =
  let src =
    "paper square\n\
     --b = through .a .c\n\
     --v = @map .c onto .b moving .c\n\
     .mid = cross --( --b #(.c .d) ) --v\n"  (* the folded-flap piece of --b *)
  in
  match Beloch.fold_string ~filename:"t.bel" src with
  | exception Error.Beloch_error (_, msg) ->
      Alcotest.failf "restriction should resolve, got error: %s" msg
  | _ -> ()  (* folded without error *)
```
(The `#(.c .d)` set is proven: after these two folds `#(.c)`→Ambiguous, `#(.d)`→unique, `#(.c .d)`→unique, `#(.c .d .a)`→Zero. Both the bent top piece `x+y=1` and the flat base piece `y=x` cross `--v` at `(1/2,1/2)`, so `.mid` is well-defined.)

- [ ] **Step 3: Register both cases + run them**

Add both to `test_e2e.ml`'s test list. Run:
Run: `dune test tests/test_e2e.exe`
Expected: PASS.

- [ ] **Step 4: Add the flip-reuse showcase example**

Create `examples/crease-flip-reuse.bel` (a diagonal crease is off-center, so `flip` genuinely relocates it — reuse must track, not snap back):
```
; status: works — precrease a diagonal, flip the paper, then reuse the crease:
; material tracking means --q resolves to the FLIPPED diagonal, not the original (#28)
paper square
--q = through .a .c
flip
perp --q through .b
```
Run and confirm no error:
Run: `dune exec bin/main.exe -- fold examples/crease-flip-reuse.bel | rg -i error ; echo done`
Expected: no error line; `done`.

- [ ] **Step 5: Add the flap-restriction showcase example**

Create `examples/crease-flap-restrict.bel` (the proven bending scenario: `--b` runs corner-to-corner; folding the top half down across `y=1/2` reflects `--b`'s upper half, so `--b` is no longer straight — reference the top-layer piece via its flap):
```
; status: works — a diagonal precrease then a half fold that BENDS it (#28).
; Bare --b would error "no longer straight"; name its folded-flap PIECE
; (upper flap, corners .c/.d) via the flap operand and cross that with --v.
paper square
--b = through .a .c
--v = @map .c onto .b moving .c
.mid = cross --( --b #(.c .d) ) --v
map .d onto .mid
```
(Keep the `#(.c .d)` point set consistent with the e2e tests above.)

- [ ] **Step 6: Generate goldens for the two new examples**

The golden harness auto-discovers them and reports "no golden" until they exist. Use the throwaway-regen pattern; commit only the two new `tests/golden/crease-flip-reuse.fold` and `tests/golden/crease-flap-restrict.fold`. Confirm no other golden changed.
Run: `git status --short tests/golden/`
Expected: only the two new `.fold` files added.

- [ ] **Step 7: Full suite green**

Run: `dune test`
Expected: PASS — parse, fold_state, eval, e2e, and golden (now covering the two new examples; `multiple-folds.bel` is unchanged — see the Task 3 correction note).

- [ ] **Step 8: Commit**

```bash
git add examples/crease-flap-restrict.bel examples/crease-flip-reuse.bel \
        tests/golden/crease-flap-restrict.fold tests/golden/crease-flip-reuse.fold \
        tests/test_e2e.ml
git commit -m "test(#28): bent-error, flap-restriction, and flip-reuse coverage"
```

---

## Self-review

- **Spec coverage (design §2/§3/§4/§8):**
  - §2 new operands `#(.a .b .c)` and `--( --d #(.a .b .c) )` → Task 1 (syntax) + Task 3 Step 4 (`LRestrict` resolution) + Task 2 (`flap_of_points`, `crease_piece_on_face`).
  - §2 flap-resolution rule (unique face; zero→error, multi→error) → `flap_of_points` `Zero`/`Ambiguous`, surfaced in Task 3 Step 4 with the design's messages.
  - §3 crease reference semantics (collinear→line; bent→error with hint) → `crease_axis` (Task 2) + `materialize_crease` (Task 3 Step 4); error string matches §3 verbatim.
  - §3 escape hatch resolves to a valid line → Task 3 Step 4 `LRestrict` + Task 4 Step 2.
  - §4 `flip` needs no crease handling; material tracking through flip → `crease_axis`'s recompute branch (Task 2), tested in Task 2 Step 1 and Task 4 Step 4.
  - §7 PR2 verification bullets (bare reuse errors; restriction resolves; unchanged programs; flip reuse) → Task 4 Steps 1/2 + Task 3 Step 8 + Task 2 Step 1.
- **Placeholders:** Task 1 Step 6 installs a deliberately-temporary `LRestrict` arm (replaced verbatim in Task 3 Step 4) — flagged, not a silent TODO. The `multiple-folds.bel` / e2e `#(...)` point sets carry an explicit "adjust if `flap_of_points` reports Zero/Ambiguous" instruction with the resolution rule to apply — the flap is determined by geometry discovered at run time, guarded by the run gates; this is a TDD target, not a gap.
- **Type consistency:** `crease_val` (`Material of int * Geom.line | Frozen of Geom.line`) used consistently across `scope.lines`, `instance.ilines`, `lookup_crease`, `bind_crease`, `materialize_crease`, `named_lines`. `crease_axis : t -> int -> Geom.line -> [ `Line | `Bent | `Empty ]`, `flap_of_points : t -> Geom.point list -> [ `Face | `Zero | `Ambiguous ]`, `crease_piece_on_face : t -> int -> int -> Geom.line option` — signatures match between Task 2 (definition) and Task 3 (call sites). `?crease_id` optional param added to `subdivide`/`fold_with_records`; existing callers (`simple_fold`, tests) unaffected; `eval` passes `~crease_id:cid`.
- **Kernel isolation:** no task touches `num.ml`/`poly.ml`/`mpoly.ml`; all geometry via `Geom`/`Isometry`. Golden net proves geometry exactness end-to-end.
- **Scope discipline (out of this PR, per design §8-analog):** `named_lines` materiality in the emitted JSON is deferred (kept frozen). Def line-*param inputs* freeze a passed material crease (materiality preserved on export, not on parameter passing). Taco/tortilla adjacency checks, richer region-as-predicate, and non-flat folds remain deferred to later slices.
