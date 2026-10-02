(* Property tests for the number kernel [Num] (ADR 0012, ADR 0013): the field
   axioms, the sign, the order, and agreement with FLINT's qqbar arithmetic
   as an oracle independent of [Num]'s rational and single-field fast
   paths. Generators in arb.ml. *)

open Beloch

let ev = Arb.eval
let ( === ) = Num.equal
let p1 = Arb.expr_str
let p2 = Arb.print_expr2
let p3 = Arb.print_expr3

(* ---- the field axioms ---- *)

let add_commutative =
  Arb.make ~name:"a + b = b + a" ~count:20 ~print:p2 Arb.expr2 (fun (a, b) ->
      let a = ev a and b = ev b in
      Num.add a b === Num.add b a)

let mul_commutative =
  Arb.make ~name:"a * b = b * a" ~count:20 ~print:p2 Arb.expr2 (fun (a, b) ->
      let a = ev a and b = ev b in
      Num.mul a b === Num.mul b a)

let add_associative =
  Arb.make ~name:"(a + b) + c = a + (b + c)" ~count:15 ~print:p3 Arb.expr3
    (fun (a, b, c) ->
      let a = ev a and b = ev b and c = ev c in
      Num.add (Num.add a b) c === Num.add a (Num.add b c))

let mul_associative =
  Arb.make ~name:"(a * b) * c = a * (b * c)" ~count:15 ~print:p3 Arb.expr3
    (fun (a, b, c) ->
      let a = ev a and b = ev b and c = ev c in
      Num.mul (Num.mul a b) c === Num.mul a (Num.mul b c))

let distributive =
  Arb.make ~name:"a * (b + c) = a * b + a * c" ~count:15 ~print:p3 Arb.expr3
    (fun (a, b, c) ->
      let a = ev a and b = ev b and c = ev c in
      Num.mul a (Num.add b c) === Num.add (Num.mul a b) (Num.mul a c))

let identities =
  Arb.make ~name:"a + 0 = a, a * 1 = a, a * 0 = 0" ~count:60 ~print:p1 Arb.expr
    (fun a ->
      let a = ev a in
      Num.add a Num.zero === a
      && Num.mul a Num.one === a
      && Num.sign (Num.mul a Num.zero) = 0)

let additive_inverse =
  Arb.make ~name:"a + (-a) = 0 and a - a = 0" ~count:60 ~print:p1 Arb.expr
    (fun a ->
      let a = ev a in
      Num.sign (Num.add a (Num.neg a)) = 0 && Num.sign (Num.sub a a) = 0)

let multiplicative_inverse =
  Arb.make ~name:"a * inv a = 1 and inv (inv a) = a for a <> 0" ~count:60
    ~print:p1 Arb.expr (fun a ->
      let a = ev a in
      QCheck2.assume (Num.sign a <> 0);
      Num.mul a (Num.inv a) === Num.one && Num.inv (Num.inv a) === a)

let inv_zero_raises =
  Arb.make ~name:"inv of a zero raises" ~count:20 ~print:p1 Arb.expr (fun a ->
      let z = Num.sub (ev a) (ev (Arb.as_fields a)) in
      match Num.inv z with
      | _ -> false
      | exception Invalid_argument _ -> true
      | exception Division_by_zero -> true)

(* ---- the sign ---- *)

(* The same number held twice, once with each √k as FLINT's [Qq] and once as
   a [Field]: the difference is zero, and every comparison has to say so. *)
