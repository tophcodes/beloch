---
title: Names and definitions
description: How a program names what it makes, binds each name once, and reuses a sequence of statements as a definition applied to new operands.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

A statement refers to what earlier statements made by name, and nothing
else carries a value from one statement to the next. This page states what
a name is, how a statement binds one, and the three constructs that give a
program structure beyond a list of statements: a *definition* records a
sequence of statements under a name, an *application* runs it on operands
of the caller's choosing, and an *export* brings the names the application
made into the scope of the caller. The three share one evaluation path. A
definition runs nothing, an application is the only form that runs a body,
and an export reads from the result of an application and runs nothing.

## Names

A name is a sigil followed by an identifier. The identifier is one or more
of the letters `a` to `z` and `A` to `Z`, the digits and `_`, and the
sigil says what the name stands for:

| sigil | stands for | bound by |
|---|---|---|
| `.` | a point | `.p = …`, a parameter, an export |
| `--` | a line or a crease ([[reference/beloch#parameter-types]]) | `--l = …`, `… as --c`, a parameter, an export |
| `$` | an instance, the result of an application | `$i = apply …` |
| none | a definition, a shape, or a parameter of a shape | `def`, `shape` |

Points, lines and instances are three namespaces: `.m`, `--m` and `$m` may
stand side by side. Definitions and shapes share one namespace for the
whole file, so a `def` of a shape's name is an error
(`` <name> is already defined as a shape ``) and a second `def` of a name is
one too (`` def <name> is already defined ``). A `;` starts a comment that
runs to the end of the line.

A program runs top to bottom, and a name is bound before it is used. A
reference to a name no statement bound is an error that names the kind and
lists the names of that kind in scope, at most twelve before an ellipsis
(`` undefined point .m ``, `` undefined crease --m ``,
`` undefined instance $m ``).

**Bindings.** `=` binds a point or a line to the value on its right, and
the right side says which sort the name gets:

```{.bel .prelude name=lines}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
```

```{.bel .frag prelude=lines}
.o  = --ac * --bd                   ; a point: the meet of two lines
.p  = free on --ac from .a at 1/4   ; a point: a free point
--m = (map --ab onto --cd)          ; a line: a construction, scoring nothing
--e = --ac & .o                     ; a line: a selection from a crease

; assert .o = (1/2, 1/2)
; assert faces = 1
```

A point is bound by a meet ([[reference/beloch#reads-and-writes]]) or by
`free on` ([[reference/beloch#free-points]]), and by nothing else: there is
no way to give a second name to a point that has one. A line is bound by a
construction, which computes the line and scores nothing, or by an operand
that selects from the lines and creases already there
([[reference/beloch-constructions]]). A crease is bound by the output clause
of a write, `as --c` ([[reference/beloch-writes]]), and an
instance by an application (below).

**One binding per name.** Within one scope a name without the `_` prefix
is bound at most once. A second binding is an error
(`` point .m is already bound; only _-prefixed temps rebind ``, and the same
for a crease and an instance), and the corners `.a` to `.d` and the edges
of the sheet count as bound by `paper`. The one exception is the output
clause of a write: `as --c!` rebinds `--c` on purpose, and the `!` is the
mark that the reader sees it ([[reference/beloch-writes]]).

**Temps.** A name whose identifier starts with `_` (`._m`, `--_h`, `$_i`)
is a *temp*. A temp may be bound again in the same scope, and the `_`
shows at every use that it may have changed since the last one. A temp is
invisible from outside its scope: it is no member of an instance, an
export cannot name it, and the output does not list it. A write bound to a
temp crease still scores and folds; its crease is unnamed in the output.

```{.bel .frag prelude=lines}
._x = --ac * --ab        ; the corner .a
._x = --ac * --bd        ; rebound: now the center
mark (map .a onto ._x) as --_fold

; assert faces = 1
```

## Definitions

A definition records a sequence of statements under a name, with the
points and lines the statements need as parameters:

```{.bel .prelude name=center}
paper square
mark (map --ab onto --cd) as --h
mark (map --da onto --bc) as --v
.o = --h * --v
```

```{.bel .frag prelude=center}
def corner(.p .o) {
  fold (map .p onto .o) (moving .p) as --c
}

apply corner(.a .o)
apply corner(.b .o)
apply corner(.c .o)
apply corner(.d .o)

; assert steps = 4
; assert faces = 8
; assert .a = .o
```

- A definition stands at the top level of a file. Its name is a bare
  identifier, so it is never an operand and needs no sigil. The
  grammar admits no `def` inside a body, and a shape body holds none
  (`` a shape body holds no def ``).
- Each parameter carries its sigil and is a point (`.p`) or a line
  (`--l`); a parameter of another type is not in the language. Two
  parameters of one name are an error (`` duplicate parameter <name> ``), and
  a definition without parameters is written with empty parentheses,
  `def name() { … }`.
- The body holds the statements of a program: writes, bindings,
  applications, exports and annotations ([[reference/beloch-annotations]]).
  It holds no `paper`, no `shape` and no `def`.
- **The scope of a body is closed.** A statement in the body sees the
  parameters, the names the body itself bound before it, and the
  definitions written earlier in the file. It sees nothing of the scope
  the application stands in: not the corners and edges of the sheet, whose
  places depend on the folds before the application, and not the names the
  program bound at the top level. A body that needs a corner takes it as a
  parameter, as `corner` takes `.o`. Because a body sees only earlier
  definitions, a definition cannot apply itself, directly or through
  another (`` def <name> is not defined before this body ``).
- **A definition runs nothing.** The body is parsed when the file is read
  and evaluated at each application. A body no program applies is never
  evaluated, so its errors of evaluation are never reported.

## Applications

An application runs a definition on operands, against the state the
program is in, and yields an *instance*: the names the body bound.

```{.bel .frag prelude=center}
def corner(.p .o) {
  fold (map .p onto .o) (moving .p) as --c
}

$a = apply corner(.a .o)           ; runs now, the instance is kept
$b = apply corner(.b .o)
export { --c as --ca } $a
export { --c as --cb } $b
.e = --ca * --cb                   ; the point where the two creases meet

; assert faces = 6
; assert .e = (1/2, 0)
```

- `$name = apply def(args)` keeps the instance under the name;
  `apply def(args)` runs the body and keeps nothing. Both run the body at
  once, so the program's state after the statement is the state the body
  left.
- `apply` is the only right side a `$`-binding takes, and `$name` is bound
  once like every other name
  (`` instance $i is already bound; only _-prefixed temps rebind ``). A
  temp instance, `$_i`, rebinds.
- The arguments are operands, written as in any statement, and resolved
  in the scope of the application before the body runs. They match the
  parameters by position, and the sigil of each argument has to agree with
  its parameter (`` def <name> takes 2 argument(s), got 1 ``,
  `` parameter .p of <name> needs a point argument ``,
  `` parameter --l of <name> needs a line argument ``).
- A crease named as an argument passes the crease itself, its material
  ([[reference/model#def-bundle|def-bundle]]): the body can meet it and fold
  along it as later folds bend it. A selection or a filter
  (`--[…]`, `&`, `\`, `[…]`) passes the line it resolves to at the
  application.
- The instance holds the parameters and every point and line the body
  bound, except the temps. An instance the body bound is no member: a
  nested application reaches the caller only through what the body
  exports from it.

**In the output.** An application has an entry of its own in
`beloch:statements`, naming the definition, and the entries of its body
follow it, each naming the application as its parent; a body statement
is logged once per application that runs it ([[decision/0030]]). A crease
scored under a kept instance carries the instance's name before its own,
`a.c` for `--c` of `$a`, and `o.in.pq` through a nested application; under
a bare `apply` or a temp instance it is unnamed. `beloch:named_points` and
`beloch:named_lines` list the names of the top level, the exported names
among them ([[reference/fold]]).

## Exports

An export copies members of an instance into the current scope. It reads
from the instance and runs nothing, so the geometry it lands is the
geometry the application left.

```{.bel .frag prelude=center}
def corner(.p .o) {
  fold (map .p onto .o) (moving .p) as --c
  .x = --c * --h                       ; where the crease meets --h
  .t = free on --c from .x             ; a point on the crease
}

$a = apply corner(.a .o)
export { .t --c } $a                   ; selective: these two names
export { .t as .left } $a              ; renamed on landing
export $a                              ; every member: .p .o .x .t --c

; assert faces = 3
```

- An entry names a member with its sigil. `as` lands it under another name
  of the same sigil (`` export rename must keep the kind ``). The landed
  name is the member itself: `beloch:named_points[].statement` and
  `beloch:named_lines[].statement` report the statement of the body that
  made it, not the export ([[reference/fold]]).
- `export $i` lands every member of `$i`, the parameters included, and
  checks each landed name on its own. Two applications of one definition
  exported whole collide on every member name; `as` on a selective export
  tells them apart.
- A landed name is bound once like every other. Landing on a name that is
  bound is an error (`` --c exists ``, with the hint `` use ! to shadow ``),
  and `!` after the member marks a deliberate shadow: `export { --c! } $a`
  rebinds `--c`. A `!` where nothing is bound is an error too
  (`` nothing to shadow with --c ``, hint `` remove ! ``). Landing on a temp,
  `export { .t as ._t } $a`, needs no `!`, since a temp rebinds anyway.
- A member the instance does not have is an error
  (`` instance $a has no point member x ``), and a temp of the body is never a
  member, so naming one is the same error. An instance no application
  bound is `` undefined instance $a ``.
- An export inside a body lands into the body's scope. A nested
  application's names reach the top level by two exports, one in the body
  and one at the top:

```{.bel .frag prelude=lines}
def midpoint(.p .q) {
  --pq = (through .p .q)
  .m = free on --pq from .p
}
def diagonal(.p .q) {
  mark (through .p .q) as --d
  $mid = apply midpoint(.p .q)
  export { .m } $mid
}

$ac = apply diagonal(.a .c)
export { .m as .o } $ac

; assert .o = (1/2, 1/2)
```

```{.bel .frag prelude=lines}
def diagonal(.p .q) {
  mark (through .p .q) as --d
}

$ac = apply diagonal(.a .c)
export { --d as --ac } $ac

; expect error "--ac exists"
```

## The rule of rebinding

One rule covers the top level, the bodies of definitions and the landing
names of exports: **a name without the `_` prefix is bound at most once
per scope.**

| situation | result |
|---|---|
| a name bound twice in one scope, at the top level or in a body | error |
| a corner `.a` to `.d` bound at the top level | error |
| a definition's name used for a second definition or a shape | error |
| an export lands on a bound name without `!` | error |
| an export lands with `!` on a name that is not bound | error |
| a write's `as --c` on a bound name without `!` | error |
| a temp bound more than once | allowed |
| an export lands on a temp, with or without `!` | allowed |
| a write's `as --c!` on a bound name | allowed |
