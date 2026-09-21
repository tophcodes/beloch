# Logo-Brief: Beloch

Auftrag für die Gestaltung von Bildzeichen und Wortmarke. Der Brief richtet
sich an einen Gestalter, Mensch oder Bildgenerierungs-Werkzeug, der das Projekt
nicht kennt. Er ist so geschrieben, dass er ohne Begleitgespräch übergeben
werden kann. Die Positionierung, an der er hängt, steht in
`docs/brand/research/positioning.md`; der Brief übernimmt deren Tonalität und
widerspricht ihr an keiner Stelle.

Auftrittssprache des Projekts ist Englisch. Die Wortmarke lautet "Beloch", in
dieser Schreibweise, ohne Zusatz.

## 1. Was Beloch ist

Beloch ist eine Programmiersprache, in der ein Programm eine Faltanleitung ist:
jede Zeile ist eine Faltung. Wer ein Blatt Papier beschreibt und dann Zeile für
Zeile sagt, welcher Punkt auf welche Linie gefaltet wird, bekommt am Ende zwei
Zeichnungen heraus: das Faltmuster (alle Faltlinien auf dem flachen Blatt) und
das gefaltete Ergebnis. Die sieben erlaubten Faltoperationen sind die
Huzita-Justin-Axiome, ein Satz von Grundoperationen, mit dem sich jede Faltung
mit geraden Faltlinien zusammensetzen lässt. Beloch rechnet dabei ohne Rundung:
eine Kubikwurzel bleibt eine Kubikwurzel, und die Frage "liegt dieser Punkt auf
dieser Linie" hat eine Antwort und keine Toleranz. Das Projekt tritt als
Forschungsartefakt auf, das benutzbar ist: Spezifikation, Decision Records und
ein Browser-Playground liegen offen.

Wer das Bild dazu sehen will: `examples/bases/fish-base-cp.svg` (Faltmuster)
und `examples/bases/fish-base-folded.svg` (gefaltet), beide aus demselben
zwölfzeiligen Programm erzeugt.

## 2. Der Name als Gestaltungsmaterial

### Margherita Piazzolla Beloch, 1936

Die Sprache ist nach der italienischen Mathematikerin Margherita Piazzolla
Beloch benannt. Sie zeigte 1936, dass Papierfalten kubische Gleichungen löst.
Zirkel und Lineal kommen bis zur Quadratwurzel; damit lassen sich weder ein
Würfel verdoppeln noch ein Winkel dritteln, zwei Aufgaben, die seit der Antike
offen waren. Eine einzige Faltung, die heute Beloch-Fold heißt, schafft beides.
Papierfalten ist damit das mächtigere Werkzeug, und diese Tatsache ist der Kern
der ganzen Origami-Mathematik. Beloch ist dafür wenig bekannt; der Name des
Projekts ist eine kleine Korrektur.

Aussprache: italienisch, "beh-LOK", Betonung auf der zweiten Silbe, hartes k
am Ende. Dateiendung der Sprache: `.bel`.

### Was der Beloch-Fold geometrisch tut

Das ist die Operation, die sich zeichnerisch aufgreifen lässt. Schritt für
Schritt, ohne Vorwissen:

1. Auf dem Blatt liegen zwei Punkte P und Q und zwei Geraden d und e.
2. Gesucht ist eine einzige gerade Faltlinie, nach der P auf d liegt und Q
   gleichzeitig auf e.
3. Nur die erste Bedingung, P auf d: es gibt unendlich viele Faltlinien, die
   das schaffen. Alle zusammen sind die Tangenten einer Parabel, deren
   Brennpunkt P und deren Leitlinie d ist. Wer die Faltlinie entlangfährt,
   zeichnet die Parabel als Hüllkurve.
4. Beide Bedingungen zusammen: die Faltlinie ist eine gemeinsame Tangente an
   zwei Parabeln. Zwei Parabeln haben bis zu drei gemeinsame Tangenten.
5. Also gibt es bis zu drei gültige Faltungen, und das Programm muss sagen,
   welche es meint. Beloch verlangt dafür ein `toward`-Wort in der Zeile.

