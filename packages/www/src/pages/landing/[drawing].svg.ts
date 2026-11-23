// The drawings of the landing's example cards, one file per model and view:
// /landing/crane-cp.svg, /landing/crane-folded.svg and so on.
import type { APIRoute } from "astro";
import { MODELS, modelDrawing, type View } from "../../lib/landing-models";

const VIEWS: View[] = ["cp", "folded"];

export function getStaticPaths() {
  return MODELS.flatMap((m) =>
    VIEWS.map((view) => ({ params: { drawing: `${m.file}-${view}` }, props: { file: m.file, view } })),
  );
}

export const GET: APIRoute = ({ props }) =>
  new Response(modelDrawing(props.file as string, props.view as View), {
    headers: { "Content-Type": "image/svg+xml" },
  });
