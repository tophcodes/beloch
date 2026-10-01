(** The sheet a program folds ([def-sheet]): the unfolded state it starts
    from and the outline of that state, in paper coordinates. *)

type side = Geom.point * Geom.point

type t = {
  start : Fold_state.t;  (** the unfolded state the program starts from *)
  outline : side list;
      (** the sides of the sheet's boundary, counter-clockwise, paper space *)
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
