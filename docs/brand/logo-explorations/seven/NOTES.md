# Richtung "Die Sieben"

Vier ausgearbeitete Bildzeichen, alle auf derselben Ziffer. Die Wortmarke und
die Kombination sind hier nicht enthalten; diese Exploration klärt nur, ob die
Ziffer als Bildzeichen trägt.

Technisch gilt für jede Datei: `viewBox="0 0 64 64"`, Strichfarbe
`currentColor`, keine Verläufe, keine Filter, keine Masken, keine Schrift,
kein Raster. Jede Datei bleibt unter 600 Byte.

## Wie geprüft wurde

Jedes SVG wurde mit resvg (`@resvg/resvg-js`, dieselbe Bibliothek, die der
Renderer des Projekts benutzt) nach PNG gerastert, in 16, 24, 32, 64, 118 und
256 Pixel, und jede Fassung angesehen. Die kleinen Größen wurden nach der
Rasterung mit Nächster-Nachbar-Interpolation vergrößert, damit das echte
Pixelraster sichtbar bleibt und nicht eine Glättung die Beurteilung trägt.

Geprüft wurde zweimal: Tinte `#0f172a` auf Papier `#ffffff` und Tinte
`#E7EAF2` auf Navy `#101C2E`. Beide Male dieselbe Zeichnung, nur die Tinte
wechselt. Ein Graustufen-Test ist für diese Entwürfe leer: sie enthalten
überhaupt keine Farbe, die Graustufen-Reduktion ist also die Identität.

Die 1-Bit-Fassung wurde bei 118 Pixel gerastert (10 mm bei 300 dpi) und hart
auf Schwarz oder Weiß geschwellt.

Die Skripte lagen im Scratchpad und sind nicht Teil der Lieferung.

## Die Lesart der Sieben

Das Risiko: Wikipedia und Demaine & O'Rourke zählen nach Huzita-Hatori und
nennen den kubischen Beloch-Fold Axiom 6. Ein Teil der Zielgruppe liest eine
nackte 7 deshalb als Hatoris quadratisches Axiom. Drei Dinge halten dagegen,
und der Entwurf lehnt sich auf das erste.

**Die Sieben zählt die Axiome, sie indiziert keines.** Justin, Huzita-Hatori
und Hull sind sich über die Anzahl einig: es sind sieben Faltaxiome. Umstritten
ist allein, welche Nummer der kubische Fold darin trägt. Ein Zeichen, das die
Anzahl behauptet, behauptet damit etwas, dem alle drei Zählungen zustimmen.
Die Vortragszeile aus Abschnitt 9 des Briefs sagt bereits genau das: "The seven
axioms, as a language." Der Plural ist die ganze Absicherung.

**Der Querbalken.** Die europäische gequerte Sieben ist die Glyphenform, die
es gibt, um eine Fehllesung zu verhindern. Hier trägt sie zusätzlich eine
Faltbedeutung: der Balken ist eine Faltlinie. Er hebt das Zeichen von einer
gesetzten Ziffer ab und macht aus dem Index eine Figur.

**Die Spezifikation trägt die Zuordnung.** Die Mapping-Tabelle im Abschnitt
"A note on axiom numbering" der Spezifikation stellt alle drei Zählungen
nebeneinander, ADR 0005 begründet die Wahl. Das Zeichen muss diese Auflösung
nicht selbst leisten, es muss nur die Frage nicht falsch beantworten.

Daraus folgt eine Auflage für den späteren Auftritt: das Bildzeichen gehört
neben den Plural. "The seven axioms" ist gedeckt, "Axiom 7" ohne die Tabelle
daneben ist es nicht.

## Die gemeinsame Konstruktion

Drei der vier Entwürfe teilen ein Skelett. Das Blatt ist das Quadrat mit den
Ecken $(10,10)$ und $(54,54)$, Seitenlänge $44$.

- **Der Balken der Sieben ist die Oberkante des Blattes**, von $(10,10)$ nach
  $(54,10)$. Er ist Papierrand, keine Faltung. Damit sitzt die Ecke der Ziffer
  auf dem Papierrand und nicht im Blattinneren, was später wichtig wird.