let sign_zero_across_representations =
  Arb.make ~name:"a - a' = 0 when a' holds a in other representations" ~count:60
    ~print:p1 Arb.expr (fun e ->
      let a = ev e and a' = ev (Arb.as_fields e) in
      Num.sign (Num.sub a a') = 0 && a === a' && Num.compare a a' = 0)

let sign_zero_iff_zero =
  Arb.make ~name:"sign a = 0 iff a is zero in qqbar" ~count:80 ~print:p1
    Arb.expr (fun a ->
      let a = ev a in
      Num.sign a = 0 = Qqbar.is_zero (Num.to_qq a)
      && Num.sign a = 0 = (a === Num.zero))

let sign_matches_float =
  Arb.make ~name:"sign a agrees with the float of a away from 0" ~count:80
    ~print:p1 Arb.expr (fun a ->
      let a = ev a in
      let f = Num.to_float a in
      QCheck2.assume (Float.abs f > 1e-9);
      Num.sign a = if f > 0. then 1 else -1)

let sign_matches_qqbar =
  Arb.make ~name:"sign a = qqbar sign of a" ~count:80 ~print:p1 Arb.expr
    (fun a ->
      let a = ev a in
      Num.sign a = Qqbar.sign_re (Num.to_qq a))

let sign_neg_mul =
  Arb.make ~name:"sign (-a) = -sign a, sign (a*b) = sign a * sign b" ~count:20
    ~print:p2 Arb.expr2 (fun (a, b) ->
      let a = ev a and b = ev b in
      Num.sign (Num.neg a) = -Num.sign a
      && Num.sign (Num.mul a b) = Num.sign a * Num.sign b)

(* ---- the order ---- *)

let compare_antisymmetric =
  Arb.make ~name:"compare a b = -compare b a, in {-1, 0, 1}" ~count:20 ~print:p2
    Arb.expr2 (fun (a, b) ->
      let a = ev a and b = ev b in
      let c = Num.compare a b in
      List.mem c [ -1; 0; 1 ] && c = -Num.compare b a && c = 0 = (a === b))

let compare_transitive =
  Arb.make ~name:"a <= b and b <= c imply a <= c" ~count:15 ~print:p3 Arb.expr3
    (fun (a, b, c) ->
      let a = ev a and b = ev b and c = ev c in
      (* sort the three by [compare], then check every pair of the sorted
         list: a transitive total order leaves no pair out of order *)
      let s = List.sort Num.compare [ a; b; c ] in
      match s with
      | [ x; y; z ] ->
          Num.compare x y <= 0 && Num.compare y z <= 0 && Num.compare x z <= 0
      | _ -> false)

let compare_matches_float =
  Arb.make ~name:"compare a b agrees with the floats when they are apart"
    ~count:20 ~print:p2 Arb.expr2 (fun (a, b) ->
      let a = ev a and b = ev b in
      let fa = Num.to_float a and fb = Num.to_float b in
      QCheck2.assume (Float.abs (fa -. fb) > 1e-9);
      Num.compare a b = if fa < fb then -1 else 1)

(* ---- the fast paths against FLINT ---- *)

(* [Num] adds and multiplies rationals with Zarith and values of one field as
   polynomials modulo the minimal polynomial, upgrades small-degree [Qq]
   values into fields, and falls back to qqbar only when no common field is
   found. Doing the same operation in qqbar on the operands' qqbar values
   must give the same number. *)
let add_mul_match_qqbar =
  Arb.make ~name:"a + b and a * b agree with qqbar" ~count:20 ~print:p2
    Arb.expr2 (fun (a, b) ->
      let a = ev a and b = ev b in
      let qa = Num.to_qq a and qb = Num.to_qq b in
      Qqbar.equal (Num.to_qq (Num.add a b)) (Qqbar.add qa qb)
      && Qqbar.equal (Num.to_qq (Num.mul a b)) (Qqbar.mul qa qb))

let roundtrip_qqbar =
  Arb.make ~name:"of_qq (to_qq a) = a" ~count:60 ~print:p1 Arb.expr (fun a ->
      let a = ev a in
      Num.of_qq (Num.to_qq a) === a)

let () =
  Arb.run "beloch-prop-num"
    [
      ( "field",
        [
          add_commutative;
          mul_commutative;
          add_associative;
          mul_associative;
          distributive;
          identities;
          additive_inverse;
          multiplicative_inverse;
          inv_zero_raises;
        ] );
      ( "sign",
        [
          sign_zero_across_representations;
          sign_zero_iff_zero;
          sign_matches_float;
          sign_matches_qqbar;
          sign_neg_mul;
        ] );
      ( "order",
        [ compare_antisymmetric; compare_transitive; compare_matches_float ] );
      ("qqbar", [ add_mul_match_qqbar; roundtrip_qqbar ]);
    ]
