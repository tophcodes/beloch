import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { lookupEntity } from "./inspect-lookup";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

test("lookupEntity resolves a crease element", () => {
  const el = document.createElement("line");
  el.setAttribute("data-crease-id", "3");
  expect(lookupEntity(el)).toEqual({ kind: "crease", creaseId: "3" });
});

test("lookupEntity resolves a face element", () => {
  const el = document.createElement("polygon");
  el.setAttribute("data-face-index", "2");
  expect(lookupEntity(el)).toEqual({ kind: "face", index: "2" });
});

test("lookupEntity resolves a named vertex, carrying its point name", () => {
  const el = document.createElement("circle");
  el.setAttribute("data-vertex", "5");
  el.setAttribute("data-bel-name", "r");
  expect(lookupEntity(el)).toEqual({ kind: "vertex", index: 5, name: "r" });
});

test("lookupEntity resolves an unnamed vertex with name: null", () => {
  const el = document.createElement("circle");
  el.setAttribute("data-vertex", "0");
  expect(lookupEntity(el)).toEqual({ kind: "vertex", index: 0, name: null });
});

test("lookupEntity walks up to the nearest ancestor carrying the data attribute", () => {
  const parent = document.createElement("g");
  parent.setAttribute("data-crease-id", "7");
  const child = document.createElement("line");
  parent.appendChild(child);
  expect(lookupEntity(child)).toEqual({ kind: "crease", creaseId: "7" });
});

test("lookupEntity returns null for an element with no matching data attribute", () => {
  const el = document.createElement("rect");
  expect(lookupEntity(el)).toBeNull();
});
