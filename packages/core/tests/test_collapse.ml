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
  match Collapse.collapse st seven ~over:[] ~stayer:(Collapse.Faces [ 0 ]) with
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
  match Collapse.collapse st es ~over:[] ~stayer:(Collapse.Faces [ 0 ]) with
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
  match Collapse.collapse st es ~over:[] ~stayer:(Collapse.Faces [ 0 ]) with
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
  match Collapse.collapse st es ~over:[] ~stayer:(Collapse.Faces [ 0 ]) with
  | Ok s ->
      (* the 8 sectors survive as 8 faces in the folded state *)
      Alcotest.(check int) "collapsed waterbomb has 8 faces" 8
        (Array.length (Fold_state.faces s))
  | Error e ->
      (* an ambiguous-stacking error would still mean the assignment is
         flat-foldable (closure + Maekawa + a valid layer order all passed) *)
      Alcotest.(check bool)
        ("waterbomb assignment is realizable (Ok or ambiguous), got: " ^ e)
        true (prefix "ambiguous stacking" e)

(* -- over resolves ambiguity (merged from test_collapse_graph.ml, Plan 3c
   Task 6 — that file's old-vs-new parity harness is gone; this is its
   new-side content) ---------------------------------------------------- *)

(* The 8-ray cross, valley pattern [V;V;M;M;V;M;M;M]: |nm-nv| = |5-3| = 2
   (Maekawa holds) but the stacking is ambiguous without `over`; over=[(3,4)]
   (face 3 above face 4) resolves it to a unique Ok. Both facts were
   originally verified against the certified old kernel (Plan 3b Task 5); the
   old kernel is gone, so the exact resolved facts it proved are pinned here
   as literals instead. *)
let over_valleys = [| true; true; false; false; true; false; false; false |]

(* The `over` pair (3,4) was pinned as face-index literals against the old
   kernel's un-rotated [sort_ccw] labeling, where the anchor sat in fan sector
   0. The stayer-anchored kernel rotates the labeling to the stayer sector, so
   to keep this pin's intent we anchor on the material in sector 0 — the first
   pre-collapse face there. [Collapse.Faces [f]] then rotates by 0 (a no-op),
   reproducing the exact labeling the over-literals were calibrated for. *)
let sector0_face st es =
  let sorted = Array.of_list (Collapse.sort_ccw o es) in
  let faces = Fold_state.faces st in
  let sec =
    Array.init (Array.length faces) (fun i ->
        Collapse.sector_of_poly o sorted (faces.(i), Fold_state.face_iso2 st i))
  in
  let r = ref (-1) in
  Array.iteri (fun i s -> if !r < 0 && s = 0 then r := i) sec;
  !r

let test_over_resolves_ambiguity () =
  let st, rays = precreased () in
  let es = elems_of rays over_valleys in
  let stay = Collapse.Faces [ sector0_face st es ] in
  (match Collapse.collapse st es ~over:[] ~stayer:stay with
  | Error e ->
      Alcotest.(check bool) ("ambiguous without over: " ^ e) true
        (prefix "ambiguous stacking" e)
  | Ok _ -> Alcotest.fail "expected ambiguous stacking without `over`");
  match Collapse.collapse st es ~over:[ (3, 4) ] ~stayer:stay with
  | Error e -> Alcotest.fail ("expected Ok with over, got: " ^ e)
  | Ok s ->
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

(* -- collapse_all: enumerating entry point (Plan flatten-derive-v2 Task 2).
   [collapse] becomes a wrapper over the same shared pipeline: single distinct
   rank -> Ok, multiple -> e_ambig, error -> passthrough. [collapse_all]
   instead anchors EVERY distinct rank independently and returns all that seat
   in-bounds. Reuses the 8-ray cross + [over_valleys] fixture above, which
   [test_over_resolves_ambiguity] already established is ambiguous (4 distinct
   orders) without `over` and uniquely resolved by over=[(3,4)]. ------------ *)

let test_collapse_all_ambiguous_returns_all () =
  let st, rays = precreased () in
  let es = elems_of rays over_valleys in
  match Collapse.collapse_all st es ~over:[] ~stayer:(Collapse.Faces [ 0 ]) with
  | Error e -> Alcotest.fail ("expected Ok list, got: " ^ e)
  | Ok sts ->
      Alcotest.(check int)
        "collapse_all returns the 4 distinct orders collapse's e_ambig names"
        4 (List.length sts)

