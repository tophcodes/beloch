(** Item classification. See items.mli for the module's place in the graph. *)

open Ast

let slot (verb : string) (head : string) (cell : 'a option ref)
    (span : Error.span) (v : 'a) : unit =
  match !cell with
  | Some _ -> Error.fail span (Printf.sprintf "only one %s item per %s" head verb)
  | None -> cell := Some v

let reject (verb : string) (head : string) (span : Error.span) : 'a =
  Error.fail span (Printf.sprintf "%s takes no (%s) item" verb head)

(* The word a message names an item by: its head token where it has one, its
   slot otherwise. *)
let head_of (it : raw_item) : string =
  match it with
  | RiConstruction _ -> "construction"
  | RiLine _ -> "axis"
  | RiMoving _ -> "moving"
  | RiUpTo _ -> "up to"
  | RiLetter (MvMountain, _) -> "mountain"
  | RiLetter (_, _) -> "valley"
  | RiPlace (PlaceOver, _, _) -> "over"
  | RiPlace (PlaceUnder, _, _) -> "under"
  | RiOutside _ -> "outside"
  | RiOn _ -> "on"
  | RiExtent (Between _, _) -> "between"
  | RiExtent (_, _) -> "at"
  | RiOrder _ -> "order"
  | RiStaying _ -> "staying"
  | RiSelection _ -> "toward"

let span_of (it : raw_item) : Error.span =
  match it with
  | RiConstruction (_, sp)
  | RiLine (_, _, sp)
  | RiMoving (_, sp)
  | RiUpTo (_, sp)
  | RiLetter (_, sp)
  | RiPlace (_, _, sp)
  | RiOutside sp
  | RiOn (_, sp)
  | RiExtent (_, sp)
  | RiOrder (_, _, sp)
  | RiStaying (_, sp)
  | RiSelection (_, sp) ->
      sp

let refuse (verb : string) (it : raw_item) : 'a =
  reject verb (head_of it) (span_of it)

(* ---- the axis slot, shared by mark, fold and reverse ---- *)

(* `(--d mountain)` is a ray item's spelling; under a verb that takes an axis
   the letter has no slot to go to. *)
let axis_item (verb : string) (cell : markable option ref) (it : raw_item) : bool
    =
  match it with
  | RiConstruction (c, sp) ->
      slot verb "axis" cell sp (MConstruction c);
      true
  | RiLine (lo, mv, sp) ->
      (match mv with
      | MvFree -> ()
      | MvMountain | MvValley ->
          Error.fail ~hint:"write (mountain) as its own item" sp
            "an axis item takes no mountain or valley");
      slot verb "axis" cell sp (MLine lo);
      true
  | _ -> false

let need_axis (verb : string) (cell : markable option ref) (span : Error.span) :
    markable =
  match !cell with
  | Some m -> m
  | None ->
      Error.fail span
        (Printf.sprintf "%s needs an axis item: a construction or a crease" verb)

let direction_of (mv : mv_constraint) : direction =
  match mv with MvMountain -> Mountain | MvValley | MvFree -> Valley

(* ---- the side items, shared by every statement over a construction ---- *)

(* `(toward …)` and `(moving …)` name the side that stays and the side that
   folds over (ADR 0031). *)
let side_item (verb : string) ~(toward : (toward_item * Error.span) option ref)
    ~(moving : (flap_arg * Error.span) option ref) (it : raw_item) : bool =
  match it with
  | RiSelection (t, sp) ->
      slot verb "toward" toward sp (t, sp);
      true
  | RiMoving (fa, sp) ->
      slot verb "moving" moving sp (fa, sp);
      true
  | _ -> false

(* the side items a verb collected, apart from where they stand *)
let sides_of toward moving : sides =
  { s_toward = Option.map fst !toward; s_moving = Option.map fst !moving;
    s_spans = { toward_span = Option.map snd !toward; moving_span = Option.map snd !moving } }

(* ---- the six verbs, and the binding of a construction ---- *)

let bind (name : string) (c : construction) (items : raw_item list)
    (span : Error.span) : stmt =
  let verb = "a binding" in
  let toward = ref None and moving = ref None in
  List.iter
    (fun it -> if not (side_item verb ~toward ~moving it) then refuse verb it)
    items;
  BindLine (name, c, sides_of toward moving, span)

let mark (items : raw_item list) (out : output) (span : Error.span) : stmt =
  let verb = "mark" in
  let axis = ref None
  and layer = ref None
  and extent = ref None
  and intent = ref None
  and toward = ref None
  and moving = ref None in
  List.iter
    (fun it ->
      if not (axis_item verb axis it || side_item verb ~toward ~moving it) then
        match it with
        | RiOn (fa, sp) -> slot verb "on" layer sp fa
        | RiExtent (e, sp) -> slot verb "extent" extent sp e
        | RiLetter (mv, sp) -> slot verb "intent" intent sp (direction_of mv)
        | it -> refuse verb it)
    items;
  Mark
    ( out,
      need_axis verb axis span,
      Option.value !extent ~default:Full,
      Option.value !intent ~default:Valley,
      !layer,
      sides_of toward moving,
      span )

let fold (items : raw_item list) (out : output) (span : Error.span) : stmt =
  let verb = "fold" in
  let axis = ref None
  and moving = ref None
  and toward = ref None
  and up_to = ref None
  (* the placement slot holds one value: `over`/`under` a flap, or the
     bottom that `(mountain)` names *)
  and bottom = ref None
  and place = ref None in
  List.iter
    (fun it ->
      if not (axis_item verb axis it || side_item verb ~toward ~moving it) then
        match it with
        | RiUpTo (fa, sp) -> slot verb "up to" up_to sp (fa, sp)
        | RiLetter (MvMountain, sp) -> slot verb "placement" bottom sp sp
        | RiPlace (d, fa, sp) -> slot verb "placement" place sp (d, fa)
        | it -> refuse verb it)
    items;
  (match (!place, !bottom) with
  | Some _, Some sp ->
      Error.fail ~hint:"drop mountain" sp "a placed fold derives its direction"
  | _ -> ());
  Fold
    ( out,
      need_axis verb axis span,
      {
        moving = Option.map fst !moving;
        toward = Option.map fst !toward;
        spans = (sides_of toward moving).s_spans;
        up_to = Option.map fst !up_to;
        direction = (if !bottom = None then Valley else Mountain);
        place = !place;
      },
      span )

let reverse (items : raw_item list) (out : output) (span : Error.span) : stmt =
  let verb = "reverse" in
  let axis = ref None and moving = ref None and toward = ref None
  and outside = ref None and letters = ref [] in
  List.iter
    (fun it ->
      match it with
      | RiLine (lo, (MvMountain | MvValley as mv), sp) ->
          letters := (lo, mv = MvValley, sp) :: !letters
      | _ ->
          if not (axis_item verb axis it || side_item verb ~toward ~moving it) then
            match it with
            | RiOutside sp -> slot verb "outside" outside sp ()
            | it -> refuse verb it)
    items;
  Reverse
    ( out,
      need_axis verb axis span,
      (let sd = sides_of toward moving in
       { rmoving = sd.s_moving; rtoward = sd.s_toward; outside = !outside <> None;
         rletters = List.rev !letters; rspans = sd.s_spans }),
      span )

(* `unfold` opens hinges that are already there (ADR 0053): its axis is a line
   the program has, and it scores no crease, so it takes no construction and
   no output clause. Its items are those of `fold` without a placement beside
   the stack. *)
let unfold (items : raw_item list) (out : output) (span : Error.span) : stmt =
  let verb = "unfold" in
  let axis = ref None and moving = ref None and toward = ref None
  and up_to = ref None and bottom = ref None in
  List.iter
    (fun it ->
      match it with
      | RiConstruction (_, sp) ->
          Error.fail ~hint:"name the crease the hinges lie on" sp
            "unfold opens hinges on a crease the program already has; it takes \
             a crease, not a construction"
      | _ ->
          if not (axis_item verb axis it || side_item verb ~toward ~moving it) then
            match it with
            | RiUpTo (fa, sp) -> slot verb "up to" up_to sp (fa, sp)
            | RiLetter (MvMountain, sp) -> slot verb "mountain" bottom sp sp
            | it -> refuse verb it)
    items;
  (match out with
  | Anonymous -> ()
  | Named (_, _, sp) | Into (_, sp) ->
      Error.fail sp "unfold scores no crease, so it takes no as or into");
  let lo =
    match need_axis verb axis span with
    | MLine lo -> lo
    | MConstruction _ -> assert false
  in
  Unfold
    ( lo,
      {
        moving = Option.map fst !moving;
        toward = Option.map fst !toward;
        spans = (sides_of toward moving).s_spans;
        up_to = Option.map fst !up_to;
        direction = (if !bottom = None then Valley else Mountain);
        place = None;
      },
      span )

let flatten (items : raw_item list) (out : output) (span : Error.span) : stmt =
  let verb = "flatten" in
  (* rays and orders are accumulated reversed and restored, so that the ray
     order the first two rays' stayer convention reads (SPECIFICATION.md
     §4.9) is source order *)
  let rays = ref [] and overs = ref [] and staying = ref None and toward = ref None in
  let on = ref None in
  List.iter
    (fun it ->
      match it with
      | RiLine (lo, mv, _) -> rays := { cline = lo; cdir = mv } :: !rays
      | RiOrder (u, l, _) -> overs := (u, l) :: !overs
      | RiStaying (ps, sp) -> slot verb "staying" staying sp ps
      | RiOn (fa, sp) -> slot verb "on" on sp fa
      | RiSelection ({ target = TowardPoint p; subject = None }, sp) ->
          slot verb "toward" toward sp p
      | RiSelection ({ subject = Some _; _ }, sp) ->
          Error.fail ~hint:"write (toward .p)" sp
            "the toward of flatten names no object"
      | RiSelection ({ target = TowardLine _; _ }, sp) ->
          Error.fail ~hint:"name a point" sp
            "the toward of flatten takes a point, not a line"
      | it -> refuse verb it)
    items;
  if !rays = [] then Error.fail span "flatten needs at least one ray item";
  Flatten (out, List.rev !rays, List.rev !overs, !staying, !on, !toward, span)

let flip (items : raw_item list) (out : output) (span : Error.span) : stmt =
  (match items with
  | it :: _ -> Error.fail (span_of it) "flip takes no items"
  | [] -> ());
  (match out with
  | Anonymous -> ()
  | Named (_, _, sp) | Into (_, sp) ->
      Error.fail sp "flip scores no crease, so it takes no as or into");
  Flip span
