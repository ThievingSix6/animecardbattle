// Ported from scripts/battle/enemy_factory.gd — builds the opposing team
// for a tower floor. Separated from both the simulation and the view so
// encounter design can evolve on its own.

import * as Config from "./config";
import type { Element, Role } from "./config";
import { makeCard, type CardData } from "./cardData";
import { rng } from "./rng";
import type { ProgressionSystem } from "./progression";

interface Tier {
  upto: number; element: Element; boss: string; names: string[]; roles: Role[];
}

export const TIERS: Tier[] = [
  { upto: 9,    element: "Earth", boss: "Golem Warlord",       names: ["Training Golem", "Rusted Automaton", "Stone Sentinel"], roles: ["Tank", "DPS"] },
  { upto: 19,   element: "Earth", boss: "Alpha Direwolf",      names: ["Feral Wolf", "Bandit Scout", "Marsh Lurker"],           roles: ["DPS", "Assassin", "Support"] },
  { upto: 29,   element: "Dark",  boss: "The Bandit Kingpin",  names: ["Bandit Raider", "Rogue Mercenary", "Cutthroat"],        roles: ["DPS", "Assassin", "Tank"] },
  { upto: 39,   element: "Dark",  boss: "High Cultist Mordrai", names: ["Dark Cultist", "Shadow Acolyte", "Void Priest"],        roles: ["DPS", "Healer", "Support"] },
  { upto: 49,   element: "Light", boss: "The Ancient Titan",   names: ["Ancient Guardian", "Fallen Knight", "Wraith Sentinel"], roles: ["Tank", "DPS", "Assassin"] },
  { upto: 9999, element: "Dark",  boss: "The Tower's Heart",   names: ["Tower Wraith", "Voidbound Horror", "Nameless Sentinel"], roles: ["Tank", "DPS", "Assassin"] },
];

const BASE = { attack: 18.0, defense: 20.0, health: 200.0, speed: 8.0 };

export function tierFor(floorNumber: number): Tier {
  return TIERS.find((t) => floorNumber <= t.upto) ?? TIERS[TIERS.length - 1];
}

export function buildFloor(floorNumber: number, progression: ProgressionSystem): CardData[] {
  const tier = tierFor(floorNumber);
  const count = progression.enemyCount(floorNumber);
  const scale = progression.statMultiplier(floorNumber);

  const out: CardData[] = [];
  for (let i = 0; i < count; i++) {
    const isBoss = i === count - 1 && progression.isBossFloor(floorNumber);
    out.push(build(tier, floorNumber, i, scale, isBoss));
  }
  return out;
}

function build(tier: Tier, floorNumber: number, slot: number, scale: number, isBoss: boolean): CardData {
  const role: Role = isBoss ? "Tank" : rng.pick(tier.roles);
  const shape = Config.ROLE_STATS[role] ?? Config.ROLE_STATS.DPS;
  const bossMult = isBoss ? Config.BOSS_STAT_MULT : 1.0;

  return makeCard({
    cardId: `enemy_${floorNumber}_${slot}`,
    cardName: isBoss ? tier.boss : rng.pick(tier.names),
    role,
    rarity: isBoss ? "Legendary" : "Common",
    modifier: "Normal",
    element: tier.element,
    originTag: "enemy",
    basicAbility: isBoss ? "Crushing Blow" : "Strike",
    ultimateAbility: isBoss ? "Devastation" : "Heavy Strike",
    attack: Math.max(5, Math.floor(BASE.attack * scale * bossMult * shape.attack)),
    defense: Math.max(3, Math.floor(BASE.defense * scale * bossMult * shape.defense)),
    health: Math.max(60, Math.floor(BASE.health * scale * bossMult * shape.health)),
    speed: Math.max(4, Math.floor(BASE.speed * scale * shape.speed)),
  });
}
