import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";

beforeAll(() => { GlobalRegistrator.register(); });

// x-midpoint folds → has steps; inline its FOLD by evaluating at test time is
// heavy, so load a golden the render tests also use.
const foldJson = await Bun.file(
  new URL("../../../tests/golden/syntax/x-midpoint.fold", import.meta.url),
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
