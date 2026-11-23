## 1. Renderers

- [ ] 1.1 Write the declared credits into the metadata of every SVG the renderers of `packages/render-2d` produce from a scene; verify with bun tests of `packages/render-2d` for a credited program and one without credits
- [ ] 1.2 Write the credits into text chunks of the PNG of `beloch render`, and state in `docs/reference/CLI.md` that both formats carry them; verify with a command line test that reads the chunks back

## 2. Playground

- [ ] 2.1 Carry the credits in the SVG the playground downloads and copies; verify with the suites of `packages/www` and by loading the playground with the console open and downloading the SVG of a credited program

## Workflow follow-up

- The pull request that builds this change archives it in its last commit.