- **Der Schaft ist eine Faltlinie** von der Ecke $(54,10)$ zum Punkt $(21,54)$
  auf der Unterkante. Ihre Richtung ist $(-33, 44)$, also $3 : 4$, mit der
  Länge $55$. Das pythagoreische Tripel $(33,44,55)$ hält die Konstruktion
  rational: Einheitsrichtung $u = (-0.6,\ 0.8)$, Normale $n = (0.8,\ 0.6)$,
  beide exakt. Jeder daraus abgeleitete Punkt bleibt exakt.
- **Der Mittelpunkt der Faltlinie** liegt bei $(37.5,\ 32)$. Er ist zugleich
  ihr Schnittpunkt mit der waagerechten Mittellinie $y = 32$ des Blattes.

Die 16-Pixel-Fassungen benutzen dasselbe Skelett, um $(32,32)$ leicht
aufgezogen: Oberkante $(9,9)$ bis $(56,9)$, Faltlinie nach $(23,53)$, wieder
$3:4$, Mittelpunkt $(39.5,\ 31)$. Das kauft Strichstärke im Pixelraster.

---

## 01 `seven-01-quer`: Die Mittellinie als Querbalken

**Konstruktion.** Skelett wie oben. Der Querbalken liegt auf $y = 32$, der
waagerechten Mittellinie des Blattes, und läuft von $x = 25.5$ bis $x = 49.5$,
also symmetrisch $12$ nach beiden Seiten um den Schnittpunkt $(37.5,\ 32)$.
Balken und Schaft sind ein Pfad, Strichstärke $6$, mit Gehrung an der Ecke.
Der Querbalken ist der zweite Pfad, Strichstärke $5$.

**Was er behauptet.** Die Mittellinie ist die Faltung, die die Oberkante auf
die Unterkante legt, also die Halbierung des Blattes. In der Zählung dieses
Projekts ist das Axiom 2, die einfachste Operation der Sprache. Das Zeichen
setzt damit die einfachste Faltung quer über die Ziffer, die für die
schwerste steht. Die Symmetrie von $12$ nach beiden Seiten ist die klassische
europäische Form, die Herleitung des Balkens kommt aus dem Papier.

**Wo er bricht.** Balken und Schaft kreuzen sich bei $53.13°$. Wer die
Zeichnung als Faltmuster liest, findet dort einen inneren Knoten vom Grad 4,
und der verletzt Kawasaki (siehe "Verworfen" unten). Die Zeichnung ist eine
Konstruktionsfigur und kein vollständiges Faltmuster: die Linien laufen nicht
bis zum Papierrand, das Blatt ist nicht gezeichnet. Ein Origami-Mathematiker,
der es trotzdem als Faltmuster liest, hat einen Einwand, und der Einwand ist
berechtigt.

Bei 16 Pixel verschmilzt der Querbalken mit dem Schaft zu einer Verdickung.
Die Ziffer bleibt, die Querung ist erkennbar, aber knapp; die 16-Pixel-Fassung
zieht deshalb an.

**Abnahmekriterien (Brief, Abschnitt 8)**

- [x] 16 px, Graustufen: unterscheidbar von Quadrat, Kreis, Stern, Fadenkreuz
- [x] 16 px ohne Strichmuster (Fassung `seven-01-quer-16.svg` liegt bei)
- [x] 32 px: Linie und Faltung erkennbar
- [x] 24 px Folienecke: gerastert und angesehen, trägt
- [x] 10 mm, 1-Bit Schwarz auf Weiß
- [x] keine verbotenen Farbwerte, kein Rot, kein Blau
- [x] dieselbe Zeichnung auf allen vier Flächen, nur Tinte wechselt
- [x] reines Schwarz auf Weiß ohne Informationsverlust
- [x] unter 2 KB, 2 `path`, kein `filter`/`mask`/`gradient`/`image`/`text`
- [x] quadratischer `viewBox`, nichts liegt außerhalb
- [ ] Kreisbeschnitt: Balkenende links und Gehrungsspitze rechts werden
      angeschnitten. Behebbar, der Avatar braucht das Zeichen auf $0.93$
      skaliert um $(32,32)$, dann liegt alles im einbeschriebenen Kreis.
