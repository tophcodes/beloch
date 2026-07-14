# Papier-Farbschemata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Im Playground wählbare Papier-Farbschemata, die site-weit und persistent (localStorage) alle Origami-Diagramme umfärben — auch die build-time-gerenderten SSR-SVGs, ohne Rebuild.

**Architecture:** Die Render-Pipeline bekommt ein `WEB_THEME`, dessen Papier-/Ink-/Boundary-Farben CSS-Variablen mit Hex-Fallback sind. Alle Web-Renderpfade (SSR-Cards + Live-Playground) rendern mit `WEB_THEME`; der headless PNG-Pfad (resvg) behält `DEFAULT_THEME` (hart-hex, resvg löst `var()` nicht auf). Ein Katalog-Modul + ein inline-`<head>`-Script setzen die Variablen auf `documentElement` aus localStorage — vor dem ersten Paint, no-flash.

**Tech Stack:** TypeScript, bun (`bun test`, `bun:test`), Astro + Starlight, `@beloch/render-svg` (pure-TS SVG), `@beloch/scene`.

## Global Constraints

- **Test runner:** `bun test` (bun:test API: `import { test, expect } from "bun:test"`). Kein vitest.
- **Fallback-Disziplin:** jede CSS-Variable trägt exakt den heutigen Hex als Fallback: `--bel-paper-cp #f8fafc`, `--bel-paper-front #fafaf7`, `--bel-paper-back #dbe4ee`, `--bel-ink #0f172a`, `--bel-boundary #1f2937`. `DEFAULT_THEME` bleibt unverändert.
- **Einzige Wahrheitsquelle** für den Farbkatalog: `site/src/lib/paper-schemes.ts`. Keine Farbtabelle woanders duplizieren (das inline-`<head>`-Script serialisiert `SCHEMES` per JSON).
- **localStorage-Key:** `beloch-paper`. **Default-id:** `weiss` (leerer Storage = heutiges Aussehen).
- **Katalog v1** (id | label | cp | front | back | ink):
  - `weiss` | Weiß | `#f8fafc` | `#fafaf7` | `#dbe4ee` | — (kein ink)
  - `kraft` | Kraft | `#c9a87d` | `#b8926a` | `#8f6f4e` | — (kein ink)
  - `washi` | Washi | `#f2ead6` | `#f2ead6` | `#d8cbaa` | — (kein ink)
  - `indigo` | Indigo | `#3b4a6b` | `#3b4a6b` | `#26314a` | `#e7eaf2`
- **Schemata sind theme-unabhängig** (Papier = Papier, unabhängig von Seiten-Hell/Dunkel). Keine Light/Dark-Verdopplung.
- **Muster/Raster explizit außerhalb v1.**

---

### Task 1: `WEB_THEME` in render-svg

CSS-Variablen-Theme für den Web-Renderpfad. `DEFAULT_THEME` bleibt hart-hex (headless/resvg + bestehende Snapshots unberührt → kein Snapshot-Update nötig).

**Files:**
- Modify: `render/render-svg/src/theme.ts` (nach `DEFAULT_THEME`, ~Zeile 69)
- Test: `render/render-svg/test/web-theme.test.ts` (neu)

**Interfaces:**
- Consumes: `Theme` interface, `DEFAULT_THEME`, `renderCP`, `renderFolded` (bestehend).
- Produces: `export const WEB_THEME: Partial<Theme>` — die 5 var-Overrides. Wird via `index.ts` (`export * from "./theme"`) re-exportiert; Task 3 & 5 importieren es aus `@beloch/render-svg`.

- [ ] **Step 1: Failing-Test schreiben**

`render/render-svg/test/web-theme.test.ts`:

```ts
import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { renderCP, renderFolded, WEB_THEME } from "../src/index";
import bisect from "./fixtures/bisect-a.fold.json";

test("renderCP with WEB_THEME emits CSS-var paper + ink fills", () => {
  const svg = renderCP(parseFold(bisect as object), { theme: WEB_THEME }).toString();
  expect(svg).toContain('fill="var(--bel-paper-cp, #f8fafc)"');
  expect(svg).toContain('fill="var(--bel-ink, #0f172a)"');
  expect(svg).toContain('stroke="var(--bel-boundary, #1f2937)"');
});

test("renderCP without a theme keeps the concrete hex (headless-safe)", () => {
  const svg = renderCP(parseFold(bisect as object)).toString();
  expect(svg).toContain('fill="#f8fafc"');
  expect(svg).not.toContain("var(--bel-");
});
```

