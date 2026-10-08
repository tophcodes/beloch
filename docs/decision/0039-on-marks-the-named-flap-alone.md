---
id: "0039"
title: "on marks the named flap alone, where the folder opens the model to do it"
date: 2026-09-29
status: accepted
issue: tophcodes/beloch#52
---

# 0039: on marks the named flap alone, where the folder opens the model to do it

## Context

By ADR 0036 a `mark` without `on` scores every layer its line crosses, and
`on` names the one flap it scores. ADR 0036 left open what `on` means for a
mark the finger cannot make on the folded model: one layer of a flap that is
hinged to other layers along the line.

The book fold of #105 shows both kinds. The short crease `--y` near the
corner runs from raw edge to raw edge, and the upper layer creases along it
alone. The corner bisector `--x` runs from the corner to the spine; the
triangle of the upper layer beside it hangs on the lower layer at the spine,
and creasing the upper layer along it moves the lower layer too.

```beloch
paper square
fold (map --ab onto --cd) (moving .a) as --m
.f = --m * --bc
mark (map --da onto --cd) (toward .f) (on #[.a]) as --x
```

A folder makes the second crease anyway: they open the model partway, crease
the one layer and close it again. The state before and the state after are
flat and valid; the opened model between them is not a flat state, and no
statement of the language describes it.

## Decision

**`on` scores the named flap and no other layer, whether or not that flap
can be creased on the closed model.** Such a mark stands for a crease made
with the model opened partway. The opening and the closing are not steps of
the program, and the write succeeds.

## Alternatives considered

- **`on` scores the tip of the named flap**, every layer that comes along
  when the flap is creased, as a fan moves its tip (ADR 0037). Along `--x`
  that scores both layers, and a mark on the upper layer alone has no
  statement.
- **`on` scores the named flap and fails where it cannot move alone.** The
  error would name the layers that come along. It refuses a crease that a
  folder makes by opening the model.

## Consequences

- `def-mark` in `docs/reference/MODEL.md` keeps its reading for a mark with `on`.
- A step that creases one layer of a flap hinged to others along the line
  cannot be drawn as a plain crease in a folding diagram; it needs the
  opening shown or noted. The test that finds such a step is whether the
  named flap, creased along the line, drags other layers along. #116 takes
  up how the diagram shows it.
