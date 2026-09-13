// Pandoc's typst writer emits math symbol names from an older typst; the
// ones renamed since are aliased here so `\cap` keeps rendering. Included
// through --include-in-header in scripts/render-model.sh.
#let sect = sym.inter
