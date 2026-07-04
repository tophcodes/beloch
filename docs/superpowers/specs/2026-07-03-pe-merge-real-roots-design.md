# Slice: primitive-element merge path in `Num.real_roots`

**Datum:** 2026-07-03
**Base:** `main` (kernel lives here)
**Vorarbeit:** Spike `notes/2026-07-03-calcium-pe-spike.md` (Calcium verworfen,
PE-merge belegt: 43× @ coeff-deg 8, knackt #33-Round-4; Resultant billig,
`qqbar_express_in_field` als nativer γ-Recovery-Baustein gefunden).

## Ziel

`Num.real_roots` löst axiom-6/7-Polynome mit algebraischen Koeffizienten über
einem **hochgradigen Feld** heute entweder gar nicht (FLINT-`qqbar`-roots-first
liefert `None` am Bit/Grad-Limit → Fallback auf hoffnungsloses deg-`3·d³`-`R`)
oder langsam (`qqbar`-native root-finding, 9s @ coeff-deg 8). Dieser Slice fügt
einen **primitive-element-Pfad** ein: alle algebraischen Koeffizienten über
**einen** Generator γ des von ihnen erzeugten Feldes ausdrücken und mit **einem**
Resultant `R = Res_x(μ_γ, F̃)` (Grad `3·[ℚ(γ):ℚ]`, minimal) eliminieren.

**Generalisiert über #33 hinaus:** nicht nur die single-chain stacked cubic
(alle Koeffizienten in ℚ(px) einer *einzelnen* Vorgänger-Koordinate), sondern
**independent folds** — Koeffizienten, die ein *Compositum* mehrerer unabhängiger
vorheriger Extensions aufspannen.

## Erfolgskriterien

- #33-Round-4-Fall (Koeffizienten über Grad-9-Feld), heute `>300s killed`, in
  **~1s**. Interaktiver stacked-cubic-Ceiling Round 3 → ~5.
- **Independent-folds-Fall**: ein axiom-7-Cubic, dessen Koeffizienten mehrere
  unabhängige vorherige algebraische Folds kombinieren (z.B. √2 aus Fold A, ∛2
  aus Fold B), wird korrekt und schneller als der aktuelle Multi-Generator-Pfad
  gelöst.
- Volle Testsuite grün; keine Korrektheitsregression an bestehenden Fällen
  (`cube-root.bel` golden, axiom-7, real-roots, field).

## Architektur & Datenfluss

Neuer algebraischer Tier in `Num.real_roots` (`lib/num.ml:299`), eingefügt
zwischen dem bestehenden `flint_first` (Tier 2) und dem bestehenden
Mpoly-Multi-Generator-Fallback (Tier 4, **bleibt** als Safety-Net):

```
real_roots(coeffs):
  1. rational fast path                        (existing, unchanged)
  2. flint_first (deg ≤3 direkt über qqbar)    (existing)
  3. NEU: primitive-element path               ← dieser Slice
  4. Mpoly multi-generator elimination         (existing) — Fallback
```

Tier 4 bleibt erhalten, damit Fälle, die Tier 3 nicht bewältigt (v.a.
`express_in_field`-Bit-Limit-Fehlschläge), nie in Korrektheit regredieren — nur
in Geschwindigkeit auf den Status quo zurückfallen.

## Komponenten

### C1 — FFI-Baustein: `express_over` (der einzige neue FFI)

FLINT bietet `qqbar_express_in_field(fmpq_poly_t res, const qqbar_t alpha,
const qqbar_t x, slong max_bits, int flags, slong prec)`: drückt die
algebraische Zahl `x` als ℚ-Polynom in `alpha` aus, exakt (interne LLL +
Zertifizierung), Rückgabe `0` bei Fehlschlag (`x ∉ ℚ(alpha)` oder
Bits/Prec-Limit).

- Neuer C-Stub in `lib/qqbar_stubs.c`: `ml_qqbar_express_in_field`, gibt die
  fmpq_poly-Koeffizienten als String-Array (low-first "num/den") zurück, oder
  `None`.
- OCaml in `lib/qqbar.ml`:
  ```ocaml
  val express_over : gen:t -> t -> Poly.t option
  ```
  ℚ-Polynom `c` mit `x = c(gen)`, oder `None`. Membership-Test **und**
  Koordinaten-Extraktion in einem. `max_bits`/`prec`: Startwerte
  (z.B. 4096 bits / prec 256), bei `None`-durch-Limit **eine** Retry-Stufe
  mit erhöhten Werten, dann endgültig `None` (→ Tier-4-Fallback).

### C2 — Compositum-Primitivelement (reines OCaml, nutzt C1)

In `lib/num.ml` (oder neues `lib/field_merge.ml`, falls `num.ml` zu groß wird —
Entscheidung beim Implementieren, `num.ml` ist bereits 525 Zeilen):

