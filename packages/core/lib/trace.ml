type removal = By_paper | By_toward | By_moving

type candidate = {
  line : Geom.line;
  removed_by : removal option;
  selected : bool;
}

type conic = { focus : Geom.point; directrix : Geom.line }

type entry = {
  statement : int;
  frame : int;
  axiom : string;
  toward : Geom.point option;
  candidates : candidate list;
  conics : conic list;
}

let num x = `Float (Num.to_float x)
let point (p : Geom.point) = `List [ num p.Geom.x; num p.Geom.y ]
let line (l : Geom.line) = `List [ num l.Geom.a; num l.Geom.b; num l.Geom.c ]

let removal_json = function
  | None -> `Null
  | Some By_paper -> `String "paper"
  | Some By_toward -> `String "toward"
  | Some By_moving -> `String "moving"

let to_json (e : entry) : Yojson.Safe.t =
  `Assoc
    ([
       ("statement", `Int e.statement);
       ("frame_index", `Int e.frame);
       ("axiom", `String e.axiom);
       ("toward", match e.toward with Some p -> point p | None -> `Null);
       ( "candidates",
         `List
           (List.map
              (fun c ->
                `Assoc
                  [
                    ("line", line c.line);
                    ("removed_by", removal_json c.removed_by);
                    ("selected", `Bool c.selected);
                  ])
              e.candidates) );
     ]
    @
    match e.conics with
    | [] -> []
    | cs ->
        [
          ( "conics",
            `List
              (List.map
                 (fun c ->
                   `Assoc [ ("focus", point c.focus); ("directrix", line c.directrix) ])
                 cs) );
        ])
