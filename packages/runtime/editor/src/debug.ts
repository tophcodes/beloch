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
  span: SpanPos;
  // What the text under `span` spells, where the span was derived from the head
  // of a statement rather than recorded by the emitter: `.o`, `--mid`. A
  // binding statement begins with the name it binds, so the head of its span
  // is that name; a host that can read the text checks the two agree before it
  // draws a box. That check is what keeps a box off a statement the
  // document dates the name to without the name standing there, which a name
  // exported from an `apply` does.
  spelling: string | null;
}

const spanOfStatement = (scene: FoldScene, index: number | null): SpanPos | null => {
  if (index === null) return null;
  const span = scene.statements[index]?.span ?? null;
  return span === null ? null : parseSpan(span);
};

// The name at the head of its binding statement, as a span of its own.
const headOf = (statement: SpanPos, spelling: string): SpanPos => ({
  fromLine: statement.fromLine,
  fromCol: statement.fromCol,
  toLine: statement.fromLine,
  toCol: statement.fromCol + spelling.length,
});

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
    const statement = spanOfStatement(scene, point.statement);
    if (statement === null) continue;
    const index = scene.cp.verticesNames.indexOf(point.name);
    if (index < 0) continue;
    const spelling = `.${point.name}`;
    targets.push({
      entity: { kind: "vertex", index, name: point.name },
      span: headOf(statement, spelling),
      spelling,
    });
  }

  // A named line is a crease where the write that made it bound the name, and a
  // construction otherwise. The crease is the identity to prefer: it is the
  // bundle every segment of the line shares (ADR-0014), and the drawing carries
  // the line as those segments rather than as a construction.
  const creaseByName = new Map<string, string>();
  for (const [id, crease] of Object.entries(scene.inspect?.creases ?? {})) {
    if (crease.name !== null) creaseByName.set(crease.name, id);
  }
  for (const line of scene.namedLines) {
    const statement = spanOfStatement(scene, line.statement);
    if (statement === null) continue;
    const creaseId = creaseByName.get(line.name);
    const spelling = `--${line.name}`;
    targets.push({
      entity:
        creaseId === undefined
          ? { kind: "construction", name: line.name }
          : { kind: "crease", creaseId },
      span: headOf(statement, spelling),
      spelling,
    });
  }

  for (const write of scene.writes) {
    const span = spanOfStatement(scene, write.index);
    if (span === null) continue;
    const creaseId = creaseOfWrite(scene, write.index);
    if (creaseId === null) continue;
    targets.push({ entity: { kind: "crease", creaseId }, span, spelling: null });
  }

  return targets.sort((a, b) =>
    a.span.fromLine - b.span.fromLine || a.span.fromCol - b.span.fromCol,
  );
}
