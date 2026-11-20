(* Per-operation cost of [Num]'s two representations of an irrational value,
   by degree: [Field] (coordinates over one generator, pure OCaml) against
   [Qq] (FLINT qqbar, a canonical minimal polynomial per value). The constant
   [Num.field_degree_cap] decides which one a value of a given degree takes;
   this benchmark measures where [Field] stops being the faster one.

   Each degree has a generator of the kind folding produces where there is
   one: nested square roots, and a root of a cubic over a field of degree 1
   to 4, which is what an axiom-7 crease on such points solves. Degrees with
   no small folding example use the real root of x^D - x - 1. Two values of
   the field with dense coordinates are combined by [Num.add], [Num.mul],
   [Num.inv] and [Num.sign] in both representations. [sign~0] is the sign
   of a value within 2^-80 of zero, where no float decides it. The chains
   run 12 steps of [v <- v*x + y] and of [v <- 1/(v + x)]; they report the
   cost of the last step and the widest numerator or denominator of the
   [Field] coordinates in bits, which is the coefficient growth the [Field]
   path pays for. [upgrade] is the cost of turning a [Qq] of the degree
   into a generator ([Num.field_upgrade]); [express] is one
   [Qqbar.express_over] onto the generator, for a member of the field and
   for a root of x^p - 3 with p the smallest prime dividing the degree,
   which lies outside the field. The [Field] path pays [upgrade] once per
   value that enters it and [express] once per pair of generators that
   meet, and once per value of a field of composite degree that meets
   another generator.

   Usage: dune exec packages/core/bench/bench_field.exe -- [D1 D2 ...]
   (default 2 to 12). Prints one line per degree; times in microseconds. *)
open Beloch

let poly l = Poly.of_list (List.map Q.of_int l)
let num_of_poly_root p lo hi = Num.make (poly p) (Q.of_string lo) (Q.of_string hi)

(* The real root of a cubic over the field of [c]: t^3 + c t^2 - (1 + c) t
   - 1/2, between 0 and 2. Its shape is what an axiom-7 crease solves; any
   cubic over the field with a simple real root serves the measurement. *)
let cubic_over (c : Num.t) : Num.t =
  let half = Num.of_q (Q.of_ints 1 2) in
  let coeffs = [| Num.neg half; Num.neg (Num.add Num.one c); c; Num.one |] in
  match List.filter (fun r -> Num.sign r > 0) (Num.real_roots coeffs) with
  | r :: _ -> r
  | [] -> failwith "cubic_over: no positive root"

let sqrt2 () = Num.sqrt (Num.of_int 2)
let crane () = Num.sqrt (Num.sub (Num.of_int 4) (Num.mul (Num.of_int 2) (sqrt2 ())))

let generic d =
  let c = Array.make (d + 1) 0 in
  c.(0) <- -1; c.(1) <- -1; c.(d) <- 1;
  num_of_poly_root (Array.to_list c) "1" "2"

let generator d : string * Num.t =
  match d with
  | 2 -> ("sqrt 2", sqrt2 ())
  | 3 -> ("cubic over Q", cubic_over (Num.of_q (Q.of_ints 1 3)))
  | 4 -> ("sqrt(4 - 2 sqrt 2)", crane ())
  | 6 -> ("cubic over Q(sqrt 2)", cubic_over (sqrt2 ()))
  | 8 ->
      ( "sqrt(2 + sqrt(2 + sqrt 2))",
        Num.sqrt
          (Num.add (Num.of_int 2) (Num.sqrt (Num.add (Num.of_int 2) (sqrt2 ())))) )
  | 9 ->
      ( "cubic over a cubic",
        cubic_over (cubic_over (Num.of_q (Q.of_ints 1 3))) )
  | 12 -> ("cubic over Q(sqrt(4 - 2 sqrt 2))", cubic_over (crane ()))
  | d -> (Printf.sprintf "x^%d - x - 1" d, generic d)

(* The generator as a [Field] over itself, whatever the cap says: the
   minimal polynomial from FLINT and an enclosure narrowed until it isolates
   the root, as [Num.field_upgrade] builds it. *)
let as_field (a : Qqbar.t) : Num.gen =
  let mu = Qqbar.minpoly a in
  let seq = Poly.sturm_sequence mu in
  let rec go prec =
    let lo, hi = Qqbar.enclosure a ~prec in
    if Poly.count_roots_in seq lo hi = 1 && Poly.sign_at mu lo <> 0
       && Poly.sign_at mu hi <> 0
    then Num.mk_gen ~mu ~lo ~hi
    else go (2 * prec)
  in
  go 64

(* Seconds per call of [f], over at least 0.2 s and 3 calls. *)
let per_call f =
  let t0 = Unix.gettimeofday () in
  let rec go n =
    ignore (Sys.opaque_identity (f ()));
    let dt = Unix.gettimeofday () -. t0 in
    if dt < 0.2 || n < 3 then go (n + 1) else dt /. float_of_int n
  in
  go 1

