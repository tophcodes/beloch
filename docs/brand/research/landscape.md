# Landschaftsanalyse: Auftritte vergleichbarer Projekte

Stand der Recherche: 21.09.2026. Alle Angaben stammen aus Live-Abrufen der
genannten URLs (WebFetch/WebSearch), nicht aus Vorwissen. Wo ein Abruf nicht
möglich war, ist das vermerkt.

## Origami-Software

### Rabbit Ear (Robby Kraft, rabbitear.org)

`rabbitear.org` liess sich aus dieser Arbeitsumgebung nicht abrufen (DNS
schlägt hier auch über einen Proxy fehl, was an der Umgebung liegt und nichts
über die Seite aussagt). Die Angaben unten stammen aus dem GitHub-Repo, der
GitHub-Organisation und Suchmaschinen-Snippets gecachter Unterseiten.

**Direkte Beobachtung von Toph, der die Seite kennt:** Rabbit Ear setzt stark
auf Animation, zeigt Quellcode neben dem laufenden Rendering, und der Auftritt
wirkt reif. Das ist der schärfste Vergleichsmaßstab für Beloch, weil beide
Projekte dasselbe Kernartefakt zeigen und Beloch heute ein statisches SVG plus
einen Editor nebeneinanderstellt, ohne dass sich etwas bewegt. Die
Reifewirkung entsteht dort über Bewegung, die den Faltvorgang selbst zeigt.

- **Positionierung/Tagline**: Auf `rabbitear.org/demo.php` und in
  Ankündigungen firmiert das Projekt als "Rabbit Ear, origami and creative
  code". Die GitHub-Organisation beschreibt sich knapper als "computational
  origami". Das README des Kern-Repos öffnet mit "This is a Javascript
  library for modeling origami."
- **Code/Artefakt**: Das README verweist sofort auf drei
  Installationswege (UMD-CDN, ES6-CDN, `npm install rabbit-ear`) statt auf ein
  Live-Beispiel im Text selbst. Interaktive Demos liegen laut Suchtreffern
  unter `/demo.php`, ein FOLD-Validator/Viewer ist ein eigenes Repo
  (`fold-validator`, Svelte).
- **Reife-Kommunikation**: Kein Versions-Badge, kein Build-Status-Badge im
  README. Reife zeigt sich indirekt: 648 Stars, 34 Forks, 1.352 Commits,
  TypeScript- und Linting-Setup, GPLv3-Lizenz klar benannt, npm-Paket
  `rabbit-ear` v0.9.4 (laut npm zuletzt vor rund zwei Jahren aktualisiert).
- **Logo**: Ein stilisiertes Hasenohr-Icon als Organisations-Avatar.
- **Signal**: Liest als Forschungsartefakt eines Einzelentwicklers: direkter,
  fast schmuckloser Zugang zu Code und Paketen, keine Marketing-Sprache,
  keine Onboarding-Choreografie. Die tote Domain relativiert das: Wer sich
  ausschließlich auf eine persönliche Domain statt auf GitHub/npm als
  primären Ankerpunkt verlässt, riskiert genau das.

