(** Exact real algebraic numbers. A value is either an exact rational [Rat q]
    (fast-path: axioms 1–4 never leave ℚ) or [Alg {poly; lo; hi}] — the unique
    real root of the squarefree ℚ-polynomial [poly] inside the open interval
    [(lo, hi)]. Invariants for [Alg]: [poly] is squarefree, has exactly one root
    in [(lo, hi)], and that root is irrational (so it is never 0). Arithmetic
    builds the result's defining polynomial by resultant-via-interpolation and
    re-isolates; sign/compare refine the interval; [equal x y] is
    [sign (sub x y) = 0]. [to_float] is the only float, output-only.
    Algorithms: [bpr2006]. Field theory: [justin1986 §8.4d], [hull2020]. *)

type t =
  | Rat of Q.t
  | Alg of { poly : Poly.t; lo : Q.t; hi : Q.t }
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

(* Forward reference so that defpoly / enclosure / enclosure_tight / to_float /
   sqrt can all call to_alg without being inside the arithmetic rec group. *)
let to_alg_ref : (t -> t) ref = ref (fun x -> x)

(* defining polynomial of a value (x − q for a rational). *)
let rec defpoly (x : t) : Poly.t =
  match x with
  | Rat q -> Poly.of_list [ Q.neg q; Q.one ]
  | Alg a -> a.poly
  | Field _ -> defpoly (!to_alg_ref x)

(* a rational enclosure [lo,hi] of the value; tight for rationals. *)
let rec enclosure (x : t) : Q.t * Q.t =
  match x with
  | Rat q -> (q, q)
  | Alg a -> (a.lo, a.hi)
  | Field _ -> enclosure (!to_alg_ref x)

(* refine an Alg interval once, keeping the unique root by the sign change. *)
let refine_alg (poly : Poly.t) (lo : Q.t) (hi : Q.t) : Q.t * Q.t =
  let m = Q.div (Q.add lo hi) two_q in
  let sl = Poly.sign_at poly lo and sm = Poly.sign_at poly m in
  if sm = 0 then (m, m) (* rational root hit exactly; caller collapses *)
  else if sl * sm < 0 then (lo, m)
  else (m, hi)

(* integer divisors of |n| (n ≠ 0). *)
let divisors (n : Z.t) : Z.t list =
  let n = Z.abs n in
  let rec go i acc =
    if Z.gt (Z.mul i i) n then acc
    else
      let acc =
        if Z.equal (Z.rem n i) Z.zero then
          let j = Z.div n i in
          if Z.equal i j then i :: acc else i :: j :: acc
        else acc
      in
      go (Z.succ i) acc
  in
  go Z.one []

(* rational roots of a ℚ-polynomial lying in [lo,hi], via the rational-root
   theorem after clearing denominators to ℤ. *)
let rational_roots_in (p : Poly.t) (lo : Q.t) (hi : Q.t) : Q.t list =
  if Poly.degree p < 1 then []
  else begin
    (* clear denominators: multiply by lcm of all denominators *)
    let l = Array.fold_left (fun acc c -> Z.lcm acc (Q.den c)) Z.one p in
    let ip = Array.map (fun c -> Q.num (Q.mul c (Q.of_bigint l))) p in
    let a0 = ip.(0) and an = ip.(Array.length ip - 1) in
    let cand =
      if Z.equal a0 Z.zero then [ Q.zero ]
      else
        let ps = divisors a0 and qs = divisors an in
        List.concat_map
          (fun pnum ->
            List.concat_map
              (fun qden ->
                let r = Q.make pnum qden in
                [ r; Q.neg r ])
              qs)
          ps
    in
    List.filter
      (fun r ->
        Q.compare lo r <= 0 && Q.compare r hi <= 0 && Q.equal (Poly.eval p r) Q.zero)
      cand
    |> List.sort_uniq Q.compare
  end

(* The irreducible minimal polynomial of the unique root of squarefree p in
   (lo,hi), when it can be produced elementarily: divide out rational-root linear
   factors; what remains, if degree 2 or 3 with no rational root, is irreducible
   (a quadratic/cubic with no rational root has no ℚ-factorization). Returns None
   for a composite remainder of degree ≥ 4 (caller keeps the root as Alg). *)
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

