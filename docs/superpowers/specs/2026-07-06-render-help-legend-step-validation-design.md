# `beloch render` help screen, `--view` redesign, `--legend` opt-in, step validation

## Context

`beloch render FILE [...args]` (`bin/main.ml`) forwards its args straight
through to `beloch-render` (the `@beloch/render-svg` CLI, `render/render-svg/bin/fold2svg.ts`).
Four gaps make the command hard to discover and easy to misuse silently:

1. **No dedicated help.** `beloch render` has no `--help`/`-h` handling at all
   — the top-level `usage()` gives it one line. `beloch render --help` today
   just forwards `--help` to `beloch-render`, which ignores it.
2. **`--view`/`--folded` is two overlapping ways to say the same thing.**
   `--view top|bottom` picks the folded-view side; `--folded` is a
   boolean shorthand for `--view top`; CP is whatever's left when neither is
   given. Three flags for two axes (what to render vs. which side) that
   aren't actually independent in how they're spelled.
3. **Legend is always on.** `appendLegend` is called unconditionally in both
   `renderCP` and `renderFolded` (`render-cp.ts`, `render-folded.ts`) — no way
   to turn it off.
4. **Step selection fails silently.** `pickStep` (`render/scene/src/parse.ts`)
   falls back to the last step when the given `--step` label doesn't match
   anything, with no error. There's also no way to select a step by ordinal
   position — only by its declared `step <name>` label from the `.bel`
   source.

Goal: a good `beloch render --help` screen; `--view cp|folded` replacing the
`--view top|bottom` / `--folded` overlap, with a separate `--flip` for the
folded-view side; `--legend` as an explicit opt-in flag (default off); and
`--step` that accepts either a name or a 1-based ordinal index, erroring
clearly (with the available named steps listed) when it doesn't match.
3D folded views are a known future direction but explicitly out of scope
here — `--view folded` stays 2D.

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
  --view cp|folded            cp (default): crease pattern, the flat unfolded
                             state. folded: the folded state (2D; 3D planned
                             for later, not this release).
  --flip                     view the folded state from the other side
                             (ignored/no-op with --view cp)

step selection (--view folded only):
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
  --title TEXT               caption drawn in the top-left corner
  --hidden dashed|hide       how occluded creases are drawn in folded view
                             (default: hide)

output options:
  --format svg|png           overrides the format implied by OUT's extension
                             (default: svg)
  --width N                  PNG output width in px (default: document width)
  --open                     render to a temp file and open it (xdg-open)

examples:
  beloch render kite.bel
  beloch render kite.bel --view folded out.png
  beloch render kite.bel --view folded --flip out.png
  beloch render kite.bel --step precrease --open
```

`usage()`'s existing one-liner for `render` gains a
`(see beloch render --help)` pointer.

### 2. `--view cp|folded` + `--flip` replace `--view top|bottom` / `--folded` (`fold2svg.ts`)

`fold2svg.ts` flag parsing changes:

```ts
const viewFlag = flagVal("--view"); // undefined | "cp" | "folded"
if (viewFlag !== undefined && viewFlag !== "cp" && viewFlag !== "folded") {
  console.error(`beloch-render: unknown --view value '${viewFlag}' — expected cp or folded`);
  process.exit(1);
}
const flip = args.includes("--flip");
const FLAGS = new Set([
  "--title", "--view", "--hidden", "--constructions", "--step", "--format",
  "--width", "--legend", "--flip",
]);
...
const doc = viewFlag === "folded"
  ? renderFolded(scene, { ...opts, view: flip ? "bottom" : "top", hidden, step })
  : renderCP(scene, opts);
```

`renderFolded`'s own `FoldedOptions.view` field stays `"top" | "bottom"`
internally (`render-folded.ts` is unchanged) — `--flip` is purely a CLI-level
translation of that internal side, same as before. `--folded` and
`--view top|bottom` are removed; there is no backwards-compat shim (pre-1.0,
no external consumers besides this repo).

Two in-repo consumers need updating to match:

- `editors/vscode/src/preview.ts:121,123` — `runFold2svg(["-", "--view", "top", ...])`
  → `runFold2svg(["-", "--view", "folded", ...])`.
- `render/README.md:25,31` — flag synopsis and the `--folded` shorthand note.

### 3. `--legend` opt-in (`render-cp.ts`, `render-folded.ts`, `fold2svg.ts`)

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

### 4. Step selection: name or ordinal, explicit error (`render/scene/src/parse.ts`)

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

### 5. CLI error surface (`fold2svg.ts`)

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
- Unknown `--view` value: exit 1, plain `beloch-render: unknown --view value
  '<value>' — expected cp or folded`.
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
- `render/render-svg/test/cli.test.ts`: update the existing `--folded` test
  to `--view folded`; add cases for `--view folded --flip` (bottom-view
  output), unknown `--view` value exiting 1, `--legend` producing the legend
  panel, and an unmatched `--step` exiting 1 with the expected stderr
  message (non-TTY, so plain text — `Bun.spawn` pipes aren't a tty).
- `tests/test_render_cli.ml` (OCaml): add a case asserting `beloch render
  --help` exits 0, prints to stdout, and works without requiring
  `beloch-render` on PATH.
- No test coverage needed for `editors/vscode/src/preview.ts` or
  `render/README.md` — mechanical updates to match the new flag, verified by
  reading the diff.
