# Positionierung und Zielgruppen

Dieses Dokument legt fest, als was Beloch nach außen auftritt, wen der Auftritt
meint, in welcher Reihenfolge, und in welcher Sprache er das tut. Es gilt für
die Site, das README, das Paper und jeden Vortrag.

Die Auftrittssprache ist Englisch. Alle Beispielformulierungen unten sind
deshalb englisch und als Text verwendbar.

Grundhaltung: Beloch tritt als Forschungsartefakt auf, das benutzbar ist. Der
Leser, den der Auftritt ernst nimmt, liest Spezifikationen freiwillig, erkennt
Verkaufssprache in einem Satz und prüft Behauptungen an Artefakten. Jede
Aussage nach außen hat deshalb einen Beleg im Repository: ein Beispielprogramm,
einen Abschnitt der Spezifikation, einen Decision Record.

## 1. Positionierungssatz

> **Beloch is a declarative language for origami: a program is a sequence of
> Huzita-Justin axiom operations, evaluated over exact real-algebraic
> arithmetic into a crease pattern and a folded state.**

Der Satz trägt drei prüfbare Angaben: die Sprachklasse (deklarativ), die
Grundlage (die sieben Axiome) und das Ergebnis (zwei FOLD-Frames). Er enthält
kein Werturteil und keinen Vergleich. Kurzform für Stellen mit wenig Platz, ein
Nebensatz weniger:

> A declarative language for origami, built on the Huzita-Justin axioms.

## 2. Tagline-Kandidaten

Alle fünf sind als Zeile unter dem Wortmarken-Titel gedacht, ohne Punkt am Ende
außer wo angegeben.

1. **"A declarative language for origami, built on the Huzita-Justin axioms."**
   Der Status quo auf Site und README. Vollständig beschreibend, null
   Interpretationsspielraum, keine Geschichte. Sicherste Wahl, wenn nur eine
   Zeile existiert.
2. **"The seven axioms, as a language."**
   Kürzeste Fassung mit Inhalt. Für Leser, die die Axiome kennen, sitzt sie
   sofort; allen anderen sagt sie nichts, braucht also den Untertitel
   daneben. Gut für Vortragstitel und Slides.
3. **"Origami constructions that run."**
   Adressiert die Reproduzierbarkeit, die in der Origami-Mathematik den Nerv
   trifft: eine Konstruktion, die bisher als Prosa plus Diagramm existiert,
   liegt hier als ausführbarer Text vor. Risiko: "run" zieht PL-Leser an, die
   dann nach Kontrollfluss suchen.
4. **"Exact geometry for folded paper."**
   Stellt den Zahlenkern nach vorn. Trägt gegenüber Lesern, die schon einmal
   an Floating-Point-Toleranzen in Geometriecode gescheitert sind. Verschweigt,
   dass es um eine Sprache geht.
5. **"Write the folding sequence. Get the folded paper."**
   Zwei Sätze, Praktiker-Register, beschreibt die Benutzung statt der
   Bauweise. Passend, sobald Schritt-für-Schritt-Diagramme existieren. Heute
   verspricht sie mehr, als der Evaluator einlöst.

Empfehlung: 1 als Untertitel auf Site und README, 2 für Talk-Titel und Slide-
Header. 3 bis 5 bleiben in Reserve und werden nicht parallel eingesetzt, damit
der Auftritt eine Formulierung hat und behält.

## 3. Zielgruppen

Die Reihenfolge folgt einem Kriterium: Kann der Auftritt diese Gruppe heute mit
Belegen bedienen, die im Repository liegen? Gruppen mit hohem Zukunftswert und
fehlendem Beleg stehen weiter unten, nicht weiter oben.

### 3.1 Origami-Mathematik und OSME-Community (Priorität 1)

**Wer genau.** Autoren und Leser der OSME-Proceedings, Bridges und JCDCG³. Die
computational-origami-Schule um Eos und Gröbner-basierte Faltverifikation.
Lehrende, die Origami-Konstruierbarkeit unterrichten. Amateur- und
Berufsmathematiker, die mit den Axiomen arbeiten. Klein, namentlich bekannt,
untereinander vernetzt.

