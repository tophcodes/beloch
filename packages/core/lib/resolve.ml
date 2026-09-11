(** Name resolution, the selector engine, flap resolution and mark resolution.
    Every stateful function takes [(ctx : Ctx.ctx)] as its first parameter. *)

open Ctx

(* render an operand back to source text for provenance + error messages *)
let rec pstr (po : Ast.point_operand) : string =
  match po with
  | Ast.PNamed pr -> "." ^ pr.Ast.name
  | Ast.PSelect (los, _) ->
      Printf.sprintf ".[%s]" (String.concat " " (List.map lstr los))
and lstr (lo : Ast.line_operand) : string =
  match lo with
  | Ast.LNamed cr -> "--" ^ cr.Ast.cname
  | Ast.LFilter (b, Ast.Keep s, _) -> Printf.sprintf "%s & %s" (lstr b) (selstr [ s ])
  | Ast.LFilter (b, Ast.Drop s, _) -> Printf.sprintf "%s \\ %s" (lstr b) (selstr [ s ])
  | Ast.LUnion (bs, _) -> Printf.sprintf "[%s]" (String.concat " " (List.map lstr bs))
  | Ast.LSelect (sels, _) ->
      Printf.sprintf "--[%s]"
        (String.concat " " (List.map (fun s -> selstr [ s ]) sels))
and selstr (sels : Ast.selector list) : string =
  let one = function
    | Ast.SelPoint po -> pstr po
    | Ast.SelLine lo -> lstr lo
    | Ast.SelFlap (Ast.FByPoints (pts, _)) ->
        Printf.sprintf "#[%s]" (String.concat " " (List.map pstr pts))
  in
  match sels with
  | [ s ] -> one s
  | ss -> Printf.sprintf "(%s)" (String.concat " and " (List.map one ss))
and fstr (fa : Ast.flap_arg) : string =
  match fa with
  | Ast.FlapPoint po -> pstr po
  | Ast.FlapLine lo -> lstr lo
  | Ast.FlapSpec (Ast.FByPoints (pts, _)) ->
      Printf.sprintf "#[%s]" (String.concat " " (List.map pstr pts))

let corner_point (n : string) : Geom.point =
  match List.assoc_opt n corners with
  | Some p -> p
  | None -> assert false (* Edge is only ever built from a,b,c,d *)

let materialize_crease (ctx : Ctx.ctx) ~(name : string) (span : Error.span) (cv : crease_val) :
    Geom.line =
  match cv with
  | Bundle _ ->
      Error.fail span
        (Printf.sprintf
           "--%s is a bundle; restrict it to one segment with & or \\" name)
  | Edge (a, b) ->
      let pa = Fold_state.table_position !(ctx.state) (corner_point a)
      and pb = Fold_state.table_position !(ctx.state) (corner_point b) in
      Geom.line_through pa pb
  | Frozen l -> l
  | Mark (cid, line) -> (
      match Fold_state.mark_axis_current !(ctx.state) cid with
      | `Line l -> l
      | `Empty -> line
      | `Collapsed ->
          Error.fail span
            (Printf.sprintf
               "--%s has collapsed to a point under folding, so it no longer \
                names a line" name)
      | `Bent ->
          Error.fail span
            (Printf.sprintf
               "--%s is bent by a fold; select a segment with `at`, e.g. \
                --%s at #[.a .b .c]" name name))
  | Material (cid, l_orig) -> (
      match Fold_state.crease_axis !(ctx.state) cid l_orig with
      | `Line l -> l
      (* a crease that cut no face (e.g. lies on the paper boundary) has no
         material pieces but is still flat at its original line — byte-stable
         and lets reference-only boundary creases resolve *)
      | `Empty -> l_orig
      | `Collapsed ->
          Error.fail span
            (Printf.sprintf
               "--%s has collapsed to a point under folding, so it no longer \
                names a line" name)
      | `Bent ->
          Error.fail span
            (Printf.sprintf
               "--%s is no longer straight after folding; select a segment \
                with `at`, e.g. --%s at #[.a .b .c] or --%s at .p"
               name name name))

(* a cross operand resolved to PAPER space: the one material line carrying
   the crease's marks, plus those marks' paper chords (None when the operand
   is a constructed line / boundary reference with no marks) *)