Die drei Lösungen entsprechen den drei reellen Wurzeln einer kubischen
Gleichung. Zirkel und Lineal kommen bis zur zweiten Wurzel; diese Faltung
erreicht die dritte.

In der Sprache ist es die schwerste Operation: keine geschlossene Formel, bis
zu drei Ergebnisse, und die Frage, wie ein Programm eindeutig sagt, welches
gemeint ist, zieht sich durch den ganzen Entwurf.

Bildmaterial für den Gestalter: zwei Punkte, zwei Geraden, zwei Parabeln, eine
Tangente, die beide berührt. Die Faltlinie ist eine Gerade. Die Parabeln sind
Hilfsfiguren; auf dem Papier sieht sie niemand.

### Eine Falle bei der Nummerierung

Die Literatur zählt die sieben Axiome unterschiedlich. Beloch folgt der
klassischen Huzita-Justin-Zählung nach Justin 1986, die nach algebraischer
Stärke ordnet; dort ist der kubische Beloch-Fold **Axiom 7**, die letzte und
stärkste Operation. Wikipedia und Demaine zählen nach Huzita-Hatori und nennen
dieselbe Faltung Axiom 6. Für das Zeichen heißt das: keine Ziffer ins Logo.
Eine "7" bindet es an eine Zählung, die außerhalb des Projekts anders lautet.

## 3. Gefühlslage

Fünf Wörter, je mit dem Grund, warum dieses und nicht das Nachbarwort.

- **exakt.** Das Nachbarwort wäre "präzise". Präzise ist ein Werkzeugversprechen
  mit Toleranz; exakt heißt: es gibt keine Toleranz, die Kubikwurzel bleibt
  Kubikwurzel. Das Zeichen darf keine Unschärfe, keine Weichzeichnung und keinen
  Verlauf haben.
- **konstruiert.** Das Nachbarwort wäre "gestaltet". Konstruiert im Sinn von
  Zirkel und Lineal: jede Linie im Zeichen hat eine Herleitung aus einer
  anderen. Nichts ist freihändig gesetzt, nichts ist "optisch korrigiert", ohne
  dass sich das begründen lässt.
- **nüchtern.** Das Nachbarwort wäre "minimalistisch". Minimalismus ist eine
  Ästhetik, die man kaufen kann; Nüchternheit ist der Ton einer Spezifikation.
  Die Vorbilder im Feld, ORIPA und Rabbit Ear, treten fast schmucklos auf, und
  das liest in dieser Community als Echtheit.
- **still.** Das Nachbarwort wäre "elegant". Elegant ist ein Werturteil, und
  die Positionierung verbietet Werturteile im Auftritt. Still heißt: das Zeichen
  steht neben einem Faltmuster, ohne es zu übertönen, und neben einem
  Vortragstitel, ohne ihn zu kommentieren.
- **flach.** Das Nachbarwort wäre "plastisch". Beloch rechnet ausschließlich
  flache Faltzustände, und das ist eine Architekturentscheidung. Ein Zeichen
  mit Tiefe, Schatten oder Perspektive verspricht 3D, das die Sprache nicht hat.

## 4. Die visuelle Welt, in der das Zeichen lebt

Das Zeichen landet neben Diagrammen, die der Renderer des Projekts erzeugt.
Diese Diagramme haben eine feste Sprache, und das Zeichen muss daneben
bestehen.

**Strichsprache (Yoshizawa-Randlett).** Der Standardstil ist einfarbig in Tinte
`#0f172a` auf Papier `#f8fafc`. Berg und Tal werden über das Strichmuster
unterschieden: Rand durchgezogen (Strichstärke 3), Berg als Strich-Punkt
(`8 2 1 2`, Stärke 2), Tal gestrichelt (`6 4`, Stärke 2), unbewegte
Konstruktionslinien fein gepunktet (`1 3`, Stärke 1,5, 45 % Deckung). Punkte
sind kleine gefüllte Kreise, Radius 3. Quelle:
`packages/render-2d/render-svg/src/theme.ts`.

