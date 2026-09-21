# Auftritts-Audit: alle öffentlichen Oberflächen von Beloch

Stand 2026-09-21. Geprüft gegen `main` bei `f69217fe` und gegen die live
ausgelieferte Seite unter `https://beloch.toph.so`.

## Quellenlage

Der lokale Arbeitsbaum steht auf `bb60d2d4` (2026-09-12) und ist rund 40
Commits hinter `main`. In der Zwischenzeit hat sich der Auftritt an zwei
Stellen verändert, die für dieses Audit zentral sind:

- `packages/www/src/content/docs/introduction.mdx` und das gesamte
  Verzeichnis `tutorials/` existieren auf `main` nicht mehr. An ihre Stelle
  sind vier Referenzdokumente getreten: `model.md`, `kernel.md`,
  `language.md`, `output.md`.
- Die Beispiel-Chips unter dem Hero sind aus `packages/www/src/pages/index.astro`
  entfernt worden. Der Hero lädt heute `examples/bases/bird-base.bel`.

Zeilenverweise beziehen sich auf `main`. `packages/www/src/components/Playground.astro`
ist in beiden Ständen bis auf eine Symbolumbenennung identisch, die Zeilennummern
gelten dort für beide.

---

## 1. Oberflächen-Inventar

### Live und öffentlich erreichbar

| Fläche | Zweck | Publikum | Zustand |
|---|---|---|---|
| Landing `https://beloch.toph.so/` | Erstkontakt, ein Satz plus lauffähiges Beispiel | Zufallsbesucher aus HN, Mastodon, Suchmaschine | Eine einzige Sektion: Kopfzeile, Titel, zwei Absätze, Playground, Fußzeile. Kein zweiter Abschnitt, kein Statusblock, kein Installationsweg. `packages/www/src/pages/index.astro:70-88` |
| Playground (im Hero eingebettet) | Sprache ausprobieren ohne Installation | dieselbe Gruppe, plus Docs-Leser | Funktional weit: CodeMirror, Schritt-Scrubber, Pan/Zoom, Entity-Inspektor, Papier-Farbschemata. Der Einstieg ist beschädigt, siehe Abschnitt 3 |
| Referenzdocs `/model/`, `/kernel/`, `/language/`, `/output/` | formale Beschreibung von Modell, Kern, Sprache, Ausgabe | Leser mit Origami- oder PL-Hintergrund, Gutachter | Vollständig gesetzt, mit KaTeX, Zitaten aus `paper/references.bib`, Pagefind-Suche, eigenem Sidebar-Kollaps. `model.md` allein hat 1160 Zeilen |
| GitHub `github.com/tophcodes/beloch` | Code, Issues, Historie | Entwickler, potenzielle Mitwirkende | Beschreibung, Homepage und sieben Topics gesetzt, MIT, 28 offene Issues, 1 Stern, 0 Releases, 0 Tags |
| README auf GitHub | 30-Sekunden-Erklärung im Repo | wie oben | Siehe Abschnitt 2. Zwei gerenderte Beispielpaare, ein Statusblock, ein Layout-Block |
| Forgejo-Spiegel `git.toph.so/toph/beloch` | kanonisches Hosting laut ADR 0005 | Selbsthoster, Direktverlinkung | Öffentlich erreichbar (HTTP 200), zeigt dasselbe README. Keine eigene Landingseite, kein Release-Bereich |
| Favicon `packages/www/public/favicon.svg` | Bildzeichen in Tab, Lesezeichen, Verlauf | alle | Achtstrahliger Stern mit vier Eckpunkten, `fill` über `prefers-color-scheme` gesetzt. Kein Origami-Bezug, liest sich als generisches Funkel-Glyph. Das einzige Markenasset im gesamten Repo |
| `beloch` CLI | eigentliche Nutzung | wer das Repo baut | `fold` implementiert, `check` und `lsp` geben "not yet implemented" aus, `render` hängt an einem zweiten Binary auf `PATH`. `packages/core/bin/main.ml:14-35` |

### Vorhanden, aber nicht veröffentlicht

