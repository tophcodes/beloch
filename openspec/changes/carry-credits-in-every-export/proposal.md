## Why

A program declares who wrote it, who designed its model and which sequence it
follows, and the FOLD file carries these credits. The drawings Beloch writes
from a program carry none of them: the SVG and the PNG of `beloch render` and
the SVG the playground downloads or copies. A drawing passed on without its
FOLD file loses the credit of the model's designer, though Beloch held it a
step earlier.

## What Changes

- Every SVG and PNG that Beloch writes from a program, through `beloch
  render` or the playground, carries the credits the program declares, as
  text a reader of the file finds without drawing it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `architecture`: declared credits reach every export, beyond the FOLD file.

## Impact

The SVG writer in `packages/render-2d`, the PNG path of `beloch render`, and
the export of the playground in `packages/www`; the section on
`beloch render` in `docs/reference/CLI.md`.
