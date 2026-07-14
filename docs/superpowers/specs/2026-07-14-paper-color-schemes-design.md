# Papier-Farbschemata — site-weit über localStorage

**Datum:** 2026-07-14
**Status:** Design freigegeben, bereit für Implementierungsplan
**Scope:** v1 = reine Farbschemata (keine Raster-/Muster-Texturen — bewusst später)

## Problem

Die Docs-Seite soll im Playground erlauben, den Papier-Look der Origami-Diagramme
zu wählen. Der Clou: die Wahl gilt **site-weit** und persistent — sie färbt nicht
nur das Playground-Ergebnis, sondern *alle* Diagramme aller Tutorials um, auch die
schon zur Build-Zeit gerenderten SSR-SVGs — ohne Rebuild.

## Warum CSS-Variablen der einzige Mechanismus sind

Diagramme entstehen auf zwei Pfaden, beide erzeugen `<polygon data-kind="face">`:

1. **Build-time SSR** — `<Beloch>`-Cards in Tutorials, per nativem `beloch` +
   `@beloch/render-svg` gerendert und fest ins HTML gebacken.
2. **Live client** — Playground-Worker, gleiche Render-Pipeline im Browser.

Die Papierfüllung ist heute **hart codiert** (`theme.paperFill` für CP,
`theme.front`/`theme.back` für gefaltet). Um schon-gebackene SSR-SVGs *ohne
Rebuild* umzufärben, gibt es genau ein Mittel: die Füllung muss eine
**CSS-Variable** sein, die ein Client-Skript auf `:root` setzt. Dann repainten
alle SVGs — SSR wie live — sobald die Variable sich ändert.

## Architektur

Drei Einheiten, entkoppelt:

### 1. Render-Ebene (`@beloch/render-svg`)

Hart codierte Farben → CSS-Variablen **mit Hex-Fallback**. Der Fallback ist exakt
der heutige Wert; damit bleiben headless SVG→PNG-Export und alte Bundles
unverändert (dort löst keine `:root`-Variable auf → Fallback greift).

| Datei / Zeile | vorher | nachher |
|---|---|---|
| `render-cp.ts:53` Fläche (CP) | `fill: theme.paperFill` | `fill: "var(--bel-paper-cp, #f8fafc)"` |
| `render-folded.ts:79` Fläche | `theme.front` / `theme.back` | `"var(--bel-paper-front, #fafaf7)"` / `"var(--bel-paper-back, #dbe4ee)"` |
| `render-cp.ts:126,135` Punkt+Label | `fill: theme.ink` | `fill: "var(--bel-ink, #0f172a)"` |
| `render-folded.ts:226,234` Punkt+Label | `fill: theme.ink` | `fill: "var(--bel-ink, #0f172a)"` |
| `constructions.ts:115,118,133` Punkt/Label/Titel | `fill: theme.ink` | `fill: "var(--bel-ink, #0f172a)"` |
| `theme.ts` yrLineStyle `M/V/F` stroke | `theme.ink` | `"var(--bel-ink, #0f172a)"` |
| `theme.ts` yrLineStyle `B` stroke | `theme.boundary` | `"var(--bel-boundary, #1f2937)"` |

Der Canvas-`<rect fill="white">` (Diagramm-Hintergrund, **nicht** Papier) bleibt.
Crease-Farben M/V (rot/blau) bleiben semantisch fix — sie sind auf jedem Papier
lesbar und tragen Bedeutung.

**Ink pro Schema:** dunkle Papiere (Indigo) machen dunkle Ink/Boundary unlesbar.
Deshalb führen Schemata ein optionales `ink`-Feld; nur dunkle Papiere überschreiben
`--bel-ink`/`--bel-boundary` mit einem hellen Wert. Helle Papiere lassen den
Fallback (dunkel) stehen.

### 2. Site-weite Anwendung (`site/src/lib/paper-schemes.ts`)

Ein kleines TS-Modul, die **einzige Quelle der Wahrheit**:

```ts
export interface PaperScheme {
  id: string;      // localStorage-Wert
  label: string;   // Swatch-title
  cp: string;      // --bel-paper-cp
  front: string;   // --bel-paper-front
  back: string;    // --bel-paper-back
  ink?: string;    // --bel-ink + --bel-boundary (nur dunkle Papiere)
  swatch: string;  // Swatch-Anzeigefarbe (i.d.R. = front)
}

export const SCHEMES: PaperScheme[];       // weiß, kraft, washi, indigo
export const DEFAULT_ID = "weiss";
export function applyScheme(id: string): void;  // setzt CSS-Vars auf documentElement + persistiert
```

