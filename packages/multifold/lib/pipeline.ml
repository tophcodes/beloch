(* See pipeline.mli. *)

module M = Beloch.Mpoly

type classify_result =
  [ `Zero_dim of Msolve.zero_dim | `Positive_dim | `No_solutions ]

let strict_keep : classify_result -> bool = function
  | `Zero_dim { count; multiplicity_free; real_count = _ } ->
      count >= 1 && multiplicity_free
  | `Positive_dim | `No_solutions -> false

(* [real_count] is not a filter criterion (see {!Msolve.zero_dim} and
   notes/2026-08-04-multifold-203-mismatch.md's addendum): a single
   parameter-point's realness is not the same question as Alperin-Lang's
   generic-over-ℂ existence claim, and empirically it is stream-dependent
   (29 vs. 23 genuine paper-listed symbols show real_count=0 at stream_a vs.
   stream_b, only 12 in common). Reported, not filtered: a strict-surviving
   combo with real_count=0 at the given stream is logged to stderr so the
   information stays visible without silently dropping the symbol. *)
let log_if_complex_only ~(where : string) ~(symbol : string)
    (r : classify_result) : unit =
  match r with
  | `Zero_dim { real_count = 0; _ } ->
      Printf.eprintf "%s: %s complex-only at this stream (real_count=0)\n%!"
        where symbol
  | _ -> ()

let lax_keep : classify_result -> bool = function
  | `Zero_dim { count; _ } -> count >= 1
  | `Positive_dim | `No_solutions -> false

(* ------------------------------------------------------------------ *)
(* One-fold: alphabet A1-A5 [alperin2006, §2, Fig. 2], 2 variables (one
   fold, index 0). Not already in Symeq (which is two-fold-focused): A1 and
   A2 compare a REFLECTED given object against a RAW given object, a shape
   none of the two-fold AL* kinds have (AL* always compares two reflected
   images, or a reflected image against a fold line). A3-A5 need no new
   algebra: they are exactly AL2/AL6/AL3's formulas at fold 0
   (self-invariance, point-onto-line, line-through-point respectively). *)

let onefold_nvars = 2

let point_triple ((px, py) : Q.t * Q.t) : M.t * M.t * M.t =
  ( M.const onefold_nvars px,
    M.const onefold_nvars py,
    M.const onefold_nvars Q.one )

(* Same (X, Y, 1) shape as a raw given point: eq_pair below is purely
   componentwise cross-multiplication, agnostic to point-vs-line meaning. *)
let line_triple = point_triple

let incidence ((lX, lY) : M.t * M.t) ((nx, ny, d) : M.t * M.t * M.t) : M.t =
  M.add (M.add (M.mul lX nx) (M.mul lY ny)) d

let eq_pair ((n1x, n1y, d1) : M.t * M.t * M.t)
    ((n2x, n2y, d2) : M.t * M.t * M.t) : M.t list =
  [ M.sub (M.mul n1x d2) (M.mul n2x d1); M.sub (M.mul n1y d2) (M.mul n2y d1) ]

let onefold_equations_of ~(stream : Symeq.param_stream) (symbol : string) :
    M.t list * M.t list =
  let x0 = M.var onefold_nvars 0 and y0 = M.var onefold_nvars 1 in
  let rec go pos = function
    | [] -> ([], [])
    | tok :: rest ->
        let eqs, denoms, pos' =
          match tok with
          | "A1" ->
              (* FLF(P1) <-> P2: reflected P1 equals given P2 — 2 eqs. *)
              let p1, pos1 = Symeq.draw_pair ~stream ~start:pos in
              let p2, pos2 = Symeq.draw_pair ~stream ~start:pos1 in
              let ((_, _, d) as img) =
                Symeq.reflect_point_raw ~nvars:onefold_nvars ~fold:0 p1
              in
              (eq_pair img (point_triple p2), [ d ], pos2)
          | "A2" ->
              (* FLF(L1) <-> L2: reflected L1 equals given L2 — 2 eqs. Also
                 clears the fold's isotropic factor x0²+y0², not just the
                 chart denominator d: reflect_line_raw's own d does NOT
                 vanish on the isotropic locus even though line-reflection is
                 undefined there [notes/2026-08-04-multifold-203-mismatch.md,
                 §R3] -- same fix as the two-fold path's AL4/AL9 (the other
                 pure line-reflection alignments), added here for consistency
                 even though A2 alone (only 2 equations total, at most this
                 one alignment) has no companion alignment to leave a
                 spurious component for; harmless, not observed to change
                 any classification. *)
              let l1, pos1 = Symeq.draw_pair ~stream ~start:pos in
              let l2, pos2 = Symeq.draw_pair ~stream ~start:pos1 in
              let ((_, _, d) as img) =
                Symeq.reflect_line_raw ~nvars:onefold_nvars ~fold:0 l1
              in
              let isotropic = M.add (M.mul x0 x0) (M.mul y0 y0) in
              (eq_pair img (line_triple l2), [ d; isotropic ], pos2)
          | "A3" ->
              (* FLF(L) <-> L: fold self-invariance <=> fold ⊥ L (same
                 perpendicularity lemma as AL2): x0·lX + y0·lY = 0 — 1 eq, no
                 denominator (no reflection is performed). *)
              let (lX, lY), pos1 = Symeq.draw_pair ~stream ~start:pos in
              ( [
                  M.add
                    (M.mul x0 (M.const onefold_nvars lX))
                    (M.mul y0 (M.const onefold_nvars lY));
                ],
                [],
                pos1 )
          | "A4" ->
              (* FLF(P) <-> L: folded point lies on given line — 1 eq. *)
              let p, pos1 = Symeq.draw_pair ~stream ~start:pos in
              let (lX, lY), pos2 = Symeq.draw_pair ~stream ~start:pos1 in
              let ((_, _, d) as img) =
                Symeq.reflect_point_raw ~nvars:onefold_nvars ~fold:0 p
              in
              ( [
                  incidence
                    (M.const onefold_nvars lX, M.const onefold_nvars lY)
                    img;
                ],
                [ d ],
                pos2 )
          | "A5" ->
              (* LF <-> P: the fold line itself passes through P — 1 eq, no
                 denominator (the given point is exact, not reflected). *)
              let p, pos1 = Symeq.draw_pair ~stream ~start:pos in
              ([ incidence (x0, y0) (point_triple p) ], [], pos1)
          | _ -> invalid_arg ("Pipeline: unknown one-fold token " ^ tok)
        in
        let eqs', denoms' = go pos' rest in
        (eqs @ eqs', denoms @ denoms')
  in
  go 0 (String.split_on_char '+' symbol)

let run_onefold () : string list =
  Combo.onefold_candidates ()
  |> List.filter (fun symbol ->
      let eqs, denoms = onefold_equations_of ~stream:Symeq.stream_a symbol in
      let r = Msolve.classify ~nvars:onefold_nvars ~denoms eqs in
      let keep = strict_keep r in
      if keep then log_if_complex_only ~where:"run_onefold" ~symbol r;
      keep)
  |> List.sort String.compare

(* ------------------------------------------------------------------ *)
(* Two-fold: candidates -> Symeq -> Msolve, 4 variables (two folds).
   Memoized per (with_al10, stream) so run_twofold / run_twofold_lax /
   lax_only share one msolve sweep (566 combos with AL10, 264 without)
   instead of each re-solving it. *)

let twofold_nvars = 4

let cache :
    (bool * Symeq.param_stream * (string * classify_result) list) list ref =
  ref []

let classify_raw ~(with_al10 : bool) ~(stream : Symeq.param_stream) :
    (string * classify_result) list =
  match
    List.find_opt (fun (b, s, _) -> b = with_al10 && s == stream) !cache
  with
  | Some (_, _, result) -> result
  | None ->
      let combos =
        Combo.candidates ()
        |> List.filter (fun c ->
            with_al10
            || not (List.exists (fun (a : Alignment.t) -> a.kind = AL10) c))
      in
      let total = List.length combos in
      Printf.eprintf "run_twofold: %d candidates (with_al10=%b)\n%!" total
        with_al10;
      let kept = ref 0 in
      let result =
        List.mapi
          (fun i combo ->
            let symbol = Alignment.combo_to_symbol combo in
            let eqs, denoms =
              Symeq.equations_denoms_of ~nvars:twofold_nvars ~stream combo
            in
            let r = Msolve.classify ~nvars:twofold_nvars ~denoms eqs in
            if strict_keep r then begin
              incr kept;
              log_if_complex_only ~where:"run_twofold" ~symbol r
            end;
            if (i + 1) mod 100 = 0 then
              Printf.eprintf "run_twofold: %d/%d processed, %d kept so far\n%!"
                (i + 1) total !kept;
            (symbol, r))
          combos
      in
      Printf.eprintf "run_twofold: done, %d/%d kept (strict)\n%!" !kept total;
      cache := (with_al10, stream, result) :: !cache;
      result

let symbols_where ~with_al10 ~stream ~(keep : classify_result -> bool) :
    string list =
  classify_raw ~with_al10 ~stream
  |> List.filter (fun (_, r) -> keep r)
  |> List.map fst
  |> List.sort_uniq String.compare

let run_twofold ~with_al10 ~stream : string list =
  symbols_where ~with_al10 ~stream ~keep:strict_keep

let run_twofold_lax ~with_al10 ~stream : string list =
  let lax = symbols_where ~with_al10 ~stream ~keep:lax_keep in
  let strict = symbols_where ~with_al10 ~stream ~keep:strict_keep in
  let diff = List.filter (fun s -> not (List.mem s strict)) lax in
  if diff = [] then Printf.eprintf "run_twofold_lax: no lax-only symbols\n%!"
  else
    Printf.eprintf "run_twofold_lax: %d lax-only symbol(s): %s\n%!"
      (List.length diff) (String.concat ", " diff);
  lax

let lax_only ~with_al10 ~stream : string list =
  let lax = symbols_where ~with_al10 ~stream ~keep:lax_keep in
  let strict = symbols_where ~with_al10 ~stream ~keep:strict_keep in
  List.filter (fun s -> not (List.mem s strict)) lax

(* R4 [notes/2026-08-04-multifold-203-mismatch.md, §R4] is deliberately not
   baked into {!Combo.candidates} -- it is an empirical criterion matching
   Alperin-Lang's printed listing, not a derived rule (see
   {!Combo.matches_published_list}'s doc comment). This is the "reproduction
   run": {!run_twofold}'s result (every candidate surviving R1/R2/R3, i.e.
   the strict algebraic filter over {!Combo.candidates}) additionally
   restricted by R4. Logs both the unfiltered and R4-filtered counts to
   stderr so the empirical filter's effect stays visible rather than
   silently baked in. *)
let run_twofold_published ~with_al10 ~stream : string list =
  let unfiltered = run_twofold ~with_al10 ~stream in
  let filtered =
    List.filter
      (fun symbol ->
        match Alignment.combo_of_symbol symbol with
        | Some c -> Combo.matches_published_list c
        | None -> invalid_arg ("Pipeline: unparseable symbol " ^ symbol))
      unfiltered
  in
  Printf.eprintf
    "run_twofold_published: %d unfiltered (R1/R2/R3 only), %d after R4 \
     (empirical published-list filter)\n\
     %!"
    (List.length unfiltered) (List.length filtered);
  filtered
