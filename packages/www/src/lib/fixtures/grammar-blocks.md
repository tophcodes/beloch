---
title: Grammar fixture
---

Prose before the first fragment.

## Statements

```grammar
program := "paper" "square" stmt*
stmt    := write_stmt
```

## Write statements

```grammar
write_stmt := "fold" item*
item       := "(" fold_item ")"
```

## Items

```grammar
fold_item    := axis
              | "moving" flap_operand [ "mountain" ]
              | ( "over" | "under" ) flap_operand   ; a placed fold
axis         := CREASE_NAME | flap_operand
reverse_item := axis | "outside"
```

## Grammar

The fragments of the sections above, collected.

```grammar-collected
```

```grammar-external
flap_operand   ; SPECIFICATION.md Appendix A
```

```grammar-planned
align   ; two-fold constructions are not evaluated yet
```
