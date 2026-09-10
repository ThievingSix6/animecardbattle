// Ported from scripts/ui/design.gd — the single source of truth for
// visual values. Colours match the Godot project exactly.

import type { Element, Rarity, Role } from "./config";

export const RARITY_COLOR: Record<Rarity, string> = {
  Common: "#8a8f9a", Uncommon: "#3ecf7e", Rare: "#3b82f6", Epic: "#a855f7",
  Legendary: "#f5a623", Mythic: "#ef4444", Secret: "#ffffff", Awakened: "#ff2d95",
};

export const RARITY_BORDER: Record<Rarity, number> = {
  Common: 2, Uncommon: 2, Rare: 3, Epic: 4,
  Legendary: 5, Mythic: 6, Secret: 7, Awakened: 8,
};

export const RARITY_AURA: Record<Rarity, number> = {
  Common: 0, Uncommon: 4, Rare: 8, Epic: 13,
  Legendary: 18, Mythic: 24, Secret: 30, Awakened: 38,
};

export const ELEMENT_COLOR: Record<Element, string> = {
  Fire: "#e0532c", Water: "#2c86e0", Earth: "#8a6a42",
  Wind: "#3ac9a6", Light: "#e0c840", Dark: "#7a4ae0",
};

export const ELEMENT_ICON: Record<Element, string> = {
  Fire: "🔥", Water: "💧", Earth: "⛰️", Wind: "🌪️", Light: "✨", Dark: "🌑",
};

export const ROLE_ICON: Record<Role, string> = {
  Tank: "🛡️", DPS: "⚔️", Assassin: "🗡️", Healer: "💚", Support: "🔮",
};

export function rarityColor(rarity: string): string {
  return RARITY_COLOR[rarity as Rarity] ?? "#646c7e";
}

export function elementColor(element: string): string {
  return ELEMENT_COLOR[element as Element] ?? "#262c3d";
}

export function rarityBorder(rarity: string): number {
  return RARITY_BORDER[rarity as Rarity] ?? 2;
}

export function rarityAura(rarity: string): number {
  return RARITY_AURA[rarity as Rarity] ?? 0;
}

export function elementIcon(element: string): string {
  return ELEMENT_ICON[element as Element] ?? "◆";
}

export function roleIcon(role: string): string {
  return ROLE_ICON[role as Role] ?? "◆";
}
