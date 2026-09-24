import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { parseFold, type FoldScene } from "@beloch/scene";
import { WEB_THEME } from "@beloch/render-svg";
import { createRuntime, renderCommand, type EntityRef, type RenderOptions } from "@beloch/runtime";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

const { createDomRenderer } = await import("../src/index");
const { HIT_CLASS, CREASE_SELECTOR, HIT_SELECTOR, POINT_SELECTOR } = await import("../src/hits");
const { HL_CLASS } = await import("../src/highlight");

// The fixture was captured before the emitter stamped a bundle id on every
// crease edge, and a drawing without ids has no bundle to light. Each
// axiom-made edge gets one here; a paper boundary keeps none, as it has in any
// document.
type EdgeStamps = { "beloch:edges": ({ crease_id?: number } | null)[] };
const document_ = JSON.parse(
  await Bun.file(new URL("./fixtures/fold-quarter.fold", import.meta.url)).text(),
) as EdgeStamps & { file_frames: EdgeStamps[] };
for (const frame of [document_, ...document_.file_frames]) {
  for (const edge of frame["beloch:edges"]) if (edge) edge.crease_id = 1;
}
const scene: FoldScene = parseFold(document_);
const folded: RenderOptions = { view: "folded", hidden: "hide" };

// The command for one step, with whatever the reader has settled on.
const commandAt = (step: number, highlight: EntityRef[] = [], settled = false) => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene });
  rt.dispatch({ type: "step/to", index: step });
  if (highlight.length > 0 && settled) rt.dispatch({ type: "selection/set", entities: highlight });
  if (highlight.length > 0 && !settled) rt.dispatch({ type: "hover/set", entity: highlight[0]! });
  return renderCommand(rt.state, folded)!;
};

const mount = () => {
  const host = document.createElement("div");
  document.body.appendChild(host);
  return host;
};

test("the drawing lands in the host, each crease and point with a hit target", () => {
  const host = mount();
  createDomRenderer(host).draw(scene, commandAt(2), { theme: WEB_THEME, fade: null });
  const svg = host.querySelector("svg")!;
  expect(svg).not.toBeNull();
  // A twin per drawn crease or mark, and one per point dot. The dot's twin is
  // itself a dot, so the real ones are counted without it.
  const lines = svg.querySelectorAll(HIT_SELECTOR).length;
  const dots = svg.querySelectorAll(`${POINT_SELECTOR}:not(.${HIT_CLASS})`).length;
  expect(lines).toBeGreaterThan(0);
  expect(svg.querySelectorAll(`line.${HIT_CLASS}`).length).toBe(lines);
  expect(svg.querySelectorAll(`circle.${HIT_CLASS}`).length).toBe(dots);
});

test("a step change draws the other step", () => {
  const host = mount();
  const renderer = createDomRenderer(host);
  renderer.draw(scene, commandAt(2), { theme: WEB_THEME, fade: null });
  const before = host.querySelector("svg")!.innerHTML;
  renderer.draw(scene, commandAt(1), { theme: WEB_THEME, fade: null });
  expect(host.querySelectorAll("svg").length).toBe(1);
  expect(host.querySelector("svg")!.innerHTML).not.toBe(before);
});

test("a fade keeps the step that was left behind the one arrived at", () => {
  const host = mount();
  const renderer = createDomRenderer(host);
  renderer.draw(scene, commandAt(2), { theme: WEB_THEME, fade: null });
  renderer.draw(scene, commandAt(1), { theme: WEB_THEME, fade: "fold" });
  const ghost = host.querySelector(".bel-fade-ghost");
  expect(ghost).not.toBeNull();
  // The step that is current comes first, so a host reaching for the drawing
  // finds it rather than the one fading off.
  expect(host.querySelector("svg")!.closest(".bel-fade-ghost")).toBeNull();
});

test("a highlight the reader moved re-lights the drawing that is up", () => {
  const host = mount();
  const renderer = createDomRenderer(host);
  renderer.draw(scene, commandAt(2), { theme: WEB_THEME, fade: null });
  const svg = host.querySelector("svg")!;
  const creaseId = svg.querySelector(`${CREASE_SELECTOR}[data-crease-id]`)!
    .getAttribute("data-crease-id")!;
  const ref: EntityRef = { kind: "crease", creaseId };

  renderer.draw(scene, commandAt(2, [ref]), { theme: WEB_THEME, fade: null });
  // The same element, so a running fade keeps running and the reader's framing
  // survives a pointer moving over a crease.
  expect(host.querySelector("svg")).toBe(svg);
  expect(svg.querySelectorAll(`.${HL_CLASS}`).length).toBeGreaterThan(0);
  // Re-lighting adds no second round of hit twins.
  expect(svg.querySelectorAll(`line.${HIT_CLASS}`).length).toBe(
    svg.querySelectorAll(HIT_SELECTOR).length,
  );

  renderer.draw(scene, commandAt(2), { theme: WEB_THEME, fade: null });
  expect(host.querySelector("svg")).toBe(svg);
  expect(svg.querySelectorAll(`.${HL_CLASS}`).length).toBe(0);
});

test("another theme is another drawing", () => {
  const host = mount();
  const renderer = createDomRenderer(host);
  renderer.draw(scene, commandAt(2), { theme: WEB_THEME, fade: null });
  const svg = host.querySelector("svg")!;
  renderer.draw(scene, commandAt(2), { theme: { ...WEB_THEME, ink: "#123456" }, fade: null });
  expect(host.querySelector("svg")).not.toBe(svg);
});

test("draw says whether it built a new drawing, so a host can dress the new hit targets", () => {
  const host = mount();
  const renderer = createDomRenderer(host);
  expect(renderer.draw(scene, commandAt(2), { theme: WEB_THEME, fade: null })).toBe(true);
  const svg = host.querySelector("svg")!;
  const creaseId = svg.querySelector(`${CREASE_SELECTOR}[data-crease-id]`)!
    .getAttribute("data-crease-id")!;
  const ref: EntityRef = { kind: "crease", creaseId };
  // A hover re-lights the drawing that is up.
  expect(renderer.draw(scene, commandAt(2, [ref]), { theme: WEB_THEME, fade: null })).toBe(false);
  expect(renderer.draw(scene, commandAt(1), { theme: WEB_THEME, fade: null })).toBe(true);
});
