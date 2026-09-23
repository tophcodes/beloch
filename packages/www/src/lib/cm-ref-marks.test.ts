import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { EditorState } from "@codemirror/state";
import { EditorView } from "codemirror";
import { spanToRange, refMarkExtensions, setRefSpansOn } from "./cm-ref-marks";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

const DOC = "paper square\nmark (map .a onto .c) as --diag\nmark (map --ab onto --diag) as --l1\n";

function mountEditor(doc: string): EditorView {
  const state = EditorState.create({ doc, extensions: refMarkExtensions });
  const parent = document.createElement("div");
  document.body.appendChild(parent);
  return new EditorView({ state, parent });
}

test("spanToRange lands on the text the span names", () => {
  const state = EditorState.create({ doc: DOC });
  // line 3 cols 11-15 is `--ab` in `mark (map --ab onto --diag) as --l1`
  const r = spanToRange(state, "f.bel:3:11-15")!;
  expect(state.doc.sliceString(r.from, r.to)).toBe("--ab");
  // cols 21-27 is `--diag` on the same line
  const d = spanToRange(state, "f.bel:3:21-27")!;
  expect(state.doc.sliceString(d.from, d.to)).toBe("--diag");
});

test("spanToRange declines a span the document no longer holds", () => {
  const state = EditorState.create({ doc: "one line only\n" });
  expect(spanToRange(state, "f.bel:9:1-4")).toBeNull();
  expect(spanToRange(state, "f.bel:1:5-5")).toBeNull(); // empty range
});

test("setRefSpansOn marks every span, and an empty list clears them", () => {
  const view = mountEditor(DOC);
  setRefSpansOn(view, ["f.bel:3:11-15", "f.bel:3:21-27"]);
  expect(view.dom.querySelectorAll(".cm-bel-ref").length).toBe(2);
  setRefSpansOn(view, []);
  expect(view.dom.querySelectorAll(".cm-bel-ref").length).toBe(0);
});

test("a duplicate span marks once rather than throwing", () => {
  const view = mountEditor(DOC);
  setRefSpansOn(view, ["f.bel:3:11-15", "f.bel:3:11-15"]);
  expect(view.dom.querySelectorAll(".cm-bel-ref").length).toBe(1);
});

// The spans describe the text the last run saw. An edit can put them out of
// range, and a decoration pointing past the end of the document would throw.
test("an edit past the end of the marked text drops the mark", () => {
  const view = mountEditor(DOC);
  setRefSpansOn(view, ["f.bel:3:11-15"]);
  expect(view.dom.querySelectorAll(".cm-bel-ref").length).toBe(1);
  view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: "x\n" } });
  expect(view.dom.querySelectorAll(".cm-bel-ref").length).toBe(0);
});
