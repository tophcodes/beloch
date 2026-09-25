(** The evaluator context: name/scope tables, the fold-state cursor, and the
    per-statement logs ([frames_rev]/[statements_rev]/[free_points_rev]) that
    [Eval.eval_program] assembles into a folded result. [ctx] and its
    component record/variant types ([scope], [instance], [crease_val],
    [name_ctx]) are concrete: [Resolve], [Axiom], [Flatten_solve] and [Eval]
    all read their fields or pattern-match their constructors directly. *)

val corners : (string * Geom.point) list
(** The four paper corners, keyed "a" "b" "c" "d". *)

type stmt_kind = SFold | SMark | SBind | SApply of string
(** Which axis a statement moves (ADR 0030). [SFold] and [SMark] are writes:
    the paper moved, or it was scored and stands where it was. [SBind] moves
    the program alone — a point, a construction line, a bundle, a definition,
    an export. [SApply] is an [apply] of the named def; its body's statements
    follow it in the log, each naming it as their parent. *)

type stmt_log_entry = {
  sl_kind : stmt_kind;
  sl_span : Error.span;
  sl_frame_index : int;
      (** Index into [ctx.frames_rev] (reversed) of the frame this
          statement's geometry reads against — the just-pushed frame for
          [SFold], the most-recently pushed frame for [SMark] and [SBind]
          (neither folds anything). *)
  sl_mark : Fold_state.mark option;
      (** The mark AS RECORDED by this statement, captured at record-time —
          independent of whether it later graduates into a real crease
          (which only happens at some LATER fold statement, or never). [None]
          for [SFold] and [SBind]. *)
  sl_kept : Fold_state.mark list;
      (** Marks still dangling (not yet graduated into a real crease) as of
          immediately after this statement. [SMark] inherits the previous
          statement's [sl_kept] and appends its own new mark, unchecked;
          [SFold] recomputes fresh via [Fold_state.mark_graduates] against
          the just-folded state; [SBind] inherits it unchanged, since a
          binding leaves every mark where it was. *)
  sl_parent : int option;
      (** The entry of the [apply] this statement runs under, [None] at the
          top level (ADR 0030). *)
}

type free_info = {
  fi_t : Num.t;
  fi_p0 : Geom.point;  (** t = 0 endpoint (anchor) *)
  fi_p1 : Geom.point;  (** t = 1 endpoint *)
  fi_source_line : int;
}

(** {1 Scope-stack context} *)

type crease_val =
  | Material of int * Geom.line
  | Mark of int * Geom.line
      (** A materialized construction line backed by the mark layer:
          meetable by [*] (its chords live in [Fold_state.marks]), never
          subdividing the working arrangement. [int] is the mark's
          [mcrease_id]. *)
  | Frozen of Geom.line
  | Bundle of Ast.line_operand
      (** A named crease bundle (`--x = --l & .c | [--a --b]`); resolves
          lazily as its expression, so the name behaves exactly like
          inlining it. *)
  | Edge of string * string
      (** A paper boundary edge, named by its two corners; resolves live (the
          edge moves under folding) through the current corner positions. *)

type instance = {
  ipoints : (string, Geom.point) Hashtbl.t;
  ilines : (string, crease_val) Hashtbl.t;
  ipoint_steps : (string, int * int option) Hashtbl.t;
  iline_steps : (string, int * int option) Hashtbl.t;
}
(** A landed [apply] instance's member tables, copied from the def body's own
    scope at apply-time. *)

type scope = {
  points : (string, Geom.point) Hashtbl.t;
  lines : (string, crease_val) Hashtbl.t;
  instances : (string, instance) Hashtbl.t;
  point_steps : (string, int * int option) Hashtbl.t;
  line_steps : (string, int * int option) Hashtbl.t;
      (** Creation step of each name bound in [points]/[lines] (respectively)
          within this scope, recorded at bind time by [bind_point]/
          [bind_crease] as [List.length ctx.frames_rev] and the index of the
          statement that binds the name ([stmt_index]). Kept as two tables
          (not one keyed by bare name) because points and lines are separate
          namespaces: a point and a line may share a stem (`.m` / `--m`). *)
}

val make_scope : unit -> scope

type reference =
  | RCrease of int * Error.span
  | REdge of string * Error.span
