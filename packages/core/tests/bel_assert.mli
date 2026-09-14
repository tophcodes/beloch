(** The `.bel` inline-assertion format
    (docs/superpowers/specs/2026-07-14-beloch-inline-assertions-design.md):
    its grammar, tokenizer and checker, shared by the `.bel` corpus runner
    (test_bel_assert.ml) and the BELOCH.md reference-corpus runner
    (test_reference_corpus.ml), so both check assertions through one
    implementation. *)

open Beloch

type assertion
(** A parsed `; assert ...` or `; expect error "..."` line. *)

exception Harness_fail of string
(** Raised by [extract], [expected_error] and [check] on anything that keeps
    them from deciding pass or fail: a malformed line, more than one
    `expect error` in a file, an `expect error` next to another assertion,
    or a failed check against the evaluator's state. *)

val is_assertion_line : string -> bool
(** [is_assertion_line line] is [true] when [line], trimmed of leading and
    trailing whitespace, is a `;`-comment starting with [assert] or
    [expect]. *)

val extract : string -> (string * assertion) list
(** [extract src] finds every line of [src] that [is_assertion_line]
    accepts, tokenizes and parses each one, and returns the line text paired
    with its parsed form, in source order. Raises [Harness_fail] on a line
    that does not parse. *)

val expected_error : assertion list -> string option
(** [expected_error assertions] is [Some substr] when [assertions] holds
    exactly one `expect error "substr"` and nothing else, and [None] when it
    holds no `expect error` at all. Raises [Harness_fail] when it holds more
    than one `expect error`, or one alongside any other assertion: an
    `expect error` must be the only assertion in its file or block. *)

val contains_substring : string -> string -> bool
(** [contains_substring haystack needle] is [true] when [needle] occurs
    anywhere in [haystack]. *)

val check_error_message : expected:string -> string -> unit
(** [check_error_message ~expected msg] raises [Harness_fail] when [msg]
    does not contain [expected] as a substring. *)

val check : Eval.folded -> assertion -> unit
(** [check folded a] verifies [a] against [folded], the result of evaluating
    the program [a] was extracted from. Raises [Harness_fail] on a failed
    assertion. Never called with the assertion [expected_error] returns. *)
