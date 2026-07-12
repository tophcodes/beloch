(** Exact real algebraic numbers. A value is an exact rational [Rat q]
    (fast path: axioms 1–4 never leave ℚ), an element of a single quadratic/
    cubic extension [Field {gen; coords}] = coords(α) with α the root of the
    monic irreducible [gen.mu] isolated in [(gen.lo, gen.hi)] (fast path for
    axiom-5/6/7 roots, [bpr2006 §12.4]), or a general real algebraic number
    [Qq] backed by FLINT's qqbar (canonical minimal polynomial + certified
    ball; cross-field arithmetic, composite extensions). Invariant: [Qq] is
    irrational — rationals collapse to [Rat]. [to_float] is the only float,
    output-only. See decisions/0013-flint-qqbar-backend.md. *)

type t =
  | Rat of Q.t
  | Qq of Qqbar.t
  | Field of { gen : gen; coords : Poly.t }

and gen = { mu : Poly.t; lo : Q.t; hi : Q.t }

let zero : t = Rat Q.zero
let one : t = Rat Q.one
let of_q (q : Q.t) : t = Rat q
let of_int (i : int) : t = Rat (Q.of_int i)
let two_q = Q.of_int 2

(* generators are equal iff their (irreducible) μ and isolating interval match.
   Distinct roots of the same μ have distinct intervals, so are never merged. *)
let same_gen (a : gen) (b : gen) : bool =
  Q.equal a.lo b.lo && Q.equal a.hi b.hi
  && Array.length a.mu = Array.length b.mu
  && Array.for_all2 Q.equal a.mu b.mu

(* smart constructor: a Field value is canonical only when irrational, so a value
   that reduces to a constant collapses to Rat (and 0 to Rat 0). coords is
   normalized (trailing zeros dropped); callers guarantee it is already reduced
   mod μ (degree < deg μ). *)
let mk_field (gen : gen) (coords : Poly.t) : t =
  let c = Poly.normalize coords in
  match Poly.degree c with
  | d when d < 0 -> Rat Q.zero
  | 0 -> Rat c.(0)
  | _ -> Field { gen; coords = c }

(* collapse a qqbar value into canonical representation (Qq iff irrational) *)
let of_qq (q : Qqbar.t) : t =
  match Qqbar.to_q q with Some r -> Rat r | None -> Qq q

(* the field generator α as a qqbar value: the unique real root of mu
   inside (lo, hi) *)
let qq_of_gen (g : gen) : Qqbar.t =
  let inside r =
    Qqbar.cmp_re r (Qqbar.of_q g.lo) > 0
    && Qqbar.cmp_re r (Qqbar.of_q g.hi) < 0
  in
  match List.filter inside (Qqbar.real_roots_of_poly g.mu) with
  | [ r ] -> r
  | _ -> invalid_arg "Num: generator interval does not isolate a root"

let to_qq (x : t) : Qqbar.t =
  match x with
  | Rat q -> Qqbar.of_q q
  | Qq q -> q
  | Field { gen; coords } ->
      (* Horner: coords(α) *)
      let alpha = qq_of_gen gen in
      let acc = ref (Qqbar.of_q Q.zero) in
      for i = Poly.degree coords downto 0 do
        acc := Qqbar.add (Qqbar.mul !acc alpha) (Qqbar.of_q coords.(i))
      done;
      !acc