| Fläche | Zweck | Publikum | Zustand |
|---|---|---|---|
| VS-Code-Extension `packages/vscode/` | Syntax-Highlighting für `.bel` | Nutzer, die eine Datei schreiben | `"private": true`, Version `0.0.1`, `repository` zeigt auf Forgejo. `marketplace.visualstudio.com/items?itemName=toph.beloch` antwortet 404. Kein Icon, keine Marketplace-README, kein `LICENSE` im Extension-Ordner |
| tree-sitter-Grammatik `packages/grammar/` | Highlighting in Neovim, Helix, Zed | dieselbe Gruppe | `"private": true`, `registry.npmjs.org/tree-sitter-beloch` antwortet 404. Nicht im `nvim-treesitter`-Register |
| Beispielkorpus `examples/` | Belege, Kopiervorlagen | alle | 6 `.bel`-Dateien in `bases/`, 10 vorgerenderte SVGs. Keine Galerieseite, kein Index, kein README im Verzeichnis |
| ADRs `decisions/` | Architekturbegründung | technisch interessierte Leser | 20 Records, öffentlich im Repo, nirgends von der Website verlinkt |
| Designtagebuch `notes/` | Werkstattbericht | dieselbe Gruppe | 42 datierte Notizen, öffentlich im Repo, nirgends verlinkt |
| Spezifikation `spec/` | Vertrag der Sprache | Implementierer | `SPECIFICATION.md` mit 114 KB plus `MODEL.md`, `KERNEL.md`, `BELOCH.md`, `FOLD.md`. Die Website zitiert diese Dateinamen, verlinkt sie aber nicht |

### Kommend, aus der akademischen Seite

| Fläche | Zweck | Publikum | Zustand |
|---|---|---|---|
| arXiv-Preprint | Eintritt in den Zitationsgraphen | Forschung | `paper/README.md:14-18` legt `cs.PL` mit Cross-List `cs.CG` fest und nennt die Endorsement-Hürde. Kein Outline, bewusst zurückgestellt bis Kranich oder Vogelbasis durchlaufen (`paper/README.md:7-10`). Die Vogelbasis läuft inzwischen, das ist der Auslöser |
| JOSS-Paper | zitierfähige Software-Veröffentlichung | Forschung, Nutzer | `paper/README.md:19-20`. Zwei Seiten, Kriterium ist Dokumentation und Tests. Näher an der Reichweite als arXiv |
| 9OSME Xi'an, August 2027 | Vortrag plus Proceedings-Kapitel | Origami-Fachcommunity | `paper/README.md:22-28`. Track "Computation" nimmt System- und Sprachpapiere. Springer-Template soll laut Notiz früh eingecheckt werden |
| OSME-Foliensatz | der Vortrag selbst | Saalpublikum | Existiert nicht. Aussprache und Namensgeschichte sind in `decisions/0005-name-beloch.md:20-35` bereits als Bühnenmaterial angelegt |
| Konferenz-Handout | Mitnahme-Artefakt mit QR auf den Playground | dieselbe Gruppe | Existiert nicht |

| Forschungsergebnis | in ein separates, nicht-öffentliches Repository ausgelagert | nicht Teil dieses Repos |
| Forschungsergebnis | in ein separates, nicht-öffentliches Repository ausgelagert | nicht Teil dieses Repos |
| Devlog aus `notes/` | Werkstattbericht als Publikum-Oberfläche | technisch interessierte Leser | Das Konzept steht in `notes/2026-06-28-blog-tooling-design.md`. Die Pipeline, die es brauchte, existiert inzwischen als `<Beloch>`-Komponente. Der Rohstoff sind 42 Notizen |

### Fehlende Flächen mit hoher Wirkung

| Fläche | Zustand |
|---|---|
| Repo-Social-Preview-Bild | Kein Bildasset im Repo außer dem Favicon. Der Tree auf `main` enthält 598 Pfade, darunter ein einziges Markenbild |
| Open-Graph-Karte der Website | Die Landing setzt `charset`, `viewport`, `title`, `description`, `icon` und sonst nichts (`packages/www/src/pages/index.astro:31-39`). Die Starlight-Seiten setzen `og:title`, `og:description` und `twitter:card="summary_large_image"`, aber kein `og:image`. Die angekündigte große Bildkarte bleibt leer |
| Release-Artefakte | 0 Tags, 0 Releases, keine Binaries |
| Changelog | Existiert nicht |
| Beispielgalerie | Existiert nicht |
| Zitationsdatei | Kein `CITATION.cff` |
| Beitragsleitfaden | Kein `CONTRIBUTING.md` |

---

