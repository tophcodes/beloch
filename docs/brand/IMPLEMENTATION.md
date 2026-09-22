# Design language: what is built, what is not

The draft that this implements is `design-language.md` (the conditions) plus
the Claude Design answer to it, which fixed nine decisions. This file says how
far the code follows, so the next piece of work does not have to re-derive it.

## Decided

| # | Decision | Where it lives |
|---|---|---|
| 1 | Interface accent is a teal outside the fold semantics | `--bel-ui-accent` in `theme.css` |
| 2 | Reference mode is light | `light-dark()` in `theme.css`, `index.astro` |
| 3 | Code surface stays dark in both modes | already true |
| 4 | Engine values win over web tokens | `render-svg/src/theme.ts` |
| 5 | Kraft and indigo get the monochrome style only | `colorOk` in `paper-schemes.ts` |
| 6 | Monospace shipped, prose on a system stack | `public/fonts/`, `--bel-font-*` |
| 7 | Wordmark stays monospace | unchanged, already true |
| 8 | A fold animates as a crossfade of two flat states | **not implemented** |
| 9 | Ten syntax roles | `--bel-syntax-*` in `theme.css` |

## Built

- **Crease colours** are the engine's, with no dark-mode variant: a crease is
  always drawn on paper, and the paper schemes set the ground under it. `flat`,
  `unassigned` and `construction` were re-measured and darkened; the old values
  sat at 2.45, 2.05 and below 3:1 on white.
- **Interface state** has its own roles, `--bel-ui-accent`, `--bel-ui-accent-text`
  and `--bel-ui-error`. Fourteen places in the playground used the valley colour
  for focus, selection and the cursor-sync highlight, which put a blue emphasis
  on blue valley folds.
- **Ten syntax roles** replace 22 colours, of which 18 pairs sat below dE76 15.
  Item heads group by what they do, not by which grammar rule produced them.
  The flap selector `#[ ]` has its own role (this changed `highlights.scm`).
- **JetBrains Mono NL**, two weights, subset, with `OFL.txt` and a regeneration
  command in `public/fonts/README.md`. NL is the no-ligature cut, which matters
  because `--` opens a crease name.
- **Highlight palette**, six measured colours, each wash derived by lightening
  its stroke towards white by 0.25, the ratio the previous palette used.
  `HIGHLIGHT_TEXT` carries darkened variants for caption text at 4.5:1 on the
  light page and in print; the dark page takes the stroke lightened towards
  white until it holds 4.5:1 there.
- **Three token layers**, `--bel-paper-*`, `--bel-ui-*` and `--bel-syntax-*`,
  one prefix, the role naming what a colour means. A role that fit two layers
  became two roles: a paragraph takes `--bel-ui-text`, a drawing's ink
  `--bel-paper-ink`. The paper layer now names every role the renderer draws
  with, and `theme-tokens.test.ts` holds the stylesheet, the renderer's `Theme`
  and the typst show rules to the same values.
- **Scale and duration tokens**, and a `prefers-reduced-motion` rule, which the
  site did not have anywhere.
- **Light as the reference mode.** Every interface role is one `light-dark()`
  declaration with the light value first, and `color-scheme` decides which half
  is handed out: with no stored choice the visitor's system decides, on the
  landing as well as in the docs. The landing no longer pins dark before the
  first paint.

## Not built, and why

- **The fold crossfade.** There is no motion on the drawing at all today, so
  this is new behaviour rather than a change to existing behaviour.
- **A colour/monochrome style switch.** `colorOk` says which papers may offer
  the coloured style, but nothing offers it yet: the renderer draws the
  monochrome Yoshizawa-Randlett style throughout.

## Measured, and left for a decision

Making light the reference put its values under the same measurement the dark
ones already had. Four things came out of it that a value change alone does not
settle.

- **The light error colour is the old light mountain colour.** `#cf4327` holds
  4.44:1 on the light surface, just under the 4.5 a text colour needs, and sits
  at ΔE76 13.2 from `mountain`, so an error message beside a drawing reads as a
  fold direction (B1.6, B6.5). Darkening the dark-mode error to 4.5:1 gives
  `#b05641`, which holds 4.68 and ΔE76 36.6 from `mountain`.

- **The light accent and the first highlight colour are both teal.** ΔE76 11.0
  against `HIGHLIGHT_TEXT[0]`, where B1.7 asks for 25. Dark mode reaches 30.1
  because the accent is light and the highlight is dark; on a light ground both
  have to be dark for 4.5:1, so the separation has to come from hue, and the
  best teal that still holds contrast reaches 24.3. Either the first highlight
  leaves teal-green, which changes every figure and the PDF, or the accent
  leaves teal, which was decision 1.

- **`--bel-ui-border` carries two roles.** It draws the dividers between panes
  and the outlines of tabs, the theme toggle, the step buttons and the paper
  swatches. At 1.28:1 light and 1.31:1 dark that is fine for a divider and
  below the 3:1 B6.5 asks of a control outline. The fix is two roles.

- **`--bel-ui-text-faint` is declared and used nowhere.**

## Next

The landing, which carries decision 2 with it, and the token rename.
