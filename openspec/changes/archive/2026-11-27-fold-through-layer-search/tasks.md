## 1. Kernel

- [x] 1.1 Fold a block placed on top of the model or under it through the layer search; verify that every program under `examples` and `packages/core/tests/cases` folds to the same FOLD file and fails with the same message before and after, and time `examples/crane.bel` before and after
- [x] 1.2 Drop the bound on the open groups of a placed fold; verify with a kernel test that folds a flap into 13 pockets and gets one state per choice of pockets
- [x] 1.3 State in `docs/reference/KERNEL.md` that every write that folds finds its layer order through the layer search; verify with `check`

## Workflow follow-up

- The pull request that builds this change archives it in its last commit.
