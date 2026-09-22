// FOLD -> logo mark. The repo's fold2svg renders a diagram: face polygons, a
// legend, labels, ~6 kB on a 572 grid. A mark needs the opposite: no faces, no
// text, a square viewBox, one path per crease assignment.
//
//   nix develop --command dune exec beloch -- fold <prog>.bel > /tmp/p.fold
//   bun docs/brand/logo-explorations/fold2logo.ts /tmp/p.fold out.svg [--plain]
//
// --plain draws every crease with the same solid stroke, which is the fassung
// for sizes below ~48 px where dash patterns collapse into dotted noise.
// --marks-only drops the F edges, the scaffolding the program marked but never
// folded. What remains is the boundary and the creases that actually move paper.

interface Fold {
  vertices_coords: [number, number][];
  edges_vertices: [number, number][];
  edges_assignment?: string[];
}

const SIZE = 64;
const PAD = 6;

// Stroke weights follow render-svg's theme.ts proportions (boundary 3, crease 2)
// scaled to a 64 grid, then the dash patterns from its yrLineStyle.
const STYLE: Record<string, { w: number; dash?: string }> = {
  B: { w: 4 },
  M: { w: 3, dash: "6 2.5 1 2.5" },
  V: { w: 3, dash: "4.5 3" },
  F: { w: 2 },
  U: { w: 2, dash: "1.5 3" },
};
const ORDER = ["B", "F", "V", "M", "U"];

function main() {
  const [src, out, ...flags] = process.argv.slice(2);
  if (!src || !out) {
    console.error("usage: fold2logo.ts <in.fold> <out.svg> [--plain] [--no-boundary]");
    process.exit(2);
  }
  const plain = flags.includes("--plain");
  const dropBoundary = flags.includes("--no-boundary");
  const marksOnly = flags.includes("--marks-only");

  const fold: Fold = JSON.parse(require("fs").readFileSync(src, "utf-8"));
  const verts = fold.vertices_coords;
  const assign = fold.edges_assignment ?? fold.edges_vertices.map(() => "U");

  const xs = verts.map((v) => v[0]);
  const ys = verts.map((v) => v[1]);
  const minX = Math.min(...xs), maxX = Math.max(...xs);
  const minY = Math.min(...ys), maxY = Math.max(...ys);
  const span = Math.max(maxX - minX, maxY - minY) || 1;
  const scale = (SIZE - 2 * PAD) / span;
  // centre the drawing in the square
  const offX = PAD + ((SIZE - 2 * PAD) - (maxX - minX) * scale) / 2;
  const offY = PAD + ((SIZE - 2 * PAD) - (maxY - minY) * scale) / 2;

  // y is flipped: FOLD counts up, SVG counts down. Same convention as the
  // project renderer (layout.ts: "world -> px, y flipped").
  const px = (v: [number, number]) => [
    round(offX + (v[0] - minX) * scale),
    round(offY + (maxY - v[1]) * scale),
  ];

  const groups = new Map<string, string[]>();
  fold.edges_vertices.forEach(([a, b], i) => {
    const kind = assign[i] ?? "U";
    if (kind === "B" && dropBoundary) return;
    if (kind === "F" && marksOnly) return;
    const [x1, y1] = px(verts[a]);
    const [x2, y2] = px(verts[b]);
    const key = plain ? (kind === "B" ? "B" : "C") : kind;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push(`M${x1} ${y1}L${x2} ${y2}`);
  });

  const keys = plain ? ["B", "C"] : ORDER;
  const paths = keys
    .filter((k) => groups.has(k))
    .map((k) => {
      const s = plain ? (k === "B" ? { w: 4 } : { w: 4 }) : STYLE[k] ?? STYLE.U;
      const dash = s.dash ? ` stroke-dasharray="${s.dash}"` : "";
      const cap = s.dash ? ` stroke-linecap="butt"` : "";
      return `  <path d="${groups.get(k)!.join("")}" stroke-width="${s.w}"${dash}${cap}/>`;
    });

  const svg = [
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIZE} ${SIZE}" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">`,
    ...paths,
    `</svg>`,
  ].join("\n");

  require("fs").writeFileSync(out, svg + "\n");
  const bytes = Buffer.byteLength(svg);
  console.log(`${out}  ${paths.length} paths, ${bytes} bytes, ${fold.edges_vertices.length} edges`);
}

function round(n: number): number {
  return Math.round(n * 100) / 100;
}

main();
