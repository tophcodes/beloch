(* Extracts the 489-symbol two-fold-axiom listing from the Alperin-Lang paper
   into a sorted, deduplicated fixture, one symbol per line. Usage:
     dune exec packages/multifold/tools/extract_fixture.exe -- refs/alperin2006.txt
   [alperin2006, §4, pp. 12-14 of the preprint]. *)

let read_lines path = In_channel.with_open_text path In_channel.input_lines

let contains ~sub s =
  let n = String.length s and m = String.length sub in
  let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
  m = 0 || go 0

let is_start_marker =
  contains ~sub:"we can provide a complete listing by symbol"

let is_end_marker = contains ~sub:"This leads naturally to the question"

(* A page-number line: the running header/footer between the two pages the
   listing spans, e.g. "13" on its own line. *)
let is_page_number s =
  let s = String.trim s in
  s <> "" && String.for_all (fun c -> c >= '0' && c <= '9') s

let is_blank s = String.trim s = ""

let is_symbol_token s =
  String.length s > 2
  && String.sub s 0 2 = "AL"
  && String.for_all
       (fun c -> (c >= '0' && c <= '9') || c = 'a' || c = 'b')
       (String.sub s 2 (String.length s - 2))

let listing_lines lines =
  let rec find_from pred i = function
    | [] -> None
    | l :: rest -> if pred l then Some i else find_from pred (i + 1) rest
  in
  match find_from is_start_marker 0 lines with
  | None -> failwith "start marker not found"
  | Some start -> (
      let after_start = List.filteri (fun i _ -> i > start) lines in
      match find_from is_end_marker 0 after_start with
      | None -> failwith "end marker not found"
      | Some stop -> List.filteri (fun i _ -> i < stop) after_start)

let () =
  if Array.length Sys.argv < 2 then begin
    prerr_endline "usage: extract_fixture <path-to-alperin2006.txt>";
    exit 1
  end;
  let lines = read_lines Sys.argv.(1) in
  let block =
    listing_lines lines
    |> List.filter (fun l -> (not (is_blank l)) && not (is_page_number l))
  in
  let tokens =
    String.concat " " block |> String.split_on_char ',' |> List.map String.trim
    |> List.filter (fun s -> s <> "")
  in
  let bad_shape = List.filter (fun s -> not (is_symbol_token s)) tokens in
  if bad_shape <> [] then begin
    Printf.eprintf "extract_fixture: %d token(s) don't match ^AL[0-9ab]+$:\n"
      (List.length bad_shape);
    List.iter (Printf.eprintf "  %s\n") bad_shape;
    exit 1
  end;
  let unparseable =
    List.filter (fun s -> Multifold.Alignment.combo_of_symbol s = None) tokens
  in
  if unparseable <> [] then begin
    Printf.eprintf
      "extract_fixture: %d token(s) rejected by Alignment.combo_of_symbol \
       (likely OCR damage):\n"
      (List.length unparseable);
    List.iter (Printf.eprintf "  %s\n") unparseable;
    exit 1
  end;
  tokens |> List.sort_uniq String.compare |> List.iter print_endline