**Farbstil.** Alternativ, nicht Standard: Berg `#dc2626` (Rot), Tal `#2563eb`
(Blau), Rand `#1f2937`, Konstruktion `#6366f1`, unzugeordnet `#f59e0b`. Diese
Farben tragen Bedeutung. Wer im Projekt Rot sieht, liest "Berg", wer Blau
sieht, liest "Tal".

**Web-Tokens.** Die Site nutzt abweichende, hellere Werte derselben
Bedeutungen: Dunkelmodus Tal `#6f9bff`, Berg `#ff7d5e`; Hellmodus Tal
`#2f5fd0`, Berg `#cf4327`. Flächen: Code-Panel `#101C2E`, Panel dunkel
`#171B24`, Panel hell `#F7F9FB`, Tinte dunkel `#E7EAF2`, Tinte hell `#171A21`.
Quelle: `packages/www/src/styles/theme.css`.

**Typografie heute.** Die Wortmarke auf der Landing ist reiner Text: "Beloch"
in IBM Plex Mono, Gewicht 600. Fließtext in IBM Plex Sans. Die Sprache selbst
hat zwei Sigillen, die in jedem Programm stehen: `.a` ist ein Punkt, `--diag`
ist eine Faltlinie. Punkt und Doppelstrich sind damit Zeichen der Sprache,
bevor irgendein Logo existiert.

**Das heutige Bildzeichen.** `packages/www/public/favicon.svg` zeigt einen
vierzackigen Stern mit vier Diagonalstrahlen, in der Mitte ein Quadrat mit
konkaven Seiten, dazu vier Punkte in den Ecken. Es ist ein Platzhalter. Zwei
Probleme: Es liest als Kompassrose oder als "Sparkle", das Symbol, das heute
jede KI-Funktion trägt. Und es hat keine Beziehung zu Papier, Faltung oder
Axiom. Es wird ersetzt.

**Der Kontext im Feld.** Rabbit Ear (JavaScript-Origami-Bibliothek, das
empfohlene Anzeigewerkzeug für Belochs Ausgabe) trägt ein stilisiertes
Hasenohr. Roc (Programmiersprache) trägt einen violetten Origami-Vogel aus
sechs Dreiecken. Gleam trägt ein Maskottchen, einen Stern. Zig trägt einen
Blitz. ORIPA hat kein Zeichen, nur den Namen. Belege in
`docs/brand/research/landscape.md`.

## 5. Harte Constraints

Jede Vorgabe mit dem Grund. Wer eine davon verletzt, liefert kein Ergebnis.

1. **Bei 16 und 32 Pixel erkennbar.** Das Zeichen ist zuerst ein Favicon im
   Browser-Tab, daneben stehen zwanzig andere. Was bei 16 Pixel zu einem
   grauen Fleck wird, existiert dort nicht. Strichmuster (gestrichelt,
   Strich-Punkt) lösen sich bei 16 Pixel auf; wenn das Zeichen sie nutzt,
   braucht es eine Fassung ohne sie.
2. **Einfarbig voll funktionsfähig.** Das Zeichen landet in der Papier-Fassung
   eines wissenschaftlichen Artikels (Schwarz auf Weiß, oft 1-Bit-Druck) und in
   der Ecke von Konferenzfolien. Eine zweite Farbe darf hinzukommen, sie darf
   nichts tragen. Der Renderer des Projekts arbeitet selbst standardmäßig
   einfarbig; das Zeichen folgt derselben Disziplin.
3. **Vektor, SVG, wenige Pfade.** Ziel: eine Datei unter 2 KB, höchstens sechs
   Pfade, keine Filter, keine Masken, keine Verläufe, kein eingebettetes
   Raster, kein Text-Element (Schrift als Pfad). Grund: das SVG wird inline in
   Seiten gesetzt, vom Build-Werkzeug rasterisiert und von Hand gepflegt.
   Jeder Pfad, den ein Mensch nicht lesen kann, ist ein Wartungsproblem.
