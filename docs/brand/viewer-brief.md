# Viewer-Brief: Beloch

Auftrag für die Gestaltung der Fläche, auf der ein Beloch-Programm und seine
Zeichnung zusammen stehen. Der Brief richtet sich an einen Gestalter, Mensch
oder Werkzeug, der das Projekt nicht kennt, und ist ohne Begleitgespräch
benutzbar.

Er gehört zu drei weiteren Dokumenten und widerspricht keinem: die Bedingungen
stehen in `docs/brand/design-language.md`, die Positionierung in
`docs/brand/research/positioning.md`, der gemessene Zustand in
`docs/brand/research/surface-audit.md`. Wo dieser Brief eine Bedingung
wiederholt, nennt er ihre Nummer (B3.1, B2.7 …), damit der Entwurf auf sie
antworten kann. Was im Brief steht und in keiner Bedingung, ist neu und in
Abschnitt 3 und 8 gesammelt.

Zwei Dinge bringt der Brief nicht mit und sie werden gebraucht: die
Kontrastmatrix aus Abschnitt 1.1 der Bedingungen, ohne die sich Abnahmekriterium
9 und die acht Zellen aus Constraint 13 nicht prüfen lassen, und die aktuellen
Tokenwerte, die in `packages/www/src/styles/theme.css` und
`packages/render-2d/render-svg/src/theme.ts` stehen. Der gemessene Zustand in
den Bedingungen ist an mehreren Stellen überholt;
`docs/brand/IMPLEMENTATION.md` sagt, was davon gebaut ist.

Auftrittssprache des Projekts ist Englisch. Dieser Brief ist deutsch, weil er
Arbeitsmaterial ist. Alle Bezeichner, Tokennamen und Pfade stehen im Original.

## 1. Was Beloch ist

Beloch ist eine Programmiersprache, in der ein Programm eine Faltanleitung ist:
jede Zeile ist eine Faltung. Wer ein Blatt beschreibt und dann Zeile für Zeile
sagt, welcher Punkt auf welche Linie gefaltet wird, bekommt zwei Zeichnungen
heraus, das Faltmuster auf dem flachen Blatt und den gefalteten Zustand. Die
erlaubten Operationen sind die sieben Huzita-Justin-Axiome. Gerechnet wird ohne
Rundung: eine Kubikwurzel bleibt eine Kubikwurzel, und die Frage "liegt dieser
Punkt auf dieser Linie" hat eine Antwort und keine Toleranz.

Ein Programm sieht so aus (`examples/bases/fish-base.bel`):

```
paper square

mark (map .a onto .c) as --diag
mark (through .a .c) as --ray

mark (map --ab onto --diag) as --l1
mark (map --da onto --diag) as --l2
flatten (--l1) (--l2) (--ray) (toward .d)
```

Beloch rechnet ausschließlich flache Faltzustände. Das ist eine
Architekturentscheidung mit Begründung und zieht sich durch mehrere Constraints
unten.

## 2. Welche Flächen der Auftrag umfasst

Drei, weil sie denselben Renderer und dieselbe Schrittmechanik benutzen und
auseinanderlaufen, sobald sie getrennt gestaltet werden.

1. **Der Playground**, eigenständig unter `/playground/` und als Hero auf der
   Startseite eingebettet. Die einzige Fläche mit einem Editor.
2. **Die `<Beloch>`-Karte in den Docs.** Dasselbe Bild, kleiner gerahmt, ohne
   Editor: der Quelltext steht links und ist unveränderlich, rechts die
   Zeichnung mit einem Tab-Paar für Faltbild und gefalteten Zustand und einem
   Schrittzähler. Siebzehn Abbildungen in `spec/BELOCH.md` und `spec/MODEL.md`
   hängen daran.
3. **Der Landing-Hero.** Heute der Playground in voller Fensterbreite. Er wird
   in diesem Auftrag eine eigene Aufgabe, siehe Abschnitt 8.

Nicht Teil des Auftrags: die Docs-Navigation, die Typografie des Fließtextes
und das Bildzeichen. Dafür gilt Starlight beziehungsweise `logo-brief.md`.

