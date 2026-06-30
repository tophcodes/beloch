(** Exact real algebraic numbers. A value is either an exact rational [Rat q]
    (fast-path: axioms 1–4 never leave ℚ) or [Alg {poly; lo; hi}] — the unique
    real root of the squarefree ℚ-polynomial [poly] inside the open interval
    [(lo, hi)]. Invariants for [Alg]: [poly] is squarefree, has exactly one root
    in [(lo, hi)], and that root is irrational (so it is never 0). Arithmetic
    builds the result's defining polynomial by resultant-via-interpolation and
    re-isolates; sign/compare refine the interval; [equal x y] is
    [sign (sub x y) = 0]. [to_float] is the only float, output-only.
    Algorithms: [bpr2006]. Field theory: [justin1986 §8.4d], [hull2020]. *)

type t = Rat of Q.t | Alg of { poly : Poly.t; lo : Q.t; hi : Q.t }

let zero : t = Rat Q.zero
let one : t = Rat Q.one
let of_q (q : Q.t) : t = Rat q
let of_int (i : int) : t = Rat (Q.of_int i)
let two_q = Q.of_int 2

(* defining polynomial of a value (x − q for a rational). *)
let defpoly (x : t) : Poly.t =
  match x with
  | Rat q -> Poly.of_list [ Q.neg q; Q.one ]
  | Alg a -> a.poly

(* a rational enclosure [lo,hi] of the value; tight for rationals. *)
let enclosure (x : t) : Q.t * Q.t =
  match x with Rat q -> (q, q) | Alg a -> (a.lo, a.hi)

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

let rec sign (x : t) : int =
  match x with
  | Rat q -> Q.sign q
  | Alg { poly; lo; hi } ->
      if Q.sign lo > 0 then 1
      else if Q.sign hi < 0 then -1
      else
        let lo, hi = refine_alg poly lo hi in
        sign (Alg { poly; lo; hi })

let neg (x : t) : t =
  match x with
  | Rat q -> Rat (Q.neg q)
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
let enclosure_tight (x : t) (w : Q.t) : Q.t * Q.t =
  match x with
  | Rat q -> (q, q)
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

let add (x : t) (y : t) : t =
  match (x, y) with
  | Rat a, Rat b -> Rat (Q.add a b)
  | Alg a, Rat q | Rat q, Alg a -> shift_alg a.poly a.lo a.hi q
  | Alg _, Alg _ ->
      let r = defpoly_sum x y in
      let enclose w =
        let xl, xh = enclosure_tight x (Q.div w two_q) in
        let yl, yh = enclosure_tight y (Q.div w two_q) in
        (Q.add xl yl, Q.add xh yh)
      in
      select_root r enclose

let sub (x : t) (y : t) : t = add x (neg y)

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

let mul (x : t) (y : t) : t =
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

let inv (x : t) : t =
  match x with
  | Rat q -> if Q.equal q Q.zero then invalid_arg "Num.inv: zero" else Rat (Q.inv q)
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

let div (x : t) (y : t) : t = mul x (inv y)
let compare (x : t) (y : t) : int = sign (sub x y)
let equal (x : t) (y : t) : bool = sign (sub x y) = 0

(* real roots, ascending, of the polynomial whose low-first coefficients are the
   given Num values. SLICE 1: rational coefficients only — the kernel demo and
   the foundation axiom 7 (slice 2) builds on. The irrational-coefficient case
   (eliminating coefficient generators by resultant) is deferred to the axiom 7
   slice, its only caller. *)
let real_roots (coeffs : t array) : t list =
  let n = Array.length coeffs in
  if n = 0 then []
  else begin
    let q_of c = match c with Rat q -> q | Alg _ ->
      failwith "Num.real_roots: algebraic coefficients deferred to the axiom 7 slice"
    in
    let p = Poly.of_list (Array.to_list (Array.map q_of coeffs)) in
    Poly.isolate_roots p
    |> List.map (fun (lo, hi) -> make p lo hi)
    |> List.sort compare
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
  | Alg { poly; lo; hi } ->
      let w = Q.of_ints 1 1000000000000 in
      let lo, hi = enclosure_tight (Alg { poly; lo; hi }) w in
      Q.to_float (Q.div (Q.add lo hi) two_q)
