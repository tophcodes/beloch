# Bedingungen für eine Designsprache: Beloch

## Wie dieses Dokument zu benutzen ist

Dieses Dokument listet die Bedingungen auf, die ein Entwurf erfüllen muss, damit
er für Beloch trägt. Es enthält selbst keine Gestaltung: keine Palette, kein
Raster, kein Layout. Jede Bedingung ist so
formuliert, dass man einem fertigen Entwurf ansehen kann, ob er sie hält. Wo
eine Bedingung aus einer technischen Tatsache im Repository folgt, steht die
Datei daneben.

Das Dokument ist als Briefing gedacht und ohne Begleitgespräch benutzbar. Es
gehört zu zwei weiteren Dokumenten und widerspricht keinem: die Positionierung
und Tonalität liegen in `docs/brand/research/positioning.md`, der Auftrag für
Bildzeichen und Wortmarke in `docs/brand/logo-brief.md`. Der Zustand, gegen den
die Bedingungen geschrieben sind, steht in
`docs/brand/research/surface-audit.md` und
`docs/brand/research/landscape.md`.

Die Bedingungen sind durchnummeriert (B1.1, B1.2 …), damit ein Entwurf auf sie
antworten kann. Wo ein Wert heute im Repository steht, ist er genannt, und der
Entwurf darf ihn ändern. Wo eine Zahl als Schwelle steht, darf er sie nicht
unterschreiten.

Auftrittssprache des Projekts ist Englisch. Dieses Dokument ist deutsch, weil es
Arbeitsmaterial ist. Alle Bezeichner, Tokennamen und Beispielformulierungen
stehen im Original.

Stand der Quellen: `origin/main` bei `f69217fe`, geprüft am 21.09.2026.

## Was Beloch ist

Beloch ist eine deklarative Sprache für Origami. Ein Programm ist eine
Faltfolge: eine Zeile ist eine Faltung. Die erlaubten Operationen sind die
sieben Huzita-Justin-Axiome. Der Evaluator rechnet über exakte
reell-algebraische Zahlen, ohne Rundung und ohne Toleranz, und gibt zwei
Zeichnungen aus, das Faltmuster auf dem flachen Blatt und den gefalteten
Zustand, beide als FOLD-Datei und als SVG.

Ein Programm sieht so aus (`examples/bases/fish-base.bel`, zwölf Zeilen, daraus
entstehen `fish-base-cp.svg` und `fish-base-folded.svg`):

```
paper square

mark (map .a onto .c) as --diag
mark (through .a .c) as --ray

mark (map --ab onto --diag) as --l1
mark (map --da onto --diag) as --l2
flatten (--l1) (--l2) (--ray) (toward .d)
```

Das Projekt tritt als Forschungsartefakt auf, das benutzbar ist. Spezifikation,
Decision Records und ein Browser-Playground liegen offen. Die erste Zielgruppe
sind Origami-Mathematiker, die zweite Leute aus dem Sprachbau. Beide prüfen
Behauptungen an Artefakten, und beide erkennen Verkaufssprache in einem Satz.

Beloch rechnet ausschließlich flache Faltzustände. Das ist eine
Architekturentscheidung mit Begründung und zieht sich durch mehrere
Bedingungen unten.

## Die sechs Oberflächen, die eine Gestaltung tragen muss

Landing, Referenzdocs, Playground, VS-Code-Extension, Abbildungen im Paper,
Konferenzfolien. Abschnitt 8 sagt pro Oberfläche, was übertragbar ist.

---

# 1. Farbe trägt Bedeutung

Berg und Tal sind Inhalt. Wer in einer Beloch-Zeichnung Rot sieht, liest
"Bergfalte", wer Blau sieht, liest "Talfalte". Diese Zuordnung ist kein
Geschmack und steht nicht zur Gestaltung frei.

## 1.1 Der heutige Zustand, gemessen

Zwei Systeme laufen auseinander. Die Render-Engine
(`packages/render-2d/render-svg/src/theme.ts`) setzt `mountain: "#dc2626"`,
`valley: "#2563eb"`, `boundary: "#1f2937"`, `flat: "#94a3b8"`,
`unassigned: "#f59e0b"`, `construction: "#6366f1"`, `ink: "#0f172a"`,
`paperFill: "#f8fafc"`. Die Web-Tokens
(`packages/www/src/styles/theme.css`) setzen für dieselben Bedeutungen andere
Werte: dunkel `--beloch-mountain: #ff7d5e`, `--beloch-valley: #6f9bff`, hell
`#cf4327` und `#2f5fd0`. Der Abstand zwischen Engine und Dunkelmodus beträgt
ΔE76 28,4 (Berg) und 32,2 (Tal), zwischen Engine und Hellmodus 13,2 und 13,0.

Dazu vier Papier-Schemata (`packages/www/src/lib/paper-schemes.ts`), die zur
Laufzeit `--bel-paper-cp`, `--bel-paper-front`, `--bel-paper-back` und bei
dunklem Papier auch `--bel-ink` und `--bel-boundary` auf `documentElement`
umschreiben: White, Kraft, Washi, Indigo.

Und zwei Strichstile in `theme.ts`: `colorLineStyle` färbt nach Zuweisung,
`yrLineStyle` ist einfarbig und unterscheidet Berg und Tal über das
Strichmuster (Rand durchgezogen Stärke 3, Berg Strich-Punkt `8 2 1 2`, Tal
gestrichelt `6 4`, unbewegt fein gepunktet `1 3`). `yrLineStyle` ist der
Standard in `DEFAULT_THEME`.

Kontrastwerte nach WCAG 2.1, berechnet aus den Werten dieser drei Dateien:

| Linienfarbe | cp white `#f8fafc` | kraft front `#b8926a` | kraft back `#8f6f4e` | washi `#f2ead6` | indigo `#3b4a6b` | panel dark `#171B24` | panel light `#F7F9FB` |
|---|---|---|---|---|---|---|---|
| mountain `#dc2626` | 4,62 | 1,69 | 1,05 | 4,03 | 1,83 | 3,57 | 4,58 |
| valley `#2563eb` | 4,94 | 1,81 | 1,12 | 4,31 | 1,71 | 3,33 | 4,90 |
| ink `#0f172a` | 17,06 | 6,25 | 3,87 | 14,89 | 2,02 | 1,04 | 16,92 |
| flat `#94a3b8` | 2,45 | 1,11 | 1,80 | 2,14 | 3,44 | 6,72 | 2,43 |
| unassigned `#f59e0b` | 2,05 | 1,33 | 2,15 | 1,79 | 4,11 | 8,02 | 2,03 |
| web-dark mountain `#ff7d5e` | 2,40 | 1,13 | 1,83 | 2,10 | 3,51 | 6,85 | 2,38 |
| web-dark valley `#6f9bff` | 2,57 | 1,06 | 1,72 | 2,24 | 3,28 | 6,41 | 2,55 |
| web-light mountain `#cf4327` | 4,47 | 1,64 | 1,01 | 3,91 | 1,89 | 3,68 | 4,44 |
| web-light valley `#2f5fd0` | 5,47 | 2,01 | 1,24 | 4,77 | 1,54 | 3,01 | 5,42 |

Zwei Befunde aus dieser Tabelle tragen die Bedingungen unten. Auf Kraft und
Indigo fällt jede Faltlinienfarbe unter 2:1 und verschwindet. Und in Graustufen
liegen Berg und Tal bei L\* 47,9 gegen 46,1, ein Abstand von 1,8, der im Druck
nicht mehr unterscheidbar ist.

## 1.2 Semantische Farben

