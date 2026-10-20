import { beforeAll, expect, test } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { figureLightboxScript } from "./figure-lightbox";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

// The script is text Starlight writes into the page head; a syntax error in
// it would reach every reader and no bundler sees it first.
test("the lightbox script parses as a program", () => {
  expect(() => new Function(figureLightboxScript())).not.toThrow();
});

test("a click on a figure view opens the drawing large, Escape closes it, + zooms", () => {
  document.body.innerHTML =
    '<figure class="figure"><div class="figure-views"><div class="figure-view" data-view="cp">' +
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100" width="200" height="100"><rect width="200" height="100"/></svg>' +
    "</div></div></figure>";
  new Function(figureLightboxScript())();
  const view = document.querySelector(".figure-view") as HTMLElement;
  expect(view.getAttribute("role")).toBe("button");
  view.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  const box = document.querySelector(".figure-lightbox") as HTMLElement;
  expect(box).not.toBeNull();
  expect(box.hidden).toBe(false);
  expect(box.querySelector(".figure-lightbox-stage svg")).not.toBeNull();
  expect(document.body.classList.contains("figure-lightbox-open")).toBe(true);
  const stage = box.querySelector(".figure-lightbox-stage") as HTMLElement;
  const before = stage.style.transform;
  document.dispatchEvent(new KeyboardEvent("keydown", { key: "+", bubbles: true }));
  expect(stage.style.transform).not.toBe(before);
  document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
  expect(box.hidden).toBe(true);
  expect(document.body.classList.contains("figure-lightbox-open")).toBe(false);
});
