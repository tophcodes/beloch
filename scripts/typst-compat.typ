// Pandoc's typst writer emits math symbol names from an older typst; the
// ones renamed since are aliased here so `\cap` keeps rendering. Included
// through --include-in-header in scripts/render-model.sh.
#let sect = sym.inter

// Grammar notation (scripts/grammar-blocks.lua). The filter carries a span's
// class as the `raw` language, so one show rule per class colours the grammar
// pages. The same class names carry the web colours in
// packages/www/src/styles/theme.css; these are the print values, set for black
// ink on white paper rather than for the navy code panel.
#show raw.where(lang: "gr-rule"): it => text(fill: rgb("#8A5A2B"), weight: "bold")[#it]
#show raw.where(lang: "gr-nonterminal"): it => text(fill: rgb("#2F5F72"))[#it]
#show raw.where(lang: "gr-keyword"): it => text(fill: rgb("#8A5A2B"))[#it]
#show raw.where(lang: "gr-token"): it => text(fill: rgb("#6B6B4A"))[#it]
#show raw.where(lang: "gr-operator"): it => text(fill: rgb("#5A6472"))[#it]
#show raw.where(lang: "gr-comment"): it => text(fill: rgb("#4F6B45"), style: "italic")[#it]

// Figure highlights (scripts/model-blocks.lua). A caption's inline code for a
// highlighted entity is emitted as raw with its palette class as the language,
// so it prints in the colour the figure draws that entity in. A caption is
// text and needs 4.5:1, which the strokes the drawing uses do not hold on
// white: these are HIGHLIGHT_TEXT in @beloch/render-svg's theme.ts, the same
// values .figure-hl-<n> carries in packages/www/src/styles/theme.css.
// theme-tokens.test.ts holds the three lists together.
#show raw.where(lang: "figure-hl-0"): it => text(fill: rgb("#1C6B33"))[#it]
#show raw.where(lang: "figure-hl-1"): it => text(fill: rgb("#c2004f"))[#it]
#show raw.where(lang: "figure-hl-2"): it => text(fill: rgb("#8a2fd6"))[#it]
#show raw.where(lang: "figure-hl-3"): it => text(fill: rgb("#b25600"))[#it]
#show raw.where(lang: "figure-hl-4"): it => text(fill: rgb("#0b6fb0"))[#it]
#show raw.where(lang: "figure-hl-5"): it => text(fill: rgb("#5f6600"))[#it]