(* Build a value from a defining polynomial and an interval that brackets the
   intended root. Collapses to Rat when the root is rational (critically, 0). *)
let make (poly : Poly.t) (lo : Q.t) (hi : Q.t) : t =
  let s = Poly.squarefree_part poly in
  match rational_roots_in s lo hi with
  | r :: _ -> Rat r
  | [] ->
      (* refine until the interval isolates exactly one root of s and excludes
         0 (the value is irrational here, so this terminates). *)
      let seq = Poly.sturm_sequence s in
      let rec tighten lo hi =
        if Poly.count_roots_in seq lo hi <= 1 then (lo, hi)
        else
          let m = Q.div (Q.add lo hi) two_q in
          if Poly.count_roots_in seq lo m >= 1 then tighten lo m
          else tighten m hi
      in
      let lo, hi = tighten lo hi in
      Alg { poly = s; lo; hi }

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

let rec sign (x : t) : int =
  match x with
  | Rat q -> Q.sign q
  | Field { gen; coords } ->
      let rec go lo hi =
        let vlo, vhi = poly_interval coords lo hi in
        if Q.sign vlo > 0 then 1
        else if Q.sign vhi < 0 then -1
        else let lo, hi = refine_alg gen.mu lo hi in go lo hi
      in
      go gen.lo gen.hi
  | Alg { poly; lo; hi } ->
      if Q.sign lo > 0 then 1
      else if Q.sign hi < 0 then -1
      else
        let lo, hi = refine_alg poly lo hi in
        sign (Alg { poly; lo; hi })

let neg (x : t) : t =
  match x with
  | Rat q -> Rat (Q.neg q)
  | Field { gen; coords } -> mk_field gen (Poly.neg coords)
  | Alg { poly; lo; hi } ->
      (* root of poly(−x); interval is the reflection *)
      let n = Array.length poly in
      let p' =
        Poly.of_list
          (List.init n (fun i ->
               if i mod 2 = 0 then poly.(i) else Q.neg poly.(i)))
      in
      make p' (Q.neg hi) (Q.neg lo)

(* enclosure refined to width < w *)
let rec enclosure_tight (x : t) (w : Q.t) : Q.t * Q.t =
  match x with
  | Rat q -> (q, q)
  | Field _ -> enclosure_tight (!to_alg_ref x) w
  | Alg { poly; lo; hi } ->
      let rec go lo hi =
        if Q.compare (Q.sub hi lo) w < 0 then (lo, hi)
        else
          let lo, hi = refine_alg poly lo hi in
          go lo hi
      in
      go lo hi

(* Given the result's defining polynomial R and a procedure that returns an
   arbitrarily tight rational enclosure of the true result value, select the
   matching root of R and return the value. *)
let select_root (r : Poly.t) (enclose : Q.t -> Q.t * Q.t) : t =
  let s = Poly.squarefree_part r in
  (* 0 is the value iff s(0)=0 and the enclosure straddles 0 *)
  let lo0, hi0 = enclose Q.one in
  if Poly.sign_at s Q.zero = 0 && Q.compare lo0 Q.zero <= 0 && Q.compare Q.zero hi0 <= 0
  then zero
  else begin
    let intervals = Poly.isolate_roots s in
    let two = Q.of_int 2 in
    let rec pick width =
      let lo, hi = enclose width in
      let hits =
        List.filter (fun (a, b) -> Q.compare a hi < 0 && Q.compare lo b < 0) intervals
      in
      match hits with
      | [ (a, b) ] ->
          let lo = Q.max lo a and hi = Q.min hi b in
          make s lo hi
      | _ -> pick (Q.div width two)
    in
    pick (Q.of_int 1)
  end

(* Resultant_y(A(x−y), B(y)) as a ℚ[x]-polynomial, by evaluation+interpolation:
   sample at x = 0..D, take numeric resultants, Lagrange-interpolate. *)
let res_interp (combine : Q.t -> Poly.t) (b : Poly.t) (dbound : int) : Poly.t =
  let pts =
    List.init (dbound + 1) (fun k ->
        let xk = Q.of_int k in
        (xk, Poly.resultant (combine xk) b))
  in
  Poly.interpolate pts

