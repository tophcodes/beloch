/**
 * Ad-hoc tree-sitter grammar for Beloch (.bel).
 *
 * Deliberately flat and error-tolerant: it classifies the lexical tokens the
 * real evaluator recognizes (see lib/lexer.ml, lib/parser.mly) so it can
 * drive syntax highlighting for static code viewers and the playground
 * editor. It is NOT a faithful parse of Beloch's grammar — highlighting only
 * needs token classes, and a permissive grammar keeps half-typed editor
 * input highlighting cleanly.
 */
module.exports = grammar({
  name: 'beloch',

  extras: $ => [/[ \t\r\n]+/],

  rules: {
    source_file: $ => repeat($._token),

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

    // statement verbs, clause words, and axiom names — see lib/lexer.ml
    keyword: _ => choice(
      'paper', 'square',
      'mark', 'fold', 'collapse', 'flip', 'def', 'apply', 'export',
      'through', 'map', 'onto', 'perp', 'toward',
      'and', 'moving', 'up', 'to', 'mountain', 'over', 'standing',
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
