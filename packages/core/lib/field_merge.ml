(** Primitive-element merge for real_roots: express algebraic coefficients over
    one generator γ of the field they span (compositum of independent folds),
    and form the ℚ[t] superset polynomial via a single resultant. See
    docs/superpowers/specs/2026-07-03-pe-merge-real-roots-design.md. *)

let k_limit = 64 (* defensive cap on the primitive-element multiplier search *)

(* γ that generates ℚ(gen, b): γ = gen + k·b for the least k in 1..k_limit such
   that both gen and b lie in ℚ(γ). None if the cap is exceeded. *)
let extend (gen : Qqbar.t) (b : Qqbar.t) : Qqbar.t option =
  match Qqbar.express_over ~gen b with
  | Some _ -> Some gen (* b already in ℚ(gen) *)
  | None ->
      let rec search k =
        if k > k_limit then None
        else
          let g = Qqbar.add gen (Qqbar.mul (Qqbar.of_q (Q.of_int k)) b) in
          match Qqbar.express_over ~gen:g gen, Qqbar.express_over ~gen:g b with
          | Some _, Some _ -> Some g
          | _ -> search (k + 1)
      in
      search 1

(* (mu_gamma, coords) with coords.(i)(gamma) = input.(i), or None. *)
let merge_generators (coeffs : Qqbar.t array) : (Poly.t * Poly.t array) option =
  (* distinct non-rational coefficients, in first-seen order *)
  let algs =
    Array.fold_left
      (fun acc c ->
        if Qqbar.is_rational c then acc
        else if List.exists (fun d -> Qqbar.equal d c) acc then acc
        else acc @ [ c ])
      [] coeffs
  in
  match algs with
  | [] -> None (* all rational: caller uses the rational path *)
  | g0 :: rest ->
      let rec build gen = function
        | [] -> Some gen
        | b :: tl -> (
            match extend gen b with None -> None | Some g -> build g tl)
      in
      match build g0 rest with
      | None -> None
      | Some gamma -> (
          let coords = Array.map (fun c -> Qqbar.express_over ~gen:gamma c) coeffs in
          if Array.exists (fun o -> o = None) coords then None
          else
            let coords =
              Array.map (function Some c -> c | None -> assert false) coords
            in
            Some (Qqbar.minpoly gamma, coords))

(* R(t) = Res_x(mu(x), F~(t,x)) where F~(t,x) = Σ_i coords.(i)(x)·t^i, a superset
   of the true roots of the original polynomial. Computed by evaluation–
   interpolation in t: sample R(t_j) = Res_x(mu, F~(t_j,·)) with the univariate
   Poly.resultant, then interpolate. deg_t R ≤ deg(mu)·(len coords − 1).

   Sampled only at t_j where F~(t_j,·) keeps its full formal x-degree: when the
   leading x-coefficient of F~ (a polynomial in t) vanishes at t_j, Poly.resultant
   would compute a reduced-degree resultant differing from the formal R(t_j) and
   corrupt the interpolation. That leading coefficient has at most (len coords−1)
   roots, so enough good integer samples always exist.

   ~10× faster than the equivalent general multivariate resultant, which pays a
   symbolic multivariate Lagrange interpolation. The result may differ from that
   path by a nonzero constant/sign (resultant argument order), which does not
   change the root set the caller extracts and exact-filters. *)
let resultant_superset ~(coords : Poly.t array) ~(mu : Poly.t) : Poly.t =
  let m = Poly.degree mu in
  let n = Array.fold_left (fun a c -> max a (Poly.degree c)) 0 coords in
  let dt = Array.length coords - 1 in
  let deg_r = m * dt in
  (* F~(t_j, x) as a ℚ-polynomial in x *)
  let ftilde (tj : Q.t) : Poly.t =
    let acc = ref Poly.zero and tp = ref Q.one in
    Array.iter
      (fun ci ->
        acc := Poly.add !acc (Poly.scale !tp ci);
        tp := Q.mul !tp tj)
      coords;
    !acc
  in
  (* collect deg_r + 1 samples that keep the full formal x-degree n *)
  let pts = ref [] and got = ref 0 and k = ref 0 in
  while !got <= deg_r do
    let tj = Q.of_int !k in
    let g = ftilde tj in
    if Poly.degree g = n then begin
      pts := (tj, Poly.resultant mu g) :: !pts;
      incr got
    end;
    incr k
  done;
  Poly.interpolate !pts
