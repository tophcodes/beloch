(* Spike driver: primitive-element root-finding for stacked axiom-7 cubics.

   Observation from the diagnostic: at round k the fed-back coordinate px is a
   SINGLE qqbar of degree d, so the cubic F(t)'s coefficients all live in the
   simple field ℚ(px) — px itself is the primitive element, μ = minpoly(px).
   The current kernel's Mpoly path rediscovers a fresh generator per distinct
   coefficient value (only degree-2 pairs merge), blowing R up to degree 3·d³.

   Here we instead build F(t) symbolically over the ring ℚ[x]/μ (x ↦ px), then
   eliminate x with ONE resultant against μ:
       R(t) = Res_x(μ(x), F(t, x))   — degree 3·d, not 3·d³.
   Real roots of the integer polynomial R come from FLINT (fast), filtered by
   exact evaluation of the true algebraic cubic in qqbar (no spurious root).

   Compared per round against Qqbar.real_roots_of_qqbar_poly (current path).
     for k in 4 5 6 7 8; do timeout 120 dune exec scratch/spike_pe.exe -- $k; done *)
open Beloch

let nq s = Num.of_q (Q.of_string s)
let pt x y = Geom.{ x; y }
let ln a b c = Geom.{ a; b; c }

(* rational value of a (rational) Num.t *)
let num_q (x : Num.t) : Q.t =
  match Qqbar.to_q (Num.to_qq x) with
  | Some q -> q
  | None -> failwith "num_q: irrational input where rational expected"

(* --- Num version of F(t): used for coeffs_qq (gate + exact root filter) --- *)
let axiom7_cubic_num (p : Geom.point) (d : Geom.line) (q : Geom.point)
    (e : Geom.line) : Num.t array =
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

(* --- ring ℚ[x]/μ: elements are Poly.t reduced mod μ; x = generator --- *)
module Ring = struct
  let make mu =
    let red p = Poly.rem p mu in
    let radd = Poly.add in
    let rsub a b = Poly.sub a b in
    let rmul a b = red (Poly.mul a b) in
    let rscale (s : Q.t) a = Poly.scale s a in
    let x = Poly.of_list [ Q.zero; Q.one ] in
    let of_q q = Poly.const q in
    (radd, rsub, rmul, rscale, of_q, x)
end

(* F(t) over ℚ[x]/μ as an array of Poly.t (one per t-power); px ↦ x. All
   divisions in F are by rational constants, so we only ever scale by ℚ. *)
let axiom7_cubic_ring mu (d : Geom.line) (q : Geom.point) (e : Geom.line)
    (dq : Geom.line -> Q.t) : Poly.t array =
  ignore dq;
  let radd, rsub, rmul, rscale, of_q, x = Ring.make mu in
  (* rationals extracted from the (rational) inputs *)
  let qz n = n in
  ignore qz;
  (* helpers on ℚ[x]/μ-coefficient polynomials-in-t (arrays of ring elts) *)
  let padd a b =
    let n = max (Array.length a) (Array.length b) in
    Array.init n (fun i ->
        let za = if i < Array.length a then a.(i) else Poly.zero in
        let zb = if i < Array.length b then b.(i) else Poly.zero in
        radd za zb)
  in
  let pscale s a = Array.map (fun c -> rmul s c) a in
  let pmul a b =
    let r = Array.make (Array.length a + Array.length b - 1) Poly.zero in
    Array.iteri
      (fun i ca ->
        Array.iteri (fun j cb -> r.(i + j) <- radd r.(i + j) (rmul ca cb)) b)
      a;
    r
  in
  let psub a b = padd a (Array.map (fun c -> rscale (Q.of_int (-1)) c) b) in
  (* rational-scalar field values as ring constants *)
  let da = of_q (num_q d.a) and db = of_q (num_q d.b)
  and dc = of_q (num_q d.c) in
  let qx = of_q (num_q q.x) and qy = of_q (num_q q.y) in
  let ea = of_q (num_q e.a) and eb = of_q (num_q e.b)
  and ec = of_q (num_q e.c) in
  let n2 = radd (rmul da da) (rmul db db) in
  let n2inv = Poly.const (Q.inv (Poly.eval n2 Q.zero)) in
  (* n2 is a rational constant (d rational) → its inverse is a ℚ scalar *)
  let d0x = rmul (rmul da dc) n2inv and d0y = rmul (rmul db dc) n2inv in
  let half = Q.of_string "1/2" in
  (* p.x = x (the generator); p.y = 1 *)
  let px = x and py = of_q Q.one in
  let aA = [| rsub d0x px; db |] in
  let bB = [| rsub d0y py; rscale (Q.of_int (-1)) da |] in
  let mx = [| rscale half (radd px d0x); rscale half db |] in
  let my = [| rscale half (radd py d0y); rscale half (rscale (Q.of_int (-1)) da) |] in
  let cC = padd (pmul aA mx) (pmul bB my) in
  let n2c = padd (pmul aA aA) (pmul bB bB) in
  let dd = psub (padd (pscale qx aA) (pscale qy bB)) cC in
  let lL = padd (pscale ea aA) (pscale eb bB) in
  let s = rsub (radd (rmul ea qx) (rmul eb qy)) ec in
  psub (pscale s n2c) (pscale (of_q (Q.of_int 2)) (pmul dd lL))