## 3. Was der Viewer können muss

Dieser Abschnitt stand bisher nirgends, und ohne ihn erfindet ein Entwurf ihn
sich selbst. Vier Aufgaben, alle gleich wichtig.

### 3.1 Eine Faltung lesen und durchsteppen

Ein Leser, der nichts schreibt, muss eine fremde Faltung nachvollziehen können.
Er geht von Schritt 0, dem leeren Blatt, bis zum letzten Schritt, sieht zu jedem
Schritt die Zeichnung und die Programmzeile, die ihn erzeugt hat, und kann
anhalten und zurückgehen. Der Schrittbalken ist die Zeitachse, und derselbe
Index steuert die Zeilenmarkierung im Code (B2.4).

Das gibt es heute. Was der Entwurf dazu beantwortet: wie der Balken bei zwei
Schritten aussieht und wie bei vierzig, und wie er auf einer Karte aussieht, die
halb so breit ist wie der Playground.

### 3.2 Eigenen Code schreiben und laufen lassen

Tippen, laufen lassen, Ergebnis sehen, Fehler an der Zeile sehen, weitertippen.
Der Editor ist vollwertig, mit Zeilennummern und Syntaxfarben.

Das gibt es heute. Was der Entwurf dazu beantwortet: wie ein Fehler erscheint,
ohne die letzte gültige Zeichnung zu löschen (B3.5, heute verletzt), und wie die
Fläche aussieht, solange die 2,3 MB Laufzeit noch laden.

### 3.3 Eine Entität befragen

Auf eine Faltlinie, einen Punkt oder eine Fläche zeigen und erfahren, welche
Anweisung sie erzeugt hat, aus welchen Segmenten sie besteht und was an dieser
Stelle sonst noch liegt. Der gefaltete Zustand legt Faltlinien übereinander, und
an einer Stelle, an der mehrere zusammenfallen, muss der Leser wählen können,
welche er meint.

Das gibt es heute als Tafel, die sich neben die Zeichnung legt. Was der Entwurf
dazu beantwortet: welche Gestalt die Tafel bekommt, ob sie die Zeichnung
verdecken darf (B3.11 sagt: nicht dauerhaft) und wie die Auswahl unter
zusammenfallenden Linien aussieht.

### 3.4 Die Zeichnung herausnehmen

Ein Leser, der die Zeichnung in seinen Vortrag, sein Paper oder sein Issue
holen will, muss sie mitnehmen können. Was er mitnimmt, ist dasselbe SVG, das
der Renderpfad erzeugt, ohne Knopf, Rahmen, Fokusring oder Panelhintergrund,
mit aufgelösten Farben (B3.10, B3.11).

Das gibt es heute nicht. Was der Entwurf dazu beantwortet: welche Form das
annimmt und wo der Auslöser sitzt, ohne die Zeichnung zu verstellen. Ob dazu
auch ein Link gehört, der Programm und Schritt mitbringt, steht in Abschnitt 8.

## 4. Wer davorsitzt

Die erste Zielgruppe sind Origami-Mathematiker, die zweite Leute aus dem
Sprachbau. Beide prüfen Behauptungen an Artefakten, und beide erkennen
Verkaufssprache in einem Satz. Ein Origami-Mathematiker sieht einer Zeichnung
an, ob die Faltung flachfaltbar ist. Er kommt mit einer konkreten Frage, etwa
ob eine bestimmte Konstruktion in dieser Sprache ausdrückbar ist, und er
beantwortet sie, indem er sie tippt.

Daraus folgt die Haltung der Fläche: das Ergebnis führt, die Bedienung tritt
zurück, und nichts behauptet mehr, als die Sprache rechnet.

## 5. Was heute da ist, gemessen

Stand `main`, geprüft am 22.09.2026.

**Aufteilung.** Zwei gleich breite Spalten, Editor links, Ausgabe rechts. Der
Umbruch liegt bei 720 px, und darunter steht der Editor oben. Der Hero ist
380 px hoch, eine eingebettete Karte 320 px.

