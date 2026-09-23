import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { DEFAULT_THEME } from "@beloch/render-svg";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

const { applyEmphasis, clearEmphasis, EMPHASIS_CLASS, EMPHASIS_VAR } = await import("../src/emphasis");
const { HIT_CLASS } = await import("../src/hits");

// A crease with its hit twin, a construction overlay, and a named point.
const drawing = (): Element => {
  const host = document.createElement("div");
  host.innerHTML =
    `<svg>` +
    `<g data-layer="creases">` +
    `<line data-kind="crease" data-crease-id="3"></line>` +
    `<line class="${HIT_CLASS}" data-crease-id="3"></line>` +
    `</g>` +
    `<g data-layer="annotations">` +
    `<g class="construction" data-construction="slant" data-name="slant"></g>` +
    `<circle data-vertex="7" data-bel-name="m"></circle>` +
    `</g></svg>`;
  return host;
};

const nothing = { creases: [], points: [], lines: [] };

test("every kind the source named is lit", () => {
  const host = drawing();
  applyEmphasis(host, { creases: ["3"], points: ["m"], lines: ["slant"] });
  expect(host.querySelectorAll(`.${EMPHASIS_CLASS}`).length).toBe(3);
});

test("a hit twin stays dark", () => {
  const host = drawing();
  applyEmphasis(host, { creases: ["3"], points: [], lines: [] });
  expect(host.querySelector(`.${HIT_CLASS}`)!.classList.contains(EMPHASIS_CLASS)).toBe(false);
});

test("each entity takes its own palette colour", () => {
  const host = drawing();
  applyEmphasis(host, { creases: ["3"], points: ["m"], lines: ["slant"] });
  const lit = Array.from(host.querySelectorAll<HTMLElement>(`.${EMPHASIS_CLASS}`));
  const colours = lit.map((el) => el.style.getPropertyValue(EMPHASIS_VAR));
  expect(new Set(colours).size).toBe(3);
  for (const colour of colours) {
    expect(DEFAULT_THEME.highlightPalette.map((c) => c.stroke)).toContain(colour);
  }
});

test("an entity the drawing does not carry lights nothing", () => {
  const host = drawing();
  applyEmphasis(host, { creases: ["99"], points: ["nowhere"], lines: ["gone"] });
  expect(host.querySelectorAll(`.${EMPHASIS_CLASS}`).length).toBe(0);
});

test("the next call clears what the last one lit", () => {
  const host = drawing();
  applyEmphasis(host, { creases: ["3"], points: ["m"], lines: ["slant"] });
  applyEmphasis(host, { creases: ["3"], points: [], lines: [] });
  expect(host.querySelectorAll(`.${EMPHASIS_CLASS}`).length).toBe(1);
  applyEmphasis(host, nothing);
  expect(host.querySelectorAll(`.${EMPHASIS_CLASS}`).length).toBe(0);
});

test("clearing takes the colour off with the class", () => {
  const host = drawing();
  applyEmphasis(host, { creases: ["3"], points: [], lines: [] });
  clearEmphasis(host);
  const line = host.querySelector<HTMLElement>('[data-kind="crease"]')!;
  expect(line.style.getPropertyValue(EMPHASIS_VAR)).toBe("");
});
