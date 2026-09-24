import { test, expect } from "bun:test";
import { cardContent, cardPlacement } from "./selection-card";

test("a card in the middle of the stage stands centred above its anchor", () => {
  expect(cardPlacement(200, 300, 400, 400)).toEqual({
    left: "200px",
    top: "300px",
    transform: "translate(-50%, calc(-100% - 14px))",
  });
});

test("a card near the left edge grows to the right of its anchor", () => {
  expect(cardPlacement(40, 300, 400, 400).transform).toBe("translate(-12px, calc(-100% - 14px))");
});

test("a card near the right edge grows to the left of its anchor", () => {
  expect(cardPlacement(360, 300, 400, 400).transform).toBe(
    "translate(calc(-100% + 12px), calc(-100% - 14px))",
  );
});

test("a card near the top stands below its anchor", () => {
  expect(cardPlacement(200, 40, 400, 400).transform).toBe("translate(-50%, 14px)");
});

test("a card names the entity, the line that made it, and that line's text", () => {
  const source = "paper square\n\nfold (map .a onto .c) as --bd";
  expect(cardContent({ title: "--bd", detail: "1 segment" }, 3, source)).toEqual({
    name: "--bd",
    line: 3,
    text: "fold (map .a onto .c) as --bd",
  });
});

test("a card with no line to point at says what the summary says", () => {
  expect(cardContent({ title: "face 2", detail: "flap 0 · rank 1" }, null, "paper square")).toEqual({
    name: "face 2",
    line: null,
    text: "flap 0 · rank 1",
  });
});

test("a line outside the source the run answered gives no text of its own", () => {
  expect(cardContent({ title: "--bd", detail: "" }, 9, "paper square")).toEqual({
    name: "--bd",
    line: 9,
    text: null,
  });
});
