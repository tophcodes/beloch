// Swapping the drawing for the next one.
//
// Beloch computes flat states only, so a fold cannot be shown as motion of the
// paper: every in-between frame would be geometry the language does not have.
// What it can show is the two flat states laid over each other, the state the
// reader left fading off the state they arrived at. Only the outgoing layer
// moves, so a half-transparent drawing is never on screen.
//
// The transition itself lives in the host's stylesheet. One
// prefers-reduced-motion rule there turns the fade into a jump, and this
// module never learns about it.

const GHOST = "bel-fade-ghost";

// Which duration token the fade takes: a step that folds the paper gets the
// fold length, a step that only draws a mark and a switch between two views of
// the same state get the shorter view length.
export type FadeLength = "view" | "fold";

// An element the browser never painted (a card below the fold, a background
// tab) fires no transitionend, so a fade also carries a deadline. It sits well
// past the longest duration token.
const DEADLINE_MS = 2000;

// `fade` of null replaces the drawing outright, which is what the first render
// of a card or a fresh evaluation does: motion starts on an action.
export function swapDrawing(host: HTMLElement, markup: string, fade: FadeLength | null): void {
  // A fade still running belongs to a step the reader has already left.
  host.querySelectorAll(`.${GHOST}`).forEach((el) => el.remove());

  if (fade === null) {
    host.innerHTML = markup;
    return;
  }

  const ghost = host.ownerDocument.createElement("div");
  ghost.className = GHOST;
  ghost.setAttribute("aria-hidden", "true");
  ghost.style.setProperty("--bel-fade-length", `var(--bel-duration-${fade})`);
  while (host.firstChild) ghost.appendChild(host.firstChild);

  host.classList.add("bel-fade-host");
  host.innerHTML = markup;
  // The outgoing state is appended AFTER the incoming one, so everything that
  // reaches for the drawing with `host.querySelector("svg")` keeps finding the
  // step that is current.
  host.appendChild(ghost);

  const drop = () => ghost.remove();
  ghost.addEventListener("transitionend", drop, { once: true });
  setTimeout(drop, DEADLINE_MS);

  requestAnimationFrame(() => ghost.setAttribute("data-fading", ""));
}
