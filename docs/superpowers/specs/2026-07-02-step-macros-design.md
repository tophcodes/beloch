# Beloch — Steps, Namespaces & Macros (Design)

- **Date:** 2026-07-02
- **Status:** Approved

## 1. Motivation

Beloch programs grow into flat lists of bindings. Two problems:

1. **Namespace pollution** — every intermediate point/line lives in root scope; names collide and context is lost.
2. **No instruction grouping** — the planned instruction-JSON output (ADR 0002) needs step boundaries; without them every action is a separate diagram step, which is unusable for real folding instructions.

Earlier idea: add description strings to individual folds. Rejected — descriptions drift as soon as the source changes. The source must own the grouping.

## 2. Binding syntax change: `:` → `=`

All named bindings switch from colon to equals:

```beloch
; before
--rs: through .rs1 .rs2
.s: cross --rs --(.d .c)

; after
--rs = through .rs1 .rs2
.s = cross --rs --(.d .c)
```

`:=` is not introduced — Beloch constructions are immutable, so there is no reassignment case.

## 3. Shorthand expressions as RHS

`.(--a --b)` (point at intersection) and `--(.p1 .p2)` (line through two points) already exist as inline arguments. They can now appear as the RHS of any binding:

```beloch
.s  = .(--rs --(.d .c))   ; sugar for: cross --rs --(.d .c)
--e = .(.p1 .p2)           ; sugar for: through .p1 .p2
```

RHS of a binding is any expression, not only a named axiom call.

## 4. Steps

Steps are the single unified concept for grouping and namespacing. `def` does not exist as a separate keyword — parameterized steps cover the macro use case.

### 4.1 Anonymous step

```beloch
step {
  @axiom3 .e1 .e2
  @map .a onto --(.b .c)
}
```

Groups actions for display in the instruction output. Bindings inside are local.

### 4.2 Named step

```beloch
$thirds = step {
  .pq1 = cross --(.d .mb) --(.a .c)
  --pq  = through .pq1 .pq2
  .s    = .(--rs --(.d .c))
}
```

`$thirds` becomes the display name in the instruction output. All bindings private. Not callable — the `$` binding is for display naming and post-hoc export only.

### 4.3 Parameterized step

```beloch
$bird-base = step(.p --e) {
  $diagonal = step {
    @map .p onto --(.a .c) moving .p
  }
  $petal = step {
    @map .a onto .p moving --e
  }
}
```

Parameters typed by sigil: `.name` = point, `--name` = line. Closed scope — body sees only its parameters. Callable via `apply`.

### 4.4 Naked actions

Actions outside any step appear **flat** in the instruction output — no implicit wrapper.

## 5. `export` and `inline`

`export` and `inline` are expression wrappers with namespace side effects:

```
export { NAMES } EXPR  →  returns EXPR, assigns NAMES into enclosing scope (grouped display)
inline EXPR            →  returns EXPR, assigns all bindings into enclosing scope (flat display)
```

| Form | Namespace | Display |
|---|---|---|
| `step { }` | private | grouped |
| `export { names } EXPR` | named names escape one level | grouped |
| `export EXPR` | all bindings escape one level | grouped |
| `inline EXPR` | all bindings escape one level | flat |

`EXPR` can be a step literal, a named step reference, or an `apply` call.

### 5.1 Anonymous step — both forms valid

```beloch
export { --pq .s } step { ... }   ; selective
export step { ... }               ; all
inline step { ... }               ; all, flat display
```

### 5.2 Named step — inline and post-hoc both valid

```beloch
; inline — author declares upfront what escapes
$thirds = export { --pq .s } step { ... }

; post-hoc — consumer decides later (or library user pulls what they need)
$thirds = step { ... }
export { --pq } $thirds
```

Both are valid. Same semantic: `--pq` assigned in enclosing scope, `$thirds` still exists for display.

### 5.3 Apply call

```beloch
apply $bird-base(.corner --(.a .b))                    ; nothing exported
export { .tip } apply $bird-base(.corner --(.a .b))    ; selective
export apply $bird-base(.corner --(.a .b))             ; all
inline apply $bird-base(.corner --(.a .b))             ; all, flat display
```

`apply` has no return value — `export`/`inline` here only produce namespace side effects.

### 5.4 Re-export

`export` propagates one level at a time. To lift further, apply `export` again:

```beloch
$outer = step {
  $inner = export { --pq .s } step { ... }
  ; --pq and .s now in $outer's scope

  ; re-export selectively:
  export { --pq } $inner     ; or just: export { --pq } (re-export name already in scope)
  ; or wildcard:
  export $inner              ; lifts everything $inner exported
}
; --pq now in root scope
```

### 5.5 Shadowing is an error

Exporting a name that already exists in the enclosing scope is an error. Use `as` to rename:

```beloch
export { --rs as --thirds-rs } step { ... }
; original --rs unchanged; --thirds-rs is the new name
```

## 6. Instruction-JSON mapping

| Source construct | Instruction output |
|---|---|
| Naked action | Flat entry |
| `step { }` / `export { } step { }` / `export step { }` | Unlabelled group |
| `inline step { }` | Flat (no group) |
| `$name = step { }` | Named group (`"name"`) |
| `apply $name(args)` / `export { } apply` / `export apply` | Named group (`"name"`) |
| `inline apply $name(args)` | Sub-steps merged into parent, flat |

## 7. Cube-root example, restructured

```beloch
paper square

--vm = map .a onto .b    ; flat

$thirds = export { --pq .s } step {
  .mb  = .(--vm --(.a .b))
  .mt  = .(--vm --(.d .c))
  .pq1 = cross --(.d .mb) --(.a .c)
  .pq2 = cross --(.a .mt) --(.d .b)
  --pq = through .pq1 .pq2
  .rs1 = cross --(.c .mb) --(.d .b)
  .rs2 = cross --(.b .mt) --(.a .c)
  --rs = through .rs1 .rs2
  .s   = .(--rs --(.d .c))
}

$beloch-fold = step {
  @map .c onto --(.a .b) and .s onto --pq
}
```

## 8. Out of scope

- String labels on steps (identifier = display name; renaming is intentional, not drift).
- `:=` / mutable rebinding.
- Higher-order macros (macros as arguments).
- Module/file-level namespacing (separate concern).

## 9. Deferred / possible future ideas

See `ideas.md` in the repo root.