(** One resolved mention of a crease name in the source: where it stands and
    what it names. The sourcemap behind "show me every reference to this
    bundle" — not recoverable from the text, since one spelling means
    different creases inside a [def] body and after a [--x!] rebinding. *)

type name_ctx = Root | InInstance of string | Anon

type ctx = {
  mutable scopes : scope list;  (** head = innermost *)
  mutable name_ctx : name_ctx;
  mutable cur_def_idx : int option;  (** [Some k] while running def k's body *)
  mutable next_def_idx : int;
  defs : (string, int * Ast.param list * Ast.stmt list) Hashtbl.t;
  state : Fold_state.t ref;
  mutable frames_rev : (Fold_state.t * Error.span option) list;
  mutable statements_rev : stmt_log_entry list;
  mutable free_points_rev : (string * free_info) list;
  mutable references_rev : reference list;
  mutable parent : int option;
      (** The log entry of the [apply] whose body is running, [None] at the
          top level: the [sl_parent] of every entry logged meanwhile. *)
  mutable pending : bool;
      (** True when the current state hasn't been captured in a frame yet;
          drives the conditional final push (see [Eval.eval_program]). *)
}

val lookup_point : ctx -> Ast.point_ref -> Geom.point

val find_crease_by_name : ctx -> string -> crease_val option
(** The innermost binding of a crease name, or [None] when the name is free.
    The scope walk {!lookup_crease} and the output clause's `into` share. *)

val lookup_crease : ctx -> Ast.crease_ref -> crease_val
val lookup_instance : ctx -> string -> Error.span -> instance

val is_temp : string -> bool
(** Whether a name is `_`-prefixed (a rebindable temp). *)

val intent_of : Ast.direction -> Fold_state.assign

val flap_lookup_result :
  Error.span -> [ `Found of 'a | `Zero | `Ambiguous ] -> 'a
(** Shared failure text for every "points must land on exactly one
    flap/face" lookup (FByPoints resolution): callers narrow their own
    success variant to [`Found] and pass their [`Zero]/[`Ambiguous] through
    as-is. *)

val bind_point : ctx -> string -> Error.span -> Geom.point -> unit

val bind_crease :
  ?stmt:int -> ctx -> string -> Error.span -> crease_val -> unit
(** Bind a crease name. [stmt] is the index of the statement that binds it,
    for a caller that binds after that statement has logged its own entry;
    it defaults to [stmt_index], which is that index while the statement is
    still running. *)

val bind_output :
  ctx -> string -> rebind:bool -> Error.span -> (crease_val -> unit)
(** The binding step of a write's `as NAME` / `as NAME!` output clause: the
    name is checked now, ahead of the write, and bound when the returned
    step runs. A bound name needs the `!`, a free one refuses it, and a
    `_`-prefixed temp rebinds either way. *)

val promote_crease : ctx -> string -> crease_val -> unit
(** Promotes an already-bound name's binding in place to a freshly
    materialised crease (e.g. `mark --d` on a pure value-bound line), so a
    later `fold --d` can find it. Not a user-facing rebind: no dup check. *)

(** {1 Incremental checkpoint: snapshot / restore of the whole ctx} *)

type snapshot
(** Opaque; produced by {!snapshot}, consumed by {!restore}. [Session]
    memoizes one per statement. *)

val snapshot : ctx -> snapshot
(** Snapshots are taken between top-level statements, where [ctx.scopes] is a
    single root scope — fails otherwise. *)

val restore : ctx -> snapshot -> unit
(** Restores a snapshot INTO the existing root-scope tables (not fresh
    records), so a [root_scope] binding taken before the restore stays
    valid. *)

val stmt_index : ctx -> int
(** Index the statement currently being evaluated will occupy in the
    `beloch:statements` log. Provenance records are built while their
    statement runs, strictly before its log entry is pushed, so the current
    log length is that statement's own index. *)

val push_bind : ctx -> Error.span -> unit
(** Log a statement that bound a name and moved no paper, at its own span.
    Called once per executed statement that logged nothing of its own, so
    every statement appears on the second axis. *)

val push_apply : ctx -> string -> Error.span -> int
(** Log an [apply] of the named def at its own span, ahead of its body's
    entries, and return the entry's index for them to name as parent. *)

val push_frame : ctx -> Error.span option -> unit