- [x] Koordinaten konstruiert, nicht gerundet (alle exakt rational)
- [ ] keine Ziffer: verletzt, absichtlich, siehe "Die Lesart der Sieben"
- [x] keine Perspektive, kein Schatten, kein Verlauf
- [ ] Maekawa und Kawasaki: verletzt, wenn die Figur als Faltmuster gelesen
      wird. Siehe "Wo er bricht".
- [x] neben `examples/bases/fish-base-cp.svg`: gleiche Tinte, gleiche
      Rundkappen, Gewichte bewusst abweichend (siehe "Abweichungen")

---

## 02 `seven-02-band`: Der gefaltete Papierstreifen

**Konstruktion.** Ein Papierstreifen der Breite $11$. Der obere Arm läuft
waagerecht, der untere in Richtung $u = (-0.6,\ 0.8)$, dieselbe $3:4$-Neigung
wie das Skelett. Die Mittellinien schneiden sich bei $(43,\ 15.5)$.

Wird ein Streifen einmal gefaltet, ist die Faltlinie die Winkelhalbierende der
beiden Materialrichtungen. Der einlaufende Arm zeigt von der Faltung aus nach
$180°$, der auslaufende nach $126.87°$; die Halbierende liegt bei $153.43°$,
also in Richtung $(-2,\ 1)/\sqrt5$. Genau diese Linie verbindet die
Außenecke $(54,\ 10)$ mit der Innenecke $(32,\ 21)$, denn
$(32,21) - (54,10) = (-22,\ 11) = 11 \cdot (-2,\ 1)$. Gegenprobe über die
Breite: eine Faltlinie, die den Streifen der Breite $11$ unter $26.57°$ quert,
ist $11 / \sin(26.57°) = 24.60$ lang, und $\sqrt{605} = 24.60$.

Beide Rohkanten sind quer zum Blatt geschnitten: der Balken links senkrecht
bei $x = 11$, der Schaft unten waagerecht bei $y = 53$, von $(8,53)$ bis
$(21.75,\ 53)$.

Die Faltlinie ist als Lücke von $1.6$ Breite gezeichnet, also durch zwei
Flächen statt einer. In der Einfarbigkeit ist das der einzige Weg, eine Kante
innerhalb einer Fläche zu zeigen: ein Strich in Tintenfarbe auf Tinte wäre
unsichtbar, und eine zweite Farbe verbietet Constraint 2.

**Was er behauptet.** Das Zeichen ist ein Stück Papier, das einmal gefaltet
wurde, und die Ziffer ist das Ergebnis dieser Faltung. Die Winkelhalbierende
ist Axiom 5 in der Zählung des Projekts. Die konstante Streifenbreite und die
quer geschnittenen Enden sind die Belege: beides folgt aus der Faltung und ist
nachmessbar.

**Wo er bricht.** Kein Querbalken. Die Absicherung gegen die Lesart "Axiom 6"
liegt damit vollständig beim Kontext, nicht beim Zeichen. Das ist der Preis
für die Masse.

Eine frühere Fassung mit schräg geschnittenem Fuß las sich bei 64 und 256
Pixel als Papierflieger, also als eines der verbotenen Bilder aus Abschnitt 6.
Der waagerechte Fußschnitt hat das behoben; er verankert die Ziffer unten und
nimmt der Form die Pfeilspitze. Die Restgefahr bleibt: wer die Lücke an der
Außenecke als Glanzlicht liest, liest Plastizität in ein flaches Zeichen. Die
Lücke muss deshalb über die ganze Faltlinie durchlaufen und darf nicht als
Kerbe an der Ecke enden.

Bei 10 mm im Druck schließt sich die Lücke voraussichtlich. Das kostet nichts:
die 16-Pixel-Fassung ist genau diese geschlossene Form, ein einziger Pfad.

**Abnahmekriterien (Brief, Abschnitt 8)**

- [x] 16 px, Graustufen: unterscheidbar; die klarste Ziffer im Feld
- [x] 16 px ohne Strichmuster (`seven-02-band-16.svg`, ein Pfad, ohne Lücke)
- [ ] 32 px: die Faltung ist bei 32 px nicht mehr abzulesen, die Lücke fällt
      zu. Die Form bleibt die eines gefalteten Streifens, die Faltlinie selbst
      ist erst ab etwa 64 px sichtbar.