let paper_line_of_crease (ctx : Ctx.ctx) ~(name : string) (span : Error.span) (cv : crease_val)
    : Geom.line * (Geom.point * Geom.point) list option =
  match cv with
  | Bundle _ ->
      Error.fail span
        (Printf.sprintf
           "--%s is a bundle; restrict it to one segment with & or \\" name)
  | Frozen _ ->
      Error.fail span
        (Printf.sprintf
           "--%s is not a physical crease, so it has no material mark to \
            cross" name)
  | Mark (cid, line) ->
      (* meet is a paper-space construction; a mark is always straight in the
         material frame (folding only bends it in table space), so use its
         paper chord line + chords directly *)
      let chords = Fold_state.mark_chords !(ctx.state) cid in
      let paper_line =
        match chords with (a, b) :: _ -> Geom.line_through a b | [] -> line
      in
      (paper_line, Some chords)
  | Edge (a, b) ->
      (Geom.line_through (corner_point a) (corner_point b), None)
  | Material (cid, l_orig) -> (
      match Fold_state.crease_paper_axis !(ctx.state) cid with
      | `Line l ->
          let chords =
            List.map
              (fun (s : Fold_state.crease_segment) ->
                (s.Fold_state.pa, s.Fold_state.pb))
              (Fold_state.crease_segments !(ctx.state) cid)
          in
          (l, Some chords)
      (* a crease that cut no face (e.g. lies on the paper boundary) has no
         material marks; fall back to its birth line, as materialize_crease
         does for reference-only boundary creases *)
      | `Empty -> (l_orig, None)
      | `Bent ->
          Error.fail span
            (Printf.sprintf
               "--%s marks different lines on different layers; select a \
                segment with `at`, e.g. --%s at #[.a .b .c]"
               name name))

(* the unique FACE (the fine ADR-0014 partition, not a flap/coplanar
   cluster) whose paper polygon contains every point in [pts]. Unlike
   `moving`/`up to`'s flap operand (ADR 0017: coarsened to a coplanar
   cluster so a still-flat neighbourhood is one flap), `at`'s `#[...]`
   incidence check and `collapse`'s `over`/`under` sector clause both need
   FACE precision even on a still-flat, multiply-precreased sheet: they
   disambiguate BETWEEN a crease bundle's own segments / a vertex's own
   sectors, which are still distinct faces while every one of them is the
   SAME flap (nothing has folded yet). Coarsening these to "the whole flap"
   would make every segment/sector match at once. *)
