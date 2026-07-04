# Spike: Calcium- / Primitive-Element-Backend gegen das Round-4-Ceiling

**Datum:** 2026-07-03
**Typ:** Spike (throwaway, benchmark-getrieben — kein Kernel-Rewrite)
**Branch:** `worktree-spike+calcium-pe-merge` (Base: `main`)

## Problem

Der Kernel *repräsentiert* origami-konstruierbare Zahlen beliebigen Grades
(2^a·3^b), aber gestapelte Axiom-7-Cubics wallen rechnerisch. Gemessen
(`notes/2026-07-03-33-verdict.md`, letzter Update-Block, FLINT-3.6-roots-first):

| Fall | Zeit |
|---|---|
| axiom 7, rationale Koords | 0.000s |
| axiom 7, p.x = (√2+√3)/8 (deg-4) | 0.113s |
| stacked cubic round 3 (3 Generatoren Grad 3) | 0.068s |
| stacked cubic round 4 (Generatoren Grad 9) | **>300s, killed** |

Der interaktive Ceiling ist **Runde 3**. Das #33-20-Step-Budget ist unerfüllt.

Der Bottleneck ist nicht die Arithmetik (qqbar ist sub-ms selbst bei Grad 27),
sondern `Num.real_roots` auf Axiom-7s F(t) (immer Grad 3 in t), sobald die
**Koeffizienten** über einem hochgradigen Feld leben. Zwei Pfade:
1. FLINT 3.6 `_qqbar_roots_poly_squarefree` über qqbar-Koeffizienten
   (`lib/num.ml:367`) — Limits 10000/100000; liefert `None` wenn überschritten.
2. Fallback: Mpoly-Generator-Elimination → ℚ-Superset R mit Grad 3·d³
   (81 @ round 3, **2187 @ round 4**). Round 4 hoffnungslos by construction.

## Erfolgsbalken

**#33-Budget knacken:** stacked-cubic Runde 4+ unter interaktiver Zeit (~1s).
Harter Pass/Fail-Gate am wallenden Benchmark aus den Notes.

## Kern-Hypothese (was der Spike beweisen muss)

Beide Ansätze reduzieren die *Ambient-Field-Komplexität*, aber F(t) braucht am
Ende **reelle Wurzeln eines Cubics mit algebraischen Koeffizienten**. Der Spike
muss zeigen, dass ein Backend-Wechsel die **Root-Finding-Kosten** senkt — nicht
nur die Arithmetik. Wenn nicht, gewinnt keiner.

### Entscheidende Diagnose zuerst

Warum wallt Runde 4? Zwei Hypothesen, von der Verdict-Note *nicht* isoliert:
- **H1 (Limit-Reject):** FLINT `real_roots_of_qqbar_poly` liefert `None`, weil
  die qqbar-Koeffizienten (Minpoly-Grad bis 729) die 10000/100000-Limits
  reißen → Fallback auf deg-2187 R → hoffnungslos.
  → Calcium/PE-merge kann gewinnen: kompaktere Feld-Darstellung (ein Generator
  statt Grad-729-qqbar) hält Root-Finding tragbar.
- **H2 (Intrinsisch schwer):** FLINT akzeptiert, rechnet aber intern zu lange —
  die qqbar eines Grad-729-Elements ist per se teuer.
  → Repräsentationswechsel hilft evtl. nicht.

Diese Diagnose (billig, ~30min) entscheidet, ob Calcium überhaupt gewinnen
*kann*. Sie ist Probe #1.

## Komponenten

Alles in `scratch/` (gitignored) — **kein Anfassen von `lib/num.ml`/`lib/geom.ml`**.

1. **Corpus** (`scratch/spike_stack.ml`) — gestapelte Axiom-7-Cubics Runden 1–5:
   jede Runde speist eine Crease-Koordinate der Vorrunde als Input-Koordinate
   der nächsten (Grad verdreifacht sich, 3^(k−2) @ Runde k). Reuse
   `Geom.beloch7_creases`, damit Zahlen mit #33-verdict vergleichbar sind.
   Plus (√2+√3)/8-Quartik als Cross-Check.

2. **Diagnose-Probe** (`scratch/spike_diag.ml`) — pro Runde:
   `Qqbar.real_roots_of_qqbar_poly` auf F(t)s Koeffizienten instrumentieren:
   `None` (Limit) vs `Some` vs Timeout, Wall-Zeit, Koeff-Minpoly-Grad +
   Bitgröße. Isoliert H1 vs H2.

3. **Calcium-Probe** (`scratch/ca_stubs.c` + `scratch/ca.ml`) — FFI zu
   `<flint/ca.h>` (libflint 3.6 schon gelinkt, kein neues Lib). Minimal-Ops:
   ca_t aus ℚ/qqbar, add/sub/mul/div, Equality/Sign, und der
   Axiom-7-Composite-Root-Pfad. F(t)-Koeffizienten als ca_t, Wurzeln, Timing
   Runden 1–5.

4. **PE-merge-Probe** (OCaml, nur falls Calcium das Budget *nicht* knackt) —
   γ=α+cβ, Minpoly via Resultant, Single-Generator statt Mpoly-Stack.

5. **Correctness-Gate** — Runden 1–3 (qqbar schafft die): neue Backends müssen
   *exakt* gleiche Wurzeln liefern (`Qqbar.equal` / `cmp_re = 0`).
   Falsch-aber-schnell = Fail.

## Deliverable

`notes/2026-07-03-calcium-pe-spike.md`: Timing-Tabelle Runden 1–5 × Backends,
H1/H2-Diagnose, Pass/Fail #33-Budget, Empfehlung. Gewinnt ein Backend → separater
echter Slice implementiert's im Kernel; dieser Spike wird nicht gemergt.

## Non-Goals

- Kein Kernel-Rewrite, keine ADR-Änderung, kein Merge nach main.
- Keine vollständige Backend-Implementierung — nur der Axiom-7-Root-Pfad, so
  viel wie zum Pass/Fail-Urteil nötig.