> **Fixture-Check vor dem Schreiben:** `ls render/render-svg/test/fixtures/` und den vorhandenen CP-Fixture-Namen aus `render-cp.test.ts` (dessen `import`-Zeile) übernehmen, falls `bisect-a.fold.json` nicht existiert. Der Test braucht nur *irgendeine* gültige FOLD-Fixture, die `render-cp.test.ts` bereits lädt.

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `cd render/render-svg && bun test test/web-theme.test.ts`
Expected: FAIL — `WEB_THEME` ist nicht exportiert (`SyntaxError`/`undefined`).

- [ ] **Step 3: `WEB_THEME` implementieren**

In `render/render-svg/src/theme.ts`, direkt nach dem `DEFAULT_THEME`-Block anhängen:

```ts
// Web-Renderpfad (SSR-Cards + Live-Playground): Papier-, Ink- und Boundary-
// Farben als CSS-Variablen mit Hex-Fallback. Ein Client-Script setzt die
// Variablen auf :root aus localStorage → alle inline-SVGs (auch schon
// gebackene SSR) repainten ohne Rebuild. Fallback = DEFAULT_THEME-Wert, damit
// der headless resvg-Pfad (der var() NICHT auflöst) unverändert bleibt; dort
// wird weiter DEFAULT_THEME benutzt.
export const WEB_THEME: Partial<Theme> = {
  paperFill: "var(--bel-paper-cp, #f8fafc)",
  front:     "var(--bel-paper-front, #fafaf7)",
  back:      "var(--bel-paper-back, #dbe4ee)",
  ink:       "var(--bel-ink, #0f172a)",
  boundary:  "var(--bel-boundary, #1f2937)",
};
```

- [ ] **Step 4: Test laufen lassen, grün prüfen**

Run: `cd render/render-svg && bun test test/web-theme.test.ts`
Expected: PASS (beide Tests).

- [ ] **Step 5: Bestehende Snapshots weiter grün prüfen (kein Churn)**

Run: `cd render/render-svg && bun test`
Expected: PASS, **keine** aktualisierten Snapshots (DEFAULT_THEME unberührt). Falls ein Snapshot rot ist → Fehler; NICHT mit `--update-snapshots` übertünchen, Ursache prüfen.

- [ ] **Step 6: Commit**

```bash
git add render/render-svg/src/theme.ts render/render-svg/test/web-theme.test.ts
git commit -m "feat(render-svg): WEB_THEME with CSS-var paper/ink fills"
```

---

### Task 2: Katalog-Modul `paper-schemes.ts`

Reine, testbare Logik (Katalog + Auflösung + Variablen-Map). Kein `document`-Zugriff im Modul-Top-Level, damit `astro.config.mjs` es zur Build-Zeit in Node importieren kann.

**Files:**
- Create: `site/src/lib/paper-schemes.ts`
- Test: `site/src/lib/paper-schemes.test.ts`

**Interfaces:**
- Consumes: nichts (Blattmodul).
- Produces:
  - `interface PaperScheme { id: string; label: string; cp: string; front: string; back: string; ink?: string; swatch: string }`
  - `const SCHEMES: PaperScheme[]`
  - `const DEFAULT_ID = "weiss"`
  - `const STORAGE_KEY = "beloch-paper"`
  - `function resolveScheme(id: string | null | undefined): PaperScheme` — unbekannt/null → Default.
  - `function schemeVars(s: PaperScheme): Record<string, string | null>` — Keys `--bel-paper-cp/front/back` immer string; `--bel-ink`/`--bel-boundary` = `s.ink` oder `null` (null ⇒ Variable entfernen).
  - `function applyScheme(id: string): void` — setzt/entfernt Variablen auf `document.documentElement.style`, persistiert nach `localStorage[STORAGE_KEY]`. (Browser-only; nicht unit-getestet.)
  - `function headSyncScript(): string` — self-contained IIFE-Quelltext fürs `<head>` (Task 4); serialisiert `SCHEMES` als Tabelle.

- [ ] **Step 1: Failing-Test schreiben**

`site/src/lib/paper-schemes.test.ts`:

