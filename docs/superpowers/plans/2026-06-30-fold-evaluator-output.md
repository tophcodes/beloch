# Fold Evaluator & Dual Output Implementation Plan (Plan B-2b)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `@` folds actually fold — thread a `Fold_state` through evaluation and emit a dual-frame FOLD file (`creasePattern` + `foldedForm`) with derived mountain/valley and `faceOrders`.

**Architecture:** A new evaluator `Eval.eval_folded : program -> folded` threads `Fold_state` (start `init_square`), resolving references against the current state; bare axioms `subdivide`, `@` axioms `fold_with_records`. A new emitter `Fold_emit.to_json_folded : folded -> json` builds the planar graph directly from the face set and emits both frames. Both are added **alongside** the old `eval`/`to_json` (build stays green), then `beloch.ml` is switched over and the old path + its tests removed. Crease provenance (the v0.5 crease-names feature) is preserved by carrying it on each crease record.

**Tech Stack:** OCaml, dune, `Num`, `Isometry`, `Fold_state` (B-1/B-2a), `Geom`, yojson, alcotest.

## Slice decomposition (context)

This is **Plan B-2b** of the fold-evaluator slice (design: `docs/superpowers/specs/2026-06-29-fold-evaluator-output-design.md`); it builds on the landed B-2a primitives (`Fold_state.subdivide`/`fold_with_records`/`paper_preimages`, `Geom.convex_overlap`/`on_segment`). It is the first slice where `@` produces a folded artifact. Visual — attach fold2svg screenshots to the PR.

