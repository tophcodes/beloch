# `beloch render` accepts `.fold` and `.bel` input

## Context

`beloch render FILE [...args]` (`bin/main.ml`) currently just `execvp`s straight
into `beloch-render` (the `@beloch/render-svg` CLI, linked onto `PATH` by the
Nix devShell — see `render/README.md`). That CLI only understands FOLD JSON
(`parseFold` in `@beloch/scene`), so passing it a `.bel` file today fails with
a JSON parse error. The only way to render a `.bel` source is to manually pipe:
`beloch fold f.bel | bun render/render-svg/bin/fold2svg.ts - out.png`.

Goal: `beloch render f.bel out.svg` and `beloch render f.fold out.svg` both
just work, with no manual piping and no intermediate temp file.

## Decision

Keep the OCaml/TypeScript boundary exactly where ADR-0001 puts it: OCaml owns
evaluation, the process boundary is FOLD JSON, `render-svg` stays a pure FOLD
consumer. All changes are in `bin/main.ml`.

### Dispatch

```
beloch render FILE [...rest]
  which "beloch-render" on PATH?
    no  → print hint, exit 1 (same message as usage() hint, see below)
    yes →
      FILE ends in ".bel" →
        read FILE, Beloch.fold_string → JSON
        Unix.pipe; Unix.create_process "beloch-render" [|"beloch-render"; "-"; ...rest|]
          (read-end as child stdin, inherit stdout/stderr)
        write JSON to write-end, close, waitpid, exit with child's code
      else (".fold" or anything else) →
        Unix.execvp "beloch-render" ("beloch-render" :: args)   (* unchanged *)
```

No temp file: the FOLD JSON is written straight into `beloch-render`'s stdin
through a real pipe, mirroring the existing shell-pipe usage above.

### PATH check surfaced in `--help`

A small `which name` helper (split `PATH` on `:`, test each
`Filename.concat dir name` with `Unix.access _ [Unix.X_OK]`) backs two call
sites:

- `usage()`: the `render` line gets a trailing
  `[unavailable: beloch-render not on PATH]` when `which "beloch-render"` is
  `None`. Plain text — no ANSI dimming/TTY detection, that's more machinery
  than this is worth.
- `run_render`: checks `which` first and prints the same hint before
  attempting anything, rather than discovering the gap only after a failed
  `exec`/`create_process` (ENOENT).

### Error handling for `.bel` input

Reuses the exact pattern already in `run_fold`: `In_channel.with_open_text`
for read errors, `Beloch.fold_string` raising `Error.Beloch_error (span, msg)`
rendered via `Diagnostic.render ~source ~span ~msg`, exit 1. No new error
plumbing.

## Out of scope

- No change to `render/render-svg` (TypeScript side) — it keeps only knowing
  FOLD.
- No ANSI/color graying of the `--help` line.
- No caching/memoization of the `which` lookup across the two call sites
  (usage + dispatch run at most once per process invocation each — not worth
  it).

## Testing

- Manual: `beloch render foo.bel out.svg` and `beloch render foo.fold out.svg`
  both produce SVG; `PATH= beloch --help` shows the `[unavailable: ...]` hint
  on the render line; `PATH= beloch render foo.fold out.svg` fails with the
  hint instead of a raw ENOENT.
- `dune test`: a case exercising the `.bel` dispatch path end-to-end if
  `beloch-render` is resolvable in the test environment; skip cleanly if not
  (CI/sandbox may not have the Nix devShell's `PATH`).
