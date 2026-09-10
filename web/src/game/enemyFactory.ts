// Ported from scripts/battle/enemy_factory.gd — builds the opposing team
// for a tower floor. Separated from both the simulation and the view so
// encounter design can evolve on its own.

import * as Config from "./config";
import type { Role } from "./config";
import { makeCard, type CardData } from "./cardData";
import { pickSkillId } from "./cardGenerator";
import { rng } from "./rng";
import type { ProgressionSystem } from "./progression";
import { zoneForFloor, type Zone } from "./campaign";

type Tier = Zone;

const BASE = { attack: 18.0, defense: 20.0, health: 200.0, speed: 8.0 };

/** Enemy identity comes from the campaign zone that owns this floor. */
export function tierFor(floorNumber: number): Tier {
  return zoneForFloor(floorNumber);
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

  // Enemies carry passives too, or the player's own skills fight nothing.
  // Rank-and-file only start showing them once the early floors are past,
  // so the opening zone stays a clean introduction to the basic loop.
  const rarity = isBoss ? "Legendary" : "Common";
  const wantsSkill = isBoss || floorNumber > 3;

  return makeCard({
    skillId: wantsSkill ? pickSkillId(role, rarity, rng) : "",
    cardId: `enemy_${floorNumber}_${slot}`,
    cardName: isBoss ? tier.boss : rng.pick(tier.names),
    role,
    rarity,
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