`applyScheme` setzt immer `--bel-paper-*`; setzt `--bel-ink`/`--bel-boundary` nur
wenn `scheme.ink` vorhanden (sonst räumt es sie ab → Fallback greift), und schreibt
`localStorage['beloch-paper']`.

**Katalog v1** (`front` / `back` / `ink`):

| id | label | cp | front | back | ink |
|---|---|---|---|---|---|
| `weiss` | Weiß | `#f8fafc` | `#fafaf7` | `#dbe4ee` | — (Default dunkel) |
| `kraft` | Kraft | `#c9a87d` | `#b8926a` | `#8f6f4e` | — |
| `washi` | Washi | `#f2ead6` | `#f2ead6` | `#d8cbaa` | — |
| `indigo` | Indigo | `#3b4a6b` | `#3b4a6b` | `#26314a` | `#e7eaf2` |

(`weiss` reproduziert exakt das heutige Aussehen — leerer localStorage = kein
Override = Fallback-Hex.)

### 3. Site-weiter Sync (Starlight `head`-Config)

Ein inline-`<script>` in der Starlight-`head`-Konfiguration läuft auf **jeder**
Doc-Seite **vor dem ersten Paint** (no-flash-Pattern, wie ein Theme-Toggler):

```js
// liest localStorage['beloch-paper'], schlägt Schema nach, setzt die CSS-Vars
// auf documentElement.style — bevor irgendein SVG gemalt wird.
```

Es teilt die Zuordnungslogik mit `applyScheme` (kein Duplikat der Farbtabelle).
Da das Skript inline im `<head>` ist und `paper-schemes.ts` ein ES-Modul, wird die
Tabelle entweder klein genug inline-serialisiert oder das Skript importiert das
Modul — Detailentscheidung für den Plan (no-flash hat Vorrang → notfalls minimaler
inline-Snapshot der id→vars-Tabelle).

### 4. Picker (Playground-Toolbar)

- 4 Swatches in der `pg-output`-Toolbar (`ergebnis`-Leiste), je Farbtupfer + `title`.
- Klick → `applyScheme(id)`, aktiver Swatch markiert, Wahl sofort site-weit sichtbar.
- Beim Laden: aktiven Swatch aus `localStorage` markieren.
- Entkoppelt über `paper-schemes.ts` → ein späterer globaler Header-Toggle ruft
  nur dasselbe `applyScheme` (v1 out of scope, aber die API ist ortsunabhängig).

## Datenfluss

```
localStorage['beloch-paper']
      │
      ├─ head-Script (jede Seite, vor Paint) ──┐
      │                                        ├─→ documentElement.style
      └─ applyScheme() (Playground-Klick) ─────┘        --bel-paper-cp/front/back
                                                        --bel-ink/--bel-boundary
                                                              │
                        alle inline-SVGs (SSR + live) ───────┘
                        <polygon fill="var(--bel-paper-*)">  → repaint
```

## Fehlerfälle

- **Unbekannte/veraltete id** in localStorage → `applyScheme` fällt auf
  `DEFAULT_ID` zurück (Schema entfernt, alter Wert im Storage).
- **localStorage nicht verfügbar** (Privatmodus/SSR) → try/catch, Default-Look,
  kein Bruch.
- **Headless SVG→PNG / alte Bundles** → keine `:root`-Vars → Hex-Fallback =
  heutiges Aussehen. Kein Regressionsrisiko im nativen Renderpfad.

## Tests

- **Unit** (`paper-schemes.test.ts`): `applyScheme` setzt die erwarteten
  CSS-Vars; unbekannte id → Default; `ink`-loses Schema räumt `--bel-ink` ab.
- **Render-Regression**: bestehende render-svg-Snapshots müssen mit
  `var(...,<hex>)` statt nacktem Hex weiter grün sein (Fallback = alter Wert →
  Snapshot-Diff nur im `fill`-Attribut-String; Goldens einmalig neu erzeugen).
- **Manuell/E2E**: Schema im Playground wählen → Tutorial-Seite öffnen → Diagramme
  tragen das Schema; Reload → Wahl bleibt.

## Bewusst außerhalb v1 (YAGNI)

- Raster-/Muster-Texturen (Washi-Faser, Kraft-Grain, Foil als `<pattern>`/`<image>`).
  Die Variable-Mechanik lässt die Tür offen: `--bel-paper-front` kann später
  `url(#pattern)` tragen, sobald ein Client-Skript die `<defs>` in jedes SVG
  injiziert. Kein Umbau nötig, nur additiv.
- Globaler Header-Toggle (v1 nur Playground-Picker; `applyScheme` ist schon
  ortsunabhängig).
- Per-Doc-Theme-abhängige Papierfarben (Schema ist theme-unabhängig: Papier ist
  Papier, egal ob die Seite hell/dunkel läuft).
