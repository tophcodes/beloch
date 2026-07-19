(* Field-degree scaling benchmark — the honest measure for the 3^N wall.

   A generic (irreducible-cubic) axiom-7 fold N sees a coefficient field of
   degree 3^(N-1). We probe the cost of ONE axiom-7 cubic as a function of that
   degree, using a single clean generator px = 2^(1/D) (root of x^D − 2,
   irreducible → degree exactly D). Prints end-to-end Num.real_roots plus the
   Tier-3 stage breakdown (merge / resultant / roots / filter), mirroring
   bench_real_roots.

   Usage: dune exec packages/core/bench/bench_generic.exe -- [D1 D2 ...]   (default 3 9 27) *)
open Beloch

let nq s = Num.of_q (Q.of_string s)
let pt x y = Geom.{ x; y }
let ln a b c = Geom.{ a; b; c }
let d = ln (nq "0") (nq "1") (nq "0")
let q = pt (nq "1") (nq "1/2")
let e = ln (nq "1") (nq "0") (nq "0")

let axiom7_cubic (px : Num.t) : Num.t array =
  let p = pt px (nq "1") in
  let padd a b = let n = max (Array.length a) (Array.length b) in
    Array.init n (fun i -> let x = if i < Array.length a then a.(i) else Num.zero in
        let y = if i < Array.length b then b.(i) else Num.zero in Num.add x y) in
  let pscale s a = Array.map (fun c -> Num.mul s c) a in
  let pmul a b = let r = Array.make (Array.length a + Array.length b - 1) Num.zero in
    Array.iteri (fun i ca -> Array.iteri (fun j cb ->
        r.(i+j) <- Num.add r.(i+j) (Num.mul ca cb)) b) a; r in
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

let root_of_two deg =
  let c = Array.make (deg + 1) Num.zero in
  c.(0) <- nq "-2"; c.(deg) <- Num.one;
  List.hd (Num.real_roots c)

let time f = let t0 = Unix.gettimeofday () in let r = f () in (r, Unix.gettimeofday () -. t0)

let run deg =
  let coeffs = axiom7_cubic (root_of_two deg) in
  let coeffs_qq = Array.map Num.to_qq coeffs in
  let eval_p z = let acc = ref (Qqbar.of_q Q.zero) in
    for i = Array.length coeffs_qq - 1 downto 0 do
      acc := Qqbar.add (Qqbar.mul !acc z) coeffs_qq.(i) done; !acc in
  let (ms, rs, rdeg, cs, ncands, fs, nroots) =
    match time (fun () -> Field_merge.merge_generators coeffs_qq) with
    | (None, m) -> (m, 0., 0, 0., 0, 0., 0)
    | (Some (mu, coords), m) ->
        let (r, rt) = time (fun () -> Field_merge.resultant_superset ~coords ~mu) in
        let (cands, ct) = time (fun () -> Qqbar.real_roots_of_poly r) in
        let prec = 128 in
        let qmin a b = if Q.compare a b <= 0 then a else b in
        let qmax a b = if Q.compare a b >= 0 then a else b in
        let ce = Array.map (fun c -> Qqbar.enclosure c ~prec) coeffs_qq in
        let excl z =
          let iadd (a,b) (c,dd) = (Q.add a c, Q.add b dd) in
          let imul (a,b) (c,dd) = let p1=Q.mul a c and p2=Q.mul a dd
            and p3=Q.mul b c and p4=Q.mul b dd in
            (qmin (qmin p1 p2) (qmin p3 p4), qmax (qmax p1 p2) (qmax p3 p4)) in
          let zi = Qqbar.enclosure z ~prec in
          let acc = ref (Q.zero, Q.zero) in
          for i = Array.length ce - 1 downto 0 do acc := iadd (imul !acc zi) ce.(i) done;
          let lo, hi = !acc in Q.compare lo Q.zero > 0 || Q.compare hi Q.zero < 0 in
        let (kept, ft) = time (fun () ->
            List.filter (fun z -> if excl z then false else Qqbar.is_zero (eval_p z)) cands) in
        (m, rt, Poly.degree r, ct, List.length cands, ft, List.length kept)
  in
  let total = ms +. rs +. cs +. fs in
  Printf.printf
    "field-deg %2d | total %9.3fs | merge %.3f  resultant %.3f (R deg %d)  roots %.3f  filter %.3f (%d cand) | %d roots\n%!"
    deg total ms rs rdeg cs fs ncands nroots

let () =
  let degs = if Array.length Sys.argv > 1
    then Array.to_list (Array.sub Sys.argv 1 (Array.length Sys.argv - 1)) |> List.map int_of_string
    else [ 3; 9; 27 ] in
  List.iter run degs