**Bedienelemente.** Ein runder Laufknopf mit 44 px, vier Papier-Swatches mit
22 px in einer Leiste über der Zeichnung, ein Schrittbalken aus Punkten mit
zwei Pfeilknöpfen und einer Beschriftung, ein Reset-Knopf, der beim Überfahren
der Zeichenfläche erscheint, und die Inspektor-Tafel. Der Zustand der Laufzeit
steht in einer Zeile mit `role="status"`, die "loading runtime (2.3 MB) …"
sagt.

**Farben.** Drei Token-Schichten: `--bel-paper-*` für alles, was im Artefakt
liegt, `--bel-ui-*` für die Oberfläche, `--bel-syntax-*` für die zehn
Tokenfarben des Codes. Hell ist der Bezugsmodus, und jede Oberflächenrolle
trägt beide Werte in einer `light-dark()`-Deklaration. Die Codefläche bleibt in
beiden Modi dunkel (`#101C2E`), und die Rollen, die auf ihr landen, haben einen
festen Wert statt zweier.

**Bewegung.** Ein Schrittwechsel blendet die zwei flachen Zustände über
einander. Sonst bewegt sich nichts. Drei Dauertokens, ein Easing ohne
Überschwingen, und eine einzige `prefers-reduced-motion`-Regel schaltet alles
ab.

**Offene Befunde.** Aus `surface-audit.md` Abschnitt 3 und aus eigener Messung:

- Ein Fehler schreibt in dieselbe Fläche wie die Zeichnung und löscht sie
  (B3.5).
- Es gibt keinen Tastaturweg zu dem, was die Fläche kann: die Zeichenfläche ist
  nicht fokussierbar, Pan und Zoom sind nur mit dem Zeiger erreichbar, die
  Trefferflächen der Faltlinien sind nicht erreichbar (Abschnitt 8.3 der
  Bedingungen).
- Die Ausgabefläche fängt das Seitenscrollen: `preventDefault` auf jedem
  Radereignis und `touch-action: none` (B3.8).
- `--bel-ui-border` trägt Trennlinie und Bedienelement-Kontur in einer Rolle
  und liegt bei 1,28:1 hell und 1,31:1 dunkel, wo eine Kontur 3:1 braucht
  (B6.5).
- `--bel-ui-text-faint` ist deklariert und wird nirgends benutzt.
- Die Übergänge der Bedienelemente stehen als hartkodierte 0,15 s im Bauteil
  statt als `--bel-duration-state`.
- Die Statuszeile nennt die Größe der Laufzeit, zeigt aber keinen Fortschritt
  (B2.12).

## 6. Harte Constraints

Jede Vorgabe mit dem Grund. Wer eine davon verletzt, liefert kein Ergebnis.

1. **Code und Zeichnung stehen gleichzeitig da, ohne Klick und ohne Scrollen**
   (B3.1). Ein Screenshot bei 1280 mal 800 enthält beides vollständig. Aus der
   Landschaftsanalyse: TikZ setzt Bild und Quelltext schon im ersten Absatz
   seiner Dokumentation nebeneinander, und das ist das stärkste beobachtete
   Muster für Projekte, deren Ergebnis eine Zeichnung ist. Penrose legt seine
   Diagramme hinter einen Klick, und das ist im selben Material das
   Gegenbeispiel.
2. **Die Zeichnung bekommt mindestens so viel Fläche wie der Editor** (B3.2).
   Ab 1000 px Viewportbreite mindestens die halbe Kartenbreite, und die kürzere
   Kante der Zeichnung nie unter 320 px.
3. **Keine Fensterdekoration** (B3.4). Kein nachgebauter Browserrahmen, keine
   Ampelknöpfe, keine Titelleiste über dem Quelltext. Ein Dateiname erscheint
   als Kommentarzeile in der Sprache selbst.