- [x] 24 px Folienecke: gerastert und angesehen, die stabilste der vier
- [x] 10 mm, 1-Bit Schwarz auf Weiß
- [x] keine verbotenen Farbwerte, kein Rot, kein Blau
- [x] dieselbe Zeichnung auf allen vier Flächen, nur Tinte wechselt
- [x] reines Schwarz auf Weiß ohne Informationsverlust
- [x] unter 2 KB, 2 `path`, kein `filter`/`mask`/`gradient`/`image`/`text`
- [x] quadratischer `viewBox`, nichts liegt außerhalb
- [x] Kreisbeschnitt: der äußerste Punkt liegt $31.9$ vom Mittelpunkt, der
      einbeschriebene Kreis hat Radius $32$. Passt ohne Anpassung.
- [ ] Koordinaten konstruiert: die tragenden Punkte sind exakt rational
      (Ecken, Streifenkanten, beide Schnittkanten). Die vier Eckpunkte der
      Lücke enthalten $1/\sqrt5$ und sind auf zwei Stellen gerundet. Sie
      tragen nichts: die Lücke ist Darstellung der Faltlinie, ihre Lage folgt
      aus der exakten Halbierenden.
- [ ] keine Ziffer: verletzt, absichtlich
- [x] keine Perspektive, kein Schatten, kein Verlauf
- [x] Maekawa und Kawasaki: kein innerer Knoten vorhanden. Eine einzige
      Faltlinie, die von Rand zu Rand läuft, hat keinen zu prüfenden Knoten.
- [ ] neben `fish-base-cp.svg`: bricht mit der Strichsprache. Der Renderer
      zeichnet Linien, dieser Entwurf zeichnet Flächen. Bewusst, aber es ist
      eine andere Hand.

---

## 03 `seven-03-falz`: Dasselbe Skelett in der Notation des Renderers

**Konstruktion.** Geometrisch identisch mit 01. Der Unterschied liegt in der
Strichsprache: die Oberkante ist Rand und trägt die schwerste Stärke $6.5$,
der Schaft ist Faltlinie und trägt $4.5$, der Querbalken ist Talfalte und
trägt dieselbe $4.5$ mit dem Muster `9 6`.

Das Verhältnis $6.5 : 4.5$ liegt nahe am $3 : 2$ des Renderers zwischen Rand
und Falte.

**Was er behauptet.** Das Zeichen stammt aus derselben Hand wie die Diagramme:
Rand und Falte sind unterscheidbar, und die Unterscheidung läuft über dieselben
Mittel, Gewicht und Strichmuster. Wer das Faltmuster der Fischbasis kennt,
liest die Hierarchie ohne Erklärung.

**Wo er bricht.** Die Muster der Yoshizawa-Randlett-Notation sind für
Diagramme gemacht und nicht für 50 Einheiten Strichlänge. Eine erste Fassung
mit dem Bergmuster `8 2 1 2` auf dem $55$ Einheiten langen Schaft wurde
gerastert und verworfen: bei $2.1$-facher Skalierung trägt der Schaft knapp
zwei Perioden und liest sich als zufällig unterbrochene Linie, nicht als
Bergfalte. Der Schaft ist deshalb durchgezogen, und nur der Querbalken trägt
ein Muster. Auch dort ist der Kompromiss sichtbar: `9 6` ist $1.5$-fach
skaliert, nicht die $2.25$, die zur Strichstärke gehören würde, weil das
Segment sonst $1.07$ Perioden trägt.

Bei 16 Pixel lösen sich die Striche des Querbalkens auf. Die 16-Pixel-Fassung
ist durchgezogen und fällt damit fast mit 01 zusammen. Das ist die ehrliche
Aussage dieses Entwurfs: die Notation ist eine Sprache für große Formate, und
im Favicon bleibt von ihr das Gewicht übrig.

Derselbe Kawasaki-Einwand wie bei 01 gilt hier stärker, weil dieser Entwurf
durch sein Strichmuster ausdrücklich behauptet, ein Faltmuster zu sein.