**Problem heute.** Eine Konstruktion wird als Prosa plus Diagramm publiziert.
Wer sie nachvollziehen will, faltet sie nach oder baut sie in GeoGebra nach,
und GeoGebra hat für Axiom 6 und 7 keine natürliche Entsprechung. Vorhandene
Software rechnet in Floating-Point, und Origami besteht aus konstruierten
Koinzidenzen: die Frage "liegt dieser Punkt exakt auf dieser Faltlinie" ist die
Frage, die float mit Toleranz beantwortet und damit die Topologie still falsch
bestimmt. Es gibt kein zitierbares Quellformat für eine Faltung.

**Was Beloch bietet.** Eine Konstruktion als ausführbaren Text, ausgewertet über
exakte reell-algebraische Zahlen, inklusive der kubischen Fälle aus Axiom 7.
Die klassische Huzita-Justin-Nummerierung mit expliziter Cross-Map zu den
beiden rivalisierenden Schemata, damit kein Paper sie erneut verwechselt. FOLD
als Ausgabeformat, das die vorhandenen Werkzeuge der Community lesen. Ein
separates Forschungspaket, das die Alperin-Lang-Enumeration der Zweifach-Axiome
reproduziert.

**Was sie nicht bekommen.** Keinen Beweisassistenten: Beloch wertet aus und
beweist keine Sätze. Keine 3D-Zustände und keine nicht-flachen Faltungen. Keine
krummen Faltlinien. Keine Kegelschnitt-Erweiterungen der Axiome.

**Welcher Beweis überzeugt.** Die reproduzierte Zählung 489/203 gegen
Alperin-Lang. Der Swivel Rabbit Ear, dessen flachfaltende Faltlinie kein Axiom
konstruiert und die der Solver aus Kawasaki und Maekawa herleitet. Eine
Konstruktion mit irrationalen Koordinaten, die exakt verglichen wird statt auf
sechs Nachkommastellen.

**Priorität.** Höchste. Diese Gruppe entscheidet, ob die Arbeit im Zitationsgraph
landet, und sie ist die einzige, für die heute vollständige Belege vorliegen.

### 3.2 PL- und Compiler-Leute (Priorität 2)

**Wer genau.** Das Publikum von Lobsters, Hacker News und cs.PL auf arXiv. Die
OCaml-Community. Leute, die Nix, Dhall, Datalog oder TikZ benutzen und kleine
Sprachen mit einem echten Semantikproblem sammeln.

**Problem heute.** Keines, das Beloch löst. Diese Gruppe sucht etwas anderes:
DSL-Beispiele, die am Ende JSON erzeugen, langweilen sie. Interessant wird eine
Sprache, deren Auswertung ein Problem hat, das nicht in der Syntax steckt.

**Was Beloch bietet.** Genau so ein Auswertungsproblem. Die Axiome sind partielle
Operationen mit mehreren Lösungen: Axiom 7 hat bis zu drei, und die Sprache
braucht eine Disambiguierungsregel, die im Quelltext sichtbar und im
Ergebnis stabil ist. Dazu eine Schichtordnung, die beim Falten fortgeschrieben
wird, und einen exakten Zahlenkern, dessen Notwendigkeit sich aus der Domäne
ergibt statt aus Reinheitsliebe. Der gesamte Entwurfsweg ist offen lesbar:
Spezifikation, Decision Records, datiertes Entwurfsjournal, dokumentierte
Sackgassen.

**Was sie nicht bekommen.** Keine General-Purpose-Sprache, keine Schleifen, kein
Paketökosystem, keinen Typsystem-Beitrag. Die Sprache ist absichtlich nicht
Turing-vollständig.