Semantisch sind die Rollen, deren Farbe eine Aussage über das Papier macht:
Bergfalte, Talfalte, Papierrand, unbewegte Faltlinie, nicht zugewiesene
Faltlinie, Konstruktionslinie, Papiervorderseite, Papierrückseite, Papierfläche
im Faltmuster, Tinte, sowie die sechs Hervorhebungsfarben aus
`HIGHLIGHT_PALETTE`, deren Aussage lautet: dieses Wort in der Bildunterschrift
meint dieses Ding in der Zeichnung.

**B1.1** Es gibt genau eine Liste semantischer Rollen, an genau einer Stelle
definiert, und jede Oberfläche leitet ihre Werte daraus ab.
*Prüfung:* Der Entwurf nennt für jede Rolle genau einen Namen und genau einen
Wert pro Modus. Zwei Listen mit denselben Rollen und verschiedenen Werten sind
ein Fehlschlag.

**B1.2** Keine semantische Unterscheidung ruht allein auf Farbe. Berg und Tal
tragen zusätzlich ein Strichmuster, ein Symbol oder eine Strichstärke.
*Prüfung:* Ein Export der Zeichnung in Graustufen, mit allen Farbkanälen
entsättigt. Berg und Tal bleiben unterscheidbar. Heute scheitert
`colorLineStyle` daran (L\* 47,9 gegen 46,1) und `yrLineStyle` besteht.

**B1.3** Jede Linienfarbe hält mindestens 3:1 gegen jedes Papier, auf dem sie
erscheinen kann (WCAG 2.1 SC 1.4.11, Nicht-Text-Kontrast).
*Prüfung:* Die Matrix aus Abschnitt 1.1, neu gerechnet mit den Werten des
Entwurfs. Keine Zelle unter 3,0.

**B1.4** Wo B1.3 für eine Kombination aus Papier und Strichstil nicht erfüllbar
ist, wird die Kombination nicht angeboten. Der Entwurf belegt alle acht Zellen
(vier Papiere mal zwei Strichstile) mit "erfüllt" oder "nicht angeboten".
*Prüfung:* Die Tabelle existiert und hat acht Zellen. Eine Oberfläche, die eine
nicht angebotene Kombination erreichbar macht, ist ein Fehlschlag.

**B1.5** Berg und Tal bleiben bei Protanopie und Deuteranopie unterscheidbar.
*Prüfung:* Simulation nach Viénot, beide Farben simuliert, ΔE76 zwischen den
Simulationen mindestens 20. Heute erfüllt: `#dc2626` simuliert zu `#82820c`,
`#2563eb` zu `#5656eb`. Fällt der Wert darunter, muss B1.2 die Last allein
tragen, und dann ist der Farbstil kein eigenständiger Stil mehr.

**B1.6** Eine semantische Farbe darf nirgends eine andere Bedeutung annehmen.
Kein Bedienzustand, keine Fläche und kein Icon benutzt eine Faltfarbe für etwas,
das keine Faltrichtung ist.
*Prüfung:* Suche nach den Faltfarben-Tokens außerhalb der Zeichnung. Heute
verletzt: `--beloch-valley` trägt den aktiven Tab, den Fokusring des
Papier-Swatch, die Schrittmarkierung im Editor-Gutter und die
Hervorhebung `.pg-hl`; `--beloch-mountain` trägt Fehlertext und fehlgeschlagene
Zusicherungen (`packages/www/src/styles/theme.css`,
`packages/www/src/components/Playground.astro`). Die Auflösung ist eine
Entscheidung, siehe Abschnitt 10.

**B1.7** Chrome-Farben halten Abstand zu semantischen Farben, auch nach
Entsättigung und nach CVD-Simulation.
*Prüfung:* ΔE76 mindestens 25 zwischen jeder Chrome-Farbe und jeder semantischen
Farbe, und keine Chrome-Farbe liegt in der Hue-Familie einer semantischen.
Heute grenzwertig: der Dunkelmodus-Wert für Berg `#ff7d5e` liegt im selben
Orange wie die Engine-Farbe für `unassigned` `#f59e0b` (ΔE76 42,8, gleiche
Hue-Familie), also bedeutet Orange auf zwei Oberflächen zwei verschiedene
Dinge.

## 1.3 Chrome-Farben

Chrome ist alles, was nicht auf dem Papier liegt: Panelflächen, Rahmen,
Fließtext, gedämpfter Text, Akzent, Fokus, Zustände, Codepanel-Hintergrund,
Syntaxfarben.

**B1.8** Chrome ist gestaltbar, und die Liste der Rollen ist geschlossen. Der
Entwurf nennt sie vollständig, und jede Rolle hat einen Wert für hell und einen
für dunkel.
*Prüfung:* Kein Bauteil führt eine Farbe ein, die in der Liste nicht steht.

**B1.9** Jede Syntaxfarbe hält 4,5:1 gegen die Codefläche, und jedes Paar
Syntaxfarben hält ΔE76 mindestens 15 zueinander, oder zwei Rollen teilen
ausdrücklich eine Farbe und das steht in der Definition.
*Prüfung:* Vollständige Paarmatrix. Heute erfüllt der Kontrast (Minimum 4,79
für `.bel-punct` und `.bel-comment` auf `#101C2E`) und scheitert die
Unterscheidbarkeit: von 231 Paaren liegen 18 unter ΔE76 15, das engste Paar ist
`.bel-construction #8FA6D9` gegen `.bel-alignment #7C93C4` bei 7,2.

**B1.10** Die sechs Hervorhebungsfarben behalten ihre drei Eigenschaften: L\*
zwischen 49 und 56, ΔE76 mindestens 19 gegen jede andere Farbe des Projekts,
ΔE76 mindestens 50 untereinander. Diese Werte stehen heute als Begründung im
Quelltext (`theme.ts`, `HIGHLIGHT_PALETTE`) und sind der Grund, warum dieselbe
Farbe auf Papier, im Hellmodus und im Dunkelmodus trägt.
*Prüfung:* Die drei Zahlen neu gerechnet für die Palette des Entwurfs.

## 1.4 Die vier Kontexte gleichzeitig

**B1.11** Dunkles Web, helles Web, farbige Papiere und monochromer Druck sind
vier Prüfungen desselben Entwurfs, nicht vier Entwürfe.
*Prüfung:* Dieselbe Zeichnung, viermal gerendert, ohne dass eine Zeile Geometrie
sich ändert.

**B1.12** Das Papier ist vom Modus unabhängig. Ein weißes Papier bleibt weiß,
wenn die Oberfläche auf Dunkel steht.
*Prüfung:* Papier-Schema White, Modus dunkel: `--bel-paper-cp` hat denselben
Wert wie im Hellmodus. Heute erfüllt, weil `applyScheme` auf
`documentElement` schreibt und `data-theme` nicht liest
(`packages/www/src/lib/paper-schemes.ts`).

**B1.13** Ein Papier-Schema setzt Tinte und Rand gemeinsam oder keines von
beiden.
*Prüfung:* `schemeVars` liefert `--bel-ink` und `--bel-boundary` immer als Paar,
entweder mit Wert oder als `null`. Ein Schema mit Tinte ohne Rand ist ein
Fehlschlag.

**B1.14** Der monochrome Fall ist der Bezugsfall für Abbildungen. Eine
Abbildung, die einfarbig nicht mehr lesbar ist, wird nicht gedruckt.
*Prüfung:* SVG in 1-Bit Schwarz auf Weiß gerastert, auf 78 mm Breite (einspaltige
Abbildung im Springer-Satz). Rand, Berg, Tal und Konstruktionslinie sind
auseinanderzuhalten.