let defpoly_sum (a : t) (b : t) : Poly.t =
  let pa = defpoly a and pb = defpoly b in
  let d = Poly.degree pa * Poly.degree pb in
  (* A(x−y) at x=k is A(k−y): compose A with (k − y) *)
  let combine k = Poly.compose pa (Poly.of_list [ k; Q.neg Q.one ]) in
  res_interp combine pb d

let defpoly_prod (a : t) (b : t) : Poly.t =
  let pa = defpoly a and pb = defpoly b in
  let da = Poly.degree pa in
  let d = da * Poly.degree pb in
  (* y^{da} · A(k/y) at x=k : coefficient a_i k^i sits on y^{da−i} *)
  let combine k =
    Poly.of_list
      (List.init (da + 1) (fun j ->
           let i = da - j in
           Q.mul pa.(i) (Poly.qpow k i)))
  in
  res_interp combine pb d

(* fast path: shift an Alg by a rational — poly(x−q), interval shifted. *)
let shift_alg (poly : Poly.t) (lo : Q.t) (hi : Q.t) (q : Q.t) : t =
  let p' = Poly.compose poly (Poly.of_list [ Q.neg q; Q.one ]) in
  make p' (Q.add lo q) (Q.add hi q)

(* fast path: scale an Alg by a nonzero rational — poly(x/q), interval scaled. *)
let scale_alg (poly : Poly.t) (lo : Q.t) (hi : Q.t) (q : Q.t) : t =
  let p' = Poly.compose poly (Poly.of_list [ Q.zero; Q.inv q ]) in
  if Q.sign q > 0 then make p' (Q.mul q lo) (Q.mul q hi)
  else make p' (Q.mul q hi) (Q.mul q lo)

(* Squaring shortcut for even polys: if pa(x) = r(x²), then if a has defpoly pa,
   a² has defpoly r (since pa(a)=0 ↔ r(a²)=0). Extract r by taking even-indexed
   coefficients: r.(i) = pa.(2*i). Only valid when all odd-indexed coeffs are 0. *)
let even_poly_half (pa : Poly.t) : Poly.t option =
  let n = Array.length pa in
  if n = 0 then Some Poly.zero
  else begin
    (* check all odd-indexed coefficients are 0 *)
    let ok = ref true in
    for i = 0 to n - 1 do
      if i mod 2 = 1 && not (Q.equal pa.(i) Q.zero) then ok := false
    done;
    if not !ok then None
    else begin
      (* r.(i) = pa.(2*i) for i = 0, 1, ..., floor((n-1)/2) *)
      let m = (n + 1) / 2 in
      Some (Poly.of_list (List.init m (fun i -> pa.(2 * i))))
    end
  end

let rec add (x : t) (y : t) : t =
  match (x, y) with
  | Rat a, Rat b -> Rat (Q.add a b)
  | Field a, Field b when same_gen a.gen b.gen ->
      mk_field a.gen (Poly.add a.coords b.coords)
  | Field a, Rat q | Rat q, Field a ->
      mk_field a.gen (Poly.add a.coords (Poly.const q))
  | (Field _, _) | (_, Field _) -> add (to_alg x) (to_alg y)
  | Alg a, Rat q | Rat q, Alg a -> shift_alg a.poly a.lo a.hi q
  | Alg _, Alg _ ->
      let r = defpoly_sum x y in
      let enclose w =
        let xl, xh = enclosure_tight x (Q.div w two_q) in
        let yl, yh = enclosure_tight y (Q.div w two_q) in
        (Q.add xl yl, Q.add xh yh)
      in
      select_root r enclose

and sub (x : t) (y : t) : t = add x (neg y)

