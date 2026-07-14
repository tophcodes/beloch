# Beloch card — filename-as-comment + optional line numbers

**Date:** 2026-07-14
**Scope:** `site/src/components/Beloch.astro` only. No change to the render
pipeline (`@beloch/render-svg`), the eval path (`eval-bel.ts`), or the
hydration island (`beloch-figure.ts`).

## Motivation

The card wears fake macOS window chrome (three traffic-light dots + a filename
pill). It reads as decoration, not documentation. Drop the chrome. Show the
filename the way beloch itself would: as a leading `;` comment on line 1 of the
source.

## Changes

### 1. Props

- Rename `title?: string` → `filename?: string`. Semantics change from
  "label pill text" to "file name shown as a leading comment".
- Add `lineNumbers?: boolean` (default `false`). Author-set at call site,
  **not** a user-facing runtime toggle.

### 2. Filename as first-line comment

- `displaySource = filename ? "; " + filename + "\n" + trimmed : trimmed`
- Highlight `displaySource` (so the injected line is highlighted as a `.bel`
  comment).
- **Eval is unchanged:** `evalBelToFold(trimmed)` still runs on the original
  source. The injected `; …` line is cosmetic; it never reaches the evaluator,
  so the build-eval / drift-guard contract is untouched.
- No `filename` → nothing injected; code starts at the real first statement.

### 3. Remove macOS chrome

- Delete the `.beloch-mac-bar` markup (three `.mac-dot` spans + filename span).
- Delete the `.beloch-mac-bar`, `.mac-dot`, `.beloch-filename` styles.
- The code panel renders `<pre>` directly.

### 4. Optional line numbers

- When `lineNumbers`, render a build-time gutter: a right-aligned, muted
  column of `1..N` where `N = displaySource` line count.
- Layout: the code panel becomes a two-column grid `[gutter][code]` sharing the
  same `line-height`; `white-space: pre` on both so rows align.
- The injected `; filename` comment counts as line 1.
- **Why build-time gutter, not CSS counters or HTML line-splitting:** splitting
  the highlighted HTML on `\n` risks cutting a highlight span across a line
  boundary; a separately-rendered numeric column sidesteps that entirely and we
  already know the line count at build.

## Non-goals

- No runtime line-number toggle.
- No change to `<beloch-figure>` (its `Faltbild`/`Gefaltet` controls bar still
  prepends to `.beloch-card`; it never referenced the mac bar).
- No change to the diagram panel or the render pipeline.

## Call-site migration

Existing usages pass `title="…"`. Rename those to `filename="…"`. Grep
`src/content` for `<Beloch` and update. Behavior shifts from a pill to a
leading comment — intended.