**B1.15** Der headless Renderpfad löst keine CSS-Variablen auf. Jede Farbe, die
er braucht, liegt als Literal im TypeScript-Theme.
*Prüfung:* Kein `var(` in einem SVG, das ohne Browser entsteht. Der Grund steht
im Quelltext (`theme.ts`: resvg resolves no `var()`), und er ist der harte Grund
für die Tokenordnung in Abschnitt 7.

---

# 2. Bewegung

Rabbit Ear erzeugt seine Reifewirkung über Animation, die den Faltvorgang zeigt.
Beloch steht heute still. `prefers-reduced-motion` kommt auf `origin/main` in
`packages/` nirgends vor (`git grep`, null Treffer), der Ladeindikator im
Playground dreht ungefragt, und `:target` in `theme.css` blendet drei Sekunden
lang.

## 2.1 Wann sich etwas bewegen darf

**B2.1** Bewegung hat genau zwei erlaubte Bedeutungen: sie zeigt einen
Faltvorgang (den Übergang von Zustand n nach n+1), oder sie zeigt einen Wechsel
der Ansicht auf dasselbe Artefakt (Faltmuster gegen gefalteten Zustand, Schritt
gegen Schritt, Zoom, Verschieben). Alles andere bewegt sich nicht.
*Prüfung:* Zu jeder Animation im Entwurf lässt sich der Satz "diese Bewegung
zeigt den Übergang von X nach Y" mit X und Y als benannten Zuständen des
Programms ausfüllen. Bleibt der Satz leer, ist die Animation Dekoration und
fällt weg.

**B2.2** Bewegung startet nur auf eine Handlung hin. Kein Autoplay beim Laden,
keine scrollgesteuerte Animation, kein Einblenden von Abschnitten.
*Prüfung:* Seite laden, nichts anfassen. Nach einer Sekunde bewegt sich nichts.

**B2.3** Bewegung darf keine Geometrie behaupten, die die Sprache nicht rechnet.
Beloch kennt nur flache Faltzustände. Ein Zwischenbild, das Papier schräg im
Raum zeigt, behauptet ein 3D-Modell.
*Prüfung:* Jedes Einzelbild einer Faltbewegung ist entweder ein flacher Zustand,
den der Evaluator ausgibt, oder eine Überblendung zwischen zwei solchen
Zuständen ohne eigene Geometrie. Perspektive, Verkürzung oder eine Biegung im
Zwischenbild sind ein Fehlschlag.

**B2.4** Der Schrittbalken ist die Zeitachse. Jede Faltbewegung hängt an einem
Schrittindex, und derselbe Index steuert die Zeilenmarkierung im Code.
*Prüfung:* Zu jedem Bild der Bewegung lassen sich der Schrittindex und die
Programmzeile benennen. Eine Bewegung ohne Schrittindex ist keine Faltung.

## 2.2 Standbild

**B2.5** Jede Animation hat einen lesbaren Standbildzustand. Paper und Folien
brauchen Standbilder, und sie bekommen sie aus derselben Quelle.
*Prüfung:* An jedem Schrittindex lässt sich ein SVG exportieren, das ohne
Vorgeschichte lesbar ist. Eine Bewegung, deren Aussage erst im Verlauf entsteht,
ist ein Fehlschlag.

**B2.6** Keine Information existiert ausschließlich in der Bewegung. Was ein
Übergang zeigt, steht auch als Zustand da.
*Prüfung:* Bewegung abschalten, dieselbe Aufgabe lösen. Nichts fehlt.

## 2.3 Reduzierte Bewegung

**B2.7** Bei `prefers-reduced-motion: reduce` entfällt jede Bewegung, die nicht
selbst der Inhalt ist. Übergänge werden zu Sprüngen, Ladeindikatoren zu Text,
Einblendungen zu sofortiger Sichtbarkeit.
*Prüfung:* Einstellung setzen, jede Oberfläche aufrufen: null laufende
Animationen, und jede Information weiterhin erreichbar. Die Ausnahme ist eine
Faltanimation, die der Nutzer ausdrücklich gestartet hat; auch sie beginnt in
diesem Modus im Standbild.

**B2.8** Die Regel steht an einer Stelle und nicht pro Bauteil.
*Prüfung:* Eine einzige Media-Query trägt die Abschaltung; kein Bauteil hat eine
eigene Fassung.

## 2.4 Dauer und Easing

**B2.9** Drei Dauerbereiche, mehr nicht:
Zustandswechsel der Oberfläche (Hover, Fokus, Panel auf oder zu) 120 bis 200 ms;
Ansichtswechsel am Artefakt (Faltmuster gegen gefaltet, Schritt gegen Schritt)
200 bis 400 ms; ein einzelner Faltvorgang höchstens 600 ms.
*Prüfung:* Liste aller Dauerwerte im Entwurf. Jeder liegt in einem der drei
Bereiche. Heute liegen die Übergänge bei 0,15 s (`Playground.astro`) und die
`:target`-Blende bei 3 s (`theme.css`), die letzte fällt aus dem Rahmen.

**B2.10** Eine Sequenz über mehrere Schritte ist unterbrechbar und an jeder
Stelle anhaltbar.
*Prüfung:* Während des Ablaufs auf einen Schritt klicken: die Sequenz hält dort
an, und die Zeichnung zeigt diesen Schritt.

**B2.11** Ein Easing-Paar für alles, ohne Überschwingen. Papier federt nicht.
*Prüfung:* Kein `cubic-bezier` mit einem Kontrollpunkt außerhalb von 0 bis 1,
kein `bounce`, kein `elastic`, kein `spring` mit Überschwingen.

**B2.12** Endlose Bewegung gibt es nur als Ladeindikator, und der Ladeindikator
nennt, worauf er wartet.
*Prüfung:* Der Indikator zeigt einen Text mit dem Gegenstand und, wo die Größe
bekannt ist, dem Fortschritt. Die Laufzeitdatei im Playground ist 2,27 MB
komprimiert; ein Kreisel ohne Angabe ist ein Fehlschlag.

---

# 3. Das Artefakt ist der Held

Aus der Landschaftsanalyse: TikZ setzt Bild und Quelltext nebeneinander, schon
im ersten Absatz seiner Dokumentation, und das ist das stärkste beobachtete
Muster für Projekte, deren Ergebnis eine Zeichnung ist. Penrose legt seine
Diagramme hinter einen Klick, und das ist im selben Material das Gegenbeispiel.

## 3.1 Code und Zeichnung

**B3.1** Jede Fläche, die Beloch-Code zeigt, zeigt dessen Ergebnis daneben, ohne
Klick und ohne Scrollen.
*Prüfung:* Ein Screenshot bei 1280 mal 800 enthält Quelltext und Zeichnung
vollständig.

**B3.2** Die Zeichnung bekommt mindestens so viel Fläche wie der Editor.
*Prüfung:* Ab 1000 px Viewportbreite belegt die Zeichenfläche mindestens die
Hälfte der Kartenbreite, und die Zeichnung ist in der kürzeren Kante nie kleiner
als 320 px. Heute 1:1 (`Playground.astro`: `grid-template-columns: 1fr 1fr`;
`Beloch.astro`: `minmax(0, 1fr) minmax(0, 1fr)`).

**B3.3** Der sichtbare Codeausschnitt beginnt bei der ersten Anweisung.
*Prüfung:* In der Anfangshöhe (heute 380 px, etwa 17 Zeilen) ist mindestens eine
Faltanweisung sichtbar, ohne zu scrollen. Heute verletzt: das Hero-Programm
beginnt mit zwölf Zeilen Quellenkommentar und endet mit Zusicherungen
(`packages/www/src/lib/landing-examples.ts`, `examples/bases/bird-base.bel`).

