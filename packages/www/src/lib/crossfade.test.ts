import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

const { swapDrawing } = await import("./crossfade");

const host = (inner: string): HTMLElement => {
  const el = document.createElement("div");
  el.innerHTML = inner;
  return el;
};

test("without a fade the drawing is replaced outright", () => {
  const el = host('<svg id="before"></svg>');
  swapDrawing(el, '<svg id="after"></svg>', null);
  expect(el.querySelectorAll("svg").length).toBe(1);
  expect(el.querySelector("svg")!.id).toBe("after");
  expect(el.querySelector(".bel-fade-ghost")).toBeNull();
});

test("a fade keeps the state that was left, behind the one arrived at", () => {
  const el = host('<svg id="before"></svg>');
  swapDrawing(el, '<svg id="after"></svg>', "fold");

  // Everything that reaches for the drawing takes the first svg in the
  // document, so the current step has to come first.
  expect(el.querySelector("svg")!.id).toBe("after");

  const ghost = el.querySelector(".bel-fade-ghost")!;
  expect(ghost.querySelector("svg")!.id).toBe("before");
  expect(ghost.getAttribute("aria-hidden")).toBe("true");
  expect((ghost as HTMLElement).style.getPropertyValue("--bel-fade-length"))
    .toBe("var(--bel-duration-fold)");
});

test("a step clicked during a fade drops the fade it interrupts", () => {
  const el = host('<svg id="one"></svg>');
  swapDrawing(el, '<svg id="two"></svg>', "fold");
  swapDrawing(el, '<svg id="three"></svg>', "fold");

  expect(el.querySelectorAll(".bel-fade-ghost").length).toBe(1);
  expect(el.querySelector("svg")!.id).toBe("three");
  expect(el.querySelector(".bel-fade-ghost svg")!.id).toBe("two");
});