**Abnahmekriterien (Brief, Abschnitt 8)**

- [x] 16 px, Graustufen: unterscheidbar
- [x] 16 px ohne Strichmuster (`seven-03-falz-16.svg`, durchgezogen)
- [x] 32 px: Linie und Faltung erkennbar
- [x] 24 px Folienecke: gerastert und angesehen, trägt in der 16er-Fassung
- [x] 10 mm, 1-Bit Schwarz auf Weiß (die Striche schließen sich, ohne dass
      Information verloren geht)
- [x] keine verbotenen Farbwerte, kein Rot, kein Blau
- [x] dieselbe Zeichnung auf allen vier Flächen, nur Tinte wechselt
- [x] reines Schwarz auf Weiß ohne Informationsverlust
- [x] unter 2 KB, 3 `path`, kein `filter`/`mask`/`gradient`/`image`/`text`
- [x] quadratischer `viewBox`, nichts liegt außerhalb
- [ ] Kreisbeschnitt: wie 01, Skalierung $0.93$ nötig
- [x] Koordinaten konstruiert, nicht gerundet
- [ ] keine Ziffer: verletzt, absichtlich
- [x] keine Perspektive, kein Schatten, kein Verlauf
- [ ] Maekawa und Kawasaki: verletzt, und hier mit Ansage, weil das
      Strichmuster die Faltmuster-Lesart einlädt
- [x] neben `fish-base-cp.svg`: die Hierarchie stimmt, die Gewichte weichen
      bewusst ab (siehe "Abweichungen")

---

## 04 `seven-04-spiegel`: Punkt und Spiegelbild als Querbalken

**Konstruktion.** Skelett wie oben. Der Querbalken ist das Segment von
$P = (29.5,\ 26)$ nach $Q = (45.5,\ 38)$. Es steht senkrecht auf der Faltlinie
und wird von ihr halbiert: $Q - P = (16,\ 12) = 4 \cdot (4,\ 3)$ ist parallel
zur Normalen $n = (0.8,\ 0.6)$, und der Mittelpunkt $(37.5,\ 32)$ ist der
Mittelpunkt der Faltlinie. Beides numerisch geprüft, beides exakt null.

An beiden Enden sitzt ein gefüllter Kreis vom Radius $3.5$, das Punktzeichen
des Renderers.

**Was er behauptet.** Ein Punkt, sein Spiegelbild, und die Faltung dazwischen.
Das ist die Grundfigur, aus der jedes Axiom besteht, und die Richtung D des
Briefs in einer Ziffer. Der rechte Winkel ist keine Setzung: die Faltlinie ist
die Mittelsenkrechte von $PQ$, also folgt die Neigung des Querbalkens aus der
Neigung des Schafts. Dieser Entwurf ist der einzige der vier, dessen Querung
auch als Faltmuster-Knoten zulässig wäre, denn $90°$ ist der einzige Winkel,
unter dem sich zwei gerade Faltlinien flachfaltbar kreuzen.

**Wo er bricht.** Er ist der unleserlichste der vier, und die Ursache ist
strukturell. Die Senkrechte auf einem Schaft, der nach unten links läuft,
fällt zwangsläufig nach unten rechts, um $36.87°$ gegen die Waagerechte. Ein
Querbalken in dieser Neigung arbeitet gegen die Ziffer: das Zeichen liest sich
bei 32 und 16 Pixel eher als Kreuzung denn als gequerte Sieben.

Eine erste Fassung mit Punktradius $5$ und Strichstärke $4.5$ wurde gerastert
und verworfen: die beiden Kreise lasen sich als Hantel, die quer über der
Ziffer liegt. Die gelieferte Fassung ist auf Radius $3.5$ bei Strichstärke
$3.5$ zurückgenommen. Der Renderer setzt $r = 1.5 w$; diese Abweichung ist der
Preis dafür, dass die Punkte Annotation bleiben und nicht Hauptmotiv werden.

**Abnahmekriterien (Brief, Abschnitt 8)**

