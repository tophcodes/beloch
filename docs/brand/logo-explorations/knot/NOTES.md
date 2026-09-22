# Knoten: fünf Entwürfe

Exploration zu Richtung B des Logo-Briefs (`docs/brand/logo-brief.md`, §7 B).
Ein einzelner flachfaltbarer Knoten, gezeichnet in der Strichsprache des
Renderers. Diese Notiz enthält für jeden Entwurf die Winkel, die
Berg-Tal-Zuweisung, die Maekawa- und Kawasaki-Rechnung und die Stelle, an der
er bricht.

## Was hier liegt

| Datei | Knoten | Herkunft der Geometrie |
| --- | --- | --- |
| `knot-01-emergent.svg` | $(1/3,\ 2/3)$ | vom Evaluator gerechnet, `logo.bel` |
| `knot-02-fan.svg` | $(0{,}36,\ 0{,}60)$ | von Hand konstruiert |
| `knot-03-fish.svg` | $(1-\tfrac{\sqrt2}{2},\ 1-\tfrac{\sqrt2}{2})$ | vom Evaluator gerechnet, `logo-fish.bel` |
| `knot-04-bare.svg` | wie 03, ohne Blattrand | von Hand konstruiert |
| `knot-05-pane.svg` | $(0{,}44,\ 0{,}40)$ | von Hand konstruiert, Bruchpunkt-Beleg |

Zu jedem Entwurf liegt eine `-16`-Fassung bei (siehe "Die 16-Pixel-Fassungen").
Alle Dateien: `viewBox="0 0 64 64"`, `stroke="currentColor"`, ein `rect`, zwei
`path`, ein `circle`, unter 600 Byte.

## Die Prüfung, die für alle gilt

Ein einzelner innerer Knoten mit Sektorwinkeln $\alpha_0 \dots \alpha_{2n-1}$
ist genau dann flachfaltbar, wenn die alternierende Winkelsumme null ist
(Kawasaki, [hull2020, §5.3]). Die Zahl der Bergfalten minus der Zahl der
Talfalten ist an einem flachen Knoten $\pm 2$ (Maekawa, [hull2020, §5.2]).
Dazu kommt das Big-Little-Big-Lemma ([hull2020, Lemma 5.25]): grenzt ein
strikt kleinster Sektor an zwei größere, müssen seine beiden Faltlinien
verschiedene Zuweisungen tragen.

Für einen Knoten vom Grad 4 mit eindeutig kleinstem Sektor sind diese drei
Bedingungen zusammen hinreichend. Kawasaki erzwingt $\alpha_1 + \alpha_3 =
\alpha_2 + \alpha_4 = 180°$; von den acht Zuweisungen, die Maekawa erfüllen,
überleben die vier, die das Lemma zulässt ([hull2020, Satz 5.26] und die
Diskussion davor). Jeder Entwurf hier hat vier paarweise verschiedene
Sektoren, also einen eindeutig kleinsten.

Die Winkel stehen unten in Grad, gemessen als Richtung vom Knoten aus, gegen
den Uhrzeigersinn, $0°$ nach rechts. Die Blattkoordinaten sind das
Einheitsquadrat mit $y$ nach oben; im SVG sitzt das Blatt bei Rand 6 auf
Seitenlänge 52.

## `knot-01-emergent`

Knoten $O = (1/3,\ 2/3)$.

| Strahl | Richtung | Endpunkt | Zuweisung |
| --- | --- | --- | --- |
| 1 | $180° - \arctan 4 = 104{,}0362°$ | $(1/4,\ 1)$ | Tal |
| 2 | $180° + \arctan 2 = 243{,}4349°$ | $(0,\ 0)$ | Tal |
| 3 | $315°$ | $(1,\ 0)$ | Tal |
| 4 | $360° - \arctan \tfrac{1}{13} = 355{,}6013°$ | $(1,\ 8/13)$ | **Berg** |

Sektoren, in dieser Reihenfolge:

$$\alpha_1 = 139{,}3987 \quad \alpha_2 = 71{,}5651 \quad \alpha_3 = 40{,}6013 \quad \alpha_4 = 108{,}4349$$

