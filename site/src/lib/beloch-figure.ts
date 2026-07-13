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
  private scene: FoldScene | null = null;
  private view: View = "cp";
  private step = 0;
  private cpHTML = "";                 // cached SSR CP svg
  private hydrated = false;

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
          step: String(this.step + 1), hidden: "dashed",
        }).toString();
        const lbl = this.querySelector(".beloch-step-label");
        if (lbl) lbl.textContent = `${this.step + 1}/${this.scene.steps.length}`;
      }
    } catch (err) {
      console.warn("beloch-figure: render failed", err);
      return;                              // graceful degradation: keep prior diagram
    }
    // (selection re-application hook — filled in Task 6)
    this.afterRender?.();
  }

  afterRender?: () => void;             // Task 6 attaches selection re-apply here
}

if (typeof customElements !== "undefined" && !customElements.get("beloch-figure")) {
  customElements.define("beloch-figure", BelochFigure);
}
