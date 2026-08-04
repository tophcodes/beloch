type kind = AL1 | AL2 | AL3 | AL4 | AL5 | AL6 | AL7 | AL8 | AL9 | AL10
type suffix = A | B | Sym
type t = { kind : kind; suffix : suffix }

let symmetric = function AL1 | AL8 | AL9 -> true | _ -> false

let all_twofold =
  let kinds = [ AL1; AL2; AL3; AL4; AL5; AL6; AL7; AL8; AL9; AL10 ] in
  List.concat_map
    (fun kind ->
      if symmetric kind then [ { kind; suffix = Sym } ]
      else [ { kind; suffix = A }; { kind; suffix = B } ])
    kinds

let equations t = match t.kind with AL4 | AL8 | AL9 -> 2 | _ -> 1

let swap_ab t =
  match t.suffix with
  | A -> { t with suffix = B }
  | B -> { t with suffix = A }
  | Sym -> t

let kind_index = function
  | AL1 -> 1
  | AL2 -> 2
  | AL3 -> 3
  | AL4 -> 4
  | AL5 -> 5
  | AL6 -> 6
  | AL7 -> 7
  | AL8 -> 8
  | AL9 -> 9
  | AL10 -> 10

let kind_of_index = function
  | 1 -> AL1
  | 2 -> AL2
  | 3 -> AL3
  | 4 -> AL4
  | 5 -> AL5
  | 6 -> AL6
  | 7 -> AL7
  | 8 -> AL8
  | 9 -> AL9
  | 10 -> AL10
  | n -> invalid_arg (Printf.sprintf "kind_of_index: %d" n)

let compare x y =
  match Int.compare (kind_index x.kind) (kind_index y.kind) with
  | 0 ->
      Stdlib.compare x.suffix
        y.suffix (* A < B; never mixed with Sym per kind *)
  | c -> c

(* [alperin2006, §4]: "AL" followed by, for each kind present (ascending),
   its number once and then its a/b letters (one per occurrence); symmetric
   kinds (AL1/AL8/AL9) carry no letters, e.g. AL6ab8 = AL6a, AL6b, AL8. *)
let combo_to_symbol combo =
  let sorted = List.sort compare combo in
  let buf = Buffer.create 16 in
  Buffer.add_string buf "AL";
  let rec take_kind kind = function
    | ({ kind = k; _ } as t) :: rest when k = kind ->
        let more, rest' = take_kind kind rest in
        (t :: more, rest')
    | rest -> ([], rest)
  in
  let rec go = function
    | [] -> ()
    | t :: rest when symmetric t.kind ->
        (* No letters; a repeated symmetric occurrence prints its number
           again (e.g. two AL8 would print "88") though this never occurs
           in valid combos. *)
        Buffer.add_string buf (string_of_int (kind_index t.kind));
        go rest
    | t :: rest ->
        let group, rest' = take_kind t.kind rest in
        Buffer.add_string buf (string_of_int (kind_index t.kind));
        List.iter
          (fun g -> Buffer.add_char buf (if g.suffix = A then 'a' else 'b'))
          (t :: group);
        go rest'
  in
  go sorted;
  Buffer.contents buf

let combo_of_symbol s =
  let n = String.length s in
  let is_digit c = c >= '0' && c <= '9' in
  let is_letter c = c = 'a' || c = 'b' in
  let digit_value c = Char.code c - Char.code '0' in
  let is_symmetric_kind = function AL1 | AL8 | AL9 -> true | _ -> false in
  (* At position [i], try a two-digit kind number (only "10" is valid);
     back off to a one-digit number (1-9) if that fails. A leading '0' is
     rejected outright -- no valid kind number starts with it, and without
     this check the two-digit path would silently read e.g. "01" as 1. *)
  let parse_number i =
    if i < n && s.[i] = '0' then None
    else
      let two =
        if i + 1 < n && is_digit s.[i] && is_digit s.[i + 1] then
          let v = (digit_value s.[i] * 10) + digit_value s.[i + 1] in
          if v >= 1 && v <= 10 then Some (v, i + 2) else None
        else None
      in
      match two with
      | Some _ -> two
      | None ->
          if i < n && is_digit s.[i] then
            let v = digit_value s.[i] in
            if v >= 1 && v <= 9 then Some (v, i + 1) else None
          else None
  in
  let rec parse_groups i acc =
    if i = n then Some (List.rev acc)
    else
      match parse_number i with
      | None -> None
      | Some (num, j) ->
          let kind = kind_of_index num in
          let rec letters k acc =
            if k < n && is_letter s.[k] then
              let suffix = if s.[k] = 'a' then A else B in
              letters (k + 1) ({ kind; suffix } :: acc)
            else (k, acc)
          in
          let k', acc' = letters j acc in
          (* AL1/AL8/AL9 are symmetric and carry no a/b letters; a letter
             immediately following their number (e.g. "AL1a") is malformed,
             not a Sym occurrence. *)
          if k' <> j && is_symmetric_kind kind then None
          else
            let acc'' =
              if k' = j then { kind; suffix = Sym } :: acc else acc'
            in
            parse_groups k' acc''
  in
  if n >= 2 && String.sub s 0 2 = "AL" then parse_groups 2 [] else None
