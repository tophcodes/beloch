(** `flatten` over fan items: several vertices folded in one motion
    (BEP-0055; docs/reference/KERNEL.md, Fans). *)

open Ctx

(* A ray of a fan: the crease scored along it, the fan it belongs to, the
   half-line from that fan's vertex through [far], the letter the program
   fixed, and whether the statement derived it. [far] is the end of the ray:
   the other vertex for a crease between two vertices, the farthest material
   along the half-line otherwise. *)
type ray = {
  cid : int;
  fan : int;
  far : Geom.point;
  dir : Ast.mv_constraint;
  derived : bool;
}

(* What a ray item names before its vertex is known: material segments of
   one crease, or the line of a construction the statement scores. *)
type operand =
  | Segments of int * Fold_state.crease_segment list * Geom.point list
      (* crease id, its segments, and the paper points a `&` keeps *)
  | Line of int * Geom.line

let centroid (f : Geom.point array) : Geom.point =
  let m = Num.of_int (Array.length f) in
  let sum get = Array.fold_left (fun acc p -> Num.add acc (get p)) Num.zero f in
  { Geom.x = Num.div (sum (fun p -> p.Geom.x)) m;
    y = Num.div (sum (fun p -> p.Geom.y)) m }

let dot (o : Geom.point) (p : Geom.point) (q : Geom.point) : Num.t =
  Num.add
    (Num.mul (Num.sub p.Geom.x o.Geom.x) (Num.sub q.Geom.x o.Geom.x))
    (Num.mul (Num.sub p.Geom.y o.Geom.y) (Num.sub q.Geom.y o.Geom.y))

(* [p] and [q] lie on one half-line from [o] *)
let same_dir (o : Geom.point) (p : Geom.point) (q : Geom.point) : bool =
  Geom.ccw_compare ~center:o p q = 0

let no_sides : Ast.sides =
  { Ast.s_toward = None; s_moving = None;
    s_spans = { Ast.toward_span = None; moving_span = None } }

(* the paper points a chain of `&` filters keeps a segment by *)
let rec kept_points (ctx : Ctx.ctx) (lo : Ast.line_operand) : Geom.point list =
  match lo with
  | Ast.LFilter (b, Ast.Keep (Ast.SelPoint po), _) ->
      Resolve.resolve_point ctx po :: kept_points ctx b
  | Ast.LFilter (b, _, _) -> kept_points ctx b
  | _ -> []

let operand_of (ctx : Ctx.ctx) (r : Ast.fan_ray) : operand =
  match r.Ast.fray with
  | Ast.MConstruction c ->
      let _, pending = Axiom.axis_of ctx r.Ast.fspan c in
      let { Axiom.line; _ } =
        Axiom.select ctx r.Ast.fspan pending ~fold:false no_sides
      in
      Line (Fold_state.fresh_crease_id (), line)
  | Ast.MLine lo -> (
      let rec force (lo : Ast.line_operand) =
        match lo with
        | Ast.LNamed cr ->
            ignore (Resolve.crease_of ctx cr ~slot:"a flatten ray" cr.Ast.cspan);
            ignore (Resolve.material_cid ctx cr)
        | Ast.LFilter (b, _, _) -> force b
        | Ast.LUnion (los, _) -> List.iter force los
        | Ast.LSelect _ -> ()
      in
      force lo;
      (* the extent of a mark that cuts no face from edge to edge: the
         segments the program marked, which the statement scores *)
      let marked cid =
        match lo with
        | Ast.LNamed _ ->
            let st = !(ctx.state) in
            List.map
              (fun (pa, pb) ->
                { Fold_state.faces = (-1, -1);
                  ta = Fold_state.table_position st pa;
                  tb = Fold_state.table_position st pb; pa; pb })
              (Fold_state.mark_chords st cid)
        | _ -> []
      in
      match Resolve.bundle_segments ctx lo with
      | Some cid, [] when marked cid <> [] -> Segments (cid, marked cid, [])
      | _, [] ->
          Error.fail r.Ast.fspan
            (Printf.sprintf "no segment of %s matches" (Resolve.lstr lo))
      | Some cid, segs -> Segments (cid, segs, kept_points ctx lo)
      | None, _ ->
          Error.fail r.Ast.fspan
            (Printf.sprintf
               "a ray folds along one crease; %s is not a material crease"
               (Resolve.lstr lo)))

