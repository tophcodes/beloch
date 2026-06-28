# Specification

There is **one living specification**: [`SPECIFICATION.md`](SPECIFICATION.md).
It always describes the language as it currently is, grows as each
implementation slice lands, and carries source citations inline (keys resolve in
[`../paper/references.bib`](../paper/references.bib)).

Division of artifacts:

- **`SPECIFICATION.md`** — *what* the language is (syntax, semantics, output
  contract). Durable source of truth.
- **`../decisions/`** (ADRs) — *why* a choice was made. Point-in-time.
- **Implementation plan** (per slice, disposable) — *how* a slice is built. Lives
  outside `spec/`; obsolete once the slice has landed and the spec reflects it.

Do not reintroduce per-increment spec files; fold each slice's language-facing
content into `SPECIFICATION.md` under a *(since vX.Y)* tag.
