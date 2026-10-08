(** The sheet a program folds ([def-sheet]): the unfolded state it starts
    from and the outline of that state, in paper coordinates. *)

type side = Geom.point * Geom.point

type t = {
  start : Fold_state.t;  (** the unfolded state the program starts from *)
  outline : side list;
      (** the sides of the sheet's boundary, counter-clockwise, paper space *)
  joins : int list;
      (** the creases whose flat hinges only divide the sheet into convex
          faces: no crease of the sheet, written as FOLD join edges *)
}

(* The corners of the square of side [s], counter-clockwise from the origin. *)
let square_corners (s : Num.t) : Geom.point array =
  let z = Num.zero in
  [| { Geom.x = z; y = z }; { x = s; y = z }; { x = s; y = s }; { x = z; y = s } |]

let square (s : Num.t) : t =
  let c = square_corners s in
  {
    start = Fold_state.flat [| c |];
    outline = List.init 4 (fun i -> (c.(i), c.((i + 1) mod 4)));
    joins = [];
  }

(* Whether the segment from [pa] to [pb] lies on the boundary of the sheet. *)
let on_boundary (sh : t) (pa : Geom.point) (pb : Geom.point) : bool =
  List.exists
    (fun s -> Geom.on_segment s pa && Geom.on_segment s pb)
    sh.outline

(* One entry per line the outline runs along, in the order of the outline:
   the paper line and the two furthest-out points of the sides on it. *)
let boundary_lines (sh : t) : (Geom.line * side) list =
  let lines =
    List.fold_left
      (fun acc (a, b) ->
        let l = Geom.line_through a b in
        if List.exists (fun l' -> Geom.same_line l l') acc then acc
        else l :: acc)
      [] sh.outline
    |> List.rev
  in
  List.map
    (fun l ->
      let on_l (a, b) =
        Geom.side_of_line l a = 0 && Geom.side_of_line l b = 0
      in
      match Geom.material_bundle (List.filter on_l sh.outline) with
      | Some ext -> (l, ext)
      | None -> assert false (* every line comes from a side of positive length *))
    lines

(* Where paper line [l] crosses the sheet, as one bundle: the two
   furthest-out points of its chords through the faces of the unfolded
   state. [None] when it crosses no face along a positive length. *)
let clip (sh : t) (l : Geom.line) : side option =
  Fold_state.faces sh.start |> Array.to_list
  |> List.filter_map (Geom.clip_line_to_convex l)
  |> Geom.material_bundle

(* ---- A sheet trimmed from a flap (docs/reference/BELOCH.md, "Sheets") ---- *)

let point_at ((p, q) : side) (t : Num.t) : Geom.point =
  { Geom.x = Num.add p.Geom.x (Num.mul t (Num.sub q.Geom.x p.Geom.x));
    y = Num.add p.Geom.y (Num.mul t (Num.sub q.Geom.y p.Geom.y)) }

let sides_of (f : Geom.point array) : side list =
  let n = Array.length f in
  List.init n (fun i -> (f.(i), f.((i + 1) mod n)))

(* The parts of the sides of [faces] that no other face's side covers: the
   boundary of their union, each part running the way its face runs. *)
let boundary_sides (faces : Geom.point array list) : side list =
  let indexed = List.mapi (fun i f -> (i, f)) faces in
  List.concat_map
    (fun (i, f) ->
      List.concat_map
        (fun ((p, q) as s) ->
          let l = Geom.line_through p q in
          let covered =
            List.concat_map
              (fun (j, g) ->
                if i = j then []
                else
                  List.filter_map
                    (fun (r, u) ->
                      if Geom.side_of_line l r <> 0 || Geom.side_of_line l u <> 0
                      then None
                      else
                        let tr = Geom.seg_param s r and tu = Geom.seg_param s u in
                        let lo = if Num.compare tr tu <= 0 then tr else tu in
                        let hi = if Num.compare tr tu <= 0 then tu else tr in
                        let lo = if Num.sign lo < 0 then Num.zero else lo in
                        let hi = if Num.compare hi Num.one > 0 then Num.one else hi in
                        if Num.compare lo hi < 0 then Some (lo, hi) else None)
                    (sides_of g))
              indexed
            |> List.sort (fun (a, _) (b, _) -> Num.compare a b)
          in
          (* walk [0, 1] and keep what the sorted cover leaves open *)
          let rec open_parts from = function
            | [] -> if Num.compare from Num.one < 0 then [ (from, Num.one) ] else []
            | (lo, hi) :: rest ->
                let gap = if Num.compare from lo < 0 then [ (from, lo) ] else [] in
                let from = if Num.compare hi from > 0 then hi else from in
                gap @ open_parts from rest
          in
          List.map (fun (a, b) -> (point_at s a, point_at s b)) (open_parts Num.zero covered))
        (sides_of f))
    indexed

(* The closed loops [sides] form, each side followed by one that starts
   where it ends. *)
let loops (sides : side list) : side list list =
  let rec follow loop start (cur : side) rest =
    if Geom.point_equal (snd cur) start then (List.rev (cur :: loop), rest)
    else
      match List.partition (fun (a, _) -> Geom.point_equal a (snd cur)) rest with
      | next :: others, rest' -> follow (cur :: loop) start next (others @ rest')
      | [], _ -> (List.rev (cur :: loop), rest)
  in
  let rec go acc = function
    | [] -> List.rev acc
    | s :: rest ->
        let loop, rest = follow [] (fst s) s rest in
        go (loop :: acc) rest
  in
  go [] sides

(* The union of convex CCW polygons [p] and [q] when [p] has the side from
   [u] to [v], [q] the side from [v] to [u], and the union is convex. *)
