// <beloch-figure> hydration island: wraps a statically-rendered
// <figure class="beloch-card"> (see Beloch.astro) and, when the fold has
// foldedForm steps, adds a per-step stepper that moves both drawings of the
// state at once — re-rendering via the same pure-TS render pipeline used at
// build time. The card shows the crease pattern and the folded form side by
// side, so there is no view to switch.
import { parseFold, type FoldScene } from "@beloch/scene";
import { renderCP, renderFolded, renderScene, WEB_THEME } from "@beloch/render-svg";
import { swapDrawing, type FadeLength } from "./crossfade";

export function clampStep(i: number, n: number): number {
  if (n <= 0) return 0;
  return Math.max(0, Math.min(i, n - 1));
}
export function viewHasSteps(scene: FoldScene): boolean {
  return scene.steps.length > 0;
}

class BelochFigure extends HTMLElement {
  private static PALETTE = ["#e8a33d", "#3db0a8", "#a878e0", "#5fa85f", "#e06e9e", "#4aa8d8"];

  private scene: FoldScene | null = null;
  private step = 0;
  private cpHTML = "";                 // cached SSR CP svg
  private hydrated = false;
  selected = new Set<string>();
  private colorOf = new Map<string, string>();

  connectedCallback() {
    // Lazy: hydrate when near the viewport.
    if (!("IntersectionObserver" in window)) { this.hydrate(); return; }
    const io = new IntersectionObserver((entries, obs) => {
      if (entries.some((e) => e.isIntersecting)) { obs.disconnect(); this.hydrate(); }
    });
    io.observe(this);
  }

  hydrate() {
    if (this.hydrated) return;
    this.hydrated = true;
    const raw = this.querySelector("script.beloch-fold")?.textContent ?? "";
    const diagram = this.querySelector('.beloch-diagram[data-view="cp"]') as HTMLElement | null;
    if (!raw || !diagram) return;
    try {
      this.scene = parseFold(JSON.parse(raw));
    } catch (err) {
      console.warn("beloch-figure: parse failed, keeping static SVG", err);
      return;                            // graceful degradation
    }
    this.cpHTML = diagram.innerHTML;      // the SSR crease pattern, and the fallback
    if (viewHasSteps(this.scene)) {
      this.step = this.scene.steps.length - 1;
      this.buildControls();
    }
    this.wireInteraction();
  }

  // Bidirectional hover + persistent multi-selection, delegated on the whole
  // card so it works for both the code panel's spans and the injected SVG's
  // creases/vertex dots, and survives re-renders (view/step changes) via the
  // afterRender hook (Task 5).
  //
  // NB: mouseenter/mouseleave (not mouseover/mouseout) — they don't bubble
  // natively, so delegation needs the *capture* phase, which always sees
  // every descendant's mouseenter/mouseleave regardless of the bubbles flag.
  private wireInteraction() {
    this.addEventListener("mouseenter", (e) => {
      const n = (e.target as Element | null)?.closest?.("[data-bel-name]") as HTMLElement | null;
      if (n) this.setHover(n.dataset.belName!, true);
    }, true);
    this.addEventListener("mouseleave", (e) => {
      const n = (e.target as Element | null)?.closest?.("[data-bel-name]") as HTMLElement | null;
      if (n) this.setHover(n.dataset.belName!, false);
    }, true);
    this.addEventListener("click", (e) => {
      const n = (e.target as Element | null)?.closest?.("[data-bel-name]") as HTMLElement | null;
      if (n) this.toggleSelect(n.dataset.belName!);
    });
    this.afterRender = () => this.applySelection();
  }

  private matches(name: string): HTMLElement[] {
    return Array.from(this.querySelectorAll<HTMLElement>(`[data-bel-name="${CSS.escape(name)}"]`));
  }
  private setHover(name: string, on: boolean) {
    this.matches(name).forEach((el) => el.classList.toggle("bel-hover", on));
  }
  private pickColor(): string {
    const used = new Set(this.colorOf.values());
    for (const c of BelochFigure.PALETTE) if (!used.has(c)) return c;
    // all palette slots active → unavoidable reuse, cycle by count
    return BelochFigure.PALETTE[this.colorOf.size % BelochFigure.PALETTE.length]!;
  }
  private toggleSelect(name: string) {
    if (this.selected.has(name)) {
      this.selected.delete(name);
      this.colorOf.delete(name);
    } else {
      this.selected.add(name);
      if (!this.colorOf.has(name))
        this.colorOf.set(name, this.pickColor());
    }
    this.applySelection();
  }
  private applySelection() {
    this.querySelectorAll(".bel-selected").forEach((el) => {
      el.classList.remove("bel-selected");
      (el as HTMLElement).style.removeProperty("--bel-sel");
    });
    this.selected.forEach((name) => {
      const color = this.colorOf.get(name)!;
      this.matches(name).forEach((el) => {
        el.classList.add("bel-selected");
        el.style.setProperty("--bel-sel", color);
      });
    });
  }

