(** Exact real algebraic numbers backed by FLINT 3's qqbar (Calcium):
    canonical minimal-polynomial representation with Arb ball certification.
    Values are immutable; the C finalizer frees the FLINT struct. ℚ crosses
    the FFI as strings. See decisions/0013-flint-qqbar-backend.md. *)

type t

external of_q_str : string -> t = "ml_qqbar_of_q"
external to_q_str : t -> string = "ml_qqbar_to_q_str"
external is_rational : t -> bool = "ml_qqbar_is_rational"
external is_zero : t -> bool = "ml_qqbar_is_zero"
external neg : t -> t = "ml_qqbar_neg"
external inv_unsafe : t -> t = "ml_qqbar_inv"
external sqrt_unsafe : t -> t = "ml_qqbar_sqrt"
external add : t -> t -> t = "ml_qqbar_add"
external sub : t -> t -> t = "ml_qqbar_sub"
external mul : t -> t -> t = "ml_qqbar_mul"
external div_unsafe : t -> t -> t = "ml_qqbar_div"
external equal : t -> t -> bool = "ml_qqbar_equal"
external cmp_re : t -> t -> int = "ml_qqbar_cmp_re"
external sign_re : t -> int = "ml_qqbar_sgn_re"
external degree : t -> int = "ml_qqbar_degree"
external to_float : t -> float = "ml_qqbar_get_d"
external minpoly_strs : t -> string array = "ml_qqbar_minpoly"
external express_in_field_raw : t -> t -> int -> string array option
  = "ml_qqbar_express_in_field"
external enclosure_strs : t -> int -> string * string * string
  = "ml_qqbar_enclosure"
external real_roots_strs : string array -> t array = "ml_qqbar_real_roots"
external roots_qqbar_poly_raw : t array -> t array option
  = "ml_qqbar_roots_qqbar_poly"

let of_q (q : Q.t) : t = of_q_str (Q.to_string q)
let to_q (x : t) : Q.t option =
  if is_rational x then Some (Q.of_string (to_q_str x)) else None

(* FLINT aborts the process on invalid input — guard here. *)
let inv (x : t) : t =
  if is_zero x then invalid_arg "Qqbar.inv: zero" else inv_unsafe x

let div (x : t) (y : t) : t =
  if is_zero y then invalid_arg "Qqbar.div: zero divisor" else div_unsafe x y

let sqrt (x : t) : t =
  if sign_re x < 0 then invalid_arg "Qqbar.sqrt: negative argument"
  else sqrt_unsafe x

let minpoly (x : t) : Poly.t =
  let coeffs =
    Array.map (fun s -> Q.of_bigint (Z.of_string s)) (minpoly_strs x)
  in
  Poly.monic (Poly.normalize coeffs)

(* x as a ℚ-polynomial (low-first) in gen, exactly, or None if x ∉ ℚ(gen)
   or the search precision is too low (one retry at a higher bound). The int
   arg drives FLINT's LLL search precision (the C stub passes it as prec);
   a too-low value can only yield a false None, never a wrong polynomial —
   FLINT re-verifies res(gen) = x exactly before reporting success. *)
let express_over ~(gen : t) (x : t) : Poly.t option =
  let parse a = Poly.of_list (Array.to_list (Array.map Q.of_string a)) in
  match express_in_field_raw gen x 4096 with
  | Some a -> Some (parse a)
  | None -> (
      match express_in_field_raw gen x 65536 with
      | Some a -> Some (parse a)
      | None -> None)

let enclosure (x : t) ~(prec : int) : Q.t * Q.t =
  let a, b, e = enclosure_strs x prec in
  let a = Z.of_string a and b = Z.of_string b and e = Z.of_string e in
  (* value ∈ [a·2^e, b·2^e], exact *)
  let scale (n : Z.t) : Q.t =
    if Z.sign e >= 0 then Q.of_bigint (Z.shift_left n (Z.to_int e))
    else Q.make n (Z.shift_left Z.one (Z.to_int (Z.neg e)))
  in
  (scale a, scale b)

let real_roots_of_poly (p : Poly.t) : t list =
  if Poly.degree p < 1 then []
  else begin
    (* clear denominators to ℤ coefficients *)
    let l = Array.fold_left (fun acc c -> Z.lcm acc (Q.den c)) Z.one p in
    let strs =
      Array.map
        (fun c -> Z.to_string (Q.num (Q.mul c (Q.of_bigint l))))
        p
    in
    real_roots_strs strs |> Array.to_list
    |> List.sort_uniq cmp_re
  end

(* Real roots (ascending) of the SQUAREFREE polynomial with qqbar
   coefficients, low-first. None when FLINT's internal degree/bits limits
   would be exceeded — the caller falls back to elimination. FLINT >= 3.6. *)
let real_roots_of_qqbar_poly (coeffs : t array) : t list option =
  match roots_qqbar_poly_raw coeffs with
  | None -> None
  | Some arr -> Some (Array.to_list arr |> List.sort_uniq cmp_re)
