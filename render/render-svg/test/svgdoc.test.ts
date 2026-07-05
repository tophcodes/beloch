import { test, expect } from "bun:test";
import { createDoc, el } from "../src/svgdoc";
import { DOMImplementation } from "@xmldom/xmldom";

test("toString: root svg with viewBox, escaped attrs, nested children", () => {
  const doc = createDoc(100, 50);
  doc.layer("creases").children.push(
    el("line", { x1: 0, y1: 0, x2: 10, y2: 10, "data-name": 'a"<b' }),
  );
  const s = doc.toString();
  expect(s).toStartWith(`<svg xmlns="http://www.w3.org/2000/svg"`);
  expect(s).toContain(`viewBox="0 0 100 50"`);
  expect(s).toContain(`data-name="a&quot;&lt;b"`);
  expect(s).toContain(`<g data-layer="creases">`);
});

test("layers serialize in fixed order regardless of touch order", () => {
  const doc = createDoc(10, 10);
  doc.layer("hud").children.push(el("text", {}, [], "late"));
  doc.layer("paper").children.push(el("rect", { width: 1, height: 1 }));
  const s = doc.toString();
  expect(s.indexOf('data-layer="paper"')).toBeLessThan(s.indexOf('data-layer="hud"'));
});

test("text content is escaped and serialized", () => {
  const doc = createDoc(10, 10);
  doc.layer("hud").children.push(el("text", { x: 1 }, [], "a<b & c"));
  expect(doc.toString()).toContain(">a&lt;b &amp; c</text>");
});

test("toDOM builds namespaced elements with attributes", () => {
  const doc = createDoc(20, 20);
  doc.layer("annotations").children.push(el("circle", { cx: 5, cy: 5, r: 2 }));
  const dom = new DOMImplementation().createDocument(null, null as unknown as string, null);
  const root = doc.toDOM(dom as unknown as Document);
  expect(root.tagName).toBe("svg");
  expect(root.namespaceURI).toBe("http://www.w3.org/2000/svg");
  const circle = root.getElementsByTagName("circle")[0]!;
  expect(circle.getAttribute("cx")).toBe("5");
});
