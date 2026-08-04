(* Symbolic two-fold alignment equations over Beloch.Mpoly.

   Line representation [alperin2006, Def. 2]: (X, Y) is the line
   Xx + Yy + 1 = 0. Lines through the origin are unrepresentable in this
   chart; the paper handles this by translating any concrete configuration
   away from the origin.

   Every reflection formula below (eq. (1), eq. (2)) divides by a
   denominator, but that denominator is a polynomial in the UNKNOWN fold
   coordinates (x_i, y_i), not in the given parameters — genericity of the
   parameters does NOT make it nonzero. Assembling an alignment's equation
   clears the denominator, which enlarges its zero set: any fold position
   where the denominator vanishes now satisfies the cleared equation
   vacuously, whether or not the original alignment held, because there the
   reflected point/line has left the (X, Y) chart altogether. For example,
   AL9 [F_a(L1) <-> F_b(L2)] clears both folded-line denominators; they can
   vanish simultaneously on a 2-dimensional locus of fold pairs regardless of
   whether the folded lines actually coincide, so the cleared system holds
   vacuously there. Consumers solving these systems MUST exclude denominator
   zeros, e.g. by Rabinowitsch saturation (auxiliary variable w, equation
   w·∏den − 1 = 0) — see the Phase-1 plan, Task 7. {!equations_denoms_of}
   exposes exactly the denominators that were cleared, for this purpose;
   {!equations_of} is a convenience wrapper that drops them.

   Fold line i has coordinates x_i = var (2i), y_i = var (2i+1). *)

module M = Beloch.Mpoly

(* ------------------------------------------------------------------ *)
(* Parameter streams                                                   *)
(* ------------------------------------------------------------------ *)

type param_stream = Q.t array

(* Generic rationals: distinct primes in every numerator/denominator,
   alternating signs. Genericity (no coincidences, collinearities, or
   parallelisms among objects built from these) makes every cleared
   denominator below nonzero; the streams are fixed so equation systems are
   reproducible. 24 values = 12 points/lines, enough for any combination of
   at most 4 alignments consuming at most 2 objects each. *)
let stream_of_strings l : param_stream = Array.of_list (List.map Q.of_string l)

let stream_a =
  stream_of_strings
    [
      "17/13";
      "-29/7";
      "41/23";
      "-53/31";
      "67/37";
      "-79/41";
      "97/43";
      "-101/47";
      "113/53";
      "-127/59";
      "131/61";
      "-139/67";
      "149/71";
      "-151/73";
      "163/79";
      "-167/83";
      "173/89";
      "-179/97";
      "181/101";
      "-191/103";
      "193/107";
      "-197/109";
      "199/113";
      "-211/127";
    ]

let stream_b =
  stream_of_strings
    [
      "19/11";
      "-23/17";
      "37/29";
      "-43/13";
      "59/19";
      "-61/7";
      "71/31";
      "-73/23";
      "83/37";
      "-89/41";
      "103/43";
      "-107/47";
      "109/53";
      "-137/59";
      "157/61";
      "-227/67";
      "229/71";
      "-233/73";
      "239/79";
      "-241/83";
      "251/89";
      "-257/97";
      "263/101";
      "-269/103";
    ]

type params = { points : (Q.t * Q.t) list; lines : (Q.t * Q.t) list }

(* How many (points, lines) each alignment kind consumes, per its notation in
   [alperin2006, Fig. 4]. Fold lines are variables, not parameters. *)
let consumes : Alignment.kind -> int * int = function
  | AL1 -> (0, 0) (* F_a(L_b) <-> L_b *)
  | AL2 -> (0, 1) (* F_a(L) <-> L *)
  | AL3 -> (1, 0) (* L_a <-> P *)
  | AL4 -> (0, 1) (* F_a(L) <-> L_b *)
  | AL5 -> (1, 0) (* F_a(P) <-> L_b *)
  | AL6 -> (1, 1) (* F_a(P) <-> L *)
  | AL7 -> (1, 1) (* F_a(P) <-> F_b(L) *)
  | AL8 -> (2, 0) (* F_a(P1) <-> F_b(P2) *)
  | AL9 -> (0, 2) (* F_a(L1) <-> F_b(L2) *)
  | AL10 -> (0, 2)
