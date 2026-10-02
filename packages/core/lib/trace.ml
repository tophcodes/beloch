type removal =
  | By_paper
  | By_toward
  | By_moving
  | By_heading
  | By_moved
  | By_letter
  | By_bodies
  | By_interleaved
  | By_crossing
  | By_opposite
  | By_mountains
  | By_top

type segment = Geom.point * Geom.point
type stage = Paper | Heading | Side | Moved | Landing
type side_from = From_toward | From_moving | Alone | First
type meets = Moves of int | Already | Misses
type motion = { source : (Geom.point * Geom.point) list; image : (Geom.point * Geom.point) list }
type attempt = { fold_side : int; meets : meets list; motions : motion option list }

type candidate = {
  line : Geom.line;
  removed_by : removal option;
  removed_at : stage option;
  selected : bool;
  landing : Geom.point option;
  angle : float option;
  side : int option;
  side_from : side_from option;
  attempts : attempt list;
  subject_folds : bool option;
  landed : segment list option;
  distance : float option;
  nearest : (Geom.point * Geom.point) option;
  suggestion : string option;
}

type conic = { focus : Geom.point; directrix : Geom.line }
type region = Geom.point array list
type placement = Top | Bottom | Over of region | Under of region

type terms =
  | Fold of {
      axis : Geom.line;
      side : int;
      moving : region;
      placement : placement;
    }
  | Reverse of { axis : Geom.line; side : int; inside : bool; tip : region }
  | Flatten of { point : Geom.point }

type detail =
  | Spine of {
      spine : segment;
      halves : (region * region) option;
      bodies : (region * region) option;
    }
  | Fan of {
      rays : segment list;
      emergent : segment option;
      stayer : Geom.point * Geom.point;
    }

type state_candidate = {
  state : Fold_state.t option;
  detail : detail;
  removed : removal option;
  chosen : bool;
}

type entry = { statement : int; frame : int; body : body }

and body = Construction of construction | Write of { terms : terms; states : state_candidate list }
and obj = { name : string; point : Geom.point option; segments : segment list }

and alignment = { objects : obj * obj; span : Error.span option }

and construction = {
  axiom : string;
  toward : Geom.point option;
  toward_segments : segment list;
  toward_name : string option;
  subject : string option;
  moving_name : string option;
  moving_point : Geom.point option;
  operands : obj list;
  heading_line : Geom.line option;
  heading_name : string option;
  alignments : alignment list;
  spans : spans;
  candidates : candidate list;
  conics : conic list;
  circle : (Geom.point * Geom.point) option;
}

and spans = {
  alignment_spans : Error.span list;
  heading : Error.span option;
  toward_span : Error.span option;
  moving_span : Error.span option;
}

let construction ~axiom ~conics =
  { axiom; toward = None; toward_segments = []; toward_name = None; subject = None;
    moving_name = None; moving_point = None; operands = []; heading_line = None; heading_name = None; alignments = [];
    spans = { alignment_spans = []; heading = None; toward_span = None;
              moving_span = None };
    candidates = []; conics; circle = None }

let faces_region st ?clip keep =
  List.filter_map
    (fun fi ->
      if not (keep fi) then None
      else
        let poly = Fold_state.table_polygon st fi in
        let poly =
          match clip with
          | Some (line, side) -> Geom.clip_convex_halfplane line side poly
          | None -> poly
        in
        if Array.length poly >= 3 then Some poly else None)
    (List.init (Array.length (Fold_state.faces st)) Fun.id)

let num x = `Float (Num.to_float x)
let point (p : Geom.point) = `List [ num p.Geom.x; num p.Geom.y ]
let line (l : Geom.line) = `List [ num l.Geom.a; num l.Geom.b; num l.Geom.c ]
let segment (p, q) = `List [ point p; point q ]
let region r = `List (List.map (fun poly -> `List (Array.to_list (Array.map point poly))) r)
let pair f = function Some (x, y) -> `List [ f x; f y ] | None -> `Null

let removal_json = function
  | None -> `Null
  | Some r ->
      `String
        (match r with
        | By_paper -> "paper"
        | By_toward -> "toward"
        | By_moving -> "moving"
        | By_heading -> "heading"
        | By_moved -> "moved"
        | By_letter -> "letter"
        | By_bodies -> "bodies"
        | By_interleaved -> "interleaved"
        | By_crossing -> "crossing"
        | By_opposite -> "opposite"
        | By_mountains -> "mountains"
        | By_top -> "top")

let stage_name = function
  | Paper -> "paper"
  | Heading -> "heading"
  | Side -> "side"
  | Moved -> "moved"
  | Landing -> "landing"