```ts
import { test, expect } from "bun:test";
import { SCHEMES, DEFAULT_ID, resolveScheme, schemeVars, headSyncScript } from "./paper-schemes";

test("catalog has the four v1 schemes with the default first", () => {
  expect(SCHEMES.map((s) => s.id)).toEqual(["weiss", "kraft", "washi", "indigo"]);
  expect(SCHEMES[0].id).toBe(DEFAULT_ID);
});

test("resolveScheme falls back to default for unknown/empty id", () => {
  expect(resolveScheme("nope").id).toBe(DEFAULT_ID);
  expect(resolveScheme(null).id).toBe(DEFAULT_ID);
});

test("schemeVars sets ink vars for dark paper, clears them for light", () => {
  const indigo = schemeVars(resolveScheme("indigo"));
  expect(indigo["--bel-paper-front"]).toBe("#3b4a6b");
  expect(indigo["--bel-ink"]).toBe("#e7eaf2");
  expect(indigo["--bel-boundary"]).toBe("#e7eaf2");

  const white = schemeVars(resolveScheme("weiss"));
  expect(white["--bel-paper-front"]).toBe("#fafaf7");
  expect(white["--bel-ink"]).toBeNull();
  expect(white["--bel-boundary"]).toBeNull();
});

test("headSyncScript embeds the catalog and reads the storage key", () => {
  const src = headSyncScript();
  expect(src).toContain("beloch-paper");
  expect(src).toContain("--bel-paper-front");
  expect(src).toContain("#3b4a6b"); // indigo baked in
});
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `cd site && bun test src/lib/paper-schemes.test.ts`
Expected: FAIL — Modul existiert nicht.

- [ ] **Step 3: Modul implementieren**

`site/src/lib/paper-schemes.ts`:

```ts
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
```

- [ ] **Step 4: Test laufen lassen, grün prüfen**

Run: `cd site && bun test src/lib/paper-schemes.test.ts`
Expected: PASS (4 Tests).

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/paper-schemes.ts site/src/lib/paper-schemes.test.ts
git commit -m "feat(site): paper-schemes catalog + apply/sync logic"
```

---

### Task 3: SSR-Cards mit `WEB_THEME` rendern

`<Beloch>`-Cards (build-time SSR) sollen var()-Füllungen ins HTML backen, damit sie site-weit umfärbbar werden.

**Files:**
- Modify: `site/src/components/Beloch.astro` (Import ~Zeile 14, `renderCP`-Aufruf Zeile 54)

**Interfaces:**
- Consumes: `WEB_THEME` aus `@beloch/render-svg` (Task 1).

- [ ] **Step 1: Import ergänzen**

In `site/src/components/Beloch.astro`, Zeile 14 ändern von:

```ts
import { renderCP } from "@beloch/render-svg";
```
zu:
```ts
import { renderCP, WEB_THEME } from "@beloch/render-svg";
```

- [ ] **Step 2: `WEB_THEME` an den Render-Aufruf durchreichen**

Zeile 54 ändern von:

```ts
const svg = renderCP(parseFold(fold as object)).toString();
```
zu:
```ts
const svg = renderCP(parseFold(fold as object), { theme: WEB_THEME }).toString();
```

- [ ] **Step 3: Build laufen lassen und var()-Einbettung verifizieren**

Run: `cd site && bun run build`
Expected: Build grün (Drift-Guard evaluiert alle `<Beloch>`-Quellen).

Dann im gebauten HTML prüfen, dass eine Tutorial-Seite die Variable trägt:

Run: `rg -l 'fill="var\(--bel-paper-cp' site/dist | head`
Expected: mindestens eine `.html` (z.B. eine Tutorial-Seite mit `<Beloch>`-Card).

- [ ] **Step 4: Commit**

```bash
git add site/src/components/Beloch.astro
git commit -m "feat(site): render <Beloch> SSR cards with WEB_THEME"
```

---

### Task 4: Site-weites `<head>`-Sync-Script

Jede Doc-Seite setzt die CSS-Variablen vor dem ersten Paint aus localStorage.

**Files:**
- Modify: `site/astro.config.mjs` (Starlight-Options: `head`-Array ergänzen; `customCss` bleibt)

**Interfaces:**
- Consumes: `headSyncScript()` aus `./src/lib/paper-schemes.ts` (Task 2). Astro lädt die Config über Vite/esbuild, TS-Import funktioniert.

- [ ] **Step 1: `headSyncScript` importieren**

Oben in `site/astro.config.mjs` (bei den übrigen Imports) ergänzen:

