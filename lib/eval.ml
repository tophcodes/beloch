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
  named_points : (string * Geom.point * int) list;
      (* [int] is the 0-based creation step (index into [frames] at bind
         time); see [scope.point_steps]/[scope.line_steps] *)
  named_lines : (string * Geom.line * int) list;
  frames : (string option * Fold_state.t * Error.span option) list;
}

(* ---- Scope-stack context ---- *)

type crease_val =
  | Material of int * Geom.line
  | Mark of int * Geom.line
      (* a materialized construction line backed by the mark layer: meetable
         by `*` (its chords live in Fold_state.marks), never subdividing the
         working arrangement. [int] is the mark's mcrease_id. *)
  | Frozen of Geom.line
  | Bundle of Ast.line_operand
      (* a named crease bundle (--x = --l & .c | [--a --b]); resolves lazily as
         its expression, so the name behaves exactly like inlining it *)
  | Edge of string * string
      (* a paper boundary edge, named by its two corners; resolves live (the
         edge moves under folding) through the current corner positions *)

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
  ipoint_steps : (string, int) Hashtbl.t;
  iline_steps : (string, int) Hashtbl.t;
      (* creation step of each member, copied from the def body's own
         [scope.point_steps]/[scope.line_steps] at apply-time; see those.
         Points and lines are separate namespaces (distinct sigils `.`/`--`),
         so a point and a line may share a stem — kept in separate tables
         rather than one shared-key table so they can't clobber each
         other's step. *)
}

type scope = {
  points    : (string, Geom.point) Hashtbl.t;
  lines     : (string, crease_val) Hashtbl.t;
  instances : (string, instance) Hashtbl.t;
  point_steps : (string, int) Hashtbl.t;
  line_steps  : (string, int) Hashtbl.t;
      (* creation step of each name bound in points/lines (respectively)
         within THIS scope, recorded at bind time by [bind_point]/
         [bind_crease] as [List.length ctx.frames_rev]. Scoped per-entry so
         it saves/restores across `apply` exactly like points/lines do — a
         def body's own bindings never clobber an outer scope's already-
         recorded step for the same name. Kept as two tables (not one keyed
         by bare name) because points and lines are separate namespaces: a
         point and a line may share a stem (`.m` / `--m`), and a single
         shared-key table would let one clobber the other's step. *)
}

let make_scope () = {
  points      = Hashtbl.create 8;
  lines       = Hashtbl.create 8;
  instances   = Hashtbl.create 4;
  point_steps = Hashtbl.create 8;
  line_steps  = Hashtbl.create 8;
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
  mutable frames_rev : (string option * Fold_state.t * Error.span option) list;
  mutable pending : bool;
      (* true when the current state hasn't been captured in a frame yet;
         drives the conditional final push (see eval_folded) *)
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

let intent_of (dir : Ast.direction) : Fold_state.assign =
  match dir with Ast.Valley -> Fold_state.V | Ast.Mountain -> Fold_state.M

(* Shared failure text for every "points must land on exactly one flap/face"
   lookup (FByPoints resolution): callers narrow their own success variant
   (`Face of int, `Cluster of int list, ...) to `Found and pass through their
   `Zero/`Ambiguous as-is, so the 0-match/multi-match wording lives here once
   instead of being copied at each call site. *)
let flap_lookup_result (span : Error.span)
    (r : [ `Found of 'a | `Zero | `Ambiguous ]) : 'a =
  match r with
  | `Found v -> v
  | `Zero -> Error.fail span "those points aren't all on one flap"
  | `Ambiguous -> Error.fail span "ambiguous flap; add another point"

let bind_point (ctx : ctx) (name : string) (span : Error.span) (p : Geom.point)
    =
  let s = List.hd ctx.scopes in
  if (not (is_temp name)) && Hashtbl.mem s.points name then
    Error.fail span
      (Printf.sprintf "point .%s is already bound; only _-prefixed temps rebind"
         name);
  Hashtbl.replace s.points name p;
  Hashtbl.replace s.point_steps name (List.length ctx.frames_rev)

let bind_crease (ctx : ctx) (name : string) (span : Error.span) (cv : crease_val) =
  let s = List.hd ctx.scopes in
  if (not (is_temp name)) && Hashtbl.mem s.lines name then
    Error.fail span
      (Printf.sprintf "crease --%s is already bound; only _-prefixed temps rebind"
         name);
  Hashtbl.replace s.lines name cv;
  Hashtbl.replace s.line_steps name (List.length ctx.frames_rev)

(* `mark --d` on an already-bound name (e.g. a pure `--d = <motion>` value)
   promotes its binding in place to the freshly materialised crease, so a
   later `fold --d` can find it. Not a user-facing rebind (no dup check): the
   name already resolved to [lo], we're just upgrading what it points to. *)
let promote_crease (ctx : ctx) (name : string) (cv : crease_val) =
  match List.find_opt (fun s -> Hashtbl.mem s.lines name) ctx.scopes with
  | Some s -> Hashtbl.replace s.lines name cv
  | None -> ()


(* ---- Evaluator ---- *)

let eval_folded (prog : Ast.program) : folded =
  Fold_state.reset_ids ();
  let root_scope = make_scope () in
  List.iter (fun (n, p) -> Hashtbl.replace root_scope.points n p) corners;
  List.iter
    (fun (n, a, b) -> Hashtbl.replace root_scope.lines n (Edge (a, b)))
    [ ("ab", "a", "b"); ("bc", "b", "c"); ("cd", "c", "d"); ("da", "d", "a") ];
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
    pending = true;
  } in
  let push_frame (span : Error.span option) =
    ctx.frames_rev <- (ctx.panel, !(ctx.state), span) :: ctx.frames_rev;
    ctx.pending <- false
  in
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
  in
  let corner_point (n : string) : Geom.point =
    match List.assoc_opt n corners with
    | Some p -> p
    | None -> assert false (* Edge is only ever built from a,b,c,d *)
  in
  let materialize_crease ~(name : string) (span : Error.span) (cv : crease_val) :
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
        | `Bent ->
            Error.fail span
              (Printf.sprintf
                 "--%s is bent by a fold; select a segment with `at`, e.g. \
                  --%s at #(.a .b .c)" name name))
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
                  segment with `at`, e.g. --%s at #(.a .b .c)"
                 name name))
  in
  (* the unique FACE (the fine ADR-0014 partition, not a flap/coplanar
     cluster) whose paper polygon contains every point in [pts]. Unlike
     `moving`/`up to`'s flap operand (ADR 0017: coarsened to a coplanar
     cluster so a still-flat neighbourhood is one flap), `at`'s `#(...)`
     incidence check and `collapse`'s `over`/`under` sector clause both need
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
    | Ast.PSelect (los, span) -> select_point los span
  and resolve_line (lo : Ast.line_operand) : Geom.line =
    match lo with
    | Ast.LNamed cr -> (
        match lookup_crease ctx cr with
        | Bundle expr -> resolve_line expr
        | cv -> materialize_crease ~name:cr.Ast.cname cr.Ast.cspan cv)
    | (Ast.LFilter _ | Ast.LUnion _) as b ->
        let s = coerce_one_segment b in
        Geom.line_through s.Fold_state.ta s.Fold_state.tb
    | Ast.LSelect (sels, span) -> select_line sels span
  and resolve_paper_line (lo : Ast.line_operand) :
      Geom.line * (Geom.point * Geom.point) list option =
    match lo with
    | Ast.LNamed cr -> (
        match lookup_crease ctx cr with
        | Bundle expr -> resolve_paper_line expr
        | cv -> paper_line_of_crease ~name:cr.Ast.cname cr.Ast.cspan cv)
    | (Ast.LFilter _ | Ast.LUnion _) as b ->
        let s = coerce_one_segment b in
        ( Geom.line_through s.Fold_state.pa s.Fold_state.pb,
          Some [ (s.Fold_state.pa, s.Fold_state.pb) ] )
    | Ast.LSelect (sels, span) ->
        let _, _, pl, pm = select_cand sels span in
        (pl, pm)
  and material_cid (cr : Ast.crease_ref) : int =
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
                 span = cr.Ast.cspan; name = None; step = ctx.panel }
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
  and seg_incident (sel : Ast.selector) (s : Fold_state.crease_segment) : bool =
    match sel with
    | Ast.SelPoint po -> point_on_seg (resolve_point po) s
    | Ast.SelLine lo -> (
        match Geom.intersection (fst (resolve_paper_line lo)) (seg_line s) with
        | Some ip -> point_on_seg ip s
        | None -> false)
    | Ast.SelFlap (Ast.FByPoints (pts, fspan)) ->
        flap_lookup_result fspan
          (match face_of_points (List.map resolve_point pts) with
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
  and select_candidates () :
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
  and cand_incident (sel : Ast.selector) (_l, (pa, pb), _pl, _pm) : bool =
    let on t = Num.compare t Num.zero >= 0 && Num.compare t Num.one <= 0 in
    match sel with
    | Ast.SelPoint po ->
        let pp = resolve_point po in
        Geom.side_of_line _pl pp = 0 && on (Geom.seg_param (pa, pb) pp)
    | Ast.SelLine lo -> (
        match Geom.intersection (fst (resolve_paper_line lo)) _pl with
        | Some ip -> on (Geom.seg_param (pa, pb) ip)
        | None -> false)
    | Ast.SelFlap (Ast.FByPoints (_, fspan)) ->
        Error.fail fspan
          "a flap is not a valid --[…] constraint; use & to filter a crease"
  and select_cand (sels : Ast.selector list) (span : Error.span) :
      Geom.line * (Geom.point * Geom.point)
      * Geom.line * (Geom.point * Geom.point) list option =
    match
      List.filter
        (fun c -> List.for_all (fun s -> cand_incident s c) sels)
        (select_candidates ())
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
  and select_line (sels : Ast.selector list) (span : Error.span) : Geom.line =
    let l, _, _, _ = select_cand sels span in
    l
  and select_point (los : Ast.line_operand list) (span : Error.span) : Geom.point =
    match los with
    | [] | [ _ ] -> Error.fail span ".[…] needs at least two lines to meet"
    | _ ->
        let resolved = List.map (fun lo -> (lo, resolve_paper_line lo)) los in
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
  and bundle_segments (lo : Ast.line_operand) :
      int option * Fold_state.crease_segment list =
    match lo with
    | Ast.LNamed cr -> (
        match lookup_crease ctx cr with
        | Bundle expr -> bundle_segments expr
        | Edge (a, b) ->
            ( None,
              Fold_state.edge_boundary_segments !(ctx.state)
                (Geom.line_through (corner_point a) (corner_point b)) )
        | _ ->
            let cid = material_cid cr in
            (Some cid, Fold_state.crease_segments !(ctx.state) cid))
    | Ast.LFilter (b, elt, _) ->
        let cid, segs = bundle_segments b in
        let sel, keep =
          match elt with Ast.Keep s -> (s, true) | Ast.Drop s -> (s, false)
        in
        (cid, List.filter (fun s -> seg_incident sel s = keep) segs)
    | Ast.LUnion (los, _) ->
        (None, List.concat_map (fun l -> snd (bundle_segments l)) los)
    | Ast.LSelect _ ->
        Error.fail (span_of_line lo)
          "a --[…] result is a single line, not a segment bundle; filter a \
           named crease with & instead"
  and coerce_one_segment (lo : Ast.line_operand) : Fold_state.crease_segment =
    match snd (bundle_segments lo) with
    | [ s ] -> s
    | [] ->
        Error.fail (span_of_line lo)
          (Printf.sprintf "no segment of %s matches" (lstr lo))
    | many ->
        Error.fail (span_of_line lo)
          (Printf.sprintf "%s is ambiguous: %d segments match; add a selector"
             (lstr lo) (List.length many))
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
     faces (ADR 0017: two faces joined only by a still-unfolded F edge are the
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
    | Ast.FlapSpec (Ast.FByPoints (pts, fspan)) ->
        flap_lookup_result fspan
          (match
             Fold_state.flap_of_points !(ctx.state) (List.map resolve_point pts)
           with
          | `Cluster fs -> `Found fs
          | (`Zero | `Ambiguous) as bad -> bad)
    | Ast.FlapLine lo -> (
        let candidates =
          match lo with
          | Ast.LNamed cr ->
              let cid = material_cid cr in
              Fold_state.crease_segments !(ctx.state) cid
              |> List.concat_map (fun (s : Fold_state.crease_segment) ->
                     let l, r = s.Fold_state.faces in
                     l :: (if r >= 0 then [ r ] else []))
              |> List.sort_uniq compare
          | (Ast.LFilter _ | Ast.LUnion _) as b ->
              snd (bundle_segments b)
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
  (* face-precise resolution for collapse's `over`/`under`: a sector around a
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
    | Ast.FlapSpec (Ast.FByPoints (pts, fspan)) ->
        flap_lookup_result fspan
          (match face_of_points (List.map resolve_point pts) with
          | `Face fi -> `Found fi
          | (`Zero | `Ambiguous) as bad -> bad)
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
        | (Ast.LFilter _ | Ast.LUnion _) as b ->
            let s = coerce_one_segment b in
            let l, r = s.Fold_state.faces in
            Fold_state.TargetHinged (fun f -> f = l || f = r)
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
            (match
               Fold_state.scoped_fold_hinge_closed !(ctx.state) ~axis
                 ~move_side ~moving_parents
             with
            | Ok () -> ()
            | Error (ta, tb) ->
                Error.fail span
                  (Printf.sprintf
                     "the moving flap is joined to a stationary layer along a \
                      segment ((%g,%g)-(%g,%g)) that is not on the fold axis \
                      — it cannot fold on its own without tearing the paper. \
                      Move those layers too, or fold along a crease on the \
                      axis."
                     (Num.to_float ta.Geom.x) (Num.to_float ta.Geom.y)
                     (Num.to_float tb.Geom.x) (Num.to_float tb.Geom.y)));
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
        | Bundle _ ->
            List.map
              (fun (s : Fold_state.crease_segment) ->
                (s.Fold_state.ta, s.Fold_state.tb))
              (snd (bundle_segments (Ast.LNamed cr)))
        | Edge _ -> Fold_state.line_material_segments !(ctx.state) p.la
        | Mark _ | Frozen _ -> Fold_state.line_material_segments !(ctx.state) p.la)
    | Ast.LSelect _ -> Fold_state.line_material_segments !(ctx.state) p.la
    | (Ast.LFilter _ | Ast.LUnion _) as b ->
        List.map
          (fun (s : Fold_state.crease_segment) ->
            (s.Fold_state.ta, s.Fold_state.tb))
          (snd (bundle_segments b))
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
  (* Resolve a markable to either a fresh motion (axis + provenance + the
     axiom-5 side override / implied-anchor, mirroring the old Crease arm) or
     an existing line to fold/mark along. [fold_opt] is [Some fs] only when
     called from a `fold` statement (axiom-5 direction resolution differs
     between bind/mark and fold). *)
  let resolve_markable (span : Error.span) (name_opt : string option)
      (fold_opt : Ast.fold_spec option) (m : Ast.markable) =
    match m with
    | Ast.MMotion ax ->
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
        let implied =
          match ax with
          | Ast.MapPoints (p, _)
          | Ast.MapThrough (p, _, _, _)
          | Ast.MapBoth (p, _, _, _, _) ->
              Some p
          | _ -> None
        in
        `Fresh (cid, axis, prov, side_override, implied)
    | Ast.MLine lo -> `Existing lo
  in
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
  let resolve_mark_extent (table_axis : Geom.line) (ext : Ast.extent)
      (span : Error.span) :
      [ `Full | `Partial of Fold_state.mark_geom * Geom.point * Geom.line ] =
    let on_axis (po : Ast.point_operand) : Geom.point =
      let p = resolve_point po in
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
           is display-only this slice (Task 6 owns CP-frame emission), so an
           imprecise fallback here is not load-bearing yet. *)
        let st = !(ctx.state) in
        let rec paper_axis_via = function
          | [] -> table_axis
          | fi :: rest -> (
              match
                Fold_state.axis_segment_in_face st.Fold_state.faces.(fi)
                  table_axis
              with
              | Some (p, q) when not (Geom.point_equal p q) ->
                  Geom.line_through p q
              | _ -> paper_axis_via rest)
        in
        `Partial (Fold_state.MPoint pp, pp, paper_axis_via (faces_containing pp))
  in
  (* Behaviour 3: the flap (coplanar cluster, as its face list) a partial
     mark's extent is written onto. An explicit #(...) layer wins (mirrors
     resolve_flap_cluster's FlapSpec branch); otherwise default to the
     carrying flap — the cluster containing the extent's representative
     paper point, erroring if that point sits on a boundary shared by several
     flaps (ambiguous without a #(...) to disambiguate). *)
  let resolve_mark_flap (layer_opt : Ast.flap_operand option)
      (rep : Geom.point) (span : Error.span) : int list =
    match layer_opt with
    | Some (Ast.FByPoints (pts, fspan)) -> (
        match
          Fold_state.flap_of_points !(ctx.state) (List.map resolve_point pts)
        with
        | `Cluster fs -> fs
        | `Zero -> Error.fail fspan "those points aren't all on one flap"
        | `Ambiguous -> Error.fail fspan "ambiguous flap; add another point")
    | None -> (
        match faces_containing rep with
        | [] -> Error.fail span "the mark's extent is not on the paper"
        | faces -> (
            let st = !(ctx.state) in
            let cl = Fold_state.coplanar_clusters st in
            let n = Array.length st.Fold_state.faces in
            match List.sort_uniq compare (List.map (fun f -> cl.(f)) faces) with
            | [ id ] -> List.filter (fun f -> cl.(f) = id) (List.init n Fun.id)
            | ids ->
                Error.fail span
                  (Printf.sprintf
                     "the mark's endpoint lies on a crease shared by %d \
                      flaps; name the flap with #(...)"
                     (List.length ids))))
  in
  let rec eval_stmt (stmt : Ast.stmt) =
    match stmt with
    | Ast.BindBundle (name, expr, span) ->
        bind_crease ctx name span (Bundle expr)
    | Ast.BindLine (n, ax, span) ->
        (* pure value: resolve the axiom to a line, bind Frozen, no subdivide *)
        let axis =
          match axis_of span ax with
          | Axis (axis, _, _) -> axis
          | Ax5 p -> select_axiom5_bind span p
        in
        bind_crease ctx n span (Frozen axis)
    | Ast.Mark (name_opt, m, ext, dir, layer_opt, span) -> (
        let intent = intent_of dir in
        let bind_mark cid line =
          match name_opt with
          | Some n -> bind_crease ctx n span (Mark (cid, line))
          | None -> ()
        in
        let record ~prov cid mgeom paper_axis =
          ctx.state :=
            Fold_state.add_mark !(ctx.state)
              { Fold_state.mgeom; mline = paper_axis; mintent = intent;
                mcrease_id = cid; mprov = prov };
          bind_mark cid paper_axis
        in
        (* A full mark is the whole line clipped to its flap; it records as a
           material chord (never subdivides). Resolve the flap (explicit #(...)
           wins; else the carrying flap of a rep point on the axis), then take
           the extreme endpoints of the per-face paper clips. *)
        let record_full ~prov cid table_axis =
          let st = !(ctx.state) in
          let clips =
            Array.to_list st.Fold_state.faces
            |> List.filter_map (fun (f : Fold_state.face) ->
                   Fold_state.axis_segment_in_face f table_axis)
          in
          let rep =
            match clips with
            | (p, q) :: _ ->
                { Geom.x = Num.div (Num.add p.Geom.x q.Geom.x) (Num.of_int 2);
                  y = Num.div (Num.add p.Geom.y q.Geom.y) (Num.of_int 2) }
            | [] -> Error.fail span "the mark's line does not cross the paper"
          in
          let flap = resolve_mark_flap layer_opt rep span in
          let pts =
            List.filter_map
              (fun fi ->
                Fold_state.axis_segment_in_face st.Fold_state.faces.(fi) table_axis)
              flap
            |> List.concat_map (fun (p, q) -> [ p; q ])
          in
          match Geom.extreme_pair pts with
          | Some (a, b) ->
              record ~prov cid (Fold_state.MSeg (a, b)) (Geom.line_through a b)
          | None -> Error.fail span "the mark's line does not cross its flap"
        in
        (* Behaviour 4: dispatch a partial extent's classification. Under the
           material-layer model NO mark subdivides — CSubdivide (a full chord
           between two boundary points) records exactly like CRecord. Only
           `Ast.Between` can ever yield [CCrossesFold]. *)
        let dispatch_partial ~prov ~cid ~flap ~extent_geom ~paper_axis () =
          match
            Fold_state.classify_mark_extent !(ctx.state) ~flap ~axis:paper_axis
              ~extent_geom
          with
          | Fold_state.CSubdivide (a, b) -> record ~prov cid (Fold_state.MSeg (a, b)) paper_axis
          | Fold_state.CRecord g -> record ~prov cid g paper_axis
          | Fold_state.CCrossesFold _ ->
              let a, b =
                match ext with Ast.Between (a, b) -> (a, b) | _ -> assert false
              in
              Error.fail span
                (Printf.sprintf
                   "the mark's extent from %s to %s crosses a folded crease \
                    (it leaves its flap)"
                   (pstr a) (pstr b))
        in
        match resolve_markable span name_opt None m with
        | `Fresh (cid, table_axis, prov, _side_override, _implied) -> (
            match resolve_mark_extent table_axis ext span with
            | `Full -> record_full ~prov cid table_axis
            | `Partial (extent_geom, rep, paper_axis) ->
                let flap = resolve_mark_flap layer_opt rep span in
                dispatch_partial ~prov ~cid ~flap ~extent_geom ~paper_axis ())
        | `Existing lo ->
            (* mark an already-bound value line: record a material chord. If it
               names a pure value (Frozen), promote its binding to Mark so a
               later `fold --d` can materialize a real crease along it. *)
            let table_axis = resolve_line lo in
            let cid = Fold_state.fresh_crease_id () in
            let promote () =
              match lo with
              | Ast.LNamed cr -> (
                  match lookup_crease ctx cr with
                  | Frozen _ ->
                      promote_crease ctx cr.Ast.cname (Mark (cid, table_axis))
                  | Mark _ | Material _ | Bundle _ | Edge _ -> ())
              | _ -> ()
            in
            (match resolve_mark_extent table_axis ext span with
            | `Full -> record_full ~prov:None cid table_axis
            | `Partial (extent_geom, rep, paper_axis) ->
                let flap = resolve_mark_flap layer_opt rep span in
                dispatch_partial ~prov:None ~cid ~flap ~extent_geom ~paper_axis ());
            promote ())
    | Ast.Fold (name_opt, m, fs, span) -> (
        match resolve_markable span name_opt (Some fs) m with
        | `Fresh (cid, axis, prov, side_override, implied) ->
            run_fold ~span ~axis ~fs ~implied ~side_override ~crease_id:cid ~prov;
            (* push the frame BEFORE binding the name: a first-fold crease's
               creation step must count that fold (step 1), not the
               pre-fold count (step 0) — see scope.line_steps. *)
            push_frame (Some span);
            (match name_opt with
            | Some n -> bind_crease ctx n span (Material (cid, axis))
            | None -> ())
        | `Existing (Ast.LNamed cr)
          when (match lookup_crease ctx cr with Mark _ -> true | _ -> false) ->
            (* fold along a MARK: marks never subdivide, so there is no existing
               crease to fold along — materialize a fresh real crease on the
               mark's line. At emit the coincident mark is superseded by this
               crease. *)
            let mark_cid, mark_line =
              match lookup_crease ctx cr with
              | Mark (c, line) -> (c, line)
              | _ -> assert false
            in
            let axis =
              match Fold_state.mark_axis_current !(ctx.state) mark_cid with
              | `Line l -> l
              | `Empty -> mark_line
              | `Bent ->
                  Error.fail span
                    (Printf.sprintf
                       "--%s is no longer straight after folding; select a \
                        segment with `at`, e.g. --%s at #(.a .b .c)"
                       cr.Ast.cname cr.Ast.cname)
            in
            let cid = Fold_state.fresh_crease_id () in
            let prov : State.provenance option =
              Some { State.axiom = "fold"; sources = [ "--" ^ cr.Ast.cname ];
                     span; name = None; step = ctx.panel }
            in
            run_fold ~span ~axis ~fs ~implied:None ~side_override:None
              ~crease_id:cid ~prov;
            push_frame (Some span);
            (match name_opt with
            | Some n -> bind_crease ctx n span (Material (cid, axis))
            | None -> promote_crease ctx cr.Ast.cname (Material (cid, axis)))
        | `Existing lo ->
            (* fold along an existing material crease (the old FoldAlong path) *)
            let cid =
              match lo with
              | Ast.LNamed cr -> material_cid cr
              | Ast.LFilter _ | Ast.LUnion _ -> (
                  match fst (bundle_segments lo) with
                  | Some c -> c
                  | None ->
                      Error.fail span
                        "fold folds along one existing crease; a union spans \
                         several")
              | _ ->
                  Error.fail span
                    "fold folds along an existing crease; give a crease \
                     name, e.g. fold --d or fold --d & .p"
            in
            let axis = resolve_line lo in
            (* per-flap material check: every segment of the bundle carried by
               a moving flap must lie on the axis — a crease bent under the
               moving set cannot fold (#28) *)
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
              ~crease_id:cid ~prov ~check:(Some check_straight);
            push_frame (Some span))
    | Ast.Point (n, Ast.PsExpr po, span) ->
        bind_point ctx n span (resolve_point po)
    | Ast.Flip _ ->
        ctx.state := Fold_state.flip !(ctx.state);
        ctx.pending <- true
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
                  | Ast.LFilter _ | Ast.LUnion _ | Ast.LSelect _ ->
                      Frozen (resolve_line lo)
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
            let inst =
              { ipoints = Hashtbl.create 8; ilines = Hashtbl.create 8;
                ipoint_steps = Hashtbl.create 8; iline_steps = Hashtbl.create 8 }
            in
            Hashtbl.iter
              (fun k v -> if not (is_temp k) then Hashtbl.replace inst.ipoints k v)
              body_scope.points;
            Hashtbl.iter
              (fun k v -> if not (is_temp k) then Hashtbl.replace inst.ilines k v)
              body_scope.lines;
            (* carries each member's OWN creation step (recorded in the def
               body's own scope) forward onto the instance, so a later
               [export] can stamp the landed name with the source's real
               step instead of defaulting to 0 (see [land_name]). Points and
               lines carried separately (see [scope.point_steps]/
               [line_steps]) so a same-stem point/line pair can't clobber
               each other's step. *)
            Hashtbl.iter
              (fun k v -> if not (is_temp k) then Hashtbl.replace inst.ipoint_steps k v)
              body_scope.point_steps;
            Hashtbl.iter
              (fun k v -> if not (is_temp k) then Hashtbl.replace inst.iline_steps k v)
              body_scope.line_steps;
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
          (* the landed name is the SAME geometric object as the source member
             inside the def body: it carries the source's own creation step,
             not a fresh one at export time (defaults to 0 if the source was
             never routed through bind_point/bind_crease, e.g. a def
             parameter passed straight through unmodified). Looked up in the
             kind-appropriate table (point vs line) so a same-stem point/line
             pair can't clobber each other's step. *)
          match kind with
          | `Point -> (
              let step =
                Option.value (Hashtbl.find_opt inst.ipoint_steps src) ~default:0
              in
              match Hashtbl.find_opt inst.ipoints src with
              | Some v ->
                  Hashtbl.replace cur.points target v;
                  Hashtbl.replace cur.point_steps target step
              | None ->
                  Error.fail espan
                    (Printf.sprintf "instance $%s has no point member %s" iname src))
          | `Line -> (
              let step =
                Option.value (Hashtbl.find_opt inst.iline_steps src) ~default:0
              in
              match Hashtbl.find_opt inst.ilines src with
              | Some v ->
                  Hashtbl.replace cur.lines target v;
                  Hashtbl.replace cur.line_steps target step
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
        (* a step marker snapshots the crease-pattern built up so far (precrease
           stages between which nothing folds). Push with the CURRENT panel
           FIRST so the snapshot carries the prior label, THEN switch the active
           label. A step marker has no single fold line → source_line None. *)
        push_frame None;
        (* the marker OPENS a new labeled step whose own end-state isn't captured
           yet; flag pending so the final push captures it (e.g. def-diagonals'
           trailing `centre` step, which only binds points/exports after the
           marker). A trailing fold/collapse clears pending again → no dup. *)
        ctx.pending <- true;
        ctx.panel <- Some id
    | Ast.Flatten (name_opt, elems, overs, standing_opt, toward_opt, span) ->
        (match standing_opt with
        | Some _ -> Error.fail span "standing folds are not yet supported"
        | None -> ());
        (* materialize every collapse crease FIRST (a mark subdivides on
           segment-selection), so all of them cross and the shared collapse
           vertex is fully formed before any ray is selected. Selecting rays
           one-by-one would subdivide the first crease before the others exist,
           leaving it unsplit at the vertex (`no common interior vertex`). *)
        let rec force_material (lo : Ast.line_operand) =
          match lo with
          | Ast.LNamed cr -> ignore (material_cid cr)
          | Ast.LFilter (b, _, _) -> force_material b
          | Ast.LUnion (los, _) -> List.iter force_material los
          | Ast.LSelect _ -> ()
        in
        List.iter (fun (el : Ast.collapse_elem) -> force_material el.Ast.cline) elems;
        (* each element must resolve to exactly ONE material segment — same
           machinery as fold's material resolution *)
        let resolve_elem (el : Ast.collapse_elem) : Collapse.elem =
          let fail_not_material () =
            Error.fail span
              (Printf.sprintf
                 "collapse folds along existing creases; %s is not a \
                  material crease" (lstr el.Ast.cline))
          in
          match el.Ast.cline with
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
                       "--%s has %d segments; select one with & "
                       cr.Ast.cname (List.length segs)))
          | (Ast.LFilter _ | Ast.LUnion _) as lo -> (
              match bundle_segments lo with
              | Some cid, [ s ] ->
                  {
                    Collapse.cid;
                    ea = s.Fold_state.ta;
                    eb = s.Fold_state.tb;
                    valley = el.Ast.cdir = Ast.Valley;
                  }
              | _, [] ->
                  Error.fail span
                    (Printf.sprintf "no segment of %s matches" (lstr lo))
              | _, (_ :: _ :: _ as many) ->
                  Error.fail span
                    (Printf.sprintf
                       "%s is ambiguous: %d segments match; add a constraint"
                       (lstr lo) (List.length many))
              | None, [ _ ] ->
                  (* a single segment but from a cross-crease union: no one cid
                     to fold along *)
                  fail_not_material ())
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
        (match toward_opt with
        | None ->
            (match Collapse.collapse !(ctx.state) es ~over with
            | Ok st -> ctx.state := st
            | Error msg -> Error.fail span msg)
        | Some toward_po ->
            (* DERIVE mode: [elems] is an odd set of given rays sharing one
               vertex O; solve the emergent crease completing them to a flat
               vertex (Flatten.derive), materialize it as a real crease
               (Fold_state.subdivide — the elems are already TABLE-space, so
               the cutting axis is too, unlike a mark's paper-space line),
               then fold the completed (now even) set exactly like the
               validate path. *)
            let o =
              match Collapse.common_vertex es with
              | Some o -> o
              | None -> Error.fail span Collapse.e_no_vertex
            in
            let toward_pt = resolve_point toward_po in
            let fixed = Collapse.sort_ccw o es in
            (match Flatten.derive o ~fixed ~toward:toward_pt with
            | Error msg -> Error.fail span msg
            | Ok emergent_line ->
                let new_cid = Fold_state.fresh_crease_id () in
                let prov : State.provenance option =
                  Some
                    { State.axiom = "flatten"; sources = []; span; name = None;
                      step = ctx.panel }
                in
                (* Materialize the emergent axis. When it is genuinely new
                   this subdivides every face it crosses; when it happens to
                   run collinear with an already-materialized given ray (the
                   common case for a symmetric vertex, where the emergent
                   crease is the straight continuation of one of the given
                   creases — verified on rabbit-ear.bel geometry: the given
                   down-spine and the emergent up-spine are the SAME line),
                   every face is already split along it and this is a no-op —
                   so the real candidate ray is found below by scanning ALL
                   existing creases at O, not just [new_cid]'s own edges. *)
                ctx.state :=
                  Fold_state.subdivide !(ctx.state) emergent_line
                    ~crease_id:new_cid ~prov;
                let far_of_seg (s : Fold_state.crease_segment) =
                  if Geom.point_equal s.Fold_state.ta o then s.Fold_state.tb
                  else s.Fold_state.ta
                in
                let given_fars =
                  List.map (fun (e : Collapse.elem) -> Collapse.far_of o e) es
                in
                let candidates =
                  Fold_state.all_crease_ids !(ctx.state)
                  |> List.concat_map (fun cid ->
                         Fold_state.crease_segments !(ctx.state) cid
                         |> List.filter_map
                              (fun (s : Fold_state.crease_segment) ->
                                if
                                  (Geom.point_equal s.Fold_state.ta o
                                  || Geom.point_equal s.Fold_state.tb o)
                                  && Geom.side_of_line emergent_line
                                       (far_of_seg s)
                                     = 0
                                then Some (cid, far_of_seg s)
                                else None))
                  |> List.filter (fun (_, far) ->
                         not (List.exists (Geom.point_equal far) given_fars))
                in
                (* closure (Kawasaki) doesn't depend on valley, so a
                   wrong-direction candidate fails both valleys identically,
                   and Maekawa admits exactly one valley for the right one —
                   Collapse.collapse is the verification oracle here, not a
                   guess. *)
                let attempts =
                  List.concat_map
                    (fun (cid, far) ->
                      [ true; false ]
                      |> List.map (fun valley ->
                             { Collapse.cid; ea = o; eb = far; valley }))
                    candidates
                in
                let results =
                  List.filter_map
                    (fun (e : Collapse.elem) ->
                      match Collapse.collapse !(ctx.state) (e :: es) ~over with
                      | Ok st -> Some st
                      | Error _ -> None)
                    attempts
                in
                (match results with
                | [ st ] -> ctx.state := st
                | [] ->
                    Error.fail span
                      "the derived crease does not close the vertex"
                | _ :: _ :: _ ->
                    Error.fail span
                      "the derived crease admits more than one closure")));
        (* bind the name (if any) to a selectable bundle of the given rays;
           validate mode only — the emergent-crease refinement is a later
           task (#Task 6). *)
        (match name_opt with
        | Some n ->
            let bundle =
              Ast.LUnion (List.map (fun (el : Ast.collapse_elem) -> el.Ast.cline) elems, span)
            in
            bind_crease ctx n span (Bundle bundle)
        | None -> ());
        push_frame (Some span)
  in
  List.iter eval_stmt prog;
  (* corners and other names never routed through bind_point/bind_crease (the
     prelude corners/edges, set up directly via Hashtbl.replace above) have no
     entry in root_scope.point_steps/.line_steps; they default to step 0.
     Reads root_scope.point_steps/.line_steps the same way named_points/
     named_lines below read root_scope.points/.lines — scoped tables, saved/
     restored across `apply` exactly like those. Kept separate (not one
     shared-key table) because points and lines are separate namespaces: a
     point and a line may share a stem (`.m` / `--m`) without clobbering each
     other's step. *)
  let step_of_point n =
    match Hashtbl.find_opt root_scope.point_steps n with Some s -> s | None -> 0
  in
  let step_of_line n =
    match Hashtbl.find_opt root_scope.line_steps n with Some s -> s | None -> 0
  in
  let named_points =
    Hashtbl.fold
      (fun k v acc -> if is_temp k then acc else (k, v, step_of_point k) :: acc)
      root_scope.points []
  in
  let named_lines =
    Hashtbl.fold
      (fun k cv acc ->
        if is_temp k then acc
        else
          match cv with
          | Frozen l -> (k, l, step_of_line k) :: acc
          | Mark (_, l) -> (k, l, step_of_line k) :: acc
          | Material (cid, l_orig) -> (
              match Fold_state.crease_axis !(ctx.state) cid l_orig with
              | `Line l -> (k, l, step_of_line k) :: acc
              (* bent by a later fold, or no material endpoints left: no
                 single current line to emit, so omit from the map rather
                 than emit the stale frozen original *)
              | `Bent | `Empty -> acc)
          (* a bundle is not a single line; it is not emitted in the
             one-line-per-name overlay map. the prelude paper edges are
             implicit, not user-declared construction lines, so they are
             likewise not emitted. *)
          | Bundle _ | Edge _ -> acc)
      root_scope.lines []
  in
  if ctx.pending then
    ctx.frames_rev <- (ctx.panel, !(ctx.state), None) :: ctx.frames_rev;
  let frames = List.rev ctx.frames_rev in
  { state = !(ctx.state); named_points; named_lines; frames }
