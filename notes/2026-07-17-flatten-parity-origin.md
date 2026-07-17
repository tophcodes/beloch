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
