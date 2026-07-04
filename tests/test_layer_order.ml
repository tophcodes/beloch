open Beloch
module L = Layer_order

let p x y = { Geom.x = Num.of_int x; y = Num.of_int y }
let sq cx cy = [| p cx cy; p (cx+2) cy; p (cx+2) (cy+2); p cx (cy+2) |]

(* reference O(n²) build: same overlap test, same rel_of *)
let ref_pairs polys rel_of =
  let n = Array.length polys in
  let acc = ref [] in
  for i = 0 to n - 1 do
    for j = i + 1 to n - 1 do
      if Geom.convex_overlap polys.(i) polys.(j) then acc := (i, j, rel_of i j) :: !acc
    done
  done;
  List.sort compare !acc

let test_sap_matches_reference () =
  (* a spread-out grid of unit-ish squares, some overlapping, some not *)
  let polys =
    [| sq 0 0; sq 1 1; sq 5 0; sq 6 1; sq 0 5; sq 3 3; sq 10 10 |]
  in
  let rel_of i j = if (i + j) land 1 = 0 then L.Above else L.Below in
  let t = L.build polys rel_of in
  let got = ref [] in
  L.iter t (fun i j r -> got := (i, j, r) :: !got);
  let got = List.sort compare !got in
  Alcotest.(check bool) "SAP pairs == reference pairs" true
    (got = ref_pairs polys rel_of)

let test_get_and_absent () =
  let polys = [| sq 0 0; sq 1 1; sq 10 10 |] in
  let t = L.build polys (fun _ _ -> L.Above) in
  Alcotest.(check bool) "overlapping 0-1 present" true (L.get t 0 1 = L.Above);
  Alcotest.(check bool) "symmetric 1-0 negated" true (L.get t 1 0 = L.Below);
  Alcotest.(check bool) "non-overlapping 0-2 absent = Apart" true (L.get t 0 2 = L.Apart);
  Alcotest.(check bool) "self = Apart" true (L.get t 0 0 = L.Apart)

let test_apart_stored_for_overlap () =
  (* overlapping pair whose rel_of says Apart must be RETRIEVABLE as Apart
     (tortilla-tortilla case) and appear in iter *)
  let polys = [| sq 0 0; sq 1 1 |] in
  let t = L.build polys (fun _ _ -> L.Apart) in
  Alcotest.(check bool) "overlap-but-Apart via get" true (L.get t 0 1 = L.Apart);
  let seen = ref false in
  L.iter t (fun i j r -> if i = 0 && j = 1 && r = L.Apart then seen := true);
  Alcotest.(check bool) "overlap-but-Apart in iter" true !seen

let test_above_neighbors () =
  let polys = [| sq 0 0; sq 1 1; sq 0 1 |] in (* all three overlap *)
  let t = L.build polys (fun _ _ -> L.Above) in (* i<j Above ⇒ 0>1,0>2,1>2 *)
  Alcotest.(check (list int)) "above neighbours of 0" [ 1; 2 ]
    (List.sort compare (L.above_neighbors t 0));
  Alcotest.(check (list int)) "above neighbours of 2" []
    (List.sort compare (L.above_neighbors t 2))

let test_flip_remaps_and_negates () =
  let polys = [| sq 0 0; sq 1 1 |] in
  let t = L.build polys (fun _ _ -> L.Above) in (* get 0 1 = Above, get 1 0 = Below *)
  let f = L.flip t 2 in
  (* flip remaps k↦1-k and negates: old adj.(1)[0]=Below → new adj.(0)[1]=Above *)
  Alcotest.(check bool) "flip: new get 0 1 = Above" true (L.get f 0 1 = L.Above);
  Alcotest.(check bool) "flip: new get 1 0 = Below" true (L.get f 1 0 = L.Below)

let () =
  Alcotest.run "layer_order"
    [ ( "layer_order",
        [ Alcotest.test_case "SAP matches reference" `Quick test_sap_matches_reference;
          Alcotest.test_case "get and absent" `Quick test_get_and_absent;
          Alcotest.test_case "Apart stored for overlap" `Quick test_apart_stored_for_overlap;
          Alcotest.test_case "above neighbours" `Quick test_above_neighbors;
          Alcotest.test_case "flip remaps and negates" `Quick test_flip_remaps_and_negates ] ) ]
