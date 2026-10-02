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
  --view candidates|op|stages
                            drawn from the trace of `beloch fold --trace`,
                            which a .bel file gets here; a program that fails
                            is drawn up to the failure. candidates: one panel
                            per candidate of a statement. op: a write's terms
                            and its result. stages: one construction's
                            selection, one row per stage.
  --statement N             the statement those views draw, as an index into
                            beloch:statements (default: the one that failed,
                            else the last that chose)
  --source FILE             the program text the stages view prints; a .bel
                            input passes itself
  --stage N                 stages: draw stage N (0 to 4) alone
  --checks                  stages: add the rows that say what each stage
                            checks
  --view side --along --l   the section along the line --l: the layers pulled
                            apart, the top one first, beside the crease
                            pattern with the same pieces and hinges named.
                            --l is read on the table of the final state: bind
                            it with = after the last fold. Seen from outside
                            the paper; arrows on the cut show the side.
  --step N                  folded, side: draw the state after the Nth write
                            (0: the flat sheet; default: the last state)
  --far-side                side: see the section from the other side of the
                            line (mirrored, arrows turned round)
  --flip                    view the folded state from the other side
                            (ignored/no-op with --view cp)

labels (named points/lines):
  --labels a,b,c            draw these named points/lines as labeled overlay
                            (comma-separated). Draws exactly what's named,
                            even a point on a paper corner or a line that's
                            also a crease. Default: no overlay.

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
  beloch render kite.bel --view folded --open
  beloch render kite.bel --view stages out.svg
|}
