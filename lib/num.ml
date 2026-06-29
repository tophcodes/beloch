(** Exact constructible reals: a tower of quadratic extensions over ℚ.
    [t] is [Rat q] or [Ext (a, b, d)] meaning [a + b·√d] with [d > 0].
    Canonical invariant (held by routing all [Ext] building through [ext]):
    in [Ext (a, b, d)] the generator [√d] is strictly greater — by the purely
    syntactic order [compare_struct] — than every generator in [a] and [b].
    That invariant is what makes [sign] terminate (it recurses on [a²−b²d],
    which sits one extension below [√d]). Equality needs no canonical form:
    [equal x y] is [sign (sub x y) = 0]. Float appears only in [to_float]. *)

type t = Rat of Q.t | Ext of t * t * t

(* A total order on terms, used to choose the outer (maximal) generator and to
   recognise identical generators. Any fixed total order works. *)
let rec compare_struct (x : t) (y : t) : int =
  match x, y with
  | Rat a, Rat b -> Q.compare a b
  | Rat _, Ext _ -> -1
  | Ext _, Rat _ -> 1
  | Ext (a1, b1, d1), Ext (a2, b2, d2) ->
      let c = compare_struct d1 d2 in
      if c <> 0 then c
      else
        let c = compare_struct a1 a2 in
        if c <> 0 then c else compare_struct b1 b2

let rec neg (x : t) : t =
  match x with Rat a -> Rat (Q.neg a) | Ext (a, b, d) -> Ext (neg a, neg b, d)

let zero : t = Rat Q.zero
let one : t = Rat Q.one
let of_q (q : Q.t) : t = Rat q
let of_int (i : int) : t = Rat (Q.of_int i)

(* Mutually recursive core. [ext] keeps the b≠0 / d>0 part of the invariant;
   [add]/[mul] keep the generator-ordering part by always combining at the
   maximal generator and recursing into the (smaller-generator) coefficients. *)
let rec sign (x : t) : int =
  match x with
  | Rat q -> Q.sign q
  | Ext (a, b, d) ->
      let sa = sign a and sb = sign b and sd = sign d in
      if sb = 0 || sd = 0 then sa
      else if sa >= 0 && sb > 0 then 1
      else if sa <= 0 && sb < 0 then -1
      else
        (* a and b√d have opposite signs: compare magnitudes a² vs b²·d *)
        let m = sign (sub (mul a a) (mul (mul b b) d)) in
        if sa > 0 then m else -m

and ext (a : t) (b : t) (d : t) : t =
  if sign b = 0 || sign d = 0 then a else Ext (a, b, d)

and add (x : t) (y : t) : t =
  match x, y with
  | Rat a, Rat b -> Rat (Q.add a b)
  | Rat _, Ext (a, b, d) -> ext (add x a) b d
  | Ext (a, b, d), Rat _ -> ext (add a y) b d
  | Ext (a1, b1, d1), Ext (a2, b2, d2) ->
      let c = compare_struct d1 d2 in
      if c = 0 then ext (add a1 a2) (add b1 b2) d1
      else if c > 0 then ext (add a1 y) b1 d1
      else ext (add x a2) b2 d2

and sub (x : t) (y : t) : t = add x (neg y)

and mul (x : t) (y : t) : t =
  match x, y with
  | Rat a, Rat b -> Rat (Q.mul a b)
  | Rat _, Ext (a, b, d) -> ext (mul x a) (mul x b) d
  | Ext (a, b, d), Rat _ -> ext (mul a y) (mul b y) d
  | Ext (a1, b1, d1), Ext (a2, b2, d2) ->
      let c = compare_struct d1 d2 in
      if c = 0 then
        (* (a1+b1√d)(a2+b2√d) = (a1a2 + b1b2 d) + (a1b2 + a2b1)√d *)
        ext
          (add (mul a1 a2) (mul (mul b1 b2) d1))
          (add (mul a1 b2) (mul a2 b1))
          d1
      else if c > 0 then ext (mul a1 y) (mul b1 y) d1
      else ext (mul x a2) (mul x b2) d2

let compare (x : t) (y : t) : int = sign (sub x y)
let equal (x : t) (y : t) : bool = sign (sub x y) = 0

(* √x. Rational perfect squares collapse to [Rat]; otherwise a fresh generator
   [0 + 1·√x] strictly above everything in x. *)
let sqrt (x : t) : t =
  if sign x < 0 then invalid_arg "Num.sqrt: negative argument"
  else
    match x with
    | Rat q ->
        let num = Q.num q and den = Q.den q in
        let sn = Z.sqrt num and sd = Z.sqrt den in
        if Z.equal (Z.mul sn sn) num && Z.equal (Z.mul sd sd) den then
          Rat (Q.make sn sd)
        else ext zero one x
    | _ -> ext zero one x

(* 1/(a+b√d) = (a − b√d) / (a² − b²d); the norm a²−b²d lies one extension below
   √d, so [inv] recurses on a structurally simpler value. *)
let rec inv (x : t) : t =
  match x with
  | Rat q -> Rat (Q.inv q)
  | Ext (a, b, d) ->
      let norm = sub (mul a a) (mul (mul b b) d) in
      mul (ext a (neg b) d) (inv norm)

let div (x : t) (y : t) : t = mul x (inv y)

let rec to_float (x : t) : float =
  match x with
  | Rat q -> Q.to_float q
  | Ext (a, b, d) -> to_float a +. (to_float b *. Float.sqrt (to_float d))
