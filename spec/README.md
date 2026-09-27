# Specification

Beloch is specified by three documents, divided by role and reader (ADR
0032). Every implementation is bound by them. Each document has one job and
refers to the others by statement id or section:

- **`MODEL.md`**: what a program means. States, values, reads and writes as
  numbered definitions and lemmas with citations. The contract.
- **`BELOCH.md`**: how a program is written. The language as the signature
  of the model: one section per sort and per write, with the model
  statement it realizes, the concrete grammar, operand resolution, errors
  and a worked example.
- **`FOLD.md`**: the output format.

The reference implementation is documented beside them and binds nothing:

- **`KERNEL.md`**: how `packages/core` realizes the model, statement by
  statement, and where it stops short.
- **`CLI.md`**: the `beloch` command.

`SPECIFICATION.md` is the previous single specification and is being
dissolved into these documents in the order ADR 0032 gives. A section
that has moved is gone from it; a section still there is authoritative for
the surface syntax until it moves, never for the meaning.

Division of artifacts:

- **`spec/`**: *what* the language is, and how the reference implementation
  realizes it. Durable source of truth.
- **`../decisions/`** (ADRs): *why* a choice was made. Point-in-time.
- **Design documents** (per slice, disposable): *how* a slice is built. They
  are obsolete once the slice has landed and the documents here reflect it,
  and they are not kept in the working tree; the Git history holds them.

A slice that changes the language edits the document whose role it touches
and adds no file here.