**Welcher Beweis überzeugt.** Der Playground, der im Browser ohne Installation
läuft. Die Spezifikation, die Syntax und Semantik durchhält statt zu skizzieren.
Die Decision Records zu Evaluator statt Compiler, zum Zahlenkern und zur
Abgrenzung gegenüber vorhandenen Bibliotheken.

**Priorität.** Zweite. Diese Gruppe konvertiert nicht zu Nutzern, sie verstärkt.
Ein guter Tag auf Lobsters bringt die Origami-Mathematiker, die sonst nie von
dem Projekt hören würden.

### 3.3 Lehre und Didaktik (Priorität 3)

**Wer genau.** Dozenten für Geometrie und Konstruierbarkeit, Leiter von
Mathematik-Zirkeln und Schulwettbewerben, Autoren von Kursmaterial, das die
Origami-Axiome behandelt.

**Problem heute.** Die Axiome an der Tafel sind statisch. Die Aussage, dass
Papierfalten die Würfelverdopplung löst und Zirkel und Lineal das nicht tun,
bleibt eine Behauptung, weil die Konstruktion im Kurs nie läuft. Vorhandene
Software verlangt Installation, eine Programmiersprache oder beides.

**Was Beloch bietet.** Einen Browser-Playground ohne Installation, in dem eine
Zeile genau einer Axiom-Anwendung entspricht, und eine Tutorialstrecke, die ein
Programm Zeile für Zeile aufbaut. Werte bleiben exakt, die Kubikwurzel
erscheint als Kubikwurzel.

**Was sie nicht bekommen.** Kein Curriculum, keine Aufgabensammlung, keine
Bewertung, keine Lokalisierung. Zeichenketten im Quelltext gibt es nicht, die
Sprache ist englisch.

**Welcher Beweis überzeugt.** Ein Link, der in einer Vorlesung geöffnet wird und
sofort ein gefaltetes Ergebnis zeigt. Die Axiom-7-Konstruktion als Beispiel,
das per Klick lädt.

**Priorität.** Dritte, mit einer Einschränkung: Als Zielgruppe ist sie klein, als
Eingang ist sie billig. Der Playground existiert ohnehin, die Tutorials
ebenfalls. Es braucht keine eigene Kampagne, nur eine Seite, die ein Dozent
verlinken kann.

### 3.4 Origami-Praktiker und Diagram-Autoren (Priorität 4, heute ehrlich vertagt)

**Wer genau.** Designer, die Crease Patterns veröffentlichen. Autoren von
Faltanleitungen für Verbandszeitschriften und Bücher. Nutzer von
ReferenceFinder, Oripa und Rabbit Ear.

**Problem heute.** Diagramme entstehen von Hand im Zeichenprogramm. Crease
Pattern und Schrittfolge driften auseinander, weil sie getrennt gepflegt
werden. Ein geänderter Schritt bedeutet, alles Folgende neu zu zeichnen. Ein
Modell hat keine Versionsgeschichte, die etwas bedeutet.

**Was Beloch bietet.** Ein textuelles Modellformat, aus dem Crease Pattern und
gefalteter Zustand gemeinsam fallen, sodass beide nicht auseinanderlaufen
können. Ein Diff, der eine geänderte Faltung als eine geänderte Zeile zeigt.

**Was sie nicht bekommen.** Schritt-für-Schritt-Diagramme sind noch nicht
implementiert. Es gibt kein Zeichenprogramm, keinen eigenen Viewer, keine
krummen Faltungen und keine 3D-Modelle. Wer heute eine publikationsfertige
Anleitung braucht, ist hier falsch.

**Welcher Beweis überzeugt.** Ein Kranich, der aus dem Quelltext fällt, mit
Schrittfolge. Bis dahin: Fischbasis und Vogelbasis als Paar aus Crease Pattern
und gefaltetem Zustand, beide aus demselben Programm erzeugt.

**Priorität.** Vierte heute, erste an Zukunftswert. Diese Gruppe ist die
größte und die lauteste, und sie kommt genau einmal vorbei. Ein Auftritt, der
sie vor den Diagrammen einlädt, verbrennt sie. Bis dahin steht in den Docs ein
Satz, der sagt, was fehlt.

