(* Property tests for the rigid motions: the plane isometries [Isometry] that
   place a face on the table, the motions of space [Isometry3] that place it
   in 3D, and the hinge motion [Fold_state.hinge_motion] built from them.
   Group laws, and the agreement of the 2D and 3D reflections. Generators in
   arb.ml: a plane isometry is a product of up to three reflections, a motion
   of space a product of up to three half-turns. *)

open Beloch

let ( =~ ) = Geom.point_equal

(* ---- Isometry ---- *)

let iso_compose_applies =
  Arb.make ~name:"apply (compose a b) p = apply a (apply b p)" ~count:40
    ~print:(fun (a, b, p) ->
      Arb.iso_str a ^ " ; " ^ Arb.iso_str b ^ " ; " ^ Arb.pt_str p)
    QCheck2.Gen.(triple Arb.iso Arb.iso Arb.pt)
    (fun (a, b, p) ->
      let a = Arb.iso_value a and b = Arb.iso_value b and p = Arb.pt_value p in
      Isometry.apply_point (Isometry.compose a b) p
      =~ Isometry.apply_point a (Isometry.apply_point b p))

let iso_inverse =
  Arb.make ~name:"compose a (inverse a) = id = compose (inverse a) a" ~count:40
    ~print:Arb.iso_str Arb.iso (fun a ->
      let a = Arb.iso_value a in
      Arb.iso_equal (Isometry.compose a (Isometry.inverse a)) Isometry.identity
      && Arb.iso_equal
           (Isometry.compose (Isometry.inverse a) a)
           Isometry.identity)

let iso_associative =
  Arb.make ~name:"compose is associative" ~count:30
    ~print:(fun (a, b, c) ->
      String.concat " ; " (List.map Arb.iso_str [ a; b; c ]))
    QCheck2.Gen.(triple Arb.iso Arb.iso Arb.iso)
    (fun (a, b, c) ->
      let a = Arb.iso_value a and b = Arb.iso_value b and c = Arb.iso_value c in
      Arb.iso_equal
        (Isometry.compose (Isometry.compose a b) c)
        (Isometry.compose a (Isometry.compose b c)))

let iso_identity =
  Arb.make ~name:"compose id a = a = compose a id" ~count:30 ~print:Arb.iso_str
    Arb.iso (fun a ->
      let a = Arb.iso_value a in
      Arb.iso_equal (Isometry.compose Isometry.identity a) a
      && Arb.iso_equal (Isometry.compose a Isometry.identity) a)

let iso_det_sign =
  Arb.make ~name:"det_sign is the parity of the reflections, and multiplies"
    ~count:40
    ~print:(fun (a, b) -> Arb.iso_str a ^ " ; " ^ Arb.iso_str b)
    QCheck2.Gen.(pair Arb.iso Arb.iso)
    (fun (la, lb) ->
      let a = Arb.iso_value la and b = Arb.iso_value lb in
      let parity l = if List.length l mod 2 = 0 then 1 else -1 in
      Isometry.det_sign a = parity la
      && Isometry.det_sign (Isometry.compose a b)
         = Isometry.det_sign a * Isometry.det_sign b
      && Isometry.det_sign (Isometry.inverse a) = Isometry.det_sign a)

let iso_preserves_distance =
  Arb.make ~name:"an isometry preserves distances" ~count:40
    ~print:(fun (a, p, r) ->
      Arb.iso_str a ^ " ; " ^ Arb.pt_str p ^ " ; " ^ Arb.pt_str r)
    QCheck2.Gen.(triple Arb.iso Arb.pt Arb.pt)
    (fun (a, p, r) ->
      let a = Arb.iso_value a and p = Arb.pt_value p and r = Arb.pt_value r in
      Num.equal
        (Arb.dist2 (Isometry.apply_point a p) (Isometry.apply_point a r))
        (Arb.dist2 p r))

let reflection_laws =
  Arb.make
    ~name:
      "a reflection is an involution, fixes its line, agrees with reflect_point"
    ~count:40
    ~print:(fun (l, p) -> Arb.ln_str l ^ " ; " ^ Arb.pt_str p)
    QCheck2.Gen.(pair Arb.ln Arb.pt)
    (fun (l, p) ->
      QCheck2.assume (Arb.proper_ln l);
      let u, v = l in
      let line = Arb.ln_value l and p = Arb.pt_value p in
      let r = Isometry.reflect_across_line line in
      Arb.iso_equal (Isometry.compose r r) Isometry.identity
      && Isometry.det_sign r = -1
      && Isometry.apply_point r (Arb.pt_value u) =~ Arb.pt_value u
      && Isometry.apply_point r (Arb.pt_value v) =~ Arb.pt_value v
      && Isometry.apply_point r p =~ Geom.reflect_point line p)

(* ---- Isometry3 ---- *)

