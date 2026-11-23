## 1. YR library

- [ ] 1.1 Read the annotations of the namespace `yr` in the YR library and report each key it does not know as a hint, with the key and its source line, drawing the program as without that annotation; verify with bun tests of `packages/render-2d/yr` for both scenarios of "The library that owns a namespace reads its annotations"
- [ ] 1.2 State in `docs/reference/BELOCH-ANNOTATIONS.md` that the library that owns a namespace reads its annotations, and in `docs/reference/CLI.md` that `--view yr` reports an unknown `yr` key; verify with `check`

## Workflow follow-up

- The pull request that builds this change archives it in its last commit.