### 3.5 Computational Design und Engineering, Faltstrukturen (eruiert, nicht adressiert)

**Wer genau.** Miura-Ori und entfaltbare Strukturen, Architektur, Materialwissenschaft,
Nutzer von Freeform Origami und Rigid Origami Simulator.

**Warum nicht adressiert.** Diese Gruppe braucht 3D-Zustände, nicht-flache
Faltungen, ein Dickenmodell, Materialverhalten und Optimierung. Beloch ist auf
flache Faltzustände festgelegt, und das ist eine Architekturentscheidung mit
Begründung, keine Lücke im Backlog. Die vorhandenen Werkzeuge dieser Gruppe
bedienen sie besser. Was Beloch ihnen heute bietet, erschöpft sich in
FOLD-Kompatibilität, und die haben sie schon.

**Was sich ändern müsste.** Der 3D-Isometrie-Umbau, nicht-flache Faltungen, ein
Dickenmodell. Nichts davon steht auf dem Weg zum nächsten Meilenstein.

**Auftrittsregel.** Nicht ansprechen, nicht abwerten, und in der Related-Work-
Sektion des Papers korrekt einordnen.

### 3.6 Weitere sekundäre Gruppen: eruiert, nicht adressiert

- **LLM-Codegenerierung.** Eine kleine Grammatik ohne Escape Hatch ist ein
  sauberes Generierungsziel, und das trägt als Argument in einem Paper. Als
  Zielgruppe trägt es nicht: es gibt kein Korpus, keinen Benchmark und keine
  Messung. Der Auftritt behauptet es nicht, solange keine Zahl daneben steht.
- **Automatisches Beweisen und Gröbner-Verifikation.** Verwandte Arbeit, die im
  Paper zitiert gehört. Beloch verifiziert keine Faltsätze, und ein Auftritt,
  der diese Nähe sucht, weckt eine Erwartung, die der Evaluator nicht bedient.
- **Generative- und Creative-Coding-Szene.** Erwartet Schleifen, Zufall und
  Parameter-Sweeps. Die Antwort des Projekts lautet: eine Host-Sprache erzeugt
  `.bel`. Das ist eine korrekte Antwort und eine schlechte Einladung. Keine
  Kampagne in diese Richtung.
- **Maker, Lasercutter, Ritzen von Faltlinien.** Plausibler Nutzen über eine
  Crease-Pattern-Ausgabe für Schneidgeräte, und kein Pfad im Projekt.
  Aufgenommen als Idee, nicht als Adressat.

## 4. Messaging-Hierarchie

### Die Landing trägt drei Aussagen

1. **Was es ist.** "A declarative language for origami, built on the
   Huzita-Justin axioms. One line is one fold."
2. **Was gerade passiert ist.** Der Playground steht über der Zeile und hat
   schon gefaltet, bevor jemand etwas gelesen hat. Der Text darunter benennt
   das Ergebnis: "Describe a sheet and the creases you want. Beloch works out
   the exact geometry and hands back a crease pattern and a folded state."
3. **Warum es existiert.** Der Quelltext ist die Faltfolge, und die Arithmetik
   ist exakt, weil Origami aus konstruierten Koinzidenzen besteht. Ausformuliert
   in Abschnitt 6.

Mehr trägt die Landing nicht. Kein Feature-Raster, keine Roadmap, kein
Vergleich.

### Das README trägt den Zustand

Das README richtet sich an jemanden, der das Repository schon geöffnet hat und
wissen will, ob die Sache echt ist.

1. Der Einzeiler und der Statusblock: was der Evaluator heute kann, in
   prüfbaren Begriffen (alle sieben Axiome, exakter Kern, FOLD-Ausgabe).
2. Zwei Programme mit Bild, die jemand nachbauen kann, und der Pfad zum
   eigenen Lauf in vier Zeilen Shell.
3. Die Landkarte: Spezifikation, Decision Records, Entwurfsjournal, Beispiele,
   und was noch nicht Teil der Sprache ist.

