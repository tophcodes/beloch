import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { bundleElements } from "./bundle-highlight";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

function mount(html: string): Element {
  const g = document.createElementNS("http://www.w3.org/2000/svg", "g");
  g.innerHTML = html;
  return g;
}

test("bundleElements finds every element carrying the given crease id", () => {
  const g = mount(
    '<line data-crease-id="3" data-kind="crease"></line>' +
      '<line data-crease-id="3" data-kind="crease"></line>' +
      '<line data-crease-id="4" data-kind="crease"></line>',
  );
  expect(bundleElements(g, "3")).toHaveLength(2);
});

test("bundleElements excludes synthetic .pg-hit twins", () => {
  const g = mount(
    '<line data-crease-id="3" data-kind="crease"></line>' +
      '<line data-crease-id="3" class="pg-hit"></line>',
  );
  const found = bundleElements(g, "3");
  expect(found).toHaveLength(1);
  expect(found[0]!.classList.contains("pg-hit")).toBe(false);
});

test("bundleElements returns an empty array when no element carries the id", () => {
  const g = mount('<line data-crease-id="3"></line>');
  expect(bundleElements(g, "9")).toEqual([]);
});
