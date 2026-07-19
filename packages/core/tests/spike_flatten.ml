(* Spike: single-emergent swivel derive on the rabbit-ear.bel geometry.
   Vertex V = (1/2, sqrt5 - 2); given lines --ba=(V,a), --bb=(V,b), --v=(V,m).
   Hypothesis: R_ear = inverse(R_ba . R_bb . R_v) is a reflection through V whose
   axis is the emergent crease (~319 deg, meeting the base near x=0.766). *)

open Beloch

let mk x y = { Geom.x; y }
let half = Num.of_q (Q.of_ints 1 2)

let () =
  let s5 = Num.sqrt (Num.of_int 5) in
  let v = mk half (Num.sub s5 (Num.of_int 2)) in
  let a = mk Num.zero Num.zero in
  let b = mk Num.one Num.zero in
  let m = mk half Num.one in
  let line_ba = Geom.line_through v a in
  let line_bb = Geom.line_through v b in
  let line_v = Geom.line_through v m in
  let r_ba = Isometry.reflect_across_line line_ba in
  let r_bb = Isometry.reflect_across_line line_bb in
  let r_v = Isometry.reflect_across_line line_v in
  (* CCW given-ray order: ba(~25) , bb(~155) , v-down(270). ear inserted last. *)
  let p = Isometry.compose (Isometry.compose r_ba r_bb) r_v in
  let r_ear = Isometry.inverse p in
  Printf.printf "det(R_ear) = %d (expect -1 = reflection)\n"
    (Isometry.det_sign r_ear);
  let vf = Isometry.apply_point r_ear v in
  Printf.printf "R_ear fixes V: %b\n" (Geom.point_equal vf v);
  (* axis of the reflection: midpoint of a probe and its image lies on it *)
  let probe = mk (Num.add v.Geom.x Num.one) v.Geom.y in
  let rp = Isometry.apply_point r_ear probe in
  let mid =
    mk
      (Num.div (Num.add probe.Geom.x rp.Geom.x) (Num.of_int 2))
      (Num.div (Num.add probe.Geom.y rp.Geom.y) (Num.of_int 2))
  in
  let axis = Geom.line_through v mid in
  let dx = Num.sub mid.Geom.x v.Geom.x and dy = Num.sub mid.Geom.y v.Geom.y in
  let ang = atan2 (Num.to_float dy) (Num.to_float dx) *. 180. /. Float.pi in
  let ang = if ang < 0. then ang +. 360. else ang in
  Printf.printf "emergent axis direction = %.2f deg (line, so +/-180; expect ~319 or ~139)\n" ang;
  if Num.sign axis.Geom.a <> 0 then
    Printf.printf "axis meets base y=0 at x = %.4f (expect ~0.766)\n"
      (Num.to_float (Num.div axis.Geom.c axis.Geom.a));
  (* closure check: reflect across the 4 lines in CCW order = identity *)
  let r_ear_line = Isometry.reflect_across_line axis in
  let full =
    Isometry.compose (Isometry.compose (Isometry.compose r_ba r_bb) r_v)
      r_ear_line
  in
  let id_ok =
    Geom.point_equal (Isometry.apply_point full a) a
    && Geom.point_equal (Isometry.apply_point full b) b
  in
  Printf.printf "closure (4-line product = identity): %b\n" id_ok
