(** Sparse multivariate polynomials over ℚ in a fixed number of variables
    (indices 0 .. nvars-1). Built for Num.real_roots: it manufactures, by
    Sylvester-resultant elimination of each algebraic coefficient's generator, a
    ℚ-polynomial in the root variable whose real roots are a SUPERSET of the true
    roots (spurious conjugate roots are removed later by exact evaluation). Only
    the root set matters, so sign/constant factors are not tracked. Determinants
    use division-free Laplace expansion (the ring is not a field).
    Algorithms: [bpr2006 §4.2]. *)

type mono = int array (* exponents, length = nvars *)
type t = (mono * Q.t) list (* unique monomials, no zero coeffs *)

let mono_equal (a : mono) (b : mono) : bool =
  Array.length a = Array.length b
  && (let ok = ref true in
      Array.iteri (fun i e -> if e <> b.(i) then ok := false) a;
      !ok)

let zero : t = []
let is_zero (p : t) : bool = p = []

let const (nvars : int) (q : Q.t) : t =
  if Q.equal q Q.zero then [] else [ (Array.make nvars 0, q) ]

let var (nvars : int) (i : int) : t =
  let m = Array.make nvars 0 in
  m.(i) <- 1;
  [ (m, Q.one) ]

(* insert (m, c) into a polynomial, merging like monomials, dropping zeros *)
let add_term (p : t) (m : mono) (c : Q.t) : t =
  if Q.equal c Q.zero then p
  else
    let rec go = function
      | [] -> [ (m, c) ]
      | (m', c') :: rest ->
          if mono_equal m m' then
            let s = Q.add c' c in
            if Q.equal s Q.zero then rest else (m', s) :: rest
          else (m', c') :: go rest
    in
    go p

let add (p : t) (q : t) : t = List.fold_left (fun acc (m, c) -> add_term acc m c) p q
let neg (p : t) : t = List.map (fun (m, c) -> (m, Q.neg c)) p
let sub (p : t) (q : t) : t = add p (neg q)

let mul (p : t) (q : t) : t =
  List.fold_left
    (fun acc (mp, cp) ->
      List.fold_left
        (fun acc (mq, cq) ->
          let m = Array.mapi (fun i e -> e + mq.(i)) mp in
          add_term acc m (Q.mul cp cq))
        acc q)
    [] p

let one_of (nvars : int) : t = const nvars Q.one

let pow (p : t) (k : int) : t =
  (* requires k >= 0; p^0 needs an nvars to build `one`, so derive from p *)
  if k = 0 then
    match p with
    | (m, _) :: _ -> one_of (Array.length m)
    | [] -> [] (* 0^0 unused here *)
  else begin
    let r = ref p in
    for _ = 2 to k do
      r := mul !r p
    done;
    !r
  end

let degree_in (p : t) (v : int) : int =
  List.fold_left (fun acc (m, _) -> max acc m.(v)) 0 p

(* coefficients of p viewed as a univariate polynomial in variable v:
   result.(k) is the Mpoly coefficient of x_v^k, with x_v stripped. *)
let coeffs_in (p : t) (v : int) : t array =
  let d = degree_in p v in
  let out = Array.make (d + 1) zero in
  List.iter
    (fun (m, c) ->
      let k = m.(v) in
      let m' = Array.copy m in
      m'.(v) <- 0;
      out.(k) <- add_term out.(k) m' c)
    p;
  out

(* determinant of a square matrix of Mpoly by Laplace expansion along row 0.
   Division-free: valid over the (non-field) polynomial ring. n is small here. *)
let rec det (mat : t array array) : t =
  let n = Array.length mat in
  if n = 0 then [] (* unused *)
  else if n = 1 then mat.(0).(0)
  else begin
    let acc = ref zero in
    for j = 0 to n - 1 do
      let minor =
        Array.init (n - 1) (fun r ->
            Array.init (n - 1) (fun c ->
                mat.(r + 1).(if c < j then c else c + 1)))
      in
      let term = mul mat.(0).(j) (det minor) in
      acc := if j land 1 = 0 then add !acc term else sub !acc term
    done;
    !acc
  end

(* Sylvester resultant of a and b with respect to variable v. Mirrors the dense
   Sylvester layout of Poly.resultant, but matrix entries are Mpoly (in the
   remaining variables). Result has exponent 0 in v. *)
let resultant (a : t) (b : t) (v : int) : t =
  let ca = coeffs_in a v and cb = coeffs_in b v in
  let da = Array.length ca - 1 and db = Array.length cb - 1 in
  if da < 0 || db < 0 then zero
  else if da = 0 then pow ca.(0) db
  else if db = 0 then pow cb.(0) da
  else begin
    let n = da + db in
    (* ca/cb are low-first; Poly.resultant indexes high-first as p.(dp - j) *)
    let hi (c : t array) (deg : int) (k : int) : t = c.(deg - k) in
    let m = Array.make_matrix n n zero in
    for i = 0 to db - 1 do
      for j = 0 to da do
        m.(i).(i + j) <- hi ca da j
      done
    done;
    for i = 0 to da - 1 do
      for j = 0 to db do
        m.(db + i).(i + j) <- hi cb db j
      done
    done;
    det m
  end

(* Extract the univariate ℚ-polynomial in variable v; every other variable must
   have exponent 0 in every monomial. *)
let to_poly_in (p : t) (v : int) : Poly.t =
  let d = degree_in p v in
  let arr = Array.make (d + 1) Q.zero in
  List.iter
    (fun (m, c) ->
      Array.iteri
        (fun i e -> if i <> v && e <> 0 then invalid_arg "Mpoly.to_poly_in: residual variable")
        m;
      arr.(m.(v)) <- Q.add arr.(m.(v)) c)
    p;
  Poly.of_list (Array.to_list arr)
