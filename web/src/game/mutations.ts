// Ported from scripts/core/mutations.gd — a second axis of rarity rolled
// independently of the card's tier. Mutated copies are separate
// collection entries, so a Gold copy and a plain copy coexist.

import { cloneCard, type CardData } from "./cardData";
import { rng } from "./rng";

export interface MutationTier {
  id: string; name: string; weight: number;
  mult: number; color: string; glow: number; rainbow: boolean;
}

export const TIERS: MutationTier[] = [
  { id: "normal",    name: "",          weight: 1_000_000, mult: 1.00, color: "#8a8f9a", glow: 0,  rainbow: false },
  { id: "silver",    name: "Silver",    weight:   180_000, mult: 1.18, color: "#c8d2e0", glow: 6,  rainbow: false },
  { id: "gold",      name: "Gold",      weight:    45_000, mult: 1.40, color: "#f5c518", glow: 10, rainbow: false },
  { id: "platinum",  name: "Platinum",  weight:     9_000, mult: 1.70, color: "#7fe7e0", glow: 14, rainbow: false },
  { id: "obsidian",  name: "Obsidian",  weight:     1_800, mult: 2.10, color: "#6b4ea8", glow: 18, rainbow: false },
  { id: "radiant",   name: "Radiant",   weight:       320, mult: 2.60, color: "#fff3c4", glow: 22, rainbow: false },
  { id: "void",      name: "Void",      weight:        55, mult: 3.30, color: "#3b1a5c", glow: 26, rainbow: false },
  { id: "prismatic", name: "Prismatic", weight:         8, mult: 4.40, color: "#ff6bd6", glow: 32, rainbow: true },
  { id: "celestial", name: "Celestial", weight:       0.6, mult: 6.00, color: "#ffffff", glow: 40, rainbow: true },
];

export const DEFAULT_ID = "normal";

export function allIds(): string[] {
  return TIERS.map((t) => t.id);
}

export function data(mutationId: string): MutationTier {
  return TIERS.find((t) => t.id === mutationId) ?? TIERS[0];
}

export function displayName(mutationId: string): string {
  return data(mutationId).name;
}

export function multiplier(mutationId: string): number {
  return data(mutationId).mult;
}

export function color(mutationId: string): string {
  return data(mutationId).color;
}

export function glow(mutationId: string): number {
  return data(mutationId).glow;
}

export function isRainbow(mutationId: string): boolean {
  return data(mutationId).rainbow;
}

export function isMutated(mutationId: string): boolean {
  return mutationId !== DEFAULT_ID && mutationId !== "" && mutationId !== "Normal";
}

export function totalWeight(): number {
  return TIERS.reduce((sum, t) => sum + t.weight, 0);
}

export function chanceOf(mutationId: string): number {
  const total = totalWeight();
  return total <= 0 ? 0 : data(mutationId).weight / total;
}

/** Luck skews mutation rolls the same way it skews rarity. */
export function roll(luck = 0): string {
  let total = 0;
  const weights = TIERS.map((tier) => {
    const w = tier.id === DEFAULT_ID ? tier.weight : tier.weight * (1 + luck);
    total += w;
    return w;
  });

  let pick = rng.randf() * total;
  for (let i = 0; i < TIERS.length; i++) {
    pick -= weights[i];
    if (pick <= 0) return TIERS[i].id;
  }
  return DEFAULT_ID;
}

export function apply(template: CardData, mutationId: string): CardData {
  if (!isMutated(mutationId)) return template;

  const card = cloneCard(template);
  card.cardId = `${template.cardId}#${mutationId}`;
  card.modifier = mutationId;

  const mult = multiplier(mutationId);
  card.attack = Math.round(card.attack * mult);
  card.defense = Math.round(card.defense * mult);
  card.health = Math.round(card.health * mult);
  card.speed = Math.round(card.speed * (1 + (mult - 1) * 0.25));
  card.sellValue = Math.round(card.sellValue * mult * 2);

  return card;
}
