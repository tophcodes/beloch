open Beloch
let q = Num.of_int
let gp x y : Geom.point = { Geom.x = q x; y = q y }
let sq a b c d : Fold_graph.face = [| a; b; c; d |]
let i3eq (a : Isometry3.point) (b : Isometry3.point) =
  Num.equal a.Isometry3.x b.Isometry3.x
  && Num.equal a.Isometry3.y b.Isometry3.y
  && Num.equal a.Isometry3.z b.Isometry3.z
let p3 x y z : Isometry3.point = { Isometry3.x = q x; y = q y; z = q z }

(* line x = k : a=1,b=0,c=k *)
let vline k : Geom.line = { Geom.a = q 1; b = q 0; c = q k }

(* SINGLE FOLD: square split at x=1 into face0=[0,1]×[0,1], face1=[1,2]×[0,1];
   one hinge at x=1, folded (angle=1). root=0. face1's placement = reflect across
   x=1, so a face1 point (2,y) lands at (0,y). *)
let test_single_fold () =
  let g = {
    Fold_graph.root = 0;
    faces = [| sq (gp 0 0) (gp 1 0) (gp 1 1) (gp 0 1);
               sq (gp 1 0) (gp 2 0) (gp 2 1) (gp 1 1) |];
    hinges = [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 } |];
  } in
  let isos = Fold_graph.face_isos g in
  Alcotest.(check bool) "root at identity" true
    (i3eq (Isometry3.apply_point isos.(0) (p3 3 5 0)) (p3 3 5 0));
  Alcotest.(check bool) "face1 reflects across x=1" true
    (i3eq (Isometry3.apply_point isos.(1) (p3 2 0 0)) (p3 0 0 0))

(* ACCORDION: strip [0,1],[1,2],[2,3]; hinges at x=1 and x=2, both folded.
   root=0. A face2 point (2.5,y) → half_turn x=2 → (1.5,y) → half_turn x=1 →
   (0.5,y). Proves the multi-hinge PATH product. *)
let test_accordion () =
  let g = {
    Fold_graph.root = 0;
    faces = [| sq (gp 0 0) (gp 1 0) (gp 1 1) (gp 0 1);
               sq (gp 1 0) (gp 2 0) (gp 2 1) (gp 1 1);
               sq (gp 2 0) (gp 3 0) (gp 3 1) (gp 2 1) |];
    hinges = [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 };
                { Fold_graph.fa = 1; fb = 2; line = vline 2; angle = q 1 } |];
  } in
  let isos = Fold_graph.face_isos g in
  let half = Num.of_q (Q.of_ints 1 2) in
  Alcotest.(check bool) "face2 folds back to x=1/2" true
    (i3eq (Isometry3.apply_point isos.(2)
             { Isometry3.x = Num.of_q (Q.of_ints 5 2); y = half; z = q 0 })
          { Isometry3.x = half; y = half; z = q 0 })

let () =
  Alcotest.run "fold_graph"
    [ ("derive",
       [ Alcotest.test_case "single fold" `Quick test_single_fold;
         Alcotest.test_case "accordion path" `Quick test_accordion ]) ]
