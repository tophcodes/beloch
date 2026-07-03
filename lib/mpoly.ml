(** Sparse multivariate polynomials over ℚ in a fixed number of variables
    (indices 0 .. nvars-1). Built for Num.real_roots: it manufactures, by
    Sylvester-resultant elimination of each algebraic coefficient's generator, a
    ℚ-polynomial in the root variable whose real roots are a SUPERSET of the true
    roots (spurious conjugate roots are removed later by exact evaluation). Only
    the root set matters, so sign/constant factors are not tracked. The
    Sylvester resultant is computed by evaluation + interpolation: each
    specialized Sylvester determinant is a numeric Gaussian elimination over ℚ
    (Poly.det), and the multivariate result is recovered by Lagrange
    interpolation. Algorithms: [bpr2006 §4.2]. *)

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

(* substitute values for the variables in [point] (all variables except v
   must be covered); returns the univariate ℚ-coefficient array of x_v,
   low-first, length degree_in p v + 1 (fixed generic length — substitution
   can only zero leading entries, never change the array shape). *)
let specialize (p : t) (v : int) (point : (int * Q.t) list) : Q.t array =
  let d = degree_in p v in
  let arr = Array.make (d + 1) Q.zero in
  List.iter
    (fun (m, c) ->
      let value = ref c in
      List.iter
        (fun (i, x) ->
          for _ = 1 to m.(i) do
            value := Q.mul !value x
          done)
        point;
      arr.(m.(v)) <- Q.add arr.(m.(v)) !value)
    p;
  arr

(* Sylvester resultant of a and b with respect to variable v, by evaluation +
   interpolation: the Sylvester matrix layout is fixed by the generic
   v-degrees (da, db), so specializing the remaining variables commutes with
   taking the determinant — even where leading coefficients vanish at a
   sample point. Each specialized determinant is a numeric Gaussian
   elimination over ℚ (Poly.det), and the multivariate result is recovered
   by tensor-grid Lagrange interpolation, one variable at a time. Degree
   bound in each remaining variable x: db·deg_x(a) + da·deg_x(b) (every
   determinant term multiplies db entries from a-rows and da from b-rows).
   Replaces the division-free Laplace expansion, which was factorial in the
   matrix size [bpr2006 §4.2 for the Sylvester construction]. *)
let resultant (a : t) (b : t) (v : int) : t =
  let ca = coeffs_in a v and cb = coeffs_in b v in
  let da = Array.length ca - 1 and db = Array.length cb - 1 in
  if da < 0 || db < 0 then zero
  else if da = 0 then pow ca.(0) db
  else if db = 0 then pow cb.(0) da
  else begin
    let nvars =
      match (a, b) with
      | (m, _) :: _, _ | _, (m, _) :: _ -> Array.length m
      | [], [] -> 0
    in
    let others =
      List.filter
        (fun i -> i <> v && (degree_in a i > 0 || degree_in b i > 0))
        (List.init nvars (fun i -> i))
    in
    let bound i = (db * degree_in a i) + (da * degree_in b i) in
    let det_at (point : (int * Q.t) list) : Q.t =
      let sa = specialize a v point and sb = specialize b v point in
      let n = da + db in
      let m = Array.make_matrix n n Q.zero in
      for i = 0 to db - 1 do
        for j = 0 to da do
          m.(i).(i + j) <- sa.(da - j)
        done
      done;
      for i = 0 to da - 1 do
        for j = 0 to db do
          m.(db + i).(i + j) <- sb.(db - j)
        done
      done;
      Poly.det m
    in
    (* interpolate over the remaining variables, innermost-first *)
    let rec interp (vars : int list) (point : (int * Q.t) list) : t =
      match vars with
      | [] -> const nvars (det_at point)
      | x :: rest ->
          let d = bound x in
          let samples =
            List.init (d + 1) (fun k ->
                let xk = Q.of_int k in
                (xk, interp rest ((x, xk) :: point)))
          in
          List.fold_left
            (fun acc (xi, ri) ->
              (* Lagrange basis L_i(x) = ∏_{j≠i} (x − xj)/(xi − xj), as Mpoly *)
              let li =
                List.fold_left
                  (fun p (xj, _) ->
                    if Q.equal xj xi then p
                    else
                      let denom = Q.sub xi xj in
                      mul p
                        (add
                           (mul (const nvars (Q.inv denom)) (var nvars x))
                           (const nvars (Q.div (Q.neg xj) denom))))
                  (one_of nvars) samples
              in
              add acc (mul ri li))
            zero samples
    in
    interp others []
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
