// The drawing the playground makes today, made from a render command instead.
// Each case writes out the call the playground's own `svgForStep` makes and
// asserts the command produces the same markup, so the migration can be read
// as a rewiring rather than a redrawing.
import { test, expect } from "bun:test";
import { parseFold, type FoldScene, type Mark } from "@beloch/scene";
import { DEFAULT_THEME, renderCP, renderFolded, renderScene, WEB_THEME } from "@beloch/render-svg";
import { createRuntime, renderCommand, type HiddenMode, type View } from "@beloch/runtime";
import { commandToSvg } from "../src/svg";

const fixture = async (name: string): Promise<FoldScene> =>
  parseFold(await Bun.file(new URL(`./fixtures/${name}`, import.meta.url)).text());

const fromCommand = (scene: FoldScene, step: number, view: View, hidden: HiddenMode): string => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene });
  rt.dispatch({ type: "step/to", index: step });
  const command = renderCommand(rt.state, { view, hidden });
  if (!command) throw new Error("no command");
  return commandToSvg(scene, command, WEB_THEME);
};

// The playground's own step-to-SVG, verbatim but for the values it reads out
// of its closure.
const svgForStep = (scene: FoldScene, i: number, view: View, hidden: HiddenMode): string => {
  if (scene.statements.length === 0) return renderCP(scene, { theme: WEB_THEME }).toString();
  const stmt = i === 0 ? null : scene.statements[i - 1]!;
  const activeMarks = stmt ? stmt.keptMarks : [];
  const newestCreaseId = activeMarks.at(-1)?.creaseId;
  if (view === "cp") {
    return renderScene(scene, {
      theme: WEB_THEME,
      isometry: { kind: "flat" },
      texture: {
        upToStatement: i - 1,
        creases: true,
        marks: true,
        points: true,
        lines: true,
        faces: "outline",
      },
      markOverlay: { marks: activeMarks, newestCreaseId },
    }).toString();
  }
  if (!stmt) {
    return renderFolded(scene, { theme: WEB_THEME, step: "0", hidden }).toString();
  }
  return renderFolded(scene, {
    theme: WEB_THEME,
    step: String(stmt.frameIndex),
    hidden,
    markOverlay: activeMarks.length > 0 ? { marks: activeMarks, newestCreaseId } : undefined,
  }).toString();
};

test("every step of both views draws what the playground draws", async () => {
  const scene = await fixture("fold-quarter.fold");
  for (let step = 0; step <= scene.statements.length; step++) {
    for (const view of ["cp", "folded"] as const) {
      expect(fromCommand(scene, step, view, "hide")).toBe(svgForStep(scene, step, view, "hide"));
    }
  }
});

test("the hidden mode reaches the folded drawing", async () => {
  const scene = await fixture("fold-quarter.fold");
  const hide = fromCommand(scene, 2, "folded", "hide");
  for (const hidden of ["dashed", "depth"] as const) {
    expect(fromCommand(scene, 2, "folded", hidden)).toBe(svgForStep(scene, 2, "folded", hidden));
    expect(fromCommand(scene, 2, "folded", hidden)).not.toBe(hide);
  }
});

test("a program with no statements draws its crease pattern in either view", async () => {
  const scene = await fixture("square.fold");
  const cp = renderCP(scene, { theme: WEB_THEME }).toString();
  expect(fromCommand(scene, 0, "cp", "hide")).toBe(cp);
  expect(fromCommand(scene, 0, "folded", "hide")).toBe(cp);
});

test("the marks dangling at a statement are drawn over both of its views", async () => {
  const scene = await fixture("fold-quarter.fold");
  const mark: Mark = {
    kind: "seg",
    a: [0, 0],
    b: [1, 1],
    line: [1, -1, 0],
    intent: "V",
    creaseId: 7,
  };
  scene.statements[0]!.keptMarks = [mark];
  for (const view of ["cp", "folded"] as const) {
    const drawn = fromCommand(scene, 1, view, "hide");
    expect(drawn).toBe(svgForStep(scene, 1, view, "hide"));
    // The newest mark is drawn in the construction colour, which is what
    // carrying `newestCreaseId` through the command buys.
    expect(drawn).toContain(DEFAULT_THEME.construction);
  }
});
