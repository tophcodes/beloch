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

let () =
  Alcotest.run "isometry3"
    [ ("core",
       [ Alcotest.test_case "identity" `Quick test_identity;
         Alcotest.test_case "compose" `Quick test_compose_is_apply_after ]);
      ("half_turn",
       [ Alcotest.test_case "reflection-equiv" `Quick test_half_turn_is_2d_reflection;
         Alcotest.test_case "involution" `Quick test_half_turn_is_involution ]) ]