(* F_b(P_(L_a,L1)) <-> L2 *)

let draw_pair (s : param_stream) (pos : int) : (Q.t * Q.t) * int =
  if pos + 1 >= Array.length s then
    invalid_arg "Symeq: parameter stream exhausted";
  ((s.(pos), s.(pos + 1)), pos + 2)

let rec draw_pairs (s : param_stream) (pos : int) (n : int) :
    (Q.t * Q.t) list * int =
  if n = 0 then ([], pos)
  else
    let p, pos = draw_pair s pos in
    let rest, pos = draw_pairs s pos (n - 1) in
    (p :: rest, pos)

let alignment_params ~(stream : param_stream) ~(start : int) (a : Alignment.t) :
    params * int =
  let np, nl = consumes a.Alignment.kind in
  let points, pos = draw_pairs stream start np in
  let lines, pos = draw_pairs stream pos nl in
  ({ points; lines }, pos)

(* ------------------------------------------------------------------ *)
(* Reflection formulas                                                 *)
(* ------------------------------------------------------------------ *)

let xv nvars fold = M.var nvars (2 * fold)
let yv nvars fold = M.var nvars ((2 * fold) + 1)
let two = Q.of_int 2

(* Folded image across fold line f of a point given as a homogeneous triple
   (nx, ny, d), i.e. the point (nx/d, ny/d) with polynomial coordinates.
   Obtained from [alperin2006, eq. (1)] by substituting px = nx/d, py = ny/d
   and multiplying both coordinates through by d:
     num_x = nx·(y_f² − x_f²) − 2·x_f·(d + ny·y_f)
     num_y = ny·(x_f² − y_f²) − 2·y_f·(d + nx·x_f)
     den   = d·(x_f² + y_f²)
   With d = 1 this is eq. (1) verbatim. x_f² + y_f² > 0 for any actual line
   ((0,0) is not a line in this chart), so den is nonzero whenever d is. *)
let reflect_triple ~nvars ~fold ((nx, ny, d) : M.t * M.t * M.t) :
    M.t * M.t * M.t =
  let x = xv nvars fold and y = yv nvars fold in
  let x2 = M.mul x x and y2 = M.mul y y in
  let two_ = M.const nvars two in
  let num_x =
    M.sub (M.mul nx (M.sub y2 x2)) (M.mul two_ (M.mul x (M.add d (M.mul ny y))))
  in
  let num_y =
    M.sub (M.mul ny (M.sub x2 y2)) (M.mul two_ (M.mul y (M.add d (M.mul nx x))))
  in
  (num_x, num_y, M.mul d (M.add x2 y2))

(* Folded image of a given rational point [alperin2006, eq. (1)]. *)
let reflect_point_raw ~nvars ~fold ((px, py) : Q.t * Q.t) : M.t * M.t * M.t =
  reflect_triple ~nvars ~fold
    (M.const nvars px, M.const nvars py, M.const nvars Q.one)

