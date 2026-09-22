// Canonical paper color catalog + apply logic. Single source of truth for the
// scheme colors (the inline <head> sync script in astro.config.mjs serializes
// SCHEMES; it does NOT duplicate the table by hand).
//
// The effect is site-wide: the CSS variables set here live on documentElement
// and are read by every inline SVG (SSR + live) via fill="var(--bel-paper-*)"
// (see WEB_THEME in @beloch/render-svg).
export interface PaperScheme {
  id: string;
  label: string;
  fill: string;   // --bel-paper-fill (face fill of the flat sheet in the crease pattern)
  front: string;  // --bel-paper-front (folded: front side)
  back: string;   // --bel-paper-back (folded: back side)
  ink?: string;   // --bel-paper-ink + --bel-paper-boundary; only dark papers set it
  swatch: string; // display color of the toolbar swatch
  // Whether the coloured line style may be offered on this paper. On kraft and
  // indigo every crease colour falls below 2:1 against the sheet (max 1.86), so
  // those papers get the monochrome Yoshizawa-Randlett style only, where the
  // dash pattern carries mountain against valley. The renderer draws monochrome
  // throughout today; this flag is what a style switch has to honour.
  colorOk: boolean;
}

export const STORAGE_KEY = "beloch-paper";
export const DEFAULT_ID = "white";

export const SCHEMES: PaperScheme[] = [
  { id: "white",  label: "White",  fill: "#f8fafc", front: "#fafaf7", back: "#dbe4ee", swatch: "#fafaf7", colorOk: true },
  { id: "kraft",  label: "Kraft",  fill: "#c9a87d", front: "#b8926a", back: "#8f6f4e", swatch: "#b8926a", colorOk: false },
  { id: "washi",  label: "Washi",  fill: "#f2ead6", front: "#f2ead6", back: "#d8cbaa", swatch: "#f2ead6", colorOk: true },
  // Ink and boundary together at 8.05 against the sheet.
  { id: "indigo", label: "Indigo", fill: "#3b4a6b", front: "#3b4a6b", back: "#26314a", ink: "#f2f5f9", swatch: "#3b4a6b", colorOk: false },
];

export function resolveScheme(id: string | null | undefined): PaperScheme {
  return SCHEMES.find((s) => s.id === id) ?? SCHEMES.find((s) => s.id === DEFAULT_ID)!;
}

// Variable map: paper vars are always set; ink vars = ink or null
// (null => remove the variable, so the WEB_THEME fallback takes over).
export function schemeVars(s: PaperScheme): Record<string, string | null> {
  return {
    "--bel-paper-fill": s.fill,
    "--bel-paper-front": s.front,
    "--bel-paper-back": s.back,
    "--bel-paper-ink": s.ink ?? null,
    "--bel-paper-boundary": s.ink ?? null,
  };
}

export function applyScheme(id: string): void {
  const s = resolveScheme(id);
  const root = document.documentElement.style;
  for (const [k, v] of Object.entries(schemeVars(s))) {
    if (v === null) root.removeProperty(k);
    else root.setProperty(k, v);
  }
  try {
    localStorage.setItem(STORAGE_KEY, s.id);
  } catch {
    /* private mode etc. — the choice only applies to this session */
  }
}

// Inline IIFE for the <head>: runs synchronously before first paint (no flash),
// setting the variables from localStorage. The table is serialized from SCHEMES;
// the ~6 lines of resolve/set logic are intentionally inlined here because the
// script cannot import a module.
export function headSyncScript(): string {
  const table: Record<string, Record<string, string | null>> = {};
  for (const s of SCHEMES) table[s.id] = schemeVars(s);
  return (
    "(function(){try{" +
    "var T=" + JSON.stringify(table) + ";" +
    "var id=localStorage.getItem(" + JSON.stringify(STORAGE_KEY) + ")||" + JSON.stringify(DEFAULT_ID) + ";" +
    "var v=T[id]||T[" + JSON.stringify(DEFAULT_ID) + "];" +
    "var r=document.documentElement.style;" +
    "for(var k in v){if(v[k]===null)r.removeProperty(k);else r.setProperty(k,v[k]);}" +
    "}catch(e){}})();"
  );
}
