# Design language: what is built, what is not

The draft that this implements is `design-language.md` (the conditions) plus
the Claude Design answer to it, which fixed nine decisions. This file says how
far the code follows, so the next piece of work does not have to re-derive it.

## Decided

| # | Decision | Where it lives |
|---|---|---|
| 1 | Interface accent is a teal outside the fold semantics | `--beloch-accent` in `theme.css` |
| 2 | Reference mode is light | **not implemented**, see below |
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
- **Interface state** has its own roles, `--beloch-accent`, `--beloch-accent-ink`
  and `--beloch-error`. Fourteen places in the playground used the valley colour
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
  `HIGHLIGHT_TEXT` carries darkened variants for caption text at 4.5:1.
- **Scale and duration tokens**, and a `prefers-reduced-motion` rule, which the
  site did not have anywhere.

## Not built, and why

- **Light as the reference mode.** The landing is still hard-defaulted to dark
  and the token blocks are still written dark-first, with light as the override.
  Turning that around touches every surface at once, so it belongs with the
  landing pass rather than ahead of it.
- **The fold crossfade.** There is no motion on the drawing at all today, so
  this is new behaviour rather than a change to existing behaviour.
- **The `--bel-ui-*` / `--bel-paper-*` naming.** The draft renames every token
  into two namespaces. The values are correct; the names are still `--beloch-*`
  for the interface and `--bel-*` for the drawing. This is a mechanical rename
  across four files and reads better done in one go than spread across commits.
- **A colour/monochrome style switch.** `colorOk` says which papers may offer
  the coloured style, but nothing offers it yet: the renderer draws the
  monochrome Yoshizawa-Randlett style throughout.

## Next

The landing, which carries decision 2 with it, and the token rename.