let us s = s *. 1e6

let coeff_bits (x : Num.t) =
  match x with
  | Num.Field { coords; _ } ->
      Array.fold_left
        (fun m c -> max m (max (Z.numbits (Q.num c)) (Z.numbits (Q.den c))))
        0 coords
  | _ -> 0

let run d =
  let name, g = generator d in
  let a = Num.to_qq g in
  if Qqbar.degree a <> d then
    failwith (Printf.sprintf "degree %d: %s has degree %d" d name (Qqbar.degree a));
  let gen = as_field a in
  let field l = Num.Field { gen; coords = Poly.of_list (List.map Q.of_string l) } in
  let dense k = List.init d (fun i -> Printf.sprintf "%d/%d" (((i * 7) + k) mod 11 - 5) (i + 2)) in
  let xf = field (dense 1) and yf = field (dense 4) in
  let xq = Num.to_qq xf and yq = Num.to_qq yf in
  let qq q = Num.of_qq q in
  (* a value within 2^-80 of zero: x minus a rational that close to it *)
  let lo, _ = Qqbar.enclosure xq ~prec:80 in
  let nf = Num.sub xf (Num.of_q lo) and nq = Qqbar.sub xq (Qqbar.of_q lo) in
  ignore (Num.sign xf);
  let add_f = per_call (fun () -> Num.add xf yf)
  and add_q = per_call (fun () -> qq (Qqbar.add xq yq))
  and mul_f = per_call (fun () -> Num.mul xf yf)
  and mul_q = per_call (fun () -> qq (Qqbar.mul xq yq))
  and inv_f = per_call (fun () -> Num.inv xf)
  and inv_q = per_call (fun () -> qq (Qqbar.inv xq))
  and sgn_f = per_call (fun () -> Num.sign xf)
  and sgn_q = per_call (fun () -> Qqbar.sign_re xq)
  and sz_f = per_call (fun () -> Num.sign nf)
  and sz_q = per_call (fun () -> Qqbar.sign_re nq) in
  let upg = per_call (fun () -> as_field a) in
  let p = List.find (fun p -> d mod p = 0) [ 2; 3; 5; 7; 11; 13 ] in
  let outside =
    Num.to_qq (num_of_poly_root ((-3) :: List.init (p - 1) (fun _ -> 0) @ [ 1 ]) "1" "2")
  in
  let hit = per_call (fun () -> Qqbar.express_over ~gen:a xq) in
  let miss = per_call (fun () -> Qqbar.express_over ~gen:a outside) in
  if Qqbar.express_over ~gen:a outside <> None then failwith "outside is inside";
  let steps = 12 in
  let chain step v0 =
    let v = ref v0 in
    for _ = 1 to steps - 1 do v := step !v done;
    !v
  in
  let ma_f v = Num.add (Num.mul v xf) yf and ma_q v = Qqbar.add (Qqbar.mul v xq) yq in
  let iv_f v = Num.inv (Num.add v xf) and iv_q v = Qqbar.inv (Qqbar.add v xq) in
  let vma_f = chain ma_f xf and vma_q = chain ma_q xq in
  let viv_f = chain iv_f yf and viv_q = chain iv_q yq in
  let cma_f = per_call (fun () -> ma_f vma_f) and cma_q = per_call (fun () -> ma_q vma_q) in
  let civ_f = per_call (fun () -> iv_f viv_f) and civ_q = per_call (fun () -> iv_q viv_q) in
  Printf.printf
    "deg %2d %-34s | add %8.1f %8.1f | mul %8.1f %8.1f | inv %8.1f %8.1f | sign %7.1f %7.1f | sign~0 %8.1f %8.1f | chain v*x+y %8.1f %8.1f (%4d bits) | chain 1/(v+x) %8.1f %8.1f (%4d bits)\n%!"
    d name (us add_f) (us add_q) (us mul_f) (us mul_q) (us inv_f) (us inv_q)
    (us sgn_f) (us sgn_q) (us sz_f) (us sz_q) (us cma_f) (us cma_q)
    (coeff_bits (ma_f vma_f)) (us civ_f) (us civ_q) (coeff_bits (iv_f viv_f));
  Printf.printf "       upgrade %10.1f | express member %10.1f | express outside %10.1f\n%!"
    (us upg) (us hit) (us miss)

let () =
  print_endline
    "times in us, Field then Qq; bits = widest numerator or denominator of the Field coordinates after the chain";
  let degs =
    if Array.length Sys.argv > 1 then
      Array.to_list (Array.sub Sys.argv 1 (Array.length Sys.argv - 1))
      |> List.map int_of_string
    else List.init 11 (fun i -> i + 2)
  in
  List.iter run degs
