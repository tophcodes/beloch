(** Dense univariate polynomials over ℚ, low coefficient first.
    Invariant: no trailing-zero coefficients; the zero polynomial is [||]. *)
type t = Q.t array

let normalize (a : Q.t array) : t =
  let n = ref (Array.length a) in
  while !n > 0 && Q.equal a.(!n - 1) Q.zero do
    decr n
  done;
  Array.sub a 0 !n

let of_list (l : Q.t list) : t = normalize (Array.of_list l)
let zero : t = [||]
let is_zero (p : t) : bool = Array.length p = 0
let degree (p : t) : int = Array.length p - 1
let leading (p : t) : Q.t = p.(Array.length p - 1)
let const (c : Q.t) : t = if Q.equal c Q.zero then zero else [| c |]

let eval (p : t) (x : Q.t) : Q.t =
  let acc = ref Q.zero in
  for i = Array.length p - 1 downto 0 do
    acc := Q.add (Q.mul !acc x) p.(i)
  done;
  !acc

let add (p : t) (q : t) : t =
  let n = max (Array.length p) (Array.length q) in
  normalize
    (Array.init n (fun i ->
         let a = if i < Array.length p then p.(i) else Q.zero in
         let b = if i < Array.length q then q.(i) else Q.zero in
         Q.add a b))

let neg (p : t) : t = Array.map Q.neg p
let sub (p : t) (q : t) : t = add p (neg q)
let scale (c : Q.t) (p : t) : t =
  if Q.equal c Q.zero then zero else Array.map (Q.mul c) p

let mul (p : t) (q : t) : t =
  if is_zero p || is_zero q then zero
  else begin
    let r = Array.make (Array.length p + Array.length q - 1) Q.zero in
    Array.iteri
      (fun i a -> Array.iteri (fun j b -> r.(i + j) <- Q.add r.(i + j) (Q.mul a b)) q)
      p;
    normalize r
  end

let derivative (p : t) : t =
  if Array.length p <= 1 then zero
  else
    normalize
      (Array.init (Array.length p - 1) (fun i ->
           Q.mul (Q.of_int (i + 1)) p.(i + 1)))

(* a ∘ g, by Horner over the polynomial ring *)
let compose (a : t) (g : t) : t =
  let acc = ref zero in
  for i = Array.length a - 1 downto 0 do
    acc := add (mul !acc g) (const a.(i))
  done;
  !acc

(* p = quo*d + rem, deg rem < deg d, over the field ℚ. *)
let divmod (p : t) (d : t) : t * t =
  if is_zero d then raise Division_by_zero;
  let dd = degree d and ld = leading d in
  let r = ref (Array.copy p) in
  let quo = Array.make (max 1 (Array.length p - dd)) Q.zero in
  while Array.length !r - 1 >= dd && not (is_zero !r) do
    let dr = Array.length !r - 1 in
    let c = Q.div !r.(dr) ld in
    quo.(dr - dd) <- c;
    let nr = Array.copy !r in
    for i = 0 to dd do
      nr.(dr - dd + i) <- Q.sub nr.(dr - dd + i) (Q.mul c d.(i))
    done;
    r := normalize nr
  done;
  (normalize quo, !r)

let rem (p : t) (d : t) : t = snd (divmod p d)
let monic (p : t) : t = if is_zero p then p else scale (Q.inv (leading p)) p

(* Determinant of a square ℚ-matrix by Gaussian elimination. *)
let det (m : Q.t array array) : Q.t =
  let n = Array.length m in
  if n = 0 then Q.one
  else begin
    let a = Array.map Array.copy m in
    let d = ref Q.one in
    (try
       for col = 0 to n - 1 do
         let piv = ref col in
         while !piv < n && Q.equal a.(!piv).(col) Q.zero do
           incr piv
         done;
         if !piv = n then begin
           d := Q.zero;
           raise Exit
         end;
         if !piv <> col then begin
           let tmp = a.(col) in
           a.(col) <- a.(!piv);
           a.(!piv) <- tmp;
           d := Q.neg !d
         end;
         d := Q.mul !d a.(col).(col);
         for row = col + 1 to n - 1 do
           let f = Q.div a.(row).(col) a.(col).(col) in
           for k = col to n - 1 do
             a.(row).(k) <- Q.sub a.(row).(k) (Q.mul f a.(col).(k))
           done
         done
       done;
       !d
     with Exit -> Q.zero)
  end