(* whether the ray item passes through the table point [p] *)
let passes (op : operand) (p : Geom.point) : bool =
  match op with
  | Line (_, l) -> Geom.side_of_line l p = 0
  | Segments (_, segs, _) ->
      List.exists
        (fun (s : Fold_state.crease_segment) ->
          Geom.on_segment (s.Fold_state.ta, s.Fold_state.tb) p)
        segs

(* The vertex of a fan: the table point of `at`, or the one point every ray
   item passes through. *)
let vertex_of (ctx : Ctx.ctx) (f : Ast.fan) (ops : operand list) : Geom.point =
  match f.Ast.fan_at with
  | Some po ->
      let v = Resolve.table_of ctx po in
      if not (List.for_all (fun op -> passes op v) ops) then
        Error.fail f.Ast.fan_span
          (Printf.sprintf "the rays of the fan do not meet at %s"
             (Resolve.fstr (Ast.FlapPoint po)));
      v
  | None ->
      let lines =
        List.concat_map
          (function
            | Line (_, l) -> [ l ]
            | Segments (_, segs, _) ->
                List.map
                  (fun (s : Fold_state.crease_segment) ->
                    Geom.line_through s.Fold_state.ta s.Fold_state.tb)
                  segs)
          ops
      in
      let ends =
        List.concat_map
          (function
            | Line _ -> []
            | Segments (_, segs, _) ->
                List.concat_map
                  (fun (s : Fold_state.crease_segment) ->
                    [ s.Fold_state.ta; s.Fold_state.tb ])
                  segs)
          ops
      in
      let meets =
        List.concat_map
          (fun l ->
            List.filter_map
              (fun l' ->
                if Geom.parallel l l' then None else Geom.intersection l l')
              lines)
          lines
      in
      let found =
        List.fold_left
          (fun acc p ->
            if
              List.for_all (fun op -> passes op p) ops
              && not (List.exists (Geom.point_equal p) acc)
            then p :: acc
            else acc)
          [] (meets @ ends)
      in
      (match found with
      | [ v ] -> v
      | [] -> Error.fail f.Ast.fan_span Collapse.e_no_vertex
      | _ ->
          Error.fail ~hint:"name the vertex: (fan at .p …)" f.Ast.fan_span
            "the rays of the fan meet in more than one point")

(* The rays an item gives at the vertex [v]: the halves of its segments that
   start at [v] and hold every point a `&` keeps, one per direction; the
   halves of a construction's line along which material under the vertex
   lies. *)