```
algebraische coeffs → dedup via Qqbar.equal → β₁..βₘ
γ := β₁
für jedes βⱼ (j ≥ 2):
  match express_over ~gen:γ βⱼ with
  | Some _ -> ()                       (* βⱼ ∈ ℚ(γ) schon *)
  | None ->
      finde kleinstes k ∈ {1,2,3,…} mit
        express_over ~gen:(γ + k·βⱼ) γ  = Some _  ∧
        express_over ~gen:(γ + k·βⱼ) βⱼ = Some _
      γ := γ + k·βⱼ
```

Terminiert per Primitivelement-Satz (nur endlich viele k versagen). γ-Arithmetik
ist qqbar (sub-ms selbst bei hohem Grad). Obergrenze für k-Suche (z.B. 64) →
bei Überschreitung Tier-4-Fallback (defensiv; sollte nie greifen).

### C3 — Resultant + Filter (reuse bestehender Code)

Jeden Koeffizienten `cᵢ` via `express_over ~gen:γ` zu `cᵢ(x) ∈ ℚ[x]` machen
(ein Fehlschlag → Tier-4-Fallback). μ_γ = `Qqbar.minpoly γ`.

```
F̃(t,x) = Σᵢ cᵢ(x)·tⁱ            als Mpoly (var0=t, var1=x)
R(t)    = Mpoly.resultant F̃ (μ_γ in x) 1    → Poly.t in t, Grad 3·[ℚ(γ):ℚ]
roots   = Qqbar.real_roots_of_poly R
          |> filter (eval_p z = 0 exakt in qqbar)   (* R ist Superset *)
          |> map (field_upgrade ∘ of_qq)
```

`eval_p` und `field_upgrade` existieren bereits (`lib/num.ml`). Kein neuer
Resultant-Code (Spike: `Mpoly.resultant` billig, 0.058s @ R deg 48; der Filter
dominiert bei hohem Grad und ist derselbe wie im Status quo).

## Gate (Tier-3-Auslösung)

Tier 3 feuert wenn:
- der maximale qqbar-Grad der Koeffizienten ≥ **T** (Default 5) ist, **oder**
- `flint_first` `None` zurückgibt.

Darunter (coeff-deg ≤ 4) bleibt `flint_first` (geringerer Overhead: 0.045s @
deg 4 vs PE-Setup-Kosten). Spike-belegt: bei deg 8 flint_first 9.2s vs PE 0.2s,
also T=5 kappt den teuren flint_first-Bereich ab. T ist eine Konstante, empirisch
justierbar.

## Fehlerbehandlung / Fallback

Jeder der folgenden Fälle → sauberes Durchfallen auf Tier 4 (bestehender
Mpoly-Multi-Generator-Pfad), nie ein falsches Ergebnis:
- `express_over` schlägt für γ-Konstruktion oder einen Koeffizienten fehl
  (Bit-Limit nach Retry).
- k-Suche überschreitet Obergrenze.
- `R` degeneriert (Grad < 1).

## Testing

- **Regression (single-chain):** Spike-Runden 3–6 als deterministische Tests
  (die stacked-cubic-Konstruktion aus `scratch/spike_pe.ml`), Erwartung: gleiche
  Wurzeln wie qqbar wo qqbar liefert, Zeit < Budget.
- **Independent folds (neu):** ein axiom-7-Cubic, dessen Koeffizienten √2 (Fold
  A) und ∛2 (Fold B) *unabhängig* kombinieren → γ = Primitivelement von
  ℚ(√2, ∛2) (Grad 6), R Grad 18; Wurzeln exakt gegen eine unabhängige
  Referenz (qqbar direkt, falls es den deg-6-Fall noch schafft) verifiziert.
- **Fallback:** ein konstruierter Fall, der express_over ans Bit-Limit treibt →
  Tier 4 greift, Ergebnis korrekt.
- **Bestehende Suite grün:** `cube-root.bel` golden (repräsentation über
  field_upgrade unverändert), axiom-6/7, real-roots, field, e2e.
- Micro: `express_over` Unit-Tests (β∈ℚ(γ) → Some c mit c(γ)=β exakt; β∉ℚ(γ) →
  None).

## Non-Goals

- Keine Änderung an Tier 1/2/4-Logik außer dem Gate-Vorschalten von Tier 3.
- Kein Ersetzen des Mpoly-Fallbacks (bleibt Safety-Net).
- Keine Provenance-/Field-Threading-Umbauten an `Num` (value-based recovery
  gewählt).
- Keine ADR in diesem Slice, außer die Backend-ADR 0013 verweist bereits auf
  "primitive-element merging" als Follow-up — ggf. eine kurze ADR-Ergänzung
  beim Merge, nicht Teil der Kern-Impl.

## Offene Tuning-Punkte (im Plan zu klären, nicht blockierend)

- Startwerte `max_bits`/`prec` für `express_in_field` und die Retry-Stufe.
- Schwelle T (Default 5).
- k-Suchobergrenze.
- `num.ml` vs neues `field_merge.ml` (Größenentscheidung beim Implementieren).
