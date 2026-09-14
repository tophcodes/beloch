# Fixture

A prelude, never rendered.

```{.bel .prelude name=p}
paper square
mark (through .a .c) as --sentinel-prelude-marker
```

A fragment with a verified assert.

```{.bel .frag}
mark (through .a .c) as --ac

; assert faces = 1
; assert faces = 2
```

A whole program with an expected error.

```bel
paper square
fold (map .a onto .c) (moving .a) (over .b) (mountain)
```

A fragment the capture tool has not run for yet.

```{.bel .frag}
mark (through .b .d) as --bd
```

A whole program with an unexpected error.

```bel
paper square
fold (map .a onto .c) (moving .a) (bogus)
```

A fragment whose expected error never fired.

```{.bel .frag}
mark (through .a .c) as --ac3

; expect error "something that never happens"
```