```js
import { headSyncScript } from "./src/lib/paper-schemes.ts";
```

- [ ] **Step 2: `head`-Eintrag in die Starlight-Config**

Im `starlight({ ... })`-Options-Objekt (dort wo `customCss: ['./src/styles/theme.css']` steht) das `head`-Feld ergänzen:

```js
head: [
  {
    tag: "script",
    content: headSyncScript(),
  },
],
```

- [ ] **Step 3: Build + Einbettung verifizieren**

Run: `cd site && bun run build`
Expected: Build grün.

Run: `rg -l "beloch-paper" site/dist | head`
Expected: HTML-Seiten enthalten das inline-Script (Storage-Key-String).

- [ ] **Step 4: No-flash-/Wirkungs-Check (manuell)**

Run: `cd site && bun run preview`
Dann im Browser DevTools-Konsole auf einer Tutorial-Seite:

```js
localStorage.setItem("beloch-paper", "indigo"); location.reload();
```
Expected: Diagramme sofort indigo (kein weißer Flash beim Laden); Ink hell/lesbar.
Danach zurücksetzen: `localStorage.removeItem("beloch-paper"); location.reload();` → wieder weiß.

- [ ] **Step 5: Commit**

```bash
git add site/astro.config.mjs
git commit -m "feat(site): site-wide paper-scheme head sync (no-flash)"
```

---

### Task 5: Playground-Swatch-Picker

Live-Playground rendert mit `WEB_THEME` und bekommt eine Swatch-Leiste, die `applyScheme` aufruft (Wirkung sofort site-weit + persistent).

**Files:**
- Modify: `site/src/components/Playground.astro`
  - Render-Imports/-Aufrufe (`renderCP`, `renderFolded` → `WEB_THEME`) im `<script>`-Block (Zeilen ~153, 201–202)
  - Swatch-Markup in die `pg-output`-Toolbar (Zeile ~31)
  - Swatch-Styles im `<style>`-Block
  - Verdrahtung im `setup()`-Script

**Interfaces:**
- Consumes: `WEB_THEME` aus `@beloch/render-svg` (Task 1); `SCHEMES`, `STORAGE_KEY`, `DEFAULT_ID`, `applyScheme` aus `../lib/paper-schemes` (Task 2).

- [ ] **Step 1: Live-Renders auf `WEB_THEME` umstellen**

Im `<script type="module">`-Block von `Playground.astro`:

Import (Zeile ~153) von:
```ts
import { renderCP, renderFolded } from "@beloch/render-svg";
```
zu:
```ts
import { renderCP, renderFolded, WEB_THEME } from "@beloch/render-svg";
```

Render-Aufrufe (Zeile ~201–202) von:
```ts
const doc = scene.steps.length > 0 ? renderFolded(scene) : renderCP(scene);
```
zu:
```ts
const doc = scene.steps.length > 0
  ? renderFolded(scene, { theme: WEB_THEME })
  : renderCP(scene, { theme: WEB_THEME });
```

- [ ] **Step 2: Swatch-Markup in die Ergebnis-Toolbar**

In `Playground.astro`, die `pg-output`-Toolbar (Zeile ~31) von:

```astro
    <div class="pg-toolbar">
      <span class="pg-label">ergebnis</span>
    </div>
```
zu:
```astro
    <div class="pg-toolbar">
      <span class="pg-label">ergebnis</span>
      <div class="pg-swatches" role="group" aria-label="Papier"></div>
    </div>
```

(Die Swatch-Buttons werden im Script aus `SCHEMES` erzeugt — kein hartcodiertes Markup, damit der Katalog die einzige Wahrheitsquelle bleibt.)

- [ ] **Step 3: Swatch-Styles ergänzen**

Im `<style>`-Block von `Playground.astro` anhängen:

```css
  .pg-swatches { display: inline-flex; gap: 6px; }
  .pg-swatch {
    width: 16px; height: 16px; padding: 0;
    border-radius: 50%;
    border: 1px solid var(--beloch-border);
    cursor: pointer;
    box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.08);
  }
  .pg-swatch.is-active {
    outline: 2px solid var(--beloch-valley);
    outline-offset: 1px;
  }
```

- [ ] **Step 4: Picker im `setup()`-Script verdrahten**

Im `<script>`-Block die Katalog-Imports oben ergänzen (neben dem render-svg-Import):

