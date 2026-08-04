(** Multisets of two-fold alignments (candidate 2FAs) [alperin2006, §4]. *)

type t = Alignment.t list
(** Sorted by {!Alignment.compare}. *)

val candidates : unit -> t list
(** All multisets of 2-4 symbols from {!Alignment.all_twofold} whose equations
    sum to exactly 4, canonical under global a<->b swap, non-{!separable}, and
    not {!al1_degenerate}. Does NOT apply {!matches_published_list} -- that
    filter is empirical and must be applied explicitly by callers reproducing
    the paper's printed count. *)

val canonical : t -> t
(** The lexicographically smaller (via {!Alignment.compare} list order) of a
    combo and its {!Alignment.swap_ab} image, both sorted. *)

val separable : t -> bool
(** Whether the combo is separable in the sense of Definition 10
    [alperin2006, l. 467-468]: sequential decomposition into two 1FAs, not a 2+2
    bipartition. True iff some fold has >= 2 single-fold alignments
    (AL2/AL3/AL6) with its suffix -- once a fold is fixed by these alone, every
    remaining alignment becomes a one-fold alignment for the other fold. See
    notes/2026-08-04-multifold-203-mismatch.md, §R1. *)

val al1_degenerate : t -> bool
(** Whether the combo contains AL1 together with any of AL4, AL5, AL8, AL9.
    Under AL1's forced perpendicularity, Definition 12's fold-equivalence
    [alperin2006, l. 476-479] rewrites each of these to a separable, duplicate,
    or degenerate combo -- never a genuine independent 2FA. See
    notes/2026-08-04-multifold-203-mismatch.md, §R2. *)

val matches_published_list : t -> bool
(** An EMPIRICAL criterion matching Alperin-Lang's printed listing, not a
    derived rule: false iff the combo contains AL8 or AL9 and no alignment of
    kinds AL3, AL4, AL5, AL6, AL10. 3 of the 5 combos it excludes (AL2ab8,
    AL2a7a9, AL2a7b9) pass every criterion the paper states and may be genuine
    2FAs missing from the paper's list. Not applied by {!candidates}; callers
    reproducing the paper's count must apply it explicitly and should report
    both filtered and unfiltered counts. See
    notes/2026-08-04-multifold-203-mismatch.md, §R4. *)

val onefold_candidates : unit -> string list
(** All multisets of 1-2 symbols from the one-fold alphabet A1-A5
    [alperin2006, §2, Fig. 2] whose equations sum to exactly 2, excluding the
    structurally invalid pair {A3,A3} [alperin2006, Table 1]. Reproduces the 7
    HJAs; names sorted ascending, e.g. ["A1"; "A2"; "A3+A4"; ...]. *)