## 2. Audit der Landing

### Was die Seite verspricht

Drei Textbausteine, sonst nichts:

- `packages/www/src/pages/index.astro:72` Titel `Beloch`
- `:73-75` Unterzeile, wörtlich: `A declarative language for origami, built on the Huzita-Justin axioms.` (die Seite setzt dort einen Halbgeviertstrich)
- `:76-79` `Describe a sheet and the creases you want; Beloch works out the exact geometry, right here in your browser.`

Das Versprechen "right here in your browser" ist das einzige Handlungsversprechen der Seite, und der Playground ist die einzige Einlösung. Alles, was ein technischer Leser sonst sucht, fehlt auf der Seite: Reifegrad, Installationsweg, Abgrenzung zu Rabbit Ear, Beispiele, Lizenz.

### Was ein Erstbesucher in dieser Reihenfolge erlebt

**Sekunde 0.** Dunkle Seite, erzwungen unabhängig von der Systemeinstellung (`:45-54`). Kopfzeile mit Wortmarke, zwei Links und einem Themenschalter (`:58-68`). Die Navigation besteht aus "Docs" und "GitHub" (`:24-27`). Es gibt keinen dritten Weg, also auch keinen Einstieg für jemanden, der nicht sofort eine formale Referenz oder ein Repository öffnen will.

**Sekunde 2.** Der Hero erscheint. Links eine Codespalte, rechts eine gefaltete Vogelbasis als fertiges SVG, aus dem Build (`:80`, `Playground.astro:1595-1602`). Das ist die stärkste Sekunde der ganzen Seite: sofort sichtbare Geometrie, ohne Ladezeit, ohne Klick.

**Sekunde 3.** Der Blick geht nach links. Dort stehen zwölf Zeilen Quellenkommentar, bevor die erste Anweisung kommt. `packages/www/src/lib/landing-examples.ts:12-14` liest `examples/bases/bird-base.bel` vollständig ein, und diese Datei beginnt in `examples/bases/bird-base.bel:1-12` mit:

```
; Bird base by the Eos route [ida2020, Fig. 7.19]: the preliminary base, then
; each of the four side corners inside-reversed along the kite crease through
...
; [ida2020, Fig. 7.20(h), p. 194]. Checked against her figures in
; notes/2026-09-12-bird-base-oracle.md.
```

Bei einer Editorhöhe von 380px und 22px Zeilenhöhe sind etwa 17 Zeilen sichtbar. Der Besucher sieht also den Kommentarblock, eine Leerzeile, `paper square`, eine Leerzeile und zwei Anweisungen. Die Sprache, die das Versprechen tragen soll, steht unterhalb des sichtbaren Bereichs. Der Verweis auf `notes/2026-09-12-bird-base-oracle.md` führt ins Leere, weil die Datei als Repopfad geschrieben ist.

Am Dateiende stehen außerdem Testzusicherungen (`examples/bases/bird-base.bel:35-53`): `; assert steps = 7`, `; assert faces = 14`, `; assert .sr = .bl`. Das Begrüßungsprogramm ist eine Testfixture. Die Ursache ist die Kommentarbegründung in `landing-examples.ts:1-4`, die Drift zwischen Landing und Korpus verhindern will. Das Ziel ist richtig, der gewählte Weg schiebt dem Besucher den Prüfapparat auf den Tisch.

**Sekunde 5.** In der Mitte der Fläche steht ein großer runder Play-Knopf (`Playground.astro:82-87`, positioniert über `:139-145`). Er ist ausgegraut. `Playground.astro:787-794` schaltet ihn nur frei, wenn der Editorinhalt vom zuletzt gelaufenen Text abweicht, und beim ersten Laden sind beide gleich. Sein `title` lautet dann "Change the code to run again". Das auffälligste Bedienelement der Seite ist im Moment des Erstkontakts tot, und die einzige Erklärung ist ein Tooltip, den niemand sucht.

**Sekunde 8.** Unter der Ausgabe liegt eine Schrittleiste mit acht Punkten (`Playground.astro:65-80`). Sie funktioniert sofort, ohne wasm, weil der Seed-FOLD clientseitig geparst wird. Sie ist die zweitstärkste Eigenschaft der Seite und nirgends beschriftet. Das Label sagt "Step 7/7" und erklärt weder, dass die Punkte anklickbar sind, noch dass sie den Programmzeilen entsprechen.

