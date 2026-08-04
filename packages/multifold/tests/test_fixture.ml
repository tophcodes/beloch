(** Reads [fixtures/al489.txt] (relative to the test's cwd), skipping blank
    lines and [#] comment lines. *)
let fixture () =
  let ic = open_in "fixtures/al489.txt" in
  let rec go acc =
    match input_line ic with
    | exception End_of_file ->
        close_in ic;
        List.rev acc
    | l when String.length l = 0 || l.[0] = '#' -> go acc
    | l -> go (l :: acc)
  in
  go []