let side_from_name = function
  | From_toward -> "toward"
  | From_moving -> "moving"
  | Alone -> "alone"
  | First -> "first"

let terms_json = function
  | Fold { axis; side; moving; placement } ->
      let kind, target =
        match placement with
        | Top -> ("top", [])
        | Bottom -> ("bottom", [])
        | Over t -> ("over", [ ("target", region t) ])
        | Under t -> ("under", [ ("target", region t) ])
      in
      `Assoc
        ([ ("axis", line axis); ("side", `Int side); ("moving", region moving);
           ("placement", `String kind) ]
        @ target)
  | Reverse { axis; side; inside; tip } ->
      `Assoc
        [ ("axis", line axis); ("side", `Int side);
          ("kind", `String (if inside then "inside" else "outside"));
          ("tip", region tip) ]
  | Flatten { point = o } -> `Assoc [ ("point", point o) ]

let detail_json = function
  | Spine { spine; halves; bodies } ->
      [ ("spine", segment spine); ("halves", pair region halves);
        ("bodies", pair region bodies) ]
  | Fan { rays; emergent; stayer = a, b } ->
      [ ("rays", `List (List.map segment rays));
        ("emergent", match emergent with Some s -> segment s | None -> `Null);
        ("stayer", `List [ point a; point b ]) ]

