## 1. Remove the outline ranking

- [x] 1.1 Time the crane with `beloch fold examples/crane.bel` before any kernel change and record the time in the pull request; verify by the recorded number
- [x] 1.2 Remove the outline ranking from the fan of one vertex, the fans of several vertices, the single valley collapse and the squash; verify with `check` that only the rabbit ear fragment of `docs/reference/BELOCH-WRITES.md` changes beside the fish-base cases `scripts/known-failures.txt` already holds for issue #11
- [x] 1.3 Add a kernel case for the scenario "The fish-base vertex names what stays", the ambiguous statement with `(staying .c)` and the fold with `(emergent beside .b)` added, and leave the fish-base cases of issue #11 as they are; verify with `check`
- [x] 1.4 Remove the outline ranking from `docs/reference/MODEL.md` and `docs/reference/KERNEL.md`; verify with `check`

## 2. Every flatten names its stayer

- [ ] 2.1 Before adding the check, add `(staying …)` to every `flatten` without one in `examples/`, `packages/www`, the kernel cases and the fragments of `docs/reference/`, with a point in the part the default holds still today; verify that the FOLD output of every changed program is unchanged
- [ ] 2.2 Fail a `flatten` without `staying` with `flatten needs (staying .p)`, hint `name a point in the part that stays`, remove the default stayers, and state in a comment at the check that a default stayer could be added later, with a pointer to this change's design; verify with kernel cases for the scenarios "The petal fold without staying" and "Collinear leading rays", and with `check-all`
- [ ] 2.3 State in `docs/reference/MODEL.md`, `docs/reference/KERNEL.md` and `docs/reference/BELOCH-WRITES.md` that every `flatten` names its stayer, and remove the default stayers there; verify with `check`
- [ ] 2.4 Time the crane again and record the time beside the first; verify that it is no slower

## Workflow follow-up

- The pull request that builds this change archives it in its last commit.
