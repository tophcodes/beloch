#!/usr/bin/env bun
// Render a Beloch FOLD file to a labelled SVG/PNG diagram.
// Rabbit Ear validates that the FOLD loads (the ADR-0009 consumer); the diagram
// itself is drawn here for full control over strokes, padding, and labels.
// Usage:
//   bun tools/fold2svg.mjs input.fold [out.svg|out.png] [--title "..."]
//   beloch fold f.bel | bun tools/fold2svg.mjs - out.png --title f.bel
import ear from "rabbit-ear";

const args = process.argv.slice(2);
const titleIdx = args.indexOf("--title");
const title = titleIdx >= 0 ? args[titleIdx + 1] : "";
const positional = args.filter((a, i) => a !== "--title" && args[i - 1] !== "--title");
const [inPath, outPath] = positional;

const raw = !inPath || inPath === "-" ? await Bun.stdin.text() : await Bun.file(inPath).text();
const fold = JSON.parse(raw);
ear.graph(fold); // throws if the FOLD is not loadable — keep this as a check

const V = fold.vertices_coords;
const E = fold.edges_vertices || [];
const F = fold.faces_vertices || [];
const A = fold.edges_assignment || [];
const prov = fold["beloch:edges"] || [];

// layout: unit-ish coords -> a padded px canvas, y flipped (math up -> svg down)
const PAD = 56, SZ = 460, W = SZ + 2 * PAD, H = SZ + 2 * PAD;
const xs = V.map((p) => p[0]), ys = V.map((p) => p[1]);
const minX = Math.min(...xs), maxX = Math.max(...xs);
const minY = Math.min(...ys), maxY = Math.max(...ys);
const span = Math.max(maxX - minX, maxY - minY) || 1;
const tx = (x) => PAD + ((x - minX) / span) * SZ;
const ty = (y) => PAD + (1 - (y - minY) / span) * SZ;

const AX = {
  axiom1: { c: "#2563eb", n: "axiom 1 · through" },
  axiom2: { c: "#16a34a", n: "axiom 2 · fold to" },
  axiom3: { c: "#db2777", n: "axiom 3 · perp" },
  axiom5: { c: "#9333ea", n: "axiom 5 · bisect" },
};
const CREASE = "#f59e0b";
const eColor = (i) => {
  if (A[i] === "B") return "#1f2937";
  const ax = prov[i] && prov[i].axiom;
  return (AX[ax] && AX[ax].c) || CREASE;
};

const near = (p, x, y) => Math.abs(p[0] - x) < 1e-6 && Math.abs(p[1] - y) < 1e-6;
const CORNER = [[0, 0, "a"], [1, 0, "b"], [1, 1, "c"], [0, 1, "d"]];
const cornerLabel = (p) => (CORNER.find(([x, y]) => near(p, x, y)) || [])[2];

const out = [];
out.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" font-family="ui-sans-serif, system-ui, sans-serif">`);
out.push(`<rect width="${W}" height="${H}" fill="white"/>`);
// faces (very light fill so regions read)
for (const f of F) {
  const pts = f.map((i) => `${tx(V[i][0])},${ty(V[i][1])}`).join(" ");
  out.push(`<polygon points="${pts}" fill="#f8fafc" stroke="none"/>`);
}
// edges
E.forEach((e, i) => {
  const [a, b] = e;
  const boundary = A[i] === "B";
  out.push(`<line x1="${tx(V[a][0])}" y1="${ty(V[a][1])}" x2="${tx(V[b][0])}" y2="${ty(V[b][1])}" stroke="${eColor(i)}" stroke-width="${boundary ? 2.5 : 2}" stroke-linecap="round"/>`);
});
// vertices + corner labels
V.forEach((p) => {
  out.push(`<circle cx="${tx(p[0])}" cy="${ty(p[1])}" r="3" fill="#0f172a"/>`);
  const lab = cornerLabel(p);
  if (lab) {
    const ox = p[0] < 0.5 ? -16 : 10, oy = p[1] < 0.5 ? 18 : -8;
    out.push(`<text x="${tx(p[0]) + ox}" y="${ty(p[1]) + oy}" font-size="17" font-weight="600" fill="#0f172a">.${lab}</text>`);
  }
});
// crease-name labels: one per NAMED crease, on the line ~18% in from one end,
// with a white halo so it reads over creases and never collides with corners.
const B_EPS = 1e-6;
const onB = (p) =>
  Math.abs(p[0] - minX) < B_EPS || Math.abs(p[0] - maxX) < B_EPS ||
  Math.abs(p[1] - minY) < B_EPS || Math.abs(p[1] - maxY) < B_EPS;
const creases = {};
E.forEach((e, i) => {
  const nm = prov[i] && prov[i].name;
  if (!nm) return;
  if (!creases[nm]) creases[nm] = { vs: new Set(), col: eColor(i) };
  creases[nm].vs.add(e[0]);
  creases[nm].vs.add(e[1]);
});
for (const [nm, { vs, col }] of Object.entries(creases)) {
  const list = [...vs];
  // the crease's two ends. Normally its two boundary exits; if fewer than two
  // verts lie on the boundary (interior fallback), use the two farthest apart.
  let ends = list.filter((j) => onB(V[j]));
  if (ends.length < 2) {
    let best = [list[0], list[0]], bd = -1;
    for (const a of list) for (const b of list) {
      const d = (V[a][0] - V[b][0]) ** 2 + (V[a][1] - V[b][1]) ** 2;
      if (d > bd) { bd = d; best = [a, b]; }
    }
    ends = best;
  }
  const A = V[ends[0]], C = V[ends[1]], t = 0.18; // 18% in from one end
  const px = tx(A[0] + (C[0] - A[0]) * t), py = ty(A[1] + (C[1] - A[1]) * t);
  out.push(`<text x="${px}" y="${py}" font-size="13" font-weight="600" fill="${col}" stroke="white" stroke-width="3" paint-order="stroke" text-anchor="middle" dominant-baseline="middle">--${nm}</text>`);
}
// title
if (title) out.push(`<text x="${PAD}" y="28" font-size="16" font-weight="700" fill="#0f172a">${title}</text>`);
// legend (axioms present in this diagram)
const present = [...new Set(prov.filter(Boolean).map((p) => p.axiom))].filter((a) => AX[a]);
present.forEach((ax, k) => {
  const lx = PAD + k * 150;
  out.push(`<line x1="${lx}" y1="${H - 22}" x2="${lx + 22}" y2="${H - 22}" stroke="${AX[ax].c}" stroke-width="3" stroke-linecap="round"/>`);
  out.push(`<text x="${lx + 28}" y="${H - 17}" font-size="13" fill="#334155">${AX[ax].n}</text>`);
});
out.push(`</svg>`);
let svg = out.join("\n");

if (outPath && outPath.endsWith(".png")) {
  const { Resvg } = await import("@resvg/resvg-js");
  const png = new Resvg(svg, { background: "white", fitTo: { mode: "width", value: W } }).render().asPng();
  await Bun.write(outPath, png);
} else if (outPath) await Bun.write(outPath, svg);
else process.stdout.write(svg);