4. **Ein Fehler ersetzt die Zeichnung nicht** (B3.5). Die letzte gültige
   Zeichnung bleibt stehen, die Diagnose erscheint daneben und markiert die
   Zeile. Die Fehlerfläche trägt `role="alert"` und wird nicht geleert, bevor
   die Meldung gesetzt ist, weil ein geleerter Bereich sonst als Meldung
   vorgelesen wird.
5. **Unter dem Umbruchpunkt liegt die Zeichnung über dem Code** (B3.7). Bei
   390 px Breite liegt sie vollständig im ersten Bildschirm, und am unteren
   Rand ist angeschnittener Inhalt sichtbar, damit klar ist, dass es weitergeht
   (B3.9).
6. **Die Zeichnung fängt die Seitengeste nicht ab** (B3.8). Wischen über der
   Zeichnung scrollt die Seite. Zoom braucht einen eigenen Auslöser:
   Modifikatortaste, Fokus oder ein Klick in die Fläche.
7. **Alles, was die Fläche kann, geht mit der Tastatur.** Die Zeichenfläche ist
   fokussierbar, Pan und Zoom sind über Tasten bedienbar, und die
   Trefferflächen der Faltlinien sind erreichbar. Der Laufknopf ist im
   Ruhezustand nicht ohne sichtbare Begründung abgeschaltet.
8. **Die Zeichnung ist ohne Chrome exportierbar** (B3.10, B3.11). Was in der
   Fläche liegt, ist dasselbe SVG, das der Renderpfad erzeugt. Reset-Knopf,
   Schrittleiste und Papierauswahl sind im Export nicht enthalten, und kein
   Bedienelement verdeckt die Zeichnung dauerhaft.
9. **Bewegung hat genau zwei erlaubte Bedeutungen** (B2.1): sie zeigt einen
   Faltvorgang oder einen Wechsel der Ansicht auf dasselbe Artefakt. Sie
   startet nur auf eine Handlung hin, nie beim Laden und nie beim Scrollen
   (B2.2). Es gibt drei Dauerbereiche und keinen vierten: Zustandswechsel 120
   bis 200 ms, Ansichtswechsel 200 bis 400 ms, ein Faltvorgang höchstens
   600 ms (B2.9). Ein Easing-Paar für alles, ohne Überschwingen: Papier federt
   nicht (B2.11). Bei `prefers-reduced-motion` entfällt jede Bewegung, und die
   Abschaltung steht an einer Stelle statt pro Bauteil (B2.7, B2.8).
10. **Keine Bewegung behauptet Geometrie, die die Sprache nicht rechnet**
    (B2.3). Beloch kennt nur flache Faltzustände. Ein Zwischenbild, das Papier
    schräg im Raum zeigt, behauptet ein 3D-Modell. Jedes Einzelbild ist
    entweder ein flacher Zustand, den der Evaluator ausgibt, oder eine
    Überblendung zwischen zwei solchen.
11. **Farben kommen aus den drei Token-Schichten, und der Entwurf führt keine
    neue ein** (B1.8). Rot heißt Berg und Blau heißt Tal: keine Faltfarbe trägt
    je einen Bedienzustand (B1.6). Die Codefläche bleibt in beiden Modi dunkel,
    und die Rollen, die auf ihr liegen, haben deshalb einen Wert statt zweier.
12. **Hell ist der Bezugsmodus** (B6.1). Der Entwurf zeigt zuerst die helle
    Fassung, und die dunkle ist die abgeleitete. Beide halten dieselben
    Schwellen: 4,5:1 für Text, 3:1 für große Schrift und für die Konturen von
    Bedienelementen (B6.5). Geometrie, Raster und Strichstärken sind in beiden
    identisch; es unterscheiden sich ausschließlich Farbwerte (B6.4).
13. **Eine Kombination aus Papier und Strichstil, die den Kontrast nicht hält,
    ist nicht erreichbar** (B1.4). Auf Kraft und Indigo fällt jede Faltfarbe
    unter 2:1. Der Entwurf belegt alle acht Zellen, vier Papiere mal zwei
    Strichstile, mit "erfüllt" oder "nicht angeboten".

