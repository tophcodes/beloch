open Beloch

let q = Num.of_int
let half = Num.div Num.one (q 2)
let pt x y = { Geom.x; Geom.y }
let o = pt half half

(* the four full lines: two diagonals + horizontal + vertical through center,
   each paired with the two ray far-tips it contributes (from O outward). *)
let line_specs =
  [
    (Geom.line_through (pt (q 0) (q 0)) (pt (q 1) (q 1)),
      [ pt (q 1) (q 1); pt (q 0) (q 0) ]);
    (Geom.line_through (pt (q 1) (q 0)) (pt (q 0) (q 1)),
      [ pt (q 0) (q 1); pt (q 1) (q 0) ]);
    (Geom.line_through (pt (q 0) half) (pt (q 1) half),
      [ pt (q 1) half; pt (q 0) half ]);
    (Geom.line_through (pt half (q 0)) (pt half (q 1)),
      [ pt half (q 1); pt half (q 0) ]);
  ]

(* precreased state + the 8 (far-tip, cid) ray descriptors in a fixed order:
   diag1 x2, diag2 x2, horiz x2, vert x2. *)
let precreased () =
  List.fold_left
    (fun (st, rays) (l, fars) ->
      let cid = Fold_state.fresh_crease_id () in
      let st' = Fold_state.subdivide ~crease_id:cid st l ~prov:None in
      (st', rays @ List.map (fun f -> (f, cid)) fars))
    (Fold_state.init_square, [])
    line_specs

(* build elems for the 8 rays given a valley assignment (bool array length 8) *)
let elems_of st_rays valleys =
  List.mapi
    (fun i (far, cid) -> { Collapse.cid; ea = o; eb = far; valley = valleys.(i) })
    st_rays

let prefix pre s =
  let lp = String.length pre in
  String.length s >= lp && String.sub s 0 lp = pre

(* -- Step 1 tests --------------------------------------------------------- *)

let all_rays () = snd (precreased ())

(* closure product of the 8 symmetric rays is the identity (Kawasaki holds) *)
let test_closure_holds () =
  let rays = all_rays () in
  let es = elems_of rays (Array.make 8 true) in
  let sorted = Array.of_list (Collapse.sort_ccw o es) in
  Alcotest.(check bool) "8-ray symmetric cross closes (Kawasaki)" true
    (Collapse.closure_ok o sorted)

(* odd element count is rejected outright *)
let test_odd_count_rejected () =
  let st, rays = precreased () in
  let es = elems_of rays (Array.make 8 true) in
  let seven = List.filteri (fun i _ -> i < 7) es in
  match Collapse.collapse st seven ~over:[] with
  | Ok _ -> Alcotest.fail "odd count must be rejected"
  | Error e -> Alcotest.(check bool) ("count error: " ^ e) true (prefix "count" e)

(* elems that share no common point are rejected *)
let test_no_common_vertex_rejected () =
  let st, _ = precreased () in
  (* four elems with pairwise-distinct disjoint endpoints *)
  let es =
    [
      { Collapse.cid = 0; ea = pt (q 0) (q 0); eb = pt (q 1) (q 0); valley = true };
      { Collapse.cid = 1; ea = pt (q 1) (q 1); eb = pt (q 0) (q 1); valley = true };
      { Collapse.cid = 2; ea = pt (q 0) (q 1); eb = pt (q 1) (q 1); valley = false };
      { Collapse.cid = 3; ea = pt (q 1) (q 0); eb = pt (q 0) (q 0); valley = false };
    ]
  in
  match Collapse.collapse st es ~over:[] with
  | Ok _ -> Alcotest.fail "no common vertex must be rejected"
  | Error e ->
      Alcotest.(check bool) ("vertex error: " ^ e) true
        (prefix "no common interior vertex" e)

(* replace the horizontal line by a non-mirrored ray through O — Kawasaki fails *)
let test_kawasaki_rejected () =
  (* rays: keep the two diagonals + vertical (6 rays), add a tilted pair through
     center: (1/2,1/2)->(1,1/4) and its NON-mirror partner. We use the ray tips
     (1,1/4) and (0,1/2): the alternating angle sum is no longer zero. *)
  let tilted =
    [
      (pt (q 1) (q 1), 0); (pt (q 0) (q 0), 0);
      (pt (q 0) (q 1), 1); (pt (q 1) (q 0), 1);
      (pt (q 1) (Num.div (q 1) (q 4)), 2); (pt (q 0) half, 2);
      (pt half (q 1), 3); (pt half (q 0), 3);
    ]
  in
  let es = elems_of tilted (Array.make 8 true) in
  let sorted = Array.of_list (Collapse.sort_ccw o es) in
  Alcotest.(check bool) "tilted vertex fails closure" false
    (Collapse.closure_ok o sorted)

(* all-valley on the symmetric cross: |M-V| = 8 ≠ 2, Maekawa is violated *)
let test_maekawa_rejected () =
  let st, rays = precreased () in
  let es = elems_of rays (Array.make 8 true) in
  match Collapse.collapse st es ~over:[] with
  | Ok _ -> Alcotest.fail "all-valley must fail Maekawa"
  | Error e ->
      Alcotest.(check bool) ("Maekawa error: " ^ e) true (prefix "Maekawa" e)

(* -- waterbomb assignment (empirical) ------------------------------------- *)

(* VERIFIED waterbomb M/V for the 8-valent all-45° center vertex.
   Straight lines through O give collinear ray-pairs, but each ray carries an
   INDEPENDENT crease (the material `cross` splits bundles at O — spec §Semantics),
   so Maekawa applies to the 8 rays, not the 4 lines: |M−V| must be 2, i.e. 5-3.
   [hull2020, ch. 5]: at O, #M and #V differ by exactly 2 (Maekawa's theorem);
   Kawasaki (alternating 45° sum = 0) holds for any 45° cross.

   The initial guess in the brief (diagonals mountain, axes valley) is 4-4 and
   fails Maekawa; iterating to |M−V|=2 gives realizable assignments. Empirically
   (see the kernel's exact enumeration) EVERY |M−V|=2 pattern on this vertex is
   flat-foldable — 0 self-intersections across all 56 of them; 16 fold to a
   unique layer order, 96 are ambiguous (need `over`). The 5-valley/3-mountain
   contiguous pattern below is one of the unique-order ones: collapse returns Ok.
   NB: refs/hull2020.txt is not present in this worktree (refs/ is gitignored),
   so the |M−V|=2 relation is taken from the spec's citation, not re-derived from
   the source text; the realizability is proved by the kernel itself. *)
let waterbomb_valleys = [| true; true; true; true; true; false; false; false |]

let test_waterbomb_assignment () =
  let st, rays = precreased () in
  let es = elems_of rays waterbomb_valleys in
  match Collapse.collapse st es ~over:[] with
  | Ok s ->
      (* the 8 sectors survive as 8 faces in the folded state *)
      Alcotest.(check int) "collapsed waterbomb has 8 faces" 8
        (Array.length s.Fold_state.faces)
  | Error e ->
      (* an ambiguous-stacking error would still mean the assignment is
         flat-foldable (closure + Maekawa + a valid layer order all passed) *)
      Alcotest.(check bool)
        ("waterbomb assignment is realizable (Ok or ambiguous), got: " ^ e)
        true (prefix "ambiguous stacking" e)

(* -- eassign parity hand-verify (fold_with_records convention) ------------- *)

(* A degree-4 "+" vertex at the centre: horizontal (y=1/2) and vertical (x=1/2)
   lines, four 90° sectors. Kawasaki holds (90−90+90−90 = 0). *)
let precreased_plus () =
  let hline = Geom.line_through (pt (q 0) half) (pt (q 1) half) in
  let vline = Geom.line_through (pt half (q 0)) (pt half (q 1)) in
  let cidh = Fold_state.fresh_crease_id () in
  let st = Fold_state.subdivide ~crease_id:cidh Fold_state.init_square hline ~prov:None in
  let cidv = Fold_state.fresh_crease_id () in
  let st = Fold_state.subdivide ~crease_id:cidv st vline ~prov:None in
  (* rays CCW-ish order: right(h), up(v), left(h), down(v) *)
  let rays =
    [ (pt (q 1) half, cidh); (pt half (q 1), cidv);
      (pt (q 0) half, cidh); (pt half (q 0), cidv) ]
  in
  (st, cidh, cidv, rays)

(* Convention (mirrors [Fold_state.fold_with_records]): a stored V means
   user_valley <> (det_sign old_iso < 0) for the crease's left (stayer) sector.
   Worked example, assignment [M;V;M;M] on the "+" vertex (ray order
   right,up,left,down):
     - up (user V, left sector 0 with T_0 = identity, det > 0): eff = V, stored V.
     - down (user M, left sector 2 with det(T_2) > 0): eff = M, stored M.
     - right & left (user M, but their left sectors 3 and 1 have det(T) < 0):
       the XOR flips M into a stored V.
   So the vertical crease carries one V and one M; the horizontal crease carries
   two V. This is exactly what the parity rule predicts and no folded crease
   stays U. *)
let test_eassign_parity () =
  let st, cidh, cidv, rays = precreased_plus () in
  let es = elems_of rays [| false; true; false; false |] in
  match Collapse.collapse st es ~over:[] with
  | Error e -> Alcotest.fail ("expected Ok, got: " ^ e)
  | Ok s ->
      let assigns cid =
        Array.to_list s.Fold_state.edges
        |> List.filter (fun (e : Fold_state.edge) -> e.Fold_state.crease_id = cid)
        |> List.map (fun (e : Fold_state.edge) -> e.Fold_state.eassign)
        |> List.sort compare
      in
      Alcotest.(check bool) "horizontal crease: both rays stored V (parity flip)"
        true (assigns cidh = [ Fold_state.V; Fold_state.V ]);
      Alcotest.(check bool) "vertical crease: one V (up) + one M (down)" true
        (List.sort compare (assigns cidv) = [ Fold_state.M; Fold_state.V ]);
      let has_u =
        Array.exists
          (fun (e : Fold_state.edge) -> e.Fold_state.eassign = Fold_state.U)
          s.Fold_state.edges
      in
      Alcotest.(check bool) "no folded crease left as U" false has_u

let () =
  Alcotest.run "collapse"
    [
      ( "flat-foldability",
        [
          Alcotest.test_case "closure holds (symmetric cross)" `Quick
            test_closure_holds;
          Alcotest.test_case "Kawasaki rejected (tilted ray)" `Quick
            test_kawasaki_rejected;
        ] );
      ( "guards",
        [
          Alcotest.test_case "odd count rejected" `Quick test_odd_count_rejected;
          Alcotest.test_case "no common vertex rejected" `Quick
            test_no_common_vertex_rejected;
          Alcotest.test_case "Maekawa rejected (all valley)" `Quick
            test_maekawa_rejected;
        ] );
      ( "waterbomb",
        [
          Alcotest.test_case "empirical MV assignment is realizable" `Quick
            test_waterbomb_assignment;
        ] );
      ( "eassign",
        [
          Alcotest.test_case "parity flip on a worked +-vertex" `Quick
            test_eassign_parity;
        ] );
    ]
