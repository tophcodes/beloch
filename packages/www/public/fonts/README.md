# Fonts

## JetBrains Mono NL

`jetbrains-mono-400.woff2` and `jetbrains-mono-600.woff2` are the Regular and
SemiBold weights of **JetBrains Mono NL** 2.304, subset to Latin-1 plus the
punctuation, arrows and mathematical symbols the site and the specification
use. `NL` is the no-ligatures cut: `!=`, `->` and `--` stay as separate glyphs,
which matters because `--` opens a crease name in Beloch.

Licensed under the SIL Open Font License 1.1, see `OFL.txt`.

Regenerate from nixpkgs:

    P=$(nix build nixpkgs#jetbrains-mono --no-link --print-out-paths)/share/fonts/truetype
    nix shell --impure --expr 'with import <nixpkgs> {}; python3.withPackages (ps: [ ps.fonttools ps.brotli ])' \
      --command pyftsubset "$P/JetBrainsMonoNL-Regular.ttf" \
      --unicodes='U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+2018-201E,U+2020-2022,U+2026,U+2030,U+2032-2033,U+2039-203A,U+2044,U+2070,U+2074-2079,U+2080-2089,U+2122,U+2190-2193,U+2212,U+00D7,U+00F7,U+221A,U+221E,U+2248,U+2260,U+2264-2265' \
      --layout-features='' --flavor=woff2 \
      --output-file=packages/www/public/fonts/jetbrains-mono-400.woff2

## TeX Gyre Pagella

`pagella-400.woff2`, `pagella-400-italic.woff2` and `pagella-700.woff2` are the
Regular, Italic and Bold cuts of **TeX Gyre Pagella** 2.501, the prose face.
They are subset to Latin-1 plus the dashes, quotes, arrows and symbols that
rendered prose carries, and keep the layout features the site uses: `kern`,
`liga`, the small caps `smcp` and `c2sc`, and the figure styles `lnum`, `onum`,
`pnum` and `tnum`. `dlig` is dropped because it turns `--` into an en dash.

Pagella is copyright 2007-2018 B. Jackowski, J. M. Nowacki et al., on behalf
of the TeX Users Groups, and licensed under the GUST Font License, see
`GUST-FONT-LICENSE.txt`, which is an instance of the LaTeX Project Public
License 1.3c, see `lppl.txt`. A subset is a derived work under that licence, so
the files carry the family name **Beloch Pagella**, as the GUST Font License
asks, and each says in its description name record what was changed and where
the unmodified fonts are:
<https://www.gust.org.pl/projects/e-foundry/tex-gyre/pagella>. The PDF sets
its own type and does not use these files.

Regenerate from nixpkgs:

    P=$(nix build nixpkgs#gyre-fonts --no-link --print-out-paths)/share/fonts/opentype
    nix shell --impure --expr 'with import <nixpkgs> {}; python3.withPackages (ps: [ ps.fonttools ps.brotli ])' \
      --command python3 packages/www/scripts/subset-pagella.py "$P" packages/www/public/fonts

`subset-pagella.py` holds the character set and the feature list.
