let which name =
  match Sys.getenv_opt "PATH" with
  | None -> None
  | Some path ->
      String.split_on_char ':' path
      |> List.find_map (fun dir ->
             if dir = "" then None
             else
               let candidate = Filename.concat dir name in
               match Unix.access candidate [ Unix.X_OK ] with
               | () -> Some candidate
               | exception Unix.Unix_error _ -> None)

let dim ~is_tty text = if is_tty then "\027[2m" ^ text ^ "\027[0m" else text