- [x] 16 px, Graustufen: unterscheidbar, aber die schwächste der vier
- [x] 16 px ohne Strichmuster (`seven-04-spiegel-16.svg`)
- [x] 32 px: Linie und Spiegelung erkennbar, das ist die Stärke des Entwurfs
- [ ] 24 px Folienecke: trägt, wirkt aber unruhig; die Punkte fallen bei
      dieser Größe mit dem Schaft zusammen
- [x] 10 mm, 1-Bit Schwarz auf Weiß
- [x] keine verbotenen Farbwerte, kein Rot, kein Blau
- [x] dieselbe Zeichnung auf allen vier Flächen, nur Tinte wechselt
- [x] reines Schwarz auf Weiß ohne Informationsverlust
- [x] unter 2 KB, 2 `path` und 2 `circle`, kein
      `filter`/`mask`/`gradient`/`image`/`text`
- [x] quadratischer `viewBox`, nichts liegt außerhalb
- [ ] Kreisbeschnitt: wie 01, Skalierung $0.93$ nötig
- [x] Koordinaten konstruiert, nicht gerundet (Senkrechte und Halbierung
      numerisch auf exakt null geprüft)
- [ ] keine Ziffer: verletzt, absichtlich
- [x] keine Perspektive, kein Schatten, kein Verlauf
- [x] Maekawa und Kawasaki: der Winkel an der Kreuzung ist $90°$ und damit
      der einzige flachfaltbare. Als vollständiges Faltmuster fehlt dem
      Segment trotzdem der Anschluss an den Papierrand, siehe "Verworfen".
- [x] neben `fish-base-cp.svg`: Punktzeichen und Tinte stammen aus dem
      Renderer, die Gewichte weichen bewusst ab

---

## Verworfen: die als Faltmuster gültige Sieben

Ein fünfter Entwurf wurde gebaut, gerastert und verworfen. Er ist hier
dokumentiert, weil er die Grenze dieser ganzen Richtung markiert.

Wer die Ziffer als gültiges Faltmuster zeichnen will, bekommt drei Auflagen
auf einmal:

1. Zwei gerade Faltlinien, die sich im Blattinneren kreuzen, bilden einen
   Knoten vom Grad 4 mit den Sektoren $\alpha,\ 180° - \alpha,\ \alpha,\
   180° - \alpha$. Kawasaki verlangt, dass abwechselnde Sektoren zusammen
   $180°$ ergeben, also $2\alpha = 180°$ und damit $\alpha = 90°$. Der
   Querbalken muss senkrecht auf dem Schaft stehen.
2. Eine Faltlinie darf im Blattinneren nicht enden. Der Querbalken muss also
   bis zum Papierrand durchlaufen.
3. Das Blatt muss gezeichnet sein, sonst ist es kein Faltmuster.

Zusammen ergibt das: Schaft von $(54,10)$ nach $(21,54)$, Querbalken senkrecht
durch $(37.5,\ 32)$ bis an die Ränder, also von $(10,\ 11.375)$ nach
$(54,\ 44.375)$, und das Quadrat drumherum. Gerastert ist das ein Quadrat mit
einem X darin, in jeder Größe. Ohne das Quadrat bleibt ein Dreieck mit einem X.
In keiner der beiden Fassungen ist eine Sieben zu sehen.

Daraus folgt die Entscheidung für alle vier gelieferten Entwürfe: der
Querbalken ist eine Bezugslinie und keine ausgeführte Faltung, und das Blatt
wird nicht gezeichnet. Die Figur ist eine Konstruktionszeichnung. Maekawa und
Kawasaki gelten für Faltmuster; eine Konstruktionszeichnung mit einer einzigen
Faltlinie hat keinen Knoten, an dem sie greifen könnten. Entwurf 02 ist der
einzige, für den diese Verteidigung nicht nötig ist: er zeigt eine ausgeführte
Faltung, und deren Faltlinie läuft von Rand zu Rand.

## Abweichungen von der Strichsprache des Renderers

Jede Abweichung mit dem Grund, damit sie nachvollziehbar bleibt.

