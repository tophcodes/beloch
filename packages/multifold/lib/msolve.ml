(** See msolve.mli. Output format pinned empirically against msolve 0.10.0
    (nixpkgs rev e73de5be04e0eff4190a1432b946d469c794e7b4, `msolve -f in -o out
    -P 1`); do not extend the parser from memory of a different msolve version
    without re-capturing literal fixtures. *)

exception Solve_failed of string

(* --- printer: Mpoly.t -> msolve polynomial syntax ---------------------- *)

let q_abs_to_string (c : Q.t) : string =
  let c = Q.abs c in
  if Z.equal (Q.den c) Z.one then Z.to_string (Q.num c)
  else Z.to_string (Q.num c) ^ "/" ^ Z.to_string (Q.den c)

let monomial_to_string ~(names : int -> string) (m : int array) : string =
  let parts = ref [] in
  Array.iteri
    (fun i e ->
      if e > 0 then begin
        let v = names i in
        parts := (if e = 1 then v else v ^ "^" ^ string_of_int e) :: !parts
      end)
    m;
  String.concat "*" (List.rev !parts)

let poly_to_string ~(names : int -> string) (p : Beloch.Mpoly.t) : string =
  if p = [] then "0"
  else begin
    let buf = Buffer.create 64 in
    List.iteri
      (fun idx ((m, c) : int array * Q.t) ->
        let neg = Q.sign c < 0 in
        let mono = monomial_to_string ~names m in
        let coeff_str =
          let abs = q_abs_to_string c in
          if mono <> "" && String.equal abs "1" then ""
          else abs ^ if mono = "" then "" else "*"
        in
        if idx = 0 then
          begin if neg then Buffer.add_char buf '-'
          end
        else Buffer.add_char buf (if neg then '-' else '+');
        Buffer.add_string buf coeff_str;
        Buffer.add_string buf mono)
      p;
    Buffer.contents buf
  end

(* --- variable extension: pad an nvars-dim Mpoly.t into nvars'-dim -------
   Directly manipulates Mpoly's public (mono * Q.t) list representation
   (mpoly.ml has no .mli — the type is not abstract); no core changes. *)
let extend_nvars ~(from_nvars : int) ~(to_nvars : int) (p : Beloch.Mpoly.t) :
    Beloch.Mpoly.t =
  if to_nvars = from_nvars then p
  else
    List.map
      (fun (m, c) -> (Array.append m (Array.make (to_nvars - from_nvars) 0), c))
      p

