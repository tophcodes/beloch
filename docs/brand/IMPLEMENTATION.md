# Design language: what is built, what is not

The draft that this implements is `design-language.md` (the conditions) plus
the Claude Design answers to it, which fixed twenty-two decisions across four
passes. This file says how far the code follows, so the next piece of work does
not have to re-derive it.

## Decided

| # | Decision | Where it lives |
|---|---|---|
| 1 | Interface accent is a teal outside the fold semantics | `--bel-ui-accent` in `tokens.css` |
| 2 | Reference mode is light | `light-dark()` in `tokens.css`, `index.astro` |
| 3 | Code surface stays dark in both modes | already true |
| 4 | Engine values win over web tokens | `render-svg/src/theme.ts` |
| 5 | Kraft and indigo get the monochrome style only | `colorOk` in `paper-schemes.ts` |
| 6 | Monospace shipped, prose on a system stack | `public/fonts/`, `--bel-font-*` |
| 7 | Wordmark stays monospace | unchanged, already true |
| 8 | A fold animates as a crossfade of two flat states | `lib/crossfade.ts` |
| 9 | Ten syntax roles | `--bel-syntax-*` in `tokens.css` |
| 10 | The token layer is a file of its own | `src/styles/tokens.css`, imported by `theme.css` |
| 11 | Starlight's custom properties are supplied from `--bel-*` | the bridge block in `theme.css` |
| 12 | Callouts and badges run on accent and error, never on a fold colour | the hue rows in the bridge |
| 13 | One line height for prose, 1.55 | `--bel-line-height` |
| 14 | The light caption of highlight 0 turns towards green | `HIGHLIGHT_TEXT[0]`, `.figure-hl-0`, `typst-compat.typ` |
| 15 | One header component draws every page | `SiteHeader.astro`, the `Header` override |
| 16 | The lockup is the mark beside the wordmark | `Wordmark.astro` |
| 17 | A control that is a mark alone is a circle, one that carries a word is a rectangle | `SiteHeader.astro`, `MenuButton.astro`, the bridge |
| 18 | On a narrow screen the drawer button sits in the bar below the header | `MenuButton.astro` |
| 19 | The table of contents is named by the section the reader is in | the bridge, `.display-current` |
| 20 | A figure's program is shown, highlighted, on the code surface | `remark-model-blocks.ts` |
| 21 | The seven statement kinds read as three groups | the bridge |
| 22 | There is a named type scale | `--bel-text-*` |

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
- **The fold crossfade.** One helper serves both surfaces that swap a drawing,
  the playground's stepper and the `<Beloch>` card. The state the reader left
  lies over the state they arrived at and fades off it, so no in-between
  geometry is drawn and no half-transparent paper appears. A step reached by
  clicking fades; a drawing that appears because a run finished does not, and a
  step clicked during a fade drops it. The transition is CSS, so the site's one
  `prefers-reduced-motion` rule turns it into a jump. A step that folds takes
  `--bel-duration-fold`, a step that only marks and a switch between two views
  of one state take `--bel-duration-view`.
- **An error colour that is not a crease colour.** The light error was the old
  light mountain colour, at 4.44:1 and ΔE76 13.2 from `mountain`, so an error
  message beside a drawing read as a fold direction. It is now `#b05641`, at
  4.68:1 and ΔE76 36.6, with 27.2 to the nearest other colour in the project.
  Accent and error also land on the always-dark code surface, where the light
  column reached 2.3:1 and 3.5:1, so that surface has its own pair alongside
  its text and gutter roles.
- **Light as the reference mode.** Every interface role is one `light-dark()`
  declaration with the light value first, and `color-scheme` decides which half
  is handed out: with no stored choice the visitor's system decides, on the
  landing as well as in the docs. The landing no longer pins dark before the
  first paint.
- **The token layer is one file.** `tokens.css` carries every `--bel-*`
  declaration and nothing else; `theme.css` imports it and holds the font
  faces, the rendering surface and the Starlight bridge. A reader asking what
  a value is opens one file, and `theme-tokens.test.ts` reads that file for
  the paper roles.
- **Three tinted grounds.** `--bel-ui-accent-low` and `--bel-ui-error-low`
  carry text on a field: the anchor a link jumped to, a callout, a badge.
  `--bel-ui-code-inline` carries inline code inside a paragraph, where the
  dark code surface would be a hole in the line. Body text holds 14.5:1 and
  above on all three, muted text 4.6:1 and above, and each sits 4.6 to 15.8
  ΔE76 off the page surface.
- **The Starlight bridge.** `--sl-*` is supplied from `--bel-*` in one block,
  so the docs take the landing's surface without a component being overridden
  for a colour. The bridge is one-way, which keeps one list of values. The
  header height and the side margin became `--bel-shell-nav-height` and
  `--bel-shell-pad-x` so the wordmark holds its place when a visitor crosses
  from the landing into the docs. `theme.css` no longer reads `--sl-color-*`
  in its own rules.
