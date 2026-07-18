# Flatten-Paritäten hängen am sort_ccw-Winkelursprung — Befund & Fix-Plan

**Kontext:** Zwei-Ear-fish-base (`tests/cases/collapse/flatten-two-ears-sequential.bel`,
beide Ears `{toward .d}` bzw. `.d`/`.b`). Nach dem flat-hinge-Taco-Check
(`ab8aa12`) hat das zweite Ear **keine** valide Realisierung mehr — der vorher
emittierte Zustand war ein Ghost (Blatt durchs geschlossene Ear-Gelenk, von
Toph am Render erkannt: Flügel unter dem stationären Streifen, Ear darüber).

## Kausalkette (empirisch, BELOCH_COLLAPSE_DEBUG/BELOCH_TT_DEBUG-Instrumentierung)

1. Sektor-Paritäten kommen aus `sector_isometries`: `det(T_k) = (−1)^k` mit
   k = CCW-Index ab `sort_ccw`s **absolutem Winkelursprung**. Die Zuordnung
   proper/improper ist damit willkürlich, nicht geometrisch.
2. Drei Konsumenten dieser Parität:
   - **Anchor-Eligibility** (`anchor_realization`, nur det>0-Sektoren):
     gefixt in `1a4f6d9` (improper-Fallback + reversed rank).
   - **Validity-Filter** (`valid_srank`): stellt sich als unkritisch heraus —
     alle `make`-Checks lesen rank nur über *betweenness*, die ist
     reversal-invariant (Varianten-Experiment war deshalb ein No-op).
   - **`effective_valley`** → Hinge-**Constraints** → `linear_extensions`:
     HIER sitzt der eigentliche Schaden. Für den c-Vertex des zweiten Ears
     erzeugt die Origin-Parität die Constraint-Richtungen der gespiegelten
     Welt: über ALLE Maekawa-Patterns hinweg werden nur 16 der 24
     Sektor-Ketten enumeriert; die physisch wahre Kette `[2,3,0,1]`
     (stationär unten, Wing-Blöcke sauber darüber, Ear zuoberst) und ihre 7
     Verwandten fehlen — und die fehlende Menge ist reversal-geschlossen,
     also auch über Spiegel-Seating unerreichbar.
3. Folge: jede enumerierte Kette verletzt (zu Recht!) einen Taco-Check —
   64/64 KILL bei nf=12. Vor `ab8aa12` überlebten nur die 4 Ghosts.

## Fix-Richtung (nächster Slice)

Parität konsequent pro Anker-Klasse rechnen statt global von der Origin:
`collapse_pipeline ~mirror:bool` — bei `mirror` flippt `effective_valley`
(und damit Constraints + `ray_assign`) sowie `intra`, geankert wird auf den
det<0-Sektoren. `collapse_all` = pipeline(false) ∪ pipeline(true) mit
Signatur-Dedup; `over` liest im mirror-Fall invertiert. Das ersetzt den
reversed-rank-Fallback aus `1a4f6d9` durch ein konsistentes Modell (der
Fallback bleibt als Spezialfall darin enthalten).

Erwartung danach: `flatten-two-ears-sequential.bel` grün (wahre Kette wird
enumeriert, Ghosts bleiben tot), `test_flatten` derive-13 grün, keine
Änderung an Einzel-flatten-Fällen (dort seatet die false-Pipeline wie heute).

## Nebenbefunde

- `e_midpaper`/„crease ends inside the sheet" feuerte für 8 Patterns des
  zweiten Ears — vermutlich der OppositeRay-Kandidat O2→center; nach dem
  Paritäts-Fix neu bewerten (Interaktion mit Tier-Frage #51).
- Debug-Hygiene: BELOCH_FLATTEN_DEBUG (eval), BELOCH_COLLAPSE_DEBUG
  (valid_srank), BELOCH_TT_DEBUG (Taco-Raise) waren als temporäre
  Instrumentierung nützlich; vor Commits entfernt. Bei Bedarf als dauerhafte
  env-gated Traces wiedereinführen.

## Aufgelöst (2026-07-18, staying-Slice)

Sprachlösung statt ~mirror-Union: `(staying <flap>)` + Leading-Pair-Konvention
verankern die Paritätsklasse semantisch
(`docs/superpowers/specs/2026-07-17-flatten-staying-design.md`, #52). Dabei
dritte Repräsentanten-Arbitrarität gefunden und gefixt: `sector_iso` nahm das
erste Face im Sektor als Orientierungs-Repräsentant — im gemischten
Stayer-Sektor des zweiten Ears (Basis-Streifen det>0 + Ear-1-Stack det<0)
las `effective_valley` dadurch die Spiegelwelt (Diagnose bestätigt: ein
invertiertes Hinge-Constraint). Fix: pro Ray das crease-adjazente Face der
Stayer-Seite. Die wahre Kette war nie ein Ghost: einmal enumeriert, besteht
sie `make` + Taco-Checks. `flatten-two-ears-sequential` und derive-13 grün;
Fallback aus 1a4f6d9 ersatzlos gestrichen. Nebenbefund e_midpaper: obsolet —
LineNew-Emergent gewinnt regulär; #51-Trio bleibt als eigener Slice rot.

## Amendment (2026-07-19, Pin-Regel — Spine-M ist kein Enumerations-Loch)

Die Diagnose `.superpowers/sdd/diagnosis-spine-m.md` widerlegt die frühere
„Spine-M wird ausgehungert"-These für das **einzelne** even-4-ray-fish (Ear 1):
das Spine-M-Pattern (#5) IST enumeriert, besteht `valid_srank`/`over`/Taco/
`in_bounds` und liegt als valide Realisierung im Pool. Es stirbt erst am
**Stage-3-Rank-Dipol**: der symmetrische Grat scored exakt `S(R)=0` und
verliert gegen den asymmetrischen Bisektor-M (`+0.369`) — ein
symmetriebrechender Score kann den symmetrischen Grat nie wählen.

**Owner-Regel (approved):** `{toward}` wählt *Seiten/Spiegel*, nie zwischen
M/V-Patterns. Konkret in `lib/eval.ml`s Drei-Stufen-Wahl: nach dem
Min-Mountain-Kanon vergleicht `given_mv_vector` die abgeleiteten Buchstaben pro
gegebenem Ray; tragen die Überlebenden **mehr als ein** distinktes M/V-Pattern,
fehlt jede legitime Entscheidung → Fehler `ambiguous mountain/valley
assignment; pin one (e.g. `<crease> mountain`)` (Check 15). Der Rank-Dipol
bleibt NUR für Spiegel-Zwillinge eines gemeinsamen Patterns. Der klassische
fisch pinnt die Spine explizit: `flatten (--l1) (--l2) (--ray & .a) (--ray & .c
mountain) {toward .d}` — M landet auf I1→c (Spine), Owner-Ground-Truth.

Betroffen (Pin bekommen): `examples/bases/fish-base.bel` (Ear 1, Golden neu:
M wandert vom d-Bisektor auf die Spine), `flatten-opposite-ray-toward-{b,d}.bel`
(Spiegel bleiben, jetzt Spine-M), `flatten-two-ears-sequential.bel` (Ear 1;
Ear 2 bleibt auf `--l4`-Fehler, #48). Rabbit-Ear-Familie unberührt: dort ist
der Mountain der emergente LineNew (givenMtn=0), alle Überlebenden teilen das
All-V-Pattern → Gate greift nicht, Dipol wählt wie bisher.