**B3.4** Es gibt keine Fensterdekoration. Kein nachgebauter Browserrahmen, keine
Ampelknöpfe, keine Titelleiste über dem Quelltext.
*Prüfung:* Der Entwurf zeigt Code als Text auf einer Fläche. Ein Dateiname
erscheint als Kommentarzeile in der Sprache selbst, so wie heute in
`Beloch.astro`.

**B3.5** Ein Fehler ersetzt die Zeichnung nicht.
*Prüfung:* Tippfehler in eine laufende Zeile setzen. Die letzte gültige
Zeichnung bleibt stehen, die Diagnose erscheint daneben und markiert die Zeile.
Heute verletzt: jeder Fehlerweg schreibt in dieselbe Fläche und löscht das Bild
(`Playground.astro`, `showNotice`).

**B3.6** Keine Illustration steht an der Stelle eines erzeugten Artefakts. Jede
Zeichnung im Auftritt ist aus einem `.bel`-Programm erzeugt oder als Schema
gekennzeichnet.
*Prüfung:* Zu jeder Abbildung existiert das Programm, das sie erzeugt, oder eine
Beschriftung, die sie als Skizze ausweist.

## 3.2 Schmale Viewports

**B3.7** Unterhalb des Umbruchpunkts steht die Zeichnung über dem Code.
*Prüfung:* Bei 390 px Breite liegt die Zeichnung vollständig im ersten
Bildschirm, der Editor beginnt darunter. Heute liegt der Umbruch bei 720 px und
die Reihenfolge ist umgekehrt.

**B3.8** Die Zeichnung fängt die Seitengeste nicht ab.
*Prüfung:* Auf dem Telefon über der Zeichnung wischen: die Seite scrollt. Auf dem
Desktop über der Zeichnung scrollen: die Seite scrollt. Zoom braucht einen
eigenen Auslöser (Modifikatortaste, Fokus oder ein Klick in die Fläche). Heute
verletzt (`Playground.astro`: `preventDefault` auf jedem Radereignis,
`touch-action: none`).

**B3.9** Unterhalb des Umbruchpunkts füllt keine Fläche das ganze Fenster ohne
sichtbare Fortsetzung.
*Prüfung:* Bei 390 px ist am unteren Rand des ersten Bildschirms angeschnittener
Inhalt sichtbar.

## 3.3 Export

**B3.10** Die Zeichnung ist ohne Chrome exportierbar. Was in der Fläche liegt,
ist dasselbe SVG, das der Renderpfad erzeugt.
*Prüfung:* Zeichnung speichern oder kopieren, die Datei in einem Programm ohne
die Seiten-CSS öffnen: kein Knopf, kein Rahmen, kein Fokusring, kein
Panelhintergrund, und alle Farben aufgelöst.

**B3.11** Bedienelemente liegen außerhalb des SVG oder sind beim Export
entfernbar, und sie verdecken die Zeichnung nicht dauerhaft.
*Prüfung:* Der Reset-Knopf, die Schrittleiste und die Papierauswahl sind im
Export nicht enthalten.

**B3.12** Auf einer Webfläche ist ein erzeugtes Diagramm ein SVG.
*Prüfung:* Kein `<img src="*.png">` für eine Zeichnung, die aus einem Programm
stammt.

---

# 4. Typografie

Drei Anforderungen laufen gleichzeitig: Mathematiksatz, eine Monospace, die die
Sigillen der Sprache unterscheidbar hält, und eine Lesetypografie für lange
Referenztexte (`model.md` hat 1160 Zeilen).

Heutiger Stand: `theme.css` und `index.astro` nennen `'IBM Plex Mono'` und
`'IBM Plex Sans'`, aber `packages/www/package.json` hat keine
Schrift-Abhängigkeit und `packages/www/public/` enthält keine Schriftdatei. Auf
jeder Maschine ohne installiertes Plex fällt die Seite auf `ui-monospace` und
`system-ui` zurück. KaTeX 0.18.7 ist als Abhängigkeit eingebunden und
`katex/dist/katex.min.css` als Custom-CSS geladen (`packages/www/astro.config.mjs`),
bringt also seine eigenen Schriften mit.

## 4.1 Rollen

**B4.1** Genau drei Rollen, genau drei Familien: Prosa, Code, Mathematik. Keine
vierte.
*Prüfung:* Der Entwurf nennt drei Familien und für jede die Rolle. Eine
Display-Schrift nur für Überschriften ist eine vierte.

**B4.2** Jede genannte Schrift wird ausgeliefert, oder es wird keine genannt.
*Prüfung:* Für jede Familie liegt entweder eine Schriftdatei im Repository mit
Lizenztext daneben, oder der Entwurf nennt einen Systemstack mit mindestens
drei Gliedern und akzeptiert, dass das Ergebnis pro Betriebssystem anders
aussieht. Der heutige Zwischenzustand, ein Name ohne Datei, ist ein Fehlschlag.

## 4.2 Mathematik

**B4.3** Die Prosaschrift muss neben dem KaTeX-Satz bestehen.
*Prüfung:* Bei gleicher `font-size` liegt die x-Höhe der Prosaschrift zwischen
0,9 und 1,1 der x-Höhe von KaTeX Main, und Ziffern in Prosa und in einer
Inline-Formel sitzen auf derselben Grundlinie, ohne dass eine Größenkorrektur
über 5 Prozent nötig wird. Eine Formel mitten im Satz darf die Zeilenhöhe nicht
aufreißen.

**B4.4** Ersetzt der Entwurf die KaTeX-Schriften, ist das eine eigene
Entscheidung mit eigener Prüfung: der gesamte Zeichensatz, den die
Referenzdokumente setzen, muss abgedeckt sein.
*Prüfung:* Alle Formeln aus `spec/MODEL.md` gesetzt, kein fehlendes Zeichen, kein
Fallback-Kasten.

**B4.5** Mathematik und Code sind visuell unterscheidbar. Ein Leser muss `.a` im
Programm von einem `a` in einer Formel trennen können.
*Prüfung:* Eine Seite aus `model.md`, die beides enthält, im Ausdruck gelesen.

## 4.3 Die Sigillen

Die Sprache setzt diese Zeichen tragend ein (`spec/BELOCH.md`,
`spec/SPECIFICATION.md`):

