// Kanonischer Papier-Farbkatalog + Anwendungslogik. Einzige Wahrheitsquelle
// für die Schema-Farben (das inline-<head>-Sync-Script in astro.config.mjs
// serialisiert SCHEMES, dupliziert die Tabelle NICHT von Hand).
//
// Wirkung ist site-weit: die gesetzten CSS-Variablen leben auf
// documentElement und werden von jedem inline-SVG (SSR + live) über
// fill="var(--bel-paper-*)" (siehe WEB_THEME in @beloch/render-svg) gelesen.
export interface PaperScheme {
  id: string;
  label: string;
  cp: string;     // --bel-paper-cp (CP-Flächenfüllung)
  front: string;  // --bel-paper-front (gefaltet: Vorderseite)
  back: string;   // --bel-paper-back (gefaltet: Rückseite)
  ink?: string;   // --bel-ink + --bel-boundary; nur dunkle Papiere setzen es
  swatch: string; // Anzeigefarbe des Toolbar-Swatch
}

export const STORAGE_KEY = "beloch-paper";
export const DEFAULT_ID = "weiss";

export const SCHEMES: PaperScheme[] = [
  { id: "weiss",  label: "Weiß",   cp: "#f8fafc", front: "#fafaf7", back: "#dbe4ee", swatch: "#fafaf7" },
  { id: "kraft",  label: "Kraft",  cp: "#c9a87d", front: "#b8926a", back: "#8f6f4e", swatch: "#b8926a" },
  { id: "washi",  label: "Washi",  cp: "#f2ead6", front: "#f2ead6", back: "#d8cbaa", swatch: "#f2ead6" },
  { id: "indigo", label: "Indigo", cp: "#3b4a6b", front: "#3b4a6b", back: "#26314a", ink: "#e7eaf2", swatch: "#3b4a6b" },
];

export function resolveScheme(id: string | null | undefined): PaperScheme {
  return SCHEMES.find((s) => s.id === id) ?? SCHEMES.find((s) => s.id === DEFAULT_ID)!;
}

// Variablen-Map: Papier-Vars immer gesetzt; Ink-Vars = ink oder null
// (null ⇒ Variable entfernen → Fallback aus WEB_THEME greift).
export function schemeVars(s: PaperScheme): Record<string, string | null> {
  return {
    "--bel-paper-cp": s.cp,
    "--bel-paper-front": s.front,
    "--bel-paper-back": s.back,
    "--bel-ink": s.ink ?? null,
    "--bel-boundary": s.ink ?? null,
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
    /* Privatmodus etc. — Wahl gilt nur für diese Session */
  }
}

// Inline-IIFE fürs <head>: läuft synchron vor dem ersten Paint (no-flash),
// setzt die Variablen aus localStorage. Die Tabelle wird aus SCHEMES
// serialisiert; die ~6 Zeilen Auflöse-/Setz-Logik sind bewusst hier inline
// dupliziert, weil das Script kein Modul importieren kann.
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
