// Minimal DOM helpers. Everything is built with real elements rather than
// innerHTML so card data can never be interpreted as markup.

export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attrs: Record<string, string> = {},
  children: Array<Node | string> = [],
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (key === "class") node.className = value;
    else if (key === "style") node.setAttribute("style", value);
    else node.setAttribute(key, value);
  }
  for (const child of children) {
    node.append(typeof child === "string" ? document.createTextNode(child) : child);
  }
  return node;
}

export function button(
  label: string,
  onClick: () => void,
  className = "btn",
): HTMLButtonElement {
  const b = el("button", { class: className }, [label]);
  b.addEventListener("click", onClick);
  return b;
}

export function clear(node: HTMLElement): void {
  node.replaceChildren();
}

/** 1234567 -> "1.23M" — mirrors Fmt.compact in the Godot project. */
export function compact(value: number): string {
  const abs = Math.abs(value);
  if (abs >= 1e12) return `${(value / 1e12).toFixed(2)}T`;
  if (abs >= 1e9) return `${(value / 1e9).toFixed(2)}B`;
  if (abs >= 1e6) return `${(value / 1e6).toFixed(2)}M`;
  if (abs >= 1e4) return `${(value / 1e3).toFixed(1)}K`;
  return Math.round(value).toLocaleString();
}

export function commas(value: number): string {
  return Math.round(value).toLocaleString();
}