**Kawasaki.** $139{,}3987 - 71{,}5651 + 40{,}6013 - 108{,}4349 = 0$.
Gleichwertig: $\alpha_1 + \alpha_3 = 180{,}0000$ und $\alpha_2 + \alpha_4 =
180{,}0000$. Summe aller vier: $360{,}0000$.

**Maekawa.** $M - V = 1 - 3 = -2$.

**Big-Little-Big.** Kleinster Sektor $\alpha_3 = 40{,}6013$, eingeschlossen von
Strahl 3 (Tal) und Strahl 4 (Berg). Die beiden unterscheiden sich.

Strahl 4 ist die Falte, die `flatten` selbst löst. Aus den benannten Punkten
konstruiert sie kein Huzita-Axiom; sie existiert, weil der Knoten flach
schließen muss, und der Evaluator weist ihr den einzigen Berg zu. Das ist die
Zeile, die kein anderes Werkzeug im Feld so schreibt.

**Wo er bricht.** Der 40,6°-Sektor ist der engste im ganzen Satz. Unter 24
Pixeln laufen Strahl 3 und Strahl 4 zu einem Keil zusammen, und der Knoten
liest sich als Dreieck mit angehängter Linie statt als vier Falten. Bei 16
Pixeln trägt nur noch die Gesamtfigur.

## `knot-02-fan`

Knoten $O = (0{,}36,\ 0{,}60)$.

| Strahl | Richtung | Endpunkt | Zuweisung |
| --- | --- | --- | --- |
| 1 | $100°$ | $(0{,}2895,\ 1)$ | Tal |
| 2 | $175°$ | $(0,\ 0{,}6315)$ | **Berg** |
| 3 | $225°$ | $(0,\ 0{,}2400)$ | Tal |
| 4 | $330°$ | $(1,\ 0{,}2305)$ | Tal |

Sektoren: $75 \quad 50 \quad 105 \quad 130$.

**Kawasaki.** $75 - 50 + 105 - 130 = 0$, also $75 + 105 = 180$ und
$50 + 130 = 180$. Summe $360$.

**Maekawa.** $M - V = 1 - 3 = -2$.

**Big-Little-Big.** Kleinster Sektor $50$, zwischen Strahl 2 (Berg) und
Strahl 3 (Tal).

**Wo er bricht.** Die Winkel sind gewählt, nicht hergeleitet. Beloch
konstruiert $100°$ und $175°$ aus den Ecken eines Quadrats nicht, also fällt
für diesen Entwurf der Beleg weg, den Richtung B eigentlich mitbringt. Er ist
das beste Bild im Satz und die schwächste Behauptung.

## `knot-03-fish`

Knoten $O = (1 - \tfrac{\sqrt2}{2},\ 1 - \tfrac{\sqrt2}{2}) \approx
(0{,}292893,\ 0{,}292893)$. Es ist der erste innere Knoten der Fischbasis,
allein gestellt.

| Strahl | Richtung | Endpunkt | Zuweisung |
| --- | --- | --- | --- |
| 1 | $112{,}5°$ | $(0,\ 1)$, Ecke `.d` | Tal |
| 2 | $180°$ | $(0,\ 1-\tfrac{\sqrt2}{2})$ | **Berg** |
| 3 | $225°$ | $(0,\ 0)$, Ecke `.a` | Tal |
| 4 | $337{,}5°$ | $(1,\ 0)$, Ecke `.b` | Tal |

Sektoren: $67{,}5 \quad 45 \quad 112{,}5 \quad 135$.

**Kawasaki.** $67{,}5 - 45 + 112{,}5 - 135 = 0$, also $67{,}5 + 112{,}5 = 180$
und $45 + 135 = 180$. Summe $360$.

**Maekawa.** $M - V = 1 - 3 = -2$.

**Big-Little-Big.** Kleinster Sektor $45$, zwischen Strahl 2 (Berg) und
Strahl 3 (Tal).

**Wo er bricht.** Drei der vier Strahlen zeigen nach links unten, zwei davon
sind kurz. Der Knoten sitzt dadurch in einer Ecke des Blattes und die rechte
Blatthälfte bleibt leer, was bei 16 Pixeln als Quadrat mit einer Diagonale
liest. Die Strahlen 3 und 4 enden exakt in den Ecken `.a` und `.b`, wo sie
optisch in den Rand laufen.

## `knot-04-bare`

