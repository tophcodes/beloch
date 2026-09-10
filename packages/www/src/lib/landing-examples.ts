/** The Beloch programs the landing page ships: `HERO_SRC`, rendered to a static
 *  SVG at build time, and the `EXAMPLES` row the playground loads into its
 *  editor on click. They live here rather than in the page so a test can
 *  evaluate them — the click-loaded ones reach no evaluator until a visitor
 *  presses a button, so nothing else would notice them going stale. */

export const HERO_SRC = `paper square

mark --diag = through .a .c
mark --ea = map --ab onto --diag
mark --eb = map --ab onto --bc
mark --ec = map --bc onto --diag

flatten (--ea & .a) (--ec & .c) (--eb & .b) {toward .a}`;

const FISH_BASE_SRC = `paper square

mark --diag = map .a onto .c
mark --ray = through .a .c

mark --l1 = map --ab onto --diag
mark --l2 = map --da onto --diag
flatten (--l1 & .b) (--l2 & .d) (--ray & .a) {toward .d}

mark --l3 = map --cd onto --diag
mark --l4 = map --bc onto --diag
flatten (--l3 & .d) (--l4 & .b) (--ray & .c) {toward .d}`;

const KITE_SRC = `paper square

mark --ac = through .a .c
fold map --da onto --ac
fold map --ab onto --ac
; status: works — incidence filter: only one candidate bisector per fold cuts the paper; moving is derived from l1's own material`;

export const EXAMPLES = [
  { label: "Fish base", code: FISH_BASE_SRC },
  { label: "Kite", code: KITE_SRC },
  { label: "Rabbit ear", code: HERO_SRC },
];
