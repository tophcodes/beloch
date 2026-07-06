(** Evaluate a program, resolving names and applying axioms. Geometry is exact;
    preconditions are reported as Error.Beloch_error. *)

let corners : (string * Geom.point) list =
  let q = Num.of_int in
  [
    ("a", { Geom.x = q 0; y = q 0 });
    ("b", { Geom.x = q 1; y = q 0 });
    ("c", { Geom.x = q 1; y = q 1 });
    ("d", { Geom.x = q 0; y = q 1 });
  ]

type folded = {
  state : Fold_state.t;
  named_points : (string * Geom.point) list;
  named_lines : (string * Geom.line) list;
  frames : (string option * Fold_state.t) list;
}

(* ---- Scope-stack context ---- *)

type crease_val =
  | Material of int * Geom.line
  | Frozen of Geom.line

(* axiom-5 (`map --l1 onto --l2`) needs its candidate bisectors selected against
   the current fold state (material of l1, paper incidence, `toward` direction),
   so [axis_of] defers that: intersecting lines yield [Ax5], everything else a
   fully-resolved [Axis]. *)
type ax5_pending = {
  la : Geom.line;
  lb : Geom.line;
  cands : Geom.line * Geom.line;   (* angle bisectors of la, lb *)
  toward : Geom.point option;      (* table space, already checked off la *)
  l1_op : Ast.line_operand;        (* for the l1-material lookup *)
  l1_str : string;
  l2_str : string;
  toward_str : string option;
  sources : string list;           (* provenance, includes toward when present *)
}

type axis_result =
  | Axis of Geom.line * string * string list
  | Ax5 of ax5_pending

type instance = {
  ipoints : (string, Geom.point) Hashtbl.t;
  ilines : (string, crease_val) Hashtbl.t;
}

type scope = {
  points    : (string, Geom.point) Hashtbl.t;
  lines     : (string, crease_val) Hashtbl.t;
  instances : (string, instance) Hashtbl.t;
}

let make_scope () = {
  points    = Hashtbl.create 8;
  lines     = Hashtbl.create 8;
  instances = Hashtbl.create 4;
}

type name_ctx = Root | InInstance of string | Anon

