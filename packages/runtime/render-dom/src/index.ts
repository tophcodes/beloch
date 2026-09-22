import type { FoldScene } from "@beloch/scene";
import type { Theme } from "@beloch/render-svg";
import type { RenderCommand } from "@beloch/runtime";
import { applyHighlight } from "./highlight";
import { enhanceHits } from "./hits";
import { commandToSvg } from "./svg";
import { swapDrawing, type FadeLength } from "./swap";

export * from "./emphasis";
export * from "./highlight";
export * from "./hits";
export * from "./match";
export * from "./svg";
export * from "./swap";

export interface DrawOptions {
  // The colours to draw in. Compared by identity, so a host that builds a
  // fresh theme object per call redraws on every event; one theme object per
  // style is what lets a hover cost a class change.
  theme: Partial<Theme>;
  // How to get from the drawing on screen to this one. Null replaces it
  // outright, which is what a first drawing and a fresh evaluation do.
  fade: FadeLength | null;
}

export interface DomRenderer {
  // Draws `command` of `scene` into the host element.
  draw(scene: FoldScene, command: RenderCommand, options: DrawOptions): void;
}

// Do the two commands ask for the same picture? The highlight is left out: it
// is put on the drawing afterwards and changing it costs no redraw. Mark lists
// are compared by identity, since a statement hands out the same array every
// time it is asked.
function samePicture(a: RenderCommand, b: RenderCommand): boolean {
  switch (a.kind) {
    case "cp-only":
      return b.kind === "cp-only";
    case "flat":
      return (
        b.kind === "flat" &&
        a.upToStatement === b.upToStatement &&
        a.marks === b.marks &&
        a.newestCreaseId === b.newestCreaseId
      );
    case "folded":
      return (
        b.kind === "folded" &&
        a.frame === b.frame &&
        a.hidden === b.hidden &&
        a.marks === b.marks &&
        a.newestCreaseId === b.newestCreaseId
      );
  }
}

// The renderer plug for a DOM host: SVG in an element, with a hit target per
// crease and per point, and the highlight the command names.
//
// It holds what it last drew so that a command asking for the same picture
// re-lights rather than rebuilds. A pointer resting on a crease sends a hover
// per mouse event, and rebuilding the drawing there would restart a running
// fade and drop the reader's framing.
//
// The viewport is the host's: pan, zoom and the element that carries the
// transform survive these swaps untouched.
export function createDomRenderer(host: HTMLElement): DomRenderer {
  let drawn: { scene: FoldScene; command: RenderCommand; theme: Partial<Theme> } | null = null;
  return {
    draw(scene, command, options) {
      const rebuild =
        drawn === null ||
        drawn.scene !== scene ||
        drawn.theme !== options.theme ||
        !samePicture(drawn.command, command);
      if (rebuild) {
        swapDrawing(host, commandToSvg(scene, command, options.theme), options.fade);
      }
      // The outgoing drawing of a fade is inert, and it sits after the
      // incoming one, so `querySelector` reaches the step that is current.
      const live = host.querySelector("svg") ?? host;
      if (rebuild) enhanceHits(live);
      applyHighlight(live, scene, command);
      drawn = { scene, command, theme: options.theme };
    },
  };
}
