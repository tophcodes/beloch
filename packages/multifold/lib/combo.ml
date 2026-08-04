type t = Alignment.t list

let sort = List.sort Alignment.compare

let canonical c =
  let a = sort c in
  let b = sort (List.map Alignment.swap_ab c) in
  if List.compare Alignment.compare a b <= 0 then a else b

(* Which fold lines does an alignment's equation system mention?
   [alperin2006, Fig. 4]: AL2, AL3, AL6 mention one fold line (their suffix);
   AL1, AL4, AL5, AL7, AL8, AL9, AL10 mention both. *)
let folds_mentioned (a : Alignment.t) : [ `One_a | `One_b | `Both ] =
  match a.kind with
  | AL2 | AL3 | AL6 -> (
      match a.suffix with A -> `One_a | B -> `One_b | Sym -> assert false)
  | _ -> `Both

let separable c =
  (* Separable iff the multiset splits into two groups, each mentioning only
     one distinct fold line, each summing to 2 equations (i.e. each is a 1FA). *)
  let one_a = List.filter (fun a -> folds_mentioned a = `One_a) c in
  let one_b = List.filter (fun a -> folds_mentioned a = `One_b) c in
  let both = List.filter (fun a -> folds_mentioned a = `Both) c in
  let sum l = List.fold_left (fun n a -> n + Alignment.equations a) 0 l in
  both = [] && sum one_a = 2 && sum one_b = 2

let candidates () =
  let alphabet = Array.of_list Alignment.all_twofold in
  let n = Array.length alphabet in
  let out = ref [] in
  (* multisets as non-decreasing index sequences, length 2..4, pruned on eq sum *)
  let rec go start acc eqs len =
    if eqs = 4 && len >= 2 then out := List.rev acc :: !out;
    if eqs < 4 && len < 4 then
      for i = start to n - 1 do
        let a = alphabet.(i) in
        let e = Alignment.equations a in
        if eqs + e <= 4 then go i (a :: acc) (eqs + e) (len + 1)
      done
  in
  go 0 [] 0 0;
  !out
  |> List.filter (fun c -> not (separable c))
  |> List.map canonical
  |> List.sort_uniq (List.compare Alignment.compare)