let face_of_points (ctx : Ctx.ctx) (pts : Geom.point list) :
    [ `Face of int | `Zero | `Ambiguous ] =
  let st = !(ctx.state) in
  let faces_arr = Fold_state.faces st in
  let contains i =
    List.for_all (fun p -> Geom.in_convex_polygon faces_arr.(i) p) pts
  in
  let hits = ref [] in
  Array.iteri (fun i _ -> if contains i then hits := i :: !hits) faces_arr;
  match !hits with [ i ] -> `Face i | [] -> `Zero | _ -> `Ambiguous

(* resolve a point operand to its material PAPER coordinate, a line operand to
   its TABLE-space line (fold axes align current table positions). `cross` is
   the exception: it is a material construction, so its operands resolve to
   PAPER-space lines via resolve_paper_line — folding never moves a mark
   within the sheet, so the crossing is fold-state-independent. *)
let rec resolve_point (ctx : Ctx.ctx) (po : Ast.point_operand) : Geom.point =
  match po with
  | Ast.PNamed pr -> lookup_point ctx pr
  | Ast.PSelect (los, span) -> select_point ctx los span
and resolve_line (ctx : Ctx.ctx) (lo : Ast.line_operand) : Geom.line =
  match lo with
  | Ast.LNamed cr -> (
      match lookup_crease ctx cr with
      | Bundle expr -> resolve_line ctx expr
      | cv -> materialize_crease ctx ~name:cr.Ast.cname cr.Ast.cspan cv)
  | (Ast.LFilter _ | Ast.LUnion _) as b ->
      let s = coerce_one_segment ctx b in
      Geom.line_through s.Fold_state.ta s.Fold_state.tb
  | Ast.LSelect (sels, span) -> select_line ctx sels span
and resolve_paper_line (ctx : Ctx.ctx) (lo : Ast.line_operand) :
    Geom.line * (Geom.point * Geom.point) list option =
  match lo with
  | Ast.LNamed cr -> (
      match lookup_crease ctx cr with
      | Bundle expr -> resolve_paper_line ctx expr
      | cv -> paper_line_of_crease ctx ~name:cr.Ast.cname cr.Ast.cspan cv)
  | (Ast.LFilter _ | Ast.LUnion _) as b ->
      let s = coerce_one_segment ctx b in
      ( Geom.line_through s.Fold_state.pa s.Fold_state.pb,
        Some [ (s.Fold_state.pa, s.Fold_state.pb) ] )
  | Ast.LSelect (sels, span) ->
      let _, _, pl, pm = select_cand ctx sels span in
      (pl, pm)
and material_cid (ctx : Ctx.ctx) (cr : Ast.crease_ref) : int =
  match lookup_crease ctx cr with
  | Material (cid, _) -> cid
  | Mark (_, line) ->
      (* selecting a segment/ray of a mark is a folding-side operation
         (collapse `& .x`, fold-along, `at`): materialize the mark into a
         real crease now (subdivide along its line), then treat it as
         Material. Pure-reference marks — never segment-selected — never
         reach here, so they stay non-subdividing records (#26). *)
      let cid = Fold_state.fresh_crease_id () in
      let prov : State.provenance option =
        Some { State.axiom = "mark"; sources = [ "--" ^ cr.Ast.cname ];
               span = cr.Ast.cspan; name = None }
      in
      ctx.state :=
        Fold_state.subdivide_paper !(ctx.state) line ~crease_id:cid ~prov;
      promote_crease ctx cr.Ast.cname (Material (cid, line));
      cid
  | Bundle _ ->
      Error.fail cr.Ast.cspan
        (Printf.sprintf
           "--%s is a bundle, not a single crease; restrict it with & or \\"
           cr.Ast.cname)
  | Frozen _ ->
      Error.fail cr.Ast.cspan
        (Printf.sprintf
           "--%s is not a physical crease, so it has no segments to select"
           cr.Ast.cname)
  | Edge _ ->
      Error.fail cr.Ast.cspan
        (Printf.sprintf "--%s is a paper edge, not a crease with segments"
           cr.Ast.cname)
(* Incidence is a MATERIAL question, so it is checked in PAPER space, never
   table space: all points are material (paper) identities, so a point
   selector always names the one segment whose paper preimage it lies on —
   even when folding has stacked several segments onto the same table locus
   (notes/2026-07-03-crease-layer-selection.md; ADR 0014's "table-space
   selector can't disambiguate" is why table space is wrong here). *)
and seg_line (s : Fold_state.crease_segment) =
  Geom.line_through s.Fold_state.pa s.Fold_state.pb
and point_on_seg (pp : Geom.point) (s : Fold_state.crease_segment) =
  Geom.side_of_line (seg_line s) pp = 0
  &&
  let t = Geom.seg_param (s.Fold_state.pa, s.Fold_state.pb) pp in
  Num.compare t Num.zero >= 0 && Num.compare t Num.one <= 0
and seg_incident (ctx : Ctx.ctx) (sel : Ast.selector) (s : Fold_state.crease_segment) : bool =
  match sel with
  | Ast.SelPoint po -> point_on_seg (resolve_point ctx po) s
  | Ast.SelLine lo -> (
      match Geom.intersection (fst (resolve_paper_line ctx lo)) (seg_line s) with
      | Some ip -> point_on_seg ip s
      | None -> false)
  | Ast.SelFlap (Ast.FByPoints (pts, fspan)) ->
      flap_lookup_result fspan
        (match face_of_points ctx (List.map (resolve_point ctx) pts) with
        | `Face fi ->
            let l, r = s.Fold_state.faces in
            `Found (l = fi || r = fi)
        | (`Zero | `Ambiguous) as bad -> bad)
(* every existing straight line a --[…] selector may name: the four paper
   edges plus each material crease segment (ADR 0014). Each candidate carries
   a table-space line (for use as a fold axis, the returned value) plus
   PAPER-space endpoints + line + optional marks — incidence is a material
   question, checked in paper space like `seg_incident`, so folded-stacked
   candidates stay distinct. Edges are markless (None). *)
and select_candidates (ctx : Ctx.ctx) :
    (Geom.line * (Geom.point * Geom.point)
    * Geom.line * (Geom.point * Geom.point) list option) list =
  let edges =
    List.map
      (fun (a, b) ->
        let ca = corner_point a and cb = corner_point b in
        let ta = Fold_state.table_position !(ctx.state) ca
        and tb = Fold_state.table_position !(ctx.state) cb in
        (Geom.line_through ta tb, (ca, cb), Geom.line_through ca cb, None))
      [ ("a", "b"); ("b", "c"); ("c", "d"); ("d", "a") ]
  in
  let creases =
    List.concat_map
      (fun cid ->
        List.map
          (fun (s : Fold_state.crease_segment) ->
            ( Geom.line_through s.Fold_state.ta s.Fold_state.tb,
              (s.Fold_state.pa, s.Fold_state.pb),
              Geom.line_through s.Fold_state.pa s.Fold_state.pb,
              Some [ (s.Fold_state.pa, s.Fold_state.pb) ] ))
          (Fold_state.crease_segments !(ctx.state) cid))
      (Fold_state.all_crease_ids !(ctx.state))
  in
  edges @ creases
and cand_incident (ctx : Ctx.ctx) (sel : Ast.selector) (_l, (pa, pb), _pl, _pm) : bool =
  let on t = Num.compare t Num.zero >= 0 && Num.compare t Num.one <= 0 in
  match sel with
  | Ast.SelPoint po ->
      let pp = resolve_point ctx po in
      Geom.side_of_line _pl pp = 0 && on (Geom.seg_param (pa, pb) pp)
  | Ast.SelLine lo -> (
      match Geom.intersection (fst (resolve_paper_line ctx lo)) _pl with
      | Some ip -> on (Geom.seg_param (pa, pb) ip)
      | None -> false)
  | Ast.SelFlap (Ast.FByPoints (_, fspan)) ->
      Error.fail fspan
        "a flap is not a valid --[…] constraint; use & to filter a crease"
and select_cand (ctx : Ctx.ctx) (sels : Ast.selector list) (span : Error.span) :
    Geom.line * (Geom.point * Geom.point)
    * Geom.line * (Geom.point * Geom.point) list option =
  match
    List.filter
      (fun c -> List.for_all (fun s -> cand_incident ctx s c) sels)
      (select_candidates ctx)
  with
  | [ c ] -> c
  | [] ->
      Error.fail span
        (Printf.sprintf "no crease or edge is incident to all of %s"
           (selstr sels))
  | many ->
      Error.fail span
        (Printf.sprintf
           "--[…] is ambiguous: %d creases/edges match %s; add a constraint"
           (List.length many) (selstr sels))
and select_line (ctx : Ctx.ctx) (sels : Ast.selector list) (span : Error.span) : Geom.line =
  let l, _, _, _ = select_cand ctx sels span in
  l
and select_point (ctx : Ctx.ctx) (los : Ast.line_operand list) (span : Error.span) : Geom.point =
  match los with
  | [] | [ _ ] -> Error.fail span ".[…] needs at least two lines to meet"
  | _ ->
      let resolved = List.map (fun lo -> (lo, resolve_paper_line ctx lo)) los in
      let lines = List.map (fun (_, (l, _)) -> l) resolved in
      let l1, l2 =
        match lines with a :: b :: _ -> (a, b) | _ -> assert false
      in
      let pp =
        match Geom.intersection l1 l2 with
        | Some p -> p
        | None -> Error.fail span "the lines are parallel; no meet point"
      in
      (* concurrency: every listed line passes through the crossing *)
      List.iter
        (fun l ->
          if Geom.side_of_line l pp <> 0 then
            Error.fail span "the lines are not concurrent; no common point")
        lines;
      (* the crossing must be physically real: each operand's mark must reach
         it (marked creases), or it must be on the sheet (markless edges) *)
      let on_chord (a, b) =
        let t = Geom.seg_param (a, b) pp in
        Num.compare t Num.zero >= 0 && Num.compare t Num.one <= 0
      in
      List.iter
        (fun (lo, (_, marks)) ->
          match marks with
          | Some chords ->
              if not (List.exists on_chord chords) then
                Error.fail span
                  (Printf.sprintf "the mark of %s does not reach the crossing"
                     (lstr lo))
          | None ->
              if not (Fold_state.on_paper !(ctx.state) pp) then
                Error.fail span
                  (Printf.sprintf "%s is off the paper" (lstr lo)))
        resolved;
      pp
and span_of_line (lo : Ast.line_operand) : Error.span =
  match lo with
  | Ast.LNamed cr -> cr.Ast.cspan
  | Ast.LFilter (_, _, s) | Ast.LUnion (_, s) | Ast.LSelect (_, s) -> s
and bundle_segments (ctx : Ctx.ctx) (lo : Ast.line_operand) :
    int option * Fold_state.crease_segment list =
  match lo with
  | Ast.LNamed cr -> (
      match lookup_crease ctx cr with
      | Bundle expr -> bundle_segments ctx expr
      | Edge (a, b) ->
          ( None,
            Fold_state.edge_boundary_segments !(ctx.state)
              (Geom.line_through (corner_point a) (corner_point b)) )
      | _ ->
          let cid = material_cid ctx cr in
          (Some cid, Fold_state.crease_segments !(ctx.state) cid))
  | Ast.LFilter (b, elt, _) ->
      let cid, segs = bundle_segments ctx b in
      let sel, keep =
        match elt with Ast.Keep s -> (s, true) | Ast.Drop s -> (s, false)
      in
      (cid, List.filter (fun s -> seg_incident ctx sel s = keep) segs)
  | Ast.LUnion (los, _) ->
      (None, List.concat_map (fun l -> snd (bundle_segments ctx l)) los)
  | Ast.LSelect _ ->
      Error.fail (span_of_line lo)
        "a --[…] result is a single line, not a segment bundle; filter a \
         named crease with & instead"
and coerce_one_segment (ctx : Ctx.ctx) (lo : Ast.line_operand) : Fold_state.crease_segment =
  match snd (bundle_segments ctx lo) with
  | [ s ] -> s
  | [] ->
      Error.fail (span_of_line lo)
        (Printf.sprintf "no segment of %s matches" (lstr lo))
  | many ->
      Error.fail (span_of_line lo)
        (Printf.sprintf "%s is ambiguous: %d segments match; add a selector"
           (lstr lo) (List.length many))

let table_of (ctx : Ctx.ctx) (po : Ast.point_operand) : Geom.point =
  Fold_state.table_position !(ctx.state) (resolve_point ctx po)

(* faces whose PAPER polygon contains material point [pp] *)
let faces_containing (ctx : Ctx.ctx) (pp : Geom.point) : int list =
  let st = !(ctx.state) in
  let acc = ref [] in
  Array.iteri
    (fun i (f : Fold_state.face) -> if Geom.in_convex_polygon f pp then acc := i :: !acc)
    (Fold_state.faces st);
  List.rev !acc

(* resolve a flap operand to its unique current flap — a coplanar cluster of
   faces (ADR 0017: two faces joined only by a still-unfolded F edge are the
   same flap). Slots demand uniqueness at cluster granularity; errors name
   the candidate flaps. *)
let resolve_flap_cluster (ctx : Ctx.ctx) (fa : Ast.flap_arg) (span : Error.span) : int list =
  match fa with
  | Ast.FlapPoint po -> (
      match faces_containing ctx (resolve_point ctx po) with
      | [] ->
          Error.fail span (Printf.sprintf "%s is not on the paper" (fstr fa))
      | faces -> (
          let cl = Fold_state.coplanar_clusters !(ctx.state) in
          let n = Array.length (Fold_state.faces !(ctx.state)) in
          match List.sort_uniq compare (List.map (fun f -> cl.(f)) faces) with
          | [ id ] -> List.filter (fun f -> cl.(f) = id) (List.init n Fun.id)
          | ids ->
              Error.fail span
                (Printf.sprintf
                   "%s lies on a crease shared by %d flaps; name the flap \
                    with #[...]"
                   (fstr fa) (List.length ids))))
  | Ast.FlapSpec (Ast.FByPoints (pts, fspan)) ->
      flap_lookup_result fspan
        (match
           Fold_state.flap_of_points !(ctx.state) (List.map (resolve_point ctx) pts)
         with
        | `Cluster fs -> `Found fs
        | (`Zero | `Ambiguous) as bad -> bad)
  | Ast.FlapLine lo -> (
      let candidates =
        match lo with
        | Ast.LNamed cr ->
            let cid = material_cid ctx cr in
            Fold_state.crease_segments !(ctx.state) cid
            |> List.concat_map (fun (s : Fold_state.crease_segment) ->
                   let l, r = s.Fold_state.faces in
                   l :: (if r >= 0 then [ r ] else []))
            |> List.sort_uniq compare
        | (Ast.LFilter _ | Ast.LUnion _) as b ->
            snd (bundle_segments ctx b)
            |> List.concat_map (fun (s : Fold_state.crease_segment) ->
                   let l, r = s.Fold_state.faces in
                   l :: (if r >= 0 then [ r ] else []))
            |> List.sort_uniq compare
        | _ ->
            Error.fail span
              (Printf.sprintf
                 "%s is not a physical crease, so it names no flap" (lstr lo))
      in
      match candidates with
      | [] -> Error.fail span (Printf.sprintf "%s touches no flap" (fstr fa))
      | _ -> (
          let cl = Fold_state.coplanar_clusters !(ctx.state) in
          let n = Array.length (Fold_state.faces !(ctx.state)) in
          let cluster_ids =
            List.sort_uniq compare (List.map (fun f -> cl.(f)) candidates)
          in
          match cluster_ids with
          | [ id ] -> List.filter (fun f -> cl.(f) = id) (List.init n Fun.id)
          | many ->
              Error.fail span
                (Printf.sprintf
                   "%s touches %d flaps; add a point, e.g. #[.p]" (fstr fa)
                   (List.length many))))

(* face-precise resolution for collapse's `over`/`under`: a sector around a
   collapse vertex is always one FACE (ADR 0017 non-goal — over/under
   stacking order is not lifted to clusters), unlike `moving`/`up to`'s flap
   operand. Mirrors resolve_flap_cluster's FlapPoint/FlapSpec branches but
   via face_of_points, not the cluster-coarsened flap_of_points. *)
let resolve_sector_face (ctx : Ctx.ctx) (fa : Ast.flap_arg) (span : Error.span) : int =
  match fa with
  | Ast.FlapPoint po -> (
      match faces_containing ctx (resolve_point ctx po) with
      | [ i ] -> i
      | [] ->
          Error.fail span (Printf.sprintf "%s is not on the paper" (fstr fa))
      | many ->
          Error.fail span
            (Printf.sprintf
               "%s lies on a crease shared by %d flaps; name the flap with \
                #[...]"
               (fstr fa) (List.length many)))
  | Ast.FlapSpec (Ast.FByPoints (pts, fspan)) ->
      flap_lookup_result fspan
        (match face_of_points ctx (List.map (resolve_point ctx) pts) with
        | `Face fi -> `Found fi
        | (`Zero | `Ambiguous) as bad -> bad)
  | Ast.FlapLine _ ->
      (* over_flap's grammar never produces FlapLine *)
      Error.fail span
        (Printf.sprintf "%s cannot name an over/under sector" (fstr fa))

(* which side of [axis] a flap anchor moves; point sugar keeps the existing
   side-of-the-point semantics. Resolution failures (point off paper, ambiguous
   flap) raise WITHIN — they are candidate-independent; only the on-axis /
   straddle verdicts are returned so axiom-5 selection can reject a candidate
   without erroring. *)
let side_of_flap_arg_res (ctx : Ctx.ctx) (axis : Geom.line) (fa : Ast.flap_arg)
    (span : Error.span) : (int, [ `OnAxis | `Straddles ]) result =
  match fa with
  | Ast.FlapPoint po ->
      let s = Geom.side_of_line axis (table_of ctx po) in
      if s = 0 then Error `OnAxis else Ok s
  | _ -> (
      let cluster = resolve_flap_cluster ctx fa span in
      let polys = List.map (Fold_state.table_polygon !(ctx.state)) cluster in
      let pos = List.exists (Array.exists (fun p -> Geom.side_of_line axis p > 0)) polys in
      let neg = List.exists (Array.exists (fun p -> Geom.side_of_line axis p < 0)) polys in
      match (pos, neg) with
      | true, true -> Error `Straddles
      | true, false -> Ok 1
      | false, true -> Ok (-1)
      | false, false -> Error `OnAxis)

let side_of_flap_arg (ctx : Ctx.ctx) (axis : Geom.line) (fa : Ast.flap_arg)
    (span : Error.span) : int =
  match side_of_flap_arg_res ctx axis fa span with
  | Ok s -> s
  | Error `Straddles ->
      Error.fail span
        (Printf.sprintf
           "%s straddles the fold axis; anchor with a point instead" (fstr fa))
  | Error `OnAxis -> (
      match fa with
      | Ast.FlapPoint _ -> Error.fail span "the moving point lies on the fold axis"
      | _ -> Error.fail span (Printf.sprintf "%s lies on the fold axis" (fstr fa)))

(* Default-scope anchor: the faces carrying the operand, as a UNION — a point on
   a crease shared by several flaps seeds all of them (design option (a)), so no
   ambiguity error here (unlike resolve_flap_cluster). *)
let anchor_faces (ctx : Ctx.ctx) (fa : Ast.flap_arg) (span : Error.span) : int list =
  match fa with
  | Ast.FlapPoint po -> (
      match faces_containing ctx (resolve_point ctx po) with
      | [] -> Error.fail span (Printf.sprintf "%s is not on the paper" (fstr fa))
      | fs -> fs)
  | Ast.FlapSpec (Ast.FByPoints (pts, _)) -> (
      let per_pt = List.map (fun p -> faces_containing ctx (resolve_point ctx p)) pts in
      match per_pt with
      | [] -> Error.fail span "empty flap selector"
      | first :: rest ->
          (match List.fold_left (fun acc l -> List.filter (fun f -> List.mem f l) acc) first rest with
           | [] -> Error.fail span (Printf.sprintf "%s is not on the paper" (fstr fa))
           | fs -> fs))
  | Ast.FlapLine _ -> resolve_flap_cluster ctx fa span

(* Moving side for the default branch. Operands carrying explicit point(s) take
   the point's side (a shared-crease flap straddles the axis, but the tip's side
   is unambiguous — the point-anchor rule). A line operand falls back to the
   cluster extent via side_of_flap_arg_res. *)
let default_move_side (ctx : Ctx.ctx) (axis : Geom.line) (fa : Ast.flap_arg) (span : Error.span) : int =
  let side_of_point po =
    let s = Geom.side_of_line axis (table_of ctx po) in
    if s = 0 then Error.fail span "the moving point lies on the fold axis" else s
  in
  match fa with
  | Ast.FlapPoint po -> side_of_point po
  | Ast.FlapSpec (Ast.FByPoints (pts, _)) -> (
      match pts with
      | po :: _ -> side_of_point po
      | [] -> Error.fail span "empty flap selector")
  | Ast.FlapLine _ -> side_of_flap_arg ctx axis fa span

let target_of (ctx : Ctx.ctx) (fa : Ast.flap_arg) (span : Error.span) :
    Fold_state.scope_target =
  match fa with
  | Ast.FlapPoint _ | Ast.FlapSpec _ ->
      let cluster = resolve_flap_cluster ctx fa span in
      Fold_state.TargetHinged (fun f -> List.mem f cluster)
  | Ast.FlapLine lo -> (
      match lo with
      | Ast.LNamed cr ->
          let cid = material_cid ctx cr in
          let st = !(ctx.state) in
          Fold_state.TargetHinged
            (fun f ->
              Array.exists
                (fun (h : Fold_state.hinge) ->
                  h.Fold_state.crease_id = cid
                  && (h.Fold_state.fa = f || h.Fold_state.fb = f))
                (Fold_state.hinges st))
      | (Ast.LFilter _ | Ast.LUnion _) as b ->
          let s = coerce_one_segment ctx b in
          let l, r = s.Fold_state.faces in
          Fold_state.TargetHinged (fun f -> f = l || f = r)
      | _ ->
          Error.fail span
            (Printf.sprintf
               "%s is not a physical crease, so it names no flap" (lstr lo)))

(* A mark's extent (spec §4), resolved to PAPER-space geometry and checked
   against the motion's axis. [table_axis] is TABLE-space (as `resolve_line`
   / `resolve_markable` produce — the current physical layout the fold acts
   on), but `resolve_point` always yields the fold-invariant PAPER
   coordinate, so the on-axis check goes through `table_of` to compare like
   spaces. `Full` needs nothing further (today's subdivide-the-whole-axis
   behaviour, unchanged). A partial extent also returns its PAPER-space
   representative point (mark_rep_point's convention: the first point of a
   segment, or the point itself) and the PAPER-space line it lies on:
   Fold_state.classify_mark_extent and the resulting mark's [mline] both
   need paper space, which need not equal [table_axis] once the carrying
   flap has moved (see Fold_state.classify_mark_extent's doc). *)
let resolve_mark_extent (ctx : Ctx.ctx) (table_axis : Geom.line) (ext : Ast.extent)
    (span : Error.span) :
    [ `Full | `Partial of Fold_state.mark_geom * Geom.point * Geom.line ] =
  let on_axis (po : Ast.point_operand) : Geom.point =
    let p = resolve_point ctx po in
    if
      Geom.side_of_line table_axis
        (Fold_state.table_position !(ctx.state) p)
      <> 0
    then
      Error.fail span
        (Printf.sprintf "%s is not on the mark's line" (pstr po));
    p
  in
  match ext with
  | Ast.Full -> `Full
  | Ast.Between (a, b) ->
      let pa = on_axis a and pb = on_axis b in
      if Geom.point_equal pa pb then
        Error.fail span "the mark's extent needs two distinct points";
      `Partial (Fold_state.MSeg (pa, pb), pa, Geom.line_through pa pb)
  | Ast.At p ->
      let pp = on_axis p in
      (* a lone point gives no second point to build its own paper-space
         line from; project [table_axis] into paper space via whichever of
         the point's own faces it actually crosses the interior of (within
         one flap every face shares one isometry, so any works). Falls back
         to the table-space axis itself if none do (an axis tangent to the
         paper only at [pp] — believed unreachable via the grammar); [mline]
         is display-only, so an imprecise fallback here is not
         load-bearing. *)
      let st = !(ctx.state) in
      let rec paper_axis_via = function
        | [] -> table_axis
        | fi :: rest -> (
            match Fold_state.axis_chord_in_face st fi table_axis with
            | Some (p, q) when not (Geom.point_equal p q) ->
                Geom.line_through p q
            | _ -> paper_axis_via rest)
      in
      `Partial (Fold_state.MPoint pp, pp, paper_axis_via (faces_containing ctx pp))

(* Behaviour 3: the flap (coplanar cluster, as its face list) a partial
   mark's extent is written onto. An explicit #[...] layer wins (mirrors
   resolve_flap_cluster's FlapSpec branch); otherwise default to the
   carrying flap — the cluster containing the extent's representative
   paper point, erroring if that point sits on a boundary shared by several
   flaps (ambiguous without a #[...] to disambiguate). *)
let resolve_mark_flap (ctx : Ctx.ctx) (layer_opt : Ast.flap_operand option)
    (rep : Geom.point) (span : Error.span) : int list =
  match layer_opt with
  | Some (Ast.FByPoints (pts, fspan)) -> (
      match
        Fold_state.flap_of_points !(ctx.state) (List.map (resolve_point ctx) pts)
      with
      | `Cluster fs -> fs
      | `Zero -> Error.fail fspan "those points aren't all on one flap"
      | `Ambiguous -> Error.fail fspan "ambiguous flap; add another point")
  | None -> (
      match faces_containing ctx rep with
      | [] -> Error.fail span "the mark's extent is not on the paper"
      | faces -> (
          let st = !(ctx.state) in
          let cl = Fold_state.coplanar_clusters st in
          let n = Array.length (Fold_state.faces st) in
          match List.sort_uniq compare (List.map (fun f -> cl.(f)) faces) with
          | [ id ] -> List.filter (fun f -> cl.(f) = id) (List.init n Fun.id)
          | ids ->
              Error.fail span
                (Printf.sprintf
                   "the mark's endpoint lies on a crease shared by %d \
                    flaps; name the flap with #[...]"
                   (List.length ids))))

(* ---- placed folds (spec 2026-09-10-reverse-fold-and-layer-placement) ---- *)

let placed_fold_plan (ctx : Ctx.ctx) (axis : Geom.line) ~(anchor : Ast.flap_arg)
    ~(place : Ast.place_dir * Ast.flap_arg) (span : Error.span) :
    int * bool array * Fold_state.placement =
  let st = !(ctx.state) in
  let n = Array.length (Fold_state.faces st) in
  let move_side = default_move_side ctx axis anchor span in
  let piece side fi =
    Geom.clip_convex_halfplane axis side (Fold_state.table_polygon_ccw st fi)
  in
  let cluster = resolve_flap_cluster ctx anchor span in
  let block = Array.make n false in
  List.iter
    (fun fi -> if Array.length (piece move_side fi) >= 3 then block.(fi) <- true)
    cluster;
  if not (Array.exists Fun.id block) then
    Error.fail span "the moving flap has no material on the moving side";
  let dir, target = place in
  let target_cluster = resolve_flap_cluster ctx target span in
  (* a target face must keep a stationary piece: any non-block face, or a
     block face the axis cuts (the anchor's own hinge layer, for a tuck) *)
  let stay_piece fi =
    if block.(fi) then piece (-move_side) fi else Fold_state.table_polygon_ccw st fi
  in
  if List.for_all (fun fi -> Array.length (stay_piece fi) < 3) target_cluster then
    Error.fail span
      "the placement target moves with the fold; name a stationary flap";
  (* landing footprint: the block's move-side pieces reflected across the axis *)
  let landing =
    List.filter_map
      (fun fi ->
        if block.(fi) then
          let p = piece move_side fi in
          if Array.length p >= 3 then
            Some
              (Array.map (Geom.reflect_point axis) p |> fun a ->
               if Num.sign (Geom.signed_area a) < 0 then
                 Array.init (Array.length a) (fun k -> a.(Array.length a - 1 - k))
               else a)
          else None
        else None)
      (List.init n Fun.id)
  in
  let overlapping =
    List.filter
      (fun fi ->
        let tp = stay_piece fi in
        Array.length tp >= 3 && List.exists (fun l -> Geom.convex_overlap tp l) landing)
      target_cluster
  in
  let rank = Fold_state.rank st in
  match overlapping with
  | [] ->
      Error.fail span
        (Printf.sprintf "%s's flap does not cover where the moved material lands"
           (fstr target))
  | f :: rest ->
      let pick better = List.fold_left (fun a b -> if better b a then b else a) f rest in
      let placement =
        match dir with
        | Ast.PlaceUnder -> Fold_state.Under (pick (fun b a -> rank.(b) < rank.(a)))
        | Ast.PlaceOver -> Fold_state.Over (pick (fun b a -> rank.(b) > rank.(a)))
      in
      (move_side, block, placement)

let placement_failure_message (dir : Ast.place_dir) (target : Ast.flap_arg)
    (v : Fold_state.violation) : string =
  let word = match dir with Ast.PlaceOver -> "over" | Ast.PlaceUnder -> "under" in
  match v with
  | Fold_state.Taco_tortilla { tortilla; _ } ->
      Printf.sprintf "placing the moved material %s %s would pierce layer %d" word
        (fstr target) tortilla
  | Fold_state.Taco_taco (_, _) ->
      Printf.sprintf "placing the moved material %s %s would pierce another layer"
        word (fstr target)
  | v -> Fold_state.violation_to_string v

let tip_faces (ctx : Ctx.ctx) (axis : Geom.line) ~(anchor : Ast.flap_arg)
    (span : Error.span) : int * bool array =
  let st = !(ctx.state) in
  let n = Array.length (Fold_state.faces st) in
  let move_side = default_move_side ctx axis anchor span in
  let beyond fi =
    Array.length
      (Geom.clip_convex_halfplane axis move_side (Fold_state.table_polygon_ccw st fi))
    >= 3
  in
  let tip = Array.make n false in
  let seeds = List.filter beyond (anchor_faces ctx anchor span) in
  if seeds = [] then
    Error.fail span "the moving flap has no material on the moving side";
  let hinges = Fold_state.hinges st in
  let reaches_beyond hi =
    let ta, tb = Fold_state.hinge_table_segment st hi in
    Geom.side_of_line axis ta = move_side || Geom.side_of_line axis tb = move_side
  in
  let stack = ref seeds in
  List.iter (fun s -> tip.(s) <- true) seeds;
  while !stack <> [] do
    let f = List.hd !stack in
    stack := List.tl !stack;
    Array.iteri
      (fun hi (h : Fold_state.hinge) ->
        let other =
          if h.Fold_state.fa = f then h.Fold_state.fb
          else if h.Fold_state.fb = f then h.Fold_state.fa
          else -1
        in
        if other >= 0 && (not tip.(other)) && beyond other && reaches_beyond hi
        then begin
          tip.(other) <- true;
          stack := other :: !stack
        end)
      hinges
  done;
  (move_side, tip)