Dieselbe Geometrie wie `knot-03-fish`, ohne gezeichneten Blattrand. Die
Strahlen enden dort, wo das Blatt wäre, also trägt die Silhouette das Quadrat
weiter, ohne es zu zeigen. Rechnung wie oben.

**Wo er bricht.** Ohne Rand fehlt das Papier, und damit die einzige Aussage,
die den Knoten von einem Zeichen für "Verzweigung" trennt. Bei 16 Pixeln ist
die Figur erkennbar und unverwechselbar, aber sie steht ohne Fläche im Tab und
verschwindet neben Favicons, die eine haben. Die Richtung braucht eine
Wortmarke daneben.

## `knot-05-pane`

Knoten $O = (0{,}44,\ 0{,}40)$, also nahe der Blattmitte.

| Strahl | Richtung | Endpunkt | Zuweisung |
| --- | --- | --- | --- |
| 1 | $25°$ | $(1,\ 0{,}6611)$ | Tal |
| 2 | $90°$ | $(0{,}44,\ 1)$ | **Berg** |
| 3 | $195°$ | $(0,\ 0{,}2821)$ | Tal |
| 4 | $310°$ | $(0{,}7756,\ 0)$ | Tal |

Sektoren: $65 \quad 105 \quad 115 \quad 75$.

**Kawasaki.** $65 - 105 + 115 - 75 = 0$, also $65 + 115 = 180$ und
$105 + 75 = 180$. Summe $360$.

**Maekawa.** $M - V = 1 - 3 = -2$.

**Big-Little-Big.** Kleinster Sektor $65$, zwischen Strahl 1 (Tal) und
Strahl 2 (Berg).

**Wo er bricht.** Er ist der Bruchpunkt, den der Brief benennt, als Beleg
mitgeliefert. Die Rechnung stimmt an jeder Stelle, und trotzdem scheitert das
Bild: ein mittiger Knoten mit vier Sektoren zwischen 65° und 115° teilt das
Quadrat in vier Felder, und bei 16 und 24 Pixeln liest die Figur als
Fenstersprosse oder als Layout-Symbol. Der Vergleich mit `knot-01` bis
`knot-03` zeigt, wie weit der Knoten aus der Mitte muss: ab etwa einem Drittel
Blattbreite Versatz und einem kleinsten Sektor unter 55° kippt die Lesart
zurück zur Faltung. Nicht zur Ausarbeitung empfohlen.

## Der `.bel`-Weg

Er trägt, für zwei der fünf Entwürfe.

```
nix develop --command dune exec beloch -- fold \
  docs/brand/logo-explorations/knot/logo.bel > /tmp/logo.fold

cd packages/render-2d/render-svg && bun bin/fold2svg.ts /tmp/logo.fold /tmp/logo-cp.svg
```

`logo.bel` erzeugt den Knoten von `knot-01-emergent`, `logo-fish.bel` den von
`knot-03-fish`. Beide Programme laufen durch, und das FOLD, das dabei
herausfällt, trägt genau die Winkel und die Berg-Tal-Zuweisung, die oben
stehen. Der Evaluator ist damit die Prüfinstanz für diese beiden Entwürfe:
Kawasaki und Maekawa sind Teil seines Pipelines, ein Knoten, der sie verletzt,
wird abgelehnt (`spec/SPECIFICATION.md` §4.9, Prüfungen 11 und die
Maekawa-Aufzählung in Schritt 2).

Zwei Einschränkungen, damit der Beleg nicht mehr behauptet, als er hält.

**Die gelieferte SVG-Datei ist nicht die Ausgabe des Renderers.** Der Renderer
setzt Flächenpolygone, eine Legende und Beschriftungen und landet bei rund 6 KB
auf einem 572er Raster. Der Brief verlangt unter 2 KB, höchstens sechs Pfade
und einen quadratischen viewBox. Die gelieferten Dateien sind deshalb aus den
Koordinaten des Evaluators gesetzt, nicht aus seinem SVG. Geprüft ist die
Geometrie, gezeichnet ist die Datei.

**Der Entwurf zeigt nur die gefalteten Strahlen.** Am Knoten von `logo.bel`
liegen im vollen Faltmuster drei weitere Strahlen mit der Zuweisung `F`,
Reste der Konstruktionslinien, die den Knoten überhaupt erst festlegen. Sie
fallen im Zeichen weg. Das reduzierte Faltmuster steht für sich: ein Quadrat
mit einem einzigen inneren Knoten vom Grad 4, der lokal flachfaltbar ist,
faltet als Ganzes flach.