- **A callout row clear of the folds.** Starlight's five hue rows name four
  fold colours: blue is the valley, red the mountain, purple the construction
  line, orange the unassigned crease. They collapse onto accent for note, tip
  and a positive badge, and onto error for caution and danger. Two kinds of
  callout then read alike in colour and are told apart by their icon and their
  title word, which B1.2 asks for regardless.
- **Headings in the monospace.** `--sl-text-h1…h5` are a size scale and carry
  no typeface, so the choice is a rule on `.sl-markdown-content` and on the
  page title. This is the one place the integration goes past supplying a
  value.
- **One line height for prose.** Starlight sets 1.75 and the landing set 1.5.
  Palatino runs narrow, and `--bel-line-height` is 1.55 on both surfaces.
- **One elevation value.** The system separates with 1px lines. The case a
  line cannot carry is a panel lying over the text it covers, so
  `--bel-shadow-overlay` exists for the mobile menu, the mobile table of
  contents, the search dialog and the two overlays this site brings of its
  own. Starlight's `--sl-shadow-sm` goes to `none`.
- **Print is light.** A stored dark choice used to survive into the printer,
  because the bridge overrides the values Starlight forces for print. One
  `@media print` rule pins `color-scheme` instead, which is what `light-dark()`
  reads.
- **One header.** `SiteHeader.astro` draws the header for the landing, the
  playground and the docs; Starlight's own `Header` and `MobileMenuFooter` are
  overrides that hand it the search and the drawer links. The docs lose
  Starlight's site title and its select-shaped mode switch, and gain the
  wordmark, the navigation and the round toggle the landing has. GitHub is an
  icon, the two page links are words. Below 50rem the words step aside for the
  search and the drawer button and reappear inside the drawer; the icon and
  the toggle stay reachable without opening anything.
- **A figure's program is code.** It was plain text in a collapsed
  `<details>`, on the page ground, so the syntax roles a real program uses
  (points, axiom operators, sigils, numbers) appeared nowhere in the
  documents. It runs through the same highlighter as a fenced block now, lands
  on `--bel-ui-code-surface`, and the disclosure starts open. The model
  document keeps its programs hidden unless a block asks for them: there the
  mathematics leads and the program is an illustration.
- **Three groups of statement.** The markup separates seven kinds and the
  stylesheet drew them alike. B1.7 leaves no room for seven hues, so they fall
  into what a reader does with them: the kinds that assert keep the accent
  spine, `remark` and `example` step back onto a divider with a muted label,
  and `open` sits on `--bel-ui-accent-low` so an unsettled question is findable
  while scrolling. The label still names which of the seven it is.
- **A type scale.** `--bel-text-2xs` to `--bel-text-xl` are the sizes the
  surfaces already used, named, plus a heading ramp and the hero. The docs
  headings take that ramp rather than Starlight's: Starlight's is built for a
  sans, and these are set in the monospace, which runs wider at the same size.
- **One control language in the header.** The bar carried four: Starlight's
  frameless search button, a frameless icon link, a 30px circle with a 1px
  outline, and Starlight's filled drawer chip with a shadow. All four now take
  a transparent ground, a 1px `--bel-ui-control-border` and the accent on
  hover, and the shape follows what the control carries: a mark alone is a
  circle, a word is a rectangle.
- **The drawer button leaves the top bar.** On a narrow screen it is fixed into
  the left end of the bar Starlight already draws under the header for the
  table of contents, as a labelled `Menu` button in the control language. The
  top bar is then the landing's bar, and no row is added: the disclosure beside
  it keeps `--bel-menu-button-width` clear. The search stays in the top bar:
  Starlight renders one search per page with fixed ids, and the desktop header
  is where that one belongs.
- **The bar below the header names the section.** Starlight's disclosure read
  "On this page" beside the heading the reader is in, which spends the width of
  a control on a label nobody needs twice. The heading is the control now, with
  a caret behind it; the label stays for a screen reader, where it also names
  the navigation landmark. The caret is drawn from borders rather than set as a
  character, so no font decides its shape. Before the first heading is
  observed the control falls back to the label.
- **The drawer opens below that bar.** Its button is fixed into the bar, so a
  drawer starting under the header would scroll its own list beneath the
  button. The drawer now starts below the bar instead. The disclosure steps out
  while the drawer is open: it sits inside `.main-frame`, which the drawer
  marks `inert`, so leaving it on screen would show a control that cannot be
  used.
- **Two components that flip themselves.** Starlight writes its base values
  dark first and flips them on `:root[data-theme='light']`. `MobileMenuToggle`
  and `Badge` do that flip in their own rules rather than through the
  variables, and `light-dark()` has already chosen the column by then, so both
  came out inverted when a visitor pinned the light mode and correct when the
  mode came from the system. The drawer button is replaced outright; the badge
  names both its ground and its text in the bridge.