let iso3_compose_applies =
  Arb.make ~name:"3D: apply (compose a b) p = apply a (apply b p)" ~count:40
    ~print:(fun (a, b, p) ->
      Arb.motion_str a ^ " ; " ^ Arb.motion_str b ^ " ; " ^ Arb.pt3_str p)
    QCheck2.Gen.(triple Arb.motion Arb.motion Arb.pt3)
    (fun (a, b, p) ->
      let a = Arb.motion_value a
      and b = Arb.motion_value b
      and p = Arb.pt3_value p in
      Arb.pt3_equal
        (Isometry3.apply_point (Isometry3.compose a b) p)
        (Isometry3.apply_point a (Isometry3.apply_point b p)))

let iso3_inverse =
  Arb.make ~name:"3D: compose a (inverse a) = id = compose (inverse a) a"
    ~count:40 ~print:Arb.motion_str Arb.motion (fun a ->
      let a = Arb.motion_value a in
      Isometry3.equal
        (Isometry3.compose a (Isometry3.inverse a))
        Isometry3.identity
      && Isometry3.equal
           (Isometry3.compose (Isometry3.inverse a) a)
           Isometry3.identity)

let iso3_associative =
  Arb.make ~name:"3D: compose is associative" ~count:30
    ~print:(fun (a, b, c) ->
      String.concat " ; " (List.map Arb.motion_str [ a; b; c ]))
    QCheck2.Gen.(triple Arb.motion Arb.motion Arb.motion)
    (fun (a, b, c) ->
      let a = Arb.motion_value a
      and b = Arb.motion_value b
      and c = Arb.motion_value c in
      Isometry3.equal
        (Isometry3.compose (Isometry3.compose a b) c)
        (Isometry3.compose a (Isometry3.compose b c)))

let half_turn_laws =
  Arb.make ~name:"3D: a half-turn is a proper involution fixing its axis"
    ~count:40
    ~print:(fun (a, (t1, t2)) ->
      Arb.axis_str a ^ Printf.sprintf " ; t = %d/%d" t1 t2)
    QCheck2.Gen.(pair Arb.axis Arb.small_q)
    (fun (ax, (t1, t2)) ->
      QCheck2.assume (Arb.axis_ok ax);
      let h = Arb.half_turn ax in
      let on = Arb.pt3_value (fst ax) and dir = Arb.pt3_value (snd ax) in
      let t = Arb.q t1 t2 in
      let on_axis =
        {
          Isometry3.x = Num.add on.Isometry3.x (Num.mul t dir.Isometry3.x);
          y = Num.add on.Isometry3.y (Num.mul t dir.Isometry3.y);
          z = Num.add on.Isometry3.z (Num.mul t dir.Isometry3.z);
        }
      in
      Isometry3.equal (Isometry3.compose h h) Isometry3.identity
      && Isometry3.det_sign h = 1
      && Arb.pt3_equal (Isometry3.apply_point h on_axis) on_axis)

(* ---- hinge motions ---- *)

let hinge line angle =
  { Fold_state.fa = 0; fb = 1; line; angle; crease_id = 0; prov = None }

let hinge_flat_is_identity =
  Arb.make ~name:"hinge motion at angle 0 is the identity" ~count:20
    ~print:Arb.ln_str Arb.ln (fun l ->
      QCheck2.assume (Arb.proper_ln l);
      Isometry3.equal
        (Fold_state.hinge_motion (hinge (Arb.ln_value l) Num.zero))
        Isometry3.identity)

(* At angle ±1 the hinge motion is the half-turn about the crease line in the
   table plane: an involution, the same for both signs, and on the table
   plane the 2D reflection in the crease. *)
let hinge_folded_is_reflection =
  Arb.make
    ~name:
      "hinge motion at angle +-1 is an involution, the 2D reflection on z = 0"
    ~count:40
    ~print:(fun (l, p) -> Arb.ln_str l ^ " ; " ^ Arb.pt_str p)
    QCheck2.Gen.(pair Arb.ln Arb.pt)
    (fun (l, p) ->
      QCheck2.assume (Arb.proper_ln l);
      let line = Arb.ln_value l and p = Arb.pt_value p in
      let up = Fold_state.hinge_motion (hinge line Num.one)
      and down = Fold_state.hinge_motion (hinge line (Num.neg Num.one)) in
      let image =
        Isometry3.apply_point up
          { Isometry3.x = p.Geom.x; y = p.Geom.y; z = Num.zero }
      in
      let r = Geom.reflect_point line p in
      Isometry3.equal (Isometry3.compose up up) Isometry3.identity
      && Isometry3.equal (Isometry3.compose down down) Isometry3.identity
      && Isometry3.equal up down
      && Num.equal image.Isometry3.x r.Geom.x
      && Num.equal image.Isometry3.y r.Geom.y
      && Num.sign image.Isometry3.z = 0)

let () =
  Arb.run "beloch-prop-motion"
    [
      ( "isometry",
        [
          iso_compose_applies;
          iso_inverse;
          iso_associative;
          iso_identity;
          iso_det_sign;
          iso_preserves_distance;
          reflection_laws;
        ] );
      ( "isometry3",
        [ iso3_compose_applies; iso3_inverse; iso3_associative; half_turn_laws ]
      );
      ("hinge", [ hinge_flat_is_identity; hinge_folded_is_reflection ]);
    ]