and mul (x : t) (y : t) : t =
  (* Enclosure of a product from tightened operand enclosures (sign-aware):
     lo/hi = min/max of the four corner products. *)
  let product_enclose x y w =
    let xl, xh = enclosure_tight x w in
    let yl, yh = enclosure_tight y w in
    let prods = [ Q.mul xl yl; Q.mul xl yh; Q.mul xh yl; Q.mul xh yh ] in
    ( List.fold_left Q.min (List.hd prods) (List.tl prods),
      List.fold_left Q.max (List.hd prods) (List.tl prods) )
  in
  match (x, y) with
  | Rat a, Rat b -> Rat (Q.mul a b)
  | _ when sign x = 0 || sign y = 0 -> zero
  | Field a, Field b when same_gen a.gen b.gen ->
      mk_field a.gen (Poly.rem (Poly.mul a.coords b.coords) a.gen.mu)
  | Field a, Rat q | Rat q, Field a -> mk_field a.gen (Poly.scale q a.coords)
  | (Field _, _) | (_, Field _) -> mul (to_alg x) (to_alg y)
  | Alg a, Rat q | Rat q, Alg a -> scale_alg a.poly a.lo a.hi q
  | Alg ax, Alg ay
    when ax.poly == ay.poly
         && Q.equal ax.lo ay.lo
         && Q.equal ax.hi ay.hi ->
      (* Squaring shortcut: x and y are provably the same Alg root.
         Guard: physically-equal poly array + identical interval endpoints.
         Two distinct roots of the same polynomial cannot share both endpoints,
         so this is a sound same-value test regardless of how Alg values are
         constructed (e.g. if a future change copies a record with {a with …}).
         If the guard does not fire, mul falls through to the exact resultant
         path below, which is correct but slower — so mis-firing is the only risk.
         If pa is even (pa(x)=r(x²)), then a² has defpoly r, with a² ∈ (lo²,hi²). *)
      (match even_poly_half ax.poly with
      | Some r ->
          let lo_sq = Q.mul ax.lo ax.lo and hi_sq = Q.mul ax.hi ax.hi in
          (* lo and hi both > 0 (irrational algebraic roots from sqrt are positive
             when lo > 0; if straddling 0, fall back). *)
          if Q.sign ax.lo > 0 then make r lo_sq hi_sq
          else
            (* fall back: use the full resultant path *)
            let r_full = defpoly_prod x y in
            select_root r_full (product_enclose x y)
      | None ->
          (* Not even; fall through to the general path *)
          let r_full = defpoly_prod x y in
          select_root r_full (product_enclose x y))
  | _ ->
      let r = defpoly_prod x y in
      select_root r (product_enclose x y)

and inv (x : t) : t =
  match x with
  | Rat q -> if Q.equal q Q.zero then invalid_arg "Num.inv: zero" else Rat (Q.inv q)
  | Field { gen; coords } -> mk_field gen (Poly.inv_mod coords gen.mu)
  | Alg _ ->
      if sign x = 0 then invalid_arg "Num.inv: zero";
      (* root of the reversed polynomial; enclosure is 1/[lo,hi] *)
      let p = defpoly x in
      let rev = Poly.of_list (List.rev (Array.to_list p)) in
      let enclose w =
        let lo, hi = enclosure_tight x w in
        (* x is bounded away from 0 (sign≠0); both ends share its sign *)
        (Q.inv hi, Q.inv lo)
      in
      select_root rev enclose

and div (x : t) (y : t) : t = mul x (inv y)

(* Field → Alg: evaluate coords at α (an Alg built from μ + interval) using the
   existing resultant arithmetic. The slow fallback; correctness baseline. *)
and to_alg (x : t) : t =
  match x with
  | Field { gen; coords } ->
      let alpha = make gen.mu gen.lo gen.hi in
      let acc = ref zero in
      for i = Poly.degree coords downto 0 do
        acc := add (mul !acc alpha) (of_q coords.(i))
      done;
      !acc
  | _ -> x

let () = to_alg_ref := to_alg

let compare (x : t) (y : t) : int = sign (sub x y)
let equal (x : t) (y : t) : bool = sign (sub x y) = 0

(* Interval-arithmetic evaluation of Σ coeffs.(i)·zⁱ at a rational interval
   [lz,hz] for z, with each coefficient's enclosure supplied by [enclose_c].
   Returns the interval [la, ha] containing the polynomial's value.
   Uses Horner with interval coefficients over ℚ. *)
