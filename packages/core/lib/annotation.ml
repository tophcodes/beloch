(** Annotations: the static checks and the read of their arguments. *)

(* ---- static checks ---- *)

type shape = Operand of [ `Point | `Line | `Flap ] | Text | Number | Word of string

let shape_of (a : Ast.annot_arg) : shape =
  match a.Ast.av with
  | Ast.AvPoint _ -> Operand `Point
  | Ast.AvLine _ | Ast.AvConstruction _ -> Operand `Line
  | Ast.AvFlap _ -> Operand `Flap
  | Ast.AvText _ -> Text
  | Ast.AvNumber _ -> Number
  | Ast.AvWord w -> Word w

let vocabulary = [ "step"; "label"; "say"; "call"; "orient" ]
let directions = [ "up"; "right"; "down"; "left" ]
let axes = [ "vertical"; "horizontal" ]

let check_args (a : Ast.annotation) : unit =
  let shapes = List.map shape_of a.Ast.a_args in
  let wrong usage = Error.fail a.Ast.a_span (Printf.sprintf "@%s takes %s" a.Ast.a_key usage) in
  match a.Ast.a_ns with
  | Some ns ->
      List.iter
        (fun (arg : Ast.annot_arg) ->
          match arg.Ast.av with
          | Ast.AvWord w ->
              Error.fail
                ~hint:(Printf.sprintf "write it as text: \"%s\"" w)
                arg.Ast.av_span
                (Printf.sprintf
                   "a bare word means nothing to @%s:%s; only the vocabulary \
                    takes words"
                   ns a.Ast.a_key)
          | _ -> ())
        a.Ast.a_args
  | None -> (
      match (a.Ast.a_key, shapes) with
      | "step", ([] | [ Word _ ] | [ Text ] | [ Word _; Text ]) -> ()
      | "step", _ -> wrong "an optional label and an optional text, in that order"
      | "label", [ Word _ ] -> ()
      | "label", _ -> wrong "one label"
      | "say", [ Text ] -> ()
      | "say", _ -> wrong "one text"
      | "call", [ Operand _; Text ] -> ()
      | "call", _ -> wrong "a point, a line or a flap, and the text a reader knows it by"
      | "orient", [ Operand `Point; Word d ] when List.mem d directions -> ()
      | "orient", [ Operand `Point; Operand `Point; Word d ] when List.mem d directions -> ()
      | "orient", [ Operand `Line; Word x ] when List.mem x axes -> ()
      | "orient", _ ->
          wrong
            "a point and a direction, two points and a direction, or a line \
             and an axis; a direction is up, right, down or left, an axis \
             vertical or horizontal"
      | key, _ ->
          Error.fail
            ~hint:
              (Printf.sprintf
                 "the vocabulary is %s; an output's own annotation carries its \
                  namespace, as in @yr:%s"
                 (String.concat ", " vocabulary) key)
            a.Ast.a_span
            (Printf.sprintf "unknown annotation @%s" key))

let label_of (a : Ast.annotation) : (string * Error.span) option =
  match (a.Ast.a_ns, a.Ast.a_key, a.Ast.a_args) with
  | None, ("label" | "step"), { Ast.av = Ast.AvWord w; av_span } :: _ -> Some (w, av_span)
  | _ -> None

(* one statement list: the top level or one def body *)
let rec check_list (stmts : Ast.stmt list) : unit =
  let labels = Hashtbl.create 8 in
  let rec go (run : Ast.annotation list) = function
    | [] -> (
        match List.rev run with
        | first :: _ ->
            Error.fail first.Ast.a_span
              "an annotation belongs to the statement after it, and none follows"
        | [] -> ())
    | Ast.Annotation a :: rest ->
        check_args a;
        (match label_of a with
        | Some (w, sp) ->
            if Hashtbl.mem labels w then
              Error.fail sp (Printf.sprintf "the label %s is already used here" w);
            Hashtbl.replace labels w ()
        | None -> ());
        if a.Ast.a_ns = None && a.Ast.a_key = "step"
           && List.exists (fun (b : Ast.annotation) -> b.Ast.a_ns = None && b.Ast.a_key = "step") run
        then Error.fail a.Ast.a_span "a statement opens at most one step";
        go (a :: run) rest
    | Ast.Def (_, _, body, _) :: rest ->
        check_list body;
        go [] rest
    | _ :: rest -> go [] rest
  in
  go [] stmts

let check (prog : Ast.program) : unit = check_list prog

(* ---- reading the arguments ---- *)

(* Runs [f] and puts back everything a read may touch on its way: the state
   and the crease-id counter a materialised mark advances, the binding it
   promotes, and the references it records. *)
let read_only (ctx : Ctx.ctx) (f : unit -> 'a) : 'a =
  let state = !(ctx.Ctx.state) in
  let next_id = Fold_state.next_id_value () in
  let references = ctx.Ctx.references_rev in
  let lines = List.map (fun (s : Ctx.scope) -> (s, Hashtbl.copy s.Ctx.lines)) ctx.Ctx.scopes in
  Fun.protect f ~finally:(fun () ->
      ctx.Ctx.state := state;
      Fold_state.set_next_id next_id;
      ctx.Ctx.references_rev <- references;
      List.iter
        (fun ((s : Ctx.scope), saved) ->
          Hashtbl.reset s.Ctx.lines;
          Hashtbl.iter (Hashtbl.replace s.Ctx.lines) saved)
        lines)

let crease_id (ctx : Ctx.ctx) (lo : Ast.line_operand) : int option =
  match lo with
  | Ast.LNamed cr -> (
      match Ctx.find_crease_by_name ctx cr.Ast.cname with
      | Some (Ctx.Material (cid, _) | Ctx.Mark (cid, _)) -> Some cid
      | _ -> None)
  | Ast.LFilter _ | Ast.LUnion _ | Ast.LSelect _ -> None

let value (ctx : Ctx.ctx) (arg : Ast.annot_arg) : Ctx.annot_value =
  match arg.Ast.av with
  | Ast.AvPoint po -> Ctx.AvPoint (Resolve.resolve_point ctx po, Resolve.table_of ctx po)
  | Ast.AvLine lo -> Ctx.AvLine (Resolve.resolve_line ctx lo, crease_id ctx lo)
  | Ast.AvConstruction c ->
      let line =
        (* an annotation reads a line and evaluates no construction of the
           program, so it leaves the trace alone *)
        match snd (Axiom.axis_of ~trace:false ctx arg.Ast.av_span c) with
        | Axiom.Axis (axis, _, _) -> axis
        | Axiom.Ax5 p -> Axiom.select_axiom5_bind ~trace:false ctx arg.Ast.av_span p
      in
      Ctx.AvLine (line, None)
  | Ast.AvFlap f ->
      Ctx.AvFlap (Resolve.resolve_flap_cluster ctx (Ast.FlapSpec f) arg.Ast.av_span)
  | Ast.AvText t -> Ctx.AvText t
  | Ast.AvNumber q -> Ctx.AvNumber q
  | Ast.AvWord w -> Ctx.AvWord w

let resolve (ctx : Ctx.ctx) (a : Ast.annotation) : Ctx.annot_entry =
  let args =
    read_only ctx (fun () ->
        List.map (fun (arg : Ast.annot_arg) -> (value ctx arg, arg.Ast.av_span)) a.Ast.a_args)
  in
  {
    Ctx.an_ns = a.Ast.a_ns;
    an_key = a.Ast.a_key;
    an_args = args;
    an_span = a.Ast.a_span;
    an_frame_index = List.length ctx.Ctx.frames_rev;
    an_target = -1;
  }
