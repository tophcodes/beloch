## 1. Kernel

- [ ] 1.1 Collect warnings while the program runs, each with its span, message, hint and statement index, and write them to `beloch:warnings` with and without `--trace`, absent when empty; verify with kernel tests for a program without warnings and one that warns
- [ ] 1.2 Warn on a `moving` that a fold with `toward` does not need; verify with kernel tests for both scenarios of "A redundant moving warns"
- [ ] 1.3 Explain the warning in `docs/reference/BELOCH-ERRORS.md` and `beloch:warnings` in `docs/reference/FOLD.md`; verify with `check`

## 2. Command line

- [ ] 2.1 Print warnings in `beloch fold`, `beloch fold --trace`, `beloch fold --watch` and `beloch render` of a `.bel` file, with exit code 0 when the program runs, and state it in `docs/reference/CLI.md`; verify with command line tests for both scenarios of "The command line prints a warning as it prints an error"

## 3. Browser readers

- [ ] 3.1 Carry `warnings` in the browser evaluator's answer and show them in the playground in a color of their own; verify with the suites of `packages/www` and by loading the playground with the console open and running a program that warns

## Workflow follow-up

- The pull request that builds this change archives it in its last commit.
