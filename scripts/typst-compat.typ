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
// so it prints in the colour the figure draws that entity in. Same values as
// HIGHLIGHT_PALETTE in @beloch/render-svg's theme.ts and .figure-hl-<n> in
// packages/www/src/styles/theme.css.
#show raw.where(lang: "figure-hl-0"): it => text(fill: rgb("#0d9488"))[#it]
#show raw.where(lang: "figure-hl-1"): it => text(fill: rgb("#c2620a"))[#it]
#show raw.where(lang: "figure-hl-2"): it => text(fill: rgb("#9a52d8"))[#it]
#show raw.where(lang: "figure-hl-3"): it => text(fill: rgb("#db2777"))[#it]
#show raw.where(lang: "figure-hl-4"): it => text(fill: rgb("#5f9412"))[#it]
#show raw.where(lang: "figure-hl-5"): it => text(fill: rgb("#0284c7"))[#it]
