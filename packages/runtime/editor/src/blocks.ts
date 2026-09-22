// The source a step stands for, and what that source built.
//
// Only a fold or a mark makes a step, so a program is a sequence of blocks:
// each statement owns its own line and everything under it until the next
// statement. A point, a named line or a comment in between belongs to the
// step it follows, and the drawing at that step carries what it built.
import type { FoldScene } from "@beloch/scene";

export interface SourceBlock {
  // Index into the statement list. -1 is the source above the first
  // statement, where the paper is declared.
  statement: number;
  fromLine: number;
  // Last line of the block, or null where it runs to the end of the program.
  toLine: number | null;
}

// The line a statement occupies, 1-based as the editor counts.
const lineOf = (scene: FoldScene, index: number): number | null =>
  scene.statements[index]?.sourceLine ?? null;

// The block a step stands for. Step 0 is the source above the first
// statement; step n is the n-th statement and what follows it.
export function blockOfStep(scene: FoldScene, step: number): SourceBlock {
  const statement = step - 1;
  const next = lineOf(scene, step);
  if (statement < 0) {
    const first = lineOf(scene, 0);
    return { statement: -1, fromLine: 1, toLine: first === null ? null : first - 1 };
  }
  return {
    statement,
    fromLine: lineOf(scene, statement) ?? 1,
    toLine: next === null ? null : next - 1,
  };
}

// The block a source line falls in. A line above the first statement belongs
// to the leading block, which is what a reader pointing at `paper square`
// asks about.
export function blockAtLine(scene: FoldScene, line: number): SourceBlock {
  let step = 0;
  for (let i = 0; i < scene.statements.length; i++) {
    if ((lineOf(scene, i) ?? 0) <= line) step = i + 1;
    else break;
  }
  return blockOfStep(scene, step);
}

// Every entity a block's source named, by the identity each kind carries: a
// crease by its bundle id (ADR-0014), a point and a construction line by
// their name.
export interface BlockEntities {
  creases: string[];
  points: string[];
  lines: string[];
}

export const NOTHING: BlockEntities = { creases: [], points: [], lines: [] };

const lineOfSpan = (span: string | null): number | null => {
  const m = span?.match(/:(\d+):/);
  return m ? Number(m[1]) : null;
};

const within = (block: SourceBlock, line: number | null): boolean =>
  line !== null && line >= block.fromLine && (block.toLine === null || line <= block.toLine);

// The frame a block's statements read against. The leading block is the flat
// sheet, frame 0.
const frameOf = (scene: FoldScene, block: SourceBlock): number =>
  block.statement < 0 ? 0 : scene.statements[block.statement]?.frameIndex ?? 0;

// A named line carries the frame it was bound against and no statement of its
// own. Where every statement is a fold, each one advances the frame by one and
// the frame a block reads against is the frame its lines were bound at, so the
// two line up. A mark breaks that: it draws against one frame and the counter
// stands elsewhere afterwards, and a line then cannot be told apart from one
// declared a block away. The lines stay out of every block in such a program
// rather than lighting up in the wrong one. What would settle it is a
// `statement` field on a named line in the FOLD, which named points already
// carry (spec/FOLD.md).
function framesArePlaceable(scene: FoldScene): boolean {
  return scene.statements.every((s, i) => s.kind === "fold" && s.frameIndex === i + 1);
}

export function entitiesIn(scene: FoldScene, block: SourceBlock): BlockEntities {
  const creases = Object.entries(scene.inspect?.creases ?? {})
    .filter(([, crease]) => within(block, lineOfSpan(crease.span)))
    .map(([id]) => id);
  // A point records how many statements ran before it was declared, which is
  // the number of the block it sits in.
  const points = scene.namedPoints
    .filter((p) => p.statement === block.statement + 1)
    .map((p) => p.name);
  const frame = frameOf(scene, block);
  const lines = framesArePlaceable(scene)
    ? scene.namedLines.filter((l) => l.step === frame).map((l) => l.name)
    : [];
  return { creases, points, lines };
}
