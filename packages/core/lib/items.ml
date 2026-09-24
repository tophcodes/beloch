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
          Error.fail sp
            "an axis item takes no mountain or valley; write (mountain) as its \
             own item");
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

(* ---- the five verbs ---- *)

let mark (items : raw_item list) (out : output) (span : Error.span) : stmt =
  let verb = "mark" in
  let axis = ref None
  and layer = ref None
  and extent = ref None
  and intent = ref None in
  List.iter
    (fun it ->
      if not (axis_item verb axis it) then
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
      span )

let fold (items : raw_item list) (out : output) (span : Error.span) : stmt =
  let verb = "fold" in
  let axis = ref None
  and moving = ref None
  and up_to = ref None
  (* the placement slot holds one value: `over`/`under` a flap, or the
     bottom that `(mountain)` names *)
  and bottom = ref None
  and place = ref None in
  List.iter
    (fun it ->
      if not (axis_item verb axis it) then
        match it with
        | RiMoving (fa, sp) -> slot verb "moving" moving sp fa
        | RiUpTo (fa, sp) -> slot verb "up to" up_to sp (fa, sp)
        | RiLetter (MvMountain, sp) -> slot verb "placement" bottom sp sp
        | RiPlace (d, fa, sp) -> slot verb "placement" place sp (d, fa)
        | it -> refuse verb it)
    items;
  (match (!place, !bottom, !up_to) with
  | Some _, Some sp, _ ->
      Error.fail sp "a placed fold derives its direction; drop mountain"
  | Some _, None, Some (_, sp) ->
      Error.fail sp
        "a placed fold moves the anchor flap only; up to is not supported here"
  | _ -> ());
  Fold
    ( out,
      need_axis verb axis span,
      {
        moving = !moving;
        up_to = Option.map fst !up_to;
        direction = (if !bottom = None then Valley else Mountain);
        place = !place;
      },
      span )

let reverse (items : raw_item list) (out : output) (span : Error.span) : stmt =
  let verb = "reverse" in
  let axis = ref None and moving = ref None and outside = ref None in
  List.iter
    (fun it ->
      if not (axis_item verb axis it) then
        match it with
        | RiMoving (fa, sp) -> slot verb "moving" moving sp fa
        | RiOutside sp -> slot verb "outside" outside sp ()
        | it -> refuse verb it)
    items;
  Reverse
    ( out,
      need_axis verb axis span,
      { rmoving = !moving; outside = !outside <> None },
      span )

let flatten (items : raw_item list) (out : output) (span : Error.span) : stmt =
  let verb = "flatten" in
  (* rays and orders are accumulated reversed and restored, so that the ray
     order the first two rays' stayer convention reads (SPECIFICATION.md
     §4.9) is source order *)
  let rays = ref [] and overs = ref [] and staying = ref None and toward = ref None in
  List.iter
    (fun it ->
      match it with
      | RiLine (lo, mv, _) -> rays := { cline = lo; cdir = mv } :: !rays
      | RiOrder (u, l, _) -> overs := (u, l) :: !overs
      | RiStaying (fa, sp) -> slot verb "staying" staying sp fa
      | RiSelection (p, sp) -> slot verb "toward" toward sp p
      | it -> refuse verb it)
    items;
  if !rays = [] then Error.fail span "flatten needs at least one ray item";
  Flatten (out, List.rev !rays, List.rev !overs, !staying, !toward, span)

let flip (items : raw_item list) (out : output) (span : Error.span) : stmt =
  (match items with
  | it :: _ -> Error.fail (span_of it) "flip takes no items"
  | [] -> ());
  (match out with
  | Anonymous -> ()
  | Named (_, _, sp) | Into (_, sp) ->
      Error.fail sp "flip scores no crease, so it takes no as or into");
  Flip span
