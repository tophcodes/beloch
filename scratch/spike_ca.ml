(* Spike driver: stacked axiom-7 cubics, comparing two root-finders on the
   SAME cubic F(t) at each round:
     - qqbar : Qqbar.real_roots_of_qqbar_poly (current kernel path)
     - ca    : Ca.ca_real_roots            (Calcium ca_poly_roots)
   Correctness gate: on every round both must return the same real root set
   (exact, via Qqbar.cmp_re). Timing shows which scales past the round-4 wall.

   Run per target round under timeout:
     for k in 3 4 5 6 7; do timeout 120 dune exec scratch/spike_ca.exe -- $k; done *)
open Beloch

let nq s = Num.of_q (Q.of_string s)
let pt x y = Geom.{ x; y }
let ln a b c = Geom.{ a; b; c }

(* F(t) as Num.t array, verbatim from Geom.beloch7_creases (see spike_diag.ml) *)
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

let d = ln (nq "0") (nq "1") (nq "0")
let q = pt (nq "1") (nq "1/2")
let e = ln (nq "1") (nq "0") (nq "0")

let same_set (a : Qqbar.t list) (b : Qqbar.t list) : bool =
  let s = List.sort_uniq Qqbar.cmp_re in
  let a = s a and b = s b in
  List.length a = List.length b && List.for_all2 (fun x y -> Qqbar.cmp_re x y = 0) a b

let time f = let t0 = Unix.gettimeofday () in let r = f () in (r, Unix.gettimeofday () -. t0)

(* sanity mode: does ca_poly_roots find canonical algebraic roots at all? *)
let sanity () =
  let qq s = Qqbar.of_q (Q.of_string s) in
  let test name coeffs =
    match Ca.ca_real_roots coeffs with
    | None -> Printf.printf "%-28s ca: None\n%!" name
    | Some r ->
        Printf.printf "%-28s ca: %d real roots [%s]\n%!" name (Array.length r)
          (String.concat ", "
             (Array.to_list
                (Array.map (fun x -> Printf.sprintf "%.4f" (Qqbar.to_float x)) r)))
  in
  test "x^3 - 2 (monic)" [| qq "-2"; qq "0"; qq "0"; qq "1" |];
  test "3x^3 - 6 (non-monic)" [| qq "-6"; qq "0"; qq "0"; qq "3" |];
  test "x^3 - x - 1" [| qq "-1"; qq "-1"; qq "0"; qq "1" |];
  test "x^2 - 2" [| qq "-2"; qq "0"; qq "1" |];
  let s2 = Qqbar.sqrt (qq "2") in
  test "x^2 - sqrt2 (alg coeff)" [| Qqbar.neg s2; qq "0"; qq "1" |];
  test "x^3 - sqrt2 (alg coeff)" [| Qqbar.neg s2; qq "0"; qq "0"; qq "1" |]

let () =
  if Array.length Sys.argv > 1 && Sys.argv.(1) = "sanity" then (sanity (); exit 0);
  let target = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 6 in
  let px = ref (nq "1/2") in
  (try
     for k = 1 to target do
       let p = pt !px (nq "1") in
       let coeffs = axiom7_cubic p d q e in
       let coeffs_qq = Array.map Num.to_qq coeffs in
       let cdeg =
         Array.fold_left (fun m c -> max m (Qqbar.degree c)) 0 coeffs_qq
       in
       Printf.printf "round %d (coeff-deg %d):\n%!" k cdeg;

       (* qqbar backend *)
       let (qq_res, qq_t) = time (fun () -> Qqbar.real_roots_of_qqbar_poly coeffs_qq) in
       (match qq_res with
        | None -> Printf.printf "  qqbar: None (limit)          %.3fs\n%!" qq_t
        | Some r -> Printf.printf "  qqbar: %d roots              %.3fs\n%!" (List.length r) qq_t);

       (* calcium backend *)
       let (ca_res, ca_t) = time (fun () -> Ca.ca_real_roots coeffs_qq) in
       (match ca_res with
        | None -> Printf.printf "  ca   : None (couldn't split) %.3fs\n%!" ca_t
        | Some r -> Printf.printf "  ca   : %d roots              %.3fs\n%!" (Array.length r) ca_t);

       (* correctness gate when both produced roots *)
       (match qq_res, ca_res with
        | Some a, Some b ->
            if same_set a (Array.to_list b) then Printf.printf "  gate : MATCH\n%!"
            else Printf.printf "  gate : *** MISMATCH ***\n%!"
        | _ -> ());

       (* advance the chain using whichever backend gave roots *)
       let advance =
         match qq_res, ca_res with
         | Some (r :: _), _ -> Some r
         | _, Some a when Array.length a > 0 -> Some a.(0)
         | _ -> None
       in
       (match advance with
        | Some r -> px := Num.of_qq r
        | None -> Printf.printf "  both failed; stopping\n%!"; raise Exit)
     done
   with Exit -> ());
  Printf.printf "done\n%!"
