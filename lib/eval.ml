(** Evaluate a program to a list of creases, resolving names and applying axioms.
    Geometry is exact; preconditions are reported as Error.Beloch_error. *)

type crease = { line : Geom.line; prov : State.provenance }

let corners : (string * Geom.point) list =
  let q = Q.of_int in
  [ ("a", { Geom.x = q 0; y = q 0 });
    ("b", { Geom.x = q 1; y = q 0 });
    ("c", { Geom.x = q 1; y = q 1 });
    ("d", { Geom.x = q 0; y = q 1 }) ]

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
    | None -> Error.fail cr.cspan (Printf.sprintf "undefined crease --%s" cr.cname)
  in
  let eval_axiom (span : Error.span) (ax : Ast.axiom) : Geom.line * string * string list =
    match ax with
    | Ast.Through (p, q) ->
        let pp = lookup_point p and qq = lookup_point q in
        if Geom.point_equal pp qq then
          Error.fail span "axiom 1 needs two distinct points";
        (Geom.line_through pp qq, "axiom1", [ "." ^ p.name; "." ^ q.name ])
    | Ast.FoldOnto (p, q) ->
        let pp = lookup_point p and qq = lookup_point q in
        if Geom.point_equal pp qq then
          Error.fail span "axiom 2 needs two distinct points";
        (Geom.perpendicular_bisector pp qq, "axiom2", [ "." ^ p.name; "." ^ q.name ])
    | Ast.Perp (p, l) ->
        let pp = lookup_point p in
        let ll = lookup_crease l in
        ( Geom.perpendicular_through ll pp,
          "axiom3",
          [ "." ^ p.name; "--" ^ l.cname ] )
  in
  List.iter
    (fun stmt ->
      match stmt with
      | Ast.Crease (name_opt, ax, span) ->
          let line, axiom, sources = eval_axiom span ax in
          (match name_opt with
           | Some n -> Hashtbl.replace creases n line
           | None -> ());
          out := { line; prov = { State.axiom; sources; span; name = name_opt } } :: !out
      | Ast.Point (n, Ast.Cross (c1, c2), span) ->
          let l1 = lookup_crease c1 and l2 = lookup_crease c2 in
          (match Geom.intersection l1 l2 with
           | None -> Error.fail span "creases are parallel; no intersection"
           | Some p ->
               if not (Geom.in_unit_square p) then
                 Error.fail span "intersection lies off the paper";
               Hashtbl.replace points n p))
    prog;
  List.rev !out