**Sekunde 12.** Der Besucher scrollt. Steht der Zeiger dabei über dem Playground, passiert nichts: `Playground.astro:669-686` ruft bei jedem Rad-Ereignis `e.preventDefault()` auf, sobald Pan/Zoom aktiv ist, und der Hero ist über `index.astro:173-182` auf volle Fensterbreite gezogen. Auf dem Telefon verschärft sich das, weil `Playground.astro:248-249` `touch-action: none` setzt und die Spalten unter 720px untereinander rutschen (`:105-107`). Der Hero füllt dort das Fenster und fängt die Wischgeste ab.

**Sekunde 15.** Wer am Playground vorbeiscrollt, erreicht direkt die Fußzeile mit denselben zwei Links wie oben (`index.astro:84-88`). Die Seite ist zu Ende. Es gibt keinen zweiten Abschnitt.

### Wo Erwartung und Einlösung auseinanderlaufen

1. **Der Verweis auf die Huzita-Justin-Axiome wird nirgends eingelöst.** Kein Axiom ist auf der Landing sichtbar, kein Link zu einer Erklärung. Die Behauptung steht in der Unterzeile (`index.astro:73-75`) und bleibt unbelegt, bis der Besucher in `/language/` einsteigt.

2. **"right here in your browser" ist an einen ausgegrauten Knopf gebunden.** Das Versprechen sagt, der Besucher könne etwas ausführen. Das Interface sagt, er könne es nicht, bevor er etwas ändert. Der Weg von "ich will es laufen sehen" nach "ich muss erst den Text verändern" ist nirgends beschrieben.

3. **"Docs" führt in die Mitte eines Vierersatzes.** Der Link zeigt auf `/language/` (`index.astro:25`). Dessen erster Absatz erklärt in `packages/www/src/content/docs/language.md:9-17`, dass drei Dokumente die Sprache beschreiben und `MODEL.md` die Mathematik ist. Die Sidebar listet "The model" als erstes (`packages/www/astro.config.mjs:102-105`). Der Einstiegspunkt der Navigation widerspricht der Lesereihenfolge, die das Dokument selbst vorgibt.

4. **Die Seite sagt nichts über Reife.** Die README hat einen Statusblock (`README.md:6-10`), die Website hat keinen. Ein Besucher kann nicht unterscheiden, ob er ein fertiges Werkzeug oder ein laufendes Forschungsprojekt vor sich hat. Die ehrliche Antwort steht im Repo: Version `0.3.0-dev`, keine Tags, keine Releases, `check` und `lsp` sind Stubs.

5. **Die Seite hat keine Linkvorschau.** `index.astro:31-39` setzt kein `og:image`, kein `og:title`, kein `og:description` als Open-Graph-Feld. Ein geteilter Link auf Mastodon oder in Slack erscheint als nackte URL. Die Docs-Seiten kündigen über `twitter:card="summary_large_image"` eine Bildkarte an und liefern kein Bild.

6. **Tote Altpfade.** `/introduction/` und `/tutorials/paper-and-values/` antworten heute mit 404. Beide waren bis zur Umstrukturierung Ziel der Hauptnavigation und stehen in Suchmaschinenindizes und in älteren Tutorialtexten. Für `/playground/` gibt es eine Weiterleitung (`packages/www/astro.config.mjs:56-60`), für die Lernpfad-Pfade keine.

7. **Das Bildzeichen trägt nichts.** `packages/www/public/favicon.svg` zeigt einen achtstrahligen Stern. Weder Papier noch Faltung noch Achse noch Buchstabe. In einer Tableiste neben zwanzig anderen Tabs ist das Zeichen nicht wiedererkennbar und nicht zuordenbar.

### Designsprache gegen Starlight-Default

`packages/www/src/styles/theme.css` sagt in seinem eigenen Kopfkommentar, was es sein will: funktionale Tokens, alles Kosmetische bleibt bei Starlight. Das hält es auch. Eigenes Design sind:

