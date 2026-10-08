(* Property tests for the seven axioms: every crease a construction returns
   carries out the alignment that was asked for, checked by reflecting in the
   crease rather than by repeating the construction. Beloch numbers the
   axioms as docs/reference/BELOCH.md does: 5 maps a line onto a line, 6 a point onto a
   line through a point, 7 two points onto two lines (Huzita-Justin 3, 5
   and 6).

   Two layers. The solvers in [Geom] that [Axiom.axis_of] calls are checked on
   generated points and lines, for soundness (every candidate is a line that
   performs the alignment) and, where a construction has several candidates,
   for completeness: a crease is drawn first, the operands are placed so that
   it performs the alignment, and the solver has to find it among its
   candidates. The second layer runs generated programs through the
   evaluator, which resolves the operands, calls [Axiom.axis_of] and selects
   a candidate, and checks the line it binds. *)

open Beloch
module G = QCheck2.Gen

let reflect = Geom.reflect_point

(* [l] reflected in [c] is [m] *)
let maps_line_onto c l m = Geom.same_line (Arb.reflect_line c l) m
let maps_point_onto_line c p d = Arb.on_line d (reflect c p)
let pp = Arb.pt_str
let pl = Arb.ln_str
let lines_str ls = "[" ^ String.concat "; " (List.map Arb.line_str ls) ^ "]"

(* ---- the solvers, sound ---- *)

let axiom1 =
  Arb.make ~name:"axiom 1: the line through p and q holds both" ~count:60
    ~print:(fun (p, q) -> pp p ^ " ; " ^ pp q)
    (G.pair Arb.pt Arb.pt)
    (fun (p, q) ->
      let p = Arb.pt_value p and q = Arb.pt_value q in
      QCheck2.assume (not (Geom.point_equal p q));
      let c = Geom.line_through p q in
      Arb.is_line c && Arb.on_line c p && Arb.on_line c q)

let axiom2 =
  Arb.make ~name:"axiom 2: the crease maps p onto q" ~count:60
    ~print:(fun (p, q) -> pp p ^ " ; " ^ pp q)
    (G.pair Arb.pt Arb.pt)
    (fun (p, q) ->
      let p = Arb.pt_value p and q = Arb.pt_value q in
      QCheck2.assume (not (Geom.point_equal p q));
      let c = Geom.perpendicular_bisector p q in
      Arb.is_line c
      && Geom.point_equal (reflect c p) q
      && Geom.point_equal (reflect c q) p)

let axiom3 =
  Arb.make ~name:"axiom 3: the crease is perpendicular to l through p" ~count:60
    ~print:(fun (p, l) -> pp p ^ " ; " ^ pl l)
    (G.pair Arb.pt Arb.ln)
    (fun (p, l) ->
      QCheck2.assume (Arb.proper_ln l);
      let p = Arb.pt_value p and l = Arb.ln_value l in
      let c = Geom.perpendicular_through l p in
      Arb.is_line c && Arb.on_line c p && Arb.perpendicular c l
      && maps_line_onto c l l)

let axiom4 =
  Arb.make ~name:"axiom 4: the crease maps p onto l1 and is perpendicular to l2"
    ~count:60
    ~print:(fun (p, l1, l2) -> pp p ^ " ; " ^ pl l1 ^ " ; " ^ pl l2)
    (G.triple Arb.pt Arb.ln Arb.ln)
    (fun (p, l1, l2) ->
      QCheck2.assume (Arb.proper_ln l1 && Arb.proper_ln l2);
      let p = Arb.pt_value p
      and l1 = Arb.ln_value l1
      and l2 = Arb.ln_value l2 in
      match Geom.project_crease p l1 l2 with
      | None -> Geom.parallel l1 l2
      | Some c ->
          (not (Geom.parallel l1 l2))
          && Arb.is_line c
          && maps_point_onto_line c p l1
          && Arb.perpendicular c l2)

