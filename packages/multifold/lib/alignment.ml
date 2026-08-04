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
