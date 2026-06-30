(** Evaluate a program, resolving names and applying axioms. Geometry is exact;
    preconditions are reported as Error.Beloch_error. *)

let corners : (string * Geom.point) list =
  let q = Num.of_int in
  [
    ("a", { Geom.x = q 0; y = q 0 });
    ("b", { Geom.x = q 1; y = q 0 });
    ("c", { Geom.x = q 1; y = q 1 });
    ("d", { Geom.x = q 0; y = q 1 });
  ]

type folded = { state : Fold_state.t; creases : Fold_state.crease_record list }

let eval_folded (prog : Ast.program) : folded =
  let points : (string, Geom.point) Hashtbl.t = Hashtbl.create 16 in
  List.iter (fun (n, p) -> Hashtbl.replace points n p) corners;
  let creases_env : (string, Geom.line) Hashtbl.t = Hashtbl.create 16 in
  let state = ref Fold_state.init_square in
  let recs = ref [] in
  let lookup_point (pr : Ast.point_ref) : Geom.point =
    match Hashtbl.find_opt points pr.Ast.name with
    | Some p -> p
    | None ->
        Error.fail pr.Ast.span
          (Printf.sprintf "undefined point .%s" pr.Ast.name)
  in
  let table_of (pr : Ast.point_ref) : Geom.point =
    Fold_state.table_position !state (lookup_point pr)
  in
  let lookup_crease (cr : Ast.crease_ref) : Geom.line =
    match Hashtbl.find_opt creases_env cr.Ast.cname with
    | Some l -> l
    | None ->
        Error.fail cr.Ast.cspan
          (Printf.sprintf "undefined crease --%s" cr.Ast.cname)
  in
  (* axis line + provenance (axiom tag, source names), evaluated against the
     current table positions *)
  let axis_of (span : Error.span) (ax : Ast.axiom) :
      Geom.line * string * string list =
    match ax with
    | Ast.Through (p, q) ->
        let pp = table_of p and qq = table_of q in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf
               ".%s and .%s are at the same place, so there is no line through \
                them"
               p.Ast.name q.Ast.name);
        ( Geom.line_through pp qq,
          "axiom1",
          [ "." ^ p.Ast.name; "." ^ q.Ast.name ] )
    | Ast.MapPoints (p, q) ->
        let pp = table_of p and qq = table_of q in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf ".%s and .%s are already at the same place"
               p.Ast.name q.Ast.name);
        ( Geom.perpendicular_bisector pp qq,
          "axiom2",
          [ "." ^ p.Ast.name; "." ^ q.Ast.name ] )
    | Ast.Perp (p, l) ->
        ( Geom.perpendicular_through (lookup_crease l) (table_of p),
          "axiom3",
          [ "." ^ p.Ast.name; "--" ^ l.Ast.cname ] )
    | Ast.MapLines (c1, c2, p_opt) -> (
        let l1 = lookup_crease c1 and l2 = lookup_crease c2 in
        let base = [ "--" ^ c1.Ast.cname; "--" ^ c2.Ast.cname ] in
        let eval_at (l : Geom.line) (pt : Geom.point) : Num.t =
          Num.sub
            (Num.add (Num.mul l.Geom.a pt.Geom.x) (Num.mul l.Geom.b pt.Geom.y))
            l.Geom.c
        in
        match Geom.angle_bisectors l1 l2 with
        | None ->
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
                let p = table_of pr in
                let s1 = Num.sign (eval_at l1 p)
                and s2 = Num.sign (eval_at l2 p) in
                if s1 = 0 || s2 = 0 then
                  Error.fail span
                    "reference point on a fold line; bisector ambiguous";
                ( (if s1 = s2 then bis_eq else bis_opp),
                  "axiom5",
                  base @ [ "." ^ pr.Ast.name ] )))
  in
  List.iter
    (fun stmt ->
      match stmt with
      | Ast.Crease (name_opt, ax, fold_opt, span) -> (
          let axis, axiom, sources = axis_of span ax in
          (match name_opt with
          | Some n -> Hashtbl.replace creases_env n axis
          | None -> ());
          let prov : State.provenance option =
            Some { State.axiom; sources; span; name = name_opt }
          in
          match fold_opt with
          | None ->
              let st, rs = Fold_state.subdivide !state axis ~prov in
              state := st;
              recs := rs @ !recs
          | Some fs ->
              let move_side =
                match fs.Ast.moving with
                | Some pr ->
                    let s = Geom.side_of_line axis (table_of pr) in
                    if s = 0 then
                      Error.fail span "the moving point lies on the fold axis";
                    s
                | None -> (
                    match ax with
                    | Ast.MapPoints (p, _) ->
                        let s = Geom.side_of_line axis (table_of p) in
                        if s = 0 then
                          Error.fail span
                            "the moving point lies on the fold axis";
                        s
                    | _ ->
                        Error.fail span
                          "this fold needs `moving .p` to choose the side")
              in
              let valley = fs.Ast.direction = Ast.Valley in
              let st, rs =
                Fold_state.fold_with_records !state ~axis ~move_side ~valley
                  ~prov
              in
              state := st;
              recs := rs @ !recs)
      | Ast.Point (n, Ast.Cross (c1, c2), span) -> (
          let l1 = lookup_crease c1 and l2 = lookup_crease c2 in
          match Geom.intersection l1 l2 with
          | None -> Error.fail span "creases are parallel; no intersection"
          | Some tp -> (
              match Fold_state.paper_preimages !state tp with
              | [] ->
                  Error.fail span
                    (Printf.sprintf
                       ".%s: where --%s and --%s cross is off the paper" n
                       c1.Ast.cname c2.Ast.cname)
              | ps ->
                  (* Q2-B: resolve to the TOP layer at that table point — the
                     point on the visible topmost layer, the one your hand would
                     touch. paper_preimages is bottom->top, so take the last. *)
                  Hashtbl.replace points n (List.nth ps (List.length ps - 1)))))
    prog;
  { state = !state; creases = !recs }