(* Axiom 5 on rational lines. The bisectors carry the norm √(a² + b²) of each
   line's normal; over coefficients already in ℚ(√2) those nested radicals
   cost seconds per case, and two rational lines whose norms lie in
   different quadratic fields cost a quarter of a second, the lattice search
   for a common field. Three cases in four therefore turn l1 by a rational
   rotation (a Pythagorean triple), which keeps the norm. *)
let pythagorean = [| (3, 4, 5); (5, 12, 13); (8, 15, 17); (0, 1, 1) |]

let axiom5_gen =
  G.(
    let* l1 = Arb.rational_ln
    and* l2 = Arb.rational_ln
    and* turn =
      oneof_weighted [ (1, return None); (3, map Option.some (int_range 0 3)) ]
    in
    match turn with
    | None -> return (l1, l2)
    | Some i ->
        let (cx, cy), (dx, dy) = l1 in
        let (ox, oy), _ = l2 in
        let a, b, h = pythagorean.(i) in
        (* the direction of l1, turned by the angle whose cosine is a/h *)
        let v = function
          | Arb.R (n, d) -> Q.of_ints n d
          | Arb.Irr _ -> assert false
        in
        let ux = Q.sub (v dx) (v cx) and uy = Q.sub (v dy) (v cy) in
        let c = Q.of_ints a h and s = Q.of_ints b h in
        let wx = Q.sub (Q.mul c ux) (Q.mul s uy)
        and wy = Q.add (Q.mul s ux) (Q.mul c uy) in
        let to_coord x = Arb.R (Z.to_int (Q.num x), Z.to_int (Q.den x)) in
        let ex = Q.add (v ox) wx and ey = Q.add (v oy) wy in
        return (l1, ((ox, oy), (to_coord ex, to_coord ey))))

let axiom5 =
  Arb.make ~name:"axiom 5: every candidate maps l1 onto l2" ~count:24
    ~print:(fun (l1, l2) -> pl l1 ^ " ; " ^ pl l2)
    axiom5_gen
    (fun (l1, l2) ->
      QCheck2.assume (Arb.proper_ln l1 && Arb.proper_ln l2);
      let l1 = Arb.ln_value l1 and l2 = Arb.ln_value l2 in
      QCheck2.assume (not (Geom.same_line l1 l2));
      let cands =
        match Geom.angle_bisectors l1 l2 with
        | Some (b1, b2) -> [ b1; b2 ]
        | None -> [ Geom.parallel_midline l1 l2 ]
      in
      List.for_all
        (fun c ->
          Arb.is_line c && maps_line_onto c l1 l2 && maps_line_onto c l2 l1)
        cands)