Resolved during foldformat review:
- **`faceOrders [f,g,s]`**: `s = +1` iff `f` is above `g` (toward `g`'s normal). Face normal is +z iff its table polygon is CCW iff `Isometry.det_sign face.iso > 0`. Faces are stored bottom→top (array index = layer). So `s = if ((fi > gi) = (det_sign g > 0)) then 1 else -1` for an overlapping pair `(fi, gi)`.
- **Frames**: frame 0 (top-level) = `creasePattern`; the `foldedForm` is `file_frames[0]` with `frame_parent: 0`, `frame_inherit: true`, overriding `vertices_coords` and adding `faceOrders`. Both frames share one vertex set (dedup by paper coord; emit paper coords in frame 0, table coords in the folded frame).

## Global Constraints

- Build `dune build`; test `dune test` (from repo root — e2e examples use a relative path). Warnings fatal in dev — clean builds.
- ocamlformat-clean (0.29.0, default) — `dune fmt` before each commit.
- **All geometry exact via `Num` — no floating point** except at JSON serialization (`Fold_emit.q_to_json` already does `Num.to_float`).
- `file_creator` string in `Fold_emit` is a literal kept in sync with `Beloch.version` (currently `"beloch 0.3.0-dev"`); do not reference `Beloch` from `fold_emit` (module cycle — see the comment in `fold_emit.ml`).
- FOLD facts (from `refs/foldformat.md`): `edges_foldAngle` is +180 for valley, −180 for mountain, 0 otherwise; `faces_vertices` CCW; `faceOrders` sign as above; `frame_inherit` inherits non-overridden parent properties.
- Commits: Conventional Commits; end the body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

Existing types: `State.provenance = { axiom : string; sources : string list; span : Error.span; name : string option }`. `Ast`: `Crease of string option * axiom * fold_spec option * Error.span`, `fold_spec = { moving : point_ref option; direction : direction }`, `direction = Valley | Mountain`, `point_ref = { name; span }`, `crease_ref = { cname; cspan }`, axioms `Through`/`MapPoints`/`Perp`/`MapLines of crease_ref*crease_ref*point_ref option`, `point_expr = Cross of crease_ref * crease_ref`. `Eval.corners : (string * Geom.point) list`. `Fold_state.{face,t,init_square,table_position,table_polygon,subdivide,fold_with_records,paper_preimages,assign,crease_record}`. `Geom.{convex_overlap,on_segment,side_of_line,point_equal,intersection,line_through,perpendicular_bisector,perpendicular_through,angle_bisectors,parallel_midline}`. `Isometry.{apply_point,det_sign}`.

---

### Task 1: Carry provenance on crease records

Extend `Fold_state.crease_record` with an optional `State.provenance`, and thread it through `subdivide`/`fold_with_records` so the emitter can rebuild `beloch:edges` (preserving the v0.5 crease-names feature).

**Files:**
- Modify: `lib/fold_state.ml`
- Test: `tests/test_beloch.ml` (update B-2a call sites)

**Interfaces:**
- Produces:
  - `Fold_state.crease_record = { ra : Geom.point; rb : Geom.point; assign : assign; prov : State.provenance option }`
  - `Fold_state.subdivide : t -> Geom.line -> prov:State.provenance option -> t * crease_record list`
  - `Fold_state.fold_with_records : t -> axis:Geom.line -> move_side:int -> valley:bool -> prov:State.provenance option -> t * crease_record list`
  - `Fold_state.simple_fold` unchanged (calls `fold_with_records … ~prov:None`).

- [ ] **Step 1: Update the existing B-2a tests to the new signatures**

In `tests/test_beloch.ml`, the four B-2a `fold_state` tests call `subdivide`/`fold_with_records`. Add `~prov:None` to each call:
- `test_fold_subdivide`: `Fold_state.subdivide Fold_state.init_square axis` → `Fold_state.subdivide Fold_state.init_square axis ~prov:None`
- `test_fold_records_valley`: `Fold_state.fold_with_records Fold_state.init_square ~axis ~move_side:1 ~valley:true` → add `~prov:None`
- `test_fold_records_accordion`: the `fold_with_records st1 ~axis:axis2 ~move_side:1 ~valley:true` → add `~prov:None`

(The `record.assign` field access in `count_assign` is unchanged.)

- [ ] **Step 2: Run to verify it fails**

Run: `dune build 2>&1`
Expected: FAIL — the record type has no `prov` / arity mismatch on the calls (the new `~prov` label is unbound until Step 3).

- [ ] **Step 3: Implement in `lib/fold_state.ml`**

Change the `crease_record` type:

```ocaml
type crease_record = {
  ra : Geom.point;
  rb : Geom.point;
  assign : assign;
  prov : State.provenance option;
}
```

In `subdivide`, change the signature and the record construction:

```ocaml
let subdivide (st : t) (axis : Geom.line) ~(prov : State.provenance option) :
    t * crease_record list =
```

and the U-record line:

```ocaml
           | Some (a, b) -> recs := { ra = a; rb = b; assign = U; prov } :: !recs
```

In `fold_with_records`, change the signature and the M/V-record line:

```ocaml
let fold_with_records (st : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) ~(prov : State.provenance option) :
    t * crease_record list =
```

```ocaml
               recs := { ra = a; rb = b; assign; prov } :: !recs
```

Update `simple_fold` to pass `~prov:None`:

```ocaml
let simple_fold (st : t) ~(axis : Geom.line) ~(move_side : int) ~(valley : bool) :
    t =
  fst (fold_with_records st ~axis ~move_side ~valley ~prov:None)
```

- [ ] **Step 4: Run to verify it passes**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: PASS — all tests green (the B-2a record tests now pass `~prov:None`), build clean.

- [ ] **Step 5: Commit**

```bash
git add lib/fold_state.ml tests/test_beloch.ml
git commit -m "feat(fold-state): carry provenance on crease records

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `Eval.eval_folded`

Add a stateful evaluator that threads `Fold_state` and returns the folded result. Leave the old `Eval.eval` in place (build stays green; it is removed in Task 4).

**Files:**
- Modify: `lib/eval.ml`
- Test: `tests/test_beloch.ml`

**Interfaces:**
- Consumes: `Fold_state.{init_square,subdivide,fold_with_records,paper_preimages,table_position,t,crease_record}`, `Geom.side_of_line`, the axiom geometry helpers.
- Produces:
  - `Eval.folded = { state : Fold_state.t; creases : Fold_state.crease_record list }`
  - `Eval.eval_folded : Ast.program -> folded`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_beloch.ml`:

```ocaml
let test_eval_folded_half () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel" "paper square\n@map .b onto .a moving .b\n")
  in
  Alcotest.(check int) "two faces" 2 (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "one valley record" 1 (count_assign Fold_state.V fd.Eval.creases);
  (* .b lands exactly on .a = (0,0) *)
  Alcotest.(check bool) ".b maps onto .a" true
    (Geom.point_equal (Fold_state.table_position fd.Eval.state (pt 1 0)) (pt 0 0))

let test_eval_folded_precrease () =
  let fd =
    Eval.eval_folded (Beloch.parse ~filename:"t.bel" "paper square\nmap .a onto .c\n")
  in
  Alcotest.(check int) "two faces" 2 (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int) "one U record" 1 (count_assign Fold_state.U fd.Eval.creases)

let test_eval_folded_moving_required () =
  expect_error "moving"
    (fun () ->
      Eval.eval_folded
        (Beloch.parse ~filename:"t.bel"
           "paper square\n--d: through .a .c\n@perp --d through .b\n"))

let test_eval_folded_quarter_accordion () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n@map .b onto .a moving .b\n@map .d onto .a moving .d\n")
  in
  Alcotest.(check int) "four faces after quarter fold" 4
    (Array.length fd.Eval.state.Fold_state.faces);
  (* second fold cuts two layers of alternating orientation -> one V, one M *)
  Alcotest.(check int) "an accordion mountain appears" 1
    (count_assign Fold_state.M fd.Eval.creases)
```

Register in a new `"eval_folded"` group:

```ocaml
      ("eval_folded",
       [ Alcotest.test_case "half fold" `Quick test_eval_folded_half;
         Alcotest.test_case "precrease subdivide" `Quick test_eval_folded_precrease;
         Alcotest.test_case "moving required" `Quick test_eval_folded_moving_required;
         Alcotest.test_case "quarter accordion" `Quick test_eval_folded_quarter_accordion ]);
```

- [ ] **Step 2: Run to verify they fail**

Run: `dune build 2>&1`
Expected: FAIL — `Unbound value Eval.eval_folded`.

- [ ] **Step 3: Implement in `lib/eval.ml`**

Add at the end of `lib/eval.ml`:

```ocaml
type folded = {
  state : Fold_state.t;
  creases : Fold_state.crease_record list;
}

let eval_folded (prog : Ast.program) : folded =
  let points : (string, Geom.point) Hashtbl.t = Hashtbl.create 16 in
  List.iter (fun (n, p) -> Hashtbl.replace points n p) corners;
  let creases_env : (string, Geom.line) Hashtbl.t = Hashtbl.create 16 in
  let state = ref Fold_state.init_square in
  let recs = ref [] in
  let lookup_point (pr : Ast.point_ref) : Geom.point =
    match Hashtbl.find_opt points pr.Ast.name with
    | Some p -> p
    | None -> Error.fail pr.Ast.span (Printf.sprintf "undefined point .%s" pr.Ast.name)
  in
  let table_of (pr : Ast.point_ref) : Geom.point =
    Fold_state.table_position !state (lookup_point pr)
  in
  let lookup_crease (cr : Ast.crease_ref) : Geom.line =
    match Hashtbl.find_opt creases_env cr.Ast.cname with
    | Some l -> l
    | None ->
        Error.fail cr.Ast.cspan (Printf.sprintf "undefined crease --%s" cr.Ast.cname)
  in
  (* axis line + provenance (axiom tag, source names), evaluated against the
     current table positions *)
  let axis_of (span : Error.span) (ax : Ast.axiom) : Geom.line * string * string list =
    match ax with
    | Ast.Through (p, q) ->
        let pp = table_of p and qq = table_of q in
        if Geom.point_equal pp qq then Error.fail span "axiom 1 needs two distinct points";
        (Geom.line_through pp qq, "axiom1", [ "." ^ p.Ast.name; "." ^ q.Ast.name ])
    | Ast.MapPoints (p, q) ->
        let pp = table_of p and qq = table_of q in
        if Geom.point_equal pp qq then Error.fail span "axiom 2 needs two distinct points";
        ( Geom.perpendicular_bisector pp qq,
          "axiom2",
          [ "." ^ p.Ast.name; "." ^ q.Ast.name ] )
    | Ast.Perp (p, l) ->
        ( Geom.perpendicular_through (lookup_crease l) (table_of p),
          "axiom3",
          [ "." ^ p.Ast.name; "--" ^ l.Ast.cname ] )
    | Ast.MapLines (c1, c2, p_opt) ->
        let l1 = lookup_crease c1 and l2 = lookup_crease c2 in
        let base = [ "--" ^ c1.Ast.cname; "--" ^ c2.Ast.cname ] in
        let eval_at (l : Geom.line) (pt : Geom.point) : Num.t =
          Num.sub
            (Num.add (Num.mul l.Geom.a pt.Geom.x) (Num.mul l.Geom.b pt.Geom.y))
            l.Geom.c
        in
        (match Geom.angle_bisectors l1 l2 with
         | None ->
             let k =
               if Num.sign l1.Geom.a <> 0 then Num.div l2.Geom.a l1.Geom.a
               else Num.div l2.Geom.b l1.Geom.b
             in
             if Num.equal l2.Geom.c (Num.mul k l1.Geom.c) then
               Error.fail span "lines are identical";
             (Geom.parallel_midline l1 l2, "axiom5", base)
         | Some (bis_eq, bis_opp) -> (
             match p_opt with
             | None -> Error.fail span "bisector is ambiguous; add `toward .p`"
             | Some pr ->
                 let p = table_of pr in
                 let s1 = Num.sign (eval_at l1 p) and s2 = Num.sign (eval_at l2 p) in
                 if s1 = 0 || s2 = 0 then
                   Error.fail span "reference point on a fold line; bisector ambiguous";
                 ( (if s1 = s2 then bis_eq else bis_opp),
                   "axiom5",
                   base @ [ "." ^ pr.Ast.name ] )))
  in
  List.iter
    (fun stmt ->
      match stmt with
      | Ast.Crease (name_opt, ax, fold_opt, span) ->
          let axis, axiom, sources = axis_of span ax in
          (match name_opt with
           | Some n -> Hashtbl.replace creases_env n axis
           | None -> ());
          let prov : State.provenance option =
            Some { State.axiom; sources; span; name = name_opt }
          in
          (match fold_opt with
           | None ->
               let st, rs = Fold_state.subdivide !state axis ~prov in
               state := st;
               recs := rs @ !recs
           | Some fs ->
               let move_side =
                 match fs.Ast.moving with
                 | Some pr ->
                     let s = Geom.side_of_line axis (table_of pr) in
                     if s = 0 then Error.fail span "the moving point lies on the fold axis";
                     s
                 | None -> (
                     match ax with
                     | Ast.MapPoints (p, _) ->
                         let s = Geom.side_of_line axis (table_of p) in
                         if s = 0 then
                           Error.fail span "the moving point lies on the fold axis";
                         s
                     | _ -> Error.fail span "this fold needs `moving .p` to choose the side")
               in
               let valley = fs.Ast.direction = Ast.Valley in
               let st, rs =
                 Fold_state.fold_with_records !state ~axis ~move_side ~valley ~prov
               in
               state := st;
               recs := rs @ !recs)
      | Ast.Point (n, Ast.Cross (c1, c2), span) ->
          let l1 = lookup_crease c1 and l2 = lookup_crease c2 in
          (match Geom.intersection l1 l2 with
           | None -> Error.fail span "creases are parallel; no intersection"
           | Some tp -> (
               match Fold_state.paper_preimages !state tp with
               | [ p ] -> Hashtbl.replace points n p
               | [] -> Error.fail span "intersection lies off the paper"
               | _ -> Error.fail span "ambiguous reference in a folded region")))
    prog;
  { state = !state; creases = !recs }
```

- [ ] **Step 4: Run to verify they pass**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: PASS, build clean.

- [ ] **Step 5: Commit**

```bash
git add lib/eval.ml tests/test_beloch.ml
git commit -m "feat(eval): stateful folded evaluator (eval_folded)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `Fold_emit.to_json_folded` — dual frames

Add a dual-frame emitter built from the face set. Leave the old `to_json` in place (removed in Task 4).

**Files:**
- Modify: `lib/fold_emit.ml`
- Test: `tests/test_beloch.ml`

**Interfaces:**
- Consumes: `Eval.folded`, `Fold_state.{face,t,crease_record,assign}`, `Isometry.apply_point`, `Isometry.det_sign`, `Geom.{on_segment,convex_overlap,point_equal}`, `State.provenance`.
- Produces: `Fold_emit.to_json_folded : Eval.folded -> Yojson.Safe.t`

- [ ] **Step 1: Write the failing tests**

```ocaml
let test_emit_folded_frames () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel" "paper square\n@map .b onto .a moving .b\n")
  in
  let json = Fold_emit.to_json_folded fd in
  let open Yojson.Safe.Util in
  Alcotest.(check string) "frame 0 is creasePattern" "creasePattern"
    (json |> member "frame_classes" |> to_list |> List.hd |> to_string);
  let frames = json |> member "file_frames" |> to_list in
  Alcotest.(check int) "one extra frame" 1 (List.length frames);
  let folded = List.hd frames in
  Alcotest.(check string) "extra frame is foldedForm" "foldedForm"
    (folded |> member "frame_classes" |> to_list |> List.hd |> to_string);
  Alcotest.(check bool) "folded frame inherits" true
    (folded |> member "frame_inherit" |> to_bool);
  (* the single crease is a valley *)
  let assigns = json |> member "edges_assignment" |> to_list |> List.map to_string in
  Alcotest.(check bool) "has a V crease" true (List.mem "V" assigns);
  Alcotest.(check bool) "has B boundary" true (List.mem "B" assigns);
  (* two overlapping faces -> one faceOrders triple *)
  Alcotest.(check int) "one faceOrders triple" 1
    (folded |> member "faceOrders" |> to_list |> List.length)

let test_emit_folded_crease_name () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel" "paper square\n--m: map .a onto .c\n")
  in
  let json = Fold_emit.to_json_folded fd in
  let open Yojson.Safe.Util in
  let names =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function `Null -> None | e -> Some (e |> member "name"))
  in
  Alcotest.(check bool) "crease carries name m" true
    (List.exists (fun n -> n = `String "m") names)
