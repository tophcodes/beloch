(** Extract the bounded faces of the planar crease graph by half-edge traversal.
    Each face is returned as vertex indices in counter-clockwise order; the
    unbounded outer face (clockwise / negative signed area) is dropped. *)

let extract (st : State.t) : int array list =
  let n = Dynarray.length st.State.verts in
  let pos i = Dynarray.get st.State.verts i in
  (* adjacency: deduplicated neighbour indices per vertex *)
  let adj = Array.make n [] in
  Dynarray.iter
    (fun (e : State.edge) ->
      let a = e.State.v0 and b = e.State.v1 in
      if not (List.mem b adj.(a)) then adj.(a) <- b :: adj.(a);
      if not (List.mem a adj.(b)) then adj.(b) <- a :: adj.(b))
    st.State.edges;
  (* sort each vertex's neighbours counter-clockwise around it *)
  let adj =
    Array.mapi
      (fun i ns ->
        List.sort (fun x y -> Geom.ccw_compare ~center:(pos i) (pos x) (pos y)) ns)
      adj
  in
  let index_in lst u =
    let rec go k = function
      | [] -> -1
      | h :: t -> if h = u then k else go (k + 1) t
    in
    go 0 lst
  in
  (* next half-edge after (u -> w): at w, the clockwise neighbour of u, i.e. the
     predecessor of u in w's CCW order *)
  let next u w =
    let ring = adj.(w) in
    let deg = List.length ring in
    let i = index_in ring u in
    let j = (i - 1 + deg) mod deg in
    (w, List.nth ring j)
  in
  let visited = Hashtbl.create 64 in
  let faces = ref [] in
  Dynarray.iter
    (fun (e : State.edge) ->
      List.iter
        (fun (a, b) ->
          if not (Hashtbl.mem visited (a, b)) then begin
            let cycle = ref [] in
            let cu = ref a and cw = ref b in
            let go = ref true in
            while !go do
              Hashtbl.replace visited (!cu, !cw) ();
              cycle := !cu :: !cycle;
              let nu, nw = next !cu !cw in
              cu := nu;
              cw := nw;
              if !cu = a && !cw = b then go := false
            done;
            let verts = Array.of_list (List.rev !cycle) in
            let pts = Array.map pos verts in
            if Num.sign (Geom.signed_area pts) > 0 then faces := verts :: !faces
          end)
        [ (e.State.v0, e.State.v1); (e.State.v1, e.State.v0) ])
    st.State.edges;
  List.rev !faces