## 7. Verbotene Muster

Jeder Punkt mit einem Satz Begründung.

- **Kein Ergebnis hinter einem Klick, einem Tab oder einem Akkordeon**, das es
  im Ruhezustand versteckt. Die Zeichnung ist das, wofür jemand die Seite
  öffnet.
- **Keine nachgebaute Anwendungsoberfläche.** Kein Fensterrahmen, keine
  Menüleiste, keine Statusleiste am unteren Rand, kein Seitenbereich mit
  Dateibaum. Die Fläche ist eine Karte auf einer Seite.
- **Keine Perspektive, keine Verkürzung, keine gebogene Papierkante.** Siehe
  Constraint 10.
- **Keine Dekoration, die sich bewegt.** Kein Einblenden beim Scrollen, kein
  pulsierender Hinweis, kein Kreisel ohne Gegenstand.
- **Keine Illustration an der Stelle einer erzeugten Zeichnung** (B3.6). Jede
  Zeichnung im Auftritt stammt aus einem `.bel`-Programm oder ist als Schema
  gekennzeichnet.
- **Kein Rot und kein Blau für Bedienzustände.** Verboten sind `#dc2626`,
  `#2563eb` und jeder Ton, der in Graustufen mit ihnen verwechselbar wäre.
- **Keine Werkzeugleiste, die über der Zeichnung liegt** und sie dauerhaft
  verdeckt (B3.11).
- **Kein zweiter Zeichensatz für Symbole.** Was ein Icon sein muss, ist ein
  Pfad im selben Stil wie die vorhandenen (Reset, Pfeile, Laufknopf).

## 8. Was der Entwurf entscheiden soll

Sieben offene Punkte. Zu jedem steht, was daran hängt.

1. **Faltbild und gefalteter Zustand: Umschalter oder nebeneinander.** Der
   Umschalter kostet keine Breite und zwingt den Leser, zwischen zwei Bildern zu
   erinnern. Nebeneinander macht den Vergleich möglich, halbiert aber die
   Fläche pro Bild und kollidiert mit Constraint 2, sobald der Editor daneben
   steht. Eine dritte Möglichkeit ist, dass die beiden Flächen sich
   unterschiedlich verhalten: die Docs-Karte hat keinen Editor und damit Platz.
2. **Ein Umschalter für den Strichstil.** Der monochrome
   Yoshizawa-Randlett-Stil trägt Berg gegen Tal über das Strichmuster und ist
   das, was ein gedrucktes Faltdiagramm benutzt. Der farbige Stil ist schneller
   zu lesen und auf Kraft und Indigo nicht anbietbar. `colorOk` in
   `paper-schemes.ts` sagt heute schon, welches Papier welchen Stil verträgt,
   und nichts bietet ihn an. Wenn der Umschalter kommt, muss der Entwurf
   zeigen, wie eine nicht angebotene Kombination aussieht, ohne wie ein Defekt
   zu wirken.
3. **Welche Form Export und Teilen bekommen.** Mindestens das SVG. Offen ist,
   ob ein Link dazugehört, der Programm und Schritt mitbringt, und wo der
   Auslöser sitzt, ohne Constraint 8 zu verletzen.
4. **Die Gestalt des Inspektors.** Tafel neben der Zeichnung, Bereich unter ihr
   oder etwas, das an der befragten Stelle hängt. Dazu: wie die Auswahl unter
   zusammenfallenden Faltlinien aussieht.
5. **Der Landing-Hero.** Er bekommt eine eigene Aufgabe statt des Playgrounds
   in voller Breite. Er muss dieselbe Sprache sprechen wie der Viewer und darf
   ein eigenes Layout haben (Abschnitt 8.1 der Bedingungen), aber kein Token
   definieren, das die Docs nicht haben. Constraint 1 gilt auch für ihn.
6. **`--bel-ui-border` als zwei Rollen.** Eine Trennlinie zwischen Bereichen
   braucht keinen Kontrast, eine Bedienelement-Kontur braucht 3:1. Der Entwurf
   nennt beide Rollen und beide Wertepaare.
