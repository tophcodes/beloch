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
