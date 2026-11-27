## Why

Every item of a `flatten` is a condition on its set of legal states (spec
`multifold`, "Every item of a flatten is a condition on its states"), and the
outline rule is the one stage left that ranks them: of the states of a
`flatten` or a `squash`, it keeps those that lie on the table inside the
convex hull of the state before the write where there are any, and all of
them where there are none. A ranking keeps a different set depending on what
else the fan could do, so a program cannot tell from its own items which
state it gets.

At the fish-base vertex, `flatten (--l1 valley) (--l2) (--ray mountain)` has
eight legal states. Four of them take the halves of `--l1`, `--l2` and
`--ray` that run to the corners `.b`, `.d` and `.a`; the other four take the
opposite halves and lay most of the square down beside its old place. The
outline drops the second four without the program saying so. A `staying`
item already says the same thing as a condition: `(staying .c)` keeps the
part around `.c` where it lies, and none of the second four can do that.

The default stayer is the other place where a `flatten` decides something
its items do not say. It saves the `staying` item only where the parts of a
fan differ in size; a symmetric collapse from the open sheet ties under any
default, and every `flatten` in `examples/` but one either writes `staying`
or would need it.

## What Changes

- **BREAKING** The outline ranking of `flatten` and `squash` is removed. A
  program that relied on it to drop the states past the outline names what
  stays with `(staying …)`, a half of a line with `&`, or the side of the
  emergent ray with `(emergent beside …)`, or it fails as ambiguous.
- **BREAKING** Every `flatten` holds a `staying` item, as Fisher's
  `multifold … holding Face` names its face that does not move. The default
  stayers of today, the part of largest area for fan items and the wedge
  between the first two rays for ray items, are removed.
- The stayer fixes only where the result lies on the table; no ranking reads
  it any more.
- A reverse fold no longer needs a requirement that exempts it from the
  outline, since no fold ranks by the outline.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `multifold`: the outline ranking and the default stayer are removed; every
  `flatten` names the part that stays; the stayer requirement stops naming
  the outline.
- `reverse-fold`: the requirement that exempts a reverse fold from the
  outline ranking is removed.

## Impact

The kernel's fan solving for `flatten`, `squash` and the fans of several
vertices, and the check of a `flatten`'s items. Every `flatten` without
`staying` gains one: seven statements in `examples/` and `packages/www`, and
the kernel cases and reference fragments that leave it out. The fish-base
cases name what stays, and the rabbit ear without conditions in
`docs/reference/BELOCH-WRITES.md` writes `(staying .d)`. The pages
`docs/reference/MODEL.md`, `docs/reference/KERNEL.md` and
`docs/reference/BELOCH-WRITES.md` describe the outline ranking and the
default stayer and change with them.