```

Register in a new `"emit_folded"` group:

```ocaml
      ("emit_folded",
       [ Alcotest.test_case "dual frames" `Quick test_emit_folded_frames;
         Alcotest.test_case "crease name preserved" `Quick test_emit_folded_crease_name ]);
```

- [ ] **Step 2: Run to verify they fail**

Run: `dune build 2>&1`
Expected: FAIL — `Unbound value Fold_emit.to_json_folded`.

- [ ] **Step 3: Implement in `lib/fold_emit.ml`**

Add at the end of `lib/fold_emit.ml` (the existing `q_to_json` helper is reused):

```ocaml
let to_json_folded (fd : Eval.folded) : Yojson.Safe.t =
  let faces = fd.Eval.state.Fold_state.faces in
  let creases = fd.Eval.creases in
  (* dedup vertices by paper coord; remember paper + table coords per vertex *)
  let vpaper = Dynarray.create () and vtable = Dynarray.create () in
  let vindex (f : Fold_state.face) (p : Geom.point) : int =
    let n = Dynarray.length vpaper in
    let rec find i =
      if i >= n then -1
      else if Geom.point_equal p (Dynarray.get vpaper i) then i
      else find (i + 1)
    in
    let i = find 0 in
    if i >= 0 then i
    else begin
      Dynarray.add_last vpaper p;
      Dynarray.add_last vtable (Isometry.apply_point f.Fold_state.iso p);
      n
    end
  in
  let face_idx =
    Array.map (fun f -> Array.map (vindex f) f.Fold_state.paper) faces
  in
  (* edge classification *)
  let on_unit_boundary (a : Geom.point) (b : Geom.point) : bool =
    let z = Num.zero and o = Num.one in
    (Num.equal a.Geom.x z && Num.equal b.Geom.x z)
    || (Num.equal a.Geom.x o && Num.equal b.Geom.x o)
    || (Num.equal a.Geom.y z && Num.equal b.Geom.y z)
    || (Num.equal a.Geom.y o && Num.equal b.Geom.y o)
  in
  let record_of (a : Geom.point) (b : Geom.point) : Fold_state.crease_record option =
    List.find_opt
      (fun (r : Fold_state.crease_record) ->
        Geom.on_segment (r.Fold_state.ra, r.Fold_state.rb) a
        && Geom.on_segment (r.Fold_state.ra, r.Fold_state.rb) b)
      creases
  in
  (* collect unique edges with (assignment string, provenance) *)
  let edge_tbl = Hashtbl.create 64 in
  let edges = ref [] in
  Array.iteri
    (fun fi f ->
      let idxs = face_idx.(fi) in
      let m = Array.length idxs in
      for k = 0 to m - 1 do
        let ia = idxs.(k) and ib = idxs.((k + 1) mod m) in
        let key = (min ia ib, max ia ib) in
        if not (Hashtbl.mem edge_tbl key) then begin
          Hashtbl.replace edge_tbl key ();
          let pa = f.Fold_state.paper.(k) and pb = f.Fold_state.paper.((k + 1) mod m) in
          let assign, prov =
            if on_unit_boundary pa pb then ("B", None)
            else
              match record_of pa pb with
              | Some r ->
                  let a =
                    match r.Fold_state.assign with
                    | Fold_state.M -> "M"
                    | Fold_state.V -> "V"
                    | Fold_state.U -> "U"
                  in
                  (a, r.Fold_state.prov)
              | None -> ("U", None)
          in
          edges := (ia, ib, assign, prov) :: !edges
        end
      done)
    faces;
  let edges = List.rev !edges in
  let verts_paper =
    Dynarray.to_list vpaper
    |> List.map (fun (p : Geom.point) ->
           `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ])
  in
  let verts_table =
    Dynarray.to_list vtable
    |> List.map (fun (p : Geom.point) ->
           `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ])
  in
  let edges_vertices =
    List.map (fun (a, b, _, _) -> `List [ `Int a; `Int b ]) edges
  in
  let edges_assignment = List.map (fun (_, _, a, _) -> `String a) edges in
  let edges_fold_angle =
    List.map
      (fun (_, _, a, _) ->
        match a with "V" -> `Float 180.0 | "M" -> `Float (-180.0) | _ -> `Float 0.0)
      edges
  in
  let faces_vertices =
    Array.to_list face_idx
    |> List.map (fun idxs -> `List (Array.to_list (Array.map (fun i -> `Int i) idxs)))
  in
  let beloch_edges =
    List.map
      (fun (_, _, _, prov) ->
        match prov with
        | None -> `Null
        | Some (pr : State.provenance) ->
            `Assoc
              [
                ("axiom", `String pr.State.axiom);
                ( "sources",
                  `List (List.map (fun s -> `String s) pr.State.sources) );
                ("span", `String (Error.span_to_string pr.State.span));
                ( "name",
                  match pr.State.name with Some n -> `String n | None -> `Null );
              ])
      edges
  in
  (* faceOrders for overlapping face pairs; faces array index = layer (bottom->top) *)
  let table_poly i =
    Array.map (Isometry.apply_point faces.(i).Fold_state.iso) faces.(i).Fold_state.paper
  in
  let nf = Array.length faces in
  let face_orders = ref [] in
  for fi = 0 to nf - 1 do
    for gi = fi + 1 to nf - 1 do
      if Geom.convex_overlap (table_poly fi) (table_poly gi) then begin
        let g_up = Isometry.det_sign faces.(gi).Fold_state.iso > 0 in
        let s = if fi > gi = g_up then 1 else -1 in
        face_orders := `List [ `Int fi; `Int gi; `Int s ] :: !face_orders
      end
    done
  done;
  let folded_frame =
    `Assoc
      [
        ("frame_classes", `List [ `String "foldedForm" ]);
        ("frame_parent", `Int 0);
        ("frame_inherit", `Bool true);
        ("vertices_coords", `List verts_table);
        ("edges_foldAngle", `List edges_fold_angle);
        ("faceOrders", `List (List.rev !face_orders));
      ]
  in
  `Assoc
    [
      ("file_spec", `Float 1.1);
      ("file_creator", `String "beloch 0.3.0-dev");
      ("frame_classes", `List [ `String "creasePattern" ]);
      ("vertices_coords", `List verts_paper);
      ("edges_vertices", `List edges_vertices);
      ("edges_assignment", `List edges_assignment);
      ("faces_vertices", `List faces_vertices);
      ("beloch:edges", `List beloch_edges);
      ("file_frames", `List [ folded_frame ]);
    ]
```

Note: `if fi > gi = g_up` parses as `if (fi > gi) = g_up` (both `bool`); OCaml `>` binds tighter than `=`. If the implementer finds this ambiguous, write `if (fi > gi) = g_up`.

- [ ] **Step 4: Run to verify they pass**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: PASS, build clean.

- [ ] **Step 5: Commit**

```bash
git add lib/fold_emit.ml tests/test_beloch.ml
git commit -m "feat(emit): dual creasePattern + foldedForm output from the face set

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Switch `fold_string` over, re-baseline, fold examples

Rewire `beloch.ml` to the folded path, remove the old `Eval.eval` / `Fold_emit.to_json` and their now-redundant tests, re-baseline the e2e assertions, and add `@`-fold examples + end-to-end fold tests.

**Files:**
- Modify: `lib/beloch.ml`, `lib/eval.ml`, `lib/fold_emit.ml`
- Create: `examples/fold-half.bel`, `examples/fold-quarter.bel`
- Modify: `tests/test_beloch.ml`

**Interfaces:**
- Consumes: `Eval.eval_folded`, `Fold_emit.to_json_folded`.
- Produces: `Beloch.fold_string` now emits the dual-frame folded output for every program.

- [ ] **Step 1: Rewire `lib/beloch.ml`**

Replace the body of `fold_string`:

```ocaml
let fold_string ~(filename : string) (src : string) : Yojson.Safe.t =
  let st = parse ~filename src |> Eval.eval |> Planarize.run in
  Fold_emit.to_json st (Faces.extract st)
```

with:

```ocaml
let fold_string ~(filename : string) (src : string) : Yojson.Safe.t =
  parse ~filename src |> Eval.eval_folded |> Fold_emit.to_json_folded
```

- [ ] **Step 2: Remove the old `Eval.eval` and `Fold_emit.to_json`**

In `lib/eval.ml`, delete the old `eval : Ast.program -> crease list` function and the `crease` type if now unused (the folded path uses neither). In `lib/fold_emit.ml`, delete the old `to_json : State.t -> int array list -> Yojson.Safe.t`. Leave `Planarize`, `Faces`, and `State` modules and `q_to_json` intact (still referenced by `Fold_emit` and their own unit tests).

- [ ] **Step 3: Delete the now-orphaned tests in `tests/test_beloch.ml`**

These exercised the removed crease-list `eval`/`to_json` path. Delete the functions **and** their `Alcotest.test_case` lines in the runner list:
- `test_eval_counts_creases`, `test_eval_cross_ok`, `test_eval_perp_provenance`, `test_eval_crease_name`, `test_eval_bisect_select` (these inspect `Eval.crease`/`prov` from the removed `eval`).
- `test_emit_fields`, `test_emit_crease_name` (call the removed `Fold_emit.to_json` with `Planarize.run`/`Faces.extract`).
- The `eval_src` helper (`Eval.eval (...)`) is now unused — delete it and convert the error tests below to `eval_folded`.

Keep and convert the eval **error** tests to `eval_folded` (same expected messages):
- `test_eval_identical_points`: `expect_error "distinct" (fun () -> ignore (Eval.eval_folded (Beloch.parse ~filename:"t.bel" "paper square\nthrough .a .a\n")))`
- `test_eval_undefined_point`: source `"paper square\nmap .a onto .z\n"`, `expect_error "undefined"`
- `test_eval_parallel_cross`: source `"paper square\n--h1: through .a .b\n--h2: through .d .c\n.x: cross --h1 --h2\n"`, `expect_error "parallel"`
- `test_eval_bisect_errors`: keep the three sources (already `map …`), wrap each in `ignore (Eval.eval_folded (Beloch.parse …))` instead of `eval_src`.

Keep `test_planarize_*`, `test_faces_*` (they test `Planarize`/`Faces` directly, still present), and `test_e2e_*` (re-baselined in Step 5).

- [ ] **Step 4: Build to confirm the old path is gone and the new path compiles**

Run: `dune fmt 2>&1; dune build 2>&1`
Expected: build clean. If `Eval.crease`/`eval`/`to_json` are referenced anywhere remaining, the build names the site — convert or delete it.

- [ ] **Step 5: Re-baseline the e2e assertions**

The e2e tests call `Beloch.fold_string` and read top-level fields (frame 0 = `creasePattern`), which the new path still provides with the same geometry for precrease-only programs. Run `dune test 2>&1` and, for each failing e2e assertion, inspect the new value and update the literal if it is the geometrically-equivalent new output (same faces/edges, possibly different vertex/edge ordering). Specifically:
- `test_e2e_diagonals` (5 vertices, 8 edges), `test_e2e_square_one_face` (1 face, 4 verts), `test_e2e_diagonals_four_faces` (4 faces), `test_e2e_perp` (4 faces + an `axiom3` in `beloch:edges`), `test_e2e_bisect_select`, `test_e2e_bisect_parallel` (2 faces): confirm counts match; the face/vertex **counts** are invariant under the path change, so these should pass as-is. If an ordering-sensitive assertion (e.g. `Yojson.Safe.equal` on `vertices_coords`) fails, replace it with a count/membership check that captures the same intent.
- `test_e2e_anti_parallel` (`expect_error "parallel"`) and `test_e2e_anti_dup` (`expect_error "distinct"`): unchanged — errors still raised by `eval_folded`.

- [ ] **Step 6: Add `@`-fold examples**

Create `examples/fold-half.bel`:

```
; status: works — fold the right half onto the left (valley), one crease
paper square
@map .b onto .a moving .b
```

Create `examples/fold-quarter.bel`:

```
; status: works — fold to a quarter; the second fold accordions across two layers
paper square
@map .b onto .a moving .b
@map .d onto .a moving .d
```

- [ ] **Step 7: Add end-to-end fold tests**

Add to `tests/test_beloch.ml`:

```ocaml
let test_e2e_fold_half () =
  let json = Beloch.fold_string ~filename:"fold-half.bel" (read_example "fold-half.bel") in
  let open Yojson.Safe.Util in
  Alcotest.(check string) "frame 0 creasePattern" "creasePattern"
    (json |> member "frame_classes" |> to_list |> List.hd |> to_string);
  Alcotest.(check int) "a foldedForm frame is present" 1
    (json |> member "file_frames" |> to_list |> List.length);
  let assigns = json |> member "edges_assignment" |> to_list |> List.map to_string in
  Alcotest.(check bool) "the fold crease is a valley" true (List.mem "V" assigns)

let test_e2e_fold_quarter () =
  let json = Beloch.fold_string ~filename:"fold-quarter.bel" (read_example "fold-quarter.bel") in
  let open Yojson.Safe.Util in
  let folded = json |> member "file_frames" |> to_list |> List.hd in
  (* four layers -> overlapping pairs -> several faceOrders triples *)
  Alcotest.(check bool) "faceOrders present for the folded stack" true
    (List.length (folded |> member "faceOrders" |> to_list) > 0);
  let assigns = json |> member "edges_assignment" |> to_list |> List.map to_string in
  Alcotest.(check bool) "accordion produced a mountain crease" true (List.mem "M" assigns)
```

Register in the `"e2e"` group:

```ocaml
         Alcotest.test_case "fold half end-to-end" `Quick test_e2e_fold_half;
         Alcotest.test_case "fold quarter accordion" `Quick test_e2e_fold_quarter;
```

- [ ] **Step 8: Add the B-1 carryover tests**

Add to `tests/test_beloch.ml` (in the `"isometry"` and `"fold_clip"` groups respectively):

```ocaml
let test_isometry_inverse_rotation () =
  (* compose two distinct reflections -> a rotation (det +1, not self-inverse);
     inverse must still undo it *)
  let r1 = Isometry.reflect_across_line { Geom.a = q 1; b = q 0; c = half } in
  let r2 = Isometry.reflect_across_line { Geom.a = q 0; b = q 1; c = half } in
  let rot = Isometry.compose r1 r2 in
  let inv = Isometry.inverse rot in
  Alcotest.(check int) "composed reflections give a rotation" 1 (Isometry.det_sign rot);
  Alcotest.(check bool) "inverse undoes the rotation" true
    (Geom.point_equal (Isometry.apply_point inv (Isometry.apply_point rot (pt 3 5))) (pt 3 5))

let test_clip_on_vertex () =
  (* clip the unit square by its own diagonal a-c (x = y): the line passes
     exactly through two vertices; each half is a triangle of 3 vertices *)
  let sq = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  let diag = Geom.line_through (pt 0 0) (pt 1 1) in
  Alcotest.(check int) "lower triangle has 3 vertices" 3
    (Array.length (Geom.clip_convex_halfplane diag 1 sq));
  Alcotest.(check int) "upper triangle has 3 vertices" 3
    (Array.length (Geom.clip_convex_halfplane diag (-1) sq))
```

Register them:

```ocaml
         Alcotest.test_case "inverse of a rotation" `Quick test_isometry_inverse_rotation;
```
```ocaml
         Alcotest.test_case "clip through vertices" `Quick test_clip_on_vertex;
```

- [ ] **Step 9: Format, build, full test run**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: all tests PASS, build clean.

- [ ] **Step 10: Commit**

```bash
git add lib/beloch.ml lib/eval.ml lib/fold_emit.ml examples tests/test_beloch.ml
git commit -m "feat(fold): execute @ folds, emit dual creasePattern + foldedForm

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage** (against `2026-06-29-fold-evaluator-output-design.md`):
- Unified face-based pipeline (decision C) → Task 2 (`eval_folded` always threads `Fold_state`) + Task 4 (rewire, old path removed).
- Reference resolution against current state; `moving` defaults/errors; Q2-A `cross` single-face rule → Task 2.
- Dual output, both frames from faces; M/V via `on_segment` record lookup; `faceOrders` via `convex_overlap` with the foldformat sign → Task 3.
- Provenance / crease names preserved → Task 1 (record `prov`) + Task 3 (`beloch:edges`).
- Regression re-baseline → Task 4 Steps 3, 5.
- Fold e2e (half/quarter/accordion/mountain) → Task 4 Steps 6–7; B-1 carryover (rotation inverse, on-vertex clip) → Task 4 Step 8. (The quarter-fold also exercises depth-2 CW-table clipping, the third carryover item.)

**Placeholder scan:** none — every code step shows full bodies; the re-baseline step (Task 4 Step 5) names each affected test and the invariant (counts unchanged) rather than leaving it open.

**Type consistency:** `Eval.folded = { state; creases }` defined in Task 2, consumed in Task 3 and Task 4. `Fold_state.crease_record` gains `prov` in Task 1, read in Task 3. `subdivide`/`fold_with_records` take `~prov` from Task 1, called with `~prov` in Task 2. `Fold_emit.to_json_folded : Eval.folded -> json` defined Task 3, called Task 4. `faceOrders` sign `if (fi > gi) = g_up then 1 else -1` matches the foldformat rule stated in Global Constraints.