| Zeichen | Bedeutung |
|---|---|
| `.a` | Punktname |
| `--diag` | Linien- oder Faltliniennname; zwei Bindestriche, kein Gedankenstrich |
| `#[…]` | Flap-Selektor über Inzidenz |
| `!` | Nachgestellt an einem Namen: Neubindung (`as --f!`) |
| `*` | Treffpunkt zweier Faltlinien |
| `&` `\` `[…]` | Filteroperatoren auf einem Bündel |
| `=` und `as` | Bindung einer Linie gegen Bindung einer Faltlinie |
| `;` | Kommentar bis Zeilenende |

`@` ist aus der Grammatik zurückgezogen (`spec/SPECIFICATION.md`, v0.21-dev: "`@`
is retired entirely"). Es kommt in den Docs weiterhin in Zitatschlüsseln vor
(`[@alperin2006, §3]`) und muss dort lesbar bleiben.

**B4.6** `--` bleibt in jeder Umgebung zwei Bindestriche.
*Prüfung:* Die Monospace hat keine aktive Ligatur, die `--` zu einem Strich
zusammenzieht, und die Prosaschrift ebenfalls nicht, weil Faltliniennamen in
Fließtext und in Bildunterschriften vorkommen. Zusätzlich auf der
Verarbeitungsseite: SmartyPants ist site-weit abgeschaltet (`astro.config.mjs`),
und das bleibt so.

**B4.7** Jedes Sigill ist von seinem nächsten Nachbarn eindeutig zu trennen, bei
13,5 px Schriftgröße und 22 px Zeilenhöhe auf der Codefläche (heutige Werte in
`theme.css` und `Beloch.astro`).
*Prüfung:* Diese beiden Zeilen setzen und lesen:
```
mark (map .a onto --diag) as --l1!
#[.a --bc] & --l1 \ (--l2 * --ray)
```
Verwechselbar sein dürfen nicht: `.` gegen `,`, `*` gegen `.`, `\` gegen `/`,
`!` gegen `1` gegen `l` gegen `I`, `0` gegen `O`, `--` gegen `-`, `[` gegen `(`.

**B4.8** Geschachtelte Klammern bleiben bis drei Ebenen zählbar.
*Prüfung:* Die zweite Zeile oben, bei 13,5 px, aus 60 cm Abstand gelesen: die
Ebenen sind auseinanderzuhalten, ohne dass die Klammern eingefärbt werden
müssen.

**B4.9** Editor und statische Codeblöcke teilen dasselbe Zeilenraster.
*Prüfung:* Gleiche `font-size` und gleiche `line-height` im Playground, in
`.bel-block` und in `.grammar-block`. Die Schrittmarkierung und der
Zeilen-Gutter hängen an Zeilenhöhen, ein abweichendes Raster verschiebt sie.

## 4.4 Lesetypografie

**B4.10** Lesetext liegt zwischen 60 und 80 Zeichen pro Zeile.
*Prüfung:* Gemessen in der Referenzdoku. Kurze Zeilen im Hero sind eine
ausdrücklich benannte Ausnahme (heute 46ch und 52ch in `index.astro`).

**B4.11** Die Prosaschrift hat echte Kapitälchen, oder der Entwurf ersetzt das
Stilmittel.
*Prüfung:* Die Referenzdokumente setzen `font-variant-caps: small-caps` für
Statement-Label, Begriffsnamen und Abbildungslabel (`theme.css`). Synthetische
Kapitälchen neben echten vergleichen; wo der Unterschied sichtbar ist, gilt die
Bedingung als verletzt.

**B4.12** Der Zeichensatz deckt Englisch, Deutsch und italienische Namen ab.
*Prüfung:* "Margherita Piazzolla Beloch", Umlaute und ß setzen, ohne
Ersatzglyphe.

## 4.5 Die Wortmarke

**B4.13** Die Wortmarke lautet "Beloch", in dieser Schreibweise, ohne Zusatz, und
sie liest sich als "Beloch".
*Prüfung:* Ein Leser ohne Kontext buchstabiert sie richtig. Lesarten wie
"Belech" oder "Beloh" sind ein Fehlschlag.

**B4.14** Die Aussprache steht als Text, nicht als Grafik: italienisch,
"beh-LOK", Betonung auf der zweiten Silbe, hartes k am Ende. Eine IPA-Fassung
/beˈlɔk/ ist zulässig.
*Prüfung:* Der Hinweis ist kopierbar, von einem Screenreader vorlesbar und von
einer Suche auffindbar. Der Grund steht in `decisions/0005-name-beloch.md`: der
Name kollidiert im geisteswissenschaftlichen Umfeld mit Karl Julius Beloch, und
die Herkunft gehört auf jede Einstiegsseite.

**B4.15** Die Wortmarke ist Text und kein Bild, wo sie Text sein kann.
*Prüfung:* Im Seitenkopf ist sie markierbar und kopierbar. Heute erfüllt
(`index.astro`, `.wordmark`, IBM Plex Mono 600).

**B4.16** Verlässt die Wortmarke die Monospace, wird die Beziehung zu den
Sigillen ausdrücklich geregelt.
*Prüfung:* Der Entwurf sagt, ob `.` und `--` weiterhin neben dem Namen stehen
dürfen und in welcher Schrift. Siehe Abschnitt 10.

## 4.6 Lizenz

**B4.17** Die Lizenz jeder ausgelieferten Schrift erlaubt Weitergabe im
Repository, Einbettung in ein PDF und Verwendung als Webfont, ohne
Mengenbegrenzung und ohne Bindung an eine Domain oder ein Konto.
*Prüfung:* Der Lizenztext liegt neben der Schriftdatei im Repository, und die
drei Erlaubnisse stehen darin. Das Projekt ist MIT-lizenziert; ein Fork muss die
Seite bauen und das Paper setzen können. "Free for personal use" fällt aus.

**B4.18** Webfonts liegen als woff2 vor, auf den gesetzten Zeichenvorrat
reduziert, und jede Familie kommt mit höchstens zwei Schnitten aus.
*Prüfung:* Dateiliste und Gesamtgröße. Eine Schriftfamilie mit neun Gewichten im
Build ist ein Fehlschlag.

---

# 5. Dichte und Ruhe

Der Inhalt sind Zeichnungen. Alles, was um eine Zeichnung liegt, konkurriert mit
ihr.

**B5.1** Ein Abstandsraster mit einem Basiswert. Jeder Abstand ist ein
ganzzahliges Vielfaches oder ein benannter Bruchteil davon.
*Prüfung:* Liste aller Abstände im Entwurf, jeder als n mal Basis darstellbar.
Heute stehen 8, 9, 10, 12, 14, 16, 18, 20 und 22 px nebeneinander
(`Playground.astro`, `Beloch.astro`).

**B5.2** Um die Zeichnung liegt eine Ruhezone von mindestens zwei Basiswerten
auf allen vier Seiten, in der nichts liegt.
*Prüfung:* Kein Text, kein Knopf, keine Linie in der Zone. Ein Element, das dort
sein muss, liegt über der Zeichnung und erscheint erst bei Zeiger oder Fokus,
so wie heute der Reset-Knopf.

**B5.3** Ein Rahmen pro Objekt. Von der Seitenfläche bis zur Zeichnung liegt
höchstens eine Kontur.
*Prüfung:* Von außen nach innen zählen. Karte, Panel und Zeichnung dürfen nicht
alle drei eine Linie haben.

**B5.4** Die Zeichnung liegt auf Papier. Der Hintergrund hinter dem SVG ist die
Papierfarbe des Schemas oder transparent, und die Papierkante ist sichtbar.
*Prüfung:* Ein Panelhintergrund, der wie Papier aussieht, ist ein Fehlschlag.
Heute schaltet der Playground den weißen Standardhintergrund ab
(`--bel-bg: transparent`), während der headless Pfad ihn behält.

**B5.5** Schatten gehören der Schichtordnung. Der Renderer setzt einen
Schlagschatten für übereinanderliegendes Papier (`feDropShadow`, dy 1,
stdDeviation 1,1, Deckung 0,18; sichtbar in `examples/bases/fish-base-cp.svg`).
Außerhalb dieser Rolle gibt es in der Oberfläche keinen Schatten.
*Prüfung:* Suche nach Schatten im Entwurf. Jeder Treffer liegt im Artefakt und
bedeutet Schichtung.

**B5.6** Kein Strichmuster in der Oberfläche, das im Artefakt Bedeutung hat.
Gestrichelt heißt Tal, Strich-Punkt heißt Berg, fein gepunktet heißt
Konstruktionslinie.
*Prüfung:* Suche nach `dasharray` außerhalb des Renderpfads. Heute grenzwertig:
die Anzeige für verdeckte Segmente benutzt `5 4` (`Playground.astro`,
`.pg-hl-ghost`), das Tal benutzt `6 4` (`theme.ts`, `yrLineStyle`).

**B5.7** Keine Fläche ohne Aufgabe. Kein Verlauf, kein Rauschen, kein Muster,
keine Trenngrafik zwischen Abschnitten.
*Prüfung:* Zu jeder gefüllten Fläche lässt sich sagen, welcher Inhalt darin
liegt.

**B5.8** Zwei Radien, höchstens: einer für Karten und Panels, einer für kleine
Bedienelemente. Das Papier selbst hat keinen Radius.
*Prüfung:* Liste aller Radien. Heute 14, 12, 8, 7, 6 und 4 px.

**B5.9** In der Referenzdoku ist der Abstand zwischen zwei Blöcken größer als der
Abstand innerhalb eines Blocks.
*Prüfung:* Zwei aufeinanderfolgende Definitionsblöcke ohne Überschrift dazwischen
lesen sich als zwei Blöcke. Die Blöcke tragen heute einen linken Balken
(`theme.css`, `.stmt` und `.term`).

**B5.10** Eine Fläche zeigt eine Sache. Der Playground zeigt Code und Zeichnung;
was darüber hinaus dort landen soll, braucht eine eigene Fläche.
*Prüfung:* Zähle die Bedienelemente auf der Fläche um die Zeichnung. Über fünf
ist eine Werkzeugleiste, und die gehört nicht an das Papier.

---

# 6. Hell und Dunkel gleichberechtigt

Heute ist die Landing hart auf Dunkel voreingestellt: ohne gespeicherte Wahl
bleibt sie dunkel, unabhängig von der Systemeinstellung
(`packages/www/src/pages/index.astro`, `var theme = stored || "dark"`). Die
Docs folgen dem System.

**B6.1** Der Bezugsmodus ist hell. Das Artefakt ist Tinte auf Papier: der
Standard des Renderers ist `ink: "#0f172a"` auf `paperFill: "#f8fafc"` mit
`background: "white"`, drei der vier Papier-Schemata sind hell, die erzeugten
SVGs im Repository tragen weiße Hintergründe, und das Paper wird auf Papier
gedruckt. Der Dunkelmodus ist die abgeleitete Fassung.
*Prüfung:* Der Entwurf zeigt zuerst die helle Fassung, und jede dunkle Farbe
lässt sich als Ableitung einer hellen benennen. Fällt der Dunkelmodus weg,
bleibt ein vollständiger Auftritt übrig.

**B6.2** Kein Modus wird erzwungen. Ohne gespeicherte Wahl folgt jede Fläche
`prefers-color-scheme`.
*Prüfung:* System auf hell, `localStorage` leer, Landing aufrufen: sie lädt hell.

**B6.3** Die Wahl gilt über alle Flächen.
*Prüfung:* Auf der Landing umschalten, in die Docs wechseln: der Modus hält.
Heute erfüllt über den gemeinsamen Schlüssel `starlight-theme`.

**B6.4** Identisch in beiden Modi bleiben: Geometrie, Layout, Abstände,
Zeilenraster, Schriftgrößen, Strichstärken, Strichmuster, Zeichenreihenfolge,
Papierfarbe des gewählten Schemas und die Bedeutung jeder Farbrolle.
*Prüfung:* Screenshots beider Modi übereinanderlegen. Es unterscheiden sich
ausschließlich Farbwerte; keine Kante verschiebt sich.

**B6.5** Beide Modi halten dieselben Schwellen: 4,5:1 für Text, 3:1 für große
Schrift und für die Konturen von Bedienelementen, 3:1 für jede semantische
Linie gegen ihr Papier.
*Prüfung:* Beide Wertesätze gerechnet, nicht nur der gestaltete.

**B6.6** Kein Inhalt existiert nur in einem Modus. Keine Abbildung, kein
Diagramm, kein Screenshot, der nur dunkel funktioniert.
*Prüfung:* Jede Abbildung in beiden Modi ansehen.

**B6.7** Die dauerhaft dunkle Codefläche ist entweder abgeschafft oder als
benannte Ausnahme durchgehalten.
*Prüfung:* Heute ist `--beloch-code-bg: #101C2E` in beiden Modi dunkel
(`theme.css`), also gibt es im Hellmodus eine dunkle Fläche. Der Entwurf sagt,
ob das bleibt. Bleibt es, gibt es im Hellmodus genau diese eine dunkle Fläche,
und die 22 Syntaxfarben werden nur gegen sie geprüft. Bleibt es nicht, gibt es
zwei Syntaxfarbsätze und zwei Prüfungen.

---

# 7. Token-Ordnung

Heute existieren drei Namensräume: `--beloch-*` für die Weboberfläche
(`packages/www/src/styles/theme.css`), `--bel-*` für die Renderfläche, gesetzt
von den Papier-Schemata und gelesen von jedem inline gesetzten SVG
(`packages/www/src/lib/paper-schemes.ts`, `WEB_THEME` in `theme.ts`), und das
`Theme`-Objekt in TypeScript, das den headless Pfad bedient.

Die harte technische Tatsache, aus der die ganze Ordnung folgt: resvg löst keine
CSS-Variablen auf. Deshalb muss `DEFAULT_THEME` vollständig aus Literalen
bestehen, und die CSS-Variablen sind eine Überschreibungsschicht darüber, immer
mit Literal als Fallback.

**B7.1** Ein einziges Präfix.
*Prüfung:* Eine Suche über die Quellen findet genau ein Variablenpräfix.

**B7.2** Der Name hat drei Teile: `--<präfix>-<schicht>-<rolle>` mit einer
optionalen vierten Stufe für Varianten. Es gibt genau drei Schichten:
`paper` für alles, was im Artefakt liegt (Papier, Tinte, Faltlinien, Punkte,
Hervorhebungen), `ui` für die Oberfläche (Flächen, Rahmen, Text, Akzent,
Zustände), `syntax` für die Tokenfarben des Codes.
*Prüfung:* Jeder Name im Entwurf zerfällt in diese Teile. Ein Name, der in zwei
Schichten passt, ist falsch benannt und wird geteilt.

**B7.3** Rollennamen benennen Bedeutung, nicht Erscheinung.
*Prüfung:* Kein Farbwort im Namen. `--bel-paper-mountain` ist zulässig,
`--bel-paper-red` nicht. Zahlen sind zulässig, wenn sie eine dokumentierte
Ordnung sind (`--bel-ui-surface-1`, `-2`, `-3`), und unzulässig als Nummerierung
ohne Ordnung.

**B7.4** Jede Rolle der Schicht `paper` hat eine Entsprechung im
TypeScript-Theme unter demselben Rollennamen, und die TypeScript-Seite trägt
einen Literalwert.
*Prüfung:* Die Namensliste im Theme-Objekt und die Variablenliste der Schicht
`paper` sind aufeinander abbildbar; ein Skript kann das vergleichen. Keine Rolle
der Schichten `ui` oder `syntax` erscheint im Theme-Objekt.

**B7.5** Jede Variable, die ein SVG liest, wird mit Fallback gelesen.
*Prüfung:* Kein `var(` ohne zweites Argument im Renderpfad. Heute erfüllt
(`WEB_THEME`).

**B7.6** Die Papier-Schemata überschreiben ausschließlich Rollen der Schicht
`paper`, und ausschließlich zur Laufzeit auf `documentElement`.
*Prüfung:* Die Ausgabe von `schemeVars` enthält nur `paper`-Namen.

**B7.7** Ein Wert steht an genau einer Stelle. Wo ein Wert zwangsläufig
dupliziert wird, weil die Zieloberfläche keine Variablen kennt, erzeugt ein
Generator die Kopie oder ein Test vergleicht sie.
*Prüfung:* Die sechs Hervorhebungsfarben stehen heute dreifach als Literale
(`theme.ts` `HIGHLIGHT_PALETTE`, `theme.css` `.figure-hl-*`,
`scripts/typst-compat.typ`). Nach der Umstellung existiert ein Test, der die
drei Listen auf Gleichheit prüft, oder es existiert nur noch eine Quelle.

**B7.8** Die Modusabhängigkeit steht bei der Definition. Ein Token hat einen Wert
oder zwei, und beide stehen nebeneinander.
*Prüfung:* Kein Token wird in einer Komponente überschrieben. Alle
Hell-Definitionen stehen in einem Block.

**B7.9** Die Rollennamen sind die Schnittstelle zu den Oberflächen ohne CSS. Für
jede Syntaxrolle existiert genau ein Name, und dieser Name trägt als Suffix im
TextMate-Scope der VS-Code-Extension und als Sprachbezeichnung in der
Typst-Show-Rule.
*Prüfung:* Die Klassenliste in `theme.css`, die Scopes in
`packages/vscode/syntaxes/beloch.tmLanguage.json` und die Show-Rules in
`scripts/typst-compat.typ` tragen dieselben Rollennamen.

**B7.10** Die Zahl der Syntaxrollen ist begrenzt durch B1.9. Wer eine Rolle
hinzufügt, weist für sie einen ΔE76-Abstand von mindestens 15 zu allen
vorhandenen nach oder legt sie mit einer vorhandenen zusammen.
*Prüfung:* Paarmatrix. Heute sind 22 Rollen definiert und 18 Paare liegen
darunter.

---

# 8. Oberflächen-Parität

**B8.0** Eine Oberfläche darf eine Regel weglassen, die sie technisch nicht
tragen kann, und darf keine Regel umkehren.
*Prüfung:* Zu jeder Abweichung nennt der Entwurf die technische Ursache.

## 8.1 Landing

Sie umgeht Starlight vollständig und bringt eigenen Reset und eigenes Layout mit
(`index.astro`).

*Übertragbar:* alle Tokens, das Abstandsraster, Typografie, Bewegungsregeln,
Hell/Dunkel, die Artefaktregeln aus Abschnitt 3.
*Eigene Regeln:* die Landing darf Layout definieren, das es in den Docs nicht
gibt (volle Breite, zentrierter Hero). Sie darf kein Token definieren, das die
Docs nicht haben.
*Prüfung:* Die Liste der Tokens, die die Landing benutzt, ist eine Teilmenge der
gemeinsamen Liste.

## 8.2 Referenzdocs

Starlight liefert Schrift, Grundpalette, Layout, Sidebar, Suche und die gesamte
Prosatypografie. Eigene Ergänzungen sind heute: die Faltfarben, die dunkle
Codefläche, das Syntaxschema, die ausbrechende `<Beloch>`-Karte, die
Definitionsblöcke, die Abbildungen, die Zitat-Rückverweise.

*Übertragbar:* Tokens, Farbordnung, Bewegungsregeln, Artefaktregeln,
Dichteregeln.
*Eigene Regeln:* jede Abweichung von Starlight geschieht über ein Token oder
eine benannte Überschreibung, nie durch Nachbau eines Starlight-Bauteils. Eine
Überschreibung muss ein Starlight-Update überstehen.
*Prüfung:* Liste der Überschreibungen. Jede nennt den Starlight-Selektor, den
sie trifft. Nach einem Update der Abhängigkeit wird diese Liste durchgegangen.

## 8.3 Playground

*Übertragbar:* alles.
*Eigene Regeln:* Interaktion. Diese Fläche ist die einzige mit Zeiger-,
Tastatur- und Screenreader-Anforderungen am Artefakt selbst.
*Prüfung:* Der Zeichenbereich ist fokussierbar, Pan und Zoom sind über die
Tastatur bedienbar, die Trefferflächen der Faltlinien sind fokussierbar, die
Fehlerfläche hat `role="alert"` und wird nicht vor dem Setzen der Meldung
geleert, und der Laufknopf ist im Ruhezustand nicht ohne sichtbare Begründung
abgeschaltet. Alle fünf Punkte sind heute offen
(`docs/brand/research/surface-audit.md`, Abschnitt 3).

## 8.4 VS-Code-Extension

Die Extension liefert heute nur eine TextMate-Grammatik
(`packages/vscode/syntaxes/beloch.tmLanguage.json`), kein Farbthema. Die Farben
kommen aus dem Thema des Nutzers, und darauf hat der Entwurf keinen Zugriff.

*Übertragbar:* die Rollennamen aus B7.9 und die Wortmarke samt Icon für den
Marketplace-Eintrag.
*Eigene Regeln:* keine Farbwerte. Der Beitrag der Designsprache ist die
Zuordnung von Sprachkonstrukt zu Scope, und die Zuordnung muss so gewählt sein,
dass fremde Themes ein brauchbares Ergebnis liefern.
*Prüfung:* Eine `.bel`-Datei in Default Dark+ und in Default Light+ öffnen. Jedes
Sigill bekommt einen Scope, der in beiden Themes eine unterscheidbare Farbe
erhält. Ein mitgeliefertes Beloch-Farbthema ist erlaubt und darf nicht
Voraussetzung sein.

## 8.5 Abbildungen im Paper

Erzeugt über den headless Pfad, in Typst gesetzt, gedruckt.

*Übertragbar:* die Farbordnung der Schicht `paper`, die Strichsprache, die
Hervorhebungsfarben, das Verhältnis von Punktradius zu Strichstärke.
*Eigene Regeln:* keine Interaktion, kein Hover, kein `var()`, keine Bewegung,
keine Bedeutung allein über Farbe, feste Abbildungsbreite.
*Prüfung:* Abbildung auf 78 mm Breite gesetzt, einfarbig gedruckt, gelesen. Rand,
Berg, Tal und Konstruktionslinie sind zu unterscheiden, Beschriftungen sind
lesbar, und die Bildunterschrift trifft mit ihren farbigen Wörtern dieselben
Dinge wie die Zeichnung.

## 8.6 Konferenzfolien

Existieren noch nicht (`paper/README.md`, 9OSME Xi'an, August 2027).

*Übertragbar:* Tokens, Typografie, Wortmarke, Artefaktregeln, die Strichsprache.
*Eigene Regeln:* Projektionsbedingungen. Ein Beamer in einem hellen Saal frisst
Kontrast, und ein Zuschauer in der letzten Reihe sitzt zehn Meter entfernt.
Folien brauchen Standbilder (B2.5), weil ein Vortrag nicht auf laufende
Animation angewiesen sein darf.
*Prüfung:* Bei 16:9 gilt: jede Linie und jeder Text hält 4,5:1 gegen den
Folienhintergrund, kleinste Schriftgröße 18 pt, die Zeichnung füllt mindestens
ein Drittel der Folienhöhe, und jede Folie ist als Standbild vollständig.
Zusätzlich: die Wortmarke in einer Ecke bei 24 px Höhe stört 18-pt-Text nicht
(Kriterium aus `docs/brand/logo-brief.md`).

---

# 9. Was die Designsprache nicht tun darf

Aus den Antimustern der Landschaftsanalyse und aus der Tonalität. Jedes Verbot
ist so formuliert, dass ein Entwurf dagegen geprüft werden kann.

**B9.1** Kein Feature-Karten-Raster.
*Prüfung:* Keine Seite trägt drei oder mehr gleich große Karten aus Icon,
Überschrift und Kurztext. Das Muster stammt aus dem Kaufentscheidungs-Layout von
Supabase und Vercel.

**B9.2** Keine Vergleichstabelle gegen vorhandene Werkzeuge.
*Prüfung:* Keine Matrix mit Häkchen, in der Beloch in einer Spalte steht und
Rabbit Ear, ORIPA oder TreeMaker in einer anderen.

**B9.3** Keine Vertriebs-Handlungsaufforderung.
*Prüfung:* Die primären Verben sind Run, Try, Install, Docs, Playground,
Examples, Source. Verboten sind "Get started free", "Deploy now", "Talk to
sales", "Join thousands", "Book a demo".

**B9.4** Keine Reichweitenzahlen als Vertrauensbeweis.
*Prüfung:* Keine Stars, keine Downloads, keine Nutzerzahlen, keine
Kundenlogowand, keine Testimonials. Zulässig sind Versionsnummer, Datum,
Reifestand, Prüfergebnis und Fachzitate mit Quelle.

**B9.5** Keine Zeitangabe zu einem Meilenstein in der Oberfläche.
*Prüfung:* Keine Roadmap mit Jahreszahl, kein "coming soon", kein Fortschritts-
balken über ungebaute Funktionen.

**B9.6** Kein Maskottchen, kein Gesicht, kein Tier.
*Prüfung:* Der Entwurf enthält keine Figur mit Augen. Der Grund steht im
Logo-Brief: eine Figur zieht Aufmerksamkeit vom Diagramm ab, und Roc und Rabbit
Ear besetzen dieses Feld bereits.

**B9.7** Keine Startup-Signaturen.
*Prüfung:* Kein Farbverlauf, kein Leuchten, kein Glasrand, kein abgerundetes
Quadrat als Fläche hinter dem Zeichen, kein Sparkle-Stern, keine Kompassrose.
Das heutige Favicon ist eine Kompassrose und wird ersetzt.

**B9.8** Keine räumliche Darstellung von Papier.
*Prüfung:* Keine Perspektive, keine Isometrie, kein Schlagschatten außerhalb der
Schichtrolle aus B5.5. Der Grund ist eine Architekturentscheidung: Beloch
rechnet ausschließlich flache Faltzustände.

**B9.9** Keine Zierform, die eine Bedeutung imitiert.
*Prüfung:* Kein gestrichelter Rand, kein Strich-Punkt-Muster, keine gepunktete
Trennlinie in der Oberfläche. Diese drei Muster gehören der Faltsemantik.

**B9.10** Keine Farbe als einziger Träger einer Aussage, nirgends.
*Prüfung:* Jede farbcodierte Information hat einen zweiten Kanal: Glyph, Muster,
Position oder Text. Heute erfüllt bei den Block-Ergebnissen (Häkchen und Kreuz
neben der Farbe, `theme.css`).

**B9.11** Kein Bedienelement, das im Ruhezustand unerreichbar aussieht, ohne dass
der Grund an der Fläche steht.
*Prüfung:* Ein abgeschaltetes Element trägt seinen Grund sichtbar, nicht nur in
einem `title`.

**B9.12** Kein Gedankenstrich als Stilmittel in Oberflächentexten.
*Prüfung:* `rg -n` auf Geviert- und Halbgeviertstrich über die Textquellen der
Site. Heute verletzt im Hero: `index.astro` setzt einen Geviertstrich zwischen
"works out the exact geometry" und "right here in your browser".

**B9.13** Kein "we" im Auftritt. Das Projekt spricht in der dritten Person über
sich.
*Prüfung:* Suche nach "we" in den Oberflächentexten.

**B9.14** Keine Onboarding-Choreografie. Kein Overlay, keine Tour, keine
Rundgangs-Sprechblasen, kein Newsletter-Aufruf.
*Prüfung:* Der erste Bildschirm zeigt das Artefakt und sonst nichts, was
weggeklickt werden muss.

**B9.15** Keine Rot- oder Blautöne außerhalb der Faltsemantik im Bildzeichen und
in der Wortmarke.
*Prüfung:* Die Dateien enthalten weder `#dc2626`, `#2563eb`, `#ff7d5e`,
`#6f9bff`, `#cf4327`, `#2f5fd0` noch einen Ton, der nach Entsättigung mit einem
von ihnen verwechselbar ist. Die Ausdehnung dieses Verbots auf die
Oberflächen-Akzentfarbe ist eine offene Entscheidung, siehe Abschnitt 10.

---

# 10. Offene Entscheidungen

Zehn Entscheidungen bleiben offen. Sie gehören in die Gestaltung, weil jede von
ihnen den Entwurf in eine andere Richtung zieht. Hinter jeder steht, was daran
hängt.

1. **Darf die Akzentfarbe der Oberfläche die Talfarbe sein?**
   Bleibt Blau doppelt belegt, spart der Entwurf eine Farbe und jeder aktive
   Zustand neben einer Zeichnung wird zur Verwechslungsquelle; wird eine dritte,
   neutrale Akzentfarbe eingeführt, ändern sich Fokus, Auswahl, aktiver Tab,
   Schrittmarkierung und Hervorhebung im Playground gleichzeitig.

2. **Ist der Bezugsmodus hell?**
   Bei Hell verliert die Landing ihre harte Dunkelvoreinstellung und der Hero
   muss auf Weiß tragen; bei Dunkel muss der Entwurf erklären, warum das
   gedruckte Artefakt und die Website gegensätzliche Grundflächen haben.

3. **Bleibt die Codefläche in beiden Modi dunkel?**
   Bleibt sie dunkel, genügt ein Syntaxfarbsatz und eine Kontrastprüfung; folgt
   sie dem Modus, werden es zwei Sätze und zwei Prüfungen über alle Rollen.

4. **Werden die Web-Tokens auf die Engine-Werte zurückgeführt oder umgekehrt?**
   Im ersten Fall ändern sich die Farben in der Weboberfläche und der
   Dunkelmodus muss mit den satteren Engine-Werten auskommen; im zweiten Fall
   ändern sich alle erzeugten SVGs im Repository, im Paper und in den
   Docs-Abbildungen.

5. **Bekommt jedes Papier-Schema einen eigenen Linienfarbsatz?**
   Mit eigenen Sätzen sind acht Kombinationen zu gestalten und zu prüfen; ohne
   sie ist der Farbstil auf helle Papiere beschränkt und Kraft und Indigo
   bekommen ausschließlich den monochromen Strichstil.

6. **Welche Schriftrolle wird ausgeliefert, welche bleibt Systemstack?**
   Ausgeliefert bedeutet Bytes im Build, eine Lizenzdatei im Repository und ein
   gleiches Bild auf jeder Maschine; Systemstack bedeutet ein Auftritt, der auf
   Linux, macOS und Windows verschieden aussieht, auch in der Wortmarke.

7. **Bleibt die Wortmarke monospace?**
   Bleibt sie es, sind `.` und `--` Teil der Marke und ein eigenes
   Wortmarken-Asset ist entbehrlich; verlässt sie die Monospace, braucht es eine
   gezeichnete Fassung und eine Regel, wie die Sigillen daneben gesetzt werden.

8. **Zeigt eine Faltanimation Zwischenzustände oder nur die Überblendung zweier
   flacher Zustände?**
   Zwischenzustände verlangen ein Bewegungsmodell, das die Sprache heute nicht
   hat, und berühren die Festlegung auf flache Faltzustände; die Überblendung
   kommt mit dem aus, was der Evaluator schon ausgibt, und wirkt neben Rabbit
   Ear bescheidener.

9. **Wird der Schrittbalken das gemeinsame Bedienmuster aller Flächen?**
   Als gemeinsames Muster teilen Docs-Abbildungen, Playground und Folien eine
   Zeitachse und eine Erklärung; ohne es bekommt jede Fläche ihr eigenes
   Vokabular und jede Erklärung wird dreimal geschrieben.

10. **Wie viele Syntaxrollen behält die Darstellung?**
    22 unterscheidbare Farben sind auf einer Fläche nicht zu halten; jede
    Zusammenlegung nimmt einem Programm eine Unterscheidung, die heute ohne
    Klammernverfolgen lesbar ist, und die Entscheidung legt fest, welche
    Unterscheidungen das sind.
