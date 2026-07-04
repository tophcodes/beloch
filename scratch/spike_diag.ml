(* Diagnostic probe for the Calcium/PE-merge spike.

   Question: when stacked axiom-7 cubics wall (verdict note: "round 4"),
   does FLINT's real_roots_of_qqbar_poly return None (H1: coefficient field
   exceeds its 10000/100000 degree/bits limit → caller falls to deg-2187 R)
   or does it hang inside FLINT (H2: intrinsically heavy)?

   We rebuild the axiom-7 cubic F(t) directly (returning its Num.t coeff array
   instead of creases), stack rounds by feeding one real root forward as the
   next round's p.x, and at each round instrument the FLINT primitive itself:
   None (fast) vs Some(n) (with time). A round that neither prints None nor
   Some before the outer `timeout` kills it is H2 for that degree.

   Run per-round under timeout to separate "None fast" from "hang":
     for k in 1 2 3 4 5; do timeout 120 dune exec scratch/spike_diag.exe -- $k; done *)

open Beloch

let nq s = Num.of_q (Q.of_string s)
let pt x y = Geom.{ x; y }
let ln a b c = Geom.{ a; b; c }

(* F(t) as a Num.t array (low-first) — copied verbatim from
   Geom.beloch7_creases, minus the crease mapping, so we can inspect the
   polynomial the axiom actually solves. *)
let axiom7_cubic (p : Geom.point) (d : Geom.line) (q : Geom.point) (e : Geom.line)
    : Num.t array =
  let padd a b =
    let n = max (Array.length a) (Array.length b) in
    Array.init n (fun i ->
        let x = if i < Array.length a then a.(i) else Num.zero in
        let y = if i < Array.length b then b.(i) else Num.zero in
        Num.add x y)
  in
  let pscale (s : Num.t) a = Array.map (fun c -> Num.mul s c) a in
  let pmul a b =
    let r = Array.make (Array.length a + Array.length b - 1) Num.zero in
    Array.iteri
      (fun i ca ->
        Array.iteri
          (fun j cb -> r.(i + j) <- Num.add r.(i + j) (Num.mul ca cb))
          b)
      a;
    r
  in
  let psub a b = padd a (pscale (Num.of_int (-1)) b) in
  let n2 = Num.add (Num.mul d.a d.a) (Num.mul d.b d.b) in
  let d0x = Num.div (Num.mul d.a d.c) n2 and d0y = Num.div (Num.mul d.b d.c) n2 in
  let two = Num.of_int 2 in
  let aA = [| Num.sub d0x p.x; d.b |] in
  let bB = [| Num.sub d0y p.y; Num.neg d.a |] in
  let mx = [| Num.div (Num.add p.x d0x) two; Num.div d.b two |] in
  let my = [| Num.div (Num.add p.y d0y) two; Num.div (Num.neg d.a) two |] in
  let cC = padd (pmul aA mx) (pmul bB my) in
  let n2c = padd (pmul aA aA) (pmul bB bB) in
  let dd = psub (padd (pscale q.x aA) (pscale q.y bB)) cC in
  let lL = padd (pscale e.a aA) (pscale e.b bB) in
  let s = Num.sub (Num.add (Num.mul e.a q.x) (Num.mul e.b q.y)) e.c in
  psub (pscale s n2c) (pscale two (pmul dd lL))

(* fixed directrices / second focus, as in scratch/probe.ml's doubling setup *)
let d = ln (nq "0") (nq "1") (nq "0") (* y = 0 *)
let q = pt (nq "1") (nq "1/2")
let e = ln (nq "1") (nq "0") (nq "0") (* x = 0 *)

(* qqbar coefficient stats: max minimal-poly degree and max coefficient bit
   size across the cubic's coefficients — this is what FLINT's limits see. *)
let coeff_stats (coeffs : Num.t array) : int * int =
  Array.fold_left
    (fun (dmax, bmax) c ->
      let z = Num.to_qq c in
      let deg = Qqbar.degree z in
      let bits =
        Array.fold_left
          (fun m s -> max m (String.length s * 4 (* ~4 bits/hex-ish digit *)))
          0
          (Qqbar.minpoly_strs z)
      in
      (max dmax deg, max bmax bits))
    (0, 0) coeffs

let () =
  let target = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 5 in
  (* start rational; feed one real root forward each round *)
  let px = ref (nq "1/2") in
  (try
     for k = 1 to target do
       let p = pt !px (nq "1") in
       let coeffs = axiom7_cubic p d q e in
       let cdeg, cbits = coeff_stats coeffs in
       Printf.printf "round %d: input p.x qqbar-deg=%d | cubic coeff max-deg=%d max-bits~%d\n%!"
         k (Qqbar.degree (Num.to_qq !px)) cdeg cbits;
       (* instrument the FLINT primitive directly *)
       let coeffs_qq = Array.map Num.to_qq coeffs in
       Printf.printf "  calling real_roots_of_qqbar_poly (coeff-deg %d) ...\n%!" cdeg;
       let t0 = Unix.gettimeofday () in
       let res = Qqbar.real_roots_of_qqbar_poly coeffs_qq in
       let dt = Unix.gettimeofday () -. t0 in
       (match res with
        | None ->
            Printf.printf "  => None (FLINT limit) in %.3fs  [H1 at this degree]\n%!" dt;
            (* can't advance the chain cheaply past a None; stop here *)
            raise Exit
        | Some roots ->
            Printf.printf "  => Some (%d real roots) in %.3fs\n%!" (List.length roots) dt;
            (match roots with
             | [] -> Printf.printf "  no real roots; stopping\n%!"; raise Exit
             | r :: _ -> px := Num.of_qq r))
     done
   with Exit -> ());
  Printf.printf "done\n%!"
