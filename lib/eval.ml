(** Evaluate a program to a list of creases, resolving names and applying
    axioms. Geometry is exact; preconditions are reported as Error.Beloch_error.
*)

type crease = { line : Geom.line; prov : State.provenance }

let corners : (string * Geom.point) list =
  let q = Num.of_int in
  [
    ("a", { Geom.x = q 0; y = q 0 });
    ("b", { Geom.x = q 1; y = q 0 });
    ("c", { Geom.x = q 1; y = q 1 });
    ("d", { Geom.x = q 0; y = q 1 });
  ]

let eval (prog : Ast.program) : crease list =
  let points : (string, Geom.point) Hashtbl.t = Hashtbl.create 16 in
  List.iter (fun (n, p) -> Hashtbl.replace points n p) corners;
  let creases : (string, Geom.line) Hashtbl.t = Hashtbl.create 16 in
  let out = ref [] in
  let lookup_point (pr : Ast.point_ref) : Geom.point =
    match Hashtbl.find_opt points pr.name with
    | Some p -> p
    | None -> Error.fail pr.span (Printf.sprintf "undefined point .%s" pr.name)
  in
  let lookup_crease (cr : Ast.crease_ref) : Geom.line =
    match Hashtbl.find_opt creases cr.cname with
    | Some l -> l
    | None ->
        Error.fail cr.cspan (Printf.sprintf "undefined crease --%s" cr.cname)
  in
  let eval_axiom (span : Error.span) (ax : Ast.axiom) :
      Geom.line * string * string list =
    match ax with
    | Ast.Through (p, q) ->
        let pp = lookup_point p and qq = lookup_point q in
        if Geom.point_equal pp qq then
          Error.fail span "axiom 1 needs two distinct points";
        (Geom.line_through pp qq, "axiom1", [ "." ^ p.name; "." ^ q.name ])
    | Ast.MapPoints (p, q) ->
        let pp = lookup_point p and qq = lookup_point q in
        if Geom.point_equal pp qq then
          Error.fail span "axiom 2 needs two distinct points";
        ( Geom.perpendicular_bisector pp qq,
          "axiom2",
          [ "." ^ p.name; "." ^ q.name ] )
    | Ast.Perp (p, l) ->
        let pp = lookup_point p in
        let ll = lookup_crease l in
        ( Geom.perpendicular_through ll pp,
          "axiom3",
          [ "." ^ p.name; "--" ^ l.cname ] )
    | Ast.MapLines (c1, c2, p_opt) -> (
        let l1 = lookup_crease c1 and l2 = lookup_crease c2 in
        let base = [ "--" ^ c1.cname; "--" ^ c2.cname ] in
        let eval_at (l : Geom.line) (pt : Geom.point) : Num.t =
          Num.sub
            (Num.add (Num.mul l.Geom.a pt.Geom.x) (Num.mul l.Geom.b pt.Geom.y))
            l.Geom.c
        in
        match Geom.angle_bisectors l1 l2 with
        | None ->
            (* parallel: identical line -> error, else the midline *)
            let k =
              if Num.sign l1.Geom.a <> 0 then Num.div l2.Geom.a l1.Geom.a
              else Num.div l2.Geom.b l1.Geom.b
            in
            if Num.equal l2.Geom.c (Num.mul k l1.Geom.c) then
              Error.fail span "lines are identical";
            (Geom.parallel_midline l1 l2, "axiom5", base)
        | Some (bis_eq, bis_opp) -> (
            match p_opt with
            | None -> Error.fail span "bisector is ambiguous; add `toward .p`"
            | Some pr ->
                let p = lookup_point pr in
                let s1 = Num.sign (eval_at l1 p)
                and s2 = Num.sign (eval_at l2 p) in
                if s1 = 0 || s2 = 0 then
                  Error.fail span
                    "reference point on a fold line; bisector ambiguous";
                let bis = if s1 = s2 then bis_eq else bis_opp in
                (bis, "axiom5", base @ [ "." ^ pr.name ])))
  in
  List.iter
    (fun stmt ->
      match stmt with
      | Ast.Crease (name_opt, ax, fold_opt, span) ->
          (match fold_opt with
          | Some _ -> Error.fail span "folding (@) is not yet implemented"
          | None -> ());
          let line, axiom, sources = eval_axiom span ax in
          (match name_opt with
          | Some n -> Hashtbl.replace creases n line
          | None -> ());
          out :=
            { line; prov = { State.axiom; sources; span; name = name_opt } }
            :: !out
      | Ast.Point (n, Ast.Cross (c1, c2), span) -> (
          let l1 = lookup_crease c1 and l2 = lookup_crease c2 in
          match Geom.intersection l1 l2 with
          | None -> Error.fail span "creases are parallel; no intersection"
          | Some p ->
              if not (Geom.in_unit_square p) then
                Error.fail span "intersection lies off the paper";
              Hashtbl.replace points n p))
    prog;
  List.rev !out
