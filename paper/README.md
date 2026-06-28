# Paper

The paper lives in the repo so it's reproducible from the code: bibliography
here, figures generated from actual `examples/`, LaTeX built in CI. If a language
change breaks the paper's worked example, CI should catch it.

**Do not start the outline yet.** Premature outlining shapes the work like other
papers instead of like the real project. Wait until something like a crane (or
at least a bird base) compiles end-to-end, then spend a weekend outlining — the
`../notes/` journal and `../decisions/` records make that weekend productive.

Publication strategy (see also [decision 0006](../decisions/0006-permissive-license-mit.md)):

1. **arXiv preprint** when the work is ready (crane/bird-base compiles, YR
   diagrams emit). Insurance policy — puts the work in the citation graph.
   Likely `cs.PL`, cross-list `cs.CG`. First-time submitters need an endorsement
   (check FU Hagen auto-endorsement first; else arXiv's built-in request flow —
   *not* a cold email; keep endorsement and feedback asks separate).
2. **JOSS** — low-friction, real citation; review is "is this useful, documented,
   tested?", a two-page paper. Underrated for this.
3. **Bridges / JCDCG³** as friendly in-between venues.
4. **9OSME** (~2028; runs ~every 4 years, 8OSME was July 2024). The "Computation"
   track explicitly welcomes system/language papers — no need to pose as a math
   paper. By then: mature artifact, maybe real users, measurable results.

Affiliation: "Aleph Garden" or "Independent researcher" is most accurate (the
work isn't FU coursework/advised); "FernUniversität in Hagen" is also factually
fine as an enrolled student — just don't imply institutional backing (no lab/dept
line, no logo).

Templates: when targeting OSME, keep the Springer proceedings LaTeX template +
page limits checked in here so the draft is formatted right from the start.
