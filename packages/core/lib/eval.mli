(** Evaluate a program, resolving names and applying axioms. Geometry is
    exact; preconditions are reported as [Error.Beloch_error]. This is the
    public surface of the [core] evaluator: consumed by [Fold_emit],
    [Session], [Beloch], the test suites and
    packages/www/public/beloch/beloch-eval.js. *)

type snapshot = Ctx.snapshot
(** Opaque incremental-eval checkpoint; see {!snapshot} / {!restore} and
    [Session]. *)

type stmt_kind = Ctx.stmt_kind = SFold | SMark | SBind | SApply of string

type stmt_log_entry = Ctx.stmt_log_entry = {
  sl_kind : stmt_kind;
  sl_span : Error.span;
  sl_frame_index : int;
      (** Index into [frames] of the frame this statement's geometry reads
          against — the just-pushed frame for [SFold], the
          most-recently pushed frame for [SMark] (marks don't fold
          anything). *)
  sl_mark : Fold_state.mark option;
      (** The mark AS RECORDED by this statement, captured at record-time —
          independent of whether it later graduates into a real crease.
          [None] for [SFold]. *)
  sl_kept : Fold_state.mark list;
      (** Marks still dangling (not yet graduated into a real crease) as of
          immediately after this statement. *)
  sl_parent : int option;
      (** The entry of the [apply] this statement runs under, [None] at the
          top level (ADR 0030). *)
}

type free_info = Ctx.free_info = {
  fi_t : Num.t;
  fi_p0 : Geom.point;  (** t = 0 endpoint (anchor) *)
  fi_p1 : Geom.point;  (** t = 1 endpoint *)
  fi_source_line : int;
}

val snapshot : Ctx.ctx -> snapshot
val restore : Ctx.ctx -> snapshot -> unit

type folded = {
  state : Fold_state.t;
  named_points : (string * Geom.point * int * int option) list;
      (** The 0-based creation step (index into [frames] at bind time) and
          the index of the statement that binds the point in the
          `beloch:statements` log. Every statement is logged (ADR 0026), so
          the index is the binding statement's own. [None] for a name no
          statement bound, which the four paper corners are. *)
  named_lines : (string * Geom.line * int * int option) list;
      (** Name, current line, and the same two counters a named point
          carries: the creation frame and the statement that binds it. *)
  named_line_cids : (string * int) list;
      (** Crease id per name for [Material]/[Mark] creases — the identity the
          line coefficients in [named_lines] lose (a folded crease's current
          line can coincide with another crease's line). *)
  frames : (Fold_state.t * Error.span option) list;
  statements : stmt_log_entry list;
  references : Ctx.reference list;
      (** Every resolved mention of a crease name, in source order — the
          sourcemap from a bundle back to the places the program names it. *)
  annotations : Ctx.annot_entry list;
      (** every annotation in the order it was read, each with the log entry
          of the statement it belongs to (ADR 0029) *)
  free_points : (string * free_info) list;
      (** One entry per `free on` point, recorded at bind time — a running
          log (like [statements]), not reconstructed from scope state at
          finalize. *)
}

val eval_program :
  ?resume:snapshot -> ?on_step:(Ctx.ctx -> unit) -> Ast.program -> folded
(** Evaluate [prog]. [resume] restores an incremental-eval checkpoint before
    the first statement; [on_step] runs after every statement (used by
    [Session] to collect a fresh snapshot per statement). *)

val eval_folded : Ast.program -> folded
(** [eval_program] with no resume/on_step. *)
