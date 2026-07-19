# Incremental Evaluation Cache — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cache evaluation results per statement so an edit or append recomputes only the changed suffix, making the Playground (and CLI) interactive.

**Architecture:** A `Session.t` memoizes `ctx` snapshots along a hash-chained statement spine. `eval_folded` is parameterized into `eval_program ?resume ?on_step` (the 2415 lines of statement logic stay put; only the enclosing loop changes). Snapshot/restore operate in place on the single root scope so the `root_scope` binding that `finalize` reads stays valid. No serialization — everything is in-memory (Phase 2 `.beli` is a separate spec).

**Tech Stack:** OCaml, dune, alcotest, `Digest` (stdlib MD5), `Yojson`. js_of_ocaml for the Playground worker.

## Global Constraints

- Engine lives in `lib/` (core library `beloch`), so both Playground and CLI use it. Copied verbatim from the design spec.
- Correctness net: `Session.eval` must produce **byte-identical** FOLD JSON to `Eval.eval_folded` for every program, whether run fresh or resumed. This is because crease ids are restored via the `next_id` counter.
- The only global mutable state is `Fold_state.next_id`; a snapshot must capture and a restore must reset it.
- Snapshots are taken at top-level statement boundaries, where `ctx.scopes` is exactly `[root_scope]` (`apply` pushes/pops scopes but returns to the root between top-level statements). Snapshot/restore assert this.
- Deep-copy the inner `instance` hashtables on both snapshot and restore; alias-sharing them would let a later `apply` corrupt a stored snapshot.
- Reference spec: `docs/superpowers/specs/2026-07-19-incremental-eval-cache-design.md`.

---

## File Structure

- **`lib/fold_state.ml` / `.mli`** — expose `next_id_value` / `set_next_id` (Task 1).
- **`lib/spine.ml`** (new) — canonical per-statement hashing + the hash chain (Task 2).
- **`lib/eval.ml`** — add `snapshot`/`restore` + parameterize `eval_folded` into `eval_program` (Task 3).
- **`lib/session.ml`** (new) — the memoizing session (Task 4).
- **`lib/beloch.ml`** — re-export `Spine` (Task 2) and `Session` (Task 4).
- **`web/beloch_web.ml`** — hold a persistent `Session.t` (Task 5).
- **`bin/main.ml`** — `beloch fold --watch` (Task 6).
- **Tests:** `tests/test_spine.ml`, `tests/test_session.ml` (new); `tests/test_fold_state.ml` (extend); `tests/dune` (register new tests).

---

### Task 1: Expose the id counter in `Fold_state`

**Files:**
- Modify: `lib/fold_state.ml:53-54`
- Modify: `lib/fold_state.mli:128` (near `val reset_ids`)
- Test: `tests/test_fold_state.ml`

**Interfaces:**
- Produces: `val Fold_state.next_id_value : unit -> int`, `val Fold_state.set_next_id : int -> unit`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_fold_state.ml` (a new test function; register it in that file's `Alcotest.run` list under an existing or new suite):

```ocaml
let test_next_id_roundtrip () =
  Fold_state.reset_ids ();
  Alcotest.(check int) "starts at 0" 0 (Fold_state.next_id_value ());
  let _ = Fold_state.fresh_crease_id () in
  let _ = Fold_state.fresh_crease_id () in
  Alcotest.(check int) "advanced to 2" 2 (Fold_state.next_id_value ());
  Fold_state.set_next_id 7;
  Alcotest.(check int) "set to 7" 7 (Fold_state.next_id_value ());
  Alcotest.(check int) "next alloc is 7" 7 (Fold_state.fresh_crease_id ())
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dune test 2>&1 | head -30`
Expected: FAIL — `Unbound value Fold_state.next_id_value`.

- [ ] **Step 3: Write minimal implementation**

In `lib/fold_state.ml`, right after `let reset_ids () = next_id := 0` (line 54):

```ocaml
let next_id_value () = !next_id
let set_next_id n = next_id := n
```

In `lib/fold_state.mli`, right after `val reset_ids : unit -> unit`:

```ocaml
(** [next_id_value ()] / [set_next_id n] — snapshot and restore the global
    crease-id counter, for the incremental evaluation cache (see
    [Session]). Ids are a deterministic function of the program prefix, so
    restoring the counter reproduces identical ids on resume. *)