(* Folded image of a given line (lX, lY) across fold line f. The paper's
   eq. (2) is garbled in our OCR copy, so we derive it. Reflection F across f
   is an involution, so the image of L = {p : lX·p_x + lY·p_y + 1 = 0} is
   {q : F(q) ∈ L}. Substituting eq. (1) for F(q) into L's equation and
   clearing the denominator x_f² + y_f² gives

     lX·(q_x(y_f²−x_f²) − 2x_f(1 + q_y·y_f))
       + lY·(q_y(x_f²−y_f²) − 2y_f(1 + q_x·x_f)) + (x_f² + y_f²) = 0.

   Collecting the coefficients of q_x, q_y and the constant term, then
   dividing by the constant term to return to the (X, Y) chart:

     num_X = lX·(y_f² − x_f²) − 2·x_f·y_f·lY
     num_Y = lY·(x_f² − y_f²) − 2·x_f·y_f·lX
     den   = x_f² + y_f² − 2·lX·x_f − 2·lY·y_f

   den = 0 exactly when the image line passes through the origin, i.e. falls
   outside the chart [alperin2006, Def. 2 discussion] — excluded generically.
   The den agrees with the legible part of the paper's eq. (2)
   (X_F² − 2XX_F − 2YY_F + Y_F²). Validated in tests by the involution
   F(F(L)) = L at three rational fold lines and by cross-checking against
   Geom.reflect_point + Geom.line_through on sample data. *)
let reflect_line_raw ~nvars ~fold ((lX, lY) : Q.t * Q.t) : M.t * M.t * M.t =
  let x = xv nvars fold and y = yv nvars fold in
  let x2 = M.mul x x and y2 = M.mul y y in
  let xy = M.mul x y in
  let c q = M.const nvars q in
  let num_X =
    M.sub (M.mul (c lX) (M.sub y2 x2)) (M.mul (c (Q.mul two lY)) xy)
  in
  let num_Y =
    M.sub (M.mul (c lY) (M.sub x2 y2)) (M.mul (c (Q.mul two lX)) xy)
  in
  let den =
    M.sub (M.add x2 y2)
      (M.add (M.mul (c (Q.mul two lX)) x) (M.mul (c (Q.mul two lY)) y))
  in
  (num_X, num_Y, den)

(* ------------------------------------------------------------------ *)
(* Per-alignment equations                                             *)
(* ------------------------------------------------------------------ *)

(* Incidence [alperin2006, Def. 7] of the point (nx/d, ny/d) with the line
   (lX, lY) given as polynomials: lX·(nx/d) + lY·(ny/d) + 1 = 0, multiplied
   through by d (nonzero generically): lX·nx + lY·ny + d. *)
let incidence ((lX, lY) : M.t * M.t) ((nx, ny, d) : M.t * M.t * M.t) : M.t =
  M.add (M.add (M.mul lX nx) (M.mul lY ny)) d

(* Componentwise equality [alperin2006, Defs. 5, 6] of two homogeneous pairs
   (n1x/d1, n1y/d1) = (n2x/d2, n2y/d2), cross-multiplied (d1, d2 nonzero
   generically): two equations. Works for points and for lines in (X,Y) rep. *)
let eq_pair ((n1x, n1y, d1) : M.t * M.t * M.t)
    ((n2x, n2y, d2) : M.t * M.t * M.t) : M.t list =
  [ M.sub (M.mul n1x d2) (M.mul n2x d1); M.sub (M.mul n1y d2) (M.mul n2y d1) ]

(* Which fold does the folding for AL2–AL7: suffix a -> fold 0, b -> fold 1.
   For AL10 the suffix instead names the fold whose line makes the
   intersection (see below). *)
let fold_of_suffix : Alignment.suffix -> int = function
  | Alignment.A -> 0
  | Alignment.B -> 1
  | Alignment.Sym -> invalid_arg "Symeq: symmetric alignment has no fold suffix"

(* Builds one alignment's equations together with the denominators actually
   cleared to produce them (see the header comment for why this matters). *)