7. **Ob `--bel-ui-text-faint` bleibt.** Entweder der Entwurf benutzt die Rolle
   und sagt wofür, oder sie fällt weg.

## 9. Abnahmekriterien

Prüfbar, in dieser Reihenfolge.

1. Screenshot bei 1280 mal 800: Quelltext und Zeichnung vollständig, die
   Zeichnung mindestens halb so breit wie die Karte, kürzere Kante über 320 px.
2. Screenshot bei 390 px: die Zeichnung vollständig im ersten Bildschirm, der
   Editor darunter, am unteren Rand angeschnittener Inhalt.
3. Tippfehler in eine laufende Zeile: die letzte gültige Zeichnung steht noch
   da, die Diagnose daneben, die Zeile markiert.
4. Tastaturdurchlauf ohne Maus: Editor, Laufknopf, Papierauswahl, Schrittbalken,
   Zeichenfläche, eine Faltlinie und der Inspektor sind erreichbar, und jeder
   Fokus ist sichtbar.
5. Über der Zeichnung scrollen: die Seite scrollt. Zoomen verlangt den eigenen
   Auslöser.
6. `prefers-reduced-motion` gesetzt, jede Fläche aufgerufen: null laufende
   Animationen, und jede Information weiterhin erreichbar.
7. Export einer Zeichnung, geöffnet ohne die Seiten-CSS: kein Knopf, kein
   Rahmen, kein Fokusring, kein Panelhintergrund, alle Farben aufgelöst.
8. Beide Modi nebeneinandergelegt: es unterscheiden sich ausschließlich
   Farbwerte, keine Kante verschiebt sich.
9. Die Kontrastmatrix neu gerechnet mit den Werten des Entwurfs: keine
   Textfarbe unter 4,5:1, keine Bedienelement-Kontur unter 3:1, keine
   Linienfarbe unter 3:1 gegen ihr Papier.
10. Die Liste aller Dauerwerte des Entwurfs: jeder liegt in einem der drei
    Bereiche aus Constraint 9.

## 10. Liefergegenstände und Formate

1. **Die helle Fassung zuerst**, als annotiertes Layout bei 1280 und bei 390 px,
   für den Playground und für die Docs-Karte. Die dunkle Fassung als Ableitung,
   mit der Regel, nach der sie abgeleitet ist.
2. **Die Zustände.** Leer vor dem ersten Lauf, ladende Laufzeit, Ergebnis,
   Fehler, ausgewählte Entität, Tastaturfokus auf der Zeichenfläche.
3. **Ein Inventar der Bedienelemente**, jedes mit seiner Rolle, seinen Tokens
   und seinen Zuständen (Ruhe, Überfahren, Fokus, Aktiv, Abgeschaltet).
4. **Die Tabelle der acht Zellen** aus Constraint 13, jede mit "erfüllt" oder
   "nicht angeboten".
5. **Die Antworten auf Abschnitt 8**, jede mit einem Satz Begründung.
6. **Der Landing-Hero** als eigener Entwurf, hell und dunkel.

Formate: was sich als Bild zeigen lässt, als SVG oder PNG bei mindestens
zweifacher Auflösung; die Entscheidungen und die Tabellen als Markdown, damit
sie in dieses Verzeichnis wandern können.

## 11. Was wir nicht wissen

- Wie viele Schritte eine typische Faltung hat, die jemand in den Playground
  tippt. Die Beispiele im Repository liegen zwischen zwei und etwa zwanzig, die
  Abbildungen in der Spezifikation meist unter fünf.
- Ob Leser die Papierauswahl benutzen oder ob sie auf Weiß bleiben.
- Ob der Inspektor gebraucht wird oder ob er eine Antwort auf eine Frage ist,
  die niemand stellt.
- Wie sich die Fläche verhält, wenn die Sprache einmal mehr als flache
  Faltzustände rechnet. Heute tut sie es nicht, und der Entwurf soll nichts
  offenhalten, was diese Annahme kostet.