let merge_convex (p : Geom.point array) (q : Geom.point array) : Geom.point array option =
  let n = Array.length p and m = Array.length q in
  let find poly len a b =
    let rec go i =
      if i >= len then None
      else if Geom.point_equal poly.(i) a && Geom.point_equal poly.((i + 1) mod len) b
      then Some i
      else go (i + 1)
    in
    go 0
  in
  let rec shared i =
    if i >= n then None
    else
      let u = p.(i) and v = p.((i + 1) mod n) in
      match find q m v u with Some j -> Some (i, j) | None -> shared (i + 1)
  in
  match shared 0 with
  | None -> None
  | Some (i, j) ->
      (* p from v round to u, then q strictly between u and v *)
      let from_p = List.init n (fun k -> p.((i + 1 + k) mod n)) in
      let from_q = List.init (m - 2) (fun k -> q.((j + 2 + k) mod m)) in
      let r = Array.of_list (from_p @ from_q) in
      let k = Array.length r in
      let convex =
        List.for_all
          (fun a ->
            let o = r.(a) and b = r.((a + 1) mod k) and c = r.((a + 2) mod k) in
            Num.sign
              (Num.sub
                 (Num.mul (Num.sub b.Geom.x o.Geom.x) (Num.sub c.Geom.y o.Geom.y))
                 (Num.mul (Num.sub b.Geom.y o.Geom.y) (Num.sub c.Geom.x o.Geom.x)))
            >= 0)
          (List.init k Fun.id)
      in
      if convex then Some r else None

(* The part of mark [m] on the faces [faces], or [None] when no part of it
   lies on them. *)
let restrict_mark (faces : Geom.point array list) (m : Fold_state.mark) :
    Fold_state.mark option =
  match m.Fold_state.mgeom with
  | Fold_state.MPoint p ->
      if List.exists (fun f -> Geom.in_convex_polygon f p) faces then
        Some { m with mprov = None }
      else None
  | Fold_state.MSeg (a, b) -> (
      let l = Geom.line_through a b in
      let pieces =
        List.filter_map
          (fun f ->
            match Geom.clip_line_to_convex l f with
            | None -> None
            | Some (c, d) ->
                let tc = Geom.seg_param (a, b) c and td = Geom.seg_param (a, b) d in
                let lo = if Num.compare tc td <= 0 then tc else td in
                let hi = if Num.compare tc td <= 0 then td else tc in
                let lo = if Num.sign lo < 0 then Num.zero else lo in
                let hi = if Num.compare hi Num.one > 0 then Num.one else hi in
                if Num.compare lo hi < 0 then Some (point_at (a, b) lo, point_at (a, b) hi)
                else None)
          faces
      in
      match Geom.material_bundle pieces with
      | Some (c, d) -> Some { m with mgeom = Fold_state.MSeg (c, d); mprov = None }
      | None -> None)

(* The sheet trimmed from the flap [flap] (face indices) of state [st]: its
   faces in paper coordinates, unfolded, with the marks and flat hinges on
   it. A flat hinge of a crease for which [folded] holds merges its two
   faces into one where their union is convex, and stays a flat hinge where
   it is not, since a face is convex; its crease is then one of [joins]. [Error `Hole] when the flap's outline is
   more than one loop. *)
let trim (st : Fold_state.t) (flap : int list) ~(folded : int -> bool) :
    (t, [ `Hole ]) result =
  let all_faces = Fold_state.faces st in
  let hs = Fold_state.hinges st in
  let faces = Array.of_list (List.map (fun i -> Some all_faces.(i)) flap) in
  let index = Hashtbl.create 8 in
  List.iteri (fun k i -> Hashtbl.replace index i k) flap;
  (* hinges inside the flap, by position in [faces] *)
  let inner =
    Array.to_list hs
    |> List.filter_map (fun (h : Fold_state.hinge) ->
           match (Hashtbl.find_opt index h.fa, Hashtbl.find_opt index h.fb) with
           | Some a, Some b -> Some (ref a, ref b, h)
           | _ -> None)
  in
  (* a merged face lives at the lower of its two indices *)
  let kept =
    List.filter
      (fun (a, b, (h : Fold_state.hinge)) ->
        if not (folded h.crease_id) then true
        else if !a = !b then false
        else
          match (faces.(!a), faces.(!b)) with
          | Some p, Some q -> (
              match merge_convex p q with
              | Some r ->
                  let lo = min !a !b and hi = max !a !b in
                  faces.(lo) <- Some r;
                  faces.(hi) <- None;
                  List.iter
                    (fun (a', b', _) ->
                      if !a' = hi then a' := lo;
                      if !b' = hi then b' := lo)
                    inner;
                  false
              | None -> true)
          | _ -> true)
      inner
  in
  let alive = List.filter_map Fun.id (Array.to_list faces) in
  let renum = Array.make (Array.length faces) (-1) in
  ignore
    (Array.fold_left
       (fun (k, i) f ->
         (match f with Some _ -> renum.(i) <- k | None -> ());
         ((if f = None then k else k + 1), i + 1))
       (0, 0) faces);
  let hinges =
    List.map
      (fun (a, b, (h : Fold_state.hinge)) ->
        { h with fa = renum.(!a); fb = renum.(!b); prov = None })
      kept
  in
  let marks =
    Array.to_list (Fold_state.marks st) |> List.filter_map (restrict_mark alive)
  in
  match loops (boundary_sides alive) with
  | [ outline ] ->
      Ok
        {
          start =
            Fold_state.flat ~hinges:(Array.of_list hinges)
              ~marks:(Array.of_list marks) (Array.of_list alive);
          outline;
          joins =
            List.sort_uniq compare
              (List.filter_map
                 (fun (_, _, (h : Fold_state.hinge)) ->
                   if folded h.crease_id then Some h.crease_id else None)
                 kept);
        }
  | _ -> Error `Hole