let equations_of_alignment ~nvars (a : Alignment.t) (prm : params) :
    M.t list * M.t list =
  let xv = xv nvars and yv = yv nvars in
  let c q = M.const nvars q in
  let one = M.const nvars Q.one in
  let point_triple (px, py) = (c px, c py, one) in
  match (a.Alignment.kind, prm) with
  | AL1, _ ->
      (* AL1 [F_a(L_b) <-> L_b]: fold b's line is invariant under folding
         across fold a. A reflection maps a line to itself iff the line is
         the axis itself or is perpendicular to the axis (any other line goes
         to its distinct mirror image); the two fold lines are distinct, so
         invariance <=> perpendicularity. The normal direction of line (X, Y)
         is the vector (X, Y) (from Xx + Yy + 1 = 0), and two lines are
         perpendicular iff their normals are:
           x_a·x_b + y_a·y_b = 0   — 1 eq, symmetric in a, b. No reflection is
         performed, so no denominator is cleared. *)
      ([ M.add (M.mul (xv 0) (xv 1)) (M.mul (yv 0) (yv 1)) ], [])
  | AL2, { lines = [ (lX, lY) ]; _ } ->
      (* AL2 [F_a(L) <-> L]: the given line is invariant under fold a. Same
         lemma as AL1 (L is generic, hence not the fold line):
           x_a·lX + y_a·lY = 0   — 1 eq. No denominator cleared. *)
      let f = fold_of_suffix a.Alignment.suffix in
      ([ M.add (M.mul (xv f) (c lX)) (M.mul (yv f) (c lY)) ], [])
  | AL3, { points = [ (px, py) ]; _ } ->
      (* AL3 [L_a <-> P]: the given point lies on fold line a
         [alperin2006, Def. 7]: x_a·px + y_a·py + 1 = 0 — 1 eq. No
         denominator cleared (the given point is exact, not reflected). *)
      let f = fold_of_suffix a.Alignment.suffix in
      ([ incidence (xv f, yv f) (point_triple (px, py)) ], [])
  | AL4, { lines = [ l ]; _ } ->
      (* AL4 [F_a(L) <-> L_b]: the folded given line coincides with fold
         line b, componentwise on the (X, Y) representation
         [alperin2006, Def. 6], cross-multiplied — 2 eqs. Clears the
         reflected line's denominator. *)
      let f = fold_of_suffix a.Alignment.suffix in
      let g = 1 - f in
      let ((_, _, den) as img) = reflect_line_raw ~nvars ~fold:f l in
      (eq_pair img (xv g, yv g, one), [ den ])
  | AL5, { points = [ p ]; _ } ->
      (* AL5 [F_a(P) <-> L_b]: the folded given point lies on fold line b:
         x_b·num_x + y_b·num_y + den = 0 — 1 eq. Clears the reflected
         point's denominator. *)
      let f = fold_of_suffix a.Alignment.suffix in
      let g = 1 - f in
      let ((_, _, d) as img) = reflect_point_raw ~nvars ~fold:f p in
      ([ incidence (xv g, yv g) img ], [ d ])
  | AL6, { points = [ p ]; lines = [ (lX, lY) ] } ->
      (* AL6 [F_a(P) <-> L]: the folded given point lies on the given line:
         lX·num_x + lY·num_y + den = 0 — 1 eq. Clears the reflected point's
         denominator. *)
      let f = fold_of_suffix a.Alignment.suffix in
      let ((_, _, d) as img) = reflect_point_raw ~nvars ~fold:f p in
      ([ incidence (c lX, c lY) img ], [ d ])
  | AL7, { points = [ p ]; lines = [ l ] } ->
      (* AL7 [F_a(P) <-> F_b(L)]: the point folded by a lies on the line
         folded by b. Incidence with both denominators cleared:
         num_X·num_x + num_Y·num_y + den_L·den_P = 0 — 1 eq. *)
      let f = fold_of_suffix a.Alignment.suffix in
      let g = 1 - f in
      let pnx, pny, pd = reflect_point_raw ~nvars ~fold:f p in
      let lnX, lnY, ld = reflect_line_raw ~nvars ~fold:g l in
      ([ incidence (lnX, lnY) (pnx, pny, M.mul pd ld) ], [ pd; ld ])
  | AL8, { points = [ p1; p2 ]; _ } ->
      (* AL8 [F_a(P1) <-> F_b(P2)]: componentwise point equality
         [alperin2006, Def. 5], cross-multiplied — 2 eqs. Symmetric: the
         roles are fixed as fold 0 folds P1, fold 1 folds P2. Clears both
         reflected points' denominators. *)
      let ((_, _, d1) as img1) = reflect_point_raw ~nvars ~fold:0 p1 in
      let ((_, _, d2) as img2) = reflect_point_raw ~nvars ~fold:1 p2 in
      (eq_pair img1 img2, [ d1; d2 ])
  | AL9, { lines = [ l1; l2 ]; _ } ->
      (* AL9 [F_a(L1) <-> F_b(L2)]: componentwise line equality
         [alperin2006, Def. 6], cross-multiplied — 2 eqs. Symmetric: fold 0
         folds L1, fold 1 folds L2. Clears both reflected lines'
         denominators (see header comment: this is the alignment whose
         cleared system admits a 2-dimensional spurious locus). *)
      let ((_, _, d1) as img1) = reflect_line_raw ~nvars ~fold:0 l1 in
      let ((_, _, d2) as img2) = reflect_line_raw ~nvars ~fold:1 l2 in
      (eq_pair img1 img2, [ d1; d2 ])
  | AL10, { lines = [ (x1, y1); l2 ]; _ } ->
      (* AL10 [F_b(P_{L_a,L1}) <-> L2] [alperin2006, §4, AL10 discussion]:
         the virtual point V is the intersection of fold line a with the
         given line L1; V folded by b lies on L2. The suffix names the fold
         whose line makes the intersection: AL10a intersects fold 0's line
         and reflects by fold 1.

         V by Cramer on  x_a·x + y_a·y = −1,  X1·x + Y1·y = −1:
           det = x_a·Y1 − y_a·X1   (zero iff fold line a is parallel to L1 —
                                    a denominator of the intersection, not of
                                    a reflection)
           V = ((y_a − Y1)/det, (X1 − x_a)/det)
         — a homogeneous triple, degree 1 in fold-a variables. Reflect it by
         fold b with the triple formula and require incidence with L2, both
         denominators cleared — 1 eq. *)
      let ia = fold_of_suffix a.Alignment.suffix in
      let rf = 1 - ia in
      let vnx = M.sub (yv ia) (c y1) in
      let vny = M.sub (c x1) (xv ia) in
      let vd = M.sub (M.mul (xv ia) (c y1)) (M.mul (yv ia) (c x1)) in
      let x2, y2 = l2 in
      let fold_den = M.add (M.mul (xv rf) (xv rf)) (M.mul (yv rf) (yv rf)) in
      ( [
          incidence (c x2, c y2) (reflect_triple ~nvars ~fold:rf (vnx, vny, vd));
        ],
        [ vd; fold_den ] )
  | _ -> invalid_arg "Symeq.equations_of: malformed params"

(* Deduplicate denominators by structural equality of the (canonically
   normalized) polynomial, not physical/syntactic equality. *)
let dedup_denoms (denoms : M.t list) : M.t list =
  List.fold_left
    (fun acc d ->
      if List.exists (fun d' -> M.is_zero (M.sub d d')) acc then acc
      else d :: acc)
    [] denoms
  |> List.rev

let equations_denoms_of ~nvars ~(stream : param_stream) (combo : Combo.t) :
    M.t list * M.t list =
  let rec go pos = function
    | [] -> ([], [])
    | a :: rest ->
        let prm, pos = alignment_params ~stream ~start:pos a in
        let eqs, denoms = equations_of_alignment ~nvars a prm in
        let eqs', denoms' = go pos rest in
        (eqs @ eqs', denoms @ denoms')
  in
  let eqs, denoms = go 0 combo in
  (eqs, dedup_denoms denoms)

let equations_of ~nvars ~(stream : param_stream) (combo : Combo.t) : M.t list =
  fst (equations_denoms_of ~nvars ~stream combo)
