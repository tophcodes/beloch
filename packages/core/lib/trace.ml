type removal =
  | By_paper
  | By_toward
  | By_moving
  | By_halves
  | By_bodies
  | By_interleaved
  | By_crossing
  | By_opposite
  | By_mountains
  | By_top

type candidate = {
  line : Geom.line;
  removed_by : removal option;
  selected : bool;
}

type conic = { focus : Geom.point; directrix : Geom.line }
type region = Geom.point array list
type segment = Geom.point * Geom.point
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

and body =
  | Construction of {
      axiom : string;
      toward : Geom.point option;
      candidates : candidate list;
      conics : conic list;
    }
  | Write of { terms : terms; states : state_candidate list }

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
        | By_halves -> "halves"
        | By_bodies -> "bodies"
        | By_interleaved -> "interleaved"
        | By_crossing -> "crossing"
        | By_opposite -> "opposite"
        | By_mountains -> "mountains"
        | By_top -> "top")

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
  | Construction { axiom; toward; candidates; conics } ->
      `Assoc
        (head
        @ [
            ("axiom", `String axiom);
            ("toward", match toward with Some p -> point p | None -> `Null);
            ( "candidates",
              `List
                (List.map
                   (fun c ->
                     `Assoc
                       [
                         ("line", line c.line);
                         ("removed_by", removal_json c.removed_by);
                         ("selected", `Bool c.selected);
                       ])
                   candidates) );
          ]
        @
        match conics with
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

let reverse_write st ~axis ~move_side ~tip ~inside attempts =
  let moving mask = faces_region st ~clip:(axis, move_side) (fun fi -> mask.(fi)) in
  let staying faces =
    faces_region st ~clip:(axis, -move_side) (fun fi -> List.mem fi faces)
  in
  let reversed =
    List.length
      (List.filter
         (fun (a : Fold_state.spine_attempt) ->
           match a.outcome with Fold_state.Reversed _ -> true | _ -> false)
         attempts)
  in
  let candidate (a : Fold_state.spine_attempt) =
    let state, removed =
      match a.outcome with
      | Fold_state.Reversed st' -> (Some st', None)
      | Fold_state.Not_two_halves -> (None, Some By_halves)
      | Fold_state.No_body -> (None, Some By_bodies)
      | Fold_state.Interleaved -> (None, Some By_interleaved)
      | Fold_state.Crossing _ -> (None, Some By_crossing)
    in
    {
      state;
      detail =
        Spine
          {
            spine = Fold_state.hinge_table_segment st a.hinge;
            halves = Option.map (fun (h1, h2) -> (moving h1, moving h2)) a.halves;
            bodies = Option.map (fun (b1, b2) -> (staying b1, staying b2)) a.bodies;
          };
      removed;
      chosen = state <> None && reversed = 1;
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
