// Lighting the entities a command names, on the drawing that is up.
//
// A crease is a bundle (ADR-0014): every segment sharing its id lights at
// once, across flaps and layers, rather than the one under the cursor. A paper
// boundary carries no id, so its lines are found by geometry instead.
import type { FoldScene, InspectSegment } from "@beloch/scene";
import { sceneLayout } from "@beloch/render-svg";
import type { EntityRef, RenderCommand } from "@beloch/runtime";
import { CREASE_SELECTOR, HIT_CLASS } from "./hits";
import { edgeOfLine, pointSegDist, type DrawnLine, type PaperSpace } from "./match";

export const HL_CLASS = "bel-hl";
export const GHOST_CLASS = "bel-hl-ghost";
const SVG_NS = "http://www.w3.org/2000/svg";
// Tolerance for "a line runs here", in SVG user units (about a pixel at 1:1
// zoom).
const EPS = 6;

const coordsOf = (el: Element): DrawnLine => [
  Number(el.getAttribute("x1")),
  Number(el.getAttribute("y1")),
  Number(el.getAttribute("x2")),
  Number(el.getAttribute("y2")),
];

// CSS.escape exists in browsers and in happy-dom; crease ids are small
// integers in practice, so a quote escape carries the fallback.
const escapeAttr = (id: string): string =>
  typeof CSS !== "undefined" && typeof CSS.escape === "function"
    ? CSS.escape(id)
    : id.replace(/"/g, '\\"');

// Every element carrying this crease id, minus the transparent hit twins. A
// twin must never take the highlight class: its own rule keeps it invisible,
// and a visible stroke would override that.
function bundleElements(root: ParentNode, creaseId: string): Element[] {
  return Array.from(root.querySelectorAll(`[data-crease-id="${escapeAttr(creaseId)}"]`)).filter(
    (el) => !el.classList.contains(HIT_CLASS),
  );
}

// Everything the drawing marks with `attribute="value"`, minus the hit twins.
// A construction line and a named point are drawn under the name the program
// gave them rather than under a crease id.
function namedElements(root: ParentNode, attribute: string, value: string): Element[] {
  return Array.from(
    root.querySelectorAll(`[${attribute}="${escapeAttr(value)}"]`),
  ).filter((el) => !el.classList.contains(HIT_CLASS));
}

function edgeElements(
  root: ParentNode,
  scene: FoldScene,
  name: string,
  space: PaperSpace,
): Element[] {
  const inspect = scene.inspect;
  if (!inspect) return [];
  const layout = sceneLayout(scene);
  return Array.from(root.querySelectorAll(CREASE_SELECTOR)).filter(
    (el) => edgeOfLine(inspect.edges, coordsOf(el), layout, space) === name,
  );
}

// A face is left dark: a filled face under a lit crease would compete with the
// paper it stands on. A vertex the program never named is left dark too, since
// the drawing has no mark to light for it.
const elementsFor = (
  root: ParentNode,
  scene: FoldScene,
  ref: EntityRef,
  space: PaperSpace,
): Element[] => {
  switch (ref.kind) {
    case "crease":
      return bundleElements(root, ref.creaseId);
    case "edge":
      return edgeElements(root, scene, ref.name, space);
    case "construction":
      return namedElements(root, "data-construction", ref.name);
    case "vertex":
      return ref.name === null ? [] : namedElements(root, "data-bel-name", ref.name);
    default:
      return [];
  }
};

// Lights what `refs` names, without clearing first and without ghosts. A
// caller offering several entities at once uses this: a chooser previewing the
// lines that share a pixel, or an editor showing what one source line built.
export function lightEntities(
  root: Element,
  scene: FoldScene,
  refs: EntityRef[],
  space: PaperSpace = "table",
): Element[] {
  const lit: Element[] = [];
  for (const ref of refs) {
    for (const el of elementsFor(root, scene, ref, space)) {
      el.classList.add(HL_CLASS);
      lit.push(el);
    }
  }
  return lit;
}

const segmentsFor = (scene: FoldScene, ref: EntityRef): InspectSegment[] => {
  const inspect = scene.inspect;
  if (!inspect) return [];
  if (ref.kind === "crease") return inspect.creases[ref.creaseId]?.segments ?? [];
  if (ref.kind === "edge") return inspect.edges[ref.name]?.segments ?? [];
  return [];
};

// `beloch:inspect` describes the final fold, so its coordinates line up with
// one drawing only: the folded state after the last statement. Anywhere else
// they would place geometry over a different placement of the paper.
function drawsFinalFold(scene: FoldScene, command: RenderCommand): boolean {
  if (command.kind !== "folded") return false;
  const last = scene.writes.at(-1);
  return last !== undefined && command.frame === last.frameIndex;
}

export function clearHighlight(root: ParentNode): void {
  root.querySelectorAll(`.${HL_CLASS}`).forEach((el) => el.classList.remove(HL_CLASS));
  root.querySelectorAll(`.${GHOST_CLASS}`).forEach((el) => el.remove());
}

// A settled entity's occluded segments have no drawn line, because a fold
// hides the layers below. Each of them goes in as a dashed ghost, in the SVG's
// own user space so it pans and zooms with the drawing.
function ghostBuried(
  svg: Element,
  scene: FoldScene,
  ref: EntityRef,
  drawn: Element[],
): void {
  const layout = sceneLayout(scene);
  const lit = drawn.map(coordsOf);
  for (const segment of segmentsFor(scene, ref)) {
    const ax = layout.tx(segment.table[0][0]), ay = layout.ty(segment.table[0][1]);
    const bx = layout.tx(segment.table[1][0]), by = layout.ty(segment.table[1][1]);
    const mx = (ax + bx) / 2, my = (ay + by) / 2;
    // A segment the drawing already shows has a line of this bundle running
    // along it; one that is buried has none.
    if (lit.some(([x1, y1, x2, y2]) => pointSegDist(mx, my, x1, y1, x2, y2) <= EPS)) continue;
    const line = svg.ownerDocument.createElementNS(SVG_NS, "line");
    line.setAttribute("x1", String(ax));
    line.setAttribute("y1", String(ay));
    line.setAttribute("x2", String(bx));
    line.setAttribute("y2", String(by));
    line.setAttribute("class", GHOST_CLASS);
    svg.appendChild(line);
  }
}

// Lights what `command.highlight` names on the markup under `root`, clearing
// what the previous command lit. The drawing itself is untouched, so this is
// also the whole of the work a hover costs.
//
// Ghosting is for a settled selection alone. A hover that drew segments the
// picture does not have would put dashes under the cursor on the way past
// every crease, while a reader who has picked one line asked about the buried
// rest of it.
export function applyHighlight(root: Element, scene: FoldScene, command: RenderCommand): void {
  clearHighlight(root);
  const svg = root.tagName.toLowerCase() === "svg" ? root : root.querySelector("svg");
  const ghosts = command.settled && svg !== null && drawsFinalFold(scene, command);
  // A flat sheet is drawn in the paper's own coordinates; a folded frame in the
  // table's. A paper boundary is found by where it runs, so it has to be
  // measured in the space the drawing used.
  const space: PaperSpace = command.kind === "folded" ? "table" : "paper";
  for (const ref of command.highlight) {
    const drawn = lightEntities(root, scene, [ref], space);
    if (ghosts && svg) ghostBuried(svg, scene, ref, drawn);
  }
}