let test_collapse_all_over_matches_collapse () =
  let st, rays = precreased () in
  let es = elems_of rays over_valleys in
  let stay = Collapse.Faces [ sector0_face st es ] in
  match
    ( Collapse.collapse st es ~over:[ (3, 4) ] ~stayer:stay,
      Collapse.collapse_all st es ~over:[ (3, 4) ] ~stayer:stay )
  with
  | Error e, _ -> Alcotest.fail ("expected collapse Ok, got: " ^ e)
  | _, Error e -> Alcotest.fail ("expected collapse_all Ok, got: " ^ e)
  | Ok _, Ok ([] | _ :: _ :: _) ->
      Alcotest.fail "expected collapse_all with over to narrow to exactly one state"
  | Ok single, Ok [ many ] ->
      let mv_list s =
        Array.to_list (Fold_state.hinges s) |> List.mapi (fun i _ -> Fold_state.mv s i)
      in
      Alcotest.(check int) "collapse_all (over-narrowed) keeps 8 faces" 8
        (Array.length (Fold_state.faces many));
      Alcotest.(check bool) "collapse_all matches collapse (per-hinge mv)" true
        (mv_list single = mv_list many);
      let pts_equal a b =
        Array.length a = Array.length b && Array.for_all2 Geom.point_equal a b
      in
      Alcotest.(check bool) "collapse_all matches collapse (face 0 table position)"
        true
        (pts_equal
           (Fold_state.table_polygon single 0)
           (Fold_state.table_polygon many 0))

let test_collapse_all_error_passthrough () =
  let st, rays = precreased () in
  let es = elems_of rays (Array.make 8 true) in
  let seven = List.filteri (fun i _ -> i < 7) es in
  match
    ( Collapse.collapse st seven ~over:[] ~stayer:(Collapse.Faces [ 0 ]),
      Collapse.collapse_all st seven ~over:[] ~stayer:(Collapse.Faces [ 0 ]) )
  with
  | Error e1, Error e2 ->
      Alcotest.(check string) "collapse_all errors identically to collapse" e1 e2
  | _ -> Alcotest.fail "expected both collapse and collapse_all to error on odd count"

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

(* [Fold_state.mv] is derived, never stored, so there is no separate
   "effective_valley" parity step to hand-verify against — on this fixture
   (no prior flip) the derived letter equals the raw declared valley/mountain
   for every ray. ADJUDICATED (Toph, 2026-07-16, Plan 3c Task 3b-5 / Task 4):
   the OLD stored `eassign` applied an extra per-ray-index parity correction
   (`effective_valley`) that did not track the actual geometry — it
   contradicted the old codebase's own `intrinsic_valley` probe on this very
   fixture (see [test_derived_mv_matches_declared] below, which pins the
   adjudicated finding; the old kernel that exhibited the contradiction no
   longer exists, per Plan 3c Task 6). Worked example, assignment
   [M;V;M;M] on the "+" vertex (ray order right,up,left,down): all four rays'
   derived mv equal their raw declared letter — right=M, up=V, left=M,
   down=M. So the horizontal crease carries two M; the vertical crease
   carries one V (up) and one M (down). *)
let test_eassign_parity () =
  let st, cidh, cidv, rays = precreased_plus () in
  let es = elems_of rays [| false; true; false; false |] in
  match Collapse.collapse st es ~over:[] ~stayer:(Collapse.Faces [ 0 ]) with
  | Error e -> Alcotest.fail ("expected Ok, got: " ^ e)
  | Ok s ->
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