val next_id_value : unit -> int
val set_next_id : int -> unit
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dune test 2>&1 | tail -20`
Expected: PASS (test_fold_state suite green).

- [ ] **Step 5: Commit**

```bash
git add lib/fold_state.ml lib/fold_state.mli tests/test_fold_state.ml
git commit -m "feat(fold-state): expose next_id get/set for eval cache"
```

---

### Task 2: Statement canonicalization + hash chain (`Spine`)

**Files:**
- Create: `lib/spine.ml`
- Modify: `lib/beloch.ml:44` (add re-export)
- Create test: `tests/test_spine.ml`
- Modify: `tests/dune`

**Interfaces:**
- Consumes: `Ast.stmt`, `Ast.program`, `Error.span` (= `Lexing.position * Lexing.position`).
- Produces:
  - `val Spine.canon_stmt : string -> Ast.stmt -> string`
  - `val Spine.chain_keys : string -> Ast.program -> string list` (one hex key per statement; running MD5 chain over the source, prefix-stable)

- [ ] **Step 1: Write the failing test**

Create `tests/test_spine.ml`:

```ocaml
open Beloch

let parse src = Beloch.parse ~filename:"t.bel" src

let keys src = Spine.chain_keys src (parse src)

let test_whitespace_insensitive () =
  let a = keys "paper square\nmark through .a .c\n" in
  let b = keys "paper square\n\n  mark   through .a .c\n" in
  Alcotest.(check (list string)) "cosmetic edits do not bust" a b

let test_append_keeps_prefix () =
  let a = keys "paper square\nfold through .a .c\n" in
  let b = keys "paper square\nfold through .a .c\nfold through .b .d\n" in
  (* every key of [a] is a prefix of [b] *)
  List.iteri
    (fun i k -> Alcotest.(check string) (Printf.sprintf "key %d stable" i) k (List.nth b i))
    a;
  Alcotest.(check int) "b has one more key" (List.length a + 1) (List.length b)

(* NOTE: `paper square` is the mandatory program HEADER (parser rule
   `program: PAPER SQUARE stmts EOF`), NOT an Ast.stmt — so `chain_keys`
   returns exactly one key per statement (here: per `fold`), seeded by the
   header. Editing the header changes the seed and busts every key. To show a
   STABLE prefix we need ≥3 statements with a shared first one. *)
let test_edit_invalidates_suffix () =
  let a =
    keys "paper square\nfold through .a .c\nfold through .b .d\nfold through .a .b\n"
  in
  let b =
    keys "paper square\nfold through .a .c\nfold through .b .c\nfold through .a .b\n"
  in
  Alcotest.(check int) "3 statements -> 3 keys" 3 (List.length a);
  Alcotest.(check string) "key 0 stable (first stmt unchanged)" (List.nth a 0) (List.nth b 0);
  Alcotest.(check bool) "key 1 changed" true (List.nth a 1 <> List.nth b 1);
  Alcotest.(check bool) "key 2 changed (chained)" true (List.nth a 2 <> List.nth b 2)

