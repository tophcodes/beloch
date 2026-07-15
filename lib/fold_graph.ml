(** The 3D-native folded-state core (issue #48, spec 2026-07-15-fold-state-3d-
    rewrite). Faces = 2D paper polygons; hinges = the face-adjacency graph. A
    face's 3D placement is DERIVED as the product of hinge motions along a path
    from the root — so adjacent faces differ by exactly their hinge's motion and
    a torn state cannot be written down. Flat-first: hinge angle (dihedral/π) ∈
    {0, ±1}; |angle|=1 folds via a half-turn about the crease line (= the 2D
    reflection on z=0), reproducing today's flat folds. General rπ is Stage B. *)

module I3 = Isometry3

type face = Geom.point array

type hinge = { fa : int; fb : int; line : Geom.line; angle : Num.t }

type t = { faces : face array; hinges : hinge array; root : int }

(* 3D motion a folded hinge applies (in the sheet frame): a half-turn about the
   crease line embedded in the z=0 plane. Flat crease (angle=0) → identity.
   Flat-first: |angle|=1 → half-turn; the sign (M vs V) does NOT change the flat
   placement (±π about the same axis coincide) — M/V is the layer order. *)
let hinge_motion (h : hinge) : I3.t =
  if Num.sign h.angle = 0 then I3.identity
  else
    let l = h.line in
    let on =
      if Num.sign l.Geom.a <> 0 then
        { I3.x = Num.div l.Geom.c l.Geom.a; y = Num.zero; z = Num.zero }
      else { I3.x = Num.zero; y = Num.div l.Geom.c l.Geom.b; z = Num.zero }
    in
    let dir = { I3.x = Num.neg l.Geom.b; y = l.Geom.a; z = Num.zero } in
    I3.half_turn_about_line ~on ~dir

(* Derived placements: BFS from [root] over the hinge graph; crossing a hinge
   composes its motion onto the already-placed face's placement,
   iso.(other) = compose iso.(fi) (hinge_motion h). half-turns are involutions,
   so crossing a hinge either direction uses the same motion (flat-first). *)
let face_isos (g : t) : I3.t array =
  let n = Array.length g.faces in
  let iso = Array.make n I3.identity in
  let seen = Array.make n false in
  let queue = Queue.create () in
  seen.(g.root) <- true;
  Queue.push g.root queue;
  while not (Queue.is_empty queue) do
    let fi = Queue.pop queue in
    Array.iter
      (fun h ->
        let step other =
          if not seen.(other) then begin
            seen.(other) <- true;
            iso.(other) <- I3.compose iso.(fi) (hinge_motion h);
            Queue.push other queue
          end
        in
        if h.fa = fi then step h.fb else if h.fb = fi then step h.fa)
      g.hinges
  done;
  iso

let face_iso (g : t) (i : int) : I3.t = (face_isos g).(i)
