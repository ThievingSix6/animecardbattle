// Ported from scripts/models/card_data.gd

import type { Element, Rarity, Role, TargetMode } from "./config";

export interface CardData {
  cardId: string;
  cardName: string;
  description: string;

  faction: string;
  element: Element;
  role: Role;
  originTag: string;

  rarity: Rarity;
  modifier: string;

  attack: number;
  defense: number;
  health: number;
  speed: number;

  basicAbility: string;
  ultimateAbility: string;

  basicTargetMode: TargetMode;
  ultimateTargetMode: TargetMode;

  /** Id into the skill library; "" means this card has no passive. */
  skillId: string;

  sellValue: number;
  locked: boolean;
}

export function makeCard(partial: Partial<CardData> = {}): CardData {
  return {
    cardId: "", cardName: "", description: "",
    faction: "", element: "Fire", role: "DPS", originTag: "",
    rarity: "Common", modifier: "Normal",
    attack: 10, defense: 10, health: 100, speed: 10,
    basicAbility: "", ultimateAbility: "",
    basicTargetMode: "active", ultimateTargetMode: "active",
    skillId: "",
    sellValue: 10, locked: false,
    ...partial,
  };
}

export function cloneCard(card: CardData): CardData {
  return { ...card };
}