4. **Lebt auf dunklem Navy und auf Papierweiß, ohne Umgestaltung.**
   Dunkel: `#101C2E` und `#171B24`. Hell: `#F7F9FB` und Weiß. Die Landing ist
   standardmäßig dunkel, die Docs folgen dem System, das Paper ist weiß. Das
   Zeichen wechselt zwischen den beiden Welten durch eine Farbe (Tinte hell
   `#E7EAF2` auf dunkel, Tinte dunkel `#0f172a` auf hell). Technisch: eine
   Datei mit `fill="currentColor"` oder dem heutigen
   `prefers-color-scheme`-Block. Keine zwei Zeichnungen.
5. **Kein Rot, kein Blau.** Im Projekt heißt Rot "Berg" und Blau "Tal". Ein
   Zeichen in einer dieser Farben behauptet eine Faltrichtung, die es nicht
   hat, und steht neben einem Diagramm, das dieselben Farben mit Bedeutung
   verwendet. Verboten sind `#dc2626`, `#2563eb`, `#ff7d5e`, `#6f9bff`,
   `#cf4327`, `#2f5fd0` und jeder Ton, der in Graustufen-Reduktion mit ihnen
   verwechselbar wäre. Falls eine Akzentfarbe nötig ist: außerhalb von Rot und
   Blau, und sie darf beim Wegfall nichts kosten (siehe Constraint 2).
6. **Wortmarke und Bildzeichen getrennt und gemeinsam.** Drei Fassungen:
   Bildzeichen allein (Favicon, Repo-Avatar, Folien-Ecke), Wortmarke allein
   (Site-Header, Paper-Titel), Kombination (Social-Preview, Vortrags-Titelfolie).
   Die Kombination darf keine dritte Zeichnung sein; sie setzt die beiden
   anderen nebeneinander. Die Wortmarke bleibt "Beloch" in einer Schreibweise,
   die sich als "Beloch" liest, keine Verformung, die "Belech" oder "Beloh"
   zulässt.
7. **Kein Widerspruch zur Geometrie.** Wenn das Zeichen eine Faltung zeigt,
   muss die Faltung flachfaltbar sein. Zwei prüfbare Regeln aus der
   Origami-Mathematik: an jedem inneren Knoten ist die Zahl der Bergfalten
   minus der Zahl der Talfalten plus oder minus zwei (Maekawa), und die
   Winkel um den Knoten summieren sich abwechselnd zu 180 Grad (Kawasaki).
   Ein Origami-Mathematiker sieht auf den ersten Blick, ob das stimmt, und er
   ist die erste Zielgruppe.

## 6. Verbotene Bilder

Jeder Punkt mit einem Satz Begründung.

- **Der gefaltete Papierkranich.** Er ist das Origami-Zeichen für alle, die
  Origami nicht kennen, und damit für niemanden aus der Zielgruppe; außerdem
  ist der Kranich ein Meilenstein, der im Projekt noch aussteht, und ein Logo
  darf nichts versprechen, das das Repository nicht einlöst.
- **Das Papierflugzeug.** Es steht für "senden", "Start" und "Telegram"; mit
  Falten hat es nur die Herkunft gemeinsam.
- **Der generische Origami-Fuchs, Vogel, Hase.** Tiere aus Dreiecken sind
  das Muster von Roc (Vogel) und Rabbit Ear (Hasenohr); der Entwurf liefe in
  beide hinein und hätte dazu ein Tier, das in der Sprache nicht vorkommt.
- **Isometrisches 3D-Papier mit Schlagschatten.** Beloch rechnet flache
  Zustände; Tiefe im Zeichen behauptet das Gegenteil, und ein Schatten
  verlangt Farbe oder Grau, das in der 1-Bit-Fassung wegfällt.
- **Verläufe.** Sie überleben weder Constraint 2 noch 3, und ein Verlauf ist
  die verlässlichste Signatur eines Startup-Logos aus den letzten zehn Jahren.
- **Maskottchen.** Ein Wesen mit Augen zieht die Aufmerksamkeit vom Diagramm
  auf sich, und die Positionierung verbietet alles, was der Auftritt nicht mit
  einem Beleg im Repository stützt.
