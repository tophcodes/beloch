export interface SvgNode {
  tag: string;
  attrs: Record<string, string | number>;
  children: SvgNode[];
  text?: string;
}

export function el(
  tag: string,
  attrs: SvgNode["attrs"] = {},
  children: SvgNode[] = [],
  text?: string,
): SvgNode {
  return { tag, attrs, children, text };
}

export type LayerName = "paper" | "creases" | "annotations" | "hud";
const LAYER_ORDER: LayerName[] = ["paper", "creases", "annotations", "hud"];

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

function serialize(n: SvgNode): string {
  const attrs = Object.entries(n.attrs)
    .map(([k, v]) => ` ${k}="${esc(String(v))}"`)
    .join("");
  const inner = (n.text !== undefined ? esc(n.text) : "") + n.children.map(serialize).join("");
  return inner ? `<${n.tag}${attrs}>${inner}</${n.tag}>` : `<${n.tag}${attrs}/>`;
}

const SVG_NS = "http://www.w3.org/2000/svg";

function toElement(document: Document, n: SvgNode): Element {
  const e = document.createElementNS(SVG_NS, n.tag);
  for (const [k, v] of Object.entries(n.attrs)) e.setAttribute(k, String(v));
  if (n.text !== undefined) e.appendChild(document.createTextNode(n.text));
  for (const c of n.children) e.appendChild(toElement(document, c));
  return e;
}

export class SvgDoc {
  readonly root: SvgNode;
  private layers = new Map<LayerName, SvgNode>();

  constructor(readonly width: number, readonly height: number) {
    this.root = el("svg", {
      xmlns: SVG_NS,
      width, height,
      viewBox: `0 0 ${width} ${height}`,
      "font-family": "ui-sans-serif, system-ui, sans-serif",
    });
  }

  layer(name: LayerName): SvgNode {
    let g = this.layers.get(name);
    if (!g) {
      g = el("g", { "data-layer": name });
      this.layers.set(name, g);
    }
    return g;
  }

  private assembled(): SvgNode {
    const ordered = LAYER_ORDER.map((n) => this.layers.get(n)).filter(
      (g): g is SvgNode => !!g,
    );
    return { ...this.root, children: [...this.root.children, ...ordered] };
  }

  toString(): string {
    return serialize(this.assembled());
  }

  toDOM(document: Document): Element {
    return toElement(document, this.assembled());
  }
}

export function createDoc(width: number, height: number): SvgDoc {
  return new SvgDoc(width, height);
}
