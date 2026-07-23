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

test("enhanceCreaseHits enhances crease + mark overlay lines, but not mark-tick", () => {
  const container = mountSvg(
    '<line data-kind="crease" data-crease-id="3" x1="0" y1="0" x2="1" y2="1"></line>' +
      '<line data-kind="mark" data-crease-id="3" x1="0" y1="0" x2="1" y2="1"></line>' +
      '<line data-kind="mark-tick" data-crease-id="3" x1="0" y1="0" x2="0.1" y2="0.1"></line>',
  );
  enhanceCreaseHits(container);
  // A flat precrease ("mark") reads as a crease and gets the fat hover target;
  // the tiny partial-mark tick does not.
  expect(container.querySelectorAll(`.${HIT_CLASS}`)).toHaveLength(2);
});

test("enhanceCreaseHits is idempotent — a second call on the same markup adds nothing", () => {
  const container = mountSvg(
    '<line data-kind="crease" data-crease-id="3" x1="0" y1="0" x2="1" y2="1"></line>',
  );
  enhanceCreaseHits(container);
  enhanceCreaseHits(container);
  expect(container.querySelectorAll(`.${HIT_CLASS}`)).toHaveLength(1);
});

// Task 9: paper boundary (type B) lines carry no data-crease-id at all (no
// per-edge id exists) — they must still get a hit-area sibling.
test("buildHitLine omits data-crease-id for a boundary line that has none", () => {
  const container = mountSvg('<line data-kind="crease" x1="0" y1="0" x2="1" y2="0"></line>');
  const line = container.querySelector("line")!;
  const hit = buildHitLine(document, line);
  expect(hit.hasAttribute("data-crease-id")).toBe(false);
});

test("enhanceCreaseHits enhances a boundary line with no data-crease-id too", () => {
  const container = mountSvg('<line data-kind="crease" x1="0" y1="0" x2="1" y2="0"></line>');
  enhanceCreaseHits(container);
  const hits = container.querySelectorAll(`.${HIT_CLASS}`);
  expect(hits).toHaveLength(1);
  expect(hits[0]!.hasAttribute("data-crease-id")).toBe(false);
  expect(hits[0]!.getAttribute("x2")).toBe("1");
});