(* w · (∏ denoms) − 1 = 0, in nvars+1 variables (w = index nvars). *)
let saturation_equation ~(nvars : int) (denoms : Beloch.Mpoly.t list) :
    Beloch.Mpoly.t =
  let nvars' = nvars + 1 in
  let w = Beloch.Mpoly.var nvars' nvars in
  let prod =
    List.fold_left
      (fun acc d ->
        Beloch.Mpoly.mul acc (extend_nvars ~from_nvars:nvars ~to_nvars:nvars' d))
      (Beloch.Mpoly.one_of nvars')
      denoms
  in
  Beloch.Mpoly.sub (Beloch.Mpoly.mul w prod) (Beloch.Mpoly.one_of nvars')

(* --- msolve input file ---------------------------------------------------
   Format per `msolve -h`: line 1 = comma-separated var names (no trailing
   comma), line 2 = characteristic (0 for ℚ), then one polynomial per line,
   comma-terminated except the last. *)
let write_input (path : string) ~(names : int -> string) ~(nvars : int)
    (polys : Beloch.Mpoly.t list) : unit =
  let oc = open_out path in
  Fun.protect
    ~finally:(fun () -> close_out_noerr oc)
    (fun () ->
      output_string oc (String.concat "," (List.init nvars names));
      output_char oc '\n';
      output_string oc "0\n";
      let n = List.length polys in
      List.iteri
        (fun i p ->
          output_string oc (poly_to_string ~names p);
          if i < n - 1 then output_char oc ',';
          output_char oc '\n')
        polys)

(* --- output parser: a tiny bracket/comma/atom S-expression reader -------
   Only the dimension marker and (for zero-dim systems) the rational
   parametrization's eliminant are interpreted; the trailing real-solution
   isolating-box block is skipped structurally (parsed into atoms, never
   inspected) — its entries include `/`- and `^`-separated big-integer
   fractions we have no use for. *)

type sexp = Atom of string | Node of sexp list

let tokenize (s : string) : [ `LB | `RB | `Comma | `Atom of string ] list =
  let n = String.length s in
  let is_space c = c = ' ' || c = '\t' || c = '\n' || c = '\r' in
  let is_delim c = c = '[' || c = ']' || c = ',' in
  let rec go i acc =
    if i >= n then List.rev acc
    else
      match s.[i] with
      | c when is_space c -> go (i + 1) acc
      | '[' -> go (i + 1) (`LB :: acc)
      | ']' -> go (i + 1) (`RB :: acc)
      | ',' -> go (i + 1) (`Comma :: acc)
      | _ ->
          (* An "atom" runs up to the next bracket/comma, NOT the next
             whitespace: the real-solution isolating-box section (which we
             never interpret, only skip over structurally) prints rational
             bounds as "num / den" with internal spaces and no comma between
             the pieces, e.g. "[-123 / 2^64, 45 / 2^63]" is a 2-element list
             whose elements are the space-separated blobs "-123 / 2^64" and
             "45 / 2^63". *)
          let j = ref i in
          while !j < n && not (is_delim s.[!j]) do
            incr j
          done;
          go !j (`Atom (String.trim (String.sub s i (!j - i))) :: acc)
  in
  go 0 []

let parse_sexp (raw : string) : sexp =
  let rec value toks =
    match toks with
    | `LB :: rest -> node rest []
    | `Atom a :: rest -> (Atom a, rest)
    | _ -> failwith "expected a value"
  and node toks acc =
    match toks with
    | `RB :: rest -> (Node (List.rev acc), rest)
    | _ -> (
        let v, rest = value toks in
        match rest with
        | `Comma :: rest' -> node rest' (v :: acc)
        | `RB :: rest' -> (Node (List.rev (v :: acc)), rest')
        | _ -> failwith "expected ',' or ']'")
  in
  fst (value (tokenize raw))

let as_node = function
  | Node l -> l
  | Atom a -> failwith ("expected a list, got atom " ^ a)

let as_int = function
  | Atom a -> int_of_string a
  | Node _ -> failwith "expected an int atom"

type zero_dim = { count : int; multiplicity_free : bool }

(* dim-tuple layout, pinned against msolve 0.10.0 `-P 1` output (see
   test_msolve.ml for the literal captures):
     [dim; nvars; degree; varnames; linear_form; [1, [eliminant; denom; params]]]
   `degree` (index 2) is the multiplicity-weighted (Bézout) degree of the
   ideal's quotient ring; `eliminant = [degree; coeffs]` is msolve's RUR
   eliminant f₀, whose own degree (`count`) is the number of DISTINCT
   solutions only — RUR is computed on the ideal's radical, so f₀ is always
   squarefree regardless of the original multiplicities. Comparing the two
   degrees (not a gcd on f₀) is what detects multiplicity. *)
let zero_dim_of_tuple (dim_tuple : sexp list) : zero_dim =
  let weighted_degree = as_int (List.nth dim_tuple 2) in
  let rur_wrapper = as_node (List.nth dim_tuple 5) in
  let rur_body = as_node (List.nth rur_wrapper 1) in
  let eliminant = as_node (List.nth rur_body 0) in
  let count = as_int (List.nth eliminant 0) in
  { count; multiplicity_free = weighted_degree = count }

let interpret (sx : sexp) :
    [ `Zero_dim of zero_dim | `Positive_dim | `No_solutions ] =
  match sx with
  | Node [ Atom "-1" ] -> `No_solutions
  | Node [ Atom "1"; _nvars; Atom "-1"; Node [] ] -> `Positive_dim
  | Node [ Atom "0"; Node dim_tuple; _real_solutions ] ->
      `Zero_dim (zero_dim_of_tuple dim_tuple)
  | _ -> failwith "unrecognized msolve output shape"

let parse_output (raw : string) :
    [ `Zero_dim of zero_dim | `Positive_dim | `No_solutions ] =
  try interpret (parse_sexp raw)
  with e ->
    raise
      (Solve_failed
         (Printf.sprintf "%s\n\nparse error: %s" raw (Printexc.to_string e)))

(* --- subprocess ----------------------------------------------------------
   Unix.create_process searches PATH for a slash-free program name (execvp
   semantics), so no manual `which` resolution is needed here. *)
let run_msolve (in_path : string) (out_path : string) : unit =
  let log_path = Filename.temp_file "multifold" ".log" in
  Fun.protect
    ~finally:(fun () -> try Sys.remove log_path with Sys_error _ -> ())
    (fun () ->
      let log_fd =
        Unix.openfile log_path
          [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ]
          0o600
      in
      let pid =
        Fun.protect
          ~finally:(fun () -> Unix.close log_fd)
          (fun () ->
            Unix.create_process "msolve"
              [| "msolve"; "-f"; in_path; "-o"; out_path; "-P"; "1" |]
              Unix.stdin log_fd log_fd)
      in
      match Unix.waitpid [] pid with
      | _, Unix.WEXITED 0 -> ()
      | _, status ->
          let log =
            try In_channel.with_open_text log_path In_channel.input_all
            with Sys_error _ -> ""
          in
          let desc =
            match status with
            | Unix.WEXITED c -> Printf.sprintf "exit %d" c
            | Unix.WSIGNALED s -> Printf.sprintf "killed by signal %d" s
            | Unix.WSTOPPED s -> Printf.sprintf "stopped by signal %d" s
          in
          raise (Solve_failed (Printf.sprintf "msolve %s\n%s" desc log)))

let classify ~(nvars : int) ~(denoms : Beloch.Mpoly.t list)
    (eqs : Beloch.Mpoly.t list) :
    [ `Zero_dim of zero_dim | `Positive_dim | `No_solutions ] =
  let nvars', system =
    match denoms with
    | [] -> (nvars, eqs)
    | _ :: _ ->
        let nvars' = nvars + 1 in
        let eqs' =
          List.map (extend_nvars ~from_nvars:nvars ~to_nvars:nvars') eqs
        in
        (nvars', eqs' @ [ saturation_equation ~nvars denoms ])
  in
  let names i = if i = nvars then "w" else "x" ^ string_of_int i in
  let in_path = Filename.temp_file "multifold" ".ms" in
  let out_path = Filename.temp_file "multifold" ".ms" in
  Fun.protect
    ~finally:(fun () ->
      (try Sys.remove in_path with Sys_error _ -> ());
      try Sys.remove out_path with Sys_error _ -> ())
    (fun () ->
      write_input in_path ~names ~nvars:nvars' system;
      run_msolve in_path out_path;
      let raw =
        try In_channel.with_open_text out_path In_channel.input_all
        with Sys_error msg -> raise (Solve_failed msg)
      in
      parse_output raw)