### Der Vortrag und das Paper tragen die Semantik

1. Die Auswertung als eigentliche Arbeit: mehrdeutige Axiome, Schichtordnung,
   und der Solver, der die flachfaltende Faltlinie herleitet, die kein Axiom
   konstruiert.
2. Der exakte Kern und der Grund dafür: die Domäne ist dicht an konstruierten
   Koinzidenzen, und genau dort liegt float daneben.
3. Die Enumeration der Mehrfach-Axiome: reproduzierte Zweifach-Zählung, und
   die offene Frage bei drei Faltungen.
4. Der Name, als letzte Folie und nicht als erste: Margherita Piazzolla Beloch
   zeigte 1936, dass Papierfalten allgemeine kubische Gleichungen löst, und
   ihre Faltung ist Axiom 7, das letzte und schwerste Stück der Sprache.

### Bewusst nicht nach vorn

- **Schritt-für-Schritt-Faltdiagramme**, solange sie nicht implementiert sind.
  Der heutige README-Einzeiler verspricht sie. Das gehört korrigiert, bevor
  irgendeine Kampagne läuft.
- **Die Verteidigung der Nicht-Turing-Vollständigkeit.** Wer sie auf der Landing
  führt, stellt die Frage selbst, die er beantworten will. Sie gehört auf eine
  Docs-Seite, die von der Frage aus gefunden wird.
- **Vergleichstabellen gegen vorhandene Werkzeuge.** Ein Einzelprojekt, das eine
  reife Bibliothek in eine Matrix stellt, verliert das Duell unabhängig vom
  Inhalt der Zellen.
- **Die Implementierungssprache als Schlagzeile.** OCaml, Menhir, FLINT und
  js_of_ocaml gehören in den Development-Abschnitt und interessieren dort die
  Richtigen.
- **Die Publikationsplanung.** arXiv, JOSS und OSME sind Absichten. Ein
  Auftritt, der sie ankündigt, lädt dazu ein, sie zu prüfen.
- **Zeitangaben zu Meilensteinen.** Ein Kranich mit Jahreszahl ist eine
  Schuld, die öffentlich fällig wird.

## 5. Tonalitäts-Leitplanken

Die Sprache im Repository ist überwiegend gut: sie benennt Operationen mit
ihren Wirkungen, sie erklärt an Beispielen, und sie sagt, was nicht geht. Die
folgenden Regeln halten sie und entfernen die Muster, die sich eingeschlichen
haben.

**1. Die Wirkung direkt benennen, ohne Gegensatzpaar.**
Do: `fold` carries the paper along the crease; the sheet ends up with two
layers.
Don't: `fold` is not just a line on the paper, it is an actual fold.
Im Repository steht heute "The verb, not the expression, decides whether the
paper actually moves." Die direkte Fassung: "The verb decides whether the paper
moves."

**2. Keine Gedankenstriche als Stilmittel.**
Do: Beloch works out the exact geometry, in your browser.
Don't: Beloch works out the exact geometry — right here in your browser.
Der Gedankenstrich steht heute in fast jedem Absatz von README und Site. Punkt,
Doppelpunkt oder Komma ersetzen ihn jedes Mal, und der Satz wird kürzer.

**3. Zahlen und Namen statt Bewertungsadverbien.**
Do: Axiom 7 has up to three solutions, and the program says which one it means.
Don't: Beloch genuinely handles the really hard axioms properly.
"really", "genuinely", "simply", "actually", "fundamentally" haben in der
Außenprosa keine Funktion.

**4. Grenzen im Indikativ, ohne Entschuldigung.**
Do: Flat folded states only. 3D is a goal and is not implemented.
Don't: 3D support is currently still somewhat limited, but we are working on
it.
Die Appendix-B-Liste der Spezifikation ist das Vorbild: eine Aufzählung dessen,
was noch nicht Teil der Sprache ist, ohne Ton.

