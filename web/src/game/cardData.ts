// Ported from scripts/models/card_data.gd

import type { Element, Rarity, Role, TargetMode } from "./config";

export type PassiveType = "" | "guardian_block_heal" | "lifesteal" | "energy_surge";

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
  passiveAbility: string;
  ultimateAbility: string;

  basicTargetMode: TargetMode;
  ultimateTargetMode: TargetMode;

  passiveType: PassiveType;
  passiveChance: number;
  passiveValue: number;

  sellValue: number;
  locked: boolean;
}

export function makeCard(partial: Partial<CardData> = {}): CardData {
  return {
    cardId: "", cardName: "", description: "",
    faction: "", element: "Fire", role: "DPS", originTag: "",
    rarity: "Common", modifier: "Normal",
    attack: 10, defense: 10, health: 100, speed: 10,
    basicAbility: "", passiveAbility: "", ultimateAbility: "",
    basicTargetMode: "active", ultimateTargetMode: "active",
    passiveType: "", passiveChance: 0, passiveValue: 0,
    sellValue: 10, locked: false,
    ...partial,
  };
}

export function cloneCard(card: CardData): CardData {
  return { ...card };
}