Quellen: [github.com/rabbit-ear/rabbit-ear](https://github.com/rabbit-ear/rabbit-ear), [github.com/rabbit-ear](https://github.com/rabbit-ear), [npmjs.com/package/rabbit-ear](https://www.npmjs.com/package/rabbit-ear), Suchtreffer zu `rabbitear.org/demo.php`, `rabbitear.org/book/`, `rabbitear.org/docs/`.

### ORIPA (Jun Mitani, mitani.cs.tsukuba.ac.jp/oripa)

- **Hero**: "ORIPA: Origami Pattern Editor" mit japanischem Untertitel
  "折紙展開図エディタ". Beschreibung: "a drawing software dedicated to
  designing the crease patterns of origami", mit dem Alleinstellungsmerkmal
  "calculation of the folded shape from the pattern".
- **Code/Artefakt**: Ein einzelner Screenshot (`img/oripa_screen030.jpg`)
  früh auf der Seite, keine eingebetteten Crease-Pattern-Beispiele. Über 40
  herunterladbare Beispieldateien (`.opx`), die man laden muss, um sie zu
  sehen.
- **Farbe/Typografie/Logo**: Kein Farbkonzept, Standard-Schwarz-auf-Weiß,
  funktionale serifenlose Schrift, kein Logo, reine Textmarke.
  Zweisprachig Japanisch/Englisch durchgängig.
- **Reife-Kommunikation**: Versionsnummer explizit ("0.35, the latest
  version") plus Entstehungsgeschichte ("first version … released in 2005",
  Open Source seit 2012/6/17 mit Datum).
- **Signal**: Akademisches Homepage-Format einer Einzelperson (Mitani ist
  Origami-Forscher an der Uni Tsukuba): Struktur wie eine
  Software-Dokumentationsseite aus den 2000ern, keinerlei Marketing-Vokabular.
  Die Nüchternheit selbst wirkt technisch ernstzunehmend.

Quelle: [mitani.cs.tsukuba.ac.jp/oripa/](https://mitani.cs.tsukuba.ac.jp/oripa/)

### TreeMaker (Robert J. Lang)

Kein einzelner offizieller Auftritt mehr unter einer Marken-Domain; das
Projekt lebt heute über mehrere GitHub-Forks (`bugfolder/TreeMaker`,
`AndrewKvalheim/treemaker` u. a.) und über Robert Langs eigene Seite
`langorigami.com`, die TreeMaker im Kontext seiner Theorie uniaxialer Basen
und seiner eigenen Origami-Werke präsentiert statt als eigenständiges
Software-Produkt. Software als Beiwerk zu einem Forschungs- und
Werk-Korpus, eingebettet in die Werkbiografie einer Person.

Quellen: [linkage.cs.umass.edu/origamiLang/treeMaker.html](http://linkage.cs.umass.edu/origamiLang/treeMaker.html), [github.com/bugfolder/TreeMaker](https://github.com/bugfolder/TreeMaker)

## Kleine Programmiersprachen

### Dhall (dhall-lang.org)

- **Hero**: "The Dhall configuration language"
- **Subline**: "Maintainable configuration files"
- **Erklärsatz**: "Dhall is a programmable configuration language that you
  can think of as: JSON + functions + types + imports"
- **Code/Artefakt**: Kein Code direkt im Fließtext des Hero-Bereichs;
  stattdessen Tabs ("Hello, world!", "Definitions", "Functions", "Types",
  "Imports"), die Beispiele erst nach Interaktion zeigen.
- **Logo**: eigenständiges SVG-Wortlogo/-glyphe (`dhall-large-logo.svg`).
- **Reife-Kommunikation**: Verweise auf Grammatik-/Semantik-Spezifikation
  auf GitHub, ein eigener Abschnitt "Dhall in production", breite Liste an
  Sprachbindungen (Haskell, Rust, Go, Clojure …) und Ökosystem-Pakete
  (Kubernetes, Ansible, Docker).
- **Navigation**: Get started, Discussion, Tutorial, How-to guides,
  References, Languages, File formats, Packages.
- **Signal**: Spezifikation zuerst, Produktsprache praktisch nicht vorhanden.
  Die Tab-Interaktion statt direktem Code ist der einzige Reibungspunkt
  gegenüber "Code sofort sichtbar".

Quelle: [dhall-lang.org](https://dhall-lang.org/)

### Roc (roc-lang.org)

- **Hero**: "Roc" mit Subline "A fast, friendly, functional language."
- **Code/Artefakt**: Echter Code erscheint direkt im Hero-Bereich (ein
  `.map()`-Beispiel mit String-Interpolation), lauffähig im Browser.
- **Logo**: eine violette Origami-Vogel-Glyphe aus sechs Dreiecken.
  Bemerkenswert für Belochs Kontext, weil ein etabliertes Sprachprojekt sein
  Maskottchen bewusst als gefaltete Papierform gestaltet hat.
- **Reife-Kommunikation**: Betont, dass die Beispiele "built and tested with
  the same Roc compiler as this website" sind; benannte Sponsoren; eine
  gemeinnützige Stiftung (501(c)(3)) als Trägerorganisation; kein "work in
  progress"-Hinweis trotz Alpha-Status der Sprache selbst.
- **Navigation**: Tutorial, Install, Examples, Community, Docs, Donate.
- **Signal**: Lauffähiger Code im Hero plus institutioneller Unterbau
  (Stiftung, Sponsoren) erzeugt Vertrauen, ohne dass die Sprache selbst
  bereits 1.0 ist.

Quelle: [roc-lang.org](https://www.roc-lang.org/)

### Zig (ziglang.org)

- **Hero**: "Zig is a general-purpose programming language and toolchain for
  maintaining robust, optimal and reusable software."
- **Subline**: "Focus on debugging your application rather than debugging
  your programming language knowledge."
- **Code/Artefakt**: Ein vollständiges Testbeispiel mit Syntax-Highlighting
  und dazugehöriger Shell-Ausgabe erscheint direkt im ersten Seitendrittel.
- **Farbe/Logo**: Minimalistisch, schwarzer Text auf hellem Grund, ein Blitz
  (⚡) als Logo/Maskottchen-Ersatz.
- **Reife-Kommunikation**: Versionsbadge "0.16.0" prominent, versionierte
  Doku, direkter Link zu Release Notes, Trägerstiftung seit 2020.
- **Navigation**: Download, Learn, News, Source, Join a Community, Zig
  Software Foundation, Devlog.
- **Signal**: Versionsnummer und Release Notes vorne, dazu Quellcode-Host auf
  Codeberg statt GitHub als bewusstes Statement zu Dezentralisierung.

Quelle: [ziglang.org](https://ziglang.org/)

### Gleam (gleam.run)

- **Hero**: "Gleam is a friendly language for building type-safe systems
  that scale!"
- **Subline**: "The power of a type system, the expressiveness of functional
  programming, and the reliability of the highly concurrent, fault tolerant
  Erlang runtime, with a familiar and modern syntax."
- **Code/Artefakt**: Ein "hello, friend!"-Beispiel direkt nach der Subline,
  weitere Code-Beispiele zu Concurrency folgen im Seitenverlauf.
- **Farbe/Logo/Maskottchen**: Violette Akzentfarbe, Wellen-SVGs als
  Sektionstrenner, Maskottchen "Lucy the star" durchgängig in Branding und
  Navigation.
- **Reife-Kommunikation**: Kein klassisches Status-Badge; Vertrauen wird über
  die Erlang-VM-Basis hergestellt ("powers planet-scale systems such as
  WhatsApp"), über einen Roadmap-Link und Case Studies.
- **Navigation**: News, Community, Sponsor, Packages, Docs, Install; Footer
  zusätzlich mit Tour, Playground, Roadmap, Case studies.
- **Signal**: Freundlicher Ton und Maskottchen bei gleichzeitig technisch
  dichtem Inhalt (Typsystem, Concurrency, Erlang-Interop). Das zeigt: Ein
  Maskottchen ist an sich kein Produkt-Signal, wenn der Rest der Seite
  fachlich bleibt.

Quelle: [gleam.run](https://gleam.run/)

### Lean (lean-lang.org)

- **Hero**: "Lean is an open-source programming language and proof assistant
  that enables correct, maintainable, and formally verified code". Das
  fungiert zugleich als Subline; eine separate kürzere Tagline gibt es nicht.
- **Code/Artefakt**: Ein echter formaler Beweis (Unendlichkeit der Primzahlen
  nach Euklid) in Lean-Syntax erscheint direkt unter dem Hero, vor jeder
  Navigation.
- **Reife-Kommunikation**: Eigener Roadmap-Link mit Zeitachse bis September
  2026, ein "PROGRESS"-Abschnitt für Meilensteine, Zitate von Terence Tao,
  einem Amazon-VP und einem Google-DeepMind-VP, sechs vorgestellte
  Referenzprojekte (u. a. Mathlib, ein Fermat's-Last-Theorem-Formalisierungsprojekt),
  Förderlogos (Sloan Foundation, Simons Foundation, Amazon).
- **Navigation**: Install, Learn, Community, Use Cases, FRO (Focused Research
  Organization); zusätzlich Playground, Mathlib, CSLib, Reservoir, GitHub.
- **Signal**: Das mathematisch-nächste Vorbild für Beloch unter den
  untersuchten Sprachen: echter Beweis-Code im Hero, prominente
  Fördergeber-Logos statt Kunden-Logos, Zitate von Fachautoritäten statt
  Testimonials von Nutzern eines Produkts.

Quelle: [lean-lang.org](https://lean-lang.org/)

## Diagramm- und Visualisierungssprachen

### Penrose (penrose.cs.cmu.edu)

- **Hero**: "Create beautiful diagrams", Subline "just by typing notation in
  plain text."
- **Code/Artefakt**: Der Hero-Bereich selbst zeigt laut Abruf drei
  Prinzip-Karten (Declarative, Beautiful, Universal) statt eines
  Diagramm-Screenshots. Diagramme als Artefakt erscheinen erst über die
  `/examples`-Seite oder den `/try`-Editor. Dort liegen über 50 Beispiele,
  organisiert nach Domänen (Mengenlehre, Gruppentheorie,
  Graphenvisualisierung, Geometrie, Fraktale), jedes verlinkt direkt in den
  Live-Editor (`/try/index.html?examples=...`).
- **Reife-Kommunikation**: MIT-Lizenz mit Copyright-Zeitraum 2017–heute,
  GitHub/Discord/Twitter verlinkt, kein Versions-Badge, kein Changelog auf
  der Startseite sichtbar, kein direkter Paper-Link im abgerufenen Ausschnitt
  (die Publikation existiert, ist aber nicht Teil des Hero-Bereichs).
- **Signal**: Bemerkenswert, weil Penrose sein Kernartefakt, die generierten
  Diagramme, hinter einen Klick zur Beispiel-Galerie legt, statt es auf der
  Startseite zu zeigen. Für "Zeichnung als Held der Seite" ist das trotz
  Penrose' fachlicher Nähe zu Beloch ein Gegenbeispiel.

Quellen: [penrose.cs.cmu.edu](https://penrose.cs.cmu.edu/), [penrose.cs.cmu.edu/examples](https://penrose.cs.cmu.edu/examples)

### TikZ/PGF (tikz.dev, texample.net)

- **Hero (tikz.dev)**: "TikZ and PGF Manual", Einstiegssatz beschreibt PGF/TikZ
  als System, das "began as a small LaTeX style" und seitdem zu einem
  vollständigen Grafiksystem gewachsen ist; betont explizit, dass man
  Grafiken "programmiert" statt sie zu zeichnen.
- **Code/Artefakt**: Bereits im Einleitungsabschnitt erscheinen kleine
  eingebettete Diagramm-Beispiele (Linien, gefüllte Kreise) als Bilder.
  Ergebnis und Quelle stehen nebeneinander.
- **Farbe/Typografie**: rein dokumentationsgetrieben: Rot für öffentliche
  Befehle/Umgebungen, Grün für optionale Parameter, serifenbetonte
  Fließtext-Typografie, helles Layout, Hamburger-Menü.
  Versionsstand "Version 3.1.11" mit explizitem Hinweis "Unofficial HTML
  Version" und Datumsstempel der letzten Aktualisierung.
- **texample.net (Galerie)**: Zeigt Beispiele als vertikale, bildlastige Liste
  statt als dichtes Thumbnail-Raster: jeder Eintrag mit Vorschaubild, Titel,
  Datum und Tags (z. B. "3D", "Mathematics"); mehrere Taxonomien
  (Themen, Pakete/Features, freie Tags); über 35 Seiten Archiv.
- **Signal**: Das Standardmuster für "Text-zu-Grafik-Sprache zeigt ihr
  Artefakt": Bild und Quellcode nebeneinander, Galerie nach Fachgebiet
  sortiert statt nach Produktkategorie, Versionsnummer der Doku selbst
  offen ausgewiesen.

Quellen: [tikz.dev](https://tikz.dev/), [texample.net/tikz/examples/](https://texample.net/tikz/examples/), [ctan.org/topic/pgf-tikz](https://ctan.org/topic/pgf-tikz)

### Observable (observablehq.com)

- **Positionierung heute**: Die GitHub-Organisationsbeschreibung fasst das
  Produkt als "The collaborative data canvas". Auf der Startseite (laut
  Suchindex) Formulierungen wie "Batteries included. Query data, visualize,
  add interaction." und Betonung von Realtime-Multiplayer-Editing und
  Git-artigem Fork-and-Merge.
- **Reife/Kommerzialisierung**: Observable hat eine eigene Pricing-Seite
  (`/pricing`) mit gestaffelten Plänen für Hobbyisten, professionelle
  Einzelnutzer, kleine Teams und Enterprise, inklusive eines Kontingents an
  "AI queries" pro Plan. Ein Hacker-News-Thread von 2022 dokumentiert den
  Übergang zu bezahlten privaten Notebooks als Bruchpunkt in der
  Community-Wahrnehmung.
- **Direkter Abruf**: Die Startseite blockierte wiederholt mit Rate-Limiting
  (HTTP 429). Die Angaben stammen aus Suchindex-Snippets der Startseite, des
  GitHub-Orga-Profils und der Pricing-Seite; ein vollständiges Live-Rendering
  lag nicht vor.
- **Signal**: Observable ist der klarste Beleg im untersuchten Feld dafür,
  dass ein Forschungsartefakt (Mike Bostocks Notebook-Umgebung, ursprünglich
  aus D3 hervorgegangen) über Jahre in Produktsprache hinüberwandern kann:
  gestaffelte Pläne, KI-Kontingente, "Canvas" als Marken-Begriff statt
  "Notebook". Für Beloch ist das ein Warnbeispiel.

Quellen: [observablehq.com/pricing](https://observablehq.com/pricing) (Existenz/Struktur laut Suchindex, Direktabruf blockiert), [github.com/observablehq](https://github.com/observablehq), Hacker-News-Diskussion zur Einführung bezahlter Pläne.

## Startup-Produkt-Gegenbeispiele

### Vercel (vercel.com)

- **Hero**: "Agentic Infrastructure", Subline "For coding agents to ship apps
  and agents automated by agents."
- **CTAs**: "Deploy now" und "Talk to sales" als primäre Handlungsaufforderungen,
  dazu "Learn more"-Links pro Produktlinie (eve, Passport, Containers).
- **Social Proof**: Kundenzitate mit Kennzahlen statt reiner Logo-Wand:
  Notion ("powers millions of agent conversations daily"), Zapier ("serves
  over 100 million monthly website visits"), Mintlify ("powers documentation
  for over 20,000 companies").
- **Layout**: Feature-Karten-Raster, nach Kunden-Use-Case gruppiert (Durable
  Orchestration, Global Delivery, Tenant Isolation).
- **Signal**: Aspirationale Business-Sprache ("ship apps and agents automated
  by agents"), Umsatz-/Reichweiten-Kennzahlen als Vertrauensbeweis,
  Vertriebs-CTA neben Self-Service-CTA: klassisches B2B-SaaS-Muster.

Quelle: [vercel.com](https://vercel.com/)

### Supabase (supabase.com)

- **Hero**: "Build in a weekend. Scale to millions."
- **Subline**: "Supabase is the Postgres development platform: an open source
  backend for building web and mobile applications…"
- **Layout**: Feature-Karten-Raster für sechs Kernprodukte (Database, Auth,
  Storage, Edge Functions, Realtime, Vector), dazu ein Abschnitt mit fünf
  "Key Differentiators".
- **Ton**: Zugänglich-technisch ("Build in a weekend") kombiniert mit
  Fachbegriffen ("pgvector", "Row Level Security") für ein
  entwicklerfreundliches, aber klar produktförmiges Publikum.
- **Signal**: Feature-Grid nach Produktlinie statt nach fachlicher Struktur,
  Wachstums-Rhetorik im Hero-Slogan.

Quelle: [supabase.com](https://supabase.com/)

---

# Synthese

## 1. Musterliste: Was bei technischem Publikum Vertrauen erzeugt

1. **Echtes, lauffähiges Artefakt im Hero-Bereich, keine Illustration.**
   Lean zeigt einen echten Beweis in Lean-Syntax direkt unter dem Hero, vor
   jeder Navigation. Roc zeigt einen lauffähigen Code-Schnipsel im Hero
   selbst und betont explizit, dass er mit demselben Compiler läuft, der die
   Seite baut. Zig zeigt ein vollständiges Test-Beispiel samt Shell-Ausgabe
   im ersten Seitendrittel.
2. **Bild und Quellcode nebeneinander statt getrennt.** TikZ/PGF bettet
   Diagramm-Ausgabe direkt neben die erzeugende Syntax ein, schon in der
   Einleitung des Manuals. Das reduziert die Distanz zwischen "das ist
   Notation" und "das ist, was dabei herauskommt" auf null Klicks.
3. **Institutioneller statt kommerzieller Vertrauensanker.** Lean stellt
   Förderlogos (Sloan Foundation, Simons Foundation, Amazon) und Zitate von
   Fachautoritäten (Terence Tao) aus, keine Kundenlogos. Roc trägt seinen
   Compiler über eine gemeinnützige Stiftung. Zig ebenso seit 2020. Das
   signalisiert Kontinuität eines Forschungs-/Infrastrukturprojekts.
4. **Versionsnummer und Änderungsverlauf offen ausgewiesen.** Zig zeigt die
   aktuelle Version als Badge und verlinkt direkt zu Release Notes. TikZ/PGF
   nennt Versionsnummer und "last updated"-Datum der Doku selbst, inklusive
   des ehrlichen Hinweises "Unofficial HTML Version". OriPA nennt
   Versionsnummer und Entstehungsdatum ohne Umschweife.
5. **Roadmap statt Marketing-Versprechen.** Lean verlinkt eine Roadmap mit
   konkreter Zeitachse und einem "PROGRESS"-Abschnitt für Meilensteine.
   Gleam verlinkt im Footer ebenfalls eine Roadmap.

Eine sechste, kleinere Beobachtung passt zu keinem der fünf Muster oben, ist
für Beloch aber relevant: OriPA und (aus den erreichbaren Sekundärquellen
rekonstruiert) Rabbit Ear verzichten fast vollständig auf
Gestaltungsvokabular. Textmarke statt Logo, direkter Sprung zu Quellcode und
Downloads, keine Onboarding-Choreografie. Bei einem
Ein-Personen-Forschungsprojekt liest diese Kargheit selbst als Signal von
Echtheit.

## 2. Antimusterliste: Was einen Auftritt in Produktsprache kippen lässt

1. **Gestaffelte Pricing-Seite mit Nutzungs-Kontingenten.** Observables
   Wandel zu Plänen für "Hobbyist / Professional / Team / Enterprise" mit
   abgezählten KI-Anfragen ist der klarste Beleg im untersuchten Feld:
   Ein Notebook-Werkzeug, das mit Forschungs- und Journalismus-Anspruch
   startete, endet mit Pläne-Vokabular, das identisch zu jedem SaaS-Produkt
   klingt.
2. **Kundenzitate mit Reichweiten-/Umsatzkennzahlen statt Fachautoritäten.**
   Vercels "powers millions of agent conversations daily" funktioniert als
   Vertrauensbeweis für ein Infrastrukturprodukt, misst im Forschungskontext
   aber Zahlungsbereitschaft anstelle fachlicher Korrektheit.
3. **Feature-Karten-Raster, organisiert nach Produktlinie statt nach
   fachlicher Struktur.** Supabase gliedert sechs Produkte in gleich
   große Karten (Database, Auth, Storage …). Sobald ein Origami- oder
   Sprachprojekt seine Fähigkeiten in identisch geformte Karten mit Icon und
   drei Zeilen Text presst, liest es wie ein Feature-Vergleich für
   Kaufentscheidungen statt wie eine Spezifikation.
4. **Aspirationale Wachstums-Rhetorik im Hero-Slogan.** "Build in a weekend.
   Scale to millions." (Supabase) und "ship apps and agents automated by
   agents" (Vercel) versprechen Ergebnis und Skalierung. Für ein Projekt,
   dessen Kernversprechen "diese Faltung ist geometrisch korrekt
   konstruierbar" lautet, ist Wachstums-Sprache ein Kategorienfehler.
5. **Primäre CTA-Verben aus dem Vertrieb ("Deploy now", "Talk to sales",
   "Get started free").** Diese Verben adressieren einen Kaufentscheider.
   Keines der untersuchten Forschungs-/Sprachprojekte (Lean, Zig, Dhall,
   Gleam, Roc) nutzt eine Verkaufs-CTA als primäre Handlung. Dort steht
   "Install", "Try", "Tutorial", "Playground".

## 3. Positionierung im Feld

Beloch sitzt zwischen drei Nachbarschaften, die im untersuchten Material klar
getrennt bleiben: Origami-Software (OriPA, TreeMaker, Rabbit Ear), kleine
deklarative/funktionale Sprachen (Dhall, Roc, Zig, Gleam) und akademische
Beweis-/Notation-Werkzeuge (Lean, Penrose, TikZ). Von der Origami-Software
unterscheidet Beloch der Sprachanspruch: eine Grammatik mit Axiomen statt ein
GUI-Editor. Von den kleinen Sprachen unterscheidet es der enge, geometrisch
geschlossene Anwendungsbereich (Origami statt Allzweck-Programmierung). Von
Lean/Penrose/TikZ unterscheidet es, dass Beloch selbst ein
Konstruktionsverfahren mit einem exakten Zahlkern implementiert und einen
eigenen Artefakt-Typ (FOLD, Faltdiagramme) erzeugt, statt nur bestehende
Mathematik zu notieren.

**Das nächste Vorbild ist Lean.** Begründung: Lean zeigt ein echtes,
verifizierbares Artefakt (einen Beweis) im Hero-Bereich, genau wie Beloch ein
echtes Faltdiagramm anstelle einer Illustration zeigen sollte. Und Lean
stützt Reife über Förderlogos, Fachzitate und eine terminierte Roadmap. Das
passt zur Größenordnung und zum akademischen Anspruch (Paper,
arXiv/JOSS/OSME) von Beloch besser als das Nutzerzahlen- und
Pricing-Vokabular eines VC-finanzierten Sprachprojekts wie Roc.

Ein zweites, ergänzendes Vorbild für die visuelle Ebene ist **TikZ/PGF**
(siehe Abschnitt 4): Für die konkrete Frage "wie zeige ich Code neben
Diagramm" liefert TikZ das dichtere, unmittelbarere Muster als Lean, dessen
Artefakt (ein Beweis) textuell bleibt.

## 4. Visuelle Muster für Projekte, deren Kernartefakt eine Zeichnung ist

Drei der untersuchten Auftritte (Penrose, TikZ, Observable) haben ein
Kernartefakt, das eine Zeichnung oder Visualisierung ist, gehen damit aber
unterschiedlich um:

- **TikZ/PGF setzt das Bild direkt neben die erzeugende Syntax**, schon im
  ersten Absatz der Dokumentation, als Beleg mitten im Fließtext. Die
  Galerie (texample.net) ergänzt das um eine durchsuchbare, kategorisierte
  Übersicht für die Fälle, in denen jemand gezielt nach einem Diagrammtyp
  sucht. Das ist das stärkste Muster für "Zeichnung als Held": Ergebnis und
  Ursache in einem Blick, an jeder Stelle der Doku.
- **Penrose verschiebt das Artefakt hinter einen Klick.** Der Hero-Bereich
  selbst zeigt laut Abruf drei Prinzip-Karten (Declarative, Beautiful,
  Universal) statt der generierten Diagramme; die über 50 Beispiele liegen
  kategorisiert nach Fachgebiet (Mengenlehre, Gruppentheorie, Geometrie,
  Fraktale) auf einer eigenen `/examples`-Seite und öffnen sich erst dort in
  einen Live-Editor. Für ein Projekt, dessen ganze Existenzberechtigung
  "beautiful diagrams" ist, ist das eine vertane Gelegenheit im Hero-Bereich.
  Für die Struktur einer Beispiel-Seite selbst ist die Sortierung nach
  Fachgebiet trotzdem ein brauchbares Muster.
- **Observable/texample.net zeigen das Kuratierungsmuster für viele
  Artefakte**: eine bildlastige, vertikale Liste (kein dichtes
  Thumbnail-Raster) mit Titel, Datum, Tags pro Eintrag, mehrere Taxonomien
  parallel (Thema, verwendete Pakete, freie Tags). Das eignet sich für eine
  spätere Beloch-Beispielgalerie mit vielen Basen/Modellen: Sortierung nach
  Faltungstyp oder verwendeten Axiomen statt nach Einreichungsdatum.

Für Beloch heißt das konkret: Das erzeugte Crease-Pattern/Faltdiagramm-Paar
gehört so früh wie möglich auf die Seite, am besten direkt neben den
erzeugenden Beloch-Code (TikZ-Muster). Ein "Examples"-Link als einziger Ort
für das Kernartefakt wäre das Penrose-Antimuster. Eine spätere
Beispielgalerie sollte nach Fachkategorie (Basen, Axiom-Verwendung) statt
nach chronologischer Veröffentlichung sortiert sein.