(* Sylvester resultant of p and q (both nonzero). Constants handled directly. *)
let rec resultant (p : t) (q : t) : Q.t =
  if is_zero p || is_zero q then Q.zero
  else
    let dp = degree p and dq = degree q in
    if dp = 0 then qpow p.(0) dq
    else if dq = 0 then qpow q.(0) dp
    else begin
      let n = dp + dq in
      let m = Array.make_matrix n n Q.zero in
      for i = 0 to dq - 1 do
        for j = 0 to dp do
          m.(i).(i + j) <- p.(dp - j)
        done
      done;
      for i = 0 to dp - 1 do
        for j = 0 to dq do
          m.(dq + i).(i + j) <- q.(dq - j)
        done
      done;
      det m
    end

and qpow (c : Q.t) (k : int) : Q.t =
  let r = ref Q.one in
  for _ = 1 to k do
    r := Q.mul !r c
  done;
  !r

let rec gcd (p : t) (q : t) : t =
  if is_zero q then monic p else gcd q (rem p q)

(* Squarefree part = p / gcd(p, p'), monic. *)
let squarefree_part (p : t) : t =
  if degree p < 1 then monic p
  else
    let g = gcd p (derivative p) in
    monic (fst (divmod p g))

let sign_at (p : t) (x : Q.t) : int = Q.sign (eval p x)

(* Standard Sturm chain: s0 = p, s1 = p', s_{k+1} = -rem(s_{k-1}, s_k). *)
let sturm_sequence (p : t) : t list =
  let s0 = p and s1 = derivative p in
  let rec aux acc a b =
    if is_zero b then List.rev acc else aux (b :: acc) b (neg (rem a b))
  in
  aux [ s0 ] s0 s1

let sign_changes (seq : t list) (x : Q.t) : int =
  let signs =
    List.filter_map
      (fun s ->
        let v = sign_at s x in
        if v = 0 then None else Some v)
      seq
  in
  let rec count = function
    | a :: (b :: _ as r) -> (if a <> b then 1 else 0) + count r
    | _ -> 0
  in
  count signs

(* Number of distinct real roots in (lo, hi]. *)
let count_roots_in (seq : t list) (lo : Q.t) (hi : Q.t) : int =
  sign_changes seq lo - sign_changes seq hi

(* 1 + max|a_i|/|a_n| bounds the absolute value of every real root. *)
let cauchy_bound (p : t) : Q.t =
  let an = Q.abs (leading p) in
  let m = Array.fold_left (fun acc c -> Q.max acc (Q.abs c)) Q.zero p in
  Q.add Q.one (Q.div m an)

(* Disjoint open intervals each holding exactly one simple real root, ascending.
   Works on the squarefree part so every root is simple. *)
let isolate_roots (p : t) : (Q.t * Q.t) list =
  let p = squarefree_part p in
  if degree p < 1 then []
  else begin
    let seq = sturm_sequence p in
    let b = cauchy_bound p in
    let two = Q.of_int 2 in
    let rec go lo hi acc =
      match count_roots_in seq lo hi with
      | 0 -> acc
      | 1 -> (lo, hi) :: acc
      | _ ->
          let m = Q.div (Q.add lo hi) two in
          (* a rational root exactly at m would sit in (lo,m]; nudge so each
             reported interval is open around a single root. squarefree => the
             midpoint is a root only finitely often; perturb when it happens. *)
          let m = if sign_at p m = 0 then Q.div (Q.add lo m) two else m in
          go lo m (go m hi acc)
    in
    go (Q.neg b) b []
  end

(* Lagrange interpolation through points with distinct x-coordinates. *)
let interpolate (pts : (Q.t * Q.t) list) : t =
  let xs = List.map fst pts in
  List.fold_left
    (fun acc (xi, yi) ->
      (* basis polynomial L_i(x) = ∏_{j≠i} (x − xj)/(xi − xj) *)
      let li =
        List.fold_left
          (fun p xj ->
            if Q.equal xj xi then p
            else
              let denom = Q.sub xi xj in
              mul p (of_list [ Q.div (Q.neg xj) denom; Q.div Q.one denom ]))
          (of_list [ Q.one ]) xs
      in
      add acc (scale yi li))
    zero pts
