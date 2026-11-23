## Why

An annotation whose key carries a namespace, such as `@yr:hold .a`, belongs
to the output library that owns the namespace. The kernel checks its shape
and passes it into the FOLD file, and there it stops: no library reads any
namespaced annotation, so a program can write `@yr:hodl .a` and no reader
ever learns that the key means nothing. The library that owns a namespace
has to read its annotations and decide what an unknown key means for it.

## What Changes

- An output library reads the annotations of the namespace it owns and
  decides what a key it does not know means for it.
- The YR library owns the namespace `yr`, and its diagram reports a `yr` key
  it does not know.

Out of scope: the keys of `yr` and what each draws. Each key enters with a
change of its own.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `annotations`: the output library that owns a namespace reads its
  annotations.

## Impact

The YR library in `packages/render-2d/yr` and the hints that `beloch render
--view yr` prints; the section on annotations of an output in
`docs/reference/BELOCH-ANNOTATIONS.md` and the YR view in
`docs/reference/CLI.md`.
