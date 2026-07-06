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

let wants_help args = List.mem "--help" args || List.mem "-h" args

let render_help =
  {|beloch render — render a .bel or .fold file to SVG/PNG

usage:
  beloch render FILE.bel|FILE.fold [OUT] [flags]

file selection:
  FILE.bel                  evaluated first (like `beloch fold`), then rendered
  FILE.fold                 rendered directly (FOLD JSON)
  OUT                       output path; extension picks the format unless
                            --format is set. Omit OUT to write to stdout.

what gets rendered:
  --view cp|folded          cp (default): crease pattern, the flat unfolded
                            state. folded: the folded state (2D; 3D planned
                            for later, not this release).
  --flip                    view the folded state from the other side
                            (ignored/no-op with --view cp)

step selection (--view folded only):
  --step NAME|N             NAME = a declared `step <name>` label from the
                            .bel source; N = 1-based ordinal position among
                            declared steps. Default: last step (final
                            folded state). Errors if NAME/N doesn't exist,
                            listing the named steps that do.

constructions (named points/lines):
  --constructions a,b,c     only render these named constructions
                            (comma-separated). Default: render all.

display options:
  --legend                  show the M/V/B/U crease-type legend (default: off)
  --title TEXT              caption drawn in the top-left corner
  --hidden dashed|hide      how occluded creases are drawn in folded view
                            (default: hide)

output options:
  --format svg|png          overrides the format implied by OUT's extension
                            (default: svg)
  --width N                 PNG output width in px (default: document width)
  --open                    render to a temp file and open it (xdg-open)

examples:
  beloch render kite.bel
  beloch render kite.bel --view folded out.png
  beloch render kite.bel --view folded --flip out.png
  beloch render kite.bel --view folded --step precrease --open
|}