- Die Faltsemantik: `--beloch-valley` und `--beloch-mountain` in beiden Themen (`theme.css:19-21`, `:42-43`). Das ist der einzige Farbwert mit Bedeutung, und er ist konsistent durchgezogen.
- Die dunkle Codefläche `--beloch-code-bg`, in beiden Themen dunkel (`theme.css:23-24`).
- Das Syntax-Token-Schema. Es ist von 8 Klassen (`theme.css:60-67`) auf 22 gewachsen: 14 neue Sortenfarben in `:71-84` plus 6 Figurenfarben in `:96-101`. Mehrere Werte liegen perzeptuell nebeneinander, etwa `.bel-construction #8FA6D9` gegen `.bel-alignment #7C93C4` und `.bel-anchor #E0A458` gegen `.bel-order #C2A66B`. Ein System, das diese Zuordnung begründet, ist nicht dokumentiert.
- Die `<Beloch>`-Karte, die aus der Textspalte ausbricht (`theme.css:49-55`).
- Die Landing selbst umgeht Starlight komplett und bringt ihren eigenen Reset und ihr eigenes Layout mit (`index.astro:90-194`).

Starlight-Default sind Schrift, Grundpalette, Layout, Sidebar-Grundgerüst, Suche und alle Docs-Typografie. Die Marke besteht heute aus zwei Kreisfarben, einer Monospace-Wortmarke und einer dunklen Codefläche. Ein Wortmarken-Asset, eine Bildmarke mit Faltbezug und eine Regel für die Tokenfarben fehlen.

---

## 3. Playground-UX: die gravierendsten Probleme

### 3.1 Der Run-Knopf ist beim Erstkontakt tot

**Beleg.** `Playground.astro:787-794`: `runBtn.disabled = running || !dirty` mit `dirty = editor.state.doc.toString() !== lastRunCode`, und `lastRunCode` wird in `:786` auf den Anfangstext gesetzt. Gestylt wird der Zustand in `:162-166` als graue Umrandung ohne weitere Erklärung.

**Folge.** Das prominenteste Element der Landingseite, ein 44px-Kreis in der Flächenmitte, lädt zum Klick ein und reagiert nicht. Die Begründung dahinter ist nachvollziehbar: das Ergebnis steht bereits da, ein Lauf würde dasselbe Bild erzeugen und 2,3 MB Netzverkehr kosten. Dem Besucher wird davon nichts mitgeteilt.

**Einordnung.** Designproblem. Die Technik erlaubt jeden Zustand, gewählt wurde eine Deaktivierung ohne sichtbare Begründung. Eine bereits am Ort vorhandene Fläche, das `role="status"`-Element in `:88`, könnte die Erklärung tragen.

### 3.2 Der Ausführungs-Timeout deckt den wasm-Download mit ab

**Beleg.** `Playground.astro:589` setzt `TIMEOUT_MS = 8000`. `:1563-1587` startet den Timer unmittelbar nach `bootIfNeeded()` und vor `worker.postMessage()`. Beim ersten Lauf lädt der Worker `/beloch/qqbar-wasm.js`, ausgeliefert mit Brotli in 2.269.007 Bytes, plus `beloch-eval.js` mit 114.520 Bytes. Läuft der Timer ab, terminiert `:1576` den Worker, baut ihn neu auf und zeigt `showError("Evaluation aborted (timeout).")`.

**Folge.** Auf einer Verbindung unter etwa 2,5 Mbit/s scheitert der erste Lauf zuverlässig, und die Fehlermeldung beschuldigt den Evaluator statt das Netz. Schlimmer: der Neuaufbau in `:1577` verwirft den bereits geladenen Teil, der nächste Klick beginnt von vorn, und der Besucher landet in einer Schleife identischer Fehlschläge.

**Einordnung.** Technikproblem mit Designanteil. Die Trennung von Ladezeit und Rechenzeit gehört in zwei getrennte Zeitgrenzen, und der Wartezustand braucht eine Fortschrittsanzeige statt einer Pille mit `white-space: nowrap` und `text-overflow: ellipsis` (`:182-200`), deren Text "loading playground runtime …" die Größenordnung verschweigt.

### 3.3 Ein Fehler löscht das Ergebnis

**Beleg.** `Playground.astro:1376-1381`: `showNotice` setzt `canvas.innerHTML = html`, ruft `panZoom.reset()`, schaltet Pan/Zoom ab und versteckt den Reset-Knopf. Jeder Fehlerweg geht dort hindurch: die Evaluator-Diagnose (`:1542`), der Renderfehler (`:1487`, `:1519`), die ungültige Worker-Antwort (`:1529`), der Worker-Absturz (`:1550`) und der Timeout (`:1583`).

