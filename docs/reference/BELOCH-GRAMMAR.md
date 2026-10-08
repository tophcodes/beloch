---
title: Grammar
description: The grammar of the language in one place, each rule linked from the page that says what it means.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

The grammar of the language, in one place. `:=` defines, `|` separates
alternatives, `[ … ]` is optional, `( … )` groups, `*` and `+` repeat,
quoted strings are keywords, upper-case names are tokens, and `;` starts a
comment that runs to the end of the line. The parsers in `packages/core`
and `packages/grammar` are held to it. Each section below names the page
that says what its rules mean.

## Programs

[[reference/beloch|Overview]].

```grammar
program := annotation* [ unit_decl ] shape_def* "paper" sheet stmt*
stmt    := annotation* ( write_stmt | bind_stmt | def_stmt | apply_stmt | export_stmt )
```

## Sheets

[[reference/beloch#sheets]].

```grammar
library    := annotation* [ unit_decl ] shape_def*
unit_decl  := "unit" WORD
sheet      := "square" [ number ]
            | WORD number*
number     := RATIONAL | WORD
shape_def  := "shape" WORD "(" WORD* ")" "{" "paper" sheet shape_stmt*
              "trim" "to" flap_operand [ "{" export_entry+ "}" ] "}"
shape_stmt := write_stmt | bind_stmt | apply_stmt | export_stmt
```

## Free points

[[reference/beloch#free-points]].

```grammar
free_point := "free" "on" line_operand "from" point_operand [ ( "at" | "by" ) number ]
```

## Operands

[[reference/beloch#parameter-types]].

```grammar
flap_operand  := point_operand | line_operand | "#[" point_operand+ "]"
```

## Write statements

[[reference/beloch-writes]].

```grammar
write_stmt := verb item* [ "as" CREASE_NAME [ "!" ] | "into" CREASE_NAME ]
verb       := "mark" | "fold" | "unfold" | "reverse" | "flatten" | "flip"
item       := "(" item_body ")"
item_body  := fold_item | unfold_item | reverse_item | mark_item | flatten_item
```

```grammar
fold_item    := axis
              | side_item
              | "up" "to" flap_operand
              | "mountain"
              | ( "over" | "under" ) flap_operand
unfold_item  := line_operand
              | [ toward_subject ] "toward" ( point_operand | line_operand )
              | "moving" flap_operand [ "up" | "down" ]
              | "up" "to" flap_operand
reverse_item := axis
              | side_item
              | "outside"
              | line_operand ( "mountain" | "valley" )
mark_item    := axis
              | side_item
              | "on" flap_operand
              | "between" point_operand point_operand
              | "at" point_operand
              | "mountain" | "valley"
flatten_item := line_operand [ "mountain" | "valley" ]
              | flap_operand "over" flap_operand
              | "staying" point_operand+
              | "on" flap_operand
              | "toward" point_operand
side_item    := [ toward_subject ] "toward" ( point_operand | line_operand )
              | "moving" flap_operand
axis         := construction_body | line_operand
```

## Constructions

[[reference/beloch-constructions]].

```grammar
construction_body := "align" CREASE_NAME* align_part+
                   | prose_axiom
align_part        := alignment
                   | "(" "heading" line_operand ")"
alignment         := "(" [ CREASE_NAME ] object "onto" [ CREASE_NAME ] object ")"
                   | "(" [ CREASE_NAME ] "through" point_operand ")"
                   | "(" [ CREASE_NAME ] "perp" line_operand ")"
object            := point_operand | line_operand
prose_axiom       := "through" point_operand point_operand
                   | "map" point_operand "onto" point_operand
                   | "perp" line_operand "through" point_operand
                   | "map" point_operand "onto" line_operand "perp" line_operand
                   | "map" line_operand "onto" line_operand
                   | "map" point_operand "onto" line_operand "through" point_operand
                   | "map" point_operand "onto" line_operand
                         "and" point_operand "onto" line_operand
line_binding      := CREASE_NAME "=" "(" construction_body ")" side_item*
```

```grammar
toward_subject := point_operand | line_operand
```

## Annotations

[[reference/beloch-annotations]].

```grammar
annotation := "@" WORD arg* NEWLINE
            | "@" WORD ":" WORD value* NEWLINE
arg        := value | WORD
value      := flap_operand | TEXT | RATIONAL
```

## Defined elsewhere

A rule the grammar refers to and states nowhere yet, with its home.

```grammar-external
point_operand   ; SPECIFICATION.md Appendix A
line_operand    ; SPECIFICATION.md Appendix A
bind_stmt       ; SPECIFICATION.md Appendix A
def_stmt        ; SPECIFICATION.md Appendix A
apply_stmt      ; SPECIFICATION.md Appendix A
export_stmt     ; SPECIFICATION.md Appendix A
export_entry    ; SPECIFICATION.md Appendix A
```
