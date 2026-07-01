#!/usr/bin/env bun
// Render a Beloch FOLD file to a labelled SVG/PNG diagram.
// Rabbit Ear validates that the FOLD loads (the ADR-0009 consumer); the diagram
// itself is drawn here for full control over strokes, padding, and labels.
// Usage:
//   bun tools/fold2svg.mjs input.fold [out.svg|out.png] [--title "..."]
//   bun tools/fold2svg.mjs f.fold --view top|bottom [--hidden dashed|hide]
//   beloch fold f.bel | bun tools/fold2svg.mjs - out.png --title f.bel
import ear from "rabbit-ear";

// ---- pure helpers (exported for tests) ------------------------------------

// Merge the foldedForm frame (file_frames[0]) over its parent: the folded frame
// overrides vertices_coords + faceOrders and inherits topology from the parent.
export function foldedFrame(fold) {
  const ff = (fold.file_frames || [])[0];
  return ff ? { ...fold, ...ff } : fold;
}

// Topologically sort faces into a bottom->top order consistent with faceOrders.
// [f,g,s]: s=+1 => f above g (edge g->f), s=-1 => f below g (edge f->g).
export function linearExtension(faceOrders, nFaces) {
  const adj = Array.from({ length: nFaces }, () => []);
  const indeg = new Array(nFaces).fill(0);
  const addEdge = (lo, hi) => { adj[lo].push(hi); indeg[hi]++; }; // lo below hi
  for (const [f, g, s] of faceOrders || []) {
    if (s === 1) addEdge(g, f);
    else if (s === -1) addEdge(f, g);
  }
  const queue = [];
  for (let i = 0; i < nFaces; i++) if (indeg[i] === 0) queue.push(i);
  queue.sort((a, b) => a - b); // deterministic tie-break
  const order = [];
  while (queue.length) {
    const n = queue.shift();
    order.push(n);
    for (const m of adj[n]) if (--indeg[m] === 0) {
      // insert keeping ascending index among ready nodes (stable, deterministic)
      let k = queue.length;
      while (k > 0 && queue[k - 1] > m) k--;
      queue.splice(k, 0, m);
    }
  }
  return order;
}

// "a-b" key (sorted) -> edge index, for mapping a face outline segment to a
// FOLD edge (to recover its colour/assignment).
export function faceEdgeIndex(edgesVertices) {
  const m = new Map();
  (edgesVertices || []).forEach(([a, b], i) => {
    m.set(a < b ? `${a}-${b}` : `${b}-${a}`, i);
  });
  return m;
}

// Shoelace signed area; >0 = CCW (front side up in folded coords).
export function signedArea(poly) {
  let s = 0;
  for (let i = 0; i < poly.length; i++) {
    const [x1, y1] = poly[i], [x2, y2] = poly[(i + 1) % poly.length];
    s += x1 * y2 - x2 * y1;
  }
  return s / 2;
}

export function sideUp(poly) {
  return signedArea(poly) >= 0 ? "front" : "back";
}

// Ray-casting point-in-polygon (boundary counts as inside is not required here).
export function pointInPolygon(pt, poly) {
  const [x, y] = pt;
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    const hit = (yi > y) !== (yj > y) &&
      x < ((xj - xi) * (y - yi)) / (yj - yi) + xi;
    if (hit) inside = !inside;
  }
  return inside;
}

// Is `mid` covered by a face strictly above `incidentMaxPos` in the stack order?
export function edgeCovered(mid, incidentMaxPos, order, F, V) {
  for (let pos = incidentMaxPos + 1; pos < order.length; pos++) {
    const fi = order[pos];
    if (pointInPolygon(mid, F[fi].map((i) => V[i]))) return true;
  }
  return false;
}

// ---- CLI ------------------------------------------------------------------

