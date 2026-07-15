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

let () =
  Alcotest.run "isometry3"
    [ ("core",
       [ Alcotest.test_case "identity" `Quick test_identity;
         Alcotest.test_case "compose" `Quick test_compose_is_apply_after ]) ]