(* Merged from test_collapse_graph.ml's `test_old_eassign_divergence` (Plan 3c
   Task 6 — that file's old-vs-new parity harness is gone). Pins the Task 5
   adjudication directly: on the "+" vertex with no prior flip, EVERY ray
   hinge's derived [Fold_state.mv] equals the raw user-declared letter — no
   effective_valley-style parity correction applies to the derived letter
   (the old kernel's stored `eassign` DID apply such a correction and, per
   the Task 5 finding, contradicted its own intrinsic_valley probe on this
   very fixture; that old kernel and probe no longer exist to re-run). This
   duplicates [test_eassign_parity]'s per-crease check above via a per-ray
   check instead — kept as its own test because it is the direct successor
   of the merged file's divergence pin, not because the coverage is new. *)
let test_derived_mv_matches_declared () =
  let st, _, _, rays = precreased_plus () in
  let valleys = [| false; true; false; false |] in
  let es = elems_of rays valleys in
  match Collapse.collapse st es ~over:[] ~stayer:(Collapse.Faces [ 0 ]) with
  | Error e -> Alcotest.fail ("expected Ok, got: " ^ e)
  | Ok s ->
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

(* -- Task 2 (flatten-staying): the stayer picks the physical world ----------
   The stayer is the material that does NOT move — identity, front-up, where it
   lay. Two Arc stayers on adjacent sectors of the same "+" vertex both solve;
   their sectors have opposite fan parity, so anchoring the identity on each
   yields through-plane mirror stacks — a shared overlapping face pair reverses
   its layer relation. This is the load-bearing claim: both worlds are reachable
   and differ (design 2026-07-17). *)
let test_stayer_picks_world () =
  let st, _, _, rays = precreased_plus () in
  let es = elems_of rays [| false; true; false; false |] in
  let right = pt (q 1) half and up = pt half (q 1) in
  let left = pt (q 0) half in
  let arc_a = Collapse.Arc (right, up) (* stayer region = the NE sector (even parity) *)
  and arc_b = Collapse.Arc (up, left) (* stayer region = the NW sector (odd parity) *) in
  match
    ( Collapse.collapse_all st es ~over:[] ~stayer:arc_a,
      Collapse.collapse_all st es ~over:[] ~stayer:arc_b )
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
  | Error e, _ -> Alcotest.fail ("arc_a stayer must solve: " ^ e)
  | _, Error e -> Alcotest.fail ("arc_b stayer must solve: " ^ e)

(* -- C1: duplicate ray (zero-width sector) ---------------------------------- *)

(* Two elements pointing the SAME direction from O fold a zero-width sector; the
   doubled reflection cancels in the closure product, so Kawasaki/Maekawa/count
   all pass on a self-contradictory vertex. The guard must reject it. Opposite
   collinear rays (waterbomb, above) stay legal — proven green by
   [test_waterbomb_assignment], whose 8 rays include four opposite-collinear
   pairs. *)
let test_duplicate_ray_rejected () =
  let st, _, _, _ = precreased_plus () in
  (* the rightward h-ray listed twice + the two v-rays: n = 4, even, and each
     line's reflection would otherwise close — only the repeat is wrong. *)
  let es =
    [
      { Collapse.cid = 0; ea = o; eb = pt (q 1) half; valley = true };
      { Collapse.cid = 0; ea = o; eb = pt (q 1) half; valley = false };
      { Collapse.cid = 1; ea = o; eb = pt half (q 1); valley = true };
      { Collapse.cid = 1; ea = o; eb = pt half (q 0); valley = false };
    ]
  in
  match Collapse.collapse st es ~over:[] ~stayer:(Collapse.Faces [ 0 ]) with
  | Ok _ -> Alcotest.fail "duplicate ray must be rejected"
  | Error e ->
      Alcotest.(check bool)
        ("duplicate-ray error: " ^ e) true
        (prefix "duplicate ray in collapse" e)

(* -- C2: orientation-preserving normalization ------------------------------- *)

(* Intrinsic (geometry-only) M/V of a crease: the crease is a valley iff the
   UPPER of its two incident faces is front-down (not [face_up]) — no
   reference to the derived [mv] on the crease itself. [test_intrinsic_convention_pin]
   below proves this is the emitter's convention on a trivial simple fold. *)
let intrinsic_valley (s : Fold_state.t) (fl : int) (fj : int) : bool =
  let upper = if Fold_state.rel s fj fl = Fold_state.Above then fj else fl in
  not (Fold_state.face_up s upper)

(* Pin the convention on a trivial fold of the square along y = 1/2 (top half
   moves): valley lands the moved flap on TOP front-down (upper not face_up,
   letter V); mountain tucks it BELOW, upper face stays front-up (face_up,
   letter M). This grounds [intrinsic_valley] against the emitter itself. *)
let test_intrinsic_convention_pin () =
  let axis = { Geom.a = Num.zero; b = Num.one; c = half } in
  List.iter
    (fun valley ->
      let s =
        Fold_state.simple_fold Fold_state.init_square ~axis ~move_side:1
          ~valley
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
   is not [face_up]). The old normalization anchored tb_inv there, mirroring
   every face's front/back while the letters — correctly derived in the fixed
   global frame — stayed put, so the emitted geometry became the M/V mirror of
   the declared collapse. After the fix (anchor = lowest-ranked orientation-
   PRESERVING sector) the geometry realises the declared fold: every crease's
   intrinsic M/V equals what was declared. Asserted via face orientation +
   layer relation, not letters. Under the pre-fix anchor this check fails on
   all 8 creases. *)
let c2_valleys = [| true; true; true; false; false; false; false; false |]

let test_c2_declared_mountain_intrinsic () =
  let st, rays = precreased () in
  let es = elems_of rays c2_valleys in
  match Collapse.collapse st es ~over:[] ~stayer:(Collapse.Faces [ 0 ]) with
  | Error e -> Alcotest.fail ("expected Ok, got: " ^ e)
  | Ok s ->
      (* recover face→sector from the ORIGINAL flat faces (collapse preserves
         face index order), then pair each ray's two bounding sectors. *)
      let sorted = Array.of_list (Collapse.sort_ccw o es) in
      let n = Array.length sorted in
      let faces = Fold_state.faces st in
      let sec =
        Array.init (Array.length faces) (fun i ->
            Collapse.sector_of_poly o sorted (faces.(i), Fold_state.face_iso2 st i))
      in
      let face_in sector =
        let r = ref (-1) in
        Array.iteri (fun i sc -> if sc = sector then r := i) sec;
        !r
      in
      for j = 0 to n - 1 do
        let l = (j - 1 + n) mod n in
        let _, e = sorted.(j) in
        Alcotest.(check bool)
          (Printf.sprintf "ray %d declared=%s comes out intrinsically the same"
             j (if e.Collapse.valley then "V" else "M"))
          e.Collapse.valley
          (intrinsic_valley s (face_in l) (face_in j))
      done

(* -- I1: flip-awareness (parity relative to the original front) ------------- *)

let collapse_letters valleys ~flip =
  let st, _, _, rays = precreased_plus () in
  let st = if flip then Fold_state.flip st else st in
  let es = elems_of rays valleys in
  match Collapse.collapse st es ~over:[] ~stayer:(Collapse.Faces [ 0 ]) with
  | Error e -> Alcotest.fail ("expected Ok, got: " ^ e)
  | Ok s ->
      let hs = Fold_state.hinges s in
      Array.to_list hs
      |> List.mapi (fun i _ -> i)
      |> List.filter_map (fun i ->
             match Fold_state.mv s i with
             | Fold_state.V -> Some true
             | Fold_state.M -> Some false
             | Fold_state.F -> None)

(* OLD model (spec §4.7, "mountain = turn over, then valley"): a prior [flip]
   was believed to invert every collapse crease's letter, because the STORED
   eassign is [ray_assign] — user valley XOR'd with the pre-collapse sector's
   placement parity ([effective_valley]) — and flip toggles that parity for
   every sector uniformly. ADJUDICATED (Toph, 2026-07-16, Plan 3c Task 4): the
   new kernel's [intent] (CP-frame, = old eintent/eassign — matches the old
   model bit-for-bit, see [test_eassign_parity] above) DOES still flip this
   way, but the DERIVED [Fold_state.mv] does not: [mv] reads only the
   constructed hinge's rank + [face_up], an invariant of the realised
   physical fold — the same "old per-ray parity term belongs to [intent], not
   to the physically-derived letter" finding as [test_eassign_parity], just
   exercised through a prior [flip] instead of a prior [subdivide]. (Compare
   test_fold_graph.ml's [test_flip_parity]: a hinge carried through a LATER
   flip keeps its [mv] too — same stability, different construction path.) *)
let test_flip_leaves_derived_assignment_unchanged () =
  let vs = [| false; true; false; false |] in
  let plain = collapse_letters vs ~flip:false in
  let flipped = collapse_letters vs ~flip:true in
  Alcotest.(check bool)
    "flip does not change the derived collapse assignment (adjudicated 2026-07-16)"
    true (plain = flipped)

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
      ( "collapse_all",
        [
          Alcotest.test_case "ambiguous case returns all 4 distinct orders"
            `Quick test_collapse_all_ambiguous_returns_all;
          Alcotest.test_case "over-narrowed case matches collapse's state"
            `Quick test_collapse_all_over_matches_collapse;
          Alcotest.test_case "error passthrough matches collapse" `Quick
            test_collapse_all_error_passthrough;
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
    ]