```ts
import { SCHEMES, STORAGE_KEY, DEFAULT_ID, applyScheme } from "../lib/paper-schemes";
```

In `setup(root)`, nach den bestehenden `querySelector`-Zeilen, folgende Verdrahtung einfügen (vor `runBtn.addEventListener`):

```ts
    const swatchBar = root.querySelector<HTMLDivElement>(".pg-swatches");
    if (swatchBar) {
      let activeId: string;
      try {
        activeId = localStorage.getItem(STORAGE_KEY) ?? DEFAULT_ID;
      } catch {
        activeId = DEFAULT_ID;
      }
      const buttons = SCHEMES.map((s) => {
        const b = document.createElement("button");
        b.type = "button";
        b.className = "pg-swatch";
        b.style.background = s.swatch;
        b.title = s.label;
        b.setAttribute("aria-label", s.label);
        b.dataset.schemeId = s.id;
        if (s.id === activeId) b.classList.add("is-active");
        b.addEventListener("click", () => {
          applyScheme(s.id);
          swatchBar.querySelectorAll(".pg-swatch").forEach((el) =>
            el.classList.toggle("is-active", el === b),
          );
        });
        return b;
      });
      swatchBar.append(...buttons);
    }
```

> Hinweis: Astro hoistet den `<script>`-Block einmalig; `setup()` läuft pro `.beloch-playground`-Instanz (`querySelectorAll(...).forEach(setup)` am Dateiende) — die Swatch-Verdrahtung ist damit instanz-lokal, konsistent mit dem bestehenden Muster.

- [ ] **Step 5: Build laufen lassen**

Run: `cd site && bun run build`
Expected: Build grün (TypeScript im Astro-Script kompiliert; Imports auflösbar).

- [ ] **Step 6: End-to-end verifizieren (manuell)**

Run: `cd site && bun run preview`
Im Browser auf der Playground-Seite:
1. „Run" drücken → Diagramm erscheint.
2. Kraft-Swatch klicken → Playground-Diagramm wird kraftbraun, Swatch aktiv markiert.
3. Zu einer Tutorial-Seite navigieren → deren `<Beloch>`-Diagramme sind ebenfalls kraftbraun.
4. Seite neu laden → Wahl bleibt (localStorage).
5. Indigo klicken → Ink/Punkte hell und lesbar.

Expected: alle 5 Punkte erfüllt.

- [ ] **Step 7: Commit**

```bash
git add site/src/components/Playground.astro
git commit -m "feat(site): playground paper-scheme swatch picker"
```

---

## Self-Review

**Spec coverage:**
- Render-Ebene CSS-Vars + Fallback → Task 1 (`WEB_THEME`; als Refinement gegenüber der Spec-Tabelle: ein `WEB_THEME`-Konstante statt 7 Call-Site-Edits, `DEFAULT_THEME` bleibt hart-hex → headless resvg + bestehende Snapshots geschützt; gleiche Wirkung).
- Ink-pro-Schema (dunkles Indigo lesbar) → `ink`-Feld + `--bel-ink`/`--bel-boundary` in Task 2, konsumiert via `WEB_THEME` in Task 1.
- Katalog `paper-schemes.ts` (4 Schemata, `applyScheme`) → Task 2.
- Site-weiter `<head>`-Sync, no-flash → Task 4.
- Playground-Picker, entkoppelt → Task 5.
- Fehlerfälle (unbekannte id → Default; localStorage-try/catch; headless-Fallback) → Task 2 (resolveScheme/applyScheme) + Task 1 (headless-safe Test).
- Tests (unit paper-schemes; render-Regression grün; manuell E2E) → Task 2 Step 4, Task 1 Step 5, Task 4/5 manuelle Steps.

**Placeholder scan:** keine TODO/TBD; alle Code-Steps zeigen vollständigen Code; Verify-Kommandos mit erwarteter Ausgabe.

**Type consistency:** `PaperScheme`-Felder (`id/label/cp/front/back/ink?/swatch`) konsistent über Task 2/5; `WEB_THEME: Partial<Theme>` konsistent Task 1/3/5; Var-Namen (`--bel-paper-cp/front/back`, `--bel-ink`, `--bel-boundary`) identisch in Task 1 (Fallbacks), Task 2 (`schemeVars`) und Task 2 (`headSyncScript`). Storage-Key `beloch-paper` / `STORAGE_KEY` konsistent.
