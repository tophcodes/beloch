(** The paper side of a fan of `flatten` (spec multifold,
    "A fan folds at a point of the paper"): the paper point of its
    vertex, the faces a ray runs through from that point, the parts of the
    paper the fan's hinges separate, and the layer error of a part that moves
    without a hinge of the fan. *)

(* the paper point at which the crease piece [s] passes over the table point
   [v], which lies on its table segment *)
let paper_on (s : Fold_state.crease_segment) (v : Geom.point) : Geom.point =
  let t = Geom.seg_param (s.Fold_state.ta, s.Fold_state.tb) v in
  let pa = s.Fold_state.pa and pb = s.Fold_state.pb in
  { Geom.x = Num.add pa.Geom.x (Num.mul t (Num.sub pb.Geom.x pa.Geom.x));
    y = Num.add pa.Geom.y (Num.mul t (Num.sub pb.Geom.y pa.Geom.y)) }

let dedup (ps : Geom.point list) : Geom.point list =
  List.fold_left
    (fun acc p -> if List.exists (Geom.point_equal p) acc then acc else p :: acc)
    [] ps
  |> List.rev

(* The paper points at which the pieces [segs] pass over the table point
   [v]: material pieces, or the chords of a mark that cuts no face from edge
   to edge. *)
let paper_points (segs : Fold_state.crease_segment list) (v : Geom.point) :
    Geom.point list =
  List.filter_map
    (fun (s : Fold_state.crease_segment) ->
      if Geom.on_segment (s.Fold_state.ta, s.Fold_state.tb) v then
        Some (paper_on s v)
      else None)
    segs
  |> dedup

(* The vertex of a fan on the paper: the one paper point that every list of
   [per_ray] holds. A list per ray item names the paper points its pieces
   pass through over the table vertex; an empty list (a construction) puts no
   condition. Where several points remain, [pick] keeps those it accepts.
   [None] when no item names a piece. *)
let vertex ?(pick : Geom.point -> bool = fun _ -> true) (span : Error.span)
    (per_ray : Geom.point list list) : Geom.point option =
  match List.filter (fun l -> l <> []) per_ray with
  | [] -> None
  | first :: rest -> (
      let common =
        List.filter (fun p -> List.for_all (List.exists (Geom.point_equal p)) rest) first
      in
      match (match common with _ :: _ :: _ -> List.filter pick common | _ -> common) with
      | [ p ] -> Some p
      | [] -> Error.fail span "the rays of the fan do not meet at one point of the paper"
      | _ ->
          Error.fail ~hint:"narrow a ray to one layer with &" span
            "the vertex lies at several points of the paper")

(* the faces of [g] a flat hinge joins to face [i] *)
let flat_neighbours (g : Fold_state.t) (i : int) : int list =
  Array.to_list (Fold_state.hinges g)
  |> List.filter_map (fun (h : Fold_state.hinge) ->
         if Num.sign h.Fold_state.angle <> 0 then None
         else if h.Fold_state.fa = i then Some h.Fold_state.fb
         else if h.Fold_state.fb = i then Some h.Fold_state.fa
         else None)

(* whether the table segment from [v] to [far] and the chord [c] on the same
   line overlap in positive length *)
let overlaps (v : Geom.point) (far : Geom.point) (c : (Geom.point * Geom.point) option) =
  match c with
  | None -> false
  | Some (p, q) ->
      let dot a b =
        Num.add
          (Num.mul (Num.sub a.Geom.x v.Geom.x) (Num.sub b.Geom.x v.Geom.x))
          (Num.mul (Num.sub a.Geom.y v.Geom.y) (Num.sub b.Geom.y v.Geom.y))
      in
      let l = dot far far and tp = dot p far and tq = dot q far in
      let lo, hi = if Num.compare tp tq <= 0 then (tp, tq) else (tq, tp) in
      Num.sign hi > 0 && Num.compare lo l < 0

(* The faces of [g] a ray that is a table line runs through, on the
   half-line from its table vertex [v] through [far]: the faces at the paper
   point [p] it enters, and every face a flat hinge joins to one of them
   that it enters. A folded hinge ends the ray's reach, so a construction
   runs through the layers that meet at [p] and no further. *)
let line_faces (g : Fold_state.t) ~(v : Geom.point) ~(p : Geom.point)
    ~(far : Geom.point) : int list =
  let pre = Fold_state.faces g in
  let line = Geom.line_through v far in
  let along q =
    Num.add
      (Num.mul (Num.sub q.Geom.x v.Geom.x) (Num.sub far.Geom.x v.Geom.x))
      (Num.mul (Num.sub q.Geom.y v.Geom.y) (Num.sub far.Geom.y v.Geom.y))
  in
  let enters i =
    match Geom.clip_line_to_convex line (Fold_state.table_polygon_ccw g i) with
    | None -> false
    | Some (a, b) -> Num.sign (along a) > 0 || Num.sign (along b) > 0
  in
  let start =
    List.filter
      (fun i -> Geom.in_convex_polygon pre.(i) p && enters i)
      (List.init (Array.length pre) Fun.id)
  in
  let seen = Array.make (Array.length pre) false in
  List.iter (fun i -> seen.(i) <- true) start;
  let q = Queue.create () in
  List.iter (fun i -> Queue.add i q) start;
  while not (Queue.is_empty q) do
    List.iter
      (fun k ->
        if (not seen.(k)) && enters k then begin
          seen.(k) <- true;
          Queue.add k q
        end)
      (flat_neighbours g (Queue.pop q))
  done;
  List.filter (fun i -> seen.(i)) (List.init (Array.length pre) Fun.id)