**Folge.** Ein Tippfehler in Zeile 9 löscht die gefaltete Vogelbasis und hinterlässt einen roten Satz auf leerem Grund. Der Besucher verliert genau die Referenz, gegen die er den Fehler verstehen müsste. Dazu kommt, dass die Diagnose als reiner Text landet: keine Zeilenmarkierung im Editor, kein Sprung zur Fundstelle, obwohl `setStepLineOn` (`:1484`) genau diese Fähigkeit für die Schrittanzeige bereits besitzt und die CLI in `packages/core/bin/main.ml:47` bereits eine Diagnose mit Quellkontext rendert.

**Einordnung.** Designproblem. Die Bausteine für eine bessere Lösung liegen im selben Modul.

### 3.4 Kein Tastaturweg zu dem, was die Fläche kann

**Beleg.** Ausführen geht per `Mod-Enter` (`Playground.astro:808-816`). Alles andere ist zeigergebunden:

- Pan und Zoom hängen an `wheel`, `pointerdown`, `pointermove` (`:669-727`). Kein Tastaturäquivalent, der Container ist nicht fokussierbar.
- Der Entity-Inspektor öffnet über `mousemove` (`:1229`) und `click` (`:1256`). Die SVG-Treffer­flächen aus `enhanceCreaseHits` sind keine fokussierbaren Elemente.
- Fehlermeldungen werden nie angesagt. Das einzige Live-Element ist `.pg-run-hint` (`:88`), und `finish()` leert es in `:1499`, bevor der Handler in `:1500` den Fehler setzt. Die Fehlerfläche selbst (`:416-425`) hat kein `role` und kein `aria-live`.
- `prefers-reduced-motion` kommt in der gesamten Datei nicht vor, der Spinner in `:167-180` dreht unabhängig davon.

**Folge.** Wer mit Tastatur oder Screenreader arbeitet, kann den Text ändern, ausführen, und erfährt vom Ergebnis nichts. Der Schritt-Scrubber ist die eine Ausnahme: seine Punkte sind echte `<button>` mit `aria-label` und `aria-current` (`:1413-1418`, `:1445`).

**Einordnung.** Designproblem, mit klarer technischer Abhilfe. Die Fehlerfläche braucht `role="alert"`, die Ausgabe eine Tastaturbedienung für Pan/Zoom und fokussierbare Trefferflächen.

### 3.5 Die Ausgabe fängt das Seitenscrollen

**Beleg.** `Playground.astro:669-686` ruft `e.preventDefault()` bei jedem Radereignis, solange Pan/Zoom aktiv ist, registriert mit `{ passive: false }`. `:248-249` setzt zusätzlich `touch-action: none`. `index.astro:173-182` zieht den Playground auf volle Fensterbreite. `Playground.astro:105-107` stapelt die Spalten unter 720px.

**Folge.** Auf dem Desktop hält jede Radbewegung über dem Hero die Seite fest. Auf dem Telefon füllt der gestapelte Playground das Fenster, und die Wischgeste wird als Pan gedeutet. Der Besucher kommt nicht zur Fußzeile, und auf der Landing gibt es auch sonst nichts, wohin er käme.

**Einordnung.** Technikproblem. Der übliche Weg ist Zoom nur mit gedrückter Modifikatortaste oder nach einem expliziten Klick in die Fläche, und `touch-action: pan-y` statt `none`.

---

## 4. Lücken im Auftritt

Sortiert nach dem, was bei technischem Publikum am meisten trägt.

**Status-Ehrlichkeit auf der Website.** Die README hat einen Statusblock (`README.md:6-10`), die Website keinen. Der ehrliche Stand ist gut belegbar: sieben Axiome implementiert, exakter reell-algebraischer Kern, FOLD-Ausgabe, Vogelbasis läuft gegen Idas Figuren, Version `0.3.0-dev`, `check` und `lsp` sind Stubs. Ein technischer Leser verzeiht einen frühen Stand und verzeiht keine Unklarheit darüber. `packages/www/src/content/docs/model.md:32-40` macht das innerhalb der Docs bereits vorbildlich mit einem Abschnitt "Review status" pro Kapitel. Diese Ehrlichkeit fehlt an der Stelle, wo sie zuerst gebraucht wird.