**Strichstärke.** Der Renderer zeichnet den Rand mit $3$ auf einem Blatt von
$460$ Einheiten, also $0.65\,\%$ der Blattbreite. Diese Entwürfe zeichnen ihn
mit $6$ auf einem Blatt von $44$ Einheiten, also $13.6\,\%$, ungefähr das
Einundzwanzigfache. Bei 16 Pixel entspricht $0.65\,\%$ einem Zehntel Pixel. Die
Proportionen des Renderers sind für ein Diagramm gemacht, das ein Blatt füllt.

**Verhältnisse.** Wo mehrere Gewichte nebeneinander stehen, bleibt das
Verhältnis erhalten. Entwurf 03 setzt Rand zu Falte auf $6.5 : 4.5$, der
Renderer auf $3 : 2$.

**Punktradius.** Der Renderer setzt $r = 3$ bei Faltstärke $2$, also
$r = 1.5\,w$. Entwurf 04 setzt $r = w$. Begründung im Entwurf.

**Strichmuster.** Die Talfalte `6 4` erscheint in Entwurf 03 als `9 6`, also
$1.5$-fach statt der zur Strichstärke gehörenden $2.25$-fachen Skalierung.
Begründung im Entwurf.

**Rundkappen.** `stroke-linecap="round"` wie im Renderer. Die Ecke der Ziffer
ist dagegen auf Gehrung gesetzt, weil eine Papierecke spitz ist.

## Rangfolge

**1. `seven-01-quer`.** Er löst die Aufgabe vollständig: die Ziffer ist gequert
und damit gegen die Fehllesung gestellt, der Querbalken hat eine Herleitung aus
dem Papier, und das Zeichen bleibt bis 16 Pixel lesbar. Er ist still genug, um
neben einem Faltmuster zu stehen, und er besteht aus zwei Pfaden. Sein offener
Punkt ist der Kawasaki-Einwand, und der ist eine Frage der Lesart, keine der
Zeichnung.

**2. `seven-02-band`.** Die mit Abstand beste Leistung bei 16 Pixel und die
einzige Fassung, die den Kreisbeschnitt ohne Anpassung übersteht. Die Faltung
ist hier die Form selbst und braucht keine Konstruktionslinie, die sie
behauptet. Er fällt auf Platz zwei, weil ihm der Querbalken fehlt: ohne ihn ist
das Zeichen eine nackte Sieben, und die Absicherung gegen "Axiom 6" liegt
vollständig im Text daneben. Dazu kommt der Bruch mit der Strichsprache. Wenn
die Entscheidung später lautet, dass die Lesart über die Wortmarke geregelt
wird, rückt dieser Entwurf auf Platz eins.

**3. `seven-03-falz`.** Der beste Beleg für Herkunft und der schlechteste
Umgang mit Größe. Bei 256 Pixel ist er der überzeugendste der vier, bei 16
Pixel ist er Entwurf 01 mit anderer Strichstärke. Er ist als große Fassung
wertvoll, etwa auf einer Titelfolie oder im Papier, und braucht für alles
Kleine ohnehin 01.

**4. `seven-04-spiegel`.** Der sauberste Gedanke und die schwächste Form. Er
ist der einzige, dessen Querung geometrisch auch als Faltknoten durchginge, und
er zeigt die Grundfigur der Sprache. Die erzwungene Neigung von $36.87°$
arbeitet gegen die Ziffer, und das ist nicht wegzugestalten: sie folgt aus der
Senkrechten. Er bleibt als Beleg im Konstruktionsblatt nützlich.

## Was offen bleibt

- Wortmarke und Kombination sind nicht Teil dieser Exploration. Constraint 6
  des Briefs ist damit für alle vier Entwürfe offen.
- Der Brief nennt `viewBox="0 0 128 128"` als heutigen Stand, diese Exploration
  arbeitet in $64 \times 64$. Die Umrechnung ist eine Verdopplung aller Werte
  und verlustfrei, weil alle tragenden Koordinaten rational sind.
- Abschnitt 6 des Briefs verbietet Ziffern. Die Aufhebung dieses Verbots ist
  eine Entscheidung, die außerhalb dieser Exploration getroffen wurde; wenn sie
  bestehen bleibt, gehört sie in den Brief und in einen Decision Record, sonst
  widerspricht das gelieferte Zeichen dem Dokument, an dem es hängt.
