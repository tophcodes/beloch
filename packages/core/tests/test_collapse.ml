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

(* precreased state + the 8 (far-tip, [cid]) ray descriptors in a fixed order:
   diag1 ×2, diag2 ×2, horizontal ×2, vert ×2. *)
let precreased () =
  List.fold_left
    (fun (st, rays) (l, fars) ->
      let cid = Fold_state.fresh_crease_id () in
      let st' = Fold_state.subdivide ~crease_id:cid st l ~prov:None in
      (st', rays @ List.map (fun f -> (f, cid)) fars))
    ((Fold_state.flat [| Sheet.square_corners Num.one |]), [])
    line_specs

(* the elements of the rays, from O to each far tip *)
let elems_of st_rays =
  List.map (fun (far, cid) -> { Collapse.cid; ea = o; eb = far }) st_rays

(* a point inside table polygon [i] of [st]: the average of its corners *)
let in_face st i =
  let poly = Fold_state.table_polygon st i in
  let n = Num.of_int (Array.length poly) in
  let mean f = Num.div (Array.fold_left (fun acc p -> Num.add acc (f p)) Num.zero poly) n in
  pt (mean (fun p -> p.Geom.x)) (mean (fun p -> p.Geom.y))

(* every state of the fan [es] on [st] with the letters [valleys] (in [es]
   order), the part that holds the points [staying] kept still *)
let collapse st es valleys ~over ~staying =
  match
    Collapse.collapse_all_patterns st es ~over ~stayer:(Collapse.Points staying)
      ~patterns:[ Array.to_list valleys ]
  with
  | [ r ] -> r
  | _ -> assert false

let prefix pre s =
  let lp = String.length pre in
  String.length s >= lp && String.sub s 0 lp = pre

(* -- flat-foldability ----------------------------------------------------- *)

let all_rays () = snd (precreased ())

(* closure product of the 8 symmetric rays is the identity (Kawasaki holds) *)
let test_closure_holds () =
  let rays = all_rays () in
  let es = elems_of rays in
  let sorted = Array.of_list (Collapse.sort_ccw o es) in
  Alcotest.(check bool) "8-ray symmetric cross closes (Kawasaki)" true
    (Collapse.closure_ok o sorted)

(* odd element count is rejected outright *)
let test_odd_count_rejected () =
  let st, rays = precreased () in
  let seven = List.filteri (fun i _ -> i < 7) (elems_of rays) in
  match collapse st seven (Array.make 7 true) ~over:[] ~staying:[ in_face st 0 ] with
  | Ok _ -> Alcotest.fail "odd count must be rejected"
  | Error e -> Alcotest.(check bool) ("count error: " ^ e) true (prefix "count" e)

(* elements that share no common point are rejected *)
let test_no_common_vertex_rejected () =
  let st, _ = precreased () in
  (* four elements with pairwise-distinct disjoint endpoints *)
  let es =
    [
      { Collapse.cid = 0; ea = pt (q 0) (q 0); eb = pt (q 1) (q 0) };
      { Collapse.cid = 1; ea = pt (q 1) (q 1); eb = pt (q 0) (q 1) };
      { Collapse.cid = 2; ea = pt (q 0) (q 1); eb = pt (q 1) (q 1) };
      { Collapse.cid = 3; ea = pt (q 1) (q 0); eb = pt (q 0) (q 0) };
    ]
  in
  match
    collapse st es [| true; true; false; false |] ~over:[] ~staying:[ in_face st 0 ]
  with
  | Ok _ -> Alcotest.fail "no common vertex must be rejected"
  | Error e ->
      Alcotest.(check bool) ("vertex error: " ^ e) true
        (prefix "no common interior vertex" e)

(* replace the horizontal line by a non-mirrored ray through O: Kawasaki fails *)
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
  let es = elems_of tilted in
  let sorted = Array.of_list (Collapse.sort_ccw o es) in
  Alcotest.(check bool) "tilted vertex fails closure" false
    (Collapse.closure_ok o sorted)

(* all-valley on the symmetric cross: |M-V| = 8 ≠ 2, Maekawa is violated *)
let test_maekawa_rejected () =
  let st, rays = precreased () in
  match
    collapse st (elems_of rays) (Array.make 8 true) ~over:[] ~staying:[ in_face st 0 ]
  with
  | Ok _ -> Alcotest.fail "all-valley must fail Maekawa"
  | Error e ->
      Alcotest.(check bool) ("Maekawa error: " ^ e) true (prefix "Maekawa" e)

(* -- waterbomb assignment (empirical) ------------------------------------- *)

(* VERIFIED waterbomb M/V for the 8-valent all-45° center vertex.
   Straight lines through O give collinear ray-pairs, but each ray carries an
   INDEPENDENT crease (the material `cross` splits bundles at O, spec §Semantics),
   so Maekawa applies to the 8 rays, not the 4 lines: |M−V| must be 2, i.e. 5-3.
   [hull2020, ch. 5]: at O, #M and #V differ by exactly 2 (Maekawa's theorem);
   Kawasaki (alternating 45° sum = 0) holds for any 45° cross.

   The initial guess in the brief (diagonals mountain, axes valley) is 4-4 and
   fails Maekawa; iterating to |M−V|=2 gives realizable assignments. Empirically
   (see the kernel's exact enumeration) EVERY |M−V|=2 pattern on this vertex is
   flat-foldable: 0 self-intersections across all 56 of them; 16 fold to a
   unique layer order, 96 are ambiguous (need `over`). The 5-valley/3-mountain
   contiguous pattern below is one of the unique-order ones: one state.
   NB: refs/hull2020.txt is not present in this worktree (refs/ is gitignored),
   so the |M−V|=2 relation is taken from the spec's citation, not re-derived from
   the source text; the realizability is proved by the kernel itself. *)
let waterbomb_valleys = [| true; true; true; true; true; false; false; false |]

let test_waterbomb_assignment () =
  let st, rays = precreased () in
  match
    collapse st (elems_of rays) waterbomb_valleys ~over:[] ~staying:[ in_face st 0 ]
  with
  | Ok (s :: _) ->
      (* the 8 sectors survive as 8 faces in the folded state *)
      Alcotest.(check int) "collapsed waterbomb has 8 faces" 8
        (Array.length (Fold_state.faces s))
  | Ok [] -> Alcotest.fail "waterbomb assignment is realizable, got no state"
  | Error e -> Alcotest.fail ("waterbomb assignment is realizable, got: " ^ e)

(* -- over resolves ambiguity ---------------------------------------------- *)

(* The 8-ray cross, valley pattern [V;V;M;M;V;M;M;M]: |nm-nv| = |5-3| = 2
   (Maekawa holds) but the stacking is ambiguous without `over`; over=[(3,4)]
   (face 3 above face 4) resolves it to one state. Both facts are pinned
   here as literals, verified against an earlier certified kernel. *)
let over_valleys = [| true; true; false; false; true; false; false; false |]

(* The `over` pair (3,4) is pinned as face-index literals against the
   un-rotated [sort_ccw] labeling, where the anchor sits in fan sector 0. The
   kernel rotates the labeling to the stayer sector, so to keep this pin's
   intent the stayer is a point in sector 0: the midpoint of the far tips of
   its two rays. The labeling then rotates by 0 (a no-op), reproducing the
   exact labeling the over-literals were calibrated for. *)
let sector0_point es =
  match Collapse.sort_ccw o es with
  | (a, _) :: (b, _) :: _ ->
      pt (Num.div (Num.add a.Geom.x b.Geom.x) (q 2))
        (Num.div (Num.add a.Geom.y b.Geom.y) (q 2))
  | _ -> assert false

let test_over_resolves_ambiguity () =
  let st, rays = precreased () in
  let es = elems_of rays in
  let staying = [ sector0_point es ] in
  (match collapse st es over_valleys ~over:[] ~staying with
  | Ok (_ :: _ :: _) -> ()
  | Ok _ -> Alcotest.fail "expected several states without `over`"
  | Error e -> Alcotest.fail ("expected several states without `over`, got: " ^ e));
  match collapse st es over_valleys ~over:[ (3, 4) ] ~staying with
  | Error e -> Alcotest.fail ("expected one state with over, got: " ^ e)
  | Ok l when List.length l <> 1 ->
      Alcotest.failf "expected one state with over, got %d" (List.length l)
  | Ok l ->
      let s = List.hd l in
      Alcotest.(check int) "over-resolved collapse keeps 8 faces" 8
        (Array.length (Fold_state.faces s));
      let m, v =
        Array.to_list (Fold_state.hinges s)
        |> List.mapi (fun i (h : Fold_state.hinge) -> (i, h))
        |> List.filter (fun (_, (h : Fold_state.hinge)) ->
               Num.sign h.Fold_state.angle <> 0)
        |> List.fold_left
             (fun (m, v) (i, _) ->
               match Fold_state.mv s i with
               | Fold_state.M -> (m + 1, v)
               | Fold_state.V -> (m, v + 1)
               | Fold_state.F -> (m, v))
             (0, 0)
      in
      Alcotest.(check int) "derived letters satisfy Maekawa (|M-V|=2)" 2
        (abs (m - v))

(* -- every state of an ambiguous fan.
   Reuses the 8-ray cross + [over_valleys] fixture above, which
   [test_over_resolves_ambiguity] already established is ambiguous without
   `over`: the fan gives all 4 distinct orders. --------------------------- *)

let test_ambiguous_returns_all () =
  let st, rays = precreased () in
  match collapse st (elems_of rays) over_valleys ~over:[] ~staying:[ in_face st 0 ] with
  | Error e -> Alcotest.fail ("expected the states, got: " ^ e)
  | Ok sts ->
      Alcotest.(check int) "the fan gives the 4 distinct orders" 4
        (List.length sts)

(* -- [eassign] parity hand-verify ([fold_with_records] convention) ------------- *)

(* A degree-4 "+" vertex at the center: horizontal (y=1/2) and vertical (x=1/2)
   lines, four 90° sectors. Kawasaki holds (90−90+90−90 = 0). *)
let precreased_plus () =
  let hline = Geom.line_through (pt (q 0) half) (pt (q 1) half) in
  let vline = Geom.line_through (pt half (q 0)) (pt half (q 1)) in
  let cidh = Fold_state.fresh_crease_id () in
  let st = Fold_state.subdivide ~crease_id:cidh (Fold_state.flat [| Sheet.square_corners Num.one |]) hline ~prov:None in
  let cidv = Fold_state.fresh_crease_id () in
  let st = Fold_state.subdivide ~crease_id:cidv st vline ~prov:None in
  (* rays CCW-ish order: right(h), up(v), left(h), down(v) *)
  let rays =
    [ (pt (q 1) half, cidh); (pt half (q 1), cidv);
      (pt (q 0) half, cidh); (pt half (q 0), cidv) ]
  in
  (st, cidh, cidv, rays)

(* [Fold_state.mv] is derived, never stored, so there is no separate
   [effective_valley] parity step to hand-verify against: on this fixture
   (no prior flip) the derived letter equals the raw declared valley/mountain
   for every ray. ADJUDICATED (Toph, 2026-07-16): a stored `eassign` with an
   extra per-ray-index parity correction (`effective_valley`) does not track
   the actual geometry: it contradicts an `intrinsic_valley` probe on this
   fixture (see [test_derived_mv_matches_declared] below, which pins the
   adjudicated finding). Worked example, assignment
   [M;V;M;M] on the "+" vertex (ray order right,up,left,down): all four rays'
   derived [mv] equal their raw declared letter: right=M, up=V, left=M,
   down=M. The horizontal crease carries two M; the vertical crease
   carries one V (up) and one M (down). *)
let test_eassign_parity () =
  let st, cidh, cidv, rays = precreased_plus () in
  match
    collapse st (elems_of rays) [| false; true; false; false |] ~over:[]
      ~staying:[ in_face st 0 ]
  with
  | Error e -> Alcotest.fail ("expected one state, got: " ^ e)
  | Ok l when List.length l <> 1 -> Alcotest.failf "expected one state, got %d" (List.length l)
  | Ok l ->
      let s = List.hd l in
      let hs = Fold_state.hinges s in
      let assigns cid =
        Array.to_list hs
        |> List.mapi (fun i (h : Fold_state.hinge) -> (i, h))
        |> List.filter (fun (_, (h : Fold_state.hinge)) -> h.Fold_state.crease_id = cid)
        |> List.map (fun (i, _) -> Fold_state.mv s i)
        |> List.sort compare
      in
      Alcotest.(check bool)
        "horizontal crease: both rays derive M (raw declared, adjudicated 2026-07-16)"
        true (assigns cidh = [ Fold_state.M; Fold_state.M ]);
      Alcotest.(check bool) "vertical crease: one V (up) + one M (down)" true
        (assigns cidv = [ Fold_state.M; Fold_state.V ]);
      let has_u =
        Array.to_list hs
        |> List.mapi (fun i _ -> i)
        |> List.exists (fun i -> Fold_state.mv s i = Fold_state.F)
      in
      Alcotest.(check bool) "no folded crease left as F" false has_u

(* Pins the 2026-07-16 adjudication directly: on the "+" vertex with no prior flip, EVERY ray
   hinge's derived [Fold_state.mv] equals the raw user-declared letter: no
   effective_valley-style parity correction applies to the derived letter
   (such a correction contradicts an [intrinsic_valley] probe on this
   fixture). This duplicates [test_eassign_parity]'s per-crease check above
   via a per-ray check, so the adjudication has a test of its own. *)
let test_derived_mv_matches_declared () =
  let st, _, _, rays = precreased_plus () in
  let valleys = [| false; true; false; false |] in
  match collapse st (elems_of rays) valleys ~over:[] ~staying:[ in_face st 0 ] with
  | Error e -> Alcotest.fail ("expected one state, got: " ^ e)
  | Ok l when List.length l <> 1 -> Alcotest.failf "expected one state, got %d" (List.length l)
  | Ok l ->
      let s = List.hd l in
      let hs = Fold_state.hinges s in
      let ray_of i =
        let a, b = Fold_state.hinge_segment s i in
        let found = ref None in
        List.iteri
          (fun j (far, cid) ->
            if
              hs.(i).Fold_state.crease_id = cid
              && Geom.on_segment (o, far) a
              && Geom.on_segment (o, far) b
            then found := Some j)
          rays;
        !found
      in
      let checked = ref 0 in
      Array.iteri
        (fun i (h : Fold_state.hinge) ->
          if Num.sign h.Fold_state.angle <> 0 then
            match ray_of i with
            | None -> Alcotest.failf "folded hinge %d matches no ray" i
            | Some j ->
                incr checked;
                let expect = if valleys.(j) then Fold_state.V else Fold_state.M in
                Alcotest.(check bool)
                  (Printf.sprintf "derived mv equals raw declared letter (ray %d)" j)
                  true (Fold_state.mv s i = expect))
        hs;
      Alcotest.(check int) "all four ray hinges checked" 4 !checked

(* -- the stayer picks the physical world -------------------------------------
   The stayer is the material that does NOT move: identity, front-up, where it
   lay. Two stayers on adjacent sectors of the same "+" vertex both solve;
   their sectors have opposite fan parity, so anchoring the identity on each
   yields through-plane mirror stacks: a shared overlapping face pair reverses
   its layer relation. This is the claim the test checks: both worlds are reachable
   and differ (design 2026-07-17). *)
let test_stayer_picks_world () =
  let st, _, _, rays = precreased_plus () in
  let es = elems_of rays and valleys = [| false; true; false; false |] in
  let three_quarters = Num.of_q (Q.of_ints 3 4) and quarter = Num.of_q (Q.of_ints 1 4) in
  let ne = [ pt three_quarters three_quarters ] (* the NE sector (even parity) *)
  and nw = [ pt quarter three_quarters ] (* the NW sector (odd parity) *) in
  match
    ( collapse st es valleys ~over:[] ~staying:ne,
      collapse st es valleys ~over:[] ~staying:nw )
  with
  | Ok (a :: _), Ok (b :: _) ->
      let nf = Array.length (Fold_state.faces a) in
      let flipped = ref false in
      for i = 0 to nf - 1 do
        for j = i + 1 to nf - 1 do
          match (Fold_state.rel a i j, Fold_state.rel b i j) with
          | Fold_state.Above, Fold_state.Below | Fold_state.Below, Fold_state.Above
            ->
              flipped := true
          | _ -> ()
        done
      done;
      Alcotest.(check bool)
        "opposite-parity stayers give mirror stacks (a face pair flips)" true
        !flipped
  | Ok [], _ | _, Ok [] -> Alcotest.fail "a stayer world came out empty"
  | Error e, _ -> Alcotest.fail ("the NE stayer must solve: " ^ e)
  | _, Error e -> Alcotest.fail ("the NW stayer must solve: " ^ e)

(* -- duplicate ray (zero-width sector) ------------------------------------ *)

(* Two elements pointing the SAME direction from O fold a zero-width sector; the
   doubled reflection cancels in the closure product, so Kawasaki/Maekawa/count
   all pass on a self-contradictory vertex. The guard must reject it. Opposite
   collinear rays (waterbomb, above) stay legal: proven green by
   [test_waterbomb_assignment], whose 8 rays include four opposite-collinear
   pairs. *)
let test_duplicate_ray_rejected () =
  let st, cidh, cidv, _ = precreased_plus () in
  (* the rightward h-ray listed twice + the two v-rays: n = 4, even, and each
     line's reflection would otherwise close: only the repeat is wrong. *)
  let es =
    [
      { Collapse.cid = cidh; ea = o; eb = pt (q 1) half };
      { Collapse.cid = cidh; ea = o; eb = pt (q 1) half };
      { Collapse.cid = cidv; ea = o; eb = pt half (q 1) };
      { Collapse.cid = cidv; ea = o; eb = pt half (q 0) };
    ]
  in
  match
    collapse st es [| true; false; true; false |] ~over:[] ~staying:[ in_face st 0 ]
  with
  | Ok _ -> Alcotest.fail "duplicate ray must be rejected"
  | Error e ->
      Alcotest.(check bool)
        ("duplicate-ray error: " ^ e) true
        (prefix "duplicate ray in collapse" e)

(* -- orientation-preserving normalization --------------------------------- *)

(* Intrinsic (geometry-only) M/V of a crease: the crease is a valley iff the
   UPPER of its two incident faces is front-down (not [face_up]): no
   reference to the derived [mv] on the crease itself. [test_intrinsic_convention_pin]
   below proves this is the emitter's convention on a trivial simple fold. *)
let intrinsic_valley (s : Fold_state.t) (fl : int) (fj : int) : bool =
  let upper = if Fold_state.rel s fj fl = Fold_state.Above then fj else fl in
  not (Fold_state.face_up s upper)

(* Pin the convention on a trivial fold of the square along y = 1/2 (top half
   moves): valley lands the moved flap on TOP front-down (upper not [face_up],
   letter V); mountain tucks it BELOW, upper face stays front-up ([face_up],
   letter M). This grounds [intrinsic_valley] against the emitter itself. *)
let test_intrinsic_convention_pin () =
  let axis = { Geom.a = Num.zero; b = Num.one; c = half } in
  List.iter
    (fun valley ->
      let s =
        Axis_fan.fold (Fold_state.flat [| Sheet.square_corners Num.one |]) ~axis ~move_side:1
          ~valley ~prov:None
      in
      let hs = Fold_state.hinges s in
      let letter =
        Array.to_list hs
        |> List.mapi (fun i _ -> i)
        |> List.filter_map (fun i ->
               match Fold_state.mv s i with
               | Fold_state.V -> Some true
               | Fold_state.M -> Some false
               | Fold_state.F -> None)
      in
      Alcotest.(check bool)
        (Printf.sprintf "trivial %s: derived letter matches"
           (if valley then "valley" else "mountain"))
        true
        (letter = [ valley ]);
      Alcotest.(check bool)
        (Printf.sprintf "trivial %s: intrinsic (upper face_up) matches"
           (if valley then "valley" else "mountain"))
        valley (intrinsic_valley s 0 1))
    [ true; false ]

(* A 3-valley / 5-mountain waterbomb variant whose solved stack seats an
   ORIENTATION-REVERSING sector at the bottom (verified: bottom-by-rank sector
   is not [face_up]). Anchoring [tb_inv] there would mirror every face's
   front/back while the letters, derived in the fixed global frame, stay
   put, so the emitted geometry would be the M/V mirror of the declared
   collapse. With the anchor on the lowest-ranked orientation-PRESERVING
   sector the geometry realizes the declared fold: every crease's intrinsic
   M/V equals what was declared. Checked via face orientation and layer
   relation alone. Anchoring on the bottom sector fails this check on all 8
   creases. *)
let c2_valleys = [| true; true; true; false; false; false; false; false |]

let test_c2_declared_mountain_intrinsic () =
  let st, rays = precreased () in
  let es = elems_of rays in
  match collapse st es c2_valleys ~over:[] ~staying:[ in_face st 0 ] with
  | Error e -> Alcotest.fail ("expected one state, got: " ^ e)
  | Ok l when List.length l <> 1 -> Alcotest.failf "expected one state, got %d" (List.length l)
  | Ok l ->
      let s = List.hd l in
      (* recover face→sector from the ORIGINAL flat faces (collapse preserves
         face index order), then pair each ray's two bounding sectors. *)
      let sorted = Array.of_list (Collapse.sort_ccw o es) in
      let n = Array.length sorted in
      let faces = Fold_state.faces st in
      let sec =
        Array.init (Array.length faces) (fun i ->
            Collapse.sector_of_poly_opt o sorted (faces.(i), Fold_state.face_iso2 st i))
      in
      let face_in sector =
        let r = ref (-1) in
        Array.iteri (fun i sc -> if sc = sector then r := i) sec;
        !r
      in
      for j = 0 to n - 1 do
        let l = (j - 1 + n) mod n in
        let far, _ = sorted.(j) in
        let declared =
          c2_valleys.(Option.get
                        (List.find_index (fun (f, _) -> Geom.point_equal f far) rays))
        in
        Alcotest.(check bool)
          (Printf.sprintf "ray %d declared=%s comes out intrinsically the same"
             j (if declared then "V" else "M"))
          declared
          (intrinsic_valley s (face_in l) (face_in j))
      done

(* -- flip-awareness (parity relative to the original front) --------------- *)

let collapse_letters valleys ~flip =
  let st, _, _, rays = precreased_plus () in
  let st = if flip then Fold_state.flip st else st in
  match collapse st (elems_of rays) valleys ~over:[] ~staying:[ in_face st 0 ] with
  | Error e -> Alcotest.fail ("expected one state, got: " ^ e)
  | Ok l when List.length l <> 1 -> Alcotest.failf "expected one state, got %d" (List.length l)
  | Ok l ->
      let s = List.hd l in
      let hs = Fold_state.hinges s in
      Array.to_list hs
      |> List.mapi (fun i _ -> i)
      |> List.filter_map (fun i ->
             match Fold_state.mv s i with
             | Fold_state.V -> Some true
             | Fold_state.M -> Some false
             | Fold_state.F -> None)

(* Spec §4.7 ("mountain = turn over, then valley") suggests a prior [flip]
   inverts every collapse crease's letter, because the STORED
   [eassign] is [ray_assign]: user valley XOR'd with the pre-collapse sector's
   placement parity ([effective_valley]), and flip toggles that parity for
   every sector uniformly. ADJUDICATED (Toph, 2026-07-16): the kernel's
   [intent] (CP-frame, = eintent/eassign, see [test_eassign_parity] above)
   DOES flip this way, but the DERIVED [Fold_state.mv] does not: [mv] reads only the
   constructed hinge's rank + [face_up], an invariant of the realized
   physical fold: the same "per-ray parity term belongs to [intent], not
   to the physically-derived letter" finding as [test_eassign_parity], just
   exercised through a prior [flip] instead of a prior [subdivide]. (Compare
   test_fold_graph.ml's [test_flip_parity]: a hinge carried through a LATER
   flip keeps its [mv] too: same stability, different construction path.) *)
let test_flip_leaves_derived_assignment_unchanged () =
  let vs = [| false; true; false; false |] in
  let plain = collapse_letters vs ~flip:false in
  let flipped = collapse_letters vs ~flip:true in
  Alcotest.(check bool)
    "flip does not change the derived collapse assignment (adjudicated 2026-07-16)"
    true (plain = flipped)

(* -- a fan of several vertices whose layers lie in a cycle ----------------- *)

(* a point given in sixteenths of the sheet's side *)
let tw x y = pt (Num.of_q (Q.of_ints x 16)) (Num.of_q (Q.of_ints y 16))

(* The square twist [hull2020, §6.5, Fig. 6.12] from the flat sheet. Face 0
   is the central square, faces 1 to 4 the pleats on its sides, faces 5 to 8
   the corner faces between two pleats. Hinges 0 to 3 are the sides of the
   square, hinges 4 to 7 the crease of each pleat that leaves the square
   clockwise, hinges 8 to 11 the other one. The square stays, every hinge
   folds, and each hinge is its own element. With the sides and hinges 8 to
   11 as valleys and hinges 4 to 7 as mountains the fan folds flat in one
   state, and its four corner faces lie in a cycle. *)
let test_square_twist () =
  let faces =
    [| [| tw 6 6; tw 10 6; tw 10 10; tw 6 10 |];
       [| tw 10 6; tw 6 6; tw 0 3; tw 0 1 |];
       [| tw 10 10; tw 10 6; tw 13 0; tw 15 0 |];
       [| tw 6 10; tw 10 10; tw 16 13; tw 16 15 |];
       [| tw 6 6; tw 6 10; tw 3 16; tw 1 16 |];
       [| tw 10 6; tw 0 1; tw 0 0; tw 13 0 |];
       [| tw 10 10; tw 15 0; tw 16 0; tw 16 13 |];
       [| tw 6 10; tw 16 15; tw 16 16; tw 3 16 |];
       [| tw 6 6; tw 1 16; tw 0 16; tw 0 3 |] |]
  in
  let h cid fa fb p r =
    { Fold_state.fa; fb; line = Geom.line_through p r; angle = Num.zero;
      crease_id = cid; prov = None }
  in
  let hinges =
    [| h 0 0 1 (tw 6 6) (tw 10 6);
       h 1 0 2 (tw 10 6) (tw 10 10);
       h 2 0 3 (tw 10 10) (tw 6 10);
       h 3 0 4 (tw 6 10) (tw 6 6);
       h 4 1 5 (tw 10 6) (tw 0 1);
       h 5 2 6 (tw 10 10) (tw 15 0);
       h 6 3 7 (tw 6 10) (tw 16 15);
       h 7 4 8 (tw 6 6) (tw 1 16);
       h 8 5 2 (tw 10 6) (tw 13 0);
       h 9 6 3 (tw 10 10) (tw 16 13);
       h 10 7 4 (tw 6 10) (tw 3 16);
       h 11 8 1 (tw 6 6) (tw 0 3) |]
  in
  let g = Fold_state.flat ~hinges faces in
  let nf = Array.length faces in
  let sgs =
    Fan.make g ~root:0
      ~tip:(Array.init nf (fun i -> i > 0))
      ~names:(Array.init 12 Option.some)
      ~role:(Array.make 12 Fan.Fold) ~nelem:12
      ~side:(fun _ a b -> Some (a, b))
  in
  let valley = Array.init 12 (fun k -> k < 4 || k >= 8) in
  match sgs with
  | None -> Alcotest.fail "the twist does not close"
  | Some [ sg ] -> (
      match Collapse.pipeline_solve sg ~valley ~over:[] with
      | Error e -> Alcotest.failf "the twist does not fold flat: %s" e
      | Ok states ->
          Alcotest.(check int) "one state" 1 (List.length states);
          let st = List.hd states in
          List.iter
            (fun (i, j) ->
              Alcotest.(check bool)
                (Printf.sprintf "corner face %d lies above corner face %d" i j)
                true (Fold_state.above st i j))
            [ (6, 5); (7, 6); (8, 7); (5, 8) ];
          Array.iteri
            (fun k v ->
              Alcotest.(check bool)
                (Printf.sprintf "hinge %d has its letter" k)
                true
                (Fold_state.mv st k = if v then Fold_state.V else Fold_state.M))
            valley)
  | Some l -> Alcotest.failf "%d ways to fold, expected one" (List.length l)

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
          Alcotest.test_case "duplicate ray rejected" `Quick
            test_duplicate_ray_rejected;
        ] );
      ( "normalization",
        [
          Alcotest.test_case "intrinsic M/V convention pin (trivial fold)"
            `Quick test_intrinsic_convention_pin;
          Alcotest.test_case "declared M/V survives improper bottom sector"
            `Quick test_c2_declared_mountain_intrinsic;
        ] );
      ( "flip",
        [
          Alcotest.test_case
            "flip leaves the derived collapse assignment unchanged (adjudicated)"
            `Quick test_flip_leaves_derived_assignment_unchanged;
        ] );
      ( "waterbomb",
        [
          Alcotest.test_case "empirical MV assignment is realizable" `Quick
            test_waterbomb_assignment;
          Alcotest.test_case "over resolves ambiguity" `Quick
            test_over_resolves_ambiguity;
        ] );
      ( "states",
        [
          Alcotest.test_case "ambiguous case returns all 4 distinct orders"
            `Quick test_ambiguous_returns_all;
          Alcotest.test_case "stayer picks the physical world (mirror stacks)"
            `Quick test_stayer_picks_world;
        ] );
      ( "eassign",
        [
          Alcotest.test_case "parity flip on a worked +-vertex" `Quick
            test_eassign_parity;
          Alcotest.test_case "derived mv matches declared (no prior flip)"
            `Quick test_derived_mv_matches_declared;
        ] );
      ( "cycle",
        [ Alcotest.test_case "the square twist folds from the flat sheet" `Quick
            test_square_twist ] );
    ]