**5. Eine Behauptung, ein Beleg.**
Do: The evaluator compares irrational crease coordinates exactly (see the
exactness section of the specification).
Don't: Beloch is fast, exact and elegant.
Dreierlisten aus Eigenschaftswörtern sind das verlässlichste Zeichen, dass die
dritte erfunden wurde.

**6. Einen Begriff wählen und behalten.**
Do: durchgehend "crease". Ein `mark` records a crease, ein `fold` folds along
one.
Don't: abwechselnd "crease", "fold line", "score line", "crease line" im selben
Absatz.
Dasselbe gilt für "evaluator": in Prosa, Spezifikation und Paper steht
"evaluator", auch wenn "compiler" umgangssprachlich durchgeht.

**7. Person und Register festlegen.**
Tutorials sprechen den Leser direkt an ("Toggle this card to its folded view").
Spezifikation und Paper sind unpersönlich. Auf der Landing und im README gilt
für ein Einzelprojekt die dritte Person über das Projekt: "Beloch emits FOLD"
statt "we emit FOLD". Ein "we", hinter dem eine Person steht, ist überprüfbar
und wird überprüft.

**8. Keine Produktverben.**
Verboten: empower, unlock, seamless, powerful, leverage, revolutionize, "take
X to the next level". Diese Wörter kommen im Repository bisher nicht vor, und
das bleibt so.

**9. Über vorhandene Werkzeuge in Funktionen sprechen, nicht in Rängen.**
Do: Rabbit Ear reads Beloch's FOLD directly and is the recommended viewer
today.
Don't: Unlike existing JavaScript libraries, Beloch gives you real guarantees.

**10. Jede Außenseite steht für sich.**
Ein Satz auf der Site verweist auf einen Decision Record oder einen
Spezifikationsabschnitt, wenn der Leser weiterlesen soll. Er setzt nicht
voraus, dass der Leser ihn gelesen hat.

### Schnellprüfung vor dem Veröffentlichen

```sh
rg -n -i -e '\bnot just .*(but|it)\b' -e "isn't .*\. It'?s" \
       -e ', not [a-z]+\.$' -e 'is (exactly )?the point' \
       -e 'which is what (makes|lets|allows)' \
       -e '—' -e '\b(really|genuinely|simply|actually|fundamentally)\b' \
       README.md packages/www/src/
```

## 6. Warum das existiert

Fassung für die Landing, unter dem Playground, als eigener Abschnitt mit der
Überschrift "Why a language". Sie nennt die vorhandene Arbeit beim Namen, bevor
jemand danach fragt, und beantwortet die Frage aus eigener Kraft.

> **Why a language**
>
> Origami math already has good software. Rabbit Ear gives you the seven axioms
> as JavaScript functions, crease-pattern math and a folding simulator. It reads
> Beloch's FOLD output directly, and it is the viewer this project recommends
> today.
>
> Beloch answers a different question: what is the file you keep? A `.bel`
> program is the folding sequence itself. One line is one fold, a diff shows one
> changed fold, and the evaluator can read the whole program ahead of time,
> because the language has no loops and no escape hatch. A folding sequence in a
> general-purpose script is a program about folding; here it is the folding.
>
> The second reason is arithmetic. Axiom 7 puts two points onto two lines at
> once, which solves a cubic and can have three solutions. Beloch computes
> them over exact real algebraic numbers, so the question "does this point lie
> on that crease" has an answer instead of a tolerance. Origami is dense in
> engineered coincidences, and those are the cases floating point gets wrong.

Was diese Fassung vermeidet: sie rechtfertigt nichts, sie vergleicht keine
Feature-Listen, und sie behauptet keine Überlegenheit. Sie nennt eine andere
Frage und beantwortet sie. Der Absatz über Turing-Vollständigkeit steht
bewusst nicht darin; er gehört in eine FAQ-Seite unter der Frage, in der er
gestellt wird.

Für das README genügt die Kurzfassung in zwei Sätzen: "Rabbit Ear is the
recommended viewer and reads Beloch's FOLD directly. Beloch owns the step
before that: the source file that is the folding sequence, evaluated exactly."

