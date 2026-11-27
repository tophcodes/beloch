(** The fan, the one operation every folding verb goes through: it moves
    each piece by the reflections across the changing hinges on its paper
    path (spec multifold, "A fan moves each piece by the changing hinges on
    its paper path") and searches the layer order over the units and
    conditions the verb gives (spec layer-order, "A verb gives the units of
    its fan's layer search"). The vertex enters through what the verb hands
    over: the scored state, the tip, the face that stays and the role of
    each hinge. [Axis_fan] builds them for a vertex at the point at infinity
    of an axis (`fold`, `unfold`, `reverse`), [Collapse], [Squash] and
    [Flatten_fans] for a vertex on the table (`flatten`, `squash`). *)

type role = Keep | Fold | Try

type t = {
  piece : int array;
  flips : bool array;
  letters : (int * int * int * bool) list;
  before : Fold_state.t;
  geometry : (Fold_state.geometry, Fold_state.violation) result Lazy.t;
}

let geometry (f : t) = Lazy.force f.geometry

(* The choices are enumerated whole, so the work doubles with every [Try]
   hinge; a fan in the corpus has a handful at most. A search that
   propagates each choice along the paths would prune the rest. *)
let make (g : Fold_state.t) ~(root : int) ~(tip : bool array)
    ~(names : int option array) ~(role : role array) ~(nelem : int)
    ~(side : int -> int -> int -> (int * int) option) : t list option =
  let faces = Fold_state.faces g in
  let nf = Array.length faces in
  let old_hinges = Fold_state.hinges g in
  let nh = Array.length old_hinges in
  let touches_tip (h : Fold_state.hinge) =
    tip.(h.Fold_state.fa) || tip.(h.Fold_state.fb)
  in
  let tries = List.filter (fun i -> role.(i) = Try) (List.init nh Fun.id) in
  let hinge_line i =
    let ta, tb = Fold_state.hinge_table_segment g i in
    Geom.line_through ta tb
  in
  let adj = Array.make nf [] in
  Array.iteri
    (fun i (h : Fold_state.hinge) ->
      adj.(h.Fold_state.fa) <- i :: adj.(h.Fold_state.fa);
      adj.(h.Fold_state.fb) <- i :: adj.(h.Fold_state.fb))
    old_hinges;
  let same_iso a b =
    Isometry.is_identity (Isometry.compose (Isometry.inverse a) b)
  in
  (* the motion of every face under one choice, or None when two paths to a
     face disagree; the faces outside the tip stay *)
  let motions_of (change : bool array) : Isometry.t array option =
    let m = Array.make nf None in
    let queue = Queue.create () in
    Array.iteri
      (fun i t ->
        if not t then begin
          m.(i) <- Some Isometry.identity;
          Queue.add i queue
        end)
      tip;
    let ok = ref true in
    while !ok && not (Queue.is_empty queue) do
      let a = Queue.pop queue in
      let ma = Option.get m.(a) in
      List.iter
        (fun hi ->
          if !ok then begin
            let h = old_hinges.(hi) in
            let b = if h.Fold_state.fa = a then h.Fold_state.fb else h.Fold_state.fa in
            let mb =
              if change.(hi) then
                Isometry.compose ma (Isometry.reflect_across_line (hinge_line hi))
              else ma
            in
            match m.(b) with
            | None ->
                m.(b) <- Some mb;
                Queue.add b queue
            | Some x -> if not (same_iso x mb) then ok := false
          end)
        adj.(a)
    done;
    if !ok && Array.for_all Option.is_some m then Some (Array.map Option.get m)
    else None
  in
  let build (change : bool array) (motion : Isometry.t array) : t =
    (* the pieces: the faces that share one motion *)
    let reps = ref [] in
    let piece =
      Array.init nf (fun i ->
          match List.find_opt (fun (m, _) -> same_iso m motion.(i)) !reps with
          | Some (_, id) -> id
          | None ->
              let id = List.length !reps in
              reps := (motion.(i), id) :: !reps;
              id)
    in
    let opened i =
      change.(i) && Num.sign old_hinges.(i).Fold_state.angle <> 0
    in
    (* The letter of an element holds at each hinge it names whose face on
       the clockwise side of the ray lies above no such face of another
       hinge it names; the other hinges it names take whatever letter the
       layer order gives them. A hinge that opens has no letter, and a hinge
       whose faces move as one piece does not fold. *)
    let letters =
      List.concat_map
        (fun k ->
          let named = ref [] in
          Array.iteri
            (fun i (h : Fold_state.hinge) ->
              if names.(i) = Some k && touches_tip h && not (opened i) then
                match side k h.Fold_state.fa h.Fold_state.fb with
                | Some s -> named := s :: !named
                | None -> ())
            old_hinges;
          let named = List.rev !named in
          List.filter_map
            (fun (fl, fo) ->
              if
                List.exists (fun (fl', _) -> Fold_state.above g fl fl') named
                || piece.(fl) = piece.(fo)
              then None
              else
                let down =
                  Isometry.det_sign
                    (Isometry.compose motion.(fl) (Fold_state.face_iso2 g fl))
                  < 0
                in
                Some (k, fl, fo, down))
            named)
        (List.init nelem Fun.id)
    in
    if root < 0 then
      invalid_arg "Fan.make: no face stays (unreachable, the verb names one)";
    let new_hinges =
      Array.mapi
        (fun i (h : Fold_state.hinge) ->
          if change.(i) then
            { h with
              Fold_state.angle =
                (if Num.sign h.Fold_state.angle = 0 then Num.one else Num.zero)
            }
          else h)
        old_hinges
    in
    { piece; flips = Array.map (fun m -> Isometry.det_sign m < 0) motion;
      letters; before = g;
      geometry =
        lazy
          (Fold_state.geometry ~base:(Fold_state.face_iso g root) ~faces
             ~hinges:new_hinges ~root ()) }
  in
  let fans =
    List.filter_map
      (fun mask ->
        let change = Array.map (fun r -> r = Fold) role in
        List.iteri
          (fun bit i -> if mask land (1 lsl bit) <> 0 then change.(i) <- true)
          tries;
        match motions_of change with
        | Some motion
          when Array.exists2
                 (fun t m -> t && not (Isometry.is_identity m))
                 tip motion ->
            Some (build change motion)
        | _ -> None)
      (List.init (1 lsl List.length tries) Fun.id)
  in
  if fans = [] then None else Some fans

type conditions =
  | Letters of bool array
  | Opening of Fold_state.reverse_fan * (bool array * Fold_state.placement) list

let stackings (f : t) (c : conditions) :
    (Fold_state.t list, Fold_state.violation) result =
  match Lazy.force f.geometry with
  | Error v -> Error v
  | Ok geo -> (
      match c with
      | Letters valley ->
          (* a valley puts the face across the ray above the face on its
             clockwise side, as seen from that side's final face *)
          let fixed =
            List.map
              (fun (k, fl, fo, down) ->
                if valley.(k) <> down then (fo, fl) else (fl, fo))
              f.letters
          in
          let before i j =
            match Fold_state.rel f.before i j with
            | Fold_state.Above -> 1
            | Fold_state.Below -> -1
            | Fold_state.Apart -> 0
          in
          Fold_state.unit_orders ~marks:(Fold_state.marks f.before) geo
            ~unit_of:f.piece ~before ~turned:f.flips
            ~across:(fun _ _ -> None) ~fixed
      | Opening (cut, blocks) ->
          Fold_state.fold_opening cut geo ~turned:f.flips ~blocks)