- **Alles, was nach Startup-Logo aussieht.** Erkennbar an: abgerundeten Quadraten
  als Fläche hinter dem Zeichen, Buchstaben in geometrischer Sans mit
  Verlauf, "Sparkle"-Sternen, negativem Raum, der einen Pfeil bildet. Dieses
  Publikum liest Verkaufssprache in einem Satz, und ein Logo ist ein Satz.
- **Die Kompassrose und der vierzackige Stern.** Das heutige Favicon ist
  beides; es wird abgelöst.
- **Eine Ziffer.** Siehe Nummerierungsfalle in Abschnitt 2.

## 7. Konzeptrichtungen

Vier Richtungen, jede so beschrieben, dass sie sich ohne Rückfrage zeichnen
lässt. Jede mit Konstruktion, Begründung und der Stelle, an der sie bricht.

### A. Die gemeinsame Tangente (aus der Mathematik)

**Idee.** Das Zeichen ist der Beloch-Fold selbst: zwei Punkte, zwei Geraden,
eine Faltlinie, die beide Bedingungen erfüllt.

**Konstruktion.** Quadratischer Rahmen, gedacht als Blatt, Rand nicht
zwingend gezeichnet. Zwei Geraden d und e, die sich außerhalb des sichtbaren
Bereichs schneiden (nicht parallel: parallel ist der Fall, in dem der Fold
zerfällt). Zwei Punkte P und Q, jeder auf der anderen Seite seiner Geraden als
der Schnittpunkt. Die Faltlinie als Gerade, die P auf d und Q auf e spiegelt.
Für die Zeichnung: P und sein Spiegelbild P' auf d, die Faltlinie ist die
Mittelsenkrechte von PP'; dasselbe muss für Q und Q' auf e stimmen, mit
derselben Faltlinie. Wer das exakt haben will, lässt Beloch die Linie rechnen
(`map .p onto --d and .q onto --e toward .x`). Die beiden Parabeln, deren
Tangente die Faltlinie ist, erscheinen in der großen Fassung als feine
Hüllkurven (Konstruktionsstil: gepunktet, 45 %); in der Favicon-Fassung fallen
sie weg. Dann bleiben: zwei Punkte, zwei Linien, eine Faltlinie in Tal-Strich
oder, bei 16 Pixel, durchgezogen mit anderer Stärke.

**Warum sie passt.** Das ist die Faltung, nach der das Projekt heißt, in
ihrem einzigen Bild. Wer die Geometrie kennt, erkennt sie sofort; wer sie
nicht kennt, sieht eine Konstruktionszeichnung, was die Tonalität trifft.

**Wo sie bricht.** Fünf Elemente sind viele für 16 Pixel; die Hüllkurven
bringen Kurven in ein Projekt, das nur gerade Faltlinien kennt, und ohne sie
sieht die Zeichnung aus wie eine beliebige Geometrieaufgabe. Die Richtung
steht und fällt mit einer Reduktion, die bei drei Elementen ankommt: ein
Punkt, sein Spiegelbild, die Faltlinie dazwischen.

### B. Ein Knoten (aus der Faltung)

**Idee.** Ein einziger flachfaltbarer Knoten: vier Faltlinien treffen sich in
einem Punkt, drei Berg, eine Tal. Die kleinste Aussage, die Origami macht,
gezeichnet in der Strichsprache des Projekts.

**Konstruktion.** Quadrat als Blatt. Ein innerer Punkt, aus dem Zentrum
versetzt, damit die vier Sektoren ungleich sind. Vier Faltlinien vom
Punkt zum Rand. Die Winkel müssen Kawasaki erfüllen: Winkel 1 plus Winkel 3
gleich 180 Grad, damit Winkel 2 plus Winkel 4 ebenfalls. Maekawa: drei Berg
(Strich-Punkt `8 2 1 2`), eine Tal (Strich `6 4`); oder umgekehrt eine Berg,
drei Tal. Die Fischbasis in `examples/bases/fish-base-cp.svg` zeigt zwei
solcher Knoten. Für 16 Pixel: das Muster fällt weg, die Talfalte wird als
dünnere Linie oder als Lücke gezeichnet, der Rand bleibt.

