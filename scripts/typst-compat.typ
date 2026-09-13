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
