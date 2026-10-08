---
id: "0052"
title: "A fold placed over or under a flap takes the layers between its depth and that flap"
date: 2026-10-02
status: accepted
issue: tophcodes/beloch#203
---

# 0052: A fold placed over or under a flap takes the layers between its depth and that flap

## Context

`def-fold` builds the moving set of a fold from its depth flap, the flap
`up to` names. It adds every candidate joined to the set by a hinge off the
axis, and for the placements *top* and *bottom* every candidate that lies
outward of a face of the set: above it for *top*, below it for *bottom*.
[[decision/0036]] gives `up to` the reading "this flap and outward". For a fold placed
`over T` or `under T` the outward step is missing, so the moving set holds the
depth flap and the layers hinged to it, and nothing else.

Step 13 of the traditional jumping frog folds each side of the body onto the
center line, under the front legs:

```beloch
fold (map .r onto .mm) (up to #[.r .mm .o]) (under #[.mr .o .pbr]) as --s13r
```

The body has two layers, front and back. On one side the folded edge of step 2
joins them, so the hinge closure takes the front layer along with the back
one. On the other side they end in raw edges and share no hinge on the moving
side. There the moving set is the back layer alone, the front layer stays
between it and the leg, and the kernel rejects the state:

```
error: placing the moved material under #[.mr .o .pbr] would pierce layer 11
```

A folder making this step lifts the whole side of the body under the leg and
folds it over: every layer between the depth and the leg goes along, hinged
or not. Selecting by hinges alone leaves a raw-edged layer behind exactly
where a folder takes it.

## Decision

**A placed fold applies outward closure up to its target.** The moving set of
a fold placed `under T` also takes every candidate that lies above a face of
the set and below every face of T it overlaps. A fold placed `over T` takes
every candidate that lies below a face of the set and above every face of T it
overlaps. T itself stays, and so does every layer beyond it. The step
alternates with the closure under hinges off the axis until neither adds a
face.

"Above a face of the set" compares the two faces where their parts on the
moving side overlap, as the outward closure of *top* and *bottom* does. "Below
every face of T it overlaps" compares the candidate's part on the moving side
with each face of T as a whole, since T may straddle the axis; a candidate
that overlaps no face of T is below T. This is the reading `def-reflection`
gives a stationary face against T when it orders a block placed at T.

**`up to` keeps its meaning.** It names the flap the moving set grows outward
from, for placed folds as for the others. Without `up to` the moving set is
every layer on the moving side, as before, and the closure adds nothing.

The closure under hinges off the axis is unchanged.

## Alternatives considered

- **`under T` without `up to` takes everything under T.** The step 13 fold
  would drop its `up to` and read "the side of the body, under the leg". This
  changes what a placed fold without `up to` means: today it takes every layer
  on the moving side, as [[decision/0036]] decided for every fold, and a program would
  read the depth of a placed fold off its target instead of off `up to`. It
  also cannot leave a layer below the depth flap in place, which `up to` does.
- **`up to` names several flaps.** The program would list the front and back
  layers of the body. The writer would have to know which layers share a
  hinge and name the others, by points on parts of the paper the diagram does
  not label, and a list that misses one still fails at the piercing check.
  The folder's step names one flap and one target.

## Consequences

- `def-fold` in [[reference/model]] states the closure for every placement, and
  the paragraph after it and `up to` in [[reference/beloch-writes]] say that a
  placed fold takes the layers between its depth and its target.
- Every program that places a fold folds to the same FOLD file as before: the
  samurai helmet (step 7 tucks the back corner, and no layer lies between it
  and the front layer), the jumping frog through step 13 left, and the test
  cases `tuck-under`, `tuck-over`, `tuck-pierce`,
  `tuck-under-mountain-conflict` and `placed-toward`. In each of them no
  candidate lies between the depth and the target.
- The other side of step 13 of the jumping frog folds.
- A layer that rests on the depth flap without reaching the axis used to stay
  in place under a placed fold, which the end state allowed. It now moves
  with the flap, as it does in the folder's hand. A program that wants it to
  stay names that layer as the target.
