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
  let lookup_crease (cr : Ast.crease_ref) : Geom.line =
    match Hashtbl.find_opt creases_env cr.Ast.cname with
    | Some l -> l
    | None ->
        Error.fail cr.Ast.cspan
          (Printf.sprintf "undefined crease --%s" cr.Ast.cname)
  in
  (* render an operand back to source text for provenance + error messages *)
  let rec pstr (po : Ast.point_operand) : string =
    match po with
    | Ast.PNamed pr -> "." ^ pr.Ast.name
    | Ast.PCross (l1, l2, _) -> Printf.sprintf ".(%s %s)" (lstr l1) (lstr l2)
  and lstr (lo : Ast.line_operand) : string =
    match lo with
    | Ast.LNamed cr -> "--" ^ cr.Ast.cname
    | Ast.LThrough (p1, p2, _) -> Printf.sprintf "--(%s %s)" (pstr p1) (pstr p2)
  in
  (* resolve a point operand to its material PAPER coordinate, a line operand to
     its TABLE-space line; mutually recursive for nesting. *)
  let rec resolve_point (po : Ast.point_operand) : Geom.point =
    match po with
    | Ast.PNamed pr -> lookup_point pr
    | Ast.PCross (l1, l2, span) -> (
        let a = resolve_line l1 and b = resolve_line l2 in
        match Geom.intersection a b with
        | None -> Error.fail span "creases are parallel; no intersection"
        | Some tp -> (
            match Fold_state.paper_preimages !state tp with
            | [] ->
                Error.fail span (Printf.sprintf "%s is off the paper" (pstr po))
            | ps -> List.nth ps (List.length ps - 1)))
  and resolve_line (lo : Ast.line_operand) : Geom.line =
    match lo with
    | Ast.LNamed cr -> lookup_crease cr
    | Ast.LThrough (p1, p2, span) ->
        let pp = Fold_state.table_position !state (resolve_point p1)
        and qq = Fold_state.table_position !state (resolve_point p2) in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf
               "%s and %s are at the same place, so there is no line through \
                them"
               (pstr p1) (pstr p2));
        Geom.line_through pp qq
  in
  let table_of (po : Ast.point_operand) : Geom.point =
    Fold_state.table_position !state (resolve_point po)
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
               "%s and %s are at the same place, so there is no line through \
                them"
               (pstr p) (pstr q));
        (Geom.line_through pp qq, "axiom1", [ pstr p; pstr q ])
    | Ast.MapPoints (p, q) ->
        let pp = table_of p and qq = table_of q in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf "%s and %s are already at the same place" (pstr p)
               (pstr q));
        (Geom.perpendicular_bisector pp qq, "axiom2", [ pstr p; pstr q ])
    | Ast.Perp (p, l) ->
        ( Geom.perpendicular_through (resolve_line l) (table_of p),
          "axiom3",
          [ pstr p; lstr l ] )
    | Ast.MapOntoLine (p, l1, l2) -> (
        let pp = table_of p and ll1 = resolve_line l1 and ll2 = resolve_line l2 in
        match Geom.project_crease pp ll1 ll2 with
        | None ->
            Error.fail span
              (Printf.sprintf "map %s onto %s perp %s: lines are parallel, no fold exists"
                 (pstr p) (lstr l1) (lstr l2))
        | Some crease -> (crease, "axiom4", [ pstr p; lstr l1; lstr l2 ]))
    | Ast.MapLines (l1, l2, p_opt) -> (
        let la = resolve_line l1 and lb = resolve_line l2 in
        let base = [ lstr l1; lstr l2 ] in
        let eval_at (l : Geom.line) (pt : Geom.point) : Num.t =
          Num.sub
            (Num.add (Num.mul l.Geom.a pt.Geom.x) (Num.mul l.Geom.b pt.Geom.y))
            l.Geom.c
        in
        match Geom.angle_bisectors la lb with
        | None ->
            let k =
              if Num.sign la.Geom.a <> 0 then Num.div lb.Geom.a la.Geom.a
              else Num.div lb.Geom.b la.Geom.b
            in
            if Num.equal lb.Geom.c (Num.mul k la.Geom.c) then
              Error.fail span "lines are identical";
            (Geom.parallel_midline la lb, "axiom5", base)
        | Some (bis_eq, bis_opp) -> (
            match p_opt with
            | None -> Error.fail span "bisector is ambiguous; add `toward .p`"
            | Some po ->
                let p = table_of po in
                let s1 = Num.sign (eval_at la p)
                and s2 = Num.sign (eval_at lb p) in
                if s1 = 0 || s2 = 0 then
                  Error.fail span
                    "reference point on a fold line; bisector ambiguous";
                ( (if s1 = s2 then bis_eq else bis_opp),
                  "axiom5",
                  base @ [ pstr po ] )))
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
                | Some po ->
                    let s = Geom.side_of_line axis (table_of po) in
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
      | Ast.Point (n, Ast.Cross (l1, l2), span) ->
          Hashtbl.replace points n (resolve_point (Ast.PCross (l1, l2, span)))
      | Ast.Flip _ -> state := Fold_state.flip !state)
    prog;
  { state = !state; creases = !recs }
