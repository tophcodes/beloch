import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { sceneLayout } from "@beloch/render-svg";
import type { EntityRef, RenderCommand } from "@beloch/runtime";
import { BURIED, DRAWN, EDGE_AB, inspectScene } from "./scene-fixture";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

const { applyHighlight, GHOST_CLASS, HL_CLASS } = await import("../src/highlight");
const { HIT_CLASS } = await import("../src/hits");

const scene = inspectScene();
const layout = sceneLayout(scene);
const at = (segment: typeof DRAWN): string => {
  const [a, b] = segment.table;
  return `x1="${layout.tx(a[0])}" y1="${layout.ty(a[1])}" x2="${layout.tx(b[0])}" y2="${layout.ty(b[1])}"`;
};

// What the renderer leaves behind for one bundle segment and one paper edge,
// hit twins included: the twin carries the same crease id and must stay dark.
const drawing = (): Element => {
  const host = document.createElement("div");
  host.innerHTML =
    `<svg><g data-layer="creases">` +
    `<line data-kind="crease" data-crease-id="3" ${at(DRAWN)}></line>` +
    `<line class="${HIT_CLASS}" data-crease-id="3" ${at(DRAWN)}></line>` +
    `<line data-kind="crease" ${at(EDGE_AB)}></line>` +
    `</g></svg>`;
  return host;
};

const crease: EntityRef = { kind: "crease", creaseId: "3" };
const edge: EntityRef = { kind: "edge", name: "ab" };

// What the renderer leaves behind for a construction line the paper does not
// carry, and for a point the program named: both are marked by that name.
const named = (): Element => {
  const host = document.createElement("div");
  host.innerHTML =
    `<svg><g data-layer="constructions">` +
    `<line class="construction" data-construction="mid" x1="0" y1="0" x2="1" y2="1"></line>` +
    `<line class="${HIT_CLASS}" data-construction="mid" x1="0" y1="0" x2="1" y2="1"></line>` +
    `</g><g data-layer="points">` +
    `<circle data-bel-name="o" data-kind="point" cx="0" cy="0" r="3"></circle>` +
    `<circle data-vertex="4" cx="1" cy="1" r="3"></circle>` +
    `</g></svg>`;
  return host;
};

// The folded drawing of the last statement, which is the one the inspect
// geometry describes.
const command = (highlight: EntityRef[], settled: boolean, frame = 1): RenderCommand => ({
  kind: "folded",
  frame,
  hidden: "hide",
  marks: [],
  newestCreaseId: null,
  constructions: [],
  highlight,
  settled,
});

test("a crease lights every line of its bundle, never a hit twin", () => {
  const host = drawing();
  applyHighlight(host, scene, command([crease], false));
  const lit = host.querySelectorAll(`.${HL_CLASS}`);
  expect(lit.length).toBe(1);
  expect(lit[0]!.getAttribute("data-kind")).toBe("crease");
  expect(host.querySelector(`.${HIT_CLASS}`)!.classList.contains(HL_CLASS)).toBe(false);
});

test("a construction line lights under the name the program gave it", () => {
  const host = named();
  applyHighlight(host, scene, command([{ kind: "construction", name: "mid" }], true));
  const lit = host.querySelectorAll(`.${HL_CLASS}`);
  expect(lit.length).toBe(1);
  expect(lit[0]!.classList.contains("construction")).toBe(true);
});

test("a named point lights, and a vertex the program never named lights nothing", () => {
  const host = named();
  applyHighlight(host, scene, command([{ kind: "vertex", index: 0, name: "o" }], true));
  expect(host.querySelectorAll(`.${HL_CLASS}`).length).toBe(1);
  const bare = named();
  applyHighlight(bare, scene, command([{ kind: "vertex", index: 4, name: null }], true));
  expect(bare.querySelectorAll(`.${HL_CLASS}`).length).toBe(0);
});

test("a paper boundary carries no id and is found by its geometry", () => {
  const host = drawing();
  applyHighlight(host, scene, command([edge], false));
  const lit = host.querySelectorAll(`.${HL_CLASS}`);
  expect(lit.length).toBe(1);
  expect(lit[0]!.hasAttribute("data-crease-id")).toBe(false);
});

test("a settled crease ghosts the segment the drawing has no line for", () => {
  const host = drawing();
  applyHighlight(host, scene, command([crease], true));
  const ghosts = host.querySelectorAll(`.${GHOST_CLASS}`);
  expect(ghosts.length).toBe(1);
  expect(ghosts[0]!.getAttribute("x1")).toBe(String(layout.tx(BURIED.table[0][0])));
  expect(ghosts[0]!.getAttribute("y1")).toBe(String(layout.ty(BURIED.table[0][1])));
});

test("a hover ghosts nothing", () => {
  const host = drawing();
  applyHighlight(host, scene, command([crease], false));
  expect(host.querySelectorAll(`.${GHOST_CLASS}`).length).toBe(0);
});

test("a step before the final fold ghosts nothing", () => {
  const host = drawing();
  applyHighlight(host, scene, command([crease], true, 0));
  expect(host.querySelectorAll(`.${GHOST_CLASS}`).length).toBe(0);
});

test("a flat drawing ghosts nothing, since it buries nothing", () => {
  const host = drawing();
  applyHighlight(host, scene, {
    kind: "flat",
    upToStatement: 0,
    marks: [],
    newestCreaseId: null,
    constructions: [],
    highlight: [crease],
    settled: true,
  });
  expect(host.querySelectorAll(`.${GHOST_CLASS}`).length).toBe(0);
});

test("the next command clears what the last one lit", () => {
  const host = drawing();
  applyHighlight(host, scene, command([crease], true));
  applyHighlight(host, scene, command([edge], false));
  expect(host.querySelectorAll(`.${GHOST_CLASS}`).length).toBe(0);
  expect(host.querySelectorAll(`.${HL_CLASS}`).length).toBe(1);
  expect(host.querySelector(`.${HL_CLASS}`)!.hasAttribute("data-crease-id")).toBe(false);
});

test("nothing highlighted leaves the drawing as it is", () => {
  const host = drawing();
  applyHighlight(host, scene, command([], false));
  expect(host.querySelectorAll(`.${HL_CLASS}`).length).toBe(0);
  expect(host.querySelectorAll("line").length).toBe(3);
});
