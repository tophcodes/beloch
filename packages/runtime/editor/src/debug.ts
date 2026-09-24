// What the program binds, and where in the source it says so.
//
// A reader debugging a program points at the line that binds `--mid` and wants
// `--mid` in the drawing. That needs the map from statements to the values they
// bind, which the document carries: every statement is logged with its span
// (ADR 0026), and a named point, a named line and a crease each record the
// statement that binds them.
//
// Free of the editor it serves, like the rest of this package: a target is a
// span and the entity it names, and the host turns that into whatever it draws
// a box with.
import type { FoldScene } from "@beloch/scene";
import type { EntityRef } from "@beloch/runtime";
import { parseSpan, type SpanPos } from "./spans";

export interface DebugTarget {
  entity: EntityRef;
  // The statement that binds the value, or null for one the sheet brings: the
  // paper's corners and its four edges are bound by no statement, so the
  // source has nothing to point at and a host offers them some other way.
  span: SpanPos | null;
  // The name that statement binds, where it binds one: `.o`, `--mid`. A host
  // that can read the text finds the word inside the span and boxes that,
  // which is the target a reader aims at; the statement's own span is the
  // target only where nothing is named. A statement that does not spell the
  // name is no target at all, which is what keeps a box off the `apply` a
  // name was exported from.
  spelling: string | null;
}

const spanOfStatement = (scene: FoldScene, index: number | null): SpanPos | null => {
  if (index === null) return null;
  const span = scene.statements[index]?.span ?? null;
  return span === null ? null : parseSpan(span);
};

// The crease a write scored, by the join the document offers: every crease edge
// records the statement that scored it. A mark that never graduated into a
// crease edge carries its own id on the statement instead.
function creaseOfWrite(scene: FoldScene, index: number): string | null {
  for (const prov of scene.cp.edgesProvenance) {
    if (prov && prov.statement === index && prov.creaseId !== null) return String(prov.creaseId);
  }
  const mark = scene.statements[index]?.mark ?? null;
  return mark === null ? null : String(mark.creaseId);
}

// Every value the program binds, in source order. A name the drawing has
// nothing to show for is left out: a point that is no vertex of the graph has
// no dot, and lighting it would promise what the picture cannot keep.
export function debugTargets(scene: FoldScene): DebugTarget[] {
  const targets: DebugTarget[] = [];

  for (const point of scene.namedPoints) {
    const index = scene.cp.verticesNames.indexOf(point.name);
    if (index < 0) continue;
    // A point no statement bound came with the sheet, which its corners do.
    const statement = point.statement === null ? null : spanOfStatement(scene, point.statement);
    if (statement === null && point.statement !== null) continue;
    targets.push({
      entity: { kind: "vertex", index, name: point.name },
      span: statement,
      spelling: `.${point.name}`,
    });
  }

  // The paper's own edges. The program names them (`--ab`) and no statement
  // binds them, so they are offered beside the corners.
  for (const name of Object.keys(scene.inspect?.edges ?? {})) {
    targets.push({ entity: { kind: "edge", name }, span: null, spelling: `--${name}` });
  }

  // Every crease the paper carries, under the name the write that made it
  // bound, or under its statement where it bound none. The creases are read
  // here rather than from the named lines, because a line whose crease a later
  // fold bends is left out of that map and its name would go with it.
  const covered = new Set<string>();
  const creaseNames = new Set<string>();
  for (const [id, crease] of Object.entries(scene.inspect?.creases ?? {})) {
    const span = crease.span === null ? null : parseSpan(crease.span);
    if (span === null) continue;
    covered.add(id);
    if (crease.name !== null) creaseNames.add(crease.name);
    targets.push({
      entity: { kind: "crease", creaseId: id },
      span,
      spelling: crease.name === null ? null : `--${crease.name}`,
    });
  }

  // A line the program named and the paper never carried: a construction, held
  // by its name alone.
  for (const line of scene.namedLines) {
    if (creaseNames.has(line.name)) continue;
    const span = spanOfStatement(scene, line.statement);
    if (span === null) continue;
    targets.push({
      entity: { kind: "construction", name: line.name },
      span,
      spelling: `--${line.name}`,
    });
  }

  // A mark that never graduated into a crease edge: the inspect inventory has
  // no entry for it, so its write is what says where it was scored.
  for (const write of scene.writes) {
    const span = spanOfStatement(scene, write.index);
    if (span === null) continue;
    const creaseId = creaseOfWrite(scene, write.index);
    if (creaseId === null || covered.has(creaseId)) continue;
    covered.add(creaseId);
    targets.push({ entity: { kind: "crease", creaseId }, span, spelling: null });
  }

  // Source order, with what the sheet brings ahead of the program that folds
  // it.
  return targets.sort((a, b) => {
    if (a.span === null || b.span === null) {
      return (a.span === null ? 0 : 1) - (b.span === null ? 0 : 1) ||
        (a.spelling ?? "").localeCompare(b.spelling ?? "");
    }
    return a.span.fromLine - b.span.fromLine || a.span.fromCol - b.span.fromCol;
  });
}