(* refine a generator's isolating interval once, keeping the unique root by the sign change. *)
let refine_alg (poly : Poly.t) (lo : Q.t) (hi : Q.t) : Q.t * Q.t =
  let m = Q.div (Q.add lo hi) two_q in
  let sl = Poly.sign_at poly lo and sm = Poly.sign_at poly m in
  if sm = 0 then (m, m) (* rational root hit exactly; caller collapses *)
  else if sl * sm < 0 then (lo, m)
  else (m, hi)

(* Simplest rational (smallest denominator; among those, closest to 0) in the
   closed interval [lo, hi], lo ≤ hi. Continued-fraction / Stern–Brocot
   descent: strip the integer part, recurse on the inverted fractional part.
   Terminates in the continued-fraction depth of the endpoints. *)
let rec simplest_in (lo : Q.t) (hi : Q.t) : Q.t =
  if Q.compare lo hi > 0 then invalid_arg "Num.simplest_in: lo > hi"
  else if Q.sign lo <= 0 && Q.sign hi >= 0 then Q.zero
  else if Q.sign hi < 0 then Q.neg (simplest_in (Q.neg hi) (Q.neg lo))
  else begin
    (* 0 < lo ≤ hi *)
    let fl = Z.fdiv (Q.num lo) (Q.den lo) in
    if Q.equal (Q.of_bigint fl) lo then lo
    else if Q.compare (Q.of_bigint (Z.succ fl)) hi <= 0 then
      Q.of_bigint (Z.succ fl)
    else
      let lo' = Q.sub lo (Q.of_bigint fl) and hi' = Q.sub hi (Q.of_bigint fl) in
      Q.add (Q.of_bigint fl) (Q.inv (simplest_in (Q.inv hi') (Q.inv lo')))
  end

(* Rational roots of a ℚ-polynomial lying in [lo,hi]. A rational root in
   lowest terms has denominator dividing the integer-cleared leading
   coefficient aₙ, and two distinct rationals with denominators ≤ aₙ differ
   by at least 1/aₙ². So: isolate the real roots, bisect each isolating
   interval below that separation — then at most one rational with
   denominator ≤ aₙ remains inside, and it is the simplest rational there.
   Verify by exact evaluation. Replaces divisor enumeration by trial
   division, the #23 real_roots wall. *)
let rational_roots_in (p : Poly.t) (lo : Q.t) (hi : Q.t) : Q.t list =
  if Poly.degree p < 1 then []
  else begin
    let s = Poly.squarefree_part p in
    let l = Array.fold_left (fun acc c -> Z.lcm acc (Q.den c)) Z.one s in
    let an = Z.abs (Q.num (Q.mul (Poly.leading s) (Q.of_bigint l))) in
    let sep = Q.make Z.one (Z.mul an an) in
    Poly.isolate_roots s
    |> List.filter_map (fun (a, b) ->
           (* endpoints of isolating intervals are never roots; the single
              root inside is bracketed by a sign change of s. *)
           let rec refine a b =
             if Q.compare (Q.sub b a) sep < 0 then simplest_in a b
             else
               let m = Q.div (Q.add a b) two_q in
               if Poly.sign_at s m = 0 then m
               else if Poly.sign_at s a * Poly.sign_at s m < 0 then refine a m
               else refine m b
           in
           let r = refine a b in
           if Q.equal (Poly.eval s r) Q.zero then Some r else None)
    |> List.filter (fun r -> Q.compare lo r <= 0 && Q.compare r hi <= 0)
    |> List.sort_uniq Q.compare
  end

(* The irreducible minimal polynomial of the unique root of squarefree p in
   (lo,hi), when it can be produced elementarily: divide out rational-root linear
   factors; what remains, if degree 2 or 3 with no rational root, is irreducible
   (a quadratic/cubic with no rational root has no ℚ-factorization). Returns None
   for a composite remainder of degree ≥ 4 (caller keeps the root as Qq). *)
let minimal_poly_in (p : Poly.t) (_lo : Q.t) (_hi : Q.t) : Poly.t option =
  let b = Poly.cauchy_bound p in
  let rats = rational_roots_in p (Q.neg b) b in
  let rest =
    List.fold_left
      (fun acc r -> fst (Poly.divmod acc (Poly.of_list [ Q.neg r; Q.one ])))
      p rats
  in
  let rest = Poly.monic rest in
  let d = Poly.degree rest in
  if d = 2 || d = 3 then Some rest else None

(* Build a value from a defining polynomial and an interval bracketing the
   intended root. Rational roots collapse to Rat; a root whose irreducible
   minimal polynomial is elementarily available at degree 2/3
   (minimal_poly_in) becomes a Field (single-generator fast path); anything
   else becomes a FLINT-backed Qq. *)
let make (poly : Poly.t) (lo : Q.t) (hi : Q.t) : t =
  let s = Poly.squarefree_part poly in
  match rational_roots_in s lo hi with
  | r :: _ -> Rat r
  | [] ->
      (* irrational: tighten until (lo,hi) isolates exactly one root of s *)
      let seq = Poly.sturm_sequence s in
      let rec tighten lo hi =
        if Poly.count_roots_in seq lo hi <= 1 then (lo, hi)
        else
          let m = Q.div (Q.add lo hi) two_q in
          if Poly.count_roots_in seq lo m >= 1 then tighten lo m
          else tighten m hi
      in
      let lo, hi = tighten lo hi in
      (match minimal_poly_in s lo hi with
      | Some mu ->
          Field { gen = { mu; lo; hi }; coords = Poly.of_list [ Q.zero; Q.one ] }
      | None ->
          let inside r =
            Qqbar.cmp_re r (Qqbar.of_q lo) > 0
            && Qqbar.cmp_re r (Qqbar.of_q hi) < 0
          in
          (match List.filter inside (Qqbar.real_roots_of_poly s) with
          | [ r ] -> Qq r
          | _ ->
              (* tighten isolated exactly one root of s in (lo,hi) *)
              assert false))

(* Upgrade an irrational Qq of degree ≤ 3 to the Field fast path: FLINT's
   canonical minimal polynomial is irreducible; refine the certified
   enclosure until it isolates this root of mu (rational endpoints are
   never roots of an irreducible deg-≥2 mu). Deterministic per value. *)
let field_upgrade (x : t) : t =
  match x with
  | Qq q when Qqbar.degree q <= 3 ->
      let mu = Qqbar.minpoly q in
      let seq = Poly.sturm_sequence mu in
      let rec go prec =
        let lo, hi = Qqbar.enclosure q ~prec in
        if
          Poly.count_roots_in seq lo hi = 1
          && Poly.sign_at mu lo <> 0
          && Poly.sign_at mu hi <> 0
        then Field { gen = { mu; lo; hi }; coords = Poly.of_list [ Q.zero; Q.one ] }
        else go (2 * prec)
      in
      go 64
  | x -> x

(* rational enclosure of p over x ∈ [lo,hi], by interval Horner. *)
let poly_interval (p : Poly.t) (lo : Q.t) (hi : Q.t) : Q.t * Q.t =
  let imul (a, b) (c, d) =
    let xs = [ Q.mul a c; Q.mul a d; Q.mul b c; Q.mul b d ] in
    (List.fold_left Q.min (List.hd xs) (List.tl xs),
     List.fold_left Q.max (List.hd xs) (List.tl xs))
  in
  let iadd (a, b) (c, d) = (Q.add a c, Q.add b d) in
  let acc = ref (Q.zero, Q.zero) in
  for i = Poly.degree p downto 0 do
    acc := iadd (imul !acc (lo, hi)) (p.(i), p.(i))
  done;
  !acc

let sign (x : t) : int =
  match x with
  | Rat q -> Q.sign q
  | Qq q -> Qqbar.sign_re q
  | Field { gen; coords } ->
      let rec go lo hi =
        let vlo, vhi = poly_interval coords lo hi in
        if Q.sign vlo > 0 then 1
        else if Q.sign vhi < 0 then -1
        else let lo, hi = refine_alg gen.mu lo hi in go lo hi
      in
      go gen.lo gen.hi

let neg (x : t) : t =
  match x with
  | Rat q -> Rat (Q.neg q)
  | Qq q -> Qq (Qqbar.neg q) (* neg of an irrational is irrational *)
  | Field { gen; coords } -> mk_field gen (Poly.neg coords)

(* enclosure refined to width < w *)
let enclosure_tight (x : t) (w : Q.t) : Q.t * Q.t =
  match x with
  | Rat q -> (q, q)
  | Qq q ->
      let rec go prec =
        let lo, hi = Qqbar.enclosure q ~prec in
        if Q.compare (Q.sub hi lo) w < 0 then (lo, hi) else go (2 * prec)
      in
      go 64
  | Field { gen; coords } ->
      let rec go lo hi =
        let vlo, vhi = poly_interval coords lo hi in
        if Q.compare (Q.sub vhi vlo) w < 0 then (vlo, vhi)
        else let lo, hi = refine_alg gen.mu lo hi in go lo hi
      in
      go gen.lo gen.hi

let to_float (x : t) : float =
  match x with
  | Rat q -> Q.to_float q
  | Qq q -> Qqbar.to_float q
  | Field _ ->
      let w = Q.make Z.one (Z.of_string "1000000000000") in
      let lo, hi = enclosure_tight x w in
      Q.to_float (Q.div (Q.add lo hi) two_q)

let add (x : t) (y : t) : t =
  match (x, y) with
  | Rat a, Rat b -> Rat (Q.add a b)
  | Field a, Field b when same_gen a.gen b.gen ->
      mk_field a.gen (Poly.add a.coords b.coords)
  | Field a, Rat q | Rat q, Field a ->
      mk_field a.gen (Poly.add a.coords (Poly.const q))
  | _ -> of_qq (Qqbar.add (to_qq x) (to_qq y))

let sub (x : t) (y : t) : t = add x (neg y)

let mul (x : t) (y : t) : t =
  match (x, y) with
  | Rat a, Rat b -> Rat (Q.mul a b)
  | _ when sign x = 0 || sign y = 0 -> zero
  | Field a, Field b when same_gen a.gen b.gen ->
      mk_field a.gen (Poly.rem (Poly.mul a.coords b.coords) a.gen.mu)
  | Field a, Rat q | Rat q, Field a -> mk_field a.gen (Poly.scale q a.coords)
  | _ -> of_qq (Qqbar.mul (to_qq x) (to_qq y))

let inv (x : t) : t =
  match x with
  | Rat q ->
      if Q.equal q Q.zero then invalid_arg "Num.inv: zero" else Rat (Q.inv q)
  | Field { gen; coords } -> mk_field gen (Poly.inv_mod coords gen.mu)
  | Qq q -> Qq (Qqbar.inv q) (* Qq is irrational hence nonzero; inv stays irrational *)

let div (x : t) (y : t) : t = mul x (inv y)

let compare (x : t) (y : t) : int = sign (sub x y)
let equal (x : t) (y : t) : bool = sign (sub x y) = 0

(* real roots, ascending, of Σ coeffs.(i)·zⁱ. Rational-coefficient fast path
   keeps axioms 1–6 cheap. For algebraic (Qq) coefficients: manufacture a
   ℚ-superset polynomial R(z) by eliminating each distinct Qq coefficient's
   generator with a Sylvester resultant (Mpoly), then keep only R's roots that
   evaluate P to exactly zero in qqbar (ADR 0013). *)
let real_roots (coeffs : t array) : t list =
  (* normalize Field coefficients to Qq so the rest of the function only sees Rat/Qq *)
  let coeffs =
    Array.map (function Field _ as x -> Qq (to_qq x) | x -> x) coeffs
  in
  (* drop leading zero coefficients to find the true degree *)
  let n = ref (Array.length coeffs) in
  while !n > 0 && sign coeffs.(!n - 1) = 0 do
    decr n
  done;
  let coeffs = Array.sub coeffs 0 !n in
  let n = Array.length coeffs in
  if n <= 1 then [] (* zero polynomial or nonzero constant: no isolated roots *)
  else if Array.for_all (function Rat _ -> true | _ -> false) coeffs then begin
    (* rational fast path (unchanged behaviour) *)
    let q_of = function Rat q -> q | _ -> assert false in
    let p = Poly.of_list (Array.to_list (Array.map q_of coeffs)) in
    (* isolate_roots returns ascending disjoint intervals and make keeps each
       root inside its interval, so the list is already sorted — an exact
       compare-based sort here would refine close roots for nothing (#23). *)
    Poly.isolate_roots p |> List.map (fun (lo, hi) -> make p lo hi)
  end
  else begin
    let coeffs_qq = Array.map to_qq coeffs in
    let eval_p (z : Qqbar.t) : Qqbar.t =
      let acc = ref (Qqbar.of_q Q.zero) in
      for i = Array.length coeffs_qq - 1 downto 0 do
        acc := Qqbar.add (Qqbar.mul !acc z) coeffs_qq.(i)
      done;
      !acc
    in
    (* FLINT 3.6 fast path: _qqbar_roots_poly_squarefree solves degree <= 3
       coefficient-field cubics (axiom 6/7) in ~ms instead of the Mpoly
       elimination's ~28s (ADR 0013). The primitive requires P squarefree —
       for degree <= 3 that's exactly "discriminant nonzero", checked exactly
       in qqbar — and its own degree/bits limits reject fields it can't
       handle (returns None instantly). Every candidate is re-verified with
       the exact eval_p zero check, so a wrong FLINT result can never leak;
       the only fallback risk is a missed root, foreclosed by the
       discriminant guard. *)
    let flint_first () : t list option =
      let d = n - 1 in
      if d > 3 then None
      else begin
        let disc_nonzero =
          match d with
          | 1 -> true
          | 2 ->
              let a = coeffs_qq.(2) and b = coeffs_qq.(1) and c = coeffs_qq.(0) in
              not
                (Qqbar.is_zero
                   (Qqbar.sub (Qqbar.mul b b)
                      (Qqbar.mul (Qqbar.of_q (Q.of_int 4)) (Qqbar.mul a c))))
          | 3 ->
              let a = coeffs_qq.(3) and b = coeffs_qq.(2) and c = coeffs_qq.(1)
              and d0 = coeffs_qq.(0) in
              let k n = Qqbar.of_q (Q.of_int n) in
              let ( * ) = Qqbar.mul and ( - ) = Qqbar.sub and ( + ) = Qqbar.add in
              let disc =
                (k 18 * a * b * c * d0) - (k 4 * b * b * b * d0)
                + (b * b * c * c) - (k 4 * a * c * c * c)
                - (k 27 * a * a * d0 * d0)
              in
              not (Qqbar.is_zero disc)
          | _ -> false
        in
        if not disc_nonzero then None
        else
          match Qqbar.real_roots_of_qqbar_poly coeffs_qq with
          | None -> None
          | Some candidates ->
              (* exact filter: every kept value is provably a root of P *)
              Some
                (candidates
                |> List.filter (fun z -> Qqbar.is_zero (eval_p z))
                |> List.map (fun z -> field_upgrade (of_qq z)))
      end
    in
    let max_deg =
      Array.fold_left (fun m c -> max m (Qqbar.degree c)) 0 coeffs_qq
    in
    let pe_tier () : t list option =
      match Field_merge.merge_generators coeffs_qq with
      | None -> None
      | Some (mu, coords) ->
          let r = Field_merge.resultant_superset ~coords ~mu in
          if Poly.degree r < 1 then None
          else begin
            (* Cheap rigorous pre-screen before the exact eval_p check. R is a
               superset, so many candidates are extraneous; evaluating P at a
               high-degree candidate in qqbar is the dominant cost (~seconds
               each). A rational-interval enclosure of P(z) — from FLINT's
               rigorous qqbar enclosures, via interval Horner — that excludes 0
               proves z is NOT a root, rejecting it without any exact qqbar
               arithmetic. A true root (P(z)=0, interval straddles 0) is never
               rejected; an inconclusive interval falls through to the exact
               check. Purely an optimization: the exact eval_p still decides
               every kept root, so the returned set is identical. *)
            let prec = 128 in
            let qmin a b = if Q.compare a b <= 0 then a else b in
            let qmax a b = if Q.compare a b >= 0 then a else b in
            let coeff_encl = Array.map (fun c -> Qqbar.enclosure c ~prec) coeffs_qq in
            let interval_excludes_zero (z : Qqbar.t) : bool =
              let iadd (a, b) (c, d) = (Q.add a c, Q.add b d) in
              let imul (a, b) (c, d) =
                let p1 = Q.mul a c and p2 = Q.mul a d
                and p3 = Q.mul b c and p4 = Q.mul b d in
                (qmin (qmin p1 p2) (qmin p3 p4), qmax (qmax p1 p2) (qmax p3 p4))
              in
              let zi = Qqbar.enclosure z ~prec in
              let acc = ref (Q.zero, Q.zero) in
              for i = Array.length coeff_encl - 1 downto 0 do
                acc := iadd (imul !acc zi) coeff_encl.(i)
              done;
              let lo, hi = !acc in
              Q.compare lo Q.zero > 0 || Q.compare hi Q.zero < 0
            in
            Some
              (Qqbar.real_roots_of_poly r
              |> List.filter (fun z ->
                     if interval_excludes_zero z then false
                     else Qqbar.is_zero (eval_p z))
              |> List.map (fun z -> field_upgrade (of_qq z)))
          end
    in
    (* Gate: max_deg is the PER-COEFFICIENT degree, not the compositum degree
       [ℚ(γ):ℚ] — a deliberate perf choice, never a correctness one. It only
       decides which tier runs first; every tier ends in the exact eval_p
       filter with the Mpoly path as terminal fallback, so a "wrong" gate can
       at worst pick a slower path. flint_first's own d>3 guard independently
       routes quartics-plus to pe_tier regardless of this threshold. *)
    let tier12 = if max_deg < 5 then flint_first () else None in
    match tier12 with
    | Some roots -> roots
    | None -> (
        match pe_tier () with
        | Some roots -> roots
        | None ->
    (* fallback: generator elimination (Mpoly) + exact verification.
       Assign generator variables to distinct algebraic numbers in the coefficient
       set. Variable 0 is z; generators are 1.. .
       Key optimisation: if c = a + q·gen for rationals a,q (affine combination),
       express the coefficient as const(a) + const(q)·gen_var rather than allocating
       a new variable. This collapses e.g. {−√2, 1−√2, 1} all into one generator
       (√2), keeping the Sylvester matrix small.
       Scalar multiple (a=0) and exact identity (a=0,q=1) are special cases.
       Affine extraction for degree-2 generators uses pure rational arithmetic on
       polynomial coefficients (no Num resultant calls):
         If gen.poly = [s_g; p_g; 1] and c.poly = [s_c; p_c; 1], both monic degree-2,
         then c = a + q·gen has:
           q² = disc_c / disc_gen  (discriminants disc = p² - 4s)
           a  = (-p_c + q·p_g) / 2 (from trace identity: c+c̄ = -p_c = 2a + q·(-p_g))
         q must be rational, and disc_c/disc_gen a perfect rational square.
         To confirm the sign of q (not just q²), we check against the enclosures.
       Falls through to a fresh generator for higher-degree or non-monic cases. *)
    (* Table: (gen_value, var_index, gen_minpoly) in discovery order *)
    let gens : (Qqbar.t * int * Poly.t) list ref = ref [] in
    (* Try to express q as an exact rational from disc_c / disc_gen.
       disc must be a perfect square in ℚ: disc = (p/q)² → num/den both perfect int squares. *)
    let rational_sqrt_q (r : Q.t) : Q.t option =
      if Q.sign r < 0 then None
      else if Q.sign r = 0 then Some Q.zero
      else begin
        let n = Q.num r and d = Q.den r in
        (* Zarith: n and d are Z.t; Z.sqrt_rem gives (floor_sqrt, rem) *)
        let sn, rn = Z.sqrt_rem (Z.abs n) in
        let sd, rd = Z.sqrt_rem d in
        if Z.equal rn Z.zero && Z.equal rd Z.zero then
          Some (Q.make sn sd)
        else None
      end
    in
    (* For irrational c, try to find an existing generator g with
       c = a + q·g for rationals a, q. Exact identity via Qqbar.equal;
       the degree-2 affine extraction reads the monic minimal polynomials
       (disc_c/disc_g must be a perfect rational square), and candidates
       are verified exactly in qqbar. *)
    let find_affine_combination (c : Qqbar.t) : (int * Q.t * Q.t) option =
      List.find_map
        (fun (g, v, mu_g) ->
          if Qqbar.equal g c then Some (v, Q.zero, Q.one)
          else if Qqbar.degree g <> 2 || Qqbar.degree c <> 2 then None
          else begin
            let mu_c = Qqbar.minpoly c in
            let p_g = mu_g.(1) and s_g = mu_g.(0) in
            let p_c = mu_c.(1) and s_c = mu_c.(0) in
            let disc_g = Q.sub (Q.mul p_g p_g) (Q.mul (Q.of_int 4) s_g) in
            let disc_c = Q.sub (Q.mul p_c p_c) (Q.mul (Q.of_int 4) s_c) in
            if Q.sign disc_g = 0 then None
            else
              match rational_sqrt_q (Q.div disc_c disc_g) with
              | None -> None
              | Some q_abs when Q.sign q_abs = 0 -> None
              | Some q_abs ->
                  let try_q q_signed =
                    let a_signed =
                      Q.div (Q.add (Q.neg p_c) (Q.mul q_signed p_g)) two_q
                    in
                    let candidate =
                      Qqbar.add (Qqbar.of_q a_signed)
                        (Qqbar.mul (Qqbar.of_q q_signed) g)
                    in
                    if Qqbar.equal c candidate then Some (v, a_signed, q_signed)
                    else None
                  in
                  (match try_q q_abs with
                  | Some _ as r -> r
                  | None -> try_q (Q.neg q_abs))
          end)
        !gens
    in
    (* For each distinct algebraic number (not an affine combination of an existing
       generator), add a new generator. *)
    Array.iter
      (fun c ->
        match c with
        | Rat _ -> ()
        | Field _ -> assert false (* normalized at entry *)
        | Qq cq ->
            if find_affine_combination cq = None then
              gens := !gens @ [ (cq, 1 + List.length !gens, Qqbar.minpoly cq) ])
      coeffs;
    let nvars = 1 + List.length !gens in
    (* Build P as an Mpoly in [nvars] variables (var 0 = z, vars 1..nvars-1 = gens). *)
    let build_p_mpoly () =
      let zv = Mpoly.var nvars 0 in
      let cm c =
        match c with
        | Rat q -> Mpoly.const nvars q
        | Field _ -> assert false (* normalized at entry *)
        | Qq cq ->
            (match find_affine_combination cq with
            | Some (v, a, q) ->
                Mpoly.add (Mpoly.const nvars a)
                  (Mpoly.mul (Mpoly.const nvars q) (Mpoly.var nvars v))
            | None -> assert false (* every Qq coefficient was registered *))
      in
      let pm = ref Mpoly.zero in
      for i = 0 to n - 1 do
        pm := Mpoly.add !pm (Mpoly.mul (cm coeffs.(i)) (Mpoly.pow zv i))
      done;
      !pm
    in
    (* Build a min-poly Mpoly for generator at variable v, in nvars-variable space. *)
    let build_minpoly_mpoly v minpoly =
      let m = ref Mpoly.zero in
      Array.iteri
        (fun k q ->
          m := Mpoly.add !m
            (Mpoly.mul (Mpoly.const nvars q) (Mpoly.pow (Mpoly.var nvars v) k)))
        minpoly;
      !m
    in
    (* Build R: eliminate generators from P in nvars-variable space → ℚ[z]. *)
    let p_mpoly = build_p_mpoly () in
    let w = ref p_mpoly in
    List.iter
      (fun (_, v, minpoly) ->
        w := Mpoly.resultant !w (build_minpoly_mpoly v minpoly) v)
      !gens;
    let r = Mpoly.to_poly_in !w 0 in
    if Poly.degree r < 1 then []
    else begin
      (* R is a ℚ-superset: every true root of P is among R's roots. Get the
         candidates exactly from FLINT and keep those where P evaluates to
         exactly zero in qqbar — no separation bound, no H(Y) construction,
         no interval refinement (the former certify pipeline's Mpoly Laplace
         resultants were the measured 48s/900s wall; ADR 0013). coeffs_qq and
         eval_p are defined above, shared with flint_first. *)
      (* FLINT handles the non-squarefree superset R directly; the naive
         ℚ-gcd squarefree pass on a fat deg-81 R was a measured wall. Repeated
         roots produce duplicate entries, which real_roots_of_poly deduplicates
         exactly (cmp_re = 0 iff equal). *)
      Qqbar.real_roots_of_poly r
      |> List.filter (fun z -> Qqbar.is_zero (eval_p z))
      |> List.map (fun z -> field_upgrade (of_qq z))
    end)
  end

(* √x, exact: rational results collapse (√4 = 2); irrational square roots
   stay Qq (see the "results stay Qq" note in this task's interface block). *)
let sqrt (x : t) : t =
  if sign x < 0 then invalid_arg "Num.sqrt: negative argument";
  if sign x = 0 then zero else of_qq (Qqbar.sqrt (to_qq x))