**Für `knot-02-fan` und `knot-05-pane` trägt der Weg nicht.** Ihre Winkel sind
aus der Zeichnung gewählt und aus den Ecken eines Quadrats nicht
konstruierbar. Sie sind von Hand gerechnet, die Rechnung steht oben.

## Die Strichsprache, und wo sie abweicht

`packages/render-2d/render-svg/src/theme.ts` gibt den Yoshizawa-Randlett-Stil
vor: Rand durchgezogen, Stärke 3; Berg Strich-Punkt `8 2 1 2`, Stärke 2; Tal
gestrichelt `6 4`, Stärke 2; alles einfarbig auf `ink`. Die Entwürfe
übernehmen die Systematik und weichen in drei Punkten bewusst ab, weil der
Renderer auf ein 460 Einheiten breites Blatt zeichnet und das Zeichen auf ein
52 Einheiten breites.

- **Strichstärken.** Rand 4, Falte 3 statt 3 und 2. Auf 52 Einheiten Blatt
  entspräche das Verhältnis des Renderers 0,34 und 0,23 Einheiten, bei 16 Pixel
  also rund einem Zwanzigstel Pixel.
- **Strichmuster.** Berg `6 2.5 1 2.5`, Tal `4.5 3`. Das Verhältnis Strich zu
  Lücke bleibt, die Periode ist auf die Strahllängen des Zeichens gerechnet.
  Mit den Werten des Renderers läge auf dem kürzesten Strahl weniger als eine
  Periode.
- **Strichende.** Die Faltlinien enden stumpf statt rund. Bei Strichstärke 3
  und Lücke 2,5 frisst ein runder Abschluss die Lücke, und Berg und Tal sehen
  gleich aus.

Der Punkt am Knoten folgt dem Renderer der Sache nach (gefüllter Kreis auf
`ink`), mit Radius 3 statt 3 auf 460 Einheiten Blatt.

## Die 16-Pixel-Fassungen

Jede `-16`-Datei ist dieselbe Geometrie ohne Strichmuster, mit Faltlinien auf
Stärke 4 und einem größeren Knotenpunkt. Die Berg-Tal-Unterscheidung fällt
dabei weg. Bei 16 Pixeln trägt ein Strichmuster nicht, und zwei Strichstärken
im Abstand von 0,1 Pixel tragen auch nicht; die Fassung zeigt das Faltmuster
ohne Zuweisung, was ein zulässiger Gegenstand ist.

Die Rasterprüfung hat dabei eine Grenze gezeigt, die der Brief so nicht
vorwegnimmt: **die Strichmuster-Fassung trägt erst ab etwa 48 Pixeln.** Bei
24 Pixeln auf der Folienecke und bei 38 Pixeln in Schwarz auf Weiß zerfallen
die Striche zu Punktreihen. Die `-16`-Fassung ist deshalb die Fassung für
alles unter 48 Pixeln und für den 1-Bit-Druck, nicht nur für das Favicon.

Geprüft wurde mit `@resvg/resvg-js` aus `packages/render-2d/node_modules`, in
16, 32, 64, 128 und 256 Pixeln, jede Größe angesehen; dazu auf `#101C2E` mit
Tinte `#E7EAF2`, im Kreisbeschnitt, in Schwarz auf Weiß bei 38 Pixeln und bei
24 Pixeln neben 18-pt-Text. Bei 16 Pixeln standen alle fünf Entwürfe neben
einem Quadrat, einem Kreis, einem Stern und einem Fadenkreuz.

Eine Maßangabe fällt dabei an, die in die Ableitung gehört: **im
Kreisbeschnitt darf das Zeichen höchstens 87 % des Kreisdurchmessers
einnehmen.** Die Ecke des Blattrahmens liegt $26\sqrt2 = 36{,}77$ Einheiten
vom Mittelpunkt des 64er viewBox entfernt, der einbeschriebene Kreis hat
Radius 32, und $32/36{,}77 = 0{,}87$. Bei voller Größe schneidet der
Repo-Avatar die vier Ecken des Blattes ab.