(* The faces of [pre] that hold each face of [st], by the paper centroid;
   -1 where none does. *)
let parents (pre : Geom.point array array) (st : Fold_state.t) : int array =
  Array.map
    (fun (f : Geom.point array) ->
      let m = Num.of_int (Array.length f) in
      let sum get = Array.fold_left (fun acc p -> Num.add acc (get p)) Num.zero f in
      let c =
        { Geom.x = Num.div (sum (fun p -> p.Geom.x)) m;
          y = Num.div (sum (fun p -> p.Geom.y)) m }
      in
      let found = ref (-1) in
      Array.iteri
        (fun j p -> if !found < 0 && Geom.in_convex_polygon p c then found := j)
        pre;
      !found)
    (Fold_state.faces st)

(* The parts of [g] the hinges [cut] separate: per face, the number of its
   part, from 0. A path from face to face crosses hinges only, never a single
   point. *)
let parts (g : Fold_state.t) ~(cut : int -> bool) : int array =
  let nf = Array.length (Fold_state.faces g) in
  let adj = Array.make nf [] in
  Array.iteri
    (fun i (h : Fold_state.hinge) ->
      if not (cut i) then begin
        adj.(h.Fold_state.fa) <- h.Fold_state.fb :: adj.(h.Fold_state.fa);
        adj.(h.Fold_state.fb) <- h.Fold_state.fa :: adj.(h.Fold_state.fb)
      end)
    (Fold_state.hinges g);
  let part = Array.make nf (-1) in
  let next = ref 0 in
  for i = 0 to nf - 1 do
    if part.(i) < 0 then begin
      let q = Queue.create () in
      part.(i) <- !next;
      Queue.add i q;
      while not (Queue.is_empty q) do
        List.iter
          (fun b ->
            if part.(b) < 0 then begin
              part.(b) <- !next;
              Queue.add b q
            end)
          adj.(Queue.pop q)
      done;
      incr next
    end
  done;
  part

(* The part of largest area on the paper. [None] when two parts share the
   largest area. *)
let largest (g : Fold_state.t) (part : int array) : int option =
  let faces = Fold_state.faces g in
  let n = Array.fold_left max (-1) part + 1 in
  let area = Array.make n Num.zero in
  Array.iteri
    (fun i f ->
      let a = Geom.signed_area f in
      area.(part.(i)) <- Num.add area.(part.(i)) (if Num.sign a < 0 then Num.neg a else a))
    faces;
  let best = ref [] in
  Array.iteri
    (fun k a ->
      match !best with
      | b :: _ when Num.compare a area.(b) < 0 -> ()
      | b :: _ when Num.compare a area.(b) = 0 -> best := k :: !best
      | _ -> best := [ k ])
    area;
  match !best with [ k ] -> Some k | _ -> None

(* The name of a point of the program on the paper polygon [poly], the
   first in alphabetical order, if one lies there. *)
let named_on (ctx : Ctx.ctx) (poly : Geom.point array) : string option =
  List.concat_map
    (fun (s : Ctx.scope) ->
      Hashtbl.fold
        (fun k p acc ->
          if Ctx.is_temp k || not (Geom.in_convex_polygon poly p) then acc else k :: acc)
        s.Ctx.points [])
    ctx.Ctx.scopes
  |> List.sort compare
  |> function [] -> None | k :: _ -> Some k

(* The layer check of the fan at the table points [v] (spec multifold,
   "A fan moves every part the stayer does not hold"): a face of
   [pre] under [v] that holds a moving face of [st] and on which no hinge of
   the fan lies makes the write undefined. [parent] maps a face of [st] to
   the face of [pre] that holds it, [tip] tells the moving faces, and
   [fan_hinge] the hinges of the fan. Returns the error message for the
   first such layer. *)
let unfolded_layer (ctx : Ctx.ctx) ~(pre : Fold_state.t) ~(st : Fold_state.t)
    ~(v : Geom.point list) ~(parent : int array) ~(tip : bool array)
    ~(fan_hinge : int -> bool) : string option =
  let npre = Array.length (Fold_state.faces pre) in
  let moves = Array.make npre false and folds = Array.make npre false in
  Array.iteri (fun i t -> if t && parent.(i) >= 0 then moves.(parent.(i)) <- true) tip;
  Array.iteri
    (fun i (h : Fold_state.hinge) ->
      if fan_hinge i then
        List.iter
          (fun f -> if parent.(f) >= 0 then folds.(parent.(f)) <- true)
          [ h.Fold_state.fa; h.Fold_state.fb ])
    (Fold_state.hinges st);
  let under i =
    List.exists (Geom.in_convex_polygon (Fold_state.table_polygon_ccw pre i)) v
  in
  List.find_opt (fun i -> moves.(i) && (not folds.(i)) && under i) (List.init npre Fun.id)
  |> Option.map (fun i ->
         match named_on ctx (Fold_state.faces pre).(i) with
         | Some k ->
             Printf.sprintf "the layer of .%s lies under the vertex and moves, but %s"
               k Collapse.e_unfolded_layer
         | None -> "a layer under the vertex moves, but " ^ Collapse.e_unfolded_layer)