let to_json ~frame (e : entry) : Yojson.Safe.t =
  let head = [ ("statement", `Int e.statement); ("frame_index", `Int e.frame) ] in
  match e.body with
  | Construction c ->
      let opt f = function Some x -> f x | None -> `Null in
      let str s = `String s in
      let span sp = `String (Error.span_to_string sp) in
      let segments ss = `List (List.map segment ss) in
      let obj o =
        `Assoc
          [ ("name", str o.name); ("point", opt point o.point);
            ("segments", segments o.segments) ]
      in
      let meets = function Moves i -> `Int i | Already -> str "already" | Misses -> `Null in
      let motion m =
        `Assoc [ ("source", segments m.source); ("image", segments m.image) ]
      in
      let candidate k =
        `Assoc
          ([
             ("line", line k.line);
             ("removed_by", removal_json k.removed_by);
             ("removed_at", opt (fun st -> str (stage_name st)) k.removed_at);
             ("selected", `Bool k.selected);
             ("angle", opt (fun a -> `Float a) k.angle);
             ("side", opt (fun s -> `Int s) k.side);
             ("side_from", opt (fun f -> str (side_from_name f)) k.side_from);
             ( "attempts",
               `List
                 (List.map
                    (fun a ->
                      `Assoc
                        [ ("side", `Int a.fold_side);
                          ("alignments", `List (List.map meets a.meets));
                          ("motions", `List (List.map (opt motion) a.motions)) ])
                    k.attempts) );
             ("subject_folds", opt (fun b -> `Bool b) k.subject_folds);
             ("landed", opt segments k.landed);
             ("distance", opt (fun d -> `Float d) k.distance);
             ("nearest", opt (fun (u, v) -> `List [ point u; point v ]) k.nearest);
             ("suggestion", opt str k.suggestion);
           ]
          @ match k.landing with Some p -> [ ("landing", point p) ] | None -> [])
      in
      `Assoc
        (head
        @ [
            ("axiom", str c.axiom);
            ("toward", opt point c.toward);
            ("toward_segments", segments c.toward_segments);
            ("toward_name", opt str c.toward_name);
            ("subject", opt str c.subject);
            ("moving_name", opt str c.moving_name);
            ("moving_point", opt point c.moving_point);
            ("operands", `List (List.map obj c.operands));
            ("heading_line", opt line c.heading_line);
            ("heading_name", opt str c.heading_name);
            ( "alignments",
              `List
                (List.map
                   (fun a ->
                     let x, y = a.objects in
                     `Assoc [ ("objects", `List [ obj x; obj y ]); ("span", opt span a.span) ])
                   c.alignments) );
            ( "spans",
              `Assoc
                [ ("alignments", `List (List.map span c.spans.alignment_spans));
                  ("heading", opt span c.spans.heading);
                  ("toward", opt span c.spans.toward_span);
                  ("moving", opt span c.spans.moving_span) ] );
            ("candidates", `List (List.map candidate c.candidates));
            ( "circle",
              opt (fun (o, t) -> `Assoc [ ("center", point o); ("through", point t) ]) c.circle );
          ]
        @
        match c.conics with
        | [] -> []
        | cs ->
            [
              ( "conics",
                `List
                  (List.map
                     (fun c ->
                       `Assoc [ ("focus", point c.focus); ("directrix", line c.directrix) ])
                     cs) );
            ])
  | Write { terms; states } ->
      let write =
        match terms with
        | Fold _ -> "fold"
        | Reverse _ -> "reverse"
        | Flatten _ -> "flatten"
      in
      `Assoc
        (head
        @ [
            ("write", `String write);
            ("terms", terms_json terms);
            ( "candidates",
              `List
                (List.map
                   (fun c ->
                     `Assoc
                       (detail_json c.detail
                       @ [
                           ("frame", match c.state with Some s -> frame s | None -> `Null);
                           ("removed_by", removal_json c.removed);
                           ("selected", `Bool c.chosen);
                         ]))
                   states) );
          ])

let fold_terms st ~axis ~move_side ~moving placement =
  let block = faces_region st ~clip:(axis, move_side) (fun fi -> moving.(fi)) in
  (* a parent in the block keeps only its part across the axis in place; any
     other parent stays whole *)
  let target fi =
    faces_region st
      ?clip:(if moving.(fi) then Some (axis, -move_side) else None)
      (fun g -> g = fi)
  in
  let placement =
    match placement with
    | Fold_state.Top -> Top
    | Fold_state.Bottom -> Bottom
    | Fold_state.Over fi -> Over (target fi)
    | Fold_state.Under fi -> Under (target fi)
  in
  Fold { axis; side = move_side; moving = block; placement }

let reverse_write st ~axis ~move_side ~tip ~inside ~keeps attempts =
  let moving mask = faces_region st ~clip:(axis, move_side) (fun fi -> mask.(fi)) in
  let staying faces =
    faces_region st ~clip:(axis, -move_side) (fun fi -> List.mem fi faces)
  in
  let chosen =
    match Fold_state.reverse_of_attempts (List.filter keeps attempts) with
    | Ok st' -> Some st'
    | Error _ -> None
  in
  let candidate (a : Fold_state.spine_attempt) =
    let state, removed =
      match a.outcome with
      | Fold_state.Reversed st' when keeps a -> (Some st', None)
      | Fold_state.Reversed _ -> (None, Some By_letter)
      | Fold_state.No_body -> (None, Some By_bodies)
      | Fold_state.Interleaved -> (None, Some By_interleaved)
      | Fold_state.Crossing _ -> (None, Some By_crossing)
    in
    let lower, upper = a.halves in
    {
      state;
      detail =
        Spine
          {
            spine = Fold_state.hinge_table_segment st a.hinge;
            halves = Some (moving lower, moving upper);
            bodies = Option.map (fun (b1, b2) -> (staying b1, staying b2)) a.bodies;
          };
      removed;
      chosen =
        (match (state, chosen) with
        | Some s, Some c -> removed = None && s == c
        | _ -> false);
    }
  in
  ( Reverse { axis; side = move_side; inside; tip = moving tip },
    List.map candidate attempts )

(* Known ceiling: each sector is probed at one point, a thousandth of the way
   from the vertex towards the two ray ends, and the probe has to lie in the
   faces that touch the vertex. A fan whose faces at the vertex are smaller
   than that would need the probe placed from the faces themselves. *)
let fan ~pre ~post ~point:o ~rays ~emergent =
  let ends =
    List.map snd (Option.to_list emergent @ rays)
    |> List.sort (Geom.ccw_compare ~center:o)
    |> Array.of_list
  in
  let n = Array.length ends in
  let k = Num.of_int 1000 in
  let probe (a : Geom.point) (b : Geom.point) =
    let off u v = Num.div (Num.add (Num.sub u o.Geom.x) (Num.sub v o.Geom.x)) k in
    let offy u v = Num.div (Num.add (Num.sub u o.Geom.y) (Num.sub v o.Geom.y)) k in
    { Geom.x = Num.add o.Geom.x (off a.Geom.x b.Geom.x);
      y = Num.add o.Geom.y (offy a.Geom.y b.Geom.y) }
  in
  let stays p =
    match Fold_state.paper_preimages pre p with
    | [] -> false
    | qs ->
        List.for_all
          (fun q -> Geom.point_equal (Fold_state.table_position post q) p)
          qs
  in
  let sectors = List.init n (fun i -> (ends.(i), ends.((i + 1) mod n))) in
  let stayer =
    match List.find_opt (fun (a, b) -> stays (probe a b)) sectors with
    | Some s -> s
    | None -> List.hd sectors
  in
  Fan { rays; emergent; stayer }