(* Axiom 6 with p on d is allowed (p folds onto another point of d); p on
   the crease's pivot q is not, [Axiom.axis_of] refuses it. *)
let axiom6_gen =
  G.(
    let* p = Arb.pt
    and* d = Arb.ln
    and* q = Arb.pt
    and* p_on_d = oneof_list_weighted [ (4, false); (1, true) ] in
    (* a fifth of the cases put p on d *)
    return (p, (if p_on_d then (p, snd d) else d), q))

let axiom6 =
  Arb.make ~name:"axiom 6: every candidate maps p onto d and holds q" ~count:60
    ~print:(fun (p, d, q) -> pp p ^ " ; " ^ pl d ^ " ; " ^ pp q)
    axiom6_gen
    (fun (p, d, q) ->
      QCheck2.assume (Arb.proper_ln d);
      let p = Arb.pt_value p and d = Arb.ln_value d and q = Arb.pt_value q in
      QCheck2.assume (not (Geom.point_equal p q));
      List.for_all
        (fun c ->
          Arb.is_line c && maps_point_onto_line c p d && Arb.on_line c q)
        (Geom.beloch_creases p d q))

(* Axiom 7 with p on d: [Axiom.axis_of] refuses q on e and parallel d, e,
   and nothing else, so p on d reaches the solver. *)
let axiom7_gen =
  G.(
    let* p = Arb.rational_pt
    and* d = Arb.rational_ln
    and* q = Arb.rational_pt
    and* e = Arb.rational_ln
    and* p_on_d = oneof_list_weighted [ (4, false); (1, true) ] in
    return (p, (if p_on_d then (p, snd d) else d), q, e))

let axiom7_print (p, d, q, e) =
  pp p ^ " ; " ^ pl d ^ " ; " ^ pp q ^ " ; " ^ pl e

let axiom7 =
  Arb.make ~name:"axiom 7: every candidate maps p onto d and q onto e" ~count:40
    ~print:axiom7_print axiom7_gen (fun (p, d, q, e) ->
      QCheck2.assume (Arb.proper_ln d && Arb.proper_ln e);
      let p = Arb.pt_value p and d = Arb.ln_value d in
      let q = Arb.pt_value q and e = Arb.ln_value e in
      (* the preconditions [Axiom.axis_of] checks before it solves, and
         p apart from q *)
      QCheck2.assume (Geom.side_of_line e q <> 0 && not (Geom.parallel d e));
      QCheck2.assume (not (Geom.point_equal p q));
      let cands = Geom.beloch7_creases p d q e in
      if not (List.for_all Arb.is_line cands) then
        QCheck2.Test.fail_reportf "a candidate is no line: %s" (lines_str cands);
      List.for_all
        (fun c -> maps_point_onto_line c p d && maps_point_onto_line c q e)
        cands)

(* ---- the solvers, complete ---- *)

(* A crease [c] and a point not on it, with the point's mirror image. *)
let off_crease (c : Arb.ln) (p : Arb.pt) =
  QCheck2.assume (Arb.proper_ln c);
  let cl = Arb.ln_value c and pv = Arb.pt_value p in
  QCheck2.assume (not (Arb.on_line cl pv));
  (cl, pv, reflect cl pv)

let found c cands = List.exists (Geom.same_line c) cands

let axiom5_complete =
  Arb.make ~name:"axiom 5: a crease mapping l1 onto l2 is among the candidates"
    ~count:60
    ~print:(fun (c, l) -> "crease " ^ pl c ^ " ; " ^ pl l)
    (G.pair Arb.rational_ln Arb.rational_ln)
    (fun (c, l) ->
      QCheck2.assume (Arb.proper_ln c && Arb.proper_ln l);
      let c = Arb.ln_value c and l1 = Arb.ln_value l in
      let l2 = Arb.reflect_line c l1 in
      (* a crease that maps l1 onto itself is no axiom-5 crease *)
      QCheck2.assume (not (Geom.same_line l1 l2));
      let cands =
        match Geom.angle_bisectors l1 l2 with
        | Some (b1, b2) -> [ b1; b2 ]
        | None -> [ Geom.parallel_midline l1 l2 ]
      in
      found c cands)

let axiom6_complete =
  Arb.make
    ~name:"axiom 6: a crease through q mapping p onto d is among the candidates"
    ~count:60
    ~print:(fun (c, p, dir, t) ->
      Printf.sprintf "crease %s ; p %s ; d along %s ; q at %d/%d" (pl c) (pp p)
        (pp dir) (fst t) (snd t))
    (G.quad Arb.ln Arb.pt Arb.pt Arb.small_q)
    (fun (c, p, dir, (t1, t2)) ->
      let cl, pv, landing = off_crease c p in
      let dir = Arb.pt_value dir in
      QCheck2.assume
        (not (Geom.point_equal dir { Geom.x = Num.zero; y = Num.zero }));
      let other =
        {
          Geom.x = Num.add landing.Geom.x dir.Geom.x;
          y = Num.add landing.Geom.y dir.Geom.y;
        }
      in
      let d = Geom.line_through landing other in
      let u, v = Arb.two_points_on cl in
      let t = Arb.q t1 t2 in
      let q =
        {
          Geom.x = Num.add u.Geom.x (Num.mul t (Num.sub v.Geom.x u.Geom.x));
          y = Num.add u.Geom.y (Num.mul t (Num.sub v.Geom.y u.Geom.y));
        }
      in
      found cl (Geom.beloch_creases pv d q))

let axiom7_complete =
  Arb.make
    ~name:
      "axiom 7: a crease mapping p onto d and q onto e is among the candidates"
    ~count:40
    ~print:(fun ((c, p, q), (dp, dq)) ->
      Printf.sprintf "crease %s ; p %s ; q %s ; d along %s ; e along %s" (pl c)
        (pp p) (pp q) (pp dp) (pp dq))
    G.(
      pair
        (triple Arb.rational_ln Arb.rational_pt Arb.rational_pt)
        (pair Arb.rational_pt Arb.rational_pt))
    (fun ((c, p, q), (dp, dq)) ->
      let cl, pv, p' = off_crease c p in
      let _, qv, q' = off_crease c q in
      let through (a : Geom.point) dir =
        let dir = Arb.pt_value dir in
        QCheck2.assume
          (not (Geom.point_equal dir { Geom.x = Num.zero; y = Num.zero }));
        Geom.line_through a
          {
            Geom.x = Num.add a.Geom.x dir.Geom.x;
            y = Num.add a.Geom.y dir.Geom.y;
          }
      in
      let d = through p' dp and e = through q' dq in
      QCheck2.assume (Geom.side_of_line e qv <> 0 && not (Geom.parallel d e));
      found cl (Geom.beloch7_creases pv d qv e))

(* ---- through the evaluator ---- *)

(* A program on the unit square: three points on the edges, a crease
   between the first two, a point inside on it, a line bound by `=` through
   the third edge point and the inner one, and then one construction over
   these operands, bound to --res. The operands are given by index into the
   pools below, so the generator and its shrinking know nothing about the
   language. *)
type program = {
  edge_pts : ((int * (int * int)) * (int * (int * int))) * (int * (int * int));
      (** per edge point: the edge (0 to 3) and the fraction of it *)
  inner : int * int;  (** the fraction along the crease *)
  kind : int;  (** the axiom, 1 to 7 *)
  pts : int * int;  (** the point operands, as indices into [point_pool] *)
  lns : int * int;  (** the line operands, as indices into [line_pool] *)
  toward : int;  (** the point of [point_pool] named by `toward` *)
}

let edges = [| ("ab", "a"); ("bc", "b"); ("cd", "c"); ("da", "d") |]
let point_pool = [| "a"; "b"; "c"; "d"; "e1"; "e2"; "e3"; "i1" |]
let line_pool = [| "ab"; "bc"; "cd"; "da"; "m"; "k" |]

let fraction =
  G.(map2 (fun a b -> (min a (b - 1), b)) (int_range 1 6) (int_range 2 7))

let program =
  G.(
    let* e1 = pair (int_range 0 3) fraction
    and* e2 = pair (int_range 1 3) fraction
    and* e3 = pair (int_range 0 3) fraction
    and* inner = fraction
    (* axioms 6 and 7 fail most often (out of reach, ambiguous), so they are
       drawn more often to be checked about as often as the others *)
    and* kind =
      oneof_list_weighted
        [ (1, 1); (1, 2); (1, 3); (1, 4); (2, 5); (3, 6); (5, 7) ]
    and* pts = pair (int_range 0 7) (int_range 0 7)
    and* lns = pair (int_range 0 5) (int_range 0 5)
    and* toward = int_range 0 3 in
    (* the second edge point on another edge than the first, so the crease
       between them runs inside the paper *)
    let e2 = ((fst e1 + fst e2) mod 4, snd e2) in
    return { edge_pts = ((e1, e2), e3); inner; kind; pts; lns; toward })

let construction (p : program) =
  let pt i = "." ^ point_pool.(i) and ln i = "--" ^ line_pool.(i) in
  let p1, p2 = p.pts and l1, l2 = p.lns in
  match p.kind with
  | 1 -> Printf.sprintf "(through %s %s)" (pt p1) (pt p2)
  | 2 -> Printf.sprintf "(map %s onto %s)" (pt p1) (pt p2)
  | 3 -> Printf.sprintf "(perp %s through %s)" (ln l1) (pt p1)
  | 4 -> Printf.sprintf "(map %s onto %s perp %s)" (pt p1) (ln l1) (ln l2)
  | 5 -> Printf.sprintf "(map %s onto %s)" (ln l1) (ln l2)
  | 6 -> Printf.sprintf "(map %s onto %s through %s)" (pt p1) (ln l1) (pt p2)
  | _ ->
      Printf.sprintf "(map %s onto %s and %s onto %s)" (pt p1) (ln l1) (pt p2)
        (ln l2)

let source (p : program) =
  let (e1, e2), e3 = p.edge_pts in
  let edge_pt name (e, (a, b)) =
    let line, from = edges.(e) in
    Printf.sprintf ".%s = free on --%s from .%s at %d/%d\n" name line from a b
  in
  (* axioms 5 to 7 can have several candidates; `toward` picks one *)
  let toward =
    if p.kind >= 5 then Printf.sprintf " (toward .%s)" point_pool.(p.toward)
    else ""
  in
  "paper square\n" ^ edge_pt "e1" e1 ^ edge_pt "e2" e2 ^ edge_pt "e3" e3
  ^ "mark (through .e1 .e2) as --m\n"
  ^ Printf.sprintf ".i1 = free on --m from .e1 at %d/%d\n" (fst p.inner)
      (snd p.inner)
  ^ "--k = (through .e3 .i1)\n"
  ^ Printf.sprintf "--res = %s%s\n" (construction p) toward

let assoc4 name l =
  List.find_map (fun (n, v, _, _) -> if n = name then Some v else None) l

(* The construction's alignment, checked on the line the program bound. *)
let program_holds (p : program) =
  match Eval.eval_folded (Beloch.parse ~filename:"prop.bel" (source p)) with
  | exception Error.Beloch_error _ ->
      (* a program the language refuses (no fold exists, two candidates
         remain, a crease off the paper) carries no line to check *)
      QCheck2.assume_fail ()
  | fd -> (
      let point name = Option.get (assoc4 name fd.Eval.named_points) in
      let line name =
        match assoc4 name fd.Eval.named_lines with
        | Some l -> l
        | None -> (
            match
              List.find_opt (fun (e, _) -> e = name) (Array.to_list edges)
            with
            | Some (e, _) ->
                Geom.line_through
                  (point (String.sub e 0 1))
                  (point (String.sub e 1 1))
            | None -> failwith ("no line --" ^ name))
      in
      let c = line "res" in
      let pt i = point point_pool.(i) and ln i = line line_pool.(i) in
      let p1, p2 = p.pts and l1, l2 = p.lns in
      Arb.is_line c
      &&
      match p.kind with
      | 1 -> Arb.on_line c (pt p1) && Arb.on_line c (pt p2)
      | 2 -> Geom.point_equal (reflect c (pt p1)) (pt p2)
      | 3 -> Arb.on_line c (pt p1) && Arb.perpendicular c (ln l1)
      | 4 ->
          maps_point_onto_line c (pt p1) (ln l1) && Arb.perpendicular c (ln l2)
      | 5 -> maps_line_onto c (ln l1) (ln l2)
      | 6 -> maps_point_onto_line c (pt p1) (ln l1) && Arb.on_line c (pt p2)
      | _ ->
          maps_point_onto_line c (pt p1) (ln l1)
          && maps_point_onto_line c (pt p2) (ln l2))

(* Most draws are programs the language refuses (two equal operands, no
   fold, an ambiguity `toward` does not settle), so the generator is called
   many times per checked case. *)
let program_axioms =
  Arb.make ~name:"the line a construction binds carries out its alignments"
    ~count:60 ~max_gen:2000 ~print:source program program_holds

let () =
  Arb.run "beloch-prop-axiom"
    [
      ("sound", [ axiom1; axiom2; axiom3; axiom4; axiom5; axiom6; axiom7 ]);
      ("complete", [ axiom5_complete; axiom6_complete; axiom7_complete ]);
      ("program", [ program_axioms ]);
    ]
