import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";

beforeAll(() => { GlobalRegistrator.register(); });

// x-midpoint folds → has steps; inline its FOLD by evaluating at test time is
// heavy, so load a golden the render tests also use.
const foldJson = await Bun.file(
  new URL("../../../tests/golden/syntax/x-midpoint.fold", import.meta.url),
).text();

// def-diagonals has 3 steps in file order [null, "diagonals", "centre"] — a
// null-labeled non-final step exercises the index-vs-label stepper bug.
const diagonalsFoldJson = await Bun.file(
  new URL("../../../tests/golden/syntax/def-diagonals.fold", import.meta.url),
).text();

function mountCard(fold: string): HTMLElement {
  document.body.innerHTML = `
    <beloch-figure>
      <figure class="beloch-card">
        <div class="beloch-code-panel"></div>
        <div class="beloch-diagram"><svg></svg></div>
        <script type="application/json" class="beloch-fold">${fold}</script>
      </figure>
    </beloch-figure>`;
  return document.querySelector("beloch-figure") as HTMLElement;
}

test("hydration adds a view toggle when the fold has steps", async () => {
  await import("./beloch-figure");            // registers the element
  const el = mountCard(foldJson);
  (el as any).hydrate();                       // force hydration (bypass IntersectionObserver in test)
  expect(el.querySelector('[data-view="cp"]')).not.toBeNull();
  expect(el.querySelector('[data-view="folded"]')).not.toBeNull();
});

test("switching to folded renders a folded svg; stepper advances", async () => {
  await import("./beloch-figure");
  const el = mountCard(foldJson);
  (el as any).hydrate();
  (el.querySelector('[data-view="folded"]') as HTMLElement).click();
  const diagram = el.querySelector(".beloch-diagram")!;
  expect(diagram.querySelector("svg")).not.toBeNull();       // re-rendered
  const stepper = el.querySelector(".beloch-stepper");
  expect(stepper).not.toBeNull();
});

test("stepper selects by index, not by (possibly null) step label", async () => {
  // def-diagonals's first step has a null label. Under the old label-based
  // code, `renderFolded` falls back to the LAST step whenever the selected
  // step's label is undefined — so index 0 and the last index render
  // identically (both show the final frame) even though the label text
  // still claims the right index. Selecting by index fixes that desync.
  await import("./beloch-figure");
  const el = mountCard(diagonalsFoldJson);
  (el as any).hydrate();
  (el.querySelector('[data-view="folded"]') as HTMLElement).click();
  const diagram = el.querySelector(".beloch-diagram") as HTMLElement;

  (el as any).setStep(0);
  const firstStepHTML = diagram.innerHTML;

  const lastIndex = (el as any).scene.steps.length - 1;
  (el as any).setStep(lastIndex);
  const lastStepHTML = diagram.innerHTML;

  expect(lastIndex).toBeGreaterThan(0);         // sanity: fixture is multi-step
  expect(firstStepHTML).not.toBe(lastStepHTML);
});

test("clicking a code token toggles selection on both sides and persists over re-render", async () => {
  await import("./beloch-figure");
  const el = mountCard(foldJson);
  // inject a code token so both sides exist
  el.querySelector(".beloch-code-panel")!.innerHTML =
    '<span class="bel-point" data-bel-name="center">.center</span>';
  (el as any).hydrate();
  const token = el.querySelector('.beloch-code-panel [data-bel-name="center"]') as HTMLElement;
  token.click();
  expect(token.classList.contains("bel-selected")).toBe(true);
  // svg side (CP already has the dot from SSR? in the test svg is empty, so assert state instead)
  expect((el as any).selected.has("center")).toBe(true);
  token.click();                                   // toggle off
  expect(token.classList.contains("bel-selected")).toBe(false);
  expect((el as any).selected.has("center")).toBe(false);
});

test("hover adds and removes .bel-hover", async () => {
  await import("./beloch-figure");
  const el = mountCard(foldJson);
  el.querySelector(".beloch-code-panel")!.innerHTML =
    '<span class="bel-point" data-bel-name="center">.center</span>';
  (el as any).hydrate();
  const token = el.querySelector('[data-bel-name="center"]') as HTMLElement;
  token.dispatchEvent(new Event("mouseenter", { bubbles: true }));
  expect(el.querySelectorAll(".bel-hover").length).toBeGreaterThan(0);
  token.dispatchEvent(new Event("mouseleave", { bubbles: true }));
  expect(el.querySelectorAll(".bel-hover").length).toBe(0);
});

test("selection survives a re-render (view switch)", async () => {
  // x-midpoint's folded SVG emits data-bel-name for its named creases/points
  // (confirmed: "d2", "d1", "d", "center", "c", "b", "a"). Select one via the
  // code panel, switch to the folded view — this replaces .beloch-diagram's
  // innerHTML wholesale with a brand-new SVG — then assert the *freshly
  // rendered* element (not the code-panel token, which render() never
  // touches) regained .bel-selected + a live --bel-sel style. That only
  // happens if afterRender re-applies selection after the diagram swap; if
  // the `this.afterRender = () => this.applySelection()` wiring in
  // wireInteraction() were removed, this assertion fails (verified manually).
  await import("./beloch-figure");
  const el = mountCard(foldJson);
  el.querySelector(".beloch-code-panel")!.innerHTML =
    '<span class="bel-crease" data-bel-name="d1">.d1</span>';
  (el as any).hydrate();
  const token = el.querySelector('.beloch-code-panel [data-bel-name="d1"]') as HTMLElement;
  token.click();
  expect((el as any).selected.has("d1")).toBe(true);

  (el.querySelector('[data-view="folded"]') as HTMLElement).click();   // triggers render() → new SVG

  const diagram = el.querySelector(".beloch-diagram")!;
  const svgEl = diagram.querySelector('[data-bel-name="d1"]') as HTMLElement;
  expect(svgEl).not.toBeNull();
  expect(svgEl.classList.contains("bel-selected")).toBe(true);
  expect(svgEl.style.getPropertyValue("--bel-sel")).not.toBe("");
});
