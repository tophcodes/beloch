type t = Alignment.t list

let sort = List.sort Alignment.compare

let canonical c =
  let a = sort c in
  let b = sort (List.map Alignment.swap_ab c) in
  if List.compare Alignment.compare a b <= 0 then a else b

(* Single-fold alignments [alperin2006, Fig. 4]: AL2, AL3, AL6 mention one
   fold line, via their suffix; every other kind's equations mention both
   fold lines' variables. *)
let is_single_fold : Alignment.kind -> bool = function
  | AL2 | AL3 | AL6 -> true
  | _ -> false

(* R1 (sequential separability), replacing the old 2+2-bipartition rule.
   [notes/2026-08-04-multifold-203-mismatch.md, §R1]; Definition 10's
   separability [alperin2006, l. 467-468] is sequential, not a bipartition:
   the Abe-trisection example immediately after it [alperin2006, l. 470-473]
   folds L1 from givens alone, then folds L2 using L1 as an ordinary given
   line. As soon as >= 2 same-suffix single-fold alignments (AL2/AL3/AL6) fix
   one fold from the given objects alone, every remaining alignment becomes a
   one-fold alignment for the other fold (which now has a known line to
   reference), so the combo reduces to two 1FAs in sequence regardless of
   what those remaining alignments are. This subsumes the old "2+2, no
   cross-fold alignment" case: {AL2a,AL3a,AL2b,AL3b} has 2 same-suffix
   single-fold alignments on each fold, so R1 rejects it too. *)
let separable c =
  let same_suffix suffix =
    List.length
      (List.filter
         (fun (a : Alignment.t) ->
           is_single_fold a.Alignment.kind && a.Alignment.suffix = suffix)
         c)
  in
  same_suffix Alignment.A >= 2 || same_suffix Alignment.B >= 2

(* R2 (AL1 fold-equivalence reduction) [notes/2026-08-04-multifold-203-mismatch.md,
   §R2; alperin2006, Def. 12, l. 476-479]. AL1 [F_a(L_b) <-> L_b] forces fold
   a perpendicular to fold b (the only line a reflection leaves invariant,
   besides the axis itself, is one perpendicular to it). Under a ⊥ b,
   Definition 12's F_a/F_b substitution rewrites every alignment of these
   kinds in the same combo to something that isn't a genuine new 2FA:
   - AL5a ≡ AL3b (apply F_a to both sides, then use AL1): separable.
   - AL8 ≡ AL3a + AL3b on the derived midpoint: separable.
   - AL4 degenerates: F_a(L) = L_b with L_b ⊥ L_a forces F_a(L) = L, i.e.
     fold b coincides with the GIVEN line L, not a new fold line
     [alperin2006, l. 285].
   - AL9 is inconsistent: F_a∘F_b is the half-turn about a ∩ b, and AL9
     needs it to map one generic given line onto another, i.e. the two given
     lines parallel — false generically.
   None of these combinations is a genuine, independent 2FA, so any combo
   containing AL1 together with AL4, AL5, AL8, or AL9 is rejected. *)
let al1_degenerate c =
  let has kind =
    List.exists (fun (a : Alignment.t) -> a.Alignment.kind = kind) c
  in
  has Alignment.AL1
  && (has Alignment.AL4 || has Alignment.AL5 || has Alignment.AL8
    || has Alignment.AL9)

(* R4 (empirical), NOT part of {!candidates} — see below. *)
let published_list_anchor_kinds : Alignment.kind list =
  [ Alignment.AL3; AL4; AL5; AL6; AL10 ]

(* R4: empirical criterion matching Alperin-Lang's printed listing
   [notes/2026-08-04-multifold-203-mismatch.md, §R4]. NOT a derived rule --
   3 of the 5 combos it excludes (AL2ab8, AL2a7a9, AL2a7b9) pass every
   criterion the paper states (real, zero-dimensional, multiplicity-free,
   non-separable under every reading of Definition 10) and may be genuine
   2FAs absent from the paper's list; see the notes file for the full
   accounting, including the 2 that are semi-principled (AL2a7a8, AL2a7b8:
   no real solution at either parameter stream). Deliberately kept out of
   {!candidates} -- callers reproducing the paper's published count must
   apply this filter explicitly and should report both the filtered and
   unfiltered counts (see {!Pipeline}). *)
let matches_published_list c =
  let has kind =
    List.exists (fun (a : Alignment.t) -> a.Alignment.kind = kind) c
  in
  let has_al8_or_al9 = has Alignment.AL8 || has Alignment.AL9 in
  let has_anchor =
    List.exists
      (fun (a : Alignment.t) ->
        List.mem a.Alignment.kind published_list_anchor_kinds)
      c
  in
  not (has_al8_or_al9 && not has_anchor)

(* The one-fold analogue of the alphabet above [alperin2006, §2, Fig. 2]:
   A1 = FLF(P1)<->P2 (2 eq), A2 = FLF(L1)<->L2 (2 eq), A3 = FLF(L)<->L (1 eq),
   A4 = FLF(P)<->L (1 eq), A5 = LF<->P (1 eq). *)
type onefold = OA1 | OA2 | OA3 | OA4 | OA5

let onefold_equations = function OA1 | OA2 -> 2 | OA3 | OA4 | OA5 -> 1

let onefold_index = function
  | OA1 -> 1
  | OA2 -> 2
  | OA3 -> 3
  | OA4 -> 4
  | OA5 -> 5

let onefold_compare a b = Int.compare (onefold_index a) (onefold_index b)

let onefold_name = function
  | OA1 -> "A1"
  | OA2 -> "A2"
  | OA3 -> "A3"
  | OA4 -> "A4"
  | OA5 -> "A5"

let onefold_combo_to_symbol combo =
  combo |> List.map onefold_name |> String.concat "+"

let onefold_candidates () =
  let alphabet = [| OA1; OA2; OA3; OA4; OA5 |] in
  let n = Array.length alphabet in
  let out = ref [] in
  (* Same multiset recursion as [candidates], length 1-2, pruned on eq sum. *)
  let rec go start acc eqs len =
    if eqs = 2 && len >= 1 then out := List.rev acc :: !out;
    if eqs < 2 && len < 2 then
      for i = start to n - 1 do
        let a = alphabet.(i) in
        let e = onefold_equations a in
        if eqs + e <= 2 then go i (a :: acc) (eqs + e) (len + 1)
      done
  in
  go 0 [] 0 0;
  !out
  (* {A3,A3}: two distinct lines each folded onto themselves — inconsistent
     if nonparallel, redundant if parallel [alperin2006, Table 1, top-left
     "N/A" cell]. *)
  |> List.filter (fun c -> c <> [ OA3; OA3 ])
  |> List.sort_uniq (List.compare onefold_compare)
  |> List.map onefold_combo_to_symbol

let candidates () =
  let alphabet = Array.of_list Alignment.all_twofold in
  let n = Array.length alphabet in
  let out = ref [] in
  (* multisets as non-decreasing index sequences, length 2..4, pruned on eq sum *)
  let rec go start acc eqs len =
    if eqs = 4 && len >= 2 then out := List.rev acc :: !out;
    if eqs < 4 && len < 4 then
      for i = start to n - 1 do
        let a = alphabet.(i) in
        let e = Alignment.equations a in
        if eqs + e <= 4 then go i (a :: acc) (eqs + e) (len + 1)
      done
  in
  go 0 [] 0 0;
  !out
  |> List.filter (fun c -> not (separable c))
  |> List.filter (fun c -> not (al1_degenerate c))
  |> List.map canonical
  |> List.sort_uniq (List.compare Alignment.compare)