## Abnahmekriterien aus §8 des Briefs

Geprüft für `knot-01-emergent`, `knot-02-fan` und `knot-03-fish` samt ihren
`-16`-Fassungen. Was diese Exploration nicht liefert, steht als offen.

Größe und Reduktion

- [x] Bei 16 Pixel, in Graustufen, von Quadrat, Kreis, Stern und Fadenkreuz
      unterscheidbar. Direkt gegeneinander gerastert.
- [x] Bei 16 Pixel kein Strichmuster nötig; die `-16`-Fassung liegt bei.
- [x] Bei 32 Pixel ist die Faltung erkennbar: Knoten und vier Strahlen
      ungleicher Länge stehen. Berg und Tal stehen erst ab 48 Pixeln.
- [x] Bei 24 Pixel Höhe neben 18-pt-Text stört es den Text nicht, in der
      `-16`-Fassung.
- [x] Bei 10 mm, 1-Bit Schwarz auf Weiß, lesbar, in der `-16`-Fassung.

Farbe

- [x] Keine der verbotenen Farben und kein Rot- oder Blauton. Die Dateien
      nennen überhaupt nur `currentColor`.
- [x] Auf `#101C2E`, `#171B24`, `#F7F9FB` und Weiß liegt dieselbe Zeichnung.
- [x] In reinem Schwarz auf Weiß geht nichts verloren; die Zeichnung ist
      einfarbig.

Datei

- [x] SVG unter 2 KB (größte Datei 521 Byte), zwei `path`, kein `filter`,
      `mask`, `linearGradient`, `radialGradient`, `image`, `text`.
- [x] Quadratischer viewBox `0 0 64 64`, nichts liegt außerhalb. Der Brief
      nennt `0 0 128 128` als heutigen Wert; 64 ist durch vier teilbar und
      legt damit die Strichkanten bei 16 Pixeln auf ganze Pixel.
- [x] Im Kreisbeschnitt geht nichts verloren, bei höchstens 87 % Größe. Bei
      voller Größe werden die Blattecken beschnitten.
- [x] Alle Koordinaten sind konstruiert. Für `knot-01` und `knot-03` aus dem
      Evaluator, für `knot-02` und `knot-05` aus den oben notierten Winkeln.

Inhalt

- [x] Kein Kranich, kein Flugzeug, kein Tier, kein Gesicht, keine Ziffer.
- [x] Keine Perspektive, kein Schatten, kein Verlauf.
- [x] Maekawa und Kawasaki gelten am inneren Knoten, für jeden Entwurf
      einzeln nachgerechnet.
- [x] Neben `examples/bases/fish-base-cp.svg` wirkt es aus derselben Hand.
      Die Abweichungen bei Strichstärke, Muster und Strichende sind oben
      benannt und begründet.

Wortmarke und Kombination

- [ ] Offen. Diese Exploration liefert nur das Bildzeichen. Wortmarke,
      Kombination und der Abstand als Vielfaches der Strichstärke kommen mit
      der Ausarbeitung der gewählten Richtung.

## Rangfolge

1. **`knot-01-emergent`.** Der Evaluator erzeugt ihn, und seine vierte Falte
   ist eine, die kein Axiom konstruiert. Für die erste Zielgruppe ist das der
   Beleg, den der Brief von dieser Richtung erwartet. Bei 16 Pixeln lesbar, bei
   24 gut.
2. **`knot-02-fan`.** Das klarste Bild bei 16 und 24 Pixeln: eine sichtbare
   Gabel und eine lange Diagonale. Die Winkel sind gewählt, damit fehlt der
   Beleg. Als Fallback zu 1, falls dessen enger Sektor im Gebrauch stört.
3. **`knot-03-fish`.** Ebenfalls vom Evaluator, mit der kürzeren und besser
   lesbaren Herleitung, und er zitiert die Fischbasis, die das Repository schon
   zeigt. Das Bild ist gedrängter als 1 und 2.
4. **`knot-04-bare`.** Die reduzierteste Fassung, und die einzige, die auf dem
   Tab keine Fläche hat. Nur mit Wortmarke.
5. **`knot-05-pane`.** Nicht empfohlen. Liegt bei, weil er den Bruchpunkt
   belegt, den der Brief benennt.
