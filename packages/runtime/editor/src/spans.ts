// Where the source says what the drawing shows, in both directions: the spans
// an editor marks for what the reader settled on, and what the source under
// the cursor names.
//
// Both sides read `beloch:inspect` and `beloch:references`, which the emitter
// wrote as it resolved each mention. Re-lexing the text could not produce
// them: one spelling names different creases inside a `def` body and after a
// `--x!` rebinding.
//
// Free of the editor it serves. A host turns a line and a column into its own
// idea of a position (a CodeMirror offset, a `TextDocument` range) and the
// spans stay text.
import type { FoldScene } from "@beloch/scene";
import type { EntityRef } from "@beloch/runtime";

// A span's place in the text, 1-based as an editor counts, with `toCol`
// exclusive.
export interface SpanPos {
  fromLine: number;
  fromCol: number;
  toLine: number;
  toCol: number;
}

// The emitter writes "file:line:col-col" on one line and
// "file:line:col-line:col" across two (Error.span_to_string). A path may
// itself contain colons, so both shapes are matched from the end.
export function parseSpan(span: string): SpanPos | null {
  const multi = /:(\d+):(\d+)-(\d+):(\d+)$/.exec(span);
  if (multi) {
    return {
      fromLine: Number(multi[1]), fromCol: Number(multi[2]),
      toLine: Number(multi[3]), toCol: Number(multi[4]),
    };
  }
  const one = /:(\d+):(\d+)-(\d+)$/.exec(span);
  if (!one) return null;
  const line = Number(one[1]);
  return { fromLine: line, fromCol: Number(one[2]), toLine: line, toCol: Number(one[3]) };
}

// The line a span starts on, which is all a line marker needs.
export function lineOfSpan(span: string | null): number | null {
  return span === null ? null : parseSpan(span)?.fromLine ?? null;
}

const namesEntity = (entity: EntityRef) => {
  switch (entity.kind) {
    case "crease":
      return (id: number | null, _edge: string | null) => id !== null && String(id) === entity.creaseId;
    case "edge":
      return (_id: number | null, edge: string | null) => edge === entity.name;
    // A face is the paper between creases and a vertex is where they meet.
    // The program names neither, so nothing in the source is marked for them.
    default:
      return () => false;
  }
};

// Every place the program names one of `entities`, in source order as the
// emitter recorded it: the operands of a construction, the arguments of a
// flatten, a filter over a bundle.
export function refSpansFor(scene: FoldScene, entities: readonly EntityRef[]): string[] {
  if (entities.length === 0) return [];
  const tests = entities.map(namesEntity);
  return scene.references
    .filter((r) => tests.some((names) => names(r.creaseId, r.edge)))
    .map((r) => r.span);
}

// The line whose statement built `entity`, where an editor puts the mark that
// says which source the drawing stands for. A paper boundary comes with the
// sheet rather than from a statement, and so answers nothing.
export function sourceLineOf(scene: FoldScene, entity: EntityRef): number | null {
  if (entity.kind !== "crease") return null;
  return lineOfSpan(scene.inspect?.creases[entity.creaseId]?.span ?? null);
}

// What the source on `line` built, as the entities a selection names. This is
// the reverse of `sourceLineOf`: a reader moving the cursor through the
// program asks the drawing what each line made.
export function entitiesAtLine(scene: FoldScene, line: number): EntityRef[] {
  return Object.entries(scene.inspect?.creases ?? {})
    .filter(([, c]) => lineOfSpan(c.span) === line)
    .map(([creaseId]) => ({ kind: "crease", creaseId }));
}