**Installationsweg.** Die einzige Anleitung ist `direnv allow`, `dune build` in `README.md:70-80`. Wer kein Nix hat, kommt nicht an das Binary. Es gibt keine Releases, keine Tags, kein opam-Paket, keine statisch gelinkte Datei. Die Folge steht in der eigenen Doku: `packages/www/DEPLOY.md:3-8` beschreibt, dass sogar der eigene Build den `beloch`-Binary auf `PATH` braucht und Cloudflares Buildpfad daran scheitert.

**"Why not Rabbit Ear".** Die Antwort existiert seit `decisions/0009-relationship-to-rabbit-ear.md` in vollständiger Form: Sprache gegen Bibliothek, nicht Turing-vollständig als Merkmal, `.bel`-Quelle als analysierbares Artefakt, Rabbit Ear als Konsument der FOLD-Ausgabe. Sie steht in einem ADR, das von keiner öffentlichen Seite verlinkt wird. Das ist die erste Frage jedes Lesers, der sich mit dem Feld auskennt, und die Antwort ist fertig geschrieben.

**Beispielgalerie.** `examples/bases/` enthält 6 Programme und 10 vorgerenderte SVG-Paare. Die README zeigt zwei davon. Es gibt keine Seite, die alle zeigt, keinen Weg, ein Beispiel im Playground zu öffnen, und keinen Index im Verzeichnis. Nach der Entfernung der Beispiel-Chips ist der Vogelbasis-Hero das einzige Programm auf der ganzen Website.

**Zitierbarkeit.** Kein `CITATION.cff`, kein DOI, keine Releaseversion, auf die sich ein Paper beziehen könnte. Das Projekt hat eine 34-KB-Bibliografie und einen publikationsfähigen Befund zur Alperin-Lang-Liste, und ist selbst nicht zitierbar. Ein Zenodo-DOI über einen GitHub-Release und eine `CITATION.cff` kosten einen Nachmittag.

**Changelog.** Existiert nicht. Die Sprache hat sich zwischen `bb60d2d4` und `f69217fe` in der Schreibweise geändert, von `mark --diag = map .a onto .c` zu `mark (map .a onto .c) as --diag`. Das ist ein brechender Syntaxwechsel ohne jede öffentliche Notiz. Wer ein `.bel` aus der alten README kopiert, bekommt einen Parserfehler ohne Erklärung.

**Ein Einstieg, der kein Beweis ist.** Zwischen der Landing, die aus drei Sätzen besteht, und `/model/` mit 1160 Zeilen Definitionen, Lemmata und KaTeX liegt nichts mehr. Die fünf Tutorials, die diesen Weg gefüllt haben, sind gelöscht. Sie waren gut gebaut: jede Seite eine Idee, jede mit gerenderter Ausgabe neben dem Code, jede mit einem "What you learned" und einem Verweis auf die nächste. Ihre Syntax ist veraltet, ihre Struktur nicht.

**Linkvorschau und Bildmarke.** Kein `og:image`, kein Social-Preview im Repo, ein Favicon ohne Bezug zum Gegenstand. Ein geteilter Link erzeugt heute keine Aufmerksamkeit. Bei einem Projekt, dessen Ergebnis buchstäblich ein Bild ist, ist das die am einfachsten zu schließende Lücke mit der größten Reichweitenwirkung.

**Tote Pfade.** `/introduction/` und `/tutorials/*` antworten mit 404 statt mit einer Weiterleitung. Das Muster für die Abhilfe steht in `packages/www/astro.config.mjs:56-60`.

---

## 5. Priorisierte Maßnahmen

### Stufe 1: kleiner Aufwand, sofortige Wirkung