**Warum sie passt.** Das Zeichen ist ein gültiges Crease Pattern und
sieht aus wie das, was der Renderer sowieso erzeugt. Es lässt sich als
`.bel`-Programm schreiben, und dann erzeugt das Projekt sein eigenes Logo. Für
die erste Zielgruppe ist das der stärkste Beleg, den ein Zeichen liefern kann.

**Wo sie bricht.** Vier Linien durch einen Punkt sind ein Asterisk, ein
Fadenkreuz oder das heutige Favicon. Die Gefahr ist die Symmetrie: sobald die
Winkel gleich sind, ist es ein Stern. Der Versatz des Knotens und die
ungleichen Sektoren sind das Einzige, was die Richtung von einem Sternchen
trennt, und bei 16 Pixel muss das noch sichtbar sein.

### C. Das gefaltete B (typografisch)

**Idee.** Der Buchstabe B, einmal gefaltet. Der Stamm ist die Faltlinie, ein
Bauch ist die Rückseite des Papiers.

**Konstruktion.** Ein geometrisches B aus einem Stamm und zwei Bögen, auf
einem Raster, das zu IBM Plex Mono passt (die Wortmarke bleibt Plex). Eine
gerade Faltlinie, die den Buchstaben schneidet, etwa diagonal durch den
unteren Bauch. Der Teil unterhalb der Faltlinie wird an ihr gespiegelt und
liegt danach auf dem oberen Teil auf. In der einfarbigen Fassung ist der
umgeklappte Teil als Kontur gezeichnet, der Rest gefüllt; so liest sich Vorder-
und Rückseite ohne zweite Farbe. Die Faltlinie selbst als Tal-Strich `6 4`
oder, klein, als durchgezogene Kante zwischen Füllung und Kontur.

**Warum sie passt.** Der Buchstabe trägt den Namen, die Faltung trägt das
Thema, und die Regel "die Faltung muss geometrisch stimmen" gilt hier
wörtlich: der gespiegelte Teil muss die exakte Spiegelung sein. Es gibt eine
Wortmarke, deren erstes Zeichen das Bildzeichen ist.

**Wo sie bricht.** Gefaltete Buchstaben sind ein bekanntes Muster
(Papierfalt-Schriften, Plakate der 1920er). Ein B mit umgeklappter Ecke wird
schnell ein Eselsohr, also ein Symbol für "Lesezeichen". Und ein B, das nach
der Faltung kein B mehr ist, verletzt Constraint 6. Die Faltlinie muss so
liegen, dass die Lesbarkeit bleibt; das ist eine kleine Menge von Winkeln.

### D. Punkt und Strich (aus der Sprache)

**Idee.** Die Sprache hat zwei Dinge: Punkte (`.a`) und Faltlinien (`--diag`).
Das Zeichen zeigt beide in ihrer Grundbeziehung: ein Punkt, sein Spiegelbild,
die Faltlinie dazwischen. Das ist die erste Faltung, die jeder lernt, und die
Grundfigur jedes Axioms.

**Konstruktion.** Zwei gefüllte Kreise, Radius wie im Renderer (Verhältnis
Punktradius zu Strichstärke 3 zu 2). Dazwischen, exakt auf der
Mittelsenkrechten, ein Liniensegment in Tal-Strich `6 4`; das Segment ist
länger als der Abstand der Punkte. Kein Rahmen. Die Achse des Segments leicht
gedreht (etwa 20 bis 30 Grad), damit es kein Gleichheitszeichen und kein
Divisionssymbol wird. Für 16 Pixel: zwei Punkte, eine durchgezogene Linie.
Die Wortmarke setzt dieselben Sigillen als Typografie ein: `.` und `--` in
Plex Mono sind bereits Zeichen des Projekts und dürfen neben dem Namen stehen.