let d = ln (nq "0") (nq "1") (nq "0")
let q = pt (nq "1") (nq "1/2")
let e = ln (nq "1") (nq "0") (nq "0")

(* embed a Poly.t in x as an Mpoly in var `v` of an nvars-space *)
let embed_poly nvars v (p : Poly.t) : Mpoly.t =
  let m = ref Mpoly.zero in
  Array.iteri
    (fun k c ->
      if not (Q.equal c Q.zero) then
        m := Mpoly.add !m (Mpoly.mul (Mpoly.const nvars c) (Mpoly.pow (Mpoly.var nvars v) k)))
    p;
  !m

(* R(t) = Res_x(μ(x), F(t,x)) via Mpoly; var0 = t, var1 = x *)
let pe_resultant mu (fcoeffs : Poly.t array) : Poly.t =
  let nvars = 2 in
  let f_mpoly = ref Mpoly.zero in
  Array.iteri
    (fun i fi ->
      let term = Mpoly.mul (embed_poly nvars 1 fi) (Mpoly.pow (Mpoly.var nvars 0) i) in
      f_mpoly := Mpoly.add !f_mpoly term)
    fcoeffs;
  let mu_mpoly = embed_poly nvars 1 mu in
  let r = Mpoly.resultant !f_mpoly mu_mpoly 1 in
  Mpoly.to_poly_in r 0

let time f = let t0 = Unix.gettimeofday () in let r = f () in (r, Unix.gettimeofday () -. t0)

let () =
  let target = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 7 in
  let px = ref (nq "1/2") in
  (try
     for k = 1 to target do
       let p = pt !px (nq "1") in
       let coeffs = axiom7_cubic_num p d q e in
       let coeffs_qq = Array.map Num.to_qq coeffs in
       let cdeg = Array.fold_left (fun m c -> max m (Qqbar.degree c)) 0 coeffs_qq in
       Printf.printf "round %d (coeff-deg %d):\n%!" k cdeg;

       (* exact filter: eval the true cubic at a qqbar candidate *)
       let eval_p (z : Qqbar.t) : Qqbar.t =
         let acc = ref (Qqbar.of_q Q.zero) in
         for i = Array.length coeffs_qq - 1 downto 0 do
           acc := Qqbar.add (Qqbar.mul !acc z) coeffs_qq.(i)
         done;
         !acc
       in

       (* baseline: qqbar native root-finder *)
       let (qq_res, qq_t) = time (fun () -> Qqbar.real_roots_of_qqbar_poly coeffs_qq) in
       (match qq_res with
        | None -> Printf.printf "  qqbar : None (limit)   %8.3fs\n%!" qq_t
        | Some r -> Printf.printf "  qqbar : %d roots        %8.3fs\n%!" (List.length r) qq_t);

       (* PE-merge: single-generator resultant + FLINT roots + exact filter *)
       let mu = if Qqbar.degree (Num.to_qq !px) <= 1 then Poly.of_list [ Q.zero; Q.one ]
                else Qqbar.minpoly (Num.to_qq !px) in
       let ((pe_roots, rdeg), pe_t) =
         time (fun () ->
             if Qqbar.degree (Num.to_qq !px) <= 1 then
               (* px rational: F already has rational coeffs; FLINT directly *)
               let rp = Poly.normalize (Array.map (fun c -> num_q c) coeffs) in
               let roots = Qqbar.real_roots_of_poly rp
                           |> List.filter (fun z -> Qqbar.is_zero (eval_p z)) in
               (roots, Poly.degree rp)
             else begin
               let fring = axiom7_cubic_ring mu d q e (fun _ -> Q.zero) in
               let (r, res_t) = time (fun () -> pe_resultant mu fring) in
               let (cands, iso_t) = time (fun () -> Qqbar.real_roots_of_poly r) in
               let (roots, filt_t) =
                 time (fun () ->
                     List.filter (fun z -> Qqbar.is_zero (eval_p z)) cands)
               in
               Printf.printf
                 "          [resultant %.3fs | isolate(deg %d, %d cands) %.3fs | filter %.3fs]\n%!"
                 res_t (Poly.degree r) (List.length cands) iso_t filt_t;
               (roots, Poly.degree r)
             end)
       in
       Printf.printf "  pe    : %d roots (R deg %d) %8.3fs\n%!"
         (List.length pe_roots) rdeg pe_t;

       (* correctness gate against qqbar when it succeeded *)
       (match qq_res with
        | Some qr ->
            let s = List.sort_uniq Qqbar.cmp_re in
            let a = s qr and b = s pe_roots in
            if List.length a = List.length b
               && List.for_all2 (fun x y -> Qqbar.cmp_re x y = 0) a b
            then Printf.printf "  gate  : MATCH\n%!"
            else Printf.printf "  gate  : *** MISMATCH ***\n%!"
        | None -> Printf.printf "  gate  : (qqbar failed; pe unverified vs baseline)\n%!");

       (* advance chain with pe roots (they reach further) *)
       (match pe_roots with
        | r :: _ -> px := Num.of_qq r
        | [] ->
            (match qq_res with
             | Some (r :: _) -> px := Num.of_qq r
             | _ -> Printf.printf "  no roots; stopping\n%!"; raise Exit))
     done
   with Exit -> ());
  Printf.printf "done\n%!"
