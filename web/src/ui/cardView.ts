// Card rendering. The Godot build draws artwork behind the frame; with no
// art shipped, the prototype leans on the element wash plus role/element
// sigils, which is what CardArt.tint_for falls back to.

import type { CardData } from "../game/cardData";
import * as Design from "../game/design";
import * as Mutations from "../game/mutations";
import { compact, el } from "./dom";

export interface CardViewOptions {
  copies?: number;
  inTeam?: boolean;
  selected?: boolean;
  onClick?: (card: CardData) => void;
}

export function cardView(card: CardData, options: CardViewOptions = {}): HTMLElement {
  const rarityCol = Design.rarityColor(card.rarity);
  const mutated = Mutations.isMutated(card.modifier);
  const borderCol = mutated ? Mutations.color(card.modifier) : rarityCol;
  const aura = Design.rarityAura(card.rarity) + (mutated ? Mutations.glow(card.modifier) : 0);

  const node = el("div", {
    class: `card${options.selected ? " selected" : ""}`,
    style: [
      `--el:${Design.elementColor(card.element)}`,
      `border-color:${borderCol}`,
      `border-width:${Design.rarityBorder(card.rarity)}px`,
      aura > 0 ? `box-shadow:0 0 ${Math.min(aura, 26)}px ${hexAlpha(borderCol, 0.45)}` : "",
    ].filter(Boolean).join(";"),
    tabindex: "0",
    role: "button",
    "aria-label": `${card.cardName}, ${card.rarity} ${card.role}`,
  });

  node.append(
    el("div", { class: "sigil" }, [
      `${Design.elementIcon(card.element)}${Design.roleIcon(card.role)}`,
    ]),
    el("div", { class: "rarity", style: `color:${rarityCol}` }, [card.rarity]),
    el("div", { class: "name" }, [card.cardName]),
    el("div", { class: "meta" }, [`${card.element} · ${card.role}`]),
  );

  if (mutated) {
    node.append(
      el("div", { class: "mutation", style: `color:${Mutations.color(card.modifier)}` }, [
        Mutations.displayName(card.modifier),
      ]),
    );
  }

  node.append(
    el("div", { class: "stats" }, [
      el("span", {}, [`⚔ ${compact(card.attack)}`]),
      el("span", {}, [`🛡 ${compact(card.defense)}`]),
      el("span", {}, [`❤ ${compact(card.health)}`]),
      el("span", {}, [`⚡ ${compact(card.speed)}`]),
    ]),
  );

  if (options.copies && options.copies > 1) {
    node.append(el("div", { class: "copies" }, [`×${compact(options.copies)}`]));
  }
  if (options.inTeam) {
    node.append(el("div", { class: "team-flag" }, ["TEAM"]));
  }

  if (options.onClick) {
    const fire = () => options.onClick!(card);
    node.addEventListener("click", fire);
    node.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        fire();
      }
    });
  }

  return node;
}

function hexAlpha(hex: string, alpha: number): string {
  const m = /^#([0-9a-f]{6})$/i.exec(hex);
  if (!m) return hex;
  const n = parseInt(m[1], 16);
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`;
}
