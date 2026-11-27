## 1. Remove the outline ranking

- [ ] 1.1 Time the crane with `beloch fold examples/crane.bel` before any kernel change and record the time in the pull request; verify by the recorded number
- [ ] 1.2 Find which stage leaves the extra face in the state at the fish-base vertex that exports the same FOLD with and without the ranking; verify that `test_flatten_derive_opposite_ray_fish_base` and the cases `flatten-opposite-ray-toward-b.bel` and `-toward-d.bel` assert 6 faces and pass
- [ ] 1.3 Remove the outline ranking from the fan of one vertex, the fans of several vertices, the single valley collapse and the squash; verify with `check` that only the fish-base cases and the rabbit ear fragment of `docs/reference/BELOCH-WRITES.md` change
- [ ] 1.4 Add `(staying .c) (emergent beside .b)` to `flatten-fish-pinned-unique.bel`, rename the case for what it now pins, and add a case for the scenario "The fish-base vertex names what stays"; verify with `check`
- [ ] 1.5 Remove the outline ranking from `docs/reference/MODEL.md` and `docs/reference/KERNEL.md`; verify with `check`

## 2. Every flatten names its stayer

- [ ] 2.1 Before adding the check, add `(staying …)` to every `flatten` without one in `examples/`, `packages/www`, the kernel cases and the fragments of `docs/reference/`, with a point in the part the default holds still today; verify that the FOLD output of every changed program is unchanged
- [ ] 2.2 Fail a `flatten` without `staying` with `flatten needs (staying .p)`, hint `name a point in the part that stays`, remove the default stayers, and state in a comment at the check that a default stayer could be added later, with a pointer to this change's design; verify with kernel cases for the scenarios "The petal fold without staying" and "Collinear leading rays", and with `check-all`
- [ ] 2.3 State in `docs/reference/MODEL.md`, `docs/reference/KERNEL.md` and `docs/reference/BELOCH-WRITES.md` that every `flatten` names its stayer, and remove the default stayers there; verify with `check`
- [ ] 2.4 Time the crane again and record the time beside the first; verify that it is no slower

## Workflow follow-up

- The pull request that builds this change archives it in its last commit.
