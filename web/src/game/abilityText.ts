// Ported from scripts/ui/ability_text.gd
//
// Generates human-readable skill descriptions from a card's ACTUAL
// mechanics (target mode, multiplier, passive type and values).
//
// Deriving the text instead of hand-writing it means a description can
// never drift from what the battle simulation really does — if the balance
// numbers in config change, every card's text updates with them.

import * as Config from "./config";
import type { CardData } from "./cardData";
import { FAMILY_LABEL, skillById } from "./skills";

export function basic(card: CardData): string {
  return attackText(card.basicTargetMode, Config.BASIC_ABILITY_MULT);
}

export function ultimate(card: CardData): string {
  return `${attackText(card.ultimateTargetMode, Config.ULTIMATE_MULT)} Charges at full energy.`;
}

/** The passive's own description, straight from the skill library. */
export function passive(card: CardData): string {
  return skillById(card.skillId)?.text ?? "";
}

export function passiveName(card: CardData): string {
  return skillById(card.skillId)?.name ?? "";
}

/** The line shown on the card face: prefers the ultimate, the signature move. */
export function headlineName(card: CardData): string {
  return card.ultimateAbility || card.basicAbility || card.role;
}

export function headlineBody(card: CardData): string {
  if (card.ultimateAbility) return ultimate(card);
  if (card.basicAbility) return basic(card);
  return card.description;
}

/** Short pills describing what makes this card mechanically distinct. */
export function tags(card: CardData): string[] {
  const out: string[] = [];

  if (card.ultimateTargetMode === "aoe") out.push("AoE Ultimate");
  else if (card.ultimateTargetMode === "backline") out.push("Backline Ultimate");

  if (card.basicTargetMode === "aoe") out.push("AoE Basic");
  else if (card.basicTargetMode === "backline") out.push("Backline Basic");

  const skill = skillById(card.skillId);
  if (skill) out.push(FAMILY_LABEL[skill.family]);

  return out;
}

function attackText(mode: string, multiplier: number): string {
  const power = pct(multiplier);
  switch (mode) {
    case "aoe": return `Deals ${power} damage to every enemy.`;
    case "backline": return `Strikes the enemy backline for ${power} damage, ignoring the front.`;
    default: return `Deals ${power} damage to the active enemy.`;
  }
}

function pct(value: number): string {
  return `${Math.round(value * 100)}%`;
}

/**
 * Stable "dex number" derived from the card id, so the same card always
 * shows the same number without needing to be stored in a save file.
 */
export function dexNumber(card: CardData): number {
  let h = 0;
  for (let i = 0; i < card.cardId.length; i++) {
    h = (Math.imul(h, 31) + card.cardId.charCodeAt(i)) | 0;
  }
  return (Math.abs(h) % 999) + 1;
}
