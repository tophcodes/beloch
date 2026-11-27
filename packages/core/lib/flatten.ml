(** The generator half of the flatten solver.
    Given a set of material creases ("rays") sharing one interior vertex O, an
    ODD ray count means one emergent ray is part of the solution space;
    [candidates] generates the geometric completions that could close the vertex
   : same-direction filter, per-line dedup, and a tag that says whether the
    completion lies on a new line (`LineNew`) or on the far side of a given
    one (`OppositeRay`). It does NOT check feasibility or M/V and does NOT
    pick a winner.

    Choosing among them is [Flatten_solve]'s job: it enumerates every
    Maekawa-consistent M/V pattern ([mv_patterns], pure and unit-testable) over
    each candidate's full ray set, tries each via [Collapse.collapse_all_patterns], pools
    the results, and keeps the states the items leave. Feasibility-filtering
    and the items belong there rather than here because they need [Collapse.collapse_all_patterns] and
    [Ast.mv_constraint], neither of which this module should depend on beyond
    the generator's own geometry. *)

let e_infeasible = "vertex not flat-foldable toward that side"

(* The +1-eigenvector direction of a reflection's linear part. A reflection
   fixing the origin is a symmetric orthogonal matrix (m01 = m10), so either
   off-diagonal entry gives the eigenvector directly; a zero off-diagonal
   means the matrix is already diagonal (axis along a coordinate direction). *)
let axis_direction (r : Isometry.t) : Num.t * Num.t =
  if Num.sign r.Isometry.m01 <> 0 then
    (r.Isometry.m01, Num.sub Num.one r.Isometry.m00)
  else if Num.sign (Num.sub r.Isometry.m00 Num.one) = 0 then (Num.one, Num.zero)
  else (Num.zero, Num.one)

(* Does point [q] (a direction from [o]) lie strictly between rays
   [lo] and [hi] going CCW from [lo] to [hi]? [lo]/[hi] are consecutive rays
   in a CCW-sorted array, so exactly one cyclic pair (the array's own seam)
   has [lo] sorting *after* [hi]; that is the wraparound gap, handled by the
   "or" branch instead of the ordinary "and" (Geom.ccw_compare's linear order
   has one cut, at the positive-x direction). *)
let in_gap (o : Geom.point) (lo : Geom.point) (hi : Geom.point) (q : Geom.point)
    : bool =
  if Geom.ccw_compare ~center:o lo hi < 0 then
    Geom.ccw_compare ~center:o lo q < 0 && Geom.ccw_compare ~center:o q hi < 0
  else
    Geom.ccw_compare ~center:o lo q < 0 || Geom.ccw_compare ~center:o q hi < 0

(* The candidate GENERATOR (spec step 1's odd branch): every geometric
   completion of the given rays that closes Kawasaki at [o], tagged by its
   kind (§4.9: the emergent crease is "not
   constructible by any Huzita axiom": a completion that only re-uses a
   given line's far side is the degenerate, `OppositeRay` case; a completion
   on a new line is `LineNew`). No feasibility check and no
   item: both are the caller's job, over the pooled
   realizations of every (candidate x M/V pattern). *)
let candidates (o : Geom.point) ~(fixed : (Geom.point * Collapse.elem) list) :
    (Geom.line * Geom.point * [ `LineNew | `OppositeRay ]) list =
  let sorted = Array.of_list (Collapse.sort_ccw o (List.map snd fixed)) in
  let k = Array.length sorted in
  let refl i =
    let far, _ = sorted.(i) in
    Isometry.reflect_across_line (Geom.line_through o far)
  in
  let compose_range lo hi =
    (* [R_lo] ∘ R_(lo+1) ∘ … ∘ R_(hi-1), identity if lo >= hi *)
    let acc = ref Isometry.identity in
    for i = lo to hi - 1 do
      acc := Isometry.compose !acc (refl i)
    done;
    !acc
  in
  (* Each candidate carries its emergent LINE *and* a point on its emergent
     RAY: O plus the axis eigenvector, signed so that the point lands in the
     candidate's own gap. The point gives the ray's direction only: the
     eigenvector's length is arbitrary, so the point may lie short of where
     the ray leaves the paper or beyond it. The ray direction is
     geometrically fixed (chosen by [in_gap], a CCW test) unlike the
     eigenvector's sign, which is arbitrary. *)
  let raw = ref [] in
  for j = 0 to k - 1 do
    let before = compose_range 0 j in
    let after = compose_range j k in
    let cand =
      Isometry.compose (Isometry.inverse before) (Isometry.inverse after)
    in
    if
      Isometry.det_sign cand < 0
      && Geom.point_equal (Isometry.apply_point cand o) o
    then begin
      let dx, dy = axis_direction cand in
      let plus = { Geom.x = Num.add o.Geom.x dx; y = Num.add o.Geom.y dy } in
      let minus = { Geom.x = Num.sub o.Geom.x dx; y = Num.sub o.Geom.y dy } in
      let lo_far, _ = sorted.((j - 1 + k) mod k) in
      let hi_far, _ = sorted.(j mod k) in
      let ray =
        if in_gap o lo_far hi_far plus then Some plus
        else if in_gap o lo_far hi_far minus then Some minus
        else None
      in
      match ray with
      | Some r -> raw := (Geom.line_through o r, r) :: !raw
      | None -> ()
    end
  done;
  (* Dedup coincident candidates by LINE: the same emergent axis can close two
     different gaps (both its rays fill a gap), landing twice. Two lines
     coincide iff parallel and one shares the other's point. *)
  let same (l1 : Geom.line) (l2 : Geom.line) =
    Geom.parallel l1 l2
    && Num.sign
         (Num.sub (Num.mul l1.Geom.a l2.Geom.c) (Num.mul l2.Geom.a l1.Geom.c)) = 0
    && Num.sign
         (Num.sub (Num.mul l1.Geom.b l2.Geom.c) (Num.mul l2.Geom.b l1.Geom.c)) = 0
  in
  (* Drop candidates whose emergent RAY points in the same direction as a
     GIVEN ray: that is the degenerate "extend a line already drawn"
     completion. The OPPOSITE ray of a given line is NOT degenerate: it is a
     new crease, so this filters by direction, not by line
     ([Geom.ccw_compare] = 0 iff same direction from O). *)
  let genuine (_, ray) =
    not (Array.exists (fun (far, _) -> Geom.ccw_compare ~center:o far ray = 0) sorted)
  in
  let uniq =
    List.fold_left
      (fun acc (l, r) ->
        if (not (genuine (l, r))) || List.exists (fun (l', _) -> same l l') acc
        then acc
        else (l, r) :: acc)
      [] !raw
  in
  let given_lines =
    Array.to_list (Array.map (fun (far, _) -> Geom.line_through o far) sorted)
  in
  let line_new (l, _) =
    not (List.exists (fun g -> Geom.parallel l g) given_lines)
  in
  List.map
    (fun (l, r) -> (l, r, if line_new (l, r) then `LineNew else `OppositeRay))
    uniq

(* Pure, unit-testable Maekawa-consistent M/V pattern enumerator (spec step
   3): given a per-ray constraint list, every [bool list] (parallel to the
   input, true = valley) honoring every pinned slot (`MvValley` -> true,
   `MvMountain` -> false) and satisfying Maekawa (|#M - #V| = 2) over the
   free slots. [] if no assignment satisfies both. *)
let mv_patterns (constraints : Ast.mv_constraint list) : bool list list =
  let n = List.length constraints in
  let base = Array.make n false in
  let free_idx = ref [] in
  List.iteri
    (fun i (c : Ast.mv_constraint) ->
      match c with
      | Ast.MvValley -> base.(i) <- true
      | Ast.MvMountain -> base.(i) <- false
      | Ast.MvFree -> free_idx := i :: !free_idx)
    constraints;
  let free_idx = List.rev !free_idx in
  let rec free_combos = function
    | [] -> [ [] ]
    | _ :: rest -> List.concat_map (fun t -> [ true :: t; false :: t ]) (free_combos rest)
  in
  free_combos free_idx
  |> List.filter_map (fun combo ->
         let arr = Array.copy base in
         List.iter2 (fun i v -> arr.(i) <- v) free_idx combo;
         let lst = Array.to_list arr in
         let nv = List.length (List.filter (fun v -> v) lst) in
         let nm = n - nv in
         if abs (nm - nv) = 2 then Some lst else None)

(* The error of a flatten that leaves several states, and its hint: the
   items that would leave one (spec multifold,
   "Every item of a flatten is a condition on its states"). [letters s] is the
   letter of every given ray in the state [s], true for a valley, parallel to
   [items]; an item spells a ray with a letter, and [None] stands for a ray the
   program cannot letter, because it lettered it already or wrote no item for
   it. Up to [max_listed] states get an item each: the letter of one ray that no
   other state shares, or the letters of two rays where one does not part it
   from the rest. A state that no letter parts from another differs from it in
   its layers only, and gets an `over` item, or two, of the named points
   [points] instead: [(name, face)] is a point and the one face of the state the
   flatten reads that holds it, and [above s i j] says whether face [i] lies
   above face [j] in [s], as an `over` item compares them. Where no item of
   named points parts the state, the hint says so. Above [max_listed] the hint
   names the ray whose letter splits the states most evenly. Returns the
   message, the hint and the item the hint names for each state, [None] where
   it names none. Ceiling: the pair searches are quadratic in the rays per
   state and in the items of named points that hold in a state, which stays
   small for the programs written so far; a program with hundreds of named
   points would want the faces that differ found first. *)
let max_listed = 4

(* a ray item with its letter, as the program writes it *)
let ray_item (name : string) (valley : bool) : string =
  Printf.sprintf "(%s %s)" name (if valley then "valley" else "mountain")

let suggest ~(verb : string) ~(items : (bool -> string) option list)
    ~(letters : 'a -> bool list) ~(points : (string * int) list)
    ~(above : 'a -> int -> int -> bool) (states : 'a list) :
    string * string * string option list =
  let n = List.length states in
  let message = Printf.sprintf "%s is ambiguous: %d realizations" verb n in
  let item k l = (Option.get (List.nth items k)) l in
  let ls = List.map letters states in
  let ks =
    List.filteri (fun _ k -> List.nth items k <> None)
      (List.init (List.length items) Fun.id)
  in
  if n <= max_listed then begin
    let parts i own =
      let others = List.filteri (fun j _ -> j <> i) ls in
      let apart sel = List.for_all (fun o -> not (sel o)) others in
      match List.find_opt (fun k -> apart (fun o -> List.nth o k = List.nth own k)) ks with
      | Some k -> Some (item k (List.nth own k))
      | None ->
          List.find_map
            (fun k1 ->
              List.find_map
                (fun k2 ->
                  if
                    k1 < k2
                    && apart (fun o ->
                           List.nth o k1 = List.nth own k1
                           && List.nth o k2 = List.nth own k2)
                  then Some (item k1 (List.nth own k1) ^ " and " ^ item k2 (List.nth own k2))
                  else None)
                ks)
            ks
    in
    (* every over item of two named points in different faces, with the
       states it holds in *)
    let overs =
      lazy
      (List.concat_map
        (fun (p, fp) ->
          List.filter_map
            (fun (q, fq) ->
              if fp = fq then None
              else
                Some
                  ( Printf.sprintf "(.%s over .%s)" p q,
                    List.map (fun s -> above s fp fq) states ))
            points)
        points)
    in
    let ordered i =
      let holds = List.filter (fun (_, h) -> List.nth h i) (Lazy.force overs) in
      let apart sel =
        List.for_all Fun.id (List.filteri (fun j _ -> j <> i) (List.init n sel))
      in
      match List.find_opt (fun (_, h) -> apart (fun j -> not (List.nth h j))) holds with
      | Some (t, _) -> Some t
      | None ->
          List.find_map
            (fun (t1, h1) ->
              List.find_map
                (fun (t2, h2) ->
                  if
                    t1 < t2
                    && apart (fun j -> not (List.nth h1 j && List.nth h2 j))
                  then Some (t1 ^ " and " ^ t2)
                  else None)
                holds)
            holds
    in
    let found =
      List.mapi
        (fun i own -> match parts i own with Some t -> Some t | None -> ordered i)
        ls
    in
    let items = List.filter_map Fun.id found in
    let layered = List.length (List.filter Option.is_none found) in
    let listed =
      if items = [] then []
      else [ "each of these keeps one state: " ^ String.concat "; " items ]
    in
    let layers =
      if layered = 0 then []
      else
        [ Printf.sprintf
            "%d states differ in their layers only, and no named point lies \
             in the faces whose order parts them"
            layered ]
    in
    (message, String.concat "; " (listed @ layers), found)
  end
  else
    let split k =
      let v = List.length (List.filter (fun l -> List.nth l k) ls) in
      (abs ((2 * v) - n), k, v)
    in
    let none = List.map (fun _ -> None) states in
    match List.sort compare (List.map split ks) with
    | (_, k, v) :: _ when v > 0 && v < n ->
        ( message,
          Printf.sprintf "add %s or %s: they keep %d and %d of the %d states"
            (item k true) (item k false) v (n - v) n,
          none )
    | _ ->
        ( message,
          "the states differ in their layers only, which an (.p over .q) item \
           orders",
          none )
