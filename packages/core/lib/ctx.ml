let corners : (string * Geom.point) list =
  let q = Num.of_int in
  [
    ("a", { Geom.x = q 0; y = q 0 });
    ("b", { Geom.x = q 1; y = q 0 });
    ("c", { Geom.x = q 1; y = q 1 });
    ("d", { Geom.x = q 0; y = q 1 });
  ]

type stmt_kind = SFold | SMark

type stmt_log_entry = {
  sl_kind : stmt_kind;
  sl_span : Error.span;
  sl_frame_index : int;
      (* file_frames index of the frame this statement's geometry reads
         against — the just-pushed frame for [SFold], the most-recently
         pushed frame for [SMark] (marks don't fold anything) *)
  sl_mark : Fold_state.mark option;
      (* the mark AS RECORDED by this statement, captured at record-time —
         independent of whether it later graduates into a real crease (which
         only happens at some LATER fold statement, or never). None for
         [SFold]. *)
  sl_kept : Fold_state.mark list;
      (* marks still dangling (not yet graduated into a real crease) as of
         immediately after this statement. [SMark] inherits the previous
         statement's [sl_kept] and appends its own new mark, unchecked — the
         backdrop frame is fixed and strictly predates this mark, so
         graduation cannot apply yet. [SFold] recomputes fresh via
         [Fold_state.mark_graduates] against the just-folded state. See
         docs/superpowers/specs/2026-07-20-per-statement-mark-graduation-design.md. *)
}

type free_info = {
  fi_t : Num.t;
  fi_p0 : Geom.point;  (* t = 0 endpoint (anchor) *)
  fi_p1 : Geom.point;  (* t = 1 endpoint *)
  fi_source_line : int;
}

(* ---- Scope-stack context ---- *)

type crease_val =
  | Material of int * Geom.line
  | Mark of int * Geom.line
      (* a materialized construction line backed by the mark layer: meetable
         by `*` (its chords live in Fold_state.marks), never subdividing the
         working arrangement. [int] is the mark's mcrease_id. *)
  | Frozen of Geom.line
  | Bundle of Ast.line_operand
      (* a named crease bundle (--x = --l & .c | [--a --b]); resolves lazily as
         its expression, so the name behaves exactly like inlining it *)
  | Edge of string * string
      (* a paper boundary edge, named by its two corners; resolves live (the
         edge moves under folding) through the current corner positions *)

type instance = {
  ipoints : (string, Geom.point) Hashtbl.t;
  ilines : (string, crease_val) Hashtbl.t;
  ipoint_steps : (string, int) Hashtbl.t;
  iline_steps : (string, int) Hashtbl.t;
      (* creation step of each member, copied from the def body's own
         [scope.point_steps]/[scope.line_steps] at apply-time; see those.
         Points and lines are separate namespaces (distinct sigils `.`/`--`),
         so a point and a line may share a stem — kept in separate tables
         rather than one shared-key table so they can't clobber each
         other's step. *)
}

type scope = {
  points    : (string, Geom.point) Hashtbl.t;
  lines     : (string, crease_val) Hashtbl.t;
  instances : (string, instance) Hashtbl.t;
  point_steps : (string, int) Hashtbl.t;
  line_steps  : (string, int) Hashtbl.t;
      (* creation step of each name bound in points/lines (respectively)
         within THIS scope, recorded at bind time by [bind_point]/
         [bind_crease] as [List.length ctx.frames_rev]. Scoped per-entry so
         it saves/restores across `apply` exactly like points/lines do — a
         def body's own bindings never clobber an outer scope's already-
         recorded step for the same name. Kept as two tables (not one keyed
         by bare name) because points and lines are separate namespaces: a
         point and a line may share a stem (`.m` / `--m`), and a single
         shared-key table would let one clobber the other's step. *)
}

let make_scope () = {
  points      = Hashtbl.create 8;
  lines       = Hashtbl.create 8;
  instances   = Hashtbl.create 4;
  point_steps = Hashtbl.create 8;
  line_steps  = Hashtbl.create 8;
}

type name_ctx = Root | InInstance of string | Anon

type ctx = {
  mutable scopes : scope list;  (* head = innermost *)
  mutable name_ctx : name_ctx;
  mutable cur_def_idx : int option; (* Some k while running def k's body *)
  mutable next_def_idx : int;
  defs : (string, int * Ast.param list * Ast.stmt list) Hashtbl.t;
  state : Fold_state.t ref;
  mutable frames_rev : (Fold_state.t * Error.span option) list;
  mutable statements_rev : stmt_log_entry list;
  mutable free_points_rev : (string * free_info) list;
  mutable pending : bool;
      (* true when the current state hasn't been captured in a frame yet;
         drives the conditional final push (see eval_folded) *)
}

let lookup_point (ctx : ctx) (pr : Ast.point_ref) : Geom.point =
  match List.find_map (fun s -> Hashtbl.find_opt s.points pr.Ast.name) ctx.scopes with
  | Some p -> p
  | None   -> Error.fail pr.Ast.span (Printf.sprintf "undefined point .%s" pr.Ast.name)

let lookup_crease (ctx : ctx) (cr : Ast.crease_ref) : crease_val =
  match List.find_map (fun s -> Hashtbl.find_opt s.lines cr.Ast.cname) ctx.scopes with
  | Some cv -> cv
  | None -> Error.fail cr.Ast.cspan (Printf.sprintf "undefined crease --%s" cr.Ast.cname)

let lookup_instance (ctx : ctx) (name : string) (span : Error.span) : instance =
  match
    List.find_map (fun s -> Hashtbl.find_opt s.instances name) ctx.scopes
  with
  | Some i -> i
  | None -> Error.fail span (Printf.sprintf "undefined instance $%s" name)

let is_temp (n : string) = String.length n > 0 && n.[0] = '_'

let intent_of (dir : Ast.direction) : Fold_state.assign =
  match dir with Ast.Valley -> Fold_state.V | Ast.Mountain -> Fold_state.M

(* Shared failure text for every "points must land on exactly one flap/face"
   lookup (FByPoints resolution): callers narrow their own success variant
   (`Face of int, `Cluster of int list, ...) to `Found and pass through their
   `Zero/`Ambiguous as-is, so the 0-match/multi-match wording lives here once
   instead of being copied at each call site. *)
let flap_lookup_result (span : Error.span)
    (r : [ `Found of 'a | `Zero | `Ambiguous ]) : 'a =
  match r with
  | `Found v -> v
  | `Zero -> Error.fail span "those points aren't all on one flap"
  | `Ambiguous -> Error.fail span "ambiguous flap; add another point"

let bind_point (ctx : ctx) (name : string) (span : Error.span) (p : Geom.point)
    =
  let s = List.hd ctx.scopes in
  if (not (is_temp name)) && Hashtbl.mem s.points name then
    Error.fail span
      (Printf.sprintf "point .%s is already bound; only _-prefixed temps rebind"
         name);
  Hashtbl.replace s.points name p;
  Hashtbl.replace s.point_steps name (List.length ctx.frames_rev)

let bind_crease (ctx : ctx) (name : string) (span : Error.span) (cv : crease_val) =
  let s = List.hd ctx.scopes in
  if (not (is_temp name)) && Hashtbl.mem s.lines name then
    Error.fail span
      (Printf.sprintf "crease --%s is already bound; only _-prefixed temps rebind"
         name);
  Hashtbl.replace s.lines name cv;
  Hashtbl.replace s.line_steps name (List.length ctx.frames_rev)

(* `mark --d` on an already-bound name (e.g. a pure `--d = <motion>` value)
   promotes its binding in place to the freshly materialised crease, so a
   later `fold --d` can find it. Not a user-facing rebind (no dup check): the
   name already resolved to [lo], we're just upgrading what it points to. *)
let promote_crease (ctx : ctx) (name : string) (cv : crease_val) =
  match List.find_opt (fun s -> Hashtbl.mem s.lines name) ctx.scopes with
  | Some s -> Hashtbl.replace s.lines name cv
  | None -> ()


(* ---- Evaluator ---- *)

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
  s_frames_rev : (Fold_state.t * Error.span option) list;
  s_statements_rev : stmt_log_entry list;
  s_free_points_rev : (string * free_info) list;
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
        s_frames_rev = ctx.frames_rev;
        s_statements_rev = ctx.statements_rev;
        s_free_points_rev = ctx.free_points_rev;
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
      ctx.frames_rev <- s.s_frames_rev;
      ctx.statements_rev <- s.s_statements_rev;
      ctx.free_points_rev <- s.s_free_points_rev;
      ctx.pending <- s.s_pending;
      ctx.state := s.s_state;
      Fold_state.set_next_id s.s_next_id
  | _ -> failwith "Eval.restore: expected a single root scope at a statement boundary"

let push_frame (ctx : ctx) (span : Error.span option) =
  ctx.frames_rev <- (!(ctx.state), span) :: ctx.frames_rev;
  ctx.pending <- false;
  (match span with
  | Some sp ->
      let st = !(ctx.state) in
      let kept =
        Array.to_list (Fold_state.marks st)
        |> List.filter (fun m -> not (Fold_state.mark_graduates st m))
      in
      ctx.statements_rev <-
        { sl_kind = SFold; sl_span = sp;
          sl_frame_index = List.length ctx.frames_rev; sl_mark = None;
          sl_kept = kept }
        :: ctx.statements_rev
  | None -> ())