## 7. Risiken der Positionierung

**Reifegrad gegen Anspruch.** Die Version ist vorstellig, es gibt keine Releases
und keine Binaries, und der Kranich steht aus. Konkreter Angriffspunkt: der
README-Einzeiler verspricht heute "step-by-step folding diagrams", und die sind
nicht implementiert. Derselbe Text verweist auf eine Kubikwurzel-Konstruktion
in `examples/`, die dort nicht liegt. Beides gehört korrigiert, bevor der
Auftritt Aufmerksamkeit anzieht, denn ein Leser, der die erste Behauptung
prüft und sie nicht bestätigt findet, prüft die zweite nicht mehr.

**Ein-Personen-Projekt.** Der Busfaktor ist eins, und das sieht jeder in der
Commit-Historie. Der Auftritt verdeckt das nicht durch ein "we". Was die Sorge
entkräftet, liegt bereits vor: eine permissive Lizenz, ein standardisiertes
Ausgabeformat, das andere Werkzeuge weiterlesen, eine Spezifikation, die die
Sprache beschreibt statt der Implementierung, und ein lückenloser
Entscheidungspfad. Diese vier Punkte gehören sichtbar ins README, formuliert
als Beschreibung des Repositories.

**Nicht-Turing-Vollständigkeit als vermeintlicher Mangel.** Die Antwort steht
fest, und ihre Platzierung ist das Risiko. Auf der Landing geführt, macht sie
aus einer Eigenschaft eine Verteidigungslinie. Zweites Risiko in der Antwort
selbst: die Analogien zu SQL und Dhall klingen geborgt, solange kein eigener
Beleg danebensteht. Der eigene Beleg ist die Schrittableitung aus dem Programm,
und bis sie existiert, bleibt die Antwort kurz und verweist auf die
Analysierbarkeit, die der Solver schon nutzt.

**Neuheitsanspruch bei den Mehrfach-Axiomen.** Die Recherche stützt sich auf
einen Zitationspfad, eine OEIS-Suche und einen Preprint-Abgleich; ein Abgleich
mit der gesetzten Fassung des Sammelbands steht aus, ebenso die Beschaffung der
nächstliegenden Dreifach-Arbeit. "The first enumeration of three-fold axioms"
ist deshalb angreifbar, "we reproduce Alperin and Lang's 489 and 203" ist
prüfbar. Öffentliche Formulierung bis zum Abschluss der Prüfung: "no
enumeration for three folds is known to us; Alperin and Lang stop at two."

**Name und Auffindbarkeit.** "Beloch" kollidiert im Technikumfeld kaum und im
geisteswissenschaftlichen stark, wo Karl Julius Beloch die Suchergebnisse
besetzt. Die Herkunft des Namens gehört deshalb in einem Satz auf jede
Einstiegsseite, weil sie zugleich die Geschichte ist, die niemand vergisst.
Zweites Risiko: zwei Domains teilen die Autorität. Eine Adresse ist die
kanonische, die andere leitet weiter.

**Zwei Communities, ein Auftritt.** PL-Leser finden die Geometrie fremd,
Origami-Leser die Sprachtheorie. Ein Text, der beide gleichzeitig bedient,
verliert beide. Die Auflösung: die Landing spricht in der Sprache der Faltung,
weil der Playground dort sofort trägt, und der Einstieg für PL-Leser ist ein
eigener Sprungpunkt in Spezifikation und Decision Records, prominent genug, dass
er als erster Link gefunden wird.

**Exaktheit als unbegrenztes Versprechen.** Der Zahlenkern hat eine Gradschranke,
und lange Modelle können sie erreichen. Wenn das öffentlich zuerst einem
Besucher passiert, wird aus "exact" ein Angriffspunkt. Der Auftritt belegt
Exaktheit deshalb an den Axiomen und an konkreten Konstruktionen und behauptet
keine Skalierbarkeit, die noch nicht gemessen ist.
