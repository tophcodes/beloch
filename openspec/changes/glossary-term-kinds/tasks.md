## 1. Model

- [ ] 1.1 Split the definition of construction in `MODEL.md` into a definition of construction and one of candidate, each defining its own term; verify that the glossary entry of candidate links to the definition of candidate
- [ ] 1.2 Give every `.term` block of `MODEL.md` its kind, and its signature where the term has one; verify by reading the glossary of the built site

## 2. Site

- [ ] 2.1 Render the kind of a `.term` block as its RDFa class, a subclass of `bm:Term`, and the signature with partiality marked; verify with tests of the remark plugin in `packages/www`

## Workflow follow-up

- The pull request that builds this change archives it in its last commit.
