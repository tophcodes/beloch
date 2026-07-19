(* Reusable kernel benchmark for Num.real_roots and its primitive-element tier.

   Runs ONE named case per invocation (so a walling case can be bounded with
   `timeout` by the runner) and prints:
     - a human-readable summary line
     - a machine-readable `CSV,...` line for diffing across optimizations

   Ground truth = end-to-end `Num.real_roots`. The per-stage breakdown
   (merge / resultant / real_roots_of_poly / eval_p filter) reproduces the
   Tier-3 pe_path via the public `Field_merge` API so we can attribute where
   time goes; `filter` here is a faithful replica of num.ml's exact eval_p
   check (it may drift if that check changes — trust `total` as the truth).

   Usage:
     dune exec packages/core/bench/bench_real_roots.exe -- <case>
     dune exec packages/core/bench/bench_real_roots.exe -- list      # names, one per line
   Cases: rational | quad | independent | deepstack | stacked:<N>
   Or just run bench/run.sh for the whole corpus under per-case timeouts. *)
open Beloch

let nq s = Num.of_q (Q.of_string s)
let pt x y = Geom.{ x; y }
let ln a b c = Geom.{ a; b; c }

(* one axiom-7 cubic F(t) for focus p.x, same construction as
   Geom.beloch7_creases, in the classic doubling-the-cube setup *)
let d = ln (nq "0") (nq "1") (nq "0")
let q = pt (nq "1") (nq "1/2")
let e = ln (nq "1") (nq "0") (nq "0")

let axiom7_cubic (px : Num.t) : Num.t array =
  let p = pt px (nq "1") in
  let padd a b = let n = max (Array.length a) (Array.length b) in
    Array.init n (fun i ->
        let x = if i < Array.length a then a.(i) else Num.zero in
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

(* stacked chain: feed round k's first real root forward as round k+1's p.x *)
let stacked_coeffs (rounds : int) : Num.t array =
  let px = ref (nq "1/2") in
  for _ = 1 to rounds - 1 do
    match Num.real_roots (axiom7_cubic !px) with r :: _ -> px := r | [] -> ()
  done;
  axiom7_cubic !px

let coeffs_of_case (case : string) : Num.t array =
  match case with
  | "rational" -> [| nq "-2"; nq "0"; nq "0"; nq "1" |] (* x^3 - 2 *)
  | "quad" ->
      let s2 = Num.sqrt (nq "2") in
      [| Num.neg s2; nq "0"; nq "0"; nq "1" |]           (* x^3 - sqrt2 *)
  | "independent" ->
      (* coeffs combine two INDEPENDENT folds sqrt2 and cbrt2 -> Q(sqrt2,cbrt2) *)
      let s2 = Num.sqrt (nq "2") in
      let c2 = List.hd (Num.real_roots [| nq "-2"; nq "0"; nq "0"; nq "1" |]) in
      [| Num.neg s2; c2; nq "0"; nq "1" |]               (* x^3 + cbrt2 x - sqrt2 *)
  | "deepstack" ->
      let g = Num.sqrt (Num.add (Num.sqrt (nq "2")) (Num.sqrt (nq "3"))) in (* deg 8 *)
      [| Num.neg (nq "2"); g; Num.neg (Num.add g g); Num.one |] (* x^3 - 2g x^2 + g x - 2 *)
  | s when String.length s > 8 && String.sub s 0 8 = "stacked:" ->
      stacked_coeffs (int_of_string (String.sub s 8 (String.length s - 8)))
  | _ -> failwith ("unknown case: " ^ case)

let time f = let t0 = Unix.gettimeofday () in let r = f () in
  (r, Unix.gettimeofday () -. t0)

let () =
  (match Sys.argv with
   | [| _; "list" |] ->
       List.iter print_endline
         ["rational"; "quad"; "independent"; "deepstack";
          "stacked:3"; "stacked:4"; "stacked:5"; "stacked:6"; "stacked:7"];
       exit 0
   | _ -> ());
  let case = if Array.length Sys.argv > 1 then Sys.argv.(1) else "stacked:5" in
  let coeffs = coeffs_of_case case in
  let coeffs_qq = Array.map Num.to_qq coeffs in
  let cdeg = Array.fold_left (fun m c -> max m (Qqbar.degree c)) 0 coeffs_qq in
  (* ground truth *)
  let (roots, t_total) = time (fun () -> Num.real_roots coeffs) in
  let nroots = List.length roots in
  (* per-stage attribution via the public pe path (best effort) *)
  let eval_p z =
    let acc = ref (Qqbar.of_q Q.zero) in
    for i = Array.length coeffs_qq - 1 downto 0 do
      acc := Qqbar.add (Qqbar.mul !acc z) coeffs_qq.(i) done; !acc in
  let (merge_s, res_s, rdeg, roots_s, ncands, filt_s) =
    match time (fun () -> Field_merge.merge_generators coeffs_qq) with
    | (None, ms) -> (ms, 0.0, 0, 0.0, 0, 0.0) (* all-rational: pe path N/A *)
    | (Some (mu, coords), ms) ->
        let (r, rs) = time (fun () -> Field_merge.resultant_superset ~coords ~mu) in
        let (cands, cs) = time (fun () -> Qqbar.real_roots_of_poly r) in
        (* mirror num.ml's pe_tier filter: rigorous interval pre-screen, then
           exact eval_p confirm on survivors *)
        let prec = 128 in
        let qmin a b = if Q.compare a b <= 0 then a else b in
        let qmax a b = if Q.compare a b >= 0 then a else b in
        let coeff_encl = Array.map (fun c -> Qqbar.enclosure c ~prec) coeffs_qq in
        let interval_excludes_zero z =
          let iadd (a, b) (c, d) = (Q.add a c, Q.add b d) in
          let imul (a, b) (c, d) =
            let p1 = Q.mul a c and p2 = Q.mul a d
            and p3 = Q.mul b c and p4 = Q.mul b d in
            (qmin (qmin p1 p2) (qmin p3 p4), qmax (qmax p1 p2) (qmax p3 p4)) in
          let zi = Qqbar.enclosure z ~prec in
          let acc = ref (Q.zero, Q.zero) in
          for i = Array.length coeff_encl - 1 downto 0 do
            acc := iadd (imul !acc zi) coeff_encl.(i) done;
          let lo, hi = !acc in
          Q.compare lo Q.zero > 0 || Q.compare hi Q.zero < 0 in
        let (_, fs) = time (fun () ->
            List.filter (fun z ->
                if interval_excludes_zero z then false
                else Qqbar.is_zero (eval_p z)) cands) in
        (ms, rs, Poly.degree r, cs, List.length cands, fs)
  in
  Printf.printf
    "%-12s deg %-2d | total %8.3fs | merge %.3f  resultant %.3f (R deg %d)  roots %.3f  filter %.3f | %d roots\n%!"
    case cdeg t_total merge_s res_s rdeg roots_s filt_s nroots;
  Printf.printf "CSV,%s,%d,%.4f,%.4f,%.4f,%d,%.4f,%d,%.4f,%d\n%!"
    case cdeg t_total merge_s res_s rdeg roots_s ncands filt_s nroots
