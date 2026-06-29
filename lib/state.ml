(** The crease pattern being built: deduplicated vertices and edges. *)

type assignment = Boundary | Crease

type provenance = {
  axiom : string;
  sources : string list;
  span : Error.span;
  name : string option;
}

type edge = {
  v0 : int;
  v1 : int;
  assign : assignment;
  prov : provenance option;
}

type t = { verts : Geom.point Dynarray.t; edges : edge Dynarray.t }

let create () : t = { verts = Dynarray.create (); edges = Dynarray.create () }

let add_vertex (t : t) (p : Geom.point) : int =
  let n = Dynarray.length t.verts in
  let rec find i =
    if i >= n then -1
    else if Geom.point_equal p (Dynarray.get t.verts i) then i
    else find (i + 1)
  in
  let idx = find 0 in
  if idx >= 0 then idx
  else begin
    Dynarray.add_last t.verts p;
    n
  end

let add_edge (t : t) (e : edge) : unit = Dynarray.add_last t.edges e
