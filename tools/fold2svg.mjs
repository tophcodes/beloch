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

// Merge a foldedForm frame over its parent (the top-level crease pattern):
// the folded frame overrides vertices_coords/edges/faces/faceOrders. Selects
// the file_frames entry whose "beloch:step" matches `step`; falls back to the
// LAST frame (the final folded state) if `step` is omitted or matches none.
export function foldedFrame(fold, step) {
  const frames = fold.file_frames || [];
  const ff =
    (step !== undefined && frames.find((f) => f["beloch:step"] === step)) ||
    frames[frames.length - 1];
  return ff ? { ...fold, ...ff } : fold;
}

// Topologically sort faces into a bottom->top order consistent with faceOrders.
// [f,g,s]: s=+1 => f above g (edge g->f), s=-1 => f below g (edge f->g).
export function linearExtension(faceOrders, nFaces, faceUp) {
  const adj = Array.from({ length: nFaces }, () => []);
  const indeg = new Array(nFaces).fill(0);
  const addEdge = (lo, hi) => { adj[lo].push(hi); indeg[hi]++; }; // lo below hi
  // FOLD's faceOrders sign is relative to g's NORMAL, not global +z:
  // [f,g,+1] means f lies on the side g's normal points to. So f is globally
  // BELOW g iff (s < 0) === gUp, where gUp = g faces up (front side up, i.e.
  // det_sign > 0 ⇔ folded winding CCW). faceUp[g] carries that; when omitted
  // (all faces up) the sign reads as plain global order.
  for (const [f, g, s] of faceOrders || []) {
    if (s === 0) continue;
    const gUp = faceUp ? faceUp[g] : true;
    if ((s < 0) === gUp) addEdge(f, g); // f below g
    else addEdge(g, f);                 // g below f
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

// Pull a paper-frame line a·x+b·y=c back into a face's table frame, given the
// face's paper→table isometry row [m00,m01,m10,m11,tx,ty]. M is orthogonal, so
// the table-frame line is [A,B,C] with A=a·m00+b·m01, B=a·m10+b·m11,
// C=c+A·tx+B·ty. Clipping this against the face's own table polygon needs no
// per-point mapping and never touches the crease-pattern vertex indices.
export const lineToFace = ([m00, m01, m10, m11, tx, ty], a, b, c) => {
  const A = a * m00 + b * m01;
  const B = a * m10 + b * m11;
  return [A, B, c + A * tx + B * ty];
};

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

// Parameter sub-intervals [t0,t1] of segment a→b that lie inside `poly`.
// Breakpoints are the segment's crossings of the polygon's edges; each gap is
// classified inside/outside by its midpoint. Works for convex or non-convex,
// CW or CCW polygons. Returns merged intervals in [0,1].
export function segInsideIntervals(a, b, poly) {
  const dx = b[0] - a[0], dy = b[1] - a[1];
  const ts = [0, 1];
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const c = poly[j], d = poly[i];
    const ex = d[0] - c[0], ey = d[1] - c[1];
    const denom = dx * ey - dy * ex;
    if (Math.abs(denom) < 1e-12) continue; // parallel/collinear
    const wx = c[0] - a[0], wy = c[1] - a[1];
    const t = (wx * ey - wy * ex) / denom; // along a→b
    const u = (wx * dy - wy * dx) / denom; // along the polygon edge
    if (t > 1e-9 && t < 1 - 1e-9 && u >= -1e-9 && u <= 1 + 1e-9) ts.push(t);
  }
  ts.sort((p, q) => p - q);
  const out = [];
  for (let k = 0; k < ts.length - 1; k++) {
    const t0 = ts[k], t1 = ts[k + 1];
    if (t1 - t0 < 1e-9) continue;
    const tm = (t0 + t1) / 2;
    if (pointInPolygon([a[0] + dx * tm, a[1] + dy * tm], poly)) {
      const last = out[out.length - 1];
      if (last && t0 - last[1] < 1e-9) last[1] = t1; // merge adjacent
      else out.push([t0, t1]);
    }
  }
  return out;
}

// Sub-intervals of segment a→b hidden by a face strictly above (or, for the
// bottom view, below) `refPos` in the stack order — the union over all such
// covering faces.
export function coveredIntervals(a, b, order, refPos, F, V, below = false) {
  const spans = [];
  const from = below ? refPos - 1 : refPos + 1;
  const step = below ? -1 : 1;
  for (let pos = from; pos >= 0 && pos < order.length; pos += step) {
    for (const iv of segInsideIntervals(a, b, F[order[pos]].map((i) => V[i]))) spans.push(iv);
  }
  if (!spans.length) return spans;
  spans.sort((p, q) => p[0] - q[0]);
  const merged = [spans[0].slice()];
  for (let k = 1; k < spans.length; k++) {
    const last = merged[merged.length - 1];
    if (spans[k][0] <= last[1] + 1e-9) last[1] = Math.max(last[1], spans[k][1]);
    else merged.push(spans[k].slice());
  }
  return merged;
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
  const constructionsFlag = flagVal("--constructions"); // undefined = show all
  const stepFlag = flagVal("--step"); // which file_frames entry to render (folded view only)
  const FLAGS = new Set(["--title", "--view", "--hidden", "--constructions", "--step"]);
  const positional = args.filter(
    (a, i) => !a.startsWith("--") && !FLAGS.has(args[i - 1])
  );
  const [inPath, outPath] = positional;

  const raw =
    !inPath || inPath === "-" ? await Bun.stdin.text() : await Bun.file(inPath).text();
  const fold = JSON.parse(raw);
  ear.graph(fold); // throws if the FOLD is not loadable — keep this as a check

  const frame = viewFlag ? foldedFrame(fold, stepFlag) : fold;
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
  out.push(`<defs><filter id="layerShadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="1" stdDeviation="1.1" flood-color="#0f172a" flood-opacity="0.18"/></filter></defs>`);

  if (viewFlag) {
    // ---- occlusion view: paint faces bottom->top, opaque -----------------
    const FRONT = "#fafaf7", BACK = "#dbe4ee"; // paper front / back tint
    const bottom = viewFlag === "bottom";
    // bottom view: look from below => reverse the stack and mirror x
    const mx = (x) => (bottom ? W - tx(x) : tx(x));
    // decode the true global stack: faceOrders sign is keyed to each g's normal
    const faceUp = F.map((f) => sideUp(f.map((i) => V[i])) === "front");
    const order = linearExtension(frame.faceOrders || [], F.length, faceUp);
    const paint = bottom ? [...order].reverse() : order;
    const edgeIx = faceEdgeIndex(E);
    for (const fi of paint) {
      const face = F[fi];
      const poly = face.map((i) => V[i]);
      // the bottom view looks at each face's underside, so its side flips
      const showFront = (sideUp(poly) === "front") !== bottom;
      const fill = showFront ? FRONT : BACK;
      const pts = face.map((i) => `${mx(V[i][0])},${ty(V[i][1])}`).join(" ");
      out.push(`<polygon points="${pts}" fill="${fill}" stroke="none" filter="url(#layerShadow)"/>`);
      for (let k = 0; k < face.length; k++) {
        const a = face[k], b = face[(k + 1) % face.length];
        const ei = edgeIx.get(a < b ? `${a}-${b}` : `${b}-${a}`);
        const col = ei === undefined ? CREASE : eColor(ei);
        const assignment = ei === undefined ? "U" : A[ei];
        const step = (ei !== undefined && prov[ei] && prov[ei].step) || "";
        const wgt = ei !== undefined && A[ei] === "B" ? 2.5 : 2;
        out.push(`<line class="crease-${assignment}" data-step="${step}" x1="${mx(V[a][0])}" y1="${ty(V[a][1])}" x2="${mx(V[b][0])}" y2="${ty(V[b][1])}" stroke="${col}" stroke-width="${wgt}" stroke-linecap="round"/>`);
      }
    }
    // x-ray: redraw occluded creases dashed over the paper. View-aware: the top
    // view hides a crease when a face ABOVE its incident faces covers it; the
    // bottom view (seen from beneath) hides one when a face BELOW does.
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
        // Boundary (paper-edge) edges are x-rayed too: a tucked-under flap's
        // outer edge is a "B" edge that IS occluded. Only the covered SUB-
        // segments are dashed — the visible part stays solid (painter's pass).
        const faces = incident[i];
        if (!faces.length) return;
        const refPos = bottom
          ? Math.min(...faces.map((fi) => pos.get(fi)))
          : Math.max(...faces.map((fi) => pos.get(fi)));
        const a0 = V[e[0]], b0 = V[e[1]];
        const covered = coveredIntervals(a0, b0, order, refPos, F, V, bottom);
        if (!covered.length) return; // fully visible
        // paper edge reads darker + thicker + longer dashes than a crease
        const isB = A[i] === "B";
        const stroke = isB ? "#475569" : "#94a3b8";
        const wgt = isB ? 2 : 1.2;
        const dash = isB ? "6 3" : "4 3";
        const step = (prov[i] && prov[i].step) || "";
        for (const [t0, t1] of covered) {
          const p0 = [a0[0] + (b0[0] - a0[0]) * t0, a0[1] + (b0[1] - a0[1]) * t0];
          const p1 = [a0[0] + (b0[0] - a0[0]) * t1, a0[1] + (b0[1] - a0[1]) * t1];
          out.push(`<line class="crease-${A[i]}" data-step="${step}" x1="${mx(p0[0])}" y1="${ty(p0[1])}" x2="${mx(p1[0])}" y2="${ty(p1[1])}" stroke="${stroke}" stroke-width="${wgt}" stroke-dasharray="${dash}" stroke-linecap="round"/>`);
        }
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
      const step = (prov[i] && prov[i].step) || "";
      out.push(`<line class="crease-${A[i]}" data-step="${step}" x1="${tx(V[a][0])}" y1="${ty(V[a][1])}" x2="${tx(V[b][0])}" y2="${ty(V[b][1])}" stroke="${eColor(i)}" stroke-width="${boundary ? 2.5 : 2}" stroke-linecap="round"/>`);
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

  // ---- construction overlay -----------------------------------------------
  // Every AUXILIARY named construction gets a data-construction hook so a
  // webview can toggle visibility by CSS/DOM; --constructions (if given)
  // narrows which names are rendered at all, but omitting it renders all
  // auxiliary ones. "Auxiliary" excludes constructions already drawn
  // elsewhere in the diagram: named lines that are creases (drawn with a
  // solid stroke + --name label) and named points that sit on a paper corner
  // (drawn as a dotted .a/.b/.c/.d corner) — overlaying those would double-
  // draw the same geometry with a second label.
  {
    const namedPoints = fold["beloch:named_points"] || {};
    const namedLines = fold["beloch:named_lines"] || {};
    const creaseLineNames = new Set(
      (fold["beloch:edges"] || []).filter(Boolean).map((e) => e.name).filter(Boolean)
    );
    const isCornerPoint = (p) => CORNER.some(([x, y]) => near(p, x, y));
    const selection =
      constructionsFlag !== undefined
        ? constructionsFlag.split(",").map((s) => s.trim()).filter(Boolean)
        : [
            ...Object.keys(namedLines).map((n) => `--${n}`),
            ...Object.keys(namedPoints).map((n) => `.${n}`),
          ];
    const CON_PT = "#6366f1", CON_LN = "#6366f1";
    const rootV = fold.vertices_coords || [];
    const FM = frame["beloch:faces_matrix"] || [];
    const pxs = rootV.map(p => p[0]), pys = rootV.map(p => p[1]);
    const [pMinX, pMaxX] = [Math.min(...pxs), Math.max(...pxs)];
    const [pMinY, pMaxY] = [Math.min(...pys), Math.max(...pys)];

    // clip line ax+by=c to bounding box
    const clipLineBox = (a, b, c, x0, x1, y0, y1) => {
      const eps = 1e-9, pts = [];
      const tryX = (x) => { if (Math.abs(b) > eps) { const y = (c-a*x)/b; if (y >= y0-eps && y <= y1+eps) pts.push([x,y]); } };
      const tryY = (y) => { if (Math.abs(a) > eps) { const x = (c-b*y)/a; if (x >= x0-eps && x <= x1+eps) pts.push([x,y]); } };
      tryX(x0); tryX(x1); tryY(y0); tryY(y1);
      const uniq = pts.filter((p,i) => !pts.slice(0,i).some(q => Math.abs(p[0]-q[0])<eps && Math.abs(p[1]-q[1])<eps));
      return uniq.length >= 2 ? [uniq[0], uniq[uniq.length-1]] : null;
    };
    // clip line ax+by=c to a convex polygon [[x,y],...]; returns [p1,p2] in paper space or null
    const clipLineToPoly = (a, b, c, poly) => {
      const eps = 1e-9, n = poly.length, pts = [];
      for (let i = 0; i < n; i++) {
        const [x1,y1] = poly[i], [x2,y2] = poly[(i+1)%n];
        const d = a*(x2-x1) + b*(y2-y1);
        if (Math.abs(d) < eps) continue;
        const t = (c - a*x1 - b*y1) / d;
        if (t >= -eps && t <= 1+eps) pts.push([x1+t*(x2-x1), y1+t*(y2-y1)]);
      }
      const uniq = pts.filter((p,i) => !pts.slice(0,i).some(q => Math.hypot(p[0]-q[0],p[1]-q[1]) < 1e-8));
      return uniq.length >= 2 ? [uniq[0], uniq[uniq.length-1]] : null;
    };
    for (const sel of selection) {
      if (sel.startsWith("--")) {
        const name = sel.slice(2);
        const l = namedLines[name];
        if (!l) continue;
        if (creaseLineNames.has(name)) continue; // crease-duplicate: already drawn as a crease
        const [la, lb, lc] = l;
        const g = [];
        if (viewFlag) {
          // folded view: clip to each face's paper polygon, transform to table space
          const drawn = [];
          for (let fi = 0; fi < F.length; fi++) {
            const M = FM[fi];
            if (!M) continue;
            const tabPoly = F[fi].map(vi => V[vi]);
            const [ta, tb, tc] = lineToFace(M, la, lb, lc);
            const seg = clipLineToPoly(ta, tb, tc, tabPoly);
            if (!seg) continue;
            const [t1, t2] = seg;
            g.push(`<line x1="${tx(t1[0])}" y1="${ty(t1[1])}" x2="${tx(t2[0])}" y2="${ty(t2[1])}" stroke="${CON_LN}" stroke-width="1.5" stroke-dasharray="6 3" opacity="0.8"/>`);
            drawn.push([t1, t2]);
          }
          if (drawn.length > 0) {
            const [[x1,y1],[x2,y2]] = drawn[0];
            g.push(`<text x="${tx((x1+x2)/2)}" y="${ty((y1+y2)/2) - 6}" font-size="12" font-weight="600" fill="${CON_LN}" stroke="white" stroke-width="2.5" paint-order="stroke" text-anchor="middle">--${name}</text>`);
          }
        } else {
          const seg = clipLineBox(la, lb, lc, pMinX, pMaxX, pMinY, pMaxY);
          if (!seg) continue;
          const [[x1,y1],[x2,y2]] = seg;
          g.push(`<line x1="${tx(x1)}" y1="${ty(y1)}" x2="${tx(x2)}" y2="${ty(y2)}" stroke="${CON_LN}" stroke-width="1.5" stroke-dasharray="6 3" opacity="0.8"/>`);
          g.push(`<text x="${tx((x1+x2)/2)}" y="${ty((y1+y2)/2) - 6}" font-size="12" font-weight="600" fill="${CON_LN}" stroke="white" stroke-width="2.5" paint-order="stroke" text-anchor="middle">--${name}</text>`);
        }
        if (g.length) out.push(`<g class="construction" data-construction="${name}">${g.join("")}</g>`);
      } else if (sel.startsWith(".")) {
        const name = sel.slice(1);
        const entry = namedPoints[name];
        if (!entry) continue;
        const paper = Array.isArray(entry) ? entry : entry.paper;
        if (paper && isCornerPoint(paper)) continue; // corner-duplicate: already dotted+labelled
        const coords = Array.isArray(entry) ? entry : (viewFlag ? entry.table : entry.paper);
        if (!coords) continue;
        const [px, py] = coords;
        const ox = px < (minX + maxX) / 2 ? -14 : 10;
        const oy = py < (minY + maxY) / 2 ? 16 : -7;
        out.push(
          `<g class="construction" data-construction="${name}">` +
          `<circle cx="${tx(px)}" cy="${ty(py)}" r="4.5" fill="${CON_PT}" opacity="0.85"/>` +
          `<text x="${tx(px) + ox}" y="${ty(py) + oy}" font-size="13" font-weight="600" fill="${CON_PT}" stroke="white" stroke-width="2.5" paint-order="stroke">.${name}</text>` +
          `</g>`
        );
      }
    }
  }

  // title
  if (title) {
    out.push(`<rect x="${PAD - 10}" y="10" width="${title.length * 9 + 20}" height="26" rx="6" fill="#f1f5f9"/>`);
    out.push(`<text x="${PAD}" y="28" font-size="16" font-weight="700" fill="#0f172a">${title}</text>`);
  }
  // legend (axioms present in this diagram) with a soft backing panel
  const present = [...new Set(prov.filter(Boolean).map((p) => p.axiom))].filter((a) => AX[a]);
  if (present.length) {
    out.push(`<rect class="legend-panel" x="${PAD - 12}" y="${H - 38}" width="${present.length * 150 + 4}" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>`);
    present.forEach((ax, k) => {
      const lx = PAD + k * 150;
      out.push(`<line x1="${lx}" y1="${H - 25}" x2="${lx + 22}" y2="${H - 25}" stroke="${AX[ax].c}" stroke-width="3" stroke-linecap="round"/>`);
      out.push(`<text x="${lx + 28}" y="${H - 20}" font-size="13" fill="#334155">${AX[ax].n}</text>`);
    });
  }
  out.push(`</svg>`);
  let svg = out.join("\n");

  if (outPath && outPath.endsWith(".png")) {
    const { Resvg } = await import("@resvg/resvg-js");
    const png = new Resvg(svg, { background: "white", fitTo: { mode: "width", value: W } }).render().asPng();
    await Bun.write(outPath, png);
  } else if (outPath) await Bun.write(outPath, svg);
  else process.stdout.write(svg);
}
