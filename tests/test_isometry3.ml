open Beloch
let q = Num.of_int
let p x y z = { Isometry3.x = q x; y = q y; z = q z }
let peq (a : Isometry3.point) (b : Isometry3.point) =
  Num.equal a.Isometry3.x b.Isometry3.x && Num.equal a.y b.y && Num.equal a.z b.z

let test_identity () =
  Alcotest.(check bool) "id fixes a point" true
    (peq (Isometry3.apply_point Isometry3.identity (p 3 (-2) 5)) (p 3 (-2) 5))

let test_compose_is_apply_after () =
  (* compose a b applied = a (b p); use two half-turns once that exists, here
     use identity-composed-identity as the associativity/shape check *)
  let i = Isometry3.identity in
  Alcotest.(check bool) "id∘id = id on a point" true
    (peq (Isometry3.apply_point (Isometry3.compose i i) (p 1 2 3)) (p 1 2 3))

(* a z=0 line ℓ: through (0,0) along (1,2). half_turn about it, on a z=0 point,
   must equal the 2D reflection across the same line. *)
let test_half_turn_is_2d_reflection () =
  let on = p 0 0 0 and dir = p 1 2 0 in
  let h = Isometry3.half_turn_about_line ~on ~dir in
  let l = Geom.line_through { Geom.x = q 0; y = q 0 } { Geom.x = q 1; y = q 2 } in
  let refl2d = Isometry.reflect_across_line l in
  let src2 = { Geom.x = q 3; y = q (-1) } in
  let r2 = Isometry.apply_point refl2d src2 in
  let r3 = Isometry3.apply_point h (p 3 (-1) 0) in
  Alcotest.(check bool) "half-turn on z=0 = 2D reflection" true
    (Num.equal r3.Isometry3.x r2.Geom.x
     && Num.equal r3.y r2.Geom.y
     && Num.sign r3.z = 0)

let test_half_turn_is_involution () =
  let h = Isometry3.half_turn_about_line ~on:(p 0 0 0) ~dir:(p 1 2 0) in
  let hh = Isometry3.compose h h in
  Alcotest.(check bool) "h∘h = id on a point" true
    (peq (Isometry3.apply_point hh (p 5 7 (-3))) (p 5 7 (-3)))

(* compose h1 h2 must apply as h1 (h2 p) — computed independently by nesting
   apply_point — and two distinct half-turns must NOT commute. Axes must meet at
   a non-right angle: half-turns about perpendicular axes (e.g. x- and y-axes)
   are both diagonal and DO commute, so we use x-axis and a 45° in-plane axis. *)
let test_compose_order () =
  let h1 = Isometry3.half_turn_about_line ~on:(p 0 0 0) ~dir:(p 1 0 0) in
  let h2 = Isometry3.half_turn_about_line ~on:(p 0 0 0) ~dir:(p 1 1 0) in
  let src = p 1 2 3 in
  let via_compose = Isometry3.apply_point (Isometry3.compose h1 h2) src in
  let via_nesting = Isometry3.apply_point h1 (Isometry3.apply_point h2 src) in
  let order_matters =
    let r12 = Isometry3.apply_point (Isometry3.compose h1 h2) src in
    let r21 = Isometry3.apply_point (Isometry3.compose h2 h1) src in
    not (peq r12 r21)
  in
  Alcotest.(check bool) "compose h1 h2 = h1 ∘ h2, and non-commuting" true
    (peq via_compose via_nesting && order_matters)

let test_inverse_round_trip () =
  let h = Isometry3.half_turn_about_line ~on:(p 1 1 0) ~dir:(p 1 2 0) in
  let q3 = p 4 (-2) 5 in
  let fwd = Isometry3.apply_point (Isometry3.compose h (Isometry3.inverse h)) q3 in
  let bwd = Isometry3.apply_point (Isometry3.compose (Isometry3.inverse h) h) q3 in
  Alcotest.(check bool) "h ∘ h⁻¹ = h⁻¹ ∘ h = id" true
    (peq fwd q3 && peq bwd q3)

let test_det_sign_is_rotation () =
  let h = Isometry3.half_turn_about_line ~on:(p 0 0 0) ~dir:(p 1 2 0) in
  Alcotest.(check int) "half-turn det = +1 (proper rotation)" 1
    (Isometry3.det_sign h)

let test_equal () =
  let h = Isometry3.half_turn_about_line ~on:(p 1 0 0) ~dir:(p 0 1 0) in
  Alcotest.(check bool) "identity = identity" true
    (Isometry3.equal Isometry3.identity Isometry3.identity);
  Alcotest.(check bool) "half-turn <> identity" false
    (Isometry3.equal h Isometry3.identity);
  Alcotest.(check bool) "involution: h∘h = identity" true
    (Isometry3.equal (Isometry3.compose h h) Isometry3.identity);
  Alcotest.(check bool) "inverse round-trip via equal" true
    (Isometry3.equal (Isometry3.compose h (Isometry3.inverse h)) Isometry3.identity)

let () =
  Alcotest.run "isometry3"
    [ ("core",
       [ Alcotest.test_case "identity" `Quick test_identity;
         Alcotest.test_case "compose" `Quick test_compose_is_apply_after ]);
      ("half_turn",
       [ Alcotest.test_case "reflection-equiv" `Quick test_half_turn_is_2d_reflection;
         Alcotest.test_case "involution" `Quick test_half_turn_is_involution ]);
      ("more",
       [ Alcotest.test_case "compose-order" `Quick test_compose_order;
         Alcotest.test_case "inverse-round-trip" `Quick test_inverse_round_trip;
         Alcotest.test_case "det-sign" `Quick test_det_sign_is_rotation;
         Alcotest.test_case "equal" `Quick test_equal ]) ]
