// Lighting the entities a command names, on the drawing that is up.
//
// A crease is a bundle (ADR-0014): every segment sharing its id lights at
// once, across flaps and layers, rather than the one under the cursor. A paper
// boundary carries no id, so its lines are found by geometry instead.
import type { FoldScene, InspectSegment } from "@beloch/scene";
import { sceneLayout } from "@beloch/render-svg";
import type { EntityRef, RenderCommand } from "@beloch/runtime";
import { CREASE_SELECTOR, HIT_CLASS } from "./hits";
import { edgeOfLine, pointSegDist, type DrawnLine } from "./match";

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

function edgeElements(root: ParentNode, scene: FoldScene, name: string): Element[] {
  const inspect = scene.inspect;
  if (!inspect) return [];
  const layout = sceneLayout(scene);
  return Array.from(root.querySelectorAll(CREASE_SELECTOR)).filter(
    (el) => edgeOfLine(inspect.edges, coordsOf(el), layout) === name,
  );
}

const elementsFor = (root: ParentNode, scene: FoldScene, ref: EntityRef): Element[] =>
  ref.kind === "crease" ? bundleElements(root, ref.creaseId) : edgeElements(root, scene, ref.name);

const segmentsFor = (scene: FoldScene, ref: EntityRef): InspectSegment[] => {
  const inspect = scene.inspect;
  if (!inspect) return [];
  return (
    (ref.kind === "crease" ? inspect.creases[ref.creaseId] : inspect.edges[ref.name])?.segments ?? []
  );
};

// `beloch:inspect` describes the final fold, so its coordinates line up with
// one drawing only: the folded state after the last statement. Anywhere else
// they would place geometry over a different placement of the paper.
function drawsFinalFold(scene: FoldScene, command: RenderCommand): boolean {
  if (command.kind !== "folded") return false;
  const last = scene.statements.at(-1);
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
  for (const ref of command.highlight) {
    const drawn = elementsFor(root, scene, ref);
    drawn.forEach((el) => el.classList.add(HL_CLASS));
    if (ghosts && svg) ghostBuried(svg, scene, ref, drawn);
  }
}
