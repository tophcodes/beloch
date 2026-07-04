(** Sparse layer order for folded states. Stores, for each face, the relation
    to every face it OVERLAPS on the table (Above/Below/Apart); non-overlapping
    pairs are absent. Built by an exact sweep-and-prune broad phase so
    distributed patterns cost O(n log n + overlapping pairs) instead of O(n²).
    The spatial index only culls candidate pairs; overlap is always decided by
    the exact Geom.convex_overlap. *)

type rel = Above | Below | Apart

let negate = function Above -> Below | Below -> Above | Apart -> Apart

(* adj.(i) maps j -> relation of i to j, for every j overlapping i. Symmetric:
   adj.(i)[j] = r  ⟺  adj.(j)[i] = negate r. *)
type t = { n : int; adj : (int, rel) Hashtbl.t array }

let get (t : t) (i : int) (j : int) : rel =
  if i = j then Apart
  else match Hashtbl.find_opt t.adj.(i) j with Some r -> r | None -> Apart

(* exact table-space bounding box of a polygon: (xmin, xmax, ymin, ymax) *)
let bbox (poly : Geom.point array) : Num.t * Num.t * Num.t * Num.t =
  let x0 = poly.(0).Geom.x and y0 = poly.(0).Geom.y in
  let xmin = ref x0 and xmax = ref x0 and ymin = ref y0 and ymax = ref y0 in
  Array.iter
    (fun (p : Geom.point) ->
      if Num.compare p.Geom.x !xmin < 0 then xmin := p.Geom.x;
      if Num.compare p.Geom.x !xmax > 0 then xmax := p.Geom.x;
      if Num.compare p.Geom.y !ymin < 0 then ymin := p.Geom.y;
      if Num.compare p.Geom.y !ymax > 0 then ymax := p.Geom.y)
    poly;
  (!xmin, !xmax, !ymin, !ymax)

let build (polys : Geom.point array array) (rel_of : int -> int -> rel) : t =
  let n = Array.length polys in
  let adj = Array.init n (fun _ -> Hashtbl.create 8) in
  if n > 1 then begin
    let boxes = Array.map bbox polys in
    (* indices sorted by bbox xmin, ascending *)
    let order = Array.init n (fun i -> i) in
    Array.sort
      (fun a b ->
        let (xa, _, _, _) = boxes.(a) and (xb, _, _, _) = boxes.(b) in
        Num.compare xa xb)
      order;
    (* sweep: active list holds indices whose xmax >= current xmin *)
    let active = ref [] in
    Array.iter
      (fun i ->
        let (xmin_i, _, ymin_i, ymax_i) = boxes.(i) in
        (* drop actives ending before i starts *)
        active := List.filter (fun k -> let (_, xmax_k, _, _) = boxes.(k) in
                                        Num.compare xmax_k xmin_i >= 0) !active;
        List.iter
          (fun k ->
            (* x-intervals overlap by construction; check y-interval overlap *)
            let (_, _, ymin_k, ymax_k) = boxes.(k) in
            if Num.compare ymin_i ymax_k <= 0 && Num.compare ymin_k ymax_i <= 0
               && Geom.convex_overlap polys.(i) polys.(k)
            then begin
              (* store both directions; rel_of is called canonically as (min,max) *)
              let a = min i k and b = max i k in
              let r = rel_of a b in
              Hashtbl.replace adj.(a) b r;
              Hashtbl.replace adj.(b) a (negate r)
            end)
          !active;
        active := i :: !active)
      order
  end;
  { n; adj }

(* Ascending (i, then j) so downstream messages (validity cycle/tortilla) name a
   deterministic pair, matching the old dense ascending double-loop and being
   stable across Hashtbl implementations. *)
let iter (t : t) (f : int -> int -> rel -> unit) : unit =
  for i = 0 to t.n - 1 do
    let js =
      Hashtbl.fold (fun j r acc -> if i < j then (j, r) :: acc else acc) t.adj.(i) []
    in
    List.iter (fun (j, r) -> f i j r)
      (List.sort (fun (a, _) (b, _) -> compare a b) js)
  done

let above_neighbors (t : t) (i : int) : int list =
  if i < 0 || i >= t.n then []
  else
    Hashtbl.fold (fun j r acc -> if r = Above then j :: acc else acc) t.adj.(i) []
    |> List.sort compare

(* Reverse the layer stack of an n-face state: remap face k ↦ n-1-k and negate
   every relation. Precondition: n >= t.n (callers pass n = the face count). *)
let flip (t : t) (n : int) : t =
  let adj = Array.init n (fun _ -> Hashtbl.create 8) in
  for i = 0 to t.n - 1 do
    Hashtbl.iter (fun j r -> Hashtbl.replace adj.(n - 1 - i) (n - 1 - j) (negate r))
      t.adj.(i)
  done;
  { n; adj }