**Warum sie passt.** Es ist das Zeichen einer Sprache, und das trennt Beloch
von Rabbit Ear und ORIPA, deren Zeichen Papiermodelle meinen. Es ist mit
drei Elementen die reduzierteste Richtung und erfüllt jede Größenvorgabe
ohne zweite Fassung.

**Wo sie bricht.** Ohne Wortmarke sagt es nichts über Origami; es könnte ein
Ladeindikator, Morsecode oder ein Divisionszeichen sein. Es lebt vom Kontext
und braucht die Wortmarke öfter als die anderen drei Richtungen.

## 8. Abnahmekriterien

Prüfliste. Jede Zeile lässt sich ohne Diskussion abhaken.

Größe und Reduktion

- [ ] Bei 16 Pixel, in Graustufen, ist das Zeichen von einem Quadrat, einem
      Kreis, einem Stern und einem Fadenkreuz unterscheidbar.
- [ ] Bei 16 Pixel braucht das Zeichen kein Strichmuster; falls die große
      Fassung eines nutzt, liegt eine Fassung ohne bei.
- [ ] Bei 32 Pixel ist die Faltung (falls das Zeichen eine zeigt) als solche
      erkennbar: Linie und Spiegelung.
- [ ] Bei 24 Pixel Höhe in einer Ecke einer 16:9-Folie neben 18-pt-Text
      stört es den Text nicht und ist noch das Zeichen.
- [ ] Bei 10 mm Breite, 1-Bit Schwarz auf Weiß, ohne Grau, bleibt es lesbar.

Farbe

- [ ] Die Datei enthält weder `#dc2626`, `#2563eb`, `#ff7d5e`, `#6f9bff`,
      `#cf4327`, `#2f5fd0` noch einen anderen Rot- oder Blauton.
- [ ] Auf `#101C2E`, `#171B24`, `#F7F9FB` und Weiß liegt dieselbe Zeichnung;
      nur die Tintenfarbe wechselt.
- [ ] In reinem Schwarz auf Weiß geht keine Information verloren.

Datei

- [ ] SVG, unter 2 KB, höchstens sechs `path`-Elemente, keine `filter`,
      `mask`, `linearGradient`, `radialGradient`, `image` oder `text`.
- [ ] Die Zeichnung sitzt in einem quadratischen `viewBox` (heute
      `0 0 128 128`); nichts liegt außerhalb.
- [ ] Im Kreisbeschnitt (Repo-Avatar) geht nichts Wesentliches verloren.
- [ ] Alle Koordinaten sind konstruiert, nicht gerundet: Schnittpunkte liegen
      auf den Linien, auf denen sie liegen sollen (Prüfung: die Koordinaten
      im SVG zeigen es, oder das Zeichen ist aus einem `.bel`-Programm erzeugt).

Inhalt

- [ ] Kein Kranich, kein Flugzeug, kein Tier, kein Gesicht, keine Ziffer.
- [ ] Keine Perspektive, kein Schatten, kein Verlauf.
- [ ] Falls das Zeichen eine Faltung zeigt: Maekawa und Kawasaki gelten an
      jedem inneren Knoten.
- [ ] Neben `examples/bases/fish-base-cp.svg` gelegt, in derselben Größe,
      wirkt es aus derselben Hand: Strichstärke, Punktradius, Strichmuster
      passen zum Renderer oder weichen bewusst und dokumentiert ab.

Wortmarke und Kombination

- [ ] Die Wortmarke liest sich als "Beloch"; ein Leser ohne Kontext buchstabiert
      sie richtig.
- [ ] Bildzeichen, Wortmarke und Kombination liegen als drei Dateien vor,
      die Kombination enthält die beiden anderen unverändert.
- [ ] Der Bildzeichen-Abstand zur Wortmarke ist als Vielfaches der
      Strichstärke angegeben.

## 9. Liefergegenstände und Formate

Ablageort im Repository: `docs/brand/logo/` (Vorschlag; endgültiger Ort bei
Übergabe klären). Was an anderer Stelle gebraucht wird, steht dabei.

