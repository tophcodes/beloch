import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

const { buildHitLine, enhanceHits, HIT_CLASS } = await import("../src/hits");

const mountSvg = (inner: string): Element => {
  const container = document.createElement("div");
  container.innerHTML =
    `<svg><g data-layer="paper"></g><g data-layer="creases">${inner}</g></svg>`;
  return container;
};

const mountDots = (inner: string): Element => {
  const container = document.createElement("div");
  container.innerHTML = `<svg><g data-layer="annotations">${inner}</g></svg>`;
  return container;
};

test("a hit line copies the endpoints and the crease id", () => {
  const container = mountSvg(
    '<line data-kind="crease" data-crease-id="3" x1="1" y1="2" x2="3" y2="4"></line>',
  );
  const hit = buildHitLine(container.querySelector("line")!);
  expect(hit.getAttribute("x1")).toBe("1");
  expect(hit.getAttribute("y1")).toBe("2");
  expect(hit.getAttribute("x2")).toBe("3");
  expect(hit.getAttribute("y2")).toBe("4");
  expect(hit.getAttribute("data-crease-id")).toBe("3");
  expect(hit.getAttribute("class")).toBe(HIT_CLASS);
});

test("one twin per crease line, right after it", () => {
  const container = mountSvg(
    '<line data-kind="crease" data-crease-id="3" x1="0" y1="0" x2="1" y2="1"></line>' +
      '<line data-kind="crease" data-crease-id="4" x1="2" y1="2" x2="3" y2="3"></line>',
  );
  enhanceHits(container);
  expect(container.querySelectorAll(`.${HIT_CLASS}`)).toHaveLength(2);
  const [first] = container.querySelectorAll('[data-kind="crease"]');
  expect(first!.nextElementSibling?.classList.contains(HIT_CLASS)).toBe(true);
});

test("a mark overlay line is a target, a mark tick is not", () => {
  const container = mountSvg(
    '<line data-kind="crease" data-crease-id="3" x1="0" y1="0" x2="1" y2="1"></line>' +
      '<line data-kind="mark" data-crease-id="3" x1="0" y1="0" x2="1" y2="1"></line>' +
      '<line data-kind="mark-tick" data-crease-id="3" x1="0" y1="0" x2="0.1" y2="0.1"></line>',
  );
  enhanceHits(container);
  // A flat precrease reads as a crease and earns the forgiving hover; the tiny
  // partial-mark tick does not.
  expect(container.querySelectorAll(`.${HIT_CLASS}`)).toHaveLength(2);
});

test("a second pass over unchanged markup stacks nothing", () => {
  const container = mountSvg(
    '<line data-kind="crease" data-crease-id="3" x1="0" y1="0" x2="1" y2="1"></line>',
  );
  enhanceHits(container);
  enhanceHits(container);
  expect(container.querySelectorAll(`.${HIT_CLASS}`)).toHaveLength(1);
});

test("a paper boundary carries no crease id and is a target anyway", () => {
  const container = mountSvg('<line data-kind="crease" x1="0" y1="0" x2="1" y2="0"></line>');
  enhanceHits(container);
  const hits = container.querySelectorAll(`.${HIT_CLASS}`);
  expect(hits).toHaveLength(1);
  expect(hits[0]!.hasAttribute("data-crease-id")).toBe(false);
  expect(hits[0]!.getAttribute("x2")).toBe("1");
});

test("a point dot gets a disc that carries the dot's identity", () => {
  const container = mountDots(
    '<circle data-kind="point" data-vertex="7" data-bel-name="m" cx="5" cy="6" r="3"></circle>' +
      '<circle data-vertex="8" cx="9" cy="9" r="3"></circle>',
  );
  enhanceHits(container);
  const hits = container.querySelectorAll(`.${HIT_CLASS}`);
  // Both dots are hoverable: a crossing carries no name and is still an entity
  // the inspector resolves by its vertex.
  expect(hits.length).toBe(2);
  const first = hits[0]!;
  expect(first.getAttribute("cx")).toBe("5");
  expect(first.getAttribute("cy")).toBe("6");
  expect(Number(first.getAttribute("r"))).toBeGreaterThan(3);
  expect(first.getAttribute("data-vertex")).toBe("7");
  expect(first.getAttribute("data-bel-name")).toBe("m");
});

test("a second pass over the dots stacks nothing either", () => {
  const container = mountDots('<circle data-vertex="1" cx="1" cy="1" r="3"></circle>');
  enhanceHits(container);
  enhanceHits(container);
  expect(container.querySelectorAll(`.${HIT_CLASS}`).length).toBe(1);
});

test("labels and lines outside the crease layer are left alone", () => {
  const container = mountDots(
    '<text data-bel-name="a">.a</text><line data-kind="crease" x1="0" y1="0" x2="1" y2="1"></line>',
  );
  enhanceHits(container);
  expect(container.querySelectorAll(`.${HIT_CLASS}`).length).toBe(0);
});
