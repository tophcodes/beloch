## Why

Two writes decide the layer order of their result on paths of their own. A
plain fold, whose moved paper lands on top of the model or under it, sets
every side from the levels of the moved paper and builds that one state
without the layer search. A fold placed `over` or `under` a flap searches,
but refuses to search more than 12 groups of layers whose side nothing
decides. Every other write, `flatten`, `squash` and `reverse`, finds its
layer order through the layer search, with no such limit. One search for
every write is the first step to a kernel in which every verb folds through
the same operation.

## What Changes

- A plain fold gives the layer search its sides and lets the search check
  the one state they give. Every program folds to the state it folds to
  today.
- **BREAKING** A fold placed `over` or `under` searches any number of
  groups of layers whose side nothing decides. The error "the moved layers
  land on <k> groups of layers whose side nothing decides; the kernel
  searches at most 10" is gone.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `layer-order`: the search over open sides has no bound, and `fold` gives
  the layer search its units like the other verbs.

## Impact

The kernel's fold of blocks and its layer search. `docs/reference/KERNEL.md`
explains which writes use the layer search. A fold that lands on many open
groups costs a search that doubles with every group no condition rejects.