  private buildControls() {
    const bar = document.createElement("div");
    bar.className = "beloch-controls";
    bar.innerHTML = `
      <span class="beloch-stepper">
        <button type="button" class="beloch-step-prev" aria-label="Previous step">◀</button>
        <span class="beloch-step-label"></span>
        <button type="button" class="beloch-step-next" aria-label="Next step">▶</button>
      </span>`;
    this.querySelector(".beloch-card")?.prepend(bar);
    bar.querySelector(".beloch-step-prev")!.addEventListener("click", () => this.setStep(this.step - 1));
    bar.querySelector(".beloch-step-next")!.addEventListener("click", () => this.setStep(this.step + 1));
    this.updateStepLabel();
  }

  private setStep(i: number) {
    if (!this.scene) return;
    this.step = clampStep(i, this.scene.steps.length);
    this.render("fold");
  }

  private updateStepLabel() {
    const lbl = this.querySelector(".beloch-step-label");
    // 0-based: step 0 is the flat starting sheet, step k the k-th fold.
    if (lbl && this.scene) lbl.textContent = `Step ${this.step} / ${this.scene.steps.length - 1}`;
  }

  // The only caller is a click, so the drawings always crossfade; the card's
  // first pair comes from the server and is never rendered here. Both panels
  // move together, because they are two drawings of one state: the crease
  // pattern carries the creases that exist by this step, the folded form is
  // that state with its layers resolved.
  private render(fade: FadeLength) {
    if (!this.scene) return;
    const cp = this.querySelector('.beloch-diagram[data-view="cp"]') as HTMLElement | null;
    const folded = this.querySelector('.beloch-diagram[data-view="folded"]') as HTMLElement | null;
    try {
      const index = this.scene.steps[this.step]?.index;
      if (cp) {
        const cpSvg =
          index === undefined
            ? this.cpHTML || renderCP(this.scene, { theme: WEB_THEME }).toString()
            : renderScene(this.scene, {
                theme: WEB_THEME,
                isometry: { kind: "flat" },
                texture: {
                  upToStep: index,
                  creases: true,
                  marks: true,
                  points: true,
                  lines: true,
                  faces: "outline",
                },
              }).toString();
        swapDrawing(cp, cpSvg, fade);
      }
      if (folded) {
        swapDrawing(folded, renderFolded(this.scene, {
          step: String(this.step), hidden: "dashed", theme: WEB_THEME,
        }).toString(), fade);
      }
      this.updateStepLabel();
    } catch (err) {
      console.warn("beloch-figure: render failed", err);
      return;                              // graceful degradation: keep prior diagram
    }
    // selection re-application — the diagram was just replaced wholesale, so
    // any [data-bel-name] elements lost their .bel-selected/.bel-hover state.
    this.afterRender?.();
    this.highlightStepLine();
  }

  // Marks the gutter line number of the fold that produced the currently
  // shown step, so the reader can see which source line is "active". No-op
  // (after clearing) for step-marker frames, which have no sourceLine.
  private highlightStepLine() {
    this.querySelectorAll(".bel-step-line").forEach((el) => el.classList.remove("bel-step-line"));
    const sl = this.scene?.steps[this.step]?.sourceLine;
    if (sl == null) return;
    const offset = Number(this.dataset.lineOffset ?? 0);
    const gutterLine = sl + offset;
    this.querySelector(`.beloch-gutter [data-line="${gutterLine}"]`)?.classList.add("bel-step-line");
  }

  afterRender?: () => void;             // set by wireInteraction() → re-applies selection
}

if (typeof customElements !== "undefined" && !customElements.get("beloch-figure")) {
  customElements.define("beloch-figure", BelochFigure);
}