let rays_at (st : Fold_state.t) ~(fan : int) (v : Geom.point)
    (r : Ast.fan_ray) (op : operand) : ray list =
  let mk cid far = { cid; fan; far; dir = r.Ast.fdir; derived = false } in
  let dedup rays =
    List.fold_left
      (fun acc (ry : ray) ->
        match List.partition (fun (q : ray) -> same_dir v q.far ry.far) acc with
        | [], _ -> ry :: acc
        | [ q ], rest ->
            (* the longer piece names the ray's end *)
            if Num.compare (dot v ry.far ry.far) (dot v q.far q.far) > 0 then
              ry :: rest
            else acc
        | _ -> acc)
      [] rays
    |> List.rev
  in
  match op with
  | Segments (cid, segs, keeps) ->
      List.concat_map
        (fun (s : Fold_state.crease_segment) ->
          let ta = s.Fold_state.ta and tb = s.Fold_state.tb in
          if not (Geom.on_segment (ta, tb) v) then []
          else
            (* the paper point of [v] on this piece *)
            let t = Geom.seg_param (ta, tb) v in
            let pa = s.Fold_state.pa and pb = s.Fold_state.pb in
            let pv =
              { Geom.x = Num.add pa.Geom.x (Num.mul t (Num.sub pb.Geom.x pa.Geom.x));
                y = Num.add pa.Geom.y (Num.mul t (Num.sub pb.Geom.y pa.Geom.y)) }
            in
            List.filter_map
              (fun (tfar, pfar) ->
                if Geom.point_equal tfar v then None
                else if
                  List.for_all (fun k -> Geom.on_segment (pv, pfar) k) keeps
                then Some (mk cid tfar)
                else None)
              [ (ta, pa); (tb, pb) ])
        segs
      |> dedup
  | Line (cid, l) ->
      let chords =
        List.filter_map
          (fun i -> Geom.clip_line_to_convex l (Fold_state.table_polygon_ccw st i))
          (List.init (Array.length (Fold_state.faces st)) Fun.id)
      in
      let farthest d =
        List.fold_left
          (fun acc (a, b) ->
            if not (Geom.on_segment (a, b) v) then acc
            else
              List.fold_left
                (fun acc p ->
                  if Num.sign (dot v p d) <= 0 then acc
                  else
                    match acc with
                    | Some q when Num.compare (dot v q d) (dot v p d) >= 0 -> acc
                    | _ -> Some p)
                acc [ a; b ])
          None chords
      in
      let dx = Num.neg l.Geom.b and dy = l.Geom.a in
      let plus = { Geom.x = Num.add v.Geom.x dx; y = Num.add v.Geom.y dy } in
      let minus = { Geom.x = Num.sub v.Geom.x dx; y = Num.sub v.Geom.y dy } in
      List.filter_map (fun d -> Option.map (mk cid) (farthest d)) [ plus; minus ]

(* The faces of [pre] that hold each face of [st], by the paper centroid. *)
let parents (pre : Geom.point array array) (st : Fold_state.t) : int array =
  Array.map
    (fun f ->
      let c = centroid f in
      let found = ref (-1) in
      Array.iteri
        (fun j p -> if !found < 0 && Geom.in_convex_polygon p c then found := j)
        pre;
      !found)
    (Fold_state.faces st)

let run (ctx : Ctx.ctx) ~(into : (int * (Geom.line -> unit)) option)
    ~(bind_out : Ctx.crease_val -> unit) ~(fans : Ast.fan list)
    ~(overs : (Ast.flap_arg * Ast.flap_arg) list)
    ~(staying_opt : Ast.point_operand list option)
    ~(on_opt : Ast.flap_arg option) (span : Error.span) : unit =
  let fans = Array.of_list fans in
  let m = Array.length fans in
  if m < 2 then
    Error.fail ~hint:"write the rays as items of the flatten" span
      "a flatten with one fan item folds one vertex; give its rays without \
       the fan";
  (* the rays of every fan, at its vertex *)
  let ops = Array.map (fun f -> List.map (operand_of ctx) f.Ast.fan_rays) fans in
  (* read after the operands: a marked crease a ray names is cut into the
     paper as it resolves, and the anchor, the stayer and the rays index the
     faces of the state that holds it *)
  let pre_st = !(ctx.state) in
  let verts = Array.mapi (fun j f -> vertex_of ctx f ops.(j)) fans in
  let given =
    Array.to_list
      (Array.mapi
         (fun j f ->
           List.concat
             (List.map2 (rays_at pre_st ~fan:j verts.(j)) f.Ast.fan_rays ops.(j)))
         fans)
  in
  List.iteri
    (fun j rs ->
      if rs = [] then
        Error.fail fans.(j).Ast.fan_span "no ray of the fan starts at its vertex")
    given;
  (* the crease between two vertices: a ray of both fans, derived when the
     program names it in neither (BEP-0055) *)
  let derived_cid =
    lazy (match into with Some (cid, _) -> cid | None -> Fold_state.fresh_crease_id ())
  in
  let given = Array.of_list given in
  let derived = ref None in
  if m = 2 then begin
    let toward j k =
      List.exists (fun (r : ray) -> same_dir verts.(j) r.far verts.(k)) given.(j)
    in
    match (toward 0 1, toward 1 0) with
    | true, true -> ()
    | false, false ->
        let cid = Lazy.force derived_cid in
        let d j k =
          { cid; fan = j; far = verts.(k); dir = Ast.MvFree; derived = true }
        in
        given.(0) <- given.(0) @ [ d 0 1 ];
        given.(1) <- given.(1) @ [ d 1 0 ];
        derived := Some (cid, Geom.line_through verts.(0) verts.(1))
    | _ ->
        Error.fail ~hint:"name the crease in both fans" span
          "a crease between two vertices is a ray of both fans"
  end;
  let rays = Array.of_list (List.concat (Array.to_list given)) in
  let nr = Array.length rays in
  (* the rays of each fan in counter-clockwise order, one per direction *)
  let fan_rays =
    Array.mapi
      (fun j v ->
        Array.to_list rays
        |> List.filter (fun (r : ray) -> r.fan = j)
        |> List.fold_left
             (fun acc (r : ray) ->
               if List.exists (fun (q, _) -> same_dir v q r.far) acc then acc
               else (r.far, ()) :: acc)
             []
        |> List.sort (fun (p, _) (q, _) -> Geom.ccw_compare ~center:v p q)
        |> Array.of_list)
      verts
  in
  let prov : State.provenance option =
    Some
      { State.axiom = "flatten"; sources = []; span; name = None;
        stmt = Ctx.stmt_index ctx }
  in
  (* The record a hinge of crease [cid] carries. A crease the program marked
     carries the record of the `mark` statement that defined its line, with
     its name, and this statement's index, as [Resolve.material_cid] gives
     it; a construction and the derived crease carry this statement's. *)
  let prov_of (cid : int) : State.provenance option =
    match
      Array.find_opt
        (fun (m : Fold_state.mark) -> m.Fold_state.mcrease_id = cid)
        (Fold_state.marks pre_st)
      |> Fun.flip Option.bind (fun (m : Fold_state.mark) -> m.Fold_state.mprov)
    with
    | Some pr -> Some { pr with State.stmt = Ctx.stmt_index ctx }
    | None -> prov
  in
  (* the anchor flap `on` names, as paper polygons *)
  let anchor =
    match on_opt with
    | None -> None
    | Some fa ->
        let faces = Resolve.resolve_flap_cluster ctx fa span in
        let under =
          List.exists
            (fun f ->
              Array.exists
                (Geom.in_convex_polygon (Fold_state.table_polygon_ccw pre_st f))
                verts)
            faces
        in
        if not under then
          Error.fail span "the on flap does not lie under a vertex";
        Some (List.map (fun f -> (Fold_state.faces pre_st).(f)) faces)
  in
  let v0 = verts.(0) in
  (* the staying points, as table points on the anchor (BEP-0048) *)
  let staying =
    match staying_opt with
    | None ->
        Error.fail ~hint:"add (staying .p) with .p in the region that stays" span
          "a flatten with several fans needs a staying item"
    | Some pos ->
        let on_anchor = Collapse.anchor_faces pre_st v0 anchor in
        let faces = Fold_state.faces pre_st in
        List.map
          (fun po ->
            let pp = Resolve.resolve_point ctx po in
            let held = ref false in
            Array.iteri
              (fun i f ->
                if on_anchor.(i) && Geom.in_convex_polygon f pp then held := true)
              faces;
            if not !held then
              Error.fail ~hint:"name a point on the flap the fans fold" span
                (Printf.sprintf "%s does not lie on the anchor"
                   (Resolve.fstr (Ast.FlapPoint po)));
            Fold_state.table_position pre_st pp)
          pos
  in
  let pre = Fold_state.faces pre_st in
  (* the faces under the fans: those whose table image meets the anchor's *)
  let under_fan =
    let on_anchor = Collapse.anchor_faces pre_st v0 anchor in
    let tp = Fold_state.table_polygon_ccw pre_st in
    Array.init (Array.length pre) (fun i ->
        let hit = ref false in
        Array.iteri
          (fun j a -> if a && not !hit then hit := Geom.convex_overlap (tp i) (tp j))
          on_anchor;
        !hit)
  in
  (* score ray [k] on the faces of [st] whose parent before the flatten
     [need k] holds *)
  let score (need : int -> int -> bool) : Fold_state.t =
    (* A face that holds two vertices or more inside it is cut along all its
       rays at once: no ray cuts it from edge to edge alone. *)
    let joint =
      let strictly_inside i v =
        let poly = Fold_state.table_polygon_ccw pre_st i in
        let n = Array.length poly in
        Geom.in_convex_polygon poly v
        && not
             (List.exists
                (fun j -> Geom.on_segment (poly.(j), poly.((j + 1) mod n)) v)
                (List.init n Fun.id))
      in
      Fold_state.subdivide_segments pre_st ~crease_prov:prov_of ~prov ~segments:(fun i ->
          let held =
            Array.to_list verts |> List.filter (strictly_inside i) |> List.length
          in
          if held < 2 then []
          else
            Array.to_list rays
            |> List.mapi (fun k (r : ray) -> (k, r))
            |> List.filter_map (fun (k, (r : ray)) ->
                   if need k i then Some (r.cid, (verts.(r.fan), r.far)) else None))
    in
    let st = ref joint in
    Array.iteri
      (fun k (r : ray) ->
        let par = parents pre !st in
        let v = verts.(r.fan) in
        st :=
          Fold_state.subdivide_fan !st ~o:v
            ~rays:[ (r.cid, Geom.line_through v r.far, r.far) ]
            ~only:(fun i -> par.(i) >= 0 && need k par.(i))
            ~prov:(prov_of r.cid))
      rays;
    !st
  in
  (* per face of [st], its wedge around each vertex, and its region: the
     wedges around all of them, or -1 when a ray runs through it *)
  let regions (st : Fold_state.t) =
    let faces = Fold_state.faces st in
    let wedges =
      Array.mapi
        (fun j v ->
          let fr = fan_rays.(j) in
          let n = Array.length fr in
          Array.init (Array.length faces) (fun i ->
              let w =
                Collapse.sector_of_poly_opt v fr (faces.(i), Fold_state.face_iso2 st i)
              in
              if w >= 0 then w
              else
                (* A ray ends at its far point. A face that only the line
                   beyond that point runs through lies in the wedge of a
                   point inside it. *)
                let poly = Fold_state.table_polygon_ccw st i in
                let crossed =
                  Array.exists
                    (fun (r : ray) ->
                      r.fan = j && Geom.segment_crosses_interior (v, r.far) poly)
                    rays
                in
                if crossed then -1
                else
                  let c = centroid poly in
                  let mid (p : Geom.point) =
                    { Geom.x = Num.div (Num.add p.Geom.x c.Geom.x) (Num.of_int 2);
                      y = Num.div (Num.add p.Geom.y c.Geom.y) (Num.of_int 2) }
                  in
                  let off_rays p =
                    (not (Geom.point_equal p v))
                    && not (Array.exists (fun (q, _) -> same_dir v p q) fr)
                  in
                  match
                    List.find_opt off_rays (c :: List.map mid (Array.to_list poly))
                  with
                  | None -> -1
                  | Some p ->
                      let found = ref (-1) in
                      for k = 0 to n - 1 do
                        let a, _ = fr.(k) and b, _ = fr.((k + 1) mod n) in
                        if !found < 0 && Collapse.in_closed_sector v a b p then
                          found := k
                      done;
                      !found))
        verts
    in
    let sig_of i = Array.to_list (Array.map (fun w -> w.(i)) wedges) in
    (wedges, Array.init (Array.length faces) (fun i ->
         let s = sig_of i in
         if List.mem (-1) s then None else Some s))
  in
  (* the region that holds every staying point, among the regions of the
     anchor's faces *)
  let stayer_of (cells : int list option array) (on_anchor : bool array) =
    let holds s =
      List.for_all
        (fun p ->
          List.for_all2
            (fun k (j, v) ->
              let n = Array.length fan_rays.(j) in
              let a, _ = fan_rays.(j).(k) and b, _ = fan_rays.(j).((k + 1) mod n) in
              Collapse.in_closed_sector v a b p)
            s
            (Array.to_list (Array.mapi (fun j v -> (j, v)) verts)))
        staying
    in
    let found =
      Array.to_list cells
      |> List.mapi (fun i c -> (i, c))
      |> List.filter_map (fun (i, c) ->
             match c with Some s when on_anchor.(i) && holds s -> Some s | _ -> None)
      |> List.sort_uniq compare
    in
    match found with
    | [ s ] -> s
    | [] -> Error.fail span Collapse.e_staying_none
    | _ ->
        Error.fail ?hint:(Collapse.hint_of Collapse.e_staying_several) span
          Collapse.e_staying_several
  in
  (* The tip on [st]: the faces of the anchor outside the region that
     stays, and every face joined to one of them by a hinge that was there
     before the flatten, in the same region. A ray this statement scores
     joins no faces. *)
  let tip_on st (par : int array) (cells : int list option array) stayer
      (on_anchor : bool array) =
    let nf = Array.length cells in
    let tip = Array.make nf false in
    Array.iteri
      (fun i a ->
        if a then
          match cells.(i) with
          | Some s when s <> stayer -> tip.(i) <- true
          | Some _ -> ()
          | None -> Error.fail span Collapse.e_unaligned)
      on_anchor;
    let grown = ref true in
    while !grown do
      grown := false;
      Array.iter
        (fun (h : Fold_state.hinge) ->
          let a = h.Fold_state.fa and b = h.Fold_state.fb in
          let join x y =
            if tip.(x) && (not tip.(y)) && par.(x) <> par.(y) && cells.(y) = cells.(x)
            then begin
              tip.(y) <- true;
              grown := true
            end
          in
          join a b;
          join b a)
        (Fold_state.hinges st)
    done;
    tip
  in
  let on_ray st i k =
    let ta, tb = Fold_state.hinge_table_segment st i in
    let v = verts.(rays.(k).fan) in
    Geom.on_segment (v, rays.(k).far) ta && Geom.on_segment (v, rays.(k).far) tb
  in
  (* 1. every ray on every layer under the fans, to read the tip off *)
  let st_all = score (fun _ p -> under_fan.(p)) in
  let par_all = parents pre st_all in
  let _, cells_all = regions st_all in
  let anchor_all = Collapse.anchor_faces st_all v0 anchor in
  let stayer = stayer_of cells_all anchor_all in
  let tip_all = tip_on st_all par_all cells_all stayer anchor_all in
  (* 2. each ray on the faces where it parts a face of the tip from a face
     of the same layer that stays, or two regions of the tip *)
  let need = Array.make_matrix nr (Array.length pre) false in
  Array.iteri
    (fun i (h : Fold_state.hinge) ->
      let a = h.Fold_state.fa and b = h.Fold_state.fb in
      if
        par_all.(a) = par_all.(b) && par_all.(a) >= 0
        && (tip_all.(a) <> tip_all.(b)
           || (tip_all.(a) && tip_all.(b) && cells_all.(a) <> cells_all.(b)))
      then
        for k = 0 to nr - 1 do
          if on_ray st_all i k then need.(k).(par_all.(a)) <- true
        done)
    (Fold_state.hinges st_all);
  let st = score (fun k p -> need.(k).(p)) in
  let par = parents pre st in
  let wedges, cells = regions st in
  let on_anchor = Collapse.anchor_faces st v0 anchor in
  let tip = tip_on st par cells stayer on_anchor in
  if not (Array.exists Fun.id tip) then Error.fail span Collapse.e_anchor_stays;
  let faces = Fold_state.faces st in
  let nf = Array.length faces in
  (* the regions, numbered with the one that stays as 0 *)
  let ids =
    stayer
    :: (Array.to_list cells |> List.filter_map Fun.id
       |> List.filter (( <> ) stayer)
       |> List.sort_uniq compare)
  in
  let sec =
    Array.map
      (function
        | None -> -1
        | Some s ->
            let rec find i = function
              | [] -> assert false
              | x :: rest -> if x = s then i else find (i + 1) rest
            in
            find 0 ids)
      cells
  in
  let hinges = Fold_state.hinges st in
  let nh = Array.length hinges in
  let touches_tip (h : Fold_state.hinge) = tip.(h.Fold_state.fa) || tip.(h.Fold_state.fb) in
  let names =
    Array.init nh (fun i ->
        let found = ref None in
        Array.iteri
          (fun k (r : ray) ->
            if !found = None && r.cid = hinges.(i).Fold_state.crease_id && on_ray st i k
            then found := Some k)
          rays;
        !found)
  in
  let role =
    Array.init nh (fun i ->
        let h = hinges.(i) in
        let on_any = List.exists (on_ray st i) (List.init nr Fun.id) in
        if (not on_any) || not (touches_tip h) then Collapse.Keep
        else
          match names.(i) with
          | Some _ when Num.sign h.Fold_state.angle = 0 -> Collapse.Fold
          | _ -> Collapse.Try)
  in
  (* the face on the clockwise side of ray [k] at its vertex *)
  let side k a b =
    let r = rays.(k) in
    let v = verts.(r.fan) in
    let fr = fan_rays.(r.fan) in
    let n = Array.length fr in
    let idx = ref (-1) in
    Array.iteri (fun j (p, _) -> if !idx < 0 && same_dir v p r.far then idx := j) fr;
    let w = wedges.(r.fan) in
    let l = (!idx - 1 + n) mod n in
    if w.(a) = l then Some (a, b)
    else if w.(b) = l then Some (b, a)
    else if w.(a) = !idx then Some (b, a)
    else if w.(b) = !idx then Some (a, b)
    else None
  in
  let sgs =
    Collapse.geoms_of st ~sec ~tip ~names ~role ~nelem:nr
      ~side ~faces ~nf
  in
  (* the letters: free where the program left them, held to Maekawa's
     parity at a vertex the anchor surrounds *)
  let surrounded = Array.map (fun v -> Collapse.surrounded st v on_anchor) verts in
  let patterns =
    let rec all = function
      | [] -> [ [] ]
      | (r : ray) :: rest ->
          let tails = all rest in
          let heads =
            match r.dir with
            | Ast.MvValley -> [ true ]
            | Ast.MvMountain -> [ false ]
            | Ast.MvFree -> [ true; false ]
          in
          List.concat_map (fun h -> List.map (fun t -> h :: t) tails) heads
    in
    all (Array.to_list rays)
    |> List.filter (fun pat ->
           let pat = Array.of_list pat in
           List.for_all
             (fun j ->
               (not surrounded.(j))
               || Collapse.maekawa_ok
                    (List.filter_map
                       (fun k -> if rays.(k).fan = j then Some pat.(k) else None)
                       (List.init nr Fun.id)))
             (List.init m Fun.id))
  in
  let over =
    List.map
      (fun (u, l) ->
        (Resolve.resolve_sector_face ctx u span, Resolve.resolve_sector_face ctx l span))
      overs
  in
  (* every realization of every pattern; the outline of the state before
     the flatten ranks them below (BEP-0058) *)
  let results =
    List.map
      (fun pat ->
        match sgs with
        | Error e -> Error e
        | Ok sgs -> (
            let runs =
              List.map
                (fun sg ->
                  match Collapse.pipeline_solve sg ~valley:(Array.of_list pat) ~over with
                  | Error e -> Error e
                  | Ok states -> Ok states)
                sgs
            in
            match List.concat_map (function Ok l -> l | Error _ -> []) runs with
            | [] -> (
                match List.find_map (function Error e -> Some e | Ok _ -> None) runs with
                | Some e -> Error e
                | None -> Error Collapse.e_selfint)
            | l -> Ok l))
      patterns
  in
  let same_state a b =
    Fold_state.same_order a b
    && List.for_all
         (fun i ->
           Array.for_all2 Geom.point_equal (Fold_state.table_polygon a i)
             (Fold_state.table_polygon b i))
         (List.init nf Fun.id)
  in
  let all =
    List.fold_left
      (fun acc res ->
        match res with
        | Ok sts ->
            List.fold_left
              (fun acc s ->
                if List.exists (same_state s) acc then acc else acc @ [ s ])
              acc sts
        | Error _ -> acc)
      [] results
  in
  (* the letters of the rays in each state, for the hint of an ambiguous
     statement: a state carries the pattern it came from *)
  let pattern_of =
    List.concat
      (List.map2
         (fun pat res -> match res with Ok sts -> List.map (fun s -> (s, pat)) sts | Error _ -> [])
         patterns results)
  in
  let states = Collapse.rank_by_outline st ~state:Fun.id all in
  let errors = List.filter_map (function Error e -> Some e | Ok _ -> None) results in
  let segs =
    Array.to_list (Array.map (fun (r : ray) -> (verts.(r.fan), r.far)) rays)
  in
  let trace chosen =
    Ctx.record_write ctx (Trace.Flatten { point = v0 })
      (List.map
         (fun s ->
           { Trace.state = Some s;
             detail =
               Trace.fan ~pre:pre_st ~post:s ~point:v0 ~rays:segs
                 ~emergent:(Option.map (fun _ -> (verts.(0), verts.(1))) !derived);
             removed = None;
             chosen = (match chosen with Some c -> c == s | None -> false) })
         states)
  in
  (match states with
  | [ s ] ->
      trace (Some s);
      (match (into, !derived) with
      | Some (_, check_axis), Some (_, line) -> check_axis line
      | Some _, None ->
          Error.fail ~hint:"drop into" span "the flatten scores no new crease"
      | None, _ -> ());
      ctx.state := s
  | [] ->
      trace None;
      let pick =
        List.find_opt
          (fun e -> List.mem e errors)
          [ Collapse.e_contra; Collapse.e_unaligned; Collapse.e_anchor_stays ]
      in
      Error.fail span
        (match pick with
        | Some e -> e
        | None -> "the fans do not fold flat together")
  | many ->
      trace None;
      (* each ray as the program could letter it, in the order of [rays]: the
         rays of each fan item, then the derived crease, which no item names *)
      let item (r : Ast.fan_ray) =
        match r.Ast.fray with
        | Ast.MLine lo -> Flatten.ray_item (Resolve.lstr lo)
        | Ast.MConstruction _ ->
            let p = fst r.Ast.fspan in
            fun l ->
              Printf.sprintf "%s on the ray at %d:%d"
                (if l then "valley" else "mountain")
                p.Lexing.pos_lnum (p.Lexing.pos_cnum - p.Lexing.pos_bol + 1)
      in
      let items =
        List.concat
          (Array.to_list
             (Array.mapi
                (fun j (f : Ast.fan) ->
                  List.concat
                    (List.map2
                       (fun (r : Ast.fan_ray) op ->
                         List.map
                           (fun _ -> if r.Ast.fdir = Ast.MvFree then Some (item r) else None)
                           (rays_at pre_st ~fan:j verts.(j) r op))
                       f.Ast.fan_rays ops.(j))
                  @ if !derived = None then [] else [ None ])
                fans))
      in
      let message, hint =
        Flatten.suggest ~verb:"flatten" ~items ~letters:(fun s -> List.assq s pattern_of) many
      in
      Error.fail ~hint span message);
  (* the vertices a fan binds, as the paper points of the anchor under them *)
  Array.iteri
    (fun j (f : Ast.fan) ->
      match f.Ast.fan_as with
      | None -> ()
      | Some (name, sp) ->
          let v = verts.(j) in
          let pre_anchor = Collapse.anchor_faces pre_st v0 anchor in
          let p = ref None in
          Array.iteri
            (fun i a ->
              if
                !p = None && a
                && Geom.in_convex_polygon (Fold_state.table_polygon_ccw pre_st i) v
              then
                p :=
                  Some
                    (Isometry.apply_point
                       (Isometry.inverse (Fold_state.face_iso2 pre_st i))
                       v))
            pre_anchor;
          match !p with
          | Some pp -> Ctx.bind_point ctx name sp pp
          | None ->
              Error.fail sp
                (Printf.sprintf "the anchor does not lie under the vertex of .%s" name))
    fans;
  bind_out
    (match !derived with
    | Some (cid, line) -> Material (cid, line)
    | None ->
        Bundle
          (Ast.LUnion
             ( List.concat_map
                 (fun (f : Ast.fan) ->
                   List.filter_map
                     (fun (r : Ast.fan_ray) ->
                       match r.Ast.fray with Ast.MLine lo -> Some lo | _ -> None)
                     f.Ast.fan_rays)
                 (Array.to_list fans),
               span )));
  push_frame ctx (Some span)