if (import.meta.main) {
  const args = process.argv.slice(2);
  const flagVal = (name) => {
    const i = args.indexOf(name);
    return i >= 0 ? args[i + 1] : undefined;
  };
  const title = flagVal("--title") || "";
  const viewFlag = args.includes("--folded") ? "top" : flagVal("--view"); // top|bottom
  const hidden = flagVal("--hidden") || "hide"; // dashed | hide
  const FLAGS = new Set(["--title", "--view", "--hidden"]);
  const positional = args.filter(
    (a, i) => !a.startsWith("--") && !FLAGS.has(args[i - 1])
  );
  const [inPath, outPath] = positional;

  const raw =
    !inPath || inPath === "-" ? await Bun.stdin.text() : await Bun.file(inPath).text();
  const fold = JSON.parse(raw);
  ear.graph(fold); // throws if the FOLD is not loadable — keep this as a check

  const frame = viewFlag ? foldedFrame(fold) : fold;
  const V = frame.vertices_coords;
  const E = frame.edges_vertices || [];
  const F = frame.faces_vertices || [];
  const A = frame.edges_assignment || [];
  const prov = frame["beloch:edges"] || [];

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
    axiom2: { c: "#16a34a", n: "axiom 2 · map onto" },
    axiom3: { c: "#db2777", n: "axiom 3 · perp" },
    axiom4: { c: "#ea580c", n: "axiom 4 · project" },
    axiom5: { c: "#9333ea", n: "axiom 5 · map onto" },
    axiom6: { c: "#0d9488", n: "axiom 6 · map through" },
    axiom7: { c: "#7c3aed", n: "axiom 7 · map onto + onto" },
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

  if (viewFlag) {
    // ---- occlusion view: paint faces bottom->top, opaque -----------------
    const FRONT = "#fafaf7", BACK = "#dbe4ee"; // paper front / back tint
    const bottom = viewFlag === "bottom";
    // bottom view: look from below => reverse the stack and mirror x
    const mx = (x) => (bottom ? W - tx(x) : tx(x));
    const order = linearExtension(frame.faceOrders || [], F.length);
    const paint = bottom ? [...order].reverse() : order;
    const edgeIx = faceEdgeIndex(E);
    for (const fi of paint) {
      const face = F[fi];
      const poly = face.map((i) => V[i]);
      const fill = sideUp(poly) === "front" ? FRONT : BACK;
      const pts = face.map((i) => `${mx(V[i][0])},${ty(V[i][1])}`).join(" ");
      out.push(`<polygon points="${pts}" fill="${fill}" stroke="none"/>`);
      for (let k = 0; k < face.length; k++) {
        const a = face[k], b = face[(k + 1) % face.length];
        const ei = edgeIx.get(a < b ? `${a}-${b}` : `${b}-${a}`);
        const col = ei === undefined ? CREASE : eColor(ei);
        const wgt = ei !== undefined && A[ei] === "B" ? 2.5 : 2;
        out.push(`<line x1="${mx(V[a][0])}" y1="${ty(V[a][1])}" x2="${mx(V[b][0])}" y2="${ty(V[b][1])}" stroke="${col}" stroke-width="${wgt}" stroke-linecap="round"/>`);
      }
    }
    // x-ray: redraw occluded creases dashed over the paper
    if (hidden === "dashed") {
      const pos = new Map(order.map((f, i) => [f, i]));
      // incident faces per edge: faces whose outline contains the edge
      const incident = E.map(() => []);
      F.forEach((face, fi) => {
        for (let k = 0; k < face.length; k++) {
          const a = face[k], b = face[(k + 1) % face.length];
          const ei = edgeIx.get(a < b ? `${a}-${b}` : `${b}-${a}`);
          if (ei !== undefined) incident[ei].push(fi);
        }
      });
      E.forEach((e, i) => {
        if (A[i] === "B") return; // boundary edges are always on the silhouette
        const faces = incident[i];
        if (!faces.length) return;
        const maxPos = Math.max(...faces.map((fi) => pos.get(fi)));
        const [a, b] = e;
        const mid = [(V[a][0] + V[b][0]) / 2, (V[a][1] + V[b][1]) / 2];
        if (!edgeCovered(mid, maxPos, order, F, V)) return; // visible already
        out.push(`<line x1="${mx(V[a][0])}" y1="${ty(V[a][1])}" x2="${mx(V[b][0])}" y2="${ty(V[b][1])}" stroke="#94a3b8" stroke-width="1.2" stroke-dasharray="4 3" stroke-linecap="round"/>`);
      });
    }
  } else {
    // ---- crease-pattern (frame 0): unchanged -----------------------------
    for (const f of F) {
      const pts = f.map((i) => `${tx(V[i][0])},${ty(V[i][1])}`).join(" ");
      out.push(`<polygon points="${pts}" fill="#f8fafc" stroke="none"/>`);
    }
    E.forEach((e, i) => {
      const [a, b] = e;
      const boundary = A[i] === "B";
      out.push(`<line x1="${tx(V[a][0])}" y1="${ty(V[a][1])}" x2="${tx(V[b][0])}" y2="${ty(V[b][1])}" stroke="${eColor(i)}" stroke-width="${boundary ? 2.5 : 2}" stroke-linecap="round"/>`);
    });
    V.forEach((p) => {
      out.push(`<circle cx="${tx(p[0])}" cy="${ty(p[1])}" r="3" fill="#0f172a"/>`);
      const lab = cornerLabel(p);
      if (lab) {
        const ox = p[0] < 0.5 ? -16 : 10, oy = p[1] < 0.5 ? 18 : -8;
        out.push(`<text x="${tx(p[0]) + ox}" y="${ty(p[1]) + oy}" font-size="17" font-weight="600" fill="#0f172a">.${lab}</text>`);
      }
    });
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
      let ends = list.filter((j) => onB(V[j]));
      if (ends.length < 2) {
        let best = [list[0], list[0]], bd = -1;
        for (const a of list) for (const b of list) {
          const d = (V[a][0] - V[b][0]) ** 2 + (V[a][1] - V[b][1]) ** 2;
          if (d > bd) { bd = d; best = [a, b]; }
        }
        ends = best;
      }
      const P = V[ends[0]], C = V[ends[1]], t = 0.18;
      const px = tx(P[0] + (C[0] - P[0]) * t), py = ty(P[1] + (C[1] - P[1]) * t);
      out.push(`<text x="${px}" y="${py}" font-size="13" font-weight="600" fill="${col}" stroke="white" stroke-width="3" paint-order="stroke" text-anchor="middle" dominant-baseline="middle">--${nm}</text>`);
    }
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
}
