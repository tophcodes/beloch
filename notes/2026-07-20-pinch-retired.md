# 2026-07-20 — `pinch` retired: absorbed by partial marks

Decision (Toph): the separate `pinch` creation primitive is **retired**, not
built. The 2026-07-03/04 pinch design
(`2026-07-03-crease-layer-selection.md`, converged 2026-07-04) predates three
language changes that between them cover its use case:

- **`mark`/`fold` verbs** (v0.21-dev) — creases are made by a verb, not a
  standalone `pinch <line>` statement.
- **partial marks** (v0.22-dev, §4.6) — `mark <motion> at .p` / `between .a .b`;
  an extent ending mid-face lays a **non-subdividing record** (splits no rays,
  dangles mid-face). This *is* the reference/pinch crease. Carried in the
  `beloch:marks` FOLD field.
- **`&` filter** (v0.17-dev, §4.8) — *selects* one segment of an existing
  bundle. The old note's `at` selector became `&`.

## What the design note wanted vs. what shipped

| note's claim | disposition |
|---|---|
| non-subdividing reference/pinch mark | **shipped** as the partial-mark record (§4.6) |
| display-short rendering | **free** — a record mark is materially short (boundary→interior stub), so it renders at true (short) geometry; no flag needed |
| single-**layer** full-chord crease on a stack (crease one layer, not all) | **dropped** — no demonstrated need; `mark` creases every crossed face and that has been sufficient. Revisit only if a real model requires it. |
| `pinch` keyword + statement | **dropped** — no keyword ever reserved (only prose); nothing to remove from the grammar |

## Edits made

- `spec/SPECIFICATION.md` §4.8, §4.10 (the landmark-interim paragraph), and
  Appendix B — dropped the "forthcoming `pinch`" promises, redirected to the
  partial mark. Header l.49 already framed v0.22 as "partial marks — the pinch";
  left as-is.
- Issue #8 — pinch slice closed as retired; tooling slice stays open.

Historical design notes (`2026-07-03-*`) left untouched as record.