- **The mode toggle is drawn, not typed.** Its moon and sun were the `☽` and
  `☀` characters set through CSS `content`, so their shape came from whichever
  installed font the page's fallback chain reached first. The landing and the
  docs bring different chains, which put two different moons on one site. Both
  icons are now SVG from Starlight's set, drawn in `currentColor`, and only
  one is shown.
- **The lockup.** `Wordmark.astro` sets the mark beside the wordmark at
  `--bel-space-2`, both inline so the mark draws in `currentColor` and follows
  the mode. The mark is a crease pattern, and the three stroke styles that say
  which line is which stop reading at header size: the scored lines dash at
  4.5/3 in a 64 unit grid, under 1.6px once the drawing is 22px wide. Below
  50rem the header therefore takes `mark-small` at 22px, where every line is
  4px, and above it `mark` at 28px.
- **The light caption of highlight 0.** `HIGHLIGHT_TEXT[0]` moves from
  `#07715a` to `#1C6B33`: ΔE76 27.5 to the light accent where it was 11.0, and
  6.22:1 on the surface where it was 5.65:1. The stroke in `HIGHLIGHT_PALETTE`
  does not move, so no drawing and no PDF changes. The price is that the
  caption of the first highlight stands in a green whose stroke is teal-green,
  which weakens the tie between the word and the drawn thing for that one
  colour.

## The viewer pass

`viewer-brief.md` put seven decisions to the design. The answer came back as
two versions of one surface, differing in how the crease pattern and the folded
state stand next to each other, where the inspector goes and how the columns
split. Both are built, on the surface each suits: the playground takes the tab
pair, because an editor needs the width and a reader has to be able to hit a
crease in the folded state; the docs card takes the pair side by side, because
it has no editor and checking flat-foldability is a comparison.

| # | Question | Answer |
|---|---|---|
| 1 | Crease pattern and folded state | Tab pair in the playground, side by side in the docs card |
| 2 | A line-style switch | Yes, beside the paper choice; a paper that cannot hold the coloured style switches that button off and says why in its title |
| 3 | Export and sharing | The drawing as SVG to a file or the clipboard, and a link carrying the program and the step |
| 4 | The inspector | A rail under the drawing, holding its place across a step change |
| 5 | The landing hero | Its own job: a program and its drawing, and nothing to operate; the playground moved back to `/playground/` |
| 6 | `--bel-ui-border` as two roles | `--bel-ui-divider` and `--bel-ui-control-border` |
| 7 | Whether `--bel-ui-text-faint` stays | It stays, as the text of a switched-off control |

Also built with it, from the findings in section 5 of the brief: a diagnostic
stands beside the drawing instead of replacing it and marks the line the
evaluator named, the drawing takes focus and answers the arrow keys, page
scrolling over the drawing stays the page's, the runtime transfer reports how
far it has got, and the control transitions take the duration tokens.

## Not built, and why

- **A view of the crease pattern in the docs card independent of its folded
  twin.** The card's stepper moves both drawings together, because they are two
  drawings of one state.
- **One code surface in the docs.** A ```` ```beloch ```` fence is `.bel-block`
  from `theme.css`, on `--bel-ui-code-surface` with a 12px radius. Every other
  fence runs through Starlight's code rendering with its own frame and its own
  theme, so two kinds of code block can stand under each other. That is a
  Shiki configuration question, and the bridge does not reach it.
- **A flat pagination link.** Starlight's pagination takes `--sl-shadow-md`,
  which the bridge points at the overlay shadow for the panels that need it.
  The link keeps a shadow it does not need until it gets a rule of its own.

## What the system does not name yet

The gaps the design system records. The list is the brief, and nothing on it
is filled.

- **No z-index scale.** The export panel sits at 5, controls at 2, tooltips at
  50, each set where it is used.
- **The focus ring is a pattern.** 2px accent at offset 2px stands at every
  control separately. There is no `--bel-focus-*`.
- **Breakpoints are unnamed.** 720px splits the card and the playground, 50rem
  and 72rem the docs sidebar.
- **Opacity literals are unnamed.** The editor gutter takes
  `rgba(255,255,255,.08)`, the active line `.04`, occluded segments `0.55`,
  the reset button `0.45`.
- **No form vocabulary.** The site knows buttons, tabs, swatches and an editor.
  Input fields, selects, switches and tables have no pattern yet.

## Next

The bridge changes every docs page at once, so the first thing it needs is a
reading pass over `/model/`, `/kernel/`, `/language/` and `/output/` in both
modes: the headings at their new typeface, the code blocks against each other,
the sidebar and the search dialog on the one page ground.
