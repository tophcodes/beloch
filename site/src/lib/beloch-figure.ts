// <beloch-figure> hydration island: wraps a statically-rendered
// <figure class="beloch-card"> (see Beloch.astro), adds a CP↔folded view
// toggle and, when the fold has foldedForm steps, a per-step stepper —
// re-rendering via the same pure-TS render pipeline used at build time.
import { parseFold, type FoldScene } from "@beloch/scene";
import { renderCP, renderFolded } from "@beloch/render-svg";

export function clampStep(i: number, n: number): number {
  if (n <= 0) return 0;
  return Math.max(0, Math.min(i, n - 1));
}
export function viewHasSteps(scene: FoldScene): boolean {
  return scene.steps.length > 0;
}

type View = "cp" | "folded";

class BelochFigure extends HTMLElement {
  private static PALETTE = ["#e8a33d", "#3db0a8", "#a878e0", "#5fa85f", "#e06e9e", "#4aa8d8"];

  private scene: FoldScene | null = null;
  private view: View = "cp";
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
    const diagram = this.querySelector(".beloch-diagram") as HTMLElement | null;
    if (!raw || !diagram) return;
    try {
      this.scene = parseFold(JSON.parse(raw));
    } catch (err) {
      console.warn("beloch-figure: parse failed, keeping static SVG", err);
      return;                            // graceful degradation
    }
    this.cpHTML = diagram.innerHTML;      // keep the SSR CP as the CP view + fallback
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
      <button type="button" data-view="cp" class="beloch-tab is-active">Faltbild</button>
      <button type="button" data-view="folded" class="beloch-tab">Gefaltet</button>
      <span class="beloch-stepper" hidden>
        <button type="button" class="beloch-step-prev" aria-label="Schritt zurück">◀</button>
        <span class="beloch-step-label"></span>
        <button type="button" class="beloch-step-next" aria-label="Schritt vor">▶</button>
      </span>`;
    this.querySelector(".beloch-card")?.prepend(bar);
    bar.querySelector('[data-view="cp"]')!.addEventListener("click", () => this.setView("cp"));
    bar.querySelector('[data-view="folded"]')!.addEventListener("click", () => this.setView("folded"));
    bar.querySelector(".beloch-step-prev")!.addEventListener("click", () => this.setStep(this.step - 1));
    bar.querySelector(".beloch-step-next")!.addEventListener("click", () => this.setStep(this.step + 1));
  }

  private setView(v: View) {
    this.view = v;
    this.querySelectorAll(".beloch-tab").forEach((b) =>
      b.classList.toggle("is-active", (b as HTMLElement).dataset.view === v));
    (this.querySelector(".beloch-stepper") as HTMLElement).hidden = v !== "folded";
    this.render();
  }
  private setStep(i: number) {
    if (!this.scene) return;
    this.step = clampStep(i, this.scene.steps.length);
    this.render();
  }

  private render() {
    const diagram = this.querySelector(".beloch-diagram") as HTMLElement;
    if (!this.scene) return;
    try {
      if (this.view === "cp") {
        diagram.innerHTML = this.cpHTML || renderCP(this.scene).toString();
      } else {
        diagram.innerHTML = renderFolded(this.scene, {
          step: String(this.step), hidden: "dashed",
        }).toString();
        const lbl = this.querySelector(".beloch-step-label");
        // 0-based: step 0 is the flat starting sheet, step k the k-th fold.
        if (lbl) lbl.textContent = `Schritt ${this.step} / ${this.scene.steps.length - 1}`;
      }
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
  // shown step (folded view only) so the reader can see which source line
  // is "active". No-op (after clearing) in the CP view and for step-marker
  // frames, which have no sourceLine.
  private highlightStepLine() {
    this.querySelectorAll(".bel-step-line").forEach((el) => el.classList.remove("bel-step-line"));
    if (this.view !== "folded") return;
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