let poly_value_interval (coeffs : t array) (enclose_c : t -> Q.t * Q.t)
    (lz : Q.t) (hz : Q.t) : Q.t * Q.t =
  (* interval multiplication [la,ha]·[lb,hb] *)
  let imul la ha lb hb =
    let products = [Q.mul la lb; Q.mul la hb; Q.mul ha lb; Q.mul ha hb] in
    List.fold_left Q.min (List.hd products) (List.tl products),
    List.fold_left Q.max (List.hd products) (List.tl products)
  in
  (* interval addition *)
  let iadd la ha lb hb = Q.add la lb, Q.add ha hb in
  let n = Array.length coeffs in
  let la = ref Q.zero and ha = ref Q.zero in
  for i = n - 1 downto 0 do
    (* acc := acc * z + coeffs.(i) *)
    let lm, hm = imul !la !ha lz hz in
    let lc, hc = enclose_c coeffs.(i) in
    let lr, hr = iadd lm hm lc hc in
    la := lr; ha := hr
  done;
  (!la, !ha)

(* Certify that candidate root z₀ (given as polynomial r and rational enclosure
   [lz,hz]) is a genuine root of P (with coefficients [coeffs]).
   Uses rational interval arithmetic with a proven separation bound b: any nonzero
   value of P at a root of R has |P(z₀)| ≥ b (Cauchy bound on nonzero roots of H).
   Hence if the interval [la,ha] around P(z₀) contains 0 and has width < b, then
   |P(z₀)| < b, which forces P(z₀) = 0 → genuine root.
   Terminates: spurious roots eventually have their interval exclude 0; genuine roots
   shrink below b. *)
let certify (coeffs : t array) (r : Poly.t) (lz : Q.t) (hz : Q.t)
    (b : Q.t) : bool =
  let z0 = make r lz hz in
  let width = ref (Q.sub hz lz) in
  let two_q_local = Q.of_int 2 in
  let rec loop () =
    let lz_t, hz_t = enclosure_tight z0 !width in
    let enclose_c c = enclosure_tight c !width in
    let la, ha = poly_value_interval coeffs enclose_c lz_t hz_t in
    if Q.sign ha < 0 || Q.sign la > 0 then
      (* Interval excludes 0: P(actual_coeff, z₀) ≠ 0 → spurious root. *)
      false
    else if Q.compare (Q.sub ha la) b < 0 then
      (* Interval width < b and 0 ∈ [la,ha]: |P(z₀)| < b impossible for a nonzero
         value, so P(z₀) = 0 → genuine root. *)
      true
    else begin
      width := Q.div !width two_q_local;
      loop ()
    end
  in
  loop ()

(* real roots, ascending, of Σ coeffs.(i)·zⁱ. Rational-coefficient fast path
   keeps axioms 1–6 cheap. For algebraic (Alg) coefficients: manufacture a
   ℚ-superset polynomial R(z) by eliminating each distinct Alg coefficient's
   generator with a Sylvester resultant (Mpoly), isolate R's real roots, then
   keep only those that are genuine roots of the original polynomial — certified
   by rational interval evaluation before falling back to exact Num arithmetic.
   [bpr2006 §§4.2, 10.2–10.3] *)
