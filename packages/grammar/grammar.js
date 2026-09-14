/**
 * Ad-hoc tree-sitter grammar for Beloch (.bel).
 *
 * Deliberately error-tolerant: alongside the lexical tokens the real
 * evaluator recognizes (see lib/lexer.ml, lib/parser.mly), it structures
 * write statements (`mark`/`fold`/`reverse`/`flatten`/`flip`) into one named
 * node per item type, matching the union-of-heads shape of `lib/parser.mly`'s
 * `item_body`: every head is accepted under every verb, so a head the verb
 * rejects still parses into a named node and the diagnostic comes from the
 * kernel rather than from an ERROR node. Everything else (binds, `def`,
 * `apply`, `export`) stays a flat run of tokens; highlighting only needs
 * token classes there, and a permissive grammar keeps half-typed editor
 * input highlighting cleanly.
 */
module.exports = grammar({
  name: 'beloch',

  // lib/lexer.ml skips `;`-to-end-of-line wherever it appears, including
  // inside an item's or a construction's parentheses.
  extras: $ => [/[ \t\r\n]+/, $.comment],

  rules: {
    source_file: $ => repeat(choice($.write_statement, $.construction, $._token)),

    // the five writes: a verb, its items in any order, its output clause.
    // Each alternative is right-associative on its own repeat so that a
    // trailing `as`/`into`/`(` is always shifted into the same statement
    // rather than read as the start of the next top-level thing (a bare
    // `(align …)` construction, or an `as`/`into` that has no meaning
    // outside a write statement's own output clause).
    write_statement: $ => choice(
      prec.right(seq('mark',    repeat($._axis_item), optional($.output_clause))),
      prec.right(seq('fold',    repeat($._axis_item), optional($.output_clause))),
      prec.right(seq('reverse', repeat($._axis_item), optional($.output_clause))),
      prec.right(seq('flatten', repeat($._ray_item),  optional($.output_clause))),
      prec.right(seq('flip',    repeat($._axis_item), optional($.output_clause))),
    ),

    // the crease a write scores: bound to a new name, added to an existing
    // crease, or left anonymous (no clause)
    output_clause: $ => choice(
      prec.right(seq('as', $.crease, optional('!'))),
      seq('into', $.crease),
    ),

    // _axis_item and _ray_item are the same union of heads and differ in one
    // alternative: the bare-line item is `axis_item` under the four axis
    // verbs and `flatten_element` under `flatten`.
    _axis_item: $ => choice(
      $.construction,
      $.axis_item,
      $.anchor_item,
      $.depth_item,
      $.placement_item,
      $.kind_item,
      $.intent_item,
      $.extent_item,
      $.layer_item,
      $.order_item,
      $.stayer_item,
      $.selection_item,
    ),

    _ray_item: $ => choice(
      $.construction,
      $.flatten_element,
      $.anchor_item,
      $.depth_item,
      $.placement_item,
      $.kind_item,
      $.intent_item,
      $.extent_item,
      $.layer_item,
      $.order_item,
      $.stayer_item,
      $.selection_item,
    ),

    // a bare crease name, with an optional inline mountain/valley pin:
    // `(--d)`, `(--d mountain)`, under mark/fold/reverse/flip
    axis_item: $ => seq('(', $._operand, optional($._mv), ')'),

    // the same shape under flatten, where each ray can carry its own pin:
    // `(--l)`, `(--l mountain)`
    flatten_element: $ => seq('(', $._operand, optional($._mv), ')'),

    _mv: _ => choice('mountain', 'valley'),

    // `(moving .a)`
    anchor_item: $ => seq('(', 'moving', $._operand, ')'),

    // `(up to .c)`
    depth_item: $ => seq('(', 'up', 'to', $._operand, ')'),

    // `(over .b)`, `(under .p)`
    placement_item: $ => seq('(', choice('over', 'under'), $._operand, ')'),

    // `(outside)`
    kind_item: $ => seq('(', 'outside', ')'),

    // `(mountain)`, `(valley)`, standalone
    intent_item: $ => seq('(', $._mv, ')'),

    // `(between .m .o)`, `(at .x)`
    extent_item: $ => seq('(', choice(
      seq('between', $._operand, $._operand),
      seq('at', $._operand),
    ), ')'),

    // `(on #[.c])`
    layer_item: $ => seq('(', 'on', $._operand, ')'),

    // `(.q over .r)`
    order_item: $ => seq('(', $._operand, 'over', $._operand, ')'),

    // `(staying .a)`
    stayer_item: $ => seq('(', 'staying', $._operand, ')'),

    // `(toward .q)`
    selection_item: $ => seq('(', 'toward', $._operand, ')'),

    // a construction: the canonical `align` over its alignments, or one of
    // the prose spellings that desugar to the same alignments (ADR 0022):
    // `(align (.a onto .c))`, `(map .a onto .c)`, `(through .a .b)`,
    // `(perp --l through .p)`
    construction: $ => prec(1, seq('(', choice(
      seq('align', repeat($.crease), repeat1($.alignment), optional(seq('toward', $._operand))),
      $._prose_axiom,
    ), ')')),

    _prose_axiom: $ => choice(
      seq('through', $._operand, $._operand),
      seq('perp', $._operand, 'through', $._operand),
      seq('map', $._operand, 'onto', $._operand, optional(choice(
        seq('perp', $._operand),
        seq('through', $._operand, optional(seq('toward', $._operand))),
        seq('and', $._operand, 'onto', $._operand, optional(seq('toward', $._operand))),
        seq('toward', $._operand),
      ))),
    ),

    // one alignment inside `align`: `(.a onto .c)`, `(through .a)`,
    // `(perp --l)`, each optionally naming the fold line it constrains
    // (`(--f through .a)`). The `onto` alternative takes that prefix through
    // its own leading `_operand`, which a crease name can start.
    alignment: $ => seq('(', choice(
      seq(optional($.crease), 'through', $._operand),
      seq(optional($.crease), 'perp', $._operand),
      seq($._operand, 'onto', $._operand),
    ), ')'),

    // Operands inside an item stay unstructured: a run of the existing
    // token classes plus a matched parenthesised or bracketed group,
    // excluding the head keywords and `over`: where the literal is a valid
    // token at that position, tree-sitter gives it higher lexing precedence
    // than the identical-length `identifier` regex, so `over` ends the run
    // in `axis_item` and `order_item` rather than being absorbed by it.
    // Where the literal is not valid there, the word falls through to
    // `identifier` and the run swallows it; the kernel rejects what that
    // mis-parses. Closing brackets are matched here rather than accepted bare,
    // so an item's own closing `)` is never mistaken for part of its
    // operand.
    _operand: $ => repeat1(choice(
      $.crease,
      $.point,
      $.instance,
      $.number,
      $.operator,
      $.identifier,
      seq('(', $._operand, ')'),
      seq('[', $._operand, ']'),
      seq($.crease_bracket, $._operand, ']'),
      seq($.point_bracket, $._operand, ']'),
      seq($.flap_bracket, $._operand, ']'),
    )),

    _token: $ => choice(
      $.comment,
      $.keyword,
      $.instance,
      $.crease,
      $.point,
      $.point_bracket,
      $.crease_bracket,
      $.flap_bracket,
      $.number,
      $.operator,
      $.punct,
      $.identifier,
    ),

    // `; ... ` to end of line
    comment: _ => token(seq(';', /[^\n]*/)),

    // clause words and axiom names outside a write statement, see
    // lib/lexer.ml. The five verbs (mark, fold, reverse, flatten, flip) are
    // anonymous tokens under write_statement instead, since a bare verb
    // word is never valid outside one.
    keyword: _ => choice(
      'paper', 'square',
      'def', 'apply', 'export',
      'through', 'map', 'onto', 'perp', 'toward',
      'and', 'moving', 'up', 'to', 'mountain', 'valley', 'over', 'under', 'outside', 'staying',
      'between', 'at', 'as',
      'free', 'on', 'from',
    ),

    // sigils: `--name` is a crease, `.name` is a point, `$name` an instance
    crease: _ => token(seq('--', /[A-Za-z0-9_]+/)),
    point: _ => token(seq('.', /[A-Za-z0-9_]+/)),
    instance: _ => token(seq('$', /[A-Za-z0-9_]+/)),

    // bundle/selector openers: `--[` line-select, `.[` point-select, `#[` flap-select
    crease_bracket: _ => '--[',
    point_bracket: _ => '.[',
    flap_bracket: _ => '#[',

    // exact rationals / integers (not in current surface syntax, kept for
    // robustness so a stray numeral doesn't break highlighting)
    number: _ => /[0-9]+(\/[0-9]+)?/,

    // operators: `=` bind, `!` export-shadow, `&`/`\` bundle filter, `*` meet/join
    operator: _ => choice('=', '!', '&', '\\', '*'),

    // plain grouping/structural punctuation
    punct: _ => choice('{', '}', '(', ')', '[', ']'),

    // bare identifiers: def/apply names
    identifier: _ => /[A-Za-z0-9_]+/,
  },
});
