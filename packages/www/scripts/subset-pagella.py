"""Builds public/fonts/pagella-*.woff2 from the TeX Gyre Pagella OTFs.

Usage: python3 subset-pagella.py <directory holding texgyrepagella-*.otf> <output directory>

Each cut is reduced to the character set below and to the layout features the
site's prose uses, then renamed "Beloch Pagella". The GUST Font License asks
that a derived font carry a new name (see GUST-FONT-LICENSE.txt), and LPPL
clause 6 asks that it say what was changed and where the original is: the
description name record (ID 10) says both.
"""

import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

FAMILY = "Beloch Pagella"
ORIGINAL = "https://www.gust.org.pl/projects/e-foundry/tex-gyre/pagella"

# Latin-1 covers English, German and Italian names (B4.12). The rest is the
# punctuation, arrows and symbols that appear in rendered prose (↑ and ↩ are
# the footnote and back-reference links), plus the dashes and quotes a
# paragraph can carry. Formulas are KaTeX's and code is JetBrains Mono, so
# neither adds to this list.
UNICODES = (
    "U+0020-007E,U+00A0-00FF,U+0131,U+0152-0153,U+2013-2014,U+2018-201E,"
    "U+2020-2022,U+2026,U+2030,U+2032-2033,U+2039-203A,U+2044,U+2122,"
    "U+2190-2193,U+21A9,U+2212,U+221E,U+2248,U+2260,U+2264-2265"
)

# kern and liga are on by default in a browser; smcp and c2sc carry
# `font-variant-caps: small-caps`; lnum, onum, pnum and tnum carry
# `font-variant-numeric`. dlig is left out: it holds the TeX ligature that
# turns `--` into an en dash, and a crease name must keep both hyphens (B4.6).
FEATURES = "kern,liga,ccmp,locl,mark,mkmk,smcp,c2sc,lnum,onum,pnum,tnum"

CUTS = {"regular": ("400", "Regular"), "italic": ("400-italic", "Italic"), "bold": ("700", "Bold")}


def rename(font: TTFont, style: str) -> None:
    name = font["name"]
    ps = f"{FAMILY.replace(' ', '')}-{style}"
    for name_id in (1, 3, 4, 6, 16, 17):
        name.removeNames(nameID=name_id)
    name.setName(FAMILY, 1, 3, 1, 0x409)
    name.setName(style, 2, 3, 1, 0x409)
    name.setName(f"{ps};subset", 3, 3, 1, 0x409)
    name.setName(f"{FAMILY} {style}", 4, 3, 1, 0x409)
    name.setName(ps, 6, 3, 1, 0x409)
    name.setName(
        f"Modified from TeX Gyre Pagella 2.501: glyphs reduced to {UNICODES}, "
        f"layout features reduced to {FEATURES}, renamed {FAMILY}. "
        f"Unmodified original: {ORIGINAL}",
        10, 3, 1, 0x409,
    )
    if "CFF " in font:
        cff = font["CFF "].cff
        cff.fontNames = [ps]
        top = cff.topDictIndex[0]
        top.FullName = f"{FAMILY} {style}"
        top.FamilyName = FAMILY


def main(src: Path, out: Path) -> None:
    options = subset.Options()
    options.layout_features = FEATURES.split(",")
    options.flavor = "woff2"
    options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 10]
    for cut, (suffix, style) in CUTS.items():
        font = TTFont(src / f"texgyrepagella-{cut}.otf")
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=subset.parse_unicodes(UNICODES))
        subsetter.subset(font)
        rename(font, style)
        target = out / f"pagella-{suffix}.woff2"
        subset.save_font(font, str(target), options)
        print(f"{target} {target.stat().st_size} bytes")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
