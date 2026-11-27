## Why

`reverse` folds through the fan: it cuts its tip along the axis, moves each
piece by the changing hinges on its paper path and orders the result with
the layer search. `fold` and `unfold` do the same steps on a path of their
own. Two code paths that compute the same fold can drift apart, and every
rule of the fan has to be stated twice. A fold is the fan whose vertex lies at
the point at infinity of its axis: one line, two half-planes as sectors, and
every layer the axis crosses under the vertex.

## What Changes

- `fold` and `unfold` fold through the fan at the point at infinity of their
  axis, the fan `reverse` folds through. `unfold` is that fan with no layer
  to cut and only folded hinges on the axis to open.
- Every program folds to the state it folds to today, and every error keeps
  its message.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `multifold`: `fold` and `unfold` hand the fan the point at infinity of
  their axis.

## Impact

The kernel's fold of blocks and the reverse fold, which share the fan after
the change. `docs/reference/KERNEL.md` explains which writes fold through
the fan at a point at infinity.