| # | Maßnahme | Beleg |
|---|---|---|
| 1 | Weiterleitungen für `/introduction/` und `/tutorials/*` auf `/model/` oder eine neue Einstiegsseite | `astro.config.mjs:56-60` hat das Muster |
| 2 | Hero-Programm vom Kommentarkopf und den `assert`-Zeilen befreien: eine schlanke Anzeigefassung, gegen `examples/bases/bird-base.bel` in CI geprüft, statt der Rohdatei | `landing-examples.ts:12-14`, `examples/bases/bird-base.bel:1-12,35-53` |
| 3 | Run-Knopf im Ruhezustand freischalten und den Grund in die vorhandene Statusleiste schreiben, statt ihn auszugrauen | `Playground.astro:787-794`, `:88` |
| 4 | Fehlerfläche `role="alert"` geben und den Live-Bereich nicht vor dem Handler leeren | `Playground.astro:416-425`, `:1493-1501` |
| 5 | Zoom an eine Modifikatortaste binden, `touch-action: pan-y` setzen | `Playground.astro:669-686`, `:248-249` |
| 6 | Statuszeile auf die Landing: Version, Reifegrad, was fehlt. Text aus `README.md:6-10` plus die Stub-Liste aus `packages/core/bin/main.ml:19-23` | |
| 7 | `og:image` und Repo-Social-Preview aus einem vorhandenen Faltbild, etwa `examples/bases/bird-base-folded.svg` auf dunklem Grund mit Wortmarke | `index.astro:31-39` |
| 8 | `CITATION.cff` im Repowurzelverzeichnis | |

### Stufe 2: mittlerer Aufwand, hoher Hebel

| # | Maßnahme | Beleg |
|---|---|---|
| 9 | Zwei getrennte Zeitgrenzen im Playground: eine für den Laufzeit-Download mit Fortschritt und Größenangabe, eine für die Auswertung | `Playground.astro:589`, `:1563-1587` |
| 10 | Fehler neben dem Ergebnis statt an dessen Stelle, mit Zeilenmarkierung im Editor über den vorhandenen `setStepLineOn`-Weg | `Playground.astro:1376-1387`, `:1484` |
| 11 | Beispielgalerie als eigene Seite: alle Programme aus `examples/` mit Vorschaupaar, Quelltext und einem Knopf, der das Programm im Playground öffnet | |
| 12 | Seite "Why Beloch", die `decisions/0009-relationship-to-rabbit-ear.md` in Lesefassung bringt und von der Hauptnavigation verlinkt ist | |
| 13 | Einstiegsseite vor die Referenz stellen und die Navigation dorthin zeigen lassen, statt in `/language/` | `index.astro:25`, `language.md:9-17`, `astro.config.mjs:98-108` |
| 14 | Tutorials in aktueller Syntax wiederherstellen, Struktur der gelöschten fünf Seiten übernehmen | |
| 15 | Changelog anlegen und rückwirkend die Syntaxwechsel eintragen, angefangen bei `mark ... = ...` nach `mark (...) as ...` | |
| 16 | Tastaturbedienung für die Ausgabe: fokussierbarer Container, Pfeiltasten für Pan, `+`/`-` für Zoom, fokussierbare Trefferflächen für den Inspektor | `Playground.astro:669-727`, `:1229`, `:1256` |
| 17 | Bildmarke mit Faltbezug entwerfen und Favicon ersetzen | `packages/www/public/favicon.svg` |

### Stufe 3: großer Aufwand, strategische Wirkung

| # | Maßnahme | Beleg |
|---|---|---|
| 18 | Releasepfad: getaggte Version, GitHub-Release mit gebauten Binaries, Zenodo-DOI daran gekoppelt | 0 Tags, 0 Releases |
| 19 | VS-Code-Extension veröffentlichen: `private` entfernen, Icon, Marketplace-README, Lizenz, Publisher einrichten | `packages/vscode/package.json:7,11-15` |
| 20 | tree-sitter-Grammatik auf npm und ins `nvim-treesitter`-Register | `packages/grammar/package.json:6` |
| 21 | JOSS-Einreichung, weil ihr Kriterium Dokumentation und Tests ist und beides vorliegt | `paper/README.md:19-20` |
| Forschungsergebnis | in ein separates, nicht-öffentliches Repository ausgelagert | nicht Teil dieses Repos |
| 23 | Devlog aus `notes/` starten, mit `<Beloch>` als Abbildungsweg | `notes/2026-06-28-blog-tooling-design.md` |
| 24 | 9OSME-Paket: Springer-Template einchecken, Foliensatz, Handout mit QR auf den Playground | `paper/README.md:22-36` |
| 25 | Token-Farbsystem für die 22 Syntaxklassen dokumentieren und auf unterscheidbare Werte reduzieren | `theme.css:60-101` |
| 26 | Domainentscheidung schließen: `beloch.it` gegen `beloch.dev`, `beloch.toph.so` bleibt Weiterleitung. Vor der ersten zitierbaren Veröffentlichung, weil ein Paper die URL festschreibt | `decisions/0005-name-beloch.md:56-57` |