| Gegenstand | Format | Wo es gebraucht wird |
| --- | --- | --- |
| Bildzeichen | `mark.svg`, `fill="currentColor"`, quadratischer viewBox | Basis für alles Weitere |
| Favicon | `favicon.svg` mit `prefers-color-scheme`-Block wie heute; dazu `favicon-32.png`, `apple-touch-icon.png` (180 px) | `packages/www/public/favicon.svg`, verlinkt aus `index.astro` und dem Starlight-Kopf |
| Repo-Avatar | PNG 512 x 512, quadratisch, auf Kreisbeschnitt geprüft | Forgejo `git.toph.so/toph/beloch` (Repo-Avatar); GitHub-Organisation, falls eine entsteht (`tophcodes/beloch` ist heute ein Nutzer-Repo) |
| Wortmarke | `wordmark.svg`, Schrift als Pfad | Site-Header (heute Text in Plex Mono), Paper-Titel, Folien |
| Kombination | `logo.svg` horizontal; `logo-stacked.svg` falls die Richtung es hergibt | Social-Preview, Titelfolie, README-Kopf |
| Social-Preview | PNG 1280 x 640, dunkler Hintergrund `#101C2E`, Kombination plus Tagline "A declarative language for origami, built on the Huzita-Justin axioms." | GitHub Social Preview des Repos; `og:image` der Site (heute nicht gesetzt) |
| Folien-Ecke | PNG 256 px, transparent, je eine Fassung Tinte hell und Tinte dunkel | Ecke jeder Vortragsfolie; Talk-Header mit "The seven axioms, as a language." |
| Papier-Abbildung | PDF, Vektor, einfarbig Schwarz, ohne Transparenz | LaTeX `\includegraphics` im Paper (arXiv, JOSS, OSME); Druckfassung |
| Konstruktionsblatt | eine Seite, SVG oder PDF: die Herleitung jeder Linie, Raster, Winkel, Abstände, Abstand Bildzeichen zu Wortmarke | Wartung und spätere Änderungen |

Falls Richtung B oder D gewählt wird: zusätzlich die `.bel`-Datei, die das
Zeichen erzeugt, unter `examples/`.

## 10. Was wir nicht wissen

Offene Entscheidungen, die den Entwurf beeinflussen können. Der Gestalter darf
Vorschläge machen; er darf sie nicht stillschweigend entscheiden.

- **Die Domain.** Heute `beloch.toph.so`. Der Decision Record zum Namen
  neigt zu `beloch.it`, Rückfall `beloch.dev`. Wer die Wortmarke mit
  Domain-Endung entwirft, entwirft gegen eine offene Entscheidung. Die
  Wortmarke bleibt ohne Endung.
- **Die Aufteilung Sprache und Implementierung.** Der Decision Record hält
  offen, ob die Sprache "Beloch" und die Implementierung "belochc" oder
  "Piazzolla" heißen wird. Falls ja, braucht das Zeichen später ein
  Geschwister. Ein Entwurf, der sich als Familie fortsetzen lässt, hat einen
  Vorteil; verlangt ist es nicht.
- **Die Schrift.** IBM Plex Mono ist heute die Wortmarke, weil sie die Schrift
  des Playgrounds ist. Ob die Wortmarke bei Plex bleibt oder eine eigene
  Zeichnung wird, ist nicht entschieden. Der Brief geht von Plex aus.
- **Die Farb-Tokens.** Renderer (`theme.ts`) und Site (`theme.css`) führen
  verschiedene Werte für Berg und Tal. Ein Abgleich steht aus. Für das Zeichen
  ist das ohne Folge, solange es Rot und Blau meidet.
- **Der Kranich.** Er ist der nächste große Meilenstein und noch nicht
  gefaltet. Das Zeichen darf ihn nicht vorwegnehmen; ob er nach Fertigstellung
  irgendwo im Auftritt erscheint, ist offen.
- **Das Zeichen im Renderer.** Ob das Bildzeichen in den erzeugten Diagrammen
  auftaucht (Legende, Ecke), ist nicht entschieden. Wenn ja, muss es in der
  Strichsprache des Renderers bestehen; Richtung B und D sind darauf
  vorbereitet, A und C nur mit Anpassung.