let () =
  Alcotest.run "spine"
    [ ( "chain",
        [ Alcotest.test_case "whitespace-insensitive" `Quick test_whitespace_insensitive;
          Alcotest.test_case "append-keeps-prefix" `Quick test_append_keeps_prefix;
          Alcotest.test_case "edit-invalidates-suffix" `Quick test_edit_invalidates_suffix ] ) ]
```

Add to `tests/dune`:

```
(test
 (name test_spine)
 (libraries beloch alcotest str))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dune test 2>&1 | head -30`
Expected: FAIL — `Unbound module Spine` (or `Unbound value Spine.chain_keys`).

- [ ] **Step 3: Write minimal implementation**

Create `lib/spine.ml`:

```ocaml
(** Per-statement hash chain for the incremental evaluation cache.

    Each statement gets a key that folds in every key before it, so the
    key at index [i] is a hash of statements [0..i]. Appending a statement
    leaves all earlier keys unchanged (full prefix reuse); editing statement
    [k] changes [k] and every key after it. See [Session]. *)

(* All [Ast.stmt] variants carry their [Error.span] as the last field. *)
let span_of_stmt : Ast.stmt -> Error.span = function
  | Ast.BindLine (_, _, sp)
  | Ast.Mark (_, _, _, _, _, sp)
  | Ast.Fold (_, _, _, sp)
  | Ast.BindBundle (_, _, sp)
  | Ast.Point (_, _, sp)
  | Ast.Flip sp
  | Ast.Def (_, _, _, sp)
  | Ast.Apply (_, _, _, sp)
  | Ast.Export (_, _, sp)
  | Ast.StepMark (_, sp)
  | Ast.Flatten (_, _, _, _, _, sp) -> sp

(* collapse every run of whitespace to a single space and trim — so
   reindentation / line breaks inside a statement do not change the key. *)
let normalize_ws (s : string) : string =
  let b = Buffer.create (String.length s) in
  let in_ws = ref true in
  String.iter
    (fun c ->
      if c = ' ' || c = '\t' || c = '\n' || c = '\r' then begin
        if not !in_ws then (Buffer.add_char b ' '; in_ws := true)
      end
      else (Buffer.add_char b c; in_ws := false))
    s;
  let r = Buffer.contents b in
  let n = String.length r in
  if n > 0 && r.[n - 1] = ' ' then String.sub r 0 (n - 1) else r

let canon_stmt (src : string) (stmt : Ast.stmt) : string =
  let start, stop = span_of_stmt stmt in
  let a = start.Lexing.pos_cnum in
  let b = stop.Lexing.pos_cnum in
  (* pos_cnum are byte offsets into [src]; clamp defensively *)
  let a = if a < 0 then 0 else a in
  let b = if b > String.length src then String.length src else b in
  let slice = if b > a then String.sub src a (b - a) else "" in
  normalize_ws slice

(* `paper square` is the program header, not a statement, so it never appears
   in [prog]. Seed the chain with the normalized source PREFIX before the first
   statement (the header + any leading trivia): editing it changes the seed and
   invalidates every key, while the returned list stays exactly one key per
   Ast.stmt — so keys align 1:1 with statements (and with [Session]'s
   per-statement snapshots). *)
let chain_keys (src : string) (prog : Ast.program) : string list =
  let first_start =
    match prog with
    | [] -> String.length src
    | stmt :: _ -> (fst (span_of_stmt stmt)).Lexing.pos_cnum
  in
  let first_start =
    if first_start < 0 then 0
    else if first_start > String.length src then String.length src
    else first_start
  in
  let prelude = normalize_ws (String.sub src 0 first_start) in
  let seed = Digest.to_hex (Digest.string ("prelude\x00" ^ prelude)) in
  let rec go prev acc = function
    | [] -> List.rev acc
    | stmt :: rest ->
        let key =
          Digest.to_hex (Digest.string (prev ^ "\x00" ^ canon_stmt src stmt))
        in
        go key (key :: acc) rest
  in
  go seed [] prog
```

Add the re-export to `lib/beloch.ml` (after line 44 `module Field_merge = Field_merge`):

```ocaml
module Spine = Spine
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dune test 2>&1 | tail -20`
Expected: PASS (spine suite green).

- [ ] **Step 5: Commit**

```bash
git add lib/spine.ml lib/beloch.ml tests/test_spine.ml tests/dune
git commit -m "feat(cache): Spine — prefix-stable per-statement hash chain"
```

---

### Task 3: `snapshot` / `restore` + `eval_program` in `Eval`

**Files:**
- Modify: `lib/eval.ml` (add types/functions before `eval_folded` at line 182; refactor `eval_folded`)
- Test: `tests/test_eval.ml`

**Interfaces:**
- Consumes: the existing top-level types `ctx`, `scope`, `instance`, `crease_val`, `folded`, and `Fold_state.next_id_value`/`set_next_id` (Task 1).
- Produces:
  - `type Eval.snapshot`
  - `val Eval.snapshot : ctx -> snapshot`
  - `val Eval.restore : ctx -> snapshot -> unit`
  - `val Eval.eval_program : ?resume:snapshot -> ?on_step:(ctx -> unit) -> Ast.program -> folded`
  - `val Eval.eval_folded : Ast.program -> folded` (unchanged signature; now `= eval_program`)

Note: `eval.ml` has no `.mli`, so all top-level bindings are exposed automatically. `Eval` is already re-exported from `beloch.ml:36`.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_eval.ml`:

```ocaml
let fold_str prog =
  Yojson.Safe.to_string (Fold_emit.to_json_folded prog)

(* grab the snapshot taken right after statement [n] (1-based) of [prog] *)
let snap_after n prog =
  let snap = ref None and i = ref 0 in
  let on_step ctx =
    incr i;
    if !i = n then snap := Some (Eval.snapshot ctx)
  in
  ignore (Eval.eval_program ~on_step prog);
  Option.get !snap

(* Use `mark` statements: they subdivide the arrangement (a real per-step state
   change → a snapshot per step) but never need `moving .p` and never throw, so
   the program evaluates cleanly. `paper square` is the header, so this is a
   3-statement program. *)
let test_resume_equals_full () =
  let src =
    "paper square\nmark through .a .c\nmark through .b .d\nmark map .a onto .b\n"
  in
  let prog = Beloch.parse ~filename:"t.bel" src in
  let full = fold_str (Eval.eval_folded prog) in
  (* resume after statement 2 (index 1), replay statement 3 (index 2) *)
  let resume = snap_after 2 prog in
  let suffix = List.filteri (fun i _ -> i >= 2) prog in
  let resumed = fold_str (Eval.eval_program ~resume suffix) in
  Alcotest.(check string) "resumed FOLD == full FOLD" full resumed
```

Register `test_resume_equals_full` in `test_eval.ml`'s `Alcotest.run` list (append an `Alcotest.test_case` to an existing suite group). Ensure `tests/dune`'s `test_eval` stanza already lists `yojson` — it does **not**; add it:

```
(test
 (name test_eval)
 (libraries beloch alcotest yojson zarith str))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dune test 2>&1 | head -30`
Expected: FAIL — `Unbound value Eval.eval_program` / `Eval.snapshot`.

- [ ] **Step 3: Write minimal implementation**

In `lib/eval.ml`, immediately before `let eval_folded` (line 182), add the snapshot type and functions:

```ocaml
(* ---- Incremental checkpoint: snapshot / restore of the whole ctx ---- *)

type snapshot = {
  s_points : (string, Geom.point) Hashtbl.t;
  s_lines : (string, crease_val) Hashtbl.t;
  s_instances : (string, instance) Hashtbl.t;
  s_point_steps : (string, int) Hashtbl.t;
  s_line_steps : (string, int) Hashtbl.t;
  s_defs : (string, int * Ast.param list * Ast.stmt list) Hashtbl.t;
  s_name_ctx : name_ctx;
  s_cur_def_idx : int option;
  s_next_def_idx : int;
  s_panel : string option;
  s_panels : (string, unit) Hashtbl.t;
  s_frames_rev : (string option * Fold_state.t * Error.span option) list;
  s_pending : bool;
  s_state : Fold_state.t;
  s_next_id : int;
}

let copy_instance (i : instance) : instance = {
  ipoints = Hashtbl.copy i.ipoints;
  ilines = Hashtbl.copy i.ilines;
  ipoint_steps = Hashtbl.copy i.ipoint_steps;
  iline_steps = Hashtbl.copy i.iline_steps;
}

let copy_instances (tbl : (string, instance) Hashtbl.t) =
  let t = Hashtbl.create (Hashtbl.length tbl) in
  Hashtbl.iter (fun k v -> Hashtbl.replace t k (copy_instance v)) tbl;
  t

(* Snapshots are taken between top-level statements, where [ctx.scopes] is a
   single root scope. Hashtable values (points, crease_vals, AST fragments)
   are immutable, so a shallow copy suffices — except [instance]s, whose inner
   tables are mutable and must be deep-copied. *)
let snapshot (ctx : ctx) : snapshot =
  match ctx.scopes with
  | [ root ] ->
      {
        s_points = Hashtbl.copy root.points;
        s_lines = Hashtbl.copy root.lines;
        s_instances = copy_instances root.instances;
        s_point_steps = Hashtbl.copy root.point_steps;
        s_line_steps = Hashtbl.copy root.line_steps;
        s_defs = Hashtbl.copy ctx.defs;
        s_name_ctx = ctx.name_ctx;
        s_cur_def_idx = ctx.cur_def_idx;
        s_next_def_idx = ctx.next_def_idx;
        s_panel = ctx.panel;
        s_panels = Hashtbl.copy ctx.panels;
        s_frames_rev = ctx.frames_rev;
        s_pending = ctx.pending;
        s_state = !(ctx.state);
        s_next_id = Fold_state.next_id_value ();
      }
  | _ -> failwith "Eval.snapshot: expected a single root scope at a statement boundary"

let restore_tbl dst src =
  Hashtbl.reset dst;
  Hashtbl.iter (fun k v -> Hashtbl.replace dst k v) src

(* Restore writes back INTO the existing root-scope tables (not fresh records),
   so the [root_scope] binding [eval_folded]'s finalize reads stays valid.
   Instances are deep-copied so re-using a snapshot across several edits can't
   let a later [apply] mutate the stored one. *)
let restore (ctx : ctx) (s : snapshot) : unit =
  match ctx.scopes with
  | [ root ] ->
      restore_tbl root.points s.s_points;
      restore_tbl root.lines s.s_lines;
      Hashtbl.reset root.instances;
      Hashtbl.iter
        (fun k v -> Hashtbl.replace root.instances k (copy_instance v))
        s.s_instances;
      restore_tbl root.point_steps s.s_point_steps;
      restore_tbl root.line_steps s.s_line_steps;
      restore_tbl ctx.defs s.s_defs;
      ctx.name_ctx <- s.s_name_ctx;
      ctx.cur_def_idx <- s.s_cur_def_idx;
      ctx.next_def_idx <- s.s_next_def_idx;
      ctx.panel <- s.s_panel;
      restore_tbl ctx.panels s.s_panels;
      ctx.frames_rev <- s.s_frames_rev;
      ctx.pending <- s.s_pending;
      ctx.state := s.s_state;
      Fold_state.set_next_id s.s_next_id
  | _ -> failwith "Eval.restore: expected a single root scope at a statement boundary"
```

Now rename `eval_folded` to `eval_program` and parameterize it. Change the header (line 182) from:

```ocaml
let eval_folded (prog : Ast.program) : folded =
  Fold_state.reset_ids ();
```

to:

```ocaml
let eval_program ?(resume : snapshot option) ?(on_step : ctx -> unit = fun _ -> ())
    (prog : Ast.program) : folded =
  (match resume with None -> Fold_state.reset_ids () | Some _ -> ());
```

Then insert the restore just before the driver loop. Change (line 2359):

```ocaml
  List.iter eval_stmt prog;
```

to:

```ocaml
  (match resume with Some s -> restore ctx s | None -> ());
  List.iter (fun stmt -> eval_stmt stmt; on_step ctx) prog;
```

Finally, add the backward-compatible wrapper immediately after `eval_program` returns (after line 2415, the closing `{ state = ...; ... }` and its enclosing `let`):

```ocaml
let eval_folded (prog : Ast.program) : folded = eval_program prog
```

(`Beloch.fold_string` at `beloch.ml:24` keeps calling `Eval.eval_folded` unchanged.)

- [ ] **Step 4: Run test to verify it passes**

Run: `dune test 2>&1 | tail -30`
Expected: PASS — `test_resume_equals_full` green, and the full existing suite still green (goldens unchanged, since `eval_folded = eval_program` with no resume).

- [ ] **Step 5: Commit**

```bash
git add lib/eval.ml tests/test_eval.ml tests/dune
git commit -m "feat(eval): ctx snapshot/restore + resumable eval_program"
```

---

### Task 4: The memoizing `Session`

**Files:**
- Create: `lib/session.ml`
- Modify: `lib/beloch.ml` (add `module Session = Session`)
- Create test: `tests/test_session.ml`
- Modify: `tests/dune`

**Interfaces:**
- Consumes: `Spine.chain_keys` (Task 2), `Eval.snapshot`/`restore`/`eval_program` (Task 3), `Beloch.parse`.
- Produces:
  - `type Session.t`
  - `val Session.create : unit -> t`
  - `val Session.eval : t -> filename:string -> string -> Eval.folded`
  - `val Session.last_ran : t -> int` (statements recomputed on the last `eval`; for tests/telemetry)

- [ ] **Step 1: Write the failing test**

Create `tests/test_session.ml`:

```ocaml
open Beloch

let fold_str f = Yojson.Safe.to_string (Fold_emit.to_json_folded f)

let full src =
  fold_str (Eval.eval_folded (Beloch.parse ~filename:"t.bel" src))

(* `mark` statements evaluate cleanly (subdivide, no `moving .p`, never throw).
   `paper square` is the header, not a statement, so an N-mark program has N
   statements and N keys — the counts below reflect that. *)

let test_equivalence () =
  let s = Session.create () in
  let src = "paper square\nmark through .a .c\nmark through .b .d\n" in
  let got = fold_str (Session.eval s ~filename:"t.bel" src) in
  Alcotest.(check string) "session == eval_folded" (full src) got

let test_append_recomputes_one () =
  let s = Session.create () in
  let a = "paper square\nmark through .a .c\n" in
  let b = "paper square\nmark through .a .c\nmark through .b .d\n" in
  ignore (Session.eval s ~filename:"t.bel" a);
  ignore (Session.eval s ~filename:"t.bel" b);
  Alcotest.(check int) "only the appended statement ran" 1 (Session.last_ran s)

let test_edit_invalidates_from_k () =
  let s = Session.create () in
  (* 3 statements; edit the 2nd — statement 1 is reused, 2 and 3 recomputed *)
  let a =
    "paper square\nmark through .a .c\nmark through .b .d\nmark map .a onto .b\n"
  in
  let b =
    "paper square\nmark through .a .c\nmark map .a onto .d\nmark map .a onto .b\n"
  in
  ignore (Session.eval s ~filename:"t.bel" a);
  ignore (Session.eval s ~filename:"t.bel" b);
  Alcotest.(check int) "recomputed 2 of 3" 2 (Session.last_ran s);
  (* and the result still equals a cold eval *)
  Alcotest.(check string) "edited result correct" (full b)
    (fold_str (Session.eval (Session.create ()) ~filename:"t.bel" b))

let test_unchanged_reuses_all () =
  let s = Session.create () in
  let src = "paper square\nmark through .a .c\nmark through .b .d\n" in
  ignore (Session.eval s ~filename:"t.bel" src);
  ignore (Session.eval s ~filename:"t.bel" src);
  Alcotest.(check int) "nothing recomputed on identical re-eval" 0 (Session.last_ran s)

let () =
  Alcotest.run "session"
    [ ( "incremental",
        [ Alcotest.test_case "equivalence" `Quick test_equivalence;
          Alcotest.test_case "append-recomputes-one" `Quick test_append_recomputes_one;
          Alcotest.test_case "edit-invalidates-from-k" `Quick test_edit_invalidates_from_k;
          Alcotest.test_case "unchanged-reuses-all" `Quick test_unchanged_reuses_all ] ) ]
```

Add to `tests/dune`:

```
(test
 (name test_session)
 (libraries beloch alcotest yojson zarith str))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dune test 2>&1 | head -30`
Expected: FAIL — `Unbound module Session`.

- [ ] **Step 3: Write minimal implementation**

Create `lib/session.ml`:

```ocaml
(** Incremental evaluation session. Memoizes one [Eval.snapshot] per statement
    along [Spine]'s prefix-stable hash chain: on re-eval, the longest matching
    key prefix is reused and only the divergent suffix is recomputed.

    In-memory only (Phase 1). See
    docs/superpowers/specs/2026-07-19-incremental-eval-cache-design.md. *)

type t = {
  mutable keys : string array;        (* one hash-chain key per statement *)
  mutable snaps : Eval.snapshot array; (* snapshot taken AFTER each statement *)
  mutable last_ran : int;             (* statements recomputed on the last eval *)
}

let create () = { keys = [||]; snaps = [||]; last_ran = 0 }
let last_ran t = t.last_ran

let eval (t : t) ~(filename : string) (src : string) : Eval.folded =
  let prog = Beloch.parse ~filename src in
  let new_keys = Array.of_list (Spine.chain_keys src prog) in
  (* longest common prefix of the old and new key chains *)
  let n = Array.length new_keys in
  let prefix = ref 0 in
  while
    !prefix < n
    && !prefix < Array.length t.keys
    && String.equal new_keys.(!prefix) t.keys.(!prefix)
  do
    incr prefix
  done;
  let prefix = !prefix in
  let resume = if prefix = 0 then None else Some t.snaps.(prefix - 1) in
  let suffix = List.filteri (fun i _ -> i >= prefix) prog in
  (* collect one snapshot per suffix statement, in order *)
  let collected = ref [] in
  let on_step ctx = collected := Eval.snapshot ctx :: !collected in
  let folded = Eval.eval_program ?resume ~on_step suffix in
  let suffix_snaps = Array.of_list (List.rev !collected) in
  t.keys <- new_keys;
  t.snaps <- Array.append (Array.sub t.snaps 0 prefix) suffix_snaps;
  t.last_ran <- n - prefix;
  folded
```

Add the re-export to `lib/beloch.ml` (after the `module Spine = Spine` line from Task 2):

```ocaml
module Session = Session
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dune test 2>&1 | tail -30`
Expected: PASS — all four session tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/session.ml lib/beloch.ml tests/test_session.ml tests/dune
git commit -m "feat(cache): Session — spine-memoized incremental eval"
```

---

### Task 5: Wire the Playground to a persistent `Session`

**Files:**
- Modify: `web/beloch_web.ml:23-49`

**Interfaces:**
- Consumes: `Session.create`/`Session.eval` (Task 4), `Fold_emit.to_json_folded`.

- [ ] **Step 1: Write the failing test**

No unit test (js_of_ocaml entry). Verification is a native compile + a behavioral check at Step 4. First, make the change fail-visibly by confirming the current build is green:

Run: `dune build web/beloch_web.bc.js 2>&1 | tail -5`
Expected: builds clean (baseline).

- [ ] **Step 2: (n/a — no failing unit test for the JS entry)**

- [ ] **Step 3: Write the implementation**

In `web/beloch_web.ml`, add a module-level session above `fold_string_js` (after line 21):

```ocaml
(* One long-lived session per worker: successive edits reuse the unchanged
   statement prefix and recompute only the divergent suffix. *)
let session = Beloch.Session.create ()
```

Then replace the success branch (line 28) inside `fold_string_js`:

```ocaml
      let fold = Beloch.fold_string ~filename:"playground" src in
      `Assoc [ ("ok", `Bool true); ("fold", fold) ]
```

with:

```ocaml
      let folded = Beloch.Session.eval session ~filename:"playground" src in
      let fold = Beloch.Fold_emit.to_json_folded folded in
      `Assoc [ ("ok", `Bool true); ("fold", fold) ]
```

Leave the `Failure` (native-fallback), `Beloch_error`, and catch-all branches unchanged.

- [ ] **Step 4: Verify — build + behavioral parity**

Build the jsoo bundle:

Run: `dune build web/beloch_web.bc.js 2>&1 | tail -5`
Expected: builds clean.

Confirm session parity natively (a rational program the jsoo path handles), proving `Session.eval` matches the old `fold_string` output that the worker used to emit:

```bash
dune exec bin/main.exe -- fold examples/... 2>/dev/null | head -3   # sanity: CLI still folds
dune test 2>&1 | tail -5                                            # test_session equivalence covers parity
```

Expected: CLI folds; `test_session` equivalence already asserts `Session.eval == eval_folded`, which is exactly the FOLD JSON the worker emits.

Note: rebuilding the deployed `site/public/beloch/beloch-eval.js` is a separate manual step (`site/scripts/build-eval.sh`) and is out of scope for this task — flag it in the PR so the Playground picks up the change.

- [ ] **Step 5: Commit**

```bash
git add web/beloch_web.ml
git commit -m "feat(web): persistent Session for incremental Playground eval"
```

---

### Task 6: CLI `beloch fold --watch`

**Files:**
- Modify: `bin/main.ml` (the `fold` subcommand — `run_fold`/`eval_bel_file` around line 39, dispatch at 133)

**Interfaces:**
- Consumes: `Session.create`/`Session.eval`, `Fold_emit.to_json_folded`. Uses `Unix.stat`/`Unix.sleep` (add `unix` to the executable's libraries if absent).

- [ ] **Step 1: Confirm current behavior (baseline)**

Run: `dune exec bin/main.exe -- fold --help 2>&1 | head` (or inspect `run_fold`)
Expected: `--watch` not yet a recognized flag.

- [ ] **Step 2: Read the current `run_fold` / arg parsing**

Read `bin/main.ml:30-140` to see how `fold` parses its file argument and prints JSON, and how flags are threaded. Match that style exactly.

- [ ] **Step 3: Implement `--watch`**

Add a `--watch` branch to the `fold` subcommand. When set, keep one `Session.t` and re-fold on file-mtime change (poll; no new dependency beyond `unix`):

```ocaml
let run_fold_watch (path : string) : unit =
  let session = Beloch.Session.create () in
  let last_mtime = ref 0.0 in
  let fold_once () =
    let src = In_channel.with_open_text path In_channel.input_all in
    match Beloch.Session.eval session ~filename:path src with
    | folded ->
        let json = Beloch.Fold_emit.to_json_folded folded in
        print_string (Yojson.Safe.pretty_to_string json);
        print_newline ();
        Printf.eprintf "[watch] refolded %s (%d statements recomputed)\n%!"
          path (Beloch.Session.last_ran session)
    | exception Beloch.Error.Beloch_error (sp, m) ->
        Printf.eprintf "[watch] %s: %s\n%!" (Beloch.Error.span_to_string sp) m
  in
  while true do
    (match (Unix.stat path).Unix.st_mtime with
    | m when m > !last_mtime -> last_mtime := m; fold_once ()
    | _ -> ());
    Unix.sleepf 0.2
  done
```

Wire it into `fold`'s dispatch: if the args contain `--watch`, call `run_fold_watch file` instead of the one-shot path. If the `bin` executable's dune stanza does not already list `unix`, add it.

- [ ] **Step 4: Verify**

```bash
dune build bin/main.exe 2>&1 | tail -5
dune exec bin/main.exe -- fold --watch examples/bases/fish.bel &   # or any .bel
# in another shell: touch/edit the file; observe "[watch] refolded ... (N statements recomputed)"
# first fold reports all statements; a trailing-append edit reports 1
kill %1
```

Expected: first run recomputes all statements; appending one fold and saving reports `1 statement recomputed`.

- [ ] **Step 5: Commit**

```bash
git add bin/main.ml bin/dune
git commit -m "feat(cli): beloch fold --watch — incremental refold on save"
```

---

## Self-Review

**Spec coverage:**
- In-memory incremental re-eval, engine in `lib/` → Tasks 2–4. ✓
- Snapshot = whole `ctx` + `next_id` → Task 3 `snapshot` record. ✓
- Hash-chain spine, AST/whitespace-insensitive key → Task 2 (`normalize_ws` + chained `Digest`). ✓
- Longest-prefix reuse, edit invalidates suffix → Task 4 `eval`, tested. ✓
- Playground persistent session → Task 5. ✓
- CLI `--watch` ("falls out almost for free") → Task 6. ✓
- Byte-identical FOLD correctness net → Task 3 `test_resume_equals_full` + Task 4 `test_equivalence`. ✓
- Declare-before-use / no-forward-ref assertion → covered by the equivalence + edit tests (a reused prefix must byte-match); `snapshot`/`restore` assert single-root-scope. ✓
- Phase 2 `.beli` on-disk → explicitly out of scope (separate spec). ✓

**Placeholder scan:** No TBD/TODO; every code step carries complete code. Task 5 has no unit test by nature (jsoo global) and says so; verification is a real build + the parity already proven by `test_session`.

**Type consistency:** `snapshot`/`restore`/`eval_program`/`eval_folded` signatures match across Tasks 3–4; `Session.eval` returns `Eval.folded`, consumed by `Fold_emit.to_json_folded` in Tasks 5–6; `chain_keys : string -> Ast.program -> string list` consumed as `Array.of_list` in Task 4. `Session.last_ran` defined in Task 4, used in Task 6. Consistent.

**Open risks carried from spec (not blockers):**
- Snapshot cadence is dense (one per statement); fine for interactive sizes, revisit for very long programs.
- `canon_stmt` is whitespace-normalized source-slice, not a full structural AST hash — comment-insensitivity within a statement span is imperfect; acceptable for v1 (comments between statements fall outside all spans and never affect keys).