let real_roots (coeffs : t array) : t list =
  (* normalize Field coefficients to Alg so the rest of the function only sees Rat/Alg *)
  let coeffs = Array.map (function Field _ as x -> to_alg x | x -> x) coeffs in
  (* drop leading zero coefficients to find the true degree *)
  let n = ref (Array.length coeffs) in
  while !n > 0 && sign coeffs.(!n - 1) = 0 do
    decr n
  done;
  let coeffs = Array.sub coeffs 0 !n in
  let n = Array.length coeffs in
  (* Upgrade an irrational Alg root to Field when its irreducible minimal
     polynomial can be produced elementarily (degree 2 or 3 with no rational root). *)
  let upgrade (v : t) : t =
    match v with
    | Alg { poly; lo; hi } -> (
        match minimal_poly_in poly lo hi with
        | Some mu -> Field { gen = { mu; lo; hi }; coords = Poly.of_list [ Q.zero; Q.one ] }
        | None -> v)
    | _ -> v
  in
  if n <= 1 then [] (* zero polynomial or nonzero constant: no isolated roots *)
  else if Array.for_all (function Rat _ -> true | Alg _ | Field _ -> false) coeffs then begin
    (* rational fast path (unchanged behaviour) *)
    let q_of = function Rat q -> q | Alg _ | Field _ -> assert false in
    let p = Poly.of_list (Array.to_list (Array.map q_of coeffs)) in
    Poly.isolate_roots p |> List.map (fun (lo, hi) -> make p lo hi) |> List.sort compare
    |> List.map upgrade
  end
  else begin
    (* Assign generator variables to distinct algebraic numbers in the coefficient
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
    let gens = ref [] in
    (* Check structural identity of two Alg values. *)
    let alg_equal (x : Poly.t * Q.t * Q.t) (y : Poly.t * Q.t * Q.t) =
      let px, lx, hx = x and py, ly, hy = y in
      Q.equal lx ly && Q.equal hx hy
      && Array.length px = Array.length py
      && Array.for_all2 Q.equal px py
    in
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
    (* For Alg c, try to find an existing generator gen such that c = a + q·gen
       for rationals a, q. Return Some (v, a, q) if found.
       Strategy:
         1. Exact structural identity → (v, 0, 1).
         2. Affine/scalar (degree-2 generators, pure rational poly arithmetic):
            compute disc_c, disc_gen; if disc_c/disc_gen is a perfect rational square,
            extract q from q²=disc_c/disc_gen (disambiguate sign via enclosures),
            then a = (-p_c + q·p_g)/2. Verify that a is indeed rational (always is if
            the discriminants match, but we double-check the expression).
       Returns None if c is not in ℚ(gen) or gen/c are not monic degree exactly 2. *)
    let find_affine_combination (c : t) : (int * Q.t * Q.t) option =
      match c with
      | Rat _ | Field _ -> None
      | Alg ac ->
          List.find_map
            (fun (gen, v, _minpoly) ->
              match gen with
              | Rat _ | Field _ -> None
              | Alg ag ->
                  (* Fast path: structurally identical → a=0, q=1 *)
                  if alg_equal (ag.poly, ag.lo, ag.hi) (ac.poly, ac.lo, ac.hi) then
                    Some (v, Q.zero, Q.one)
                  else if Array.length ag.poly <> 3 || Array.length ac.poly <> 3 then
                    None
                  else begin
                    (* Both are monic degree-2: gen.poly = [s_g; p_g; 1], c.poly = [s_c; p_c; 1] *)
                    let p_g = ag.poly.(1) and s_g = ag.poly.(0) in
                    let p_c = ac.poly.(1) and s_c = ac.poly.(0) in
                    let disc_g = Q.sub (Q.mul p_g p_g) (Q.mul (Q.of_int 4) s_g) in
                    let disc_c = Q.sub (Q.mul p_c p_c) (Q.mul (Q.of_int 4) s_c) in
                    if Q.sign disc_g = 0 then None  (* gen would be rational — shouldn't happen *)
                    else
                      (* q² = disc_c / disc_g must be a perfect rational square *)
                      let q_sq = Q.div disc_c disc_g in
                      match rational_sqrt_q q_sq with
                      | None -> None  (* disc_c/disc_g is not a perfect square → different fields *)
                      | Some q_abs ->
                          if Q.sign q_abs = 0 then None  (* c would be rational — handled above *)
                          else begin
                            (* a = (-p_c + q·p_g) / 2 (exact ℚ computation, always rational) *)
                            let two = Q.of_int 2 in
                            let try_q q_signed =
                              let a_signed = Q.div (Q.add (Q.neg p_c) (Q.mul q_signed p_g)) two in
                              (* Exact check: c = a + q·gen iff c − a − q·gen = 0.
                                 sub c (add (of_q a) (scale_alg gen q)) collapses to Rat 0
                                 when c truly equals a + q·gen.
                                 For the wrong sign this is 2·q·gen (irrational). *)
                              let candidate = add (of_q a_signed) (scale_alg ag.poly ag.lo ag.hi q_signed) in
                              if sign (sub c candidate) = 0 then
                                Some (v, a_signed, q_signed)
                              else None
                            in
                            match try_q q_abs with
                            | Some _ as r -> r
                            | None -> try_q (Q.neg q_abs)
                          end
                  end)
            !gens
    in
    (* For each distinct algebraic number (not an affine combination of an existing
       generator), add a new generator. *)
    Array.iter
      (fun c ->
        match c with
        | Rat _ | Field _ -> ()
        | Alg a ->
            let affine = find_affine_combination c in
            if affine = None then
              gens := !gens @ [ (c, 1 + List.length !gens, a.poly) ])
      coeffs;
    let nvars = 1 + List.length !gens in
    (* Build P as an Mpoly in [nvars] variables (var 0 = z, vars 1..nvars-1 = gens).
       Also build it in [nvars_y = nvars+1] space for the H(Y) construction,
       where var [nvars] will be Y. *)
    let build_p_mpoly nv =
      let zv = Mpoly.var nv 0 in
      let cm c =
        match c with
        | Rat q -> Mpoly.const nv q
        | Field _ -> assert false (* converted to Alg at real_roots entry *)
        | Alg _ ->
            (match find_affine_combination c with
            | Some (v, a, q) ->
                (* c = a + q·gen_v  →  const(a) + const(q)·var(v) *)
                Mpoly.add (Mpoly.const nv a)
                  (Mpoly.mul (Mpoly.const nv q) (Mpoly.var nv v))
            | None -> assert false)
      in
      let pm = ref Mpoly.zero in
      for i = 0 to n - 1 do
        pm := Mpoly.add !pm (Mpoly.mul (cm coeffs.(i)) (Mpoly.pow zv i))
      done;
      !pm
    in
    (* Build a min-poly Mpoly for generator at variable v, in [nv]-variable space. *)
    let build_minpoly_mpoly nv v minpoly =
      let m = ref Mpoly.zero in
      Array.iteri
        (fun k q ->
          m := Mpoly.add !m
            (Mpoly.mul (Mpoly.const nv q) (Mpoly.pow (Mpoly.var nv v) k)))
        minpoly;
      !m
    in
    (* Build R: eliminate generators from P in nvars-variable space → ℚ[z]. *)
    let p_mpoly = build_p_mpoly nvars in
    let w = ref p_mpoly in
    List.iter
      (fun (_, v, minpoly) ->
        w := Mpoly.resultant !w (build_minpoly_mpoly nvars v minpoly) v)
      !gens;
    let r = Mpoly.to_poly_in !w 0 in
    if Poly.degree r < 1 then []
    else begin
      (* Build H(Y) ∈ ℚ[Y]: the polynomial whose roots include all values
         {P(ζ) : ζ a root of R}.  Y is variable index [nvars] in a
         (nvars+1)-variable space. *)
      let nvars_y = nvars + 1 in
      let y_var = nvars in         (* index of Y in nvars_y-space *)
      let p_mpoly_y = build_p_mpoly nvars_y in
      (* W_h = Y - P(z, gens) *)
      let w_h = ref (Mpoly.sub (Mpoly.var nvars_y y_var) p_mpoly_y) in
      (* Eliminate each generator from W_h. *)
      List.iter
        (fun (_, v, minpoly) ->
          w_h := Mpoly.resultant !w_h (build_minpoly_mpoly nvars_y v minpoly) v)
        !gens;
      (* Lift R (∈ ℚ[z]) into the nvars_y-variable space, then eliminate z. *)
      let r_mpoly_y =
        let zv = Mpoly.var nvars_y 0 in
        let rm = ref Mpoly.zero in
        Array.iteri
          (fun k q ->
            rm := Mpoly.add !rm
              (Mpoly.mul (Mpoly.const nvars_y q) (Mpoly.pow zv k)))
          r;
        !rm
      in
      w_h := Mpoly.resultant !w_h r_mpoly_y 0;
      (* Extract H as a ℚ[Y] polynomial. *)
      let h = Mpoly.to_poly_in !w_h y_var in
      (* Soundness invariant: H is never the zero polynomial. real_roots returns []
         before this point when Poly.degree r < 1, so R has at least one root,
         meaning P evaluated at that root yields a value, making H nontrivial. *)
      assert (Array.length h > 0);
      (* Cauchy lower bound on the smallest nonzero |root| of H.
         Strip leading zero-power factors (corresponding to genuine zero values):
         find the smallest k with h.(k) ≠ 0. Then B = |h0| / (|h0| + max_{i>k}|h.(i)|).
         Any nonzero root Y of H satisfies |Y| ≥ B. *)
      let hlen = Array.length h in
      let k = ref 0 in
      while !k < hlen && Q.equal h.(!k) Q.zero do incr k done;
      let b =
        if !k >= hlen - 1 then
          (* H is zero or a monomial in Y: no nonzero roots, any positive B works. *)
          Q.one
        else begin
          let h0 = Q.abs h.(!k) in
          let m = ref Q.zero in
          for i = !k + 1 to hlen - 1 do
            m := Q.max !m (Q.abs h.(i))
          done;
          (* B = |h0| / (|h0| + m); guaranteed > 0 since |h0| > 0 *)
          Q.div h0 (Q.add h0 !m)
        end
      in
      (* isolate R's real roots; keep those that are genuine roots of P *)
      Poly.isolate_roots r
      |> List.filter_map (fun (lo, hi) ->
             if certify coeffs r lo hi b then Some (make r lo hi) else None)
      |> List.sort compare
      |> List.map upgrade
    end
  end

(* sign of m² − x purely via rational bisection of x's defining interval.
   This avoids creating new Num.t values in the inner loop of sqrt. *)
let cmp_sq_rat (poly : Poly.t) (lo : Q.t) (hi : Q.t) (m : Q.t) : int =
  let m2 = Q.mul m m in
  (* Narrow x's interval until m² is outside [lo, hi]. Since m is rational and x
     is irrational (Alg invariant), m² ≠ x, so this terminates. *)
  let rec narrow lo hi =
    if Q.compare m2 lo < 0 then -1
    else if Q.compare m2 hi > 0 then 1
    else
      let lo', hi' = refine_alg poly lo hi in
      narrow lo' hi'
  in
  narrow lo hi

(* √x, exact for rational *and* algebraic x: √x is a root of x's defining
   polynomial composed with (·)², i.e. poly(y²); the positive one is bracketed by
   exact sign tests of (m² − x). No dependency on real_roots. *)
let sqrt (x : t) : t =
  let x = match x with Field _ -> to_alg x | _ -> x in
  if sign x < 0 then invalid_arg "Num.sqrt: negative argument";
  if sign x = 0 then zero
  else begin
    let p = defpoly x in
    let p2 = Poly.compose p (Poly.of_list [ Q.zero; Q.zero; Q.one ]) in
    let lo_x, hi_x = enclosure x in
    (* cmp_sq m = sign of (m² - x): negative if m < √x, positive if m > √x. *)
    let cmp_sq =
      match x with
      | Rat q ->
          fun m -> Q.compare (Q.mul m m) q
      | Field _ -> assert false (* converted to Alg above *)
      | Alg { poly = xpoly; lo = xlo; hi = xhi } ->
          (* Use pure rational comparison, avoiding Num.t arithmetic. *)
          fun m -> cmp_sq_rat xpoly xlo xhi m
    in
    (* bracket √x in (lo_s, hi_s), narrowing until the squared bracket sits
       strictly inside x's rational isolating window. *)
    let rec go lo_s hi_s =
      let m = Q.div (Q.add lo_s hi_s) two_q in
      let lo_s, hi_s = if cmp_sq m <= 0 then (m, hi_s) else (lo_s, m) in
      let inside =
        Q.compare (Q.mul lo_s lo_s) lo_x >= 0
        && Q.compare (Q.mul hi_s hi_s) hi_x <= 0
      in
      (* The width floor is a termination safety-valve, not a correctness boundary:
         make p2 lo_s hi_s re-isolates and re-validates from whatever bracket. *)
      if inside || Q.compare (Q.sub hi_s lo_s) (Q.of_ints 1 1000000000) < 0 then
        (lo_s, hi_s)
      else go lo_s hi_s
    in
    let _, hi_enc = enclosure x in
    let lo_s, hi_s = go Q.zero (Q.add hi_enc Q.one) in
    make p2 lo_s hi_s
  end

let to_float (x : t) : float =
  match x with
  | Rat q -> Q.to_float q
  | Field { gen; coords } ->
      let w = Q.of_ints 1 1000000000000 in
      let rec narrow lo hi =
        if Q.compare (Q.sub hi lo) w < 0 then (lo, hi)
        else let lo, hi = refine_alg gen.mu lo hi in narrow lo hi
      in
      let lo, hi = narrow gen.lo gen.hi in
      Q.to_float (Poly.eval coords (Q.div (Q.add lo hi) two_q))
  | Alg { poly; lo; hi } ->
      let w = Q.of_ints 1 1000000000000 in
      let lo, hi = enclosure_tight (Alg { poly; lo; hi }) w in
      Q.to_float (Q.div (Q.add lo hi) two_q)
