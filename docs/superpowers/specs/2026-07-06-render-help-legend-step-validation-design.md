# `beloch render` help screen, `--legend` opt-in, step validation

## Context

`beloch render FILE [...args]` (`bin/main.ml`) forwards its args straight
through to `beloch-render` (the `@beloch/render-svg` CLI, `render/render-svg/bin/fold2svg.ts`).
Three gaps make the command hard to discover and easy to misuse silently:

1. **No dedicated help.** `beloch render` has no `--help`/`-h` handling at all
   — the top-level `usage()` gives it one line. `beloch render --help` today
   just forwards `--help` to `beloch-render`, which ignores it.
2. **Legend is always on.** `appendLegend` is called unconditionally in both
   `renderCP` and `renderFolded` (`render-cp.ts`, `render-folded.ts`) — no way
   to turn it off.
3. **Step selection fails silently.** `pickStep` (`render/scene/src/parse.ts`)
   falls back to the last step when the given `--step` label doesn't match
   anything, with no error. There's also no way to select a step by ordinal
   position — only by its declared `step <name>` label from the `.bel`
   source.

Goal: a good `beloch render --help` screen, `--legend` as an explicit opt-in
flag (default off), and `--step` that accepts either a name or a 1-based
ordinal index, erroring clearly (with the available named steps listed) when
it doesn't match.

## Decision

### 1. `beloch render --help` / `-h` (`bin/main.ml`)

Intercepted at the very top of `run_render`, before the `beloch-render`
PATH check — so it works even when `beloch-render` isn't installed. Prints to
stdout, exits 0.

```
beloch render — render a .bel or .fold file to SVG/PNG

usage:
  beloch render FILE.bel|FILE.fold [OUT] [flags]

file selection:
  FILE.bel                  evaluated first (like `beloch fold`), then rendered
  FILE.fold                 rendered directly (FOLD JSON)
  OUT                       output path; extension picks the format unless
                             --format is set. Omit OUT to write to stdout.

what gets rendered:
  (default)                 crease pattern (CP) — the flat, unfolded state
  --view top|bottom         folded state, viewed from the given side
  --folded                  shorthand for --view top

step selection (folded state only):
  --step NAME|N              NAME = a declared `step <name>` label from the
                             .bel source; N = 1-based ordinal position among
                             declared steps. Default: last step (final
                             folded state). Errors if NAME/N doesn't exist,
                             listing the named steps that do.

constructions (named points/lines):
  --constructions a,b,c      only render these named constructions
                             (comma-separated). Default: render all.

display options:
  --legend                   show the M/V/B/U crease-type legend (default: off)
  --title TEXT                caption drawn in the top-left corner
  --hidden dashed|hide        how occluded creases are drawn in folded view
                             (default: hide)

output options:
  --format svg|png            overrides the format implied by OUT's extension
                             (default: svg)
  --width N                    PNG output width in px (default: document width)
  --open                      render to a temp file and open it (xdg-open)

examples:
  beloch render kite.bel
  beloch render kite.bel --folded out.png
  beloch render kite.bel --step precrease --open
```

`usage()`'s existing one-liner for `render` gains a
`(see beloch render --help)` pointer.

### 2. `--legend` opt-in (`render-cp.ts`, `render-folded.ts`, `fold2svg.ts`)

`RenderOptions` (declared in `render-cp.ts`, shared via `FoldedOptions extends
RenderOptions` in `render-folded.ts`) gains `legend?: boolean` (default
`false`). Both `renderCP` and `renderFolded` change their unconditional
`appendLegend(...)` call to `if (opts.legend) appendLegend(...)`.

`fold2svg.ts`: `--legend` added to the `FLAGS` set as a boolean (no value),
`opts.legend = args.includes("--legend")`.

This is a **default-behavior change**: existing output (SVG/PNG) loses the
legend panel unless `--legend` is passed. Golden snapshot tests for
`render-cp.test.ts`/`render-folded.test.ts` get re-recorded without it, plus
one new test per file asserting `legend: true` still renders the panel.

### 3. Step selection: name or ordinal, explicit error (`render/scene/src/parse.ts`)

