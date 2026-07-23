import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { buildHitLine, enhanceCreaseHits, HIT_CLASS } from "./crease-hits";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

function mountSvg(inner: string): Element {
  const container = document.createElement("div");
  container.innerHTML =
    `<svg>` +
    `<g data-layer="paper"></g>` +
    `<g data-layer="creases">${inner}</g>` +
    `</svg>`;
  return container;
}

test("buildHitLine copies endpoints and crease id, tagging the pg-hit class", () => {
  const container = mountSvg(
    '<line data-kind="crease" data-crease-id="3" x1="1" y1="2" x2="3" y2="4"></line>',
  );
  const line = container.querySelector("line")!;
  const hit = buildHitLine(document, line);
  expect(hit.getAttribute("x1")).toBe("1");
  expect(hit.getAttribute("y1")).toBe("2");
  expect(hit.getAttribute("x2")).toBe("3");
  expect(hit.getAttribute("y2")).toBe("4");
  expect(hit.getAttribute("data-crease-id")).toBe("3");
  expect(hit.getAttribute("class")).toBe(HIT_CLASS);
});

test("enhanceCreaseHits inserts one hit-line sibling per crease line", () => {
  const container = mountSvg(
    '<line data-kind="crease" data-crease-id="3" x1="0" y1="0" x2="1" y2="1"></line>' +
      '<line data-kind="crease" data-crease-id="4" x1="2" y1="2" x2="3" y2="3"></line>',
  );
  enhanceCreaseHits(container);
  expect(container.querySelectorAll(`.${HIT_CLASS}`)).toHaveLength(2);
  const [first] = container.querySelectorAll('[data-kind="crease"]');
  expect(first!.nextElementSibling?.classList.contains(HIT_CLASS)).toBe(true);
});

test("enhanceCreaseHits does not enhance mark/mark-tick overlay lines", () => {
  const container = mountSvg(
    '<line data-kind="crease" data-crease-id="3" x1="0" y1="0" x2="1" y2="1"></line>' +
      '<line data-kind="mark" data-crease-id="3" x1="0" y1="0" x2="1" y2="1"></line>',
  );
  enhanceCreaseHits(container);
  expect(container.querySelectorAll(`.${HIT_CLASS}`)).toHaveLength(1);
});

test("enhanceCreaseHits is idempotent — a second call on the same markup adds nothing", () => {
  const container = mountSvg(
    '<line data-kind="crease" data-crease-id="3" x1="0" y1="0" x2="1" y2="1"></line>',
  );
  enhanceCreaseHits(container);
  enhanceCreaseHits(container);
  expect(container.querySelectorAll(`.${HIT_CLASS}`)).toHaveLength(1);
});
