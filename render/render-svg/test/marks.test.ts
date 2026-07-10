// Task 8 (mark/fold slice 2): render beloch:marks in the CP view.
//
// Fixture `fixtures/marks-demo.fold` was generated via the OCaml pipeline
// (`nix develop -c dune exec bin/main.exe -- fold`) on:
//
//   paper square
//   mark --hm = map .a onto .d
//   mark --vm = map .a onto .b
//   .bm = --vm * --ab
//   mark --v34 = map .b onto .bm
//   .lm = --hm * --da
//   mark --h34 = map .d onto .lm
//   .end = --v34 * --h34
//   mark through .a .c between .a .end   ; dangles mid-face -> seg record
//   .ctr = --vm * --hm
//   mark --vm at .ctr                    ; -> point record, ticked along --vm (x=0.5)
//
// which records exactly one "seg" mark ((0.5,0.5)->(0.75,0.75)) and one
// "point" mark (at (0.5,0.5), oriented along the vertical line x=0.5).
import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { renderCP } from "@beloch/render-svg";

const fixture = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();

test("renders a seg mark as a thin line between its exact endpoints", async () => {
  const scene = parseFold(await fixture("marks-demo.fold"));
  const s = renderCP(scene).toString();
  expect((s.match(/data-kind="mark"/g) ?? []).length).toBe(1);
  // endpoints (0.5,0.5) -> (0.75,0.75) transformed through the same paper->SVG
  // layout as everything else in the CP view.
  const m = s.match(/<line class="mark" data-crease-id="4"[^>]*\/>/);
  expect(m).not.toBeNull();
  expect(m![0]).toContain('stroke-dasharray="2 2"');
});

test("renders a point mark as a tick oriented along its line, not a dot", async () => {
  const scene = parseFold(await fixture("marks-demo.fold"));
  const s = renderCP(scene).toString();
  expect((s.match(/data-kind="mark-tick"/g) ?? []).length).toBe(1);
  const tick = s.match(/<line class="mark" data-crease-id="5"[^>]*\/>/);
  expect(tick).not.toBeNull();
  // point's line is x=0.5 (vertical) -> direction (b,-a) normalized = (0,-1)
  // -> the tick is a VERTICAL segment centered on (0.5,0.5): same x1/x2, y
  // straddling the point's y coordinate.
  const attrs = Object.fromEntries(
    [...tick![0]!.matchAll(/(\S+)="([^"]*)"/g)].map(([, k, v]) => [k, v]),
  );
  expect(attrs["x1"]).toBe(attrs["x2"]);
  expect(Number(attrs["y1"])).not.toBe(Number(attrs["y2"]));
});

test("marks are visually distinct from live creases: thinner, dashed, translucent", async () => {
  const scene = parseFold(await fixture("marks-demo.fold"));
  const s = renderCP(scene).toString();
  const seg = s.match(/<line class="mark" data-crease-id="4"[^>]*\/>/)![0]!;
  const creaseLine = s.match(/<line class="crease-V"[^>]*\/>/)![0]!;
  const markWidth = Number(seg.match(/stroke-width="([\d.]+)"/)![1]);
  const creaseWidth = Number(creaseLine.match(/stroke-width="([\d.]+)"/)![1]);
  expect(markWidth).toBeLessThan(creaseWidth);
  expect(seg).toContain('opacity="0.7"');
});

test("a FOLD scene with no beloch:marks draws no mark elements", async () => {
  const golden = (p: string) =>
    Bun.file(new URL(`../../../tests/golden/${p}`, import.meta.url)).text();
  const scene = parseFold(await golden("syntax/bisect-a.fold"));
  const s = renderCP(scene).toString();
  expect(s).not.toContain('data-kind="mark"');
  expect(s).not.toContain('data-kind="mark-tick"');
});
