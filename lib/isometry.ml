(** Exact 2D isometry: an orthogonal 2×2 matrix (det ±1) plus a translation, all
    in [Num]. Used to place each face of the paper onto the table. *)

type t = {
  m00 : Num.t;
  m01 : Num.t;
  m10 : Num.t;
  m11 : Num.t;
  tx : Num.t;
  ty : Num.t;
}

let identity : t =
  {
    m00 = Num.one;
    m01 = Num.zero;
    m10 = Num.zero;
    m11 = Num.one;
    tx = Num.zero;
    ty = Num.zero;
  }

let apply_point (i : t) (p : Geom.point) : Geom.point =
  {
    Geom.x =
      Num.add (Num.add (Num.mul i.m00 p.Geom.x) (Num.mul i.m01 p.Geom.y)) i.tx;
    y = Num.add (Num.add (Num.mul i.m10 p.Geom.x) (Num.mul i.m11 p.Geom.y)) i.ty;
  }

(* (compose a b)(p) = a (b p) *)
let compose (a : t) (b : t) : t =
  {
    m00 = Num.add (Num.mul a.m00 b.m00) (Num.mul a.m01 b.m10);
    m01 = Num.add (Num.mul a.m00 b.m01) (Num.mul a.m01 b.m11);
    m10 = Num.add (Num.mul a.m10 b.m00) (Num.mul a.m11 b.m10);
    m11 = Num.add (Num.mul a.m10 b.m01) (Num.mul a.m11 b.m11);
    tx = Num.add (Num.add (Num.mul a.m00 b.tx) (Num.mul a.m01 b.ty)) a.tx;
    ty = Num.add (Num.add (Num.mul a.m10 b.tx) (Num.mul a.m11 b.ty)) a.ty;
  }

let det_sign (i : t) : int =
  Num.sign (Num.sub (Num.mul i.m00 i.m11) (Num.mul i.m01 i.m10))

(* M is orthogonal, so M⁻¹ = Mᵀ; the inverse maps q ↦ Mᵀ (q − t). *)
let inverse (i : t) : t =
  let m00 = i.m00 and m01 = i.m10 and m10 = i.m01 and m11 = i.m11 in
  {
    m00;
    m01;
    m10;
    m11;
    tx = Num.neg (Num.add (Num.mul m00 i.tx) (Num.mul m01 i.ty));
    ty = Num.neg (Num.add (Num.mul m10 i.tx) (Num.mul m11 i.ty));
  }

(* Reflection across a·x + b·y = c as an isometry:
   M = I − 2/(a²+b²) [[a² ab];[ab b²]] ;  t = 2c/(a²+b²) (a, b). *)
let reflect_across_line (l : Geom.line) : t =
  let n2 = Num.add (Num.mul l.Geom.a l.Geom.a) (Num.mul l.Geom.b l.Geom.b) in
  let f = Num.div (Num.of_int 2) n2 in
  {
    m00 = Num.sub Num.one (Num.mul f (Num.mul l.Geom.a l.Geom.a));
    m01 = Num.neg (Num.mul f (Num.mul l.Geom.a l.Geom.b));
    m10 = Num.neg (Num.mul f (Num.mul l.Geom.a l.Geom.b));
    m11 = Num.sub Num.one (Num.mul f (Num.mul l.Geom.b l.Geom.b));
    tx = Num.mul f (Num.mul l.Geom.c l.Geom.a);
    ty = Num.mul f (Num.mul l.Geom.c l.Geom.b);
  }
