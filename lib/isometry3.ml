(** Exact 3D rigid motion: a 3×3 orthogonal matrix (det ±1) plus a translation,
    all in [Num]. Places a face of the paper into 3-space. Flat folds use only
    [half_turn_about_line]; general rotation-by-θ (θ = rπ) is Stage B. *)

type point = { x : Num.t; y : Num.t; z : Num.t }

type t = {
  m00 : Num.t; m01 : Num.t; m02 : Num.t;
  m10 : Num.t; m11 : Num.t; m12 : Num.t;
  m20 : Num.t; m21 : Num.t; m22 : Num.t;
  tx : Num.t; ty : Num.t; tz : Num.t;
}

let identity : t =
  let o = Num.one and z = Num.zero in
  { m00 = o; m01 = z; m02 = z;
    m10 = z; m11 = o; m12 = z;
    m20 = z; m21 = z; m22 = o;
    tx = z; ty = z; tz = z }

let apply_point (i : t) (p : point) : point =
  let ( * ) = Num.mul and ( + ) = Num.add in
  { x = (i.m00 * p.x) + (i.m01 * p.y) + (i.m02 * p.z) + i.tx;
    y = (i.m10 * p.x) + (i.m11 * p.y) + (i.m12 * p.z) + i.ty;
    z = (i.m20 * p.x) + (i.m21 * p.y) + (i.m22 * p.z) + i.tz }

let compose (a : t) (b : t) : t =
  let ( * ) = Num.mul and ( + ) = Num.add in
  let r i0 i1 i2 j0 j1 j2 = (i0 * j0) + (i1 * j1) + (i2 * j2) in
  (* translation: a.M · b.t + a.t *)
  let tx = (a.m00 * b.tx) + (a.m01 * b.ty) + (a.m02 * b.tz) + a.tx in
  let ty = (a.m10 * b.tx) + (a.m11 * b.ty) + (a.m12 * b.tz) + a.ty in
  let tz = (a.m20 * b.tx) + (a.m21 * b.ty) + (a.m22 * b.tz) + a.tz in
  { m00 = r a.m00 a.m01 a.m02 b.m00 b.m10 b.m20;
    m01 = r a.m00 a.m01 a.m02 b.m01 b.m11 b.m21;
    m02 = r a.m00 a.m01 a.m02 b.m02 b.m12 b.m22;
    m10 = r a.m10 a.m11 a.m12 b.m00 b.m10 b.m20;
    m11 = r a.m10 a.m11 a.m12 b.m01 b.m11 b.m21;
    m12 = r a.m10 a.m11 a.m12 b.m02 b.m12 b.m22;
    m20 = r a.m20 a.m21 a.m22 b.m00 b.m10 b.m20;
    m21 = r a.m20 a.m21 a.m22 b.m01 b.m11 b.m21;
    m22 = r a.m20 a.m21 a.m22 b.m02 b.m12 b.m22;
    tx; ty; tz }

let det_sign (i : t) : int =
  let ( * ) = Num.mul and ( - ) = Num.sub and ( + ) = Num.add in
  let d =
    (i.m00 * ((i.m11 * i.m22) - (i.m12 * i.m21)))
    - (i.m01 * ((i.m10 * i.m22) - (i.m12 * i.m20)))
    + (i.m02 * ((i.m10 * i.m21) - (i.m11 * i.m20)))
  in
  Num.sign d

let inverse (i : t) : t =
  (* orthogonal M ⇒ M⁻¹ = Mᵀ; the motion q ↦ Mᵀ(q − t) *)
  let ( * ) = Num.mul and ( + ) = Num.add and neg = Num.neg in
  let tx = neg ((i.m00 * i.tx) + (i.m10 * i.ty) + (i.m20 * i.tz)) in
  let ty = neg ((i.m01 * i.tx) + (i.m11 * i.ty) + (i.m21 * i.tz)) in
  let tz = neg ((i.m02 * i.tx) + (i.m12 * i.ty) + (i.m22 * i.tz)) in
  { m00 = i.m00; m01 = i.m10; m02 = i.m20;
    m10 = i.m01; m11 = i.m11; m12 = i.m21;
    m20 = i.m02; m21 = i.m12; m22 = i.m22;
    tx; ty; tz }

let half_turn_about_line ~(on : point) ~(dir : point) : t =
  let ( * ) = Num.mul and ( + ) = Num.add and ( - ) = Num.sub in
  let dd = (dir.x * dir.x) + (dir.y * dir.y) + (dir.z * dir.z) in
  (* R = 2 (d dᵀ)/(d·d) − I ; entry (i,j) = 2 d_i d_j / dd − [i=j] *)
  let two = Num.of_int 2 in
  let e di dj diag =
    Num.sub (Num.div (Num.mul two (Num.mul di dj)) dd)
      (if diag then Num.one else Num.zero)
  in
  let m00 = e dir.x dir.x true  and m01 = e dir.x dir.y false and m02 = e dir.x dir.z false
  and m10 = e dir.y dir.x false and m11 = e dir.y dir.y true  and m12 = e dir.y dir.z false
  and m20 = e dir.z dir.x false and m21 = e dir.z dir.y false and m22 = e dir.z dir.z true in
  (* translation so [on] is fixed: t = on − R·on *)
  let rx = (m00 * on.x) + (m01 * on.y) + (m02 * on.z) in
  let ry = (m10 * on.x) + (m11 * on.y) + (m12 * on.z) in
  let rz = (m20 * on.x) + (m21 * on.y) + (m22 * on.z) in
  { m00; m01; m02; m10; m11; m12; m20; m21; m22;
    tx = on.x - rx; ty = on.y - ry; tz = on.z - rz }