type ctx = {
  mutable scopes : scope list;  (* head = innermost *)
  mutable name_ctx : name_ctx;
  mutable cur_def_idx : int option; (* Some k while running def k's body *)
  mutable next_def_idx : int;
  defs : (string, int * Ast.param list * Ast.stmt list) Hashtbl.t;
  state : Fold_state.t ref;
  mutable panel : string option;
  panels : (string, unit) Hashtbl.t;
  mutable frames_rev : (string option * Fold_state.t) list;
}

let lookup_point (ctx : ctx) (pr : Ast.point_ref) : Geom.point =
  match List.find_map (fun s -> Hashtbl.find_opt s.points pr.Ast.name) ctx.scopes with
  | Some p -> p
  | None   -> Error.fail pr.Ast.span (Printf.sprintf "undefined point .%s" pr.Ast.name)

let lookup_crease (ctx : ctx) (cr : Ast.crease_ref) : crease_val =
  match List.find_map (fun s -> Hashtbl.find_opt s.lines cr.Ast.cname) ctx.scopes with
  | Some cv -> cv
  | None -> Error.fail cr.Ast.cspan (Printf.sprintf "undefined crease --%s" cr.Ast.cname)

let lookup_instance (ctx : ctx) (name : string) (span : Error.span) : instance =
  match
    List.find_map (fun s -> Hashtbl.find_opt s.instances name) ctx.scopes
  with
  | Some i -> i
  | None -> Error.fail span (Printf.sprintf "undefined instance $%s" name)

let is_temp (n : string) = String.length n > 0 && n.[0] = '_'

let bind_point (ctx : ctx) (name : string) (span : Error.span) (p : Geom.point)
    =
  let s = List.hd ctx.scopes in
  if (not (is_temp name)) && Hashtbl.mem s.points name then
    Error.fail span
      (Printf.sprintf "point .%s is already bound; only _-prefixed temps rebind"
         name);
  Hashtbl.replace s.points name p

let bind_crease (ctx : ctx) (name : string) (span : Error.span) (cv : crease_val) =
  let s = List.hd ctx.scopes in
  if (not (is_temp name)) && Hashtbl.mem s.lines name then
    Error.fail span
      (Printf.sprintf "crease --%s is already bound; only _-prefixed temps rebind"
         name);
  Hashtbl.replace s.lines name cv


(* ---- Evaluator ---- *)

let eval_folded (prog : Ast.program) : folded =
  let root_scope = make_scope () in
  List.iter (fun (n, p) -> Hashtbl.replace root_scope.points n p) corners;
  let ctx = {
    scopes = [root_scope];
    name_ctx = Root;
    cur_def_idx = None;
    next_def_idx = 0;
    defs = Hashtbl.create 4;
    state  = ref Fold_state.init_square;
    panel = None;
    panels = Hashtbl.create 4;
    frames_rev = [];
  } in
  (* render an operand back to source text for provenance + error messages *)
  let rec pstr (po : Ast.point_operand) : string =
    match po with
    | Ast.PNamed pr -> "." ^ pr.Ast.name
    | Ast.PCross (l1, l2, _) -> Printf.sprintf ".(%s %s)" (lstr l1) (lstr l2)
    | Ast.PMember (i, m, _) -> Printf.sprintf ".[$%s %s]" i m
  and lstr (lo : Ast.line_operand) : string =
    match lo with
    | Ast.LNamed cr -> "--" ^ cr.Ast.cname
    | Ast.LThrough (p1, p2, _) -> Printf.sprintf "--(%s %s)" (pstr p1) (pstr p2)
    | Ast.LMember (i, m, _) -> Printf.sprintf "--[$%s %s]" i m
    | Ast.LAt (cr, sels, _) -> Printf.sprintf "--%s at %s" cr.Ast.cname (selstr sels)
  and selstr (sels : Ast.selector list) : string =
    let one = function
      | Ast.SelPoint po -> pstr po
      | Ast.SelLine lo -> lstr lo
      | Ast.SelFlap (Ast.FByPoints (pts, _)) ->
          Printf.sprintf "#(%s)" (String.concat " " (List.map pstr pts))
    in
    match sels with
    | [ s ] -> one s
    | ss -> Printf.sprintf "(%s)" (String.concat " and " (List.map one ss))
  and fstr (fa : Ast.flap_arg) : string =
    match fa with
    | Ast.FlapPoint po -> pstr po
    | Ast.FlapLine lo -> lstr lo
    | Ast.FlapSpec (Ast.FByPoints (pts, _)) ->
        Printf.sprintf "#(%s)" (String.concat " " (List.map pstr pts))
  in
  let materialize_crease ~(name : string) (span : Error.span) (cv : crease_val) :
      Geom.line =
    match cv with
    | Frozen l -> l
    | Material (cid, l_orig) -> (
        match Fold_state.crease_axis !(ctx.state) cid l_orig with
        | `Line l -> l
        (* a crease that cut no face (e.g. lies on the paper boundary) has no
           material pieces but is still flat at its original line — byte-stable
           and lets reference-only boundary creases resolve *)
        | `Empty -> l_orig
        | `Bent ->
            Error.fail span
              (Printf.sprintf
                 "--%s is no longer straight after folding; select a segment \
                  with `at`, e.g. --%s at #(.a .b .c) or --%s at .p"
                 name name name))
  in
  (* a cross operand resolved to PAPER space: the one material line carrying
     the crease's marks, plus those marks' paper chords (None when the operand
     is a constructed line / boundary reference with no marks) *)
  let paper_line_of_crease ~(name : string) (span : Error.span) (cv : crease_val)
      : Geom.line * (Geom.point * Geom.point) list option =
    match cv with
    | Frozen _ ->
        Error.fail span
          (Printf.sprintf
             "--%s is not a physical crease, so it has no material mark to \
              cross" name)
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
                  segment with `at`, e.g. --%s at #(.a .b .c)"
                 name name))
  in
  (* the unique FACE (the fine ADR-0014 partition, not a flap/coplanar
     cluster) whose paper polygon contains every point in [pts]. Unlike
     `moving`/`up to`'s flap operand (ADR 0017: coarsened to a coplanar
     cluster so a still-flat neighbourhood is one flap), `at`'s `#(...)`
     incidence check and `@collapse`'s `over`/`under` sector clause both need
     FACE precision even on a still-flat, multiply-precreased sheet: they
     disambiguate BETWEEN a crease bundle's own segments / a vertex's own
     sectors, which are still distinct faces while every one of them is the
     SAME flap (nothing has folded yet). Coarsening these to "the whole flap"
     would make every segment/sector match at once. *)
  let face_of_points (pts : Geom.point list) :
      [ `Face of int | `Zero | `Ambiguous ] =
    let st = !(ctx.state) in
    let contains i =
      List.for_all
        (fun p -> Geom.in_convex_polygon st.Fold_state.faces.(i).Fold_state.paper p)
        pts
    in
    let hits = ref [] in
    Array.iteri (fun i _ -> if contains i then hits := i :: !hits) st.Fold_state.faces;
    match !hits with [ i ] -> `Face i | [] -> `Zero | _ -> `Ambiguous
  in
  (* resolve a point operand to its material PAPER coordinate, a line operand to
     its TABLE-space line (fold axes align current table positions). `cross` is
     the exception: it is a material construction, so its operands resolve to
     PAPER-space lines via resolve_paper_line — folding never moves a mark
     within the sheet, so the crossing is fold-state-independent. *)
  let rec resolve_point (po : Ast.point_operand) : Geom.point =
    match po with
    | Ast.PNamed pr -> lookup_point ctx pr
    | Ast.PCross (l1, l2, span) -> (
        let la, ma = resolve_paper_line l1 and lb, mb = resolve_paper_line l2 in
        match Geom.intersection la lb with
        | None -> Error.fail span "creases are parallel; no intersection"
        | Some pp ->
            (* the crossing must be real: paper is opaque, so the marks must
               actually meet — [pp] on a chord of each crease that has marks,
               and on the sheet in any case *)
            let on_chord (a, b) =
              let t = Geom.seg_param (a, b) pp in
              Num.compare t Num.zero >= 0 && Num.compare t Num.one <= 0
            in
            let check lo = function
              | Some chords ->
                  if not (List.exists on_chord chords) then
                    Error.fail span
                      (Printf.sprintf
                         "%s: the mark of %s does not reach the crossing"
                         (pstr po) (lstr lo))
              | None ->
                  if not (Fold_state.on_paper !(ctx.state) pp) then
                    Error.fail span
                      (Printf.sprintf "%s is off the paper" (pstr po))
            in
            check l1 ma;
            check l2 mb;
            pp)
    | Ast.PMember (iname, mem, span) -> (
        let inst = lookup_instance ctx iname span in
        match Hashtbl.find_opt inst.ipoints mem with
        | Some p -> p
        | None ->
            Error.fail span
              (Printf.sprintf "instance $%s has no point member %s" iname mem))
  and resolve_line (lo : Ast.line_operand) : Geom.line =
    match lo with
    | Ast.LNamed cr -> materialize_crease ~name:cr.Ast.cname cr.Ast.cspan (lookup_crease ctx cr)
    | Ast.LThrough (p1, p2, span) ->
        let pp = Fold_state.table_position !(ctx.state) (resolve_point p1)
        and qq = Fold_state.table_position !(ctx.state) (resolve_point p2) in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf
               "%s and %s are at the same place, so there is no line through \
                them"
               (pstr p1) (pstr p2));
        Geom.line_through pp qq
    | Ast.LMember (iname, mem, span) -> (
        let inst = lookup_instance ctx iname span in
        match Hashtbl.find_opt inst.ilines mem with
        | Some cv -> materialize_crease ~name:mem span cv
        | None ->
            Error.fail span
              (Printf.sprintf "instance $%s has no line member %s" iname mem))
    | Ast.LAt (cr, sels, span) -> (
        let _cid, matches = at_matches cr sels span in
        match matches with
        | [ s ] -> Geom.line_through s.Fold_state.ta s.Fold_state.tb
        | [] ->
            Error.fail span
              (Printf.sprintf "no segment of --%s matches %s" cr.Ast.cname
                 (selstr sels))
        | many ->
            Error.fail span
              (Printf.sprintf
                 "--%s at %s is ambiguous: %d segments match; add a selector"
                 cr.Ast.cname (selstr sels) (List.length many)))
  and resolve_paper_line (lo : Ast.line_operand) :
      Geom.line * (Geom.point * Geom.point) list option =
    match lo with
    | Ast.LNamed cr ->
        paper_line_of_crease ~name:cr.Ast.cname cr.Ast.cspan
          (lookup_crease ctx cr)
    | Ast.LThrough (p1, p2, span) ->
        let pp = resolve_point p1 and qq = resolve_point p2 in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf
               "%s and %s are at the same place, so there is no line through \
                them"
               (pstr p1) (pstr p2));
        (Geom.line_through pp qq, None)
    | Ast.LMember (iname, mem, span) -> (
        let inst = lookup_instance ctx iname span in
        match Hashtbl.find_opt inst.ilines mem with
        | Some cv -> paper_line_of_crease ~name:mem span cv
        | None ->
            Error.fail span
              (Printf.sprintf "instance $%s has no line member %s" iname mem))
    | Ast.LAt (cr, sels, span) -> (
        let _cid, matches = at_matches cr sels span in
        match matches with
        | [ s ] ->
            ( Geom.line_through s.Fold_state.pa s.Fold_state.pb,
              Some [ (s.Fold_state.pa, s.Fold_state.pb) ] )
        | [] ->
            Error.fail span
              (Printf.sprintf "no segment of --%s matches %s" cr.Ast.cname
                 (selstr sels))
        | many ->
            Error.fail span
              (Printf.sprintf
                 "--%s at %s is ambiguous: %d segments match; add a selector"
                 cr.Ast.cname (selstr sels) (List.length many)))
  and material_cid (cr : Ast.crease_ref) : int =
    match lookup_crease ctx cr with
    | Material (cid, _) -> cid
    | Frozen _ ->
        Error.fail cr.Ast.cspan
          (Printf.sprintf
             "--%s is not a physical crease, so it has no segments to select"
             cr.Ast.cname)
  and at_matches (cr : Ast.crease_ref) (sels : Ast.selector list)
      (_span : Error.span) : int * Fold_state.crease_segment list =
    let cid = material_cid cr in
    let segs = Fold_state.crease_segments !(ctx.state) cid in
    let seg_line (s : Fold_state.crease_segment) =
      Geom.line_through s.Fold_state.ta s.Fold_state.tb
    in
    let point_on_seg (tp : Geom.point) (s : Fold_state.crease_segment) =
      Geom.side_of_line (seg_line s) tp = 0
      &&
      let t = Geom.seg_param (s.Fold_state.ta, s.Fold_state.tb) tp in
      Num.compare t Num.zero >= 0 && Num.compare t Num.one <= 0
    in
    let incident (sel : Ast.selector) (s : Fold_state.crease_segment) : bool =
      match sel with
      | Ast.SelPoint po ->
          point_on_seg
            (Fold_state.table_position !(ctx.state) (resolve_point po)) s
      | Ast.SelLine lo -> (
          match Geom.intersection (resolve_line lo) (seg_line s) with
          | Some ip -> point_on_seg ip s
          | None -> false)
      | Ast.SelFlap (Ast.FByPoints (pts, fspan)) -> (
          match face_of_points (List.map resolve_point pts) with
          | `Face fi ->
              let l, r = s.Fold_state.faces in
              l = fi || r = fi
          | `Zero -> Error.fail fspan "those points aren't all on one flap"
          | `Ambiguous -> Error.fail fspan "ambiguous flap; add another point")
    in
    (cid, List.filter (fun s -> List.for_all (fun sel -> incident sel s) sels) segs)
  in
  let table_of (po : Ast.point_operand) : Geom.point =
    Fold_state.table_position !(ctx.state) (resolve_point po)
  in
  (* faces whose PAPER polygon contains material point [pp] *)
  let faces_containing (pp : Geom.point) : int list =
    let st = !(ctx.state) in
    let acc = ref [] in
    Array.iteri
      (fun i (f : Fold_state.face) ->
        if Geom.in_convex_polygon f.Fold_state.paper pp then acc := i :: !acc)
      st.Fold_state.faces;
    List.rev !acc
  in
  (* resolve a flap operand to its unique current flap — a coplanar cluster of
     faces (ADR 0017: two faces joined only by a still-unfolded U edge are the
     same flap). Slots demand uniqueness at cluster granularity; errors name
     the candidate flaps. *)
  let resolve_flap_cluster (fa : Ast.flap_arg) (span : Error.span) : int list =
    match fa with
    | Ast.FlapPoint po -> (
        match faces_containing (resolve_point po) with
        | [] ->
            Error.fail span (Printf.sprintf "%s is not on the paper" (fstr fa))
        | faces -> (
            let cl = Fold_state.coplanar_clusters !(ctx.state) in
            let n = Array.length !(ctx.state).Fold_state.faces in
            match List.sort_uniq compare (List.map (fun f -> cl.(f)) faces) with
            | [ id ] -> List.filter (fun f -> cl.(f) = id) (List.init n Fun.id)
            | ids ->
                Error.fail span
                  (Printf.sprintf
                     "%s lies on a crease shared by %d flaps; name the flap \
                      with #(...)"
                     (fstr fa) (List.length ids))))
    | Ast.FlapSpec (Ast.FByPoints (pts, fspan)) -> (
        match
          Fold_state.flap_of_points !(ctx.state) (List.map resolve_point pts)
        with
        | `Cluster fs -> fs
        | `Zero -> Error.fail fspan "those points aren't all on one flap"
        | `Ambiguous -> Error.fail fspan "ambiguous flap; add another point")
    | Ast.FlapLine lo -> (
        let candidates =
          match lo with
          | Ast.LAt (cr, sels, aspan) -> (
              match at_matches cr sels aspan with
              | _, [ s ] ->
                  let l, r = s.Fold_state.faces in
                  l :: (if r >= 0 then [ r ] else [])
              | _, [] ->
                  Error.fail aspan
                    (Printf.sprintf "no segment of --%s matches %s"
                       cr.Ast.cname (selstr sels))
              | _, many ->
                  Error.fail aspan
                    (Printf.sprintf
                       "--%s at %s is ambiguous: %d segments match; add a \
                        selector"
                       cr.Ast.cname (selstr sels) (List.length many)))
          | Ast.LNamed cr ->
              let cid = material_cid cr in
              Fold_state.crease_segments !(ctx.state) cid
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
            let n = Array.length !(ctx.state).Fold_state.faces in
            let cluster_ids =
              List.sort_uniq compare (List.map (fun f -> cl.(f)) candidates)
            in
            match cluster_ids with
            | [ id ] -> List.filter (fun f -> cl.(f) = id) (List.init n Fun.id)
            | many ->
                Error.fail span
                  (Printf.sprintf
                     "%s touches %d flaps; add a point, e.g. #(.p)" (fstr fa)
                     (List.length many))))
  in
  (* face-precise resolution for @collapse's `over`/`under`: a sector around a
     collapse vertex is always one FACE (ADR 0017 non-goal — over/under
     stacking order is not lifted to clusters), unlike `moving`/`up to`'s flap
     operand. Mirrors resolve_flap_cluster's FlapPoint/FlapSpec branches but
     via face_of_points, not the cluster-coarsened flap_of_points. *)
  let resolve_sector_face (fa : Ast.flap_arg) (span : Error.span) : int =
    match fa with
    | Ast.FlapPoint po -> (
        match faces_containing (resolve_point po) with
        | [ i ] -> i
        | [] ->
            Error.fail span (Printf.sprintf "%s is not on the paper" (fstr fa))
        | many ->
            Error.fail span
              (Printf.sprintf
                 "%s lies on a crease shared by %d flaps; name the flap with \
                  #(...)"
                 (fstr fa) (List.length many)))
    | Ast.FlapSpec (Ast.FByPoints (pts, fspan)) -> (
        match face_of_points (List.map resolve_point pts) with
        | `Face fi -> fi
        | `Zero -> Error.fail fspan "those points aren't all on one flap"
        | `Ambiguous -> Error.fail fspan "ambiguous flap; add another point")
    | Ast.FlapLine _ ->
        (* over_flap's grammar never produces FlapLine *)
        Error.fail span
          (Printf.sprintf "%s cannot name an over/under sector" (fstr fa))
  in
  (* which side of [axis] a flap anchor moves; point sugar keeps the existing
     side-of-the-point semantics. Resolution failures (point off paper, ambiguous
     flap) raise WITHIN — they are candidate-independent; only the on-axis /
     straddle verdicts are returned so axiom-5 selection can reject a candidate
     without erroring. *)
  let side_of_flap_arg_res (axis : Geom.line) (fa : Ast.flap_arg)
      (span : Error.span) : (int, [ `OnAxis | `Straddles ]) result =
    match fa with
    | Ast.FlapPoint po ->
        let s = Geom.side_of_line axis (table_of po) in
        if s = 0 then Error `OnAxis else Ok s
    | _ -> (
        let cluster = resolve_flap_cluster fa span in
        let polys = List.map (Fold_state.table_polygon !(ctx.state)) cluster in
        let pos = List.exists (Array.exists (fun p -> Geom.side_of_line axis p > 0)) polys in
        let neg = List.exists (Array.exists (fun p -> Geom.side_of_line axis p < 0)) polys in
        match (pos, neg) with
        | true, true -> Error `Straddles
        | true, false -> Ok 1
        | false, true -> Ok (-1)
        | false, false -> Error `OnAxis)
  in
  let side_of_flap_arg (axis : Geom.line) (fa : Ast.flap_arg)
      (span : Error.span) : int =
    match side_of_flap_arg_res axis fa span with
    | Ok s -> s
    | Error `Straddles ->
        Error.fail span
          (Printf.sprintf
             "%s straddles the fold axis; anchor with a point instead" (fstr fa))
    | Error `OnAxis -> (
        match fa with
        | Ast.FlapPoint _ -> Error.fail span "the moving point lies on the fold axis"
        | _ -> Error.fail span (Printf.sprintf "%s lies on the fold axis" (fstr fa)))
  in
  let target_of (fa : Ast.flap_arg) (span : Error.span) :
      Fold_state.scope_target =
    match fa with
    | Ast.FlapPoint _ | Ast.FlapSpec _ ->
        let cluster = resolve_flap_cluster fa span in
        Fold_state.TargetHinged (fun f -> List.mem f cluster)
    | Ast.FlapLine lo -> (
        match lo with
        | Ast.LNamed cr ->
            let cid = material_cid cr in
            let st = !(ctx.state) in
            Fold_state.TargetHinged
              (fun f ->
                Array.exists
                  (fun (e : Fold_state.edge) ->
                    e.Fold_state.crease_id = cid
                    && (e.Fold_state.left = f || e.Fold_state.right = f))
                  st.Fold_state.edges)
        | Ast.LAt (cr, sels, aspan) -> (
            match at_matches cr sels aspan with
            | _, [ s ] ->
                let l, r = s.Fold_state.faces in
                Fold_state.TargetHinged (fun f -> f = l || f = r)
            | _, [] ->
                Error.fail aspan
                  (Printf.sprintf "no segment of --%s matches %s" cr.Ast.cname
                     (selstr sels))
            | _, many ->
                Error.fail aspan
                  (Printf.sprintf
                     "--%s at %s is ambiguous: %d segments match; add a \
                      selector"
                     cr.Ast.cname (selstr sels) (List.length many)))
        | _ ->
            Error.fail span
              (Printf.sprintf
                 "%s is not a physical crease, so it names no flap" (lstr lo)))
  in
  (* axis line + provenance (axiom tag, source names), evaluated against the
     current table positions *)
  let axis_of (span : Error.span) (ax : Ast.axiom) : axis_result =
    match ax with
    | Ast.Through (p, q) ->
        let pp = table_of p and qq = table_of q in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf
               "%s and %s are at the same place, so there is no line through \
                them"
               (pstr p) (pstr q));
        Axis (Geom.line_through pp qq, "axiom1", [ pstr p; pstr q ])
    | Ast.MapPoints (p, q) ->
        let pp = table_of p and qq = table_of q in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf "%s and %s are already at the same place" (pstr p)
               (pstr q));
        Axis (Geom.perpendicular_bisector pp qq, "axiom2", [ pstr p; pstr q ])
    | Ast.Perp (p, l) ->
        Axis
          ( Geom.perpendicular_through (resolve_line l) (table_of p),
            "axiom3",
            [ pstr p; lstr l ] )
    | Ast.MapOntoLine (p, l1, l2) -> (
        let pp = table_of p and ll1 = resolve_line l1 and ll2 = resolve_line l2 in
        match Geom.project_crease pp ll1 ll2 with
        | None ->
            Error.fail span
              (Printf.sprintf "map %s onto %s perp %s: lines are parallel, no fold exists"
                 (pstr p) (lstr l1) (lstr l2))
        | Some crease -> Axis (crease, "axiom4", [ pstr p; lstr l1; lstr l2 ]))
    | Ast.MapLines (l1, l2, p_opt) -> (
        let la = resolve_line l1 and lb = resolve_line l2 in
        let l1_str = lstr l1 and l2_str = lstr l2 in
        match Geom.angle_bisectors la lb with
        | None ->
            (* parallel: unique midline, `toward` has no meaning here *)
            let k =
              if Num.sign la.Geom.a <> 0 then Num.div lb.Geom.a la.Geom.a
              else Num.div lb.Geom.b la.Geom.b
            in
            if Num.equal lb.Geom.c (Num.mul k la.Geom.c) then
              Error.fail span "lines are identical";
            Axis (Geom.parallel_midline la lb, "axiom5", [ l1_str; l2_str ])
        | Some cands ->
            (* intersecting: defer bisector choice to the fold state. `toward`
               names where the fold goes, so a point on l1 is meaningless (E1);
               a point on l2 is fine. *)
            let toward = Option.map table_of p_opt in
            let toward_str = Option.map pstr p_opt in
            (match toward with
            | Some x when Geom.side_of_line la x = 0 ->
                Error.fail span
                  (Printf.sprintf
                     "`toward %s` lies on %s; `toward` names where the fold \
                      goes — pick a point off %s"
                     (Option.get toward_str) l1_str l1_str)
            | _ -> ());
            let sources =
              [ l1_str; l2_str ]
              @ (match toward_str with Some s -> [ s ] | None -> [])
            in
            Ax5
              {
                la;
                lb;
                cands;
                toward;
                l1_op = l1;
                l1_str;
                l2_str;
                toward_str;
                sources;
              })
    | Ast.MapThrough (p, d, p', x_opt) -> (
        let pp = table_of p and dd = resolve_line d and pp' = table_of p' in
        if Geom.point_equal pp pp' then
          Error.fail span
            (Printf.sprintf
               "map %s onto %s through %s: %s and %s are the same point, so no \
                fold exists"
               (pstr p) (lstr d) (pstr p') (pstr p) (pstr p'));
        let base = [ pstr p; lstr d; pstr p' ] in
        match Geom.beloch_creases pp dd pp' with
        | [] ->
            Error.fail span
              (Printf.sprintf "cannot fold %s onto %s through %s: out of reach"
                 (pstr p) (lstr d) (pstr p'))
        | [ c ] -> Axis (c, "axiom6", base)
        | creases -> (
            match x_opt with
            | None ->
                Error.fail span
                  (Printf.sprintf
                     "two folds place %s onto %s through %s; add 'toward .x'"
                     (pstr p) (lstr d) (pstr p'))
            | Some xo ->
                let xt = table_of xo in
                (* pick the crease whose landing (the reflection of p across it)
                   is nearest x; exact squared-distance comparison *)
                let dist2 (c : Geom.line) =
                  let im = Geom.reflect_point c pp in
                  let ex = Num.sub im.Geom.x xt.Geom.x
                  and ey = Num.sub im.Geom.y xt.Geom.y in
                  Num.add (Num.mul ex ex) (Num.mul ey ey)
                in
                let best =
                  List.fold_left
                    (fun acc c ->
                      match acc with
                      | None -> Some c
                      | Some b ->
                          if Num.compare (dist2 c) (dist2 b) < 0 then Some c
                          else acc)
                    None creases
                in
                match best with
                | Some c -> Axis (c, "axiom6", base @ [ pstr xo ])
                (* unreachable: this arm only runs with ≥2 creases, so the
                   fold over a non-empty list always yields [Some]. *)
                | None -> assert false))
    | Ast.MapBoth (p, d, q, e, x_opt) -> (
        let pp = table_of p and dd = resolve_line d in
        let qq = table_of q and ee = resolve_line e in
        let base = [ pstr p; lstr d; pstr q; lstr e ] in
        (* degeneracy guards *)
        if Geom.side_of_line ee qq = 0 then
          Error.fail span
            (Printf.sprintf
               "map %s onto %s and %s onto %s: %s already lies on %s — use \
                axiom 6 (fold %s onto %s through a point) then axiom 4"
               (pstr p) (lstr d) (pstr q) (lstr e) (pstr q) (lstr e) (pstr p)
               (lstr d));
        if Geom.parallel dd ee then
          Error.fail span
            (Printf.sprintf
               "map %s onto %s and %s onto %s: %s and %s are parallel — \
                degenerate, no general cubic fold"
               (pstr p) (lstr d) (pstr q) (lstr e) (lstr d) (lstr e));
        match Geom.beloch7_creases pp dd qq ee with
        | [] ->
            Error.fail span
              (Printf.sprintf
                 "cannot fold %s onto %s and %s onto %s: out of reach (no \
                  common tangent)"
                 (pstr p) (lstr d) (pstr q) (lstr e))
        | [ c ] -> Axis (c, "axiom7", base)
        | creases -> (
            match x_opt with
            | None ->
                Error.fail span
                  (Printf.sprintf
                     "%d folds place %s onto %s and %s onto %s; add 'toward \
                      .x'"
                     (List.length creases) (pstr p) (lstr d) (pstr q) (lstr e))
            | Some xo ->
                let xt = table_of xo in
                (* nearest landing of the first point p, exact squared distance *)
                let dist2 (c : Geom.line) =
                  let im = Geom.reflect_point c pp in
                  let ex = Num.sub im.Geom.x xt.Geom.x
                  and ey = Num.sub im.Geom.y xt.Geom.y in
                  Num.add (Num.mul ex ex) (Num.mul ey ey)
                in
                let best =
                  List.fold_left
                    (fun acc c ->
                      match acc with
                      | None -> Some c
                      | Some b ->
                          if Num.compare (dist2 c) (dist2 b) < 0 then Some c
                          else acc)
                    None creases
                in
                match best with
                | Some c -> Axis (c, "axiom7", base @ [ pstr xo ])
                | None -> assert false))
  in
  let run_fold_checked ~(span : Error.span) ~(axis : Geom.line)
      ~(fs : Ast.fold_spec) ~(implied : Ast.point_operand option)
      ~(side_override : int option) ~(crease_id : int)
      ~(prov : State.provenance option)
      ~(check : ((int -> bool) -> unit) option) : unit =
    (* [side_override] fixes the moving side (axiom-5 derived direction), so the
       anchor is only needed to scope an `up to` range *)
    let anchor_arg =
      match (fs.Ast.moving, implied) with
      | Some fa, _ -> Some fa
      | None, Some p -> Some (Ast.FlapPoint p)
      | None, None -> None
    in
    let move_side =
      match side_override with
      | Some s -> s
      | None -> (
          match anchor_arg with
          | Some fa -> side_of_flap_arg axis fa span
          | None ->
              Error.fail span "this fold needs `moving .p` to choose the side")
    in
    let valley = fs.Ast.direction = Ast.Valley in
    match fs.Ast.up_to with
    | None ->
        (match check with
        | Some k ->
            (* default scope: a face moves iff it has a piece on move_side *)
            let st = !(ctx.state) in
            k (fun fi ->
                Array.length
                  (Geom.clip_convex_halfplane axis move_side
                     (Fold_state.table_polygon st fi))
                >= 3)
        | None -> ());
        ctx.state :=
          Fold_state.fold_with_records !(ctx.state) ~axis ~move_side ~valley
            ~crease_id ~prov
    | Some tgt -> (
        let anchor =
          match anchor_arg with
          | Some fa ->
              let st = !(ctx.state) in
              let cluster = resolve_flap_cluster fa span in
              (match
                 List.find_opt
                   (fun f ->
                     Array.length
                       (Geom.clip_convex_halfplane axis move_side
                          (Fold_state.table_polygon st f))
                     >= 3)
                   cluster
               with
              | Some f -> f
              | None -> List.hd cluster)
          | None ->
              Error.fail span "`up to` needs `moving` to anchor the moving flaps"
        in
        let target = target_of tgt span in
        match
          Fold_state.select_scope !(ctx.state) ~axis ~move_side ~valley ~anchor
            ~target
        with
        | Error msg -> Error.fail span msg
        | Ok moving_parents ->
            (match check with
            | Some k -> k (fun fi -> moving_parents.(fi))
            | None -> ());
            ctx.state :=
              Fold_state.fold_with_records !(ctx.state) ~moving_parents ~axis
                ~move_side ~valley ~crease_id ~prov)
  in
  let run_fold ~(span : Error.span) ~(axis : Geom.line) ~(fs : Ast.fold_spec)
      ~(implied : Ast.point_operand option) ~(side_override : int option)
      ~(crease_id : int) ~(prov : State.provenance option) : unit =
    run_fold_checked ~span ~axis ~fs ~implied ~side_override ~crease_id ~prov
      ~check:None
  in
  (* ---- axiom-5 bisector selection (direction + paper incidence) ---- *)
  (* l1's swinging material as table-space segments *)
  let ax5_material (p : ax5_pending) : (Geom.point * Geom.point) list =
    let of_material cid =
      List.map
        (fun (s : Fold_state.crease_segment) -> (s.Fold_state.ta, s.Fold_state.tb))
        (Fold_state.crease_segments !(ctx.state) cid)
    in
    match p.l1_op with
    | Ast.LNamed cr -> (
        match lookup_crease ctx cr with
        | Material (cid, _) -> of_material cid
        | Frozen _ -> Fold_state.line_material_segments !(ctx.state) p.la)
    | Ast.LMember (iname, mem, mspan) -> (
        let inst = lookup_instance ctx iname mspan in
        match Hashtbl.find_opt inst.ilines mem with
        | Some (Material (cid, _)) -> of_material cid
        | Some (Frozen _) -> Fold_state.line_material_segments !(ctx.state) p.la
        | None ->
            Error.fail mspan
              (Printf.sprintf "instance $%s has no line member %s" iname mem))
    | Ast.LAt (cr, sels, aspan) -> (
        let _cid, matches = at_matches cr sels aspan in
        match matches with
        | [ s ] -> [ (s.Fold_state.ta, s.Fold_state.tb) ]
        | [] ->
            Error.fail aspan
              (Printf.sprintf "no segment of --%s matches %s" cr.Ast.cname
                 (selstr sels))
        | many ->
            Error.fail aspan
              (Printf.sprintf
                 "--%s at %s is ambiguous: %d segments match; add a selector"
                 cr.Ast.cname (selstr sels) (List.length many)))
    | Ast.LThrough _ -> Fold_state.line_material_segments !(ctx.state) p.la
  in
  (* viability core (shared by bind and fold): one material endpoint strictly on
     side [s] of candidate [b] is a representative of the swinging half; its
     image under reflection lands on [xside] of la iff the fold moves that half
     toward the target. The image is never clipped — a sign suffices. *)
  let swing_rep mat (b : Geom.line) (s : int) : Geom.point option =
    List.find_map
      (fun (u, v) ->
        if Geom.side_of_line b u = s then Some u
        else if Geom.side_of_line b v = s then Some v
        else None)
      mat
  in
  let viable ~(la : Geom.line) ~(xside : int) mat (b : Geom.line) (s : int) : bool
      =
    match swing_rep mat b s with
    | None -> false
    | Some q -> Geom.side_of_line la (Geom.reflect_point b q) = xside
  in
  (* paper-incidence filter for omitted `toward`: keep only bisectors that crease
     the sheet *)
  let ax5_filter (p : ax5_pending) : Geom.line list =
    let b1, b2 = p.cands in
    List.filter (Fold_state.line_cuts_paper !(ctx.state)) [ b1; b2 ]
  in
  let e2 (p : ax5_pending) =
    Printf.sprintf
      "map %s onto %s is ambiguous: both bisectors land on the paper; add \
       `toward .p` to pick the direction"
      p.l1_str p.l2_str
  in
  let e3 (p : ax5_pending) =
    Printf.sprintf
      "map %s onto %s: neither bisector lands on the paper — no fold to make"
      p.l1_str p.l2_str
  in
  let e5_head (p : ax5_pending) (x : string) =
    Printf.sprintf
      "map %s onto %s toward %s is ambiguous: %s straddles the crossing, so \
       both bisectors move material toward %s"
      p.l1_str p.l2_str x p.l1_str x
  in
  let select_axiom5_bind (span : Error.span) (p : ax5_pending) : Geom.line =
    let b1, b2 = p.cands in
    match p.toward with
    | None -> (
        match ax5_filter p with
        | [ b ] -> b
        | [ _; _ ] -> Error.fail span (e2 p)
        | _ -> Error.fail span (e3 p))
    | Some x ->
        let xside = Geom.side_of_line p.la x in
        let mat = ax5_material p in
        let xs = Option.get p.toward_str in
        let viable_c b = viable ~la:p.la ~xside mat b 1 || viable ~la:p.la ~xside mat b (-1) in
        (match List.filter viable_c [ b1; b2 ] with
        | [ b ] -> b
        | [] ->
            Error.fail span
              (Printf.sprintf "no fold of %s onto %s moves its material toward %s"
                 p.l1_str p.l2_str xs)
        | _ ->
            Error.fail span
              (e5_head p xs
              ^ Printf.sprintf "; select the swinging segment of %s with `at`"
                  p.l1_str))
  in
  (* returns the chosen axis + an optional move-side override (Some when the
     direction is derived, not read off an explicit `moving`) *)
  let select_axiom5_fold (span : Error.span) (p : ax5_pending)
      ~(fs : Ast.fold_spec) : Geom.line * int option =
    let b1, b2 = p.cands in
    match p.toward with
    | None -> (
        let b =
          match ax5_filter p with
          | [ b ] -> b
          | [ _; _ ] -> Error.fail span (e2 p)
          | _ -> Error.fail span (e3 p)
        in
        match fs.Ast.moving with
        | Some _ -> (b, None) (* explicit moving: side read off the anchor *)
        | None ->
            (* implied moving: l1's material swings; the side it sits on decides *)
            let mat = ax5_material p in
            if mat = [] then
              Error.fail span
                (Printf.sprintf "%s has no material on the paper to fold" p.l1_str);
            let on s = swing_rep mat b s <> None in
            (match (on 1, on (-1)) with
            | true, false -> (b, Some 1)
            | false, true -> (b, Some (-1))
            | true, true ->
                Error.fail span
                  (Printf.sprintf
                     "%s straddles the fold line; add `moving` to pick the \
                      swinging flap"
                     p.l1_str)
            | false, false ->
                Error.fail span
                  (Printf.sprintf "%s has no material on the paper to fold"
                     p.l1_str)))
    | Some x ->
        let xside = Geom.side_of_line p.la x in
        let mat = ax5_material p in
        let xs = Option.get p.toward_str in
        if mat = [] then
          Error.fail span
            (Printf.sprintf "%s has no material on the paper to fold" p.l1_str);
        (match fs.Ast.moving with
        | None ->
            (* geometry guarantees ≤1 viable side per candidate *)
            let cand_side b =
              if viable ~la:p.la ~xside mat b 1 then Some 1
              else if viable ~la:p.la ~xside mat b (-1) then Some (-1)
              else None
            in
            let viables =
              List.filter_map
                (fun b -> Option.map (fun s -> (b, s)) (cand_side b))
                [ b1; b2 ]
            in
            (match viables with
            | [ (b, s) ] -> (b, Some s)
            | [] ->
                Error.fail span
                  (Printf.sprintf
                     "no fold of %s onto %s moves its material toward %s"
                     p.l1_str p.l2_str xs)
            | _ ->
                Error.fail span
                  (e5_head p xs ^ "; add `moving` to pick the swinging flap"))
        | Some fa ->
            (* the anchor's side of each candidate names the swinging half; a
               candidate is viable iff that half moves toward x. On-axis /
               straddling anchors just reject the candidate. *)
            let viable_c b =
              match side_of_flap_arg_res b fa span with
              | Ok s -> viable ~la:p.la ~xside mat b s
              | Error _ -> false
            in
            (match List.filter viable_c [ b1; b2 ] with
            | [ b ] -> (b, None) (* side resolved normally via the anchor *)
            | [] ->
                Error.fail span
                  (Printf.sprintf "no fold of %s onto %s moves %s toward %s"
                     p.l1_str p.l2_str (fstr fa) xs)
            | _ ->
                Error.fail span
                  (Printf.sprintf
                     "map %s onto %s toward %s is ambiguous even with `moving \
                      %s`: it lies in both swinging flaps; anchor with a point \
                      in only one flap"
                     p.l1_str p.l2_str xs (fstr fa))))
  in
  let rec eval_stmt (stmt : Ast.stmt) =
    match stmt with
    | Ast.Crease (name_opt, ax, fold_opt, span) -> (
        let cid = Fold_state.fresh_crease_id () in
        let prov_name =
          match name_opt with
          | Some n when not (is_temp n) -> (
              match ctx.name_ctx with
              | Root -> Some n
              | InInstance i -> Some (i ^ "." ^ n)
              | Anon -> None)
          | _ -> None
        in
        (* axiom 5 defers bisector choice to the fold state (direction / paper
           incidence); every other axiom resolves its axis up front *)
        let axis, axiom, sources, side_override =
          match axis_of span ax with
          | Axis (axis, axiom, sources) -> (axis, axiom, sources, None)
          | Ax5 p ->
              let axis, so =
                match fold_opt with
                | None -> (select_axiom5_bind span p, None)
                | Some fs -> select_axiom5_fold span p ~fs
              in
              (axis, "axiom5", p.sources, so)
        in
        let prov : State.provenance option =
          Some { State.axiom; sources; span; name = prov_name; step = ctx.panel }
        in
        (match fold_opt with
        | None -> ctx.state := Fold_state.subdivide !(ctx.state) axis ~crease_id:cid ~prov
        | Some fs ->
            let implied =
              match ax with
              | Ast.MapPoints (p, _)
              | Ast.MapThrough (p, _, _, _)
              | Ast.MapBoth (p, _, _, _, _) ->
                  Some p
              | _ -> None
            in
            run_fold ~span ~axis ~fs ~implied ~side_override ~crease_id:cid ~prov);
        match name_opt with
        | Some n -> bind_crease ctx n span (Material (cid, axis))
        | None -> ())
    | Ast.Point (n, Ast.Cross (l1, l2), span) ->
        bind_point ctx n span (resolve_point (Ast.PCross (l1, l2, span)))
    | Ast.Flip _ -> ctx.state := Fold_state.flip !(ctx.state)
    | Ast.Def (name, params, body, span) ->
        if Hashtbl.mem ctx.defs name then
          Error.fail span (Printf.sprintf "def %s is already defined" name);
        let seen = Hashtbl.create 4 in
        List.iter
          (fun (p : Ast.param) ->
            if Hashtbl.mem seen p.Ast.pname then
              Error.fail p.Ast.pspan
                (Printf.sprintf "duplicate parameter %s" p.Ast.pname);
            Hashtbl.replace seen p.Ast.pname ())
          params;
        Hashtbl.replace ctx.defs name (ctx.next_def_idx, params, body);
        ctx.next_def_idx <- ctx.next_def_idx + 1
    | Ast.Apply (bind_opt, defname, args, span) ->
        let def_idx, params, body =
          match Hashtbl.find_opt ctx.defs defname with
          | Some d -> d
          | None -> Error.fail span (Printf.sprintf "undefined def %s" defname)
        in
        (match ctx.cur_def_idx with
        | Some k when def_idx >= k ->
            Error.fail span
              (Printf.sprintf "def %s is not defined before this body" defname)
        | _ -> ());
        if List.length args <> List.length params then
          Error.fail span
            (Printf.sprintf "def %s takes %d argument(s), got %d" defname
               (List.length params) (List.length args));
        (* resolve args in the CALLER scope, then swap in the closed scope *)
        let body_scope = make_scope () in
        List.iter2
          (fun (p : Ast.param) (a : Ast.arg) ->
            match (p.Ast.pkind, a) with
            | `Point, Ast.APoint po ->
                Hashtbl.replace body_scope.points p.Ast.pname (resolve_point po)
            | `Line, Ast.ALine lo ->
                (* a named crease argument stays material inside the body
                   (cross needs its marks); only constructed lines freeze *)
                let cv =
                  match lo with
                  | Ast.LNamed cr -> lookup_crease ctx cr
                  | Ast.LMember (iname, mem, mspan) -> (
                      let inst = lookup_instance ctx iname mspan in
                      match Hashtbl.find_opt inst.ilines mem with
                      | Some cv -> cv
                      | None ->
                          Error.fail mspan
                            (Printf.sprintf "instance $%s has no line member %s"
                               iname mem))
                  | Ast.LThrough _ | Ast.LAt _ -> Frozen (resolve_line lo)
                in
                Hashtbl.replace body_scope.lines p.Ast.pname cv
            | `Point, Ast.ALine _ ->
                Error.fail span
                  (Printf.sprintf "parameter .%s of %s needs a point argument"
                     p.Ast.pname defname)
            | `Line, Ast.APoint _ ->
                Error.fail span
                  (Printf.sprintf "parameter --%s of %s needs a line argument"
                     p.Ast.pname defname))
          params args;
        let saved_scopes = ctx.scopes
        and saved_nctx = ctx.name_ctx
        and saved_def_idx = ctx.cur_def_idx in
        ctx.scopes <- [ body_scope ];
        ctx.cur_def_idx <- Some def_idx;
        (ctx.name_ctx <-
           (match (bind_opt, saved_nctx) with
           | None, _ -> Anon
           | Some i, _ when is_temp i -> Anon
           | Some _, Anon -> Anon
           | Some i, Root -> InInstance i
           | Some i, InInstance outer -> InInstance (outer ^ "." ^ i)));
        List.iter eval_stmt body;
        ctx.scopes <- saved_scopes;
        ctx.name_ctx <- saved_nctx;
        ctx.cur_def_idx <- saved_def_idx;
        (match bind_opt with
        | None -> ()
        | Some iname ->
            let cur = List.hd ctx.scopes in
            if (not (is_temp iname)) && Hashtbl.mem cur.instances iname then
              Error.fail span
                (Printf.sprintf
                   "instance $%s is already bound; only _-prefixed temps rebind"
                   iname);
            let inst = { ipoints = Hashtbl.create 8; ilines = Hashtbl.create 8 } in
            Hashtbl.iter
              (fun k v -> if not (is_temp k) then Hashtbl.replace inst.ipoints k v)
              body_scope.points;
            Hashtbl.iter
              (fun k v -> if not (is_temp k) then Hashtbl.replace inst.ilines k v)
              body_scope.lines;
            Hashtbl.replace cur.instances iname inst)
    | Ast.Export (entries_opt, iname, span) ->
        let inst = lookup_instance ctx iname span in
        let cur = List.hd ctx.scopes in
        let land_name ~(kind : [ `Point | `Line ]) ~(shadow : bool)
            ~(espan : Error.span) (src : string) (target : string) =
          let target_exists, sigil =
            match kind with
            | `Point -> (Hashtbl.mem cur.points target, ".")
            | `Line -> (Hashtbl.mem cur.lines target, "--")
          in
          (if not (is_temp target) then
             match (target_exists, shadow) with
             | true, false ->
                 Error.fail espan
                   (Printf.sprintf "%s%s exists; use ! to shadow" sigil target)
             | false, true ->
                 Error.fail espan
                   (Printf.sprintf "nothing to shadow with %s%s; remove !" sigil
                      target)
             | _ -> ());
          match kind with
          | `Point -> (
              match Hashtbl.find_opt inst.ipoints src with
              | Some v -> Hashtbl.replace cur.points target v
              | None ->
                  Error.fail espan
                    (Printf.sprintf "instance $%s has no point member %s" iname src))
          | `Line -> (
              match Hashtbl.find_opt inst.ilines src with
              | Some v -> Hashtbl.replace cur.lines target v
              | None ->
                  Error.fail espan
                    (Printf.sprintf "instance $%s has no line member %s" iname src))
        in
        (match entries_opt with
        | Some entries ->
            List.iter
              (fun (e : Ast.export_entry) ->
                land_name ~kind:e.Ast.ekind ~shadow:e.Ast.eshadow ~espan:e.Ast.espan
                  e.Ast.esrc
                  (Option.value e.Ast.erename ~default:e.Ast.esrc))
              entries
        | None ->
            Hashtbl.iter
              (fun k _ -> land_name ~kind:`Point ~shadow:false ~espan:span k k)
              inst.ipoints;
            Hashtbl.iter
              (fun k _ -> land_name ~kind:`Line ~shadow:false ~espan:span k k)
              inst.ilines)
    | Ast.StepMark (id, span) ->
        if Hashtbl.mem ctx.panels id then
          Error.fail span (Printf.sprintf "step id %s is already used" id);
        Hashtbl.replace ctx.panels id ();
        ctx.frames_rev <- (ctx.panel, !(ctx.state)) :: ctx.frames_rev;
        ctx.panel <- Some id
    | Ast.FoldAlong (lo, fs, span) ->
        let cid =
          match lo with
          | Ast.LNamed cr | Ast.LAt (cr, _, _) -> material_cid cr
          | _ ->
              Error.fail span
                "@fold folds along an existing crease; give a crease name, \
                 e.g. @fold --d or @fold --d at .p"
        in
        let axis = resolve_line lo in
        (* per-flap material check: every segment of the bundle carried by a
           moving flap must lie on the axis — a crease bent under the moving
           set cannot fold (#28) *)
        let check_straight (moves : int -> bool) =
          List.iter
            (fun (s : Fold_state.crease_segment) ->
              let l, r = s.Fold_state.faces in
              if
                (moves l || (r >= 0 && moves r))
                && (Geom.side_of_line axis s.Fold_state.ta <> 0
                   || Geom.side_of_line axis s.Fold_state.tb <> 0)
              then
                Error.fail span
                  "the crease is bent under the moving flaps; select a \
                   straight segment with `at` or move fewer flaps")
            (Fold_state.crease_segments !(ctx.state) cid)
        in
        let prov : State.provenance option =
          Some
            {
              State.axiom = "fold";
              sources = [ lstr lo ];
              span;
              name = None;
              step = ctx.panel;
            }
        in
        run_fold_checked ~span ~axis ~fs ~implied:None ~side_override:None
          ~crease_id:cid ~prov ~check:(Some check_straight)
    | Ast.Collapse (elems, overs, standing_opt, span) ->
        (match standing_opt with
        | Some _ -> Error.fail span "standing folds are not yet supported"
        | None -> ());
        (* each element must resolve to exactly ONE material segment — same
           machinery as @fold's material resolution *)
        let resolve_elem (el : Ast.collapse_elem) : Collapse.elem =
          let fail_not_material () =
            Error.fail span
              (Printf.sprintf
                 "collapse folds along existing creases; %s is not a \
                  material crease" (lstr el.Ast.cline))
          in
          match el.Ast.cline with
          | Ast.LAt (cr, sels, aspan) -> (
              match at_matches cr sels aspan with
              | cid, [ s ] ->
                  {
                    Collapse.cid;
                    ea = s.Fold_state.ta;
                    eb = s.Fold_state.tb;
                    valley = el.Ast.cdir = Ast.Valley;
                  }
              | _, [] ->
                  Error.fail aspan
                    (Printf.sprintf "no segment of --%s matches %s"
                       cr.Ast.cname (selstr sels))
              | _, many ->
                  Error.fail aspan
                    (Printf.sprintf
                       "--%s at %s is ambiguous: %d segments match; add a \
                        selector"
                       cr.Ast.cname (selstr sels) (List.length many)))
          | Ast.LNamed cr -> (
              let cid = material_cid cr in
              match Fold_state.crease_segments !(ctx.state) cid with
              | [ s ] ->
                  {
                    Collapse.cid;
                    ea = s.Fold_state.ta;
                    eb = s.Fold_state.tb;
                    valley = el.Ast.cdir = Ast.Valley;
                  }
              | [] ->
                  Error.fail span
                    (Printf.sprintf "--%s has no material segment"
                       cr.Ast.cname)
              | segs ->
                  Error.fail span
                    (Printf.sprintf
                       "--%s has %d segments; select one with `at`"
                       cr.Ast.cname (List.length segs)))
          | _ -> fail_not_material ()
        in
        let es = List.map resolve_elem elems in
        (* all-layers congruence guard: every layer under the collapse region
           folds as one unit (spec §Semantics: "Material / layers"). For each
           element's infinite table-space line, any face it actually cuts
           (not just grazes an edge of) must already carry THAT element's
           crease lying on that same line — otherwise the bundle is bent or
           missing on some layer under the vertex and collapsing it as one
           unit is unsound. On today's all-layer precreases this never fires
           (every face the line touches borders an edge of the same cid on
           that line); it guards future partial-crease states. *)
        List.iter
          (fun (el : Collapse.elem) ->
            let st = !(ctx.state) in
            let line = Geom.line_through el.Collapse.ea el.Collapse.eb in
            let aligned_faces =
              Fold_state.crease_segments st el.Collapse.cid
              |> List.concat_map (fun (s : Fold_state.crease_segment) ->
                     if
                       Geom.side_of_line line s.Fold_state.ta = 0
                       && Geom.side_of_line line s.Fold_state.tb = 0
                     then
                       let l, r = s.Fold_state.faces in
                       l :: (if r >= 0 then [ r ] else [])
                     else [])
            in
            Array.iteri
              (fun i _ ->
                if
                  Geom.line_cuts_polygon line (Fold_state.table_polygon_ccw st i)
                  && not (List.mem i aligned_faces)
                then Error.fail span "collapse through unaligned layers")
              st.Fold_state.faces)
          es;
        let over =
          List.map
            (fun (u, l) -> (resolve_sector_face u span, resolve_sector_face l span))
            overs
        in
        (match Collapse.collapse !(ctx.state) es ~over with
        | Ok st -> ctx.state := st
        | Error msg -> Error.fail span msg)
  in
  List.iter eval_stmt prog;
  let named_points =
    Hashtbl.fold
      (fun k v acc -> if is_temp k then acc else (k, v) :: acc)
      root_scope.points []
  in
  let named_lines =
    Hashtbl.fold
      (fun k cv acc ->
        if is_temp k then acc
        else
          match cv with
          | Frozen l -> (k, l) :: acc
          | Material (_, l_orig) -> (k, l_orig) :: acc)
      root_scope.lines []
  in
  ctx.frames_rev <- (ctx.panel, !(ctx.state)) :: ctx.frames_rev;
  let frames = List.rev ctx.frames_rev in
  { state = !(ctx.state); named_points; named_lines; frames }