`pickStep(scene, label)`:

- no `label` → last step (unchanged — final folded state is still the
  default).
- `label` matches a step's `.label` exactly → that step (unchanged).
- no name match, `label` is all-digits → treat as 1-based ordinal into
  `scene.steps`; in range → that step.
- otherwise (no name match, not a valid in-range ordinal) → throw.

The thrown error is a new `StepNotFoundError extends SceneError`
(`render/scene/src/types.ts`), carrying structured data instead of just a
message string, so the CLI boundary can render it differently for a
TTY vs. a pipe:

```ts
export class StepNotFoundError extends SceneError {
  constructor(
    readonly label: string,
    readonly available: { index: number; label: string | null }[],
  ) {
    super(StepNotFoundError.render(label, available, (s) => s));
  }
  static render(
    label: string,
    available: { index: number; label: string | null }[],
    style: (s: string) => string,
  ): string {
    const named = available
      .filter((s) => s.label !== null)
      .map((s) => `${style(s.label!)} (${s.index + 1})`)
      .join(", ");
    return (
      `step '${label}' not found — ${available.length} step(s) available` +
      (named ? `. named steps are ${named}` : "")
    );
  }
}
```

Unnamed steps count toward the total but are skipped in the named-steps
list (they can still be reached by ordinal, just not shown by name — nothing
to show). `available[].index` is 0-based internally but rendered 1-based
(`index + 1`), matching the same ordinal `--step N` accepts.

### 4. CLI error surface (`fold2svg.ts`)

Currently an uncaught `SceneError` (e.g. "no foldedForm frames in scene")
prints a raw stack trace. Wrap the parse+render call in a top-level
try/catch:

```ts
try {
  // existing parse + render + write logic
} catch (err) {
  if (err instanceof StepNotFoundError) {
    const tty = process.stderr.isTTY;
    const style = tty ? (s: string) => `\x1b[1;36m${s}\x1b[0m` : (s: string) => s;
    console.error(`beloch-render: ${StepNotFoundError.render(err.label, err.available, style)}`);
  } else if (err instanceof SceneError) {
    console.error(`beloch-render: ${err.message}`);
  } else {
    throw err; // unexpected — keep the stack trace
  }
  process.exit(1);
}
```

Color (bold cyan) is applied only at this CLI boundary, gated on
`process.stderr.isTTY` — mirrors the existing tty-aware `Render_cli.dim` on
the OCaml side (`bin/render_cli.ml`). `StepNotFoundError.render` is a pure
function, independently testable for its plain (non-colored) form.

## Error handling

- `beloch render --help` works without `beloch-render` on PATH (checked
  before the `which` lookup).
- Step name/ordinal mismatch: exit 1, message lists count + named steps with
  their ordinal position. No fallback to the last step anymore (behavior
  change, intentional).
- Other `SceneError`s (e.g. "no foldedForm frames in scene"): same plain
  `beloch-render: <message>` treatment, no color (not a
  `StepNotFoundError`).
- Non-`SceneError` exceptions are rethrown unchanged (unexpected bugs keep
  their stack trace).

## Testing

- `render/scene/test/parse.test.ts`: replace the existing "unmatched label
  falls back to last step" test (behavior no longer holds) with tests for:
  name match (unchanged), ordinal match, ordinal out of range throws,
  unnamed-label throws, thrown error's `available` list shape, and
  `StepNotFoundError.render`'s plain-text output (named + all-unnamed
  cases).
- `render/render-svg/test/render-cp.test.ts` /
  `render-folded.test.ts`: re-record snapshots without the legend by
  default; add one `legend: true` test per file asserting the panel is
  present.
- `render/render-svg/test/cli.test.ts`: add a case for `--legend` producing
  the legend panel, and a case for an unmatched `--step` exiting 1 with the
  expected stderr message (non-TTY, so plain text — `Bun.spawn` pipes
  aren't a tty).
- `tests/test_render_cli.ml` (OCaml): add a case asserting `beloch render
  --help` exits 0, prints to stdout, and works without requiring
  `beloch-render` on PATH.
