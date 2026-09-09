// Ported from scripts/systems/progression.gd — talents, tower progress,
// and roll-pack inventory.

import * as Config from "./config";

export type TalentId = "speed" | "luck" | "multi";

export interface FloorRewards {
  gems: number; gold: number; pack: string;
}

export class ProgressionSystem {
  talents: Record<TalentId, number> = { speed: 0, luck: 0, multi: 0 };
  highestFloor = 0;
  pendingFloor = 1;
  rollPacks: Record<string, number> = {};

  cost(talent: TalentId): number {
    const base = Config.TALENT_BASE_COST[talent];
    return Math.floor(base * Math.pow(Config.TALENT_COST_GROWTH, this.talents[talent]));
  }

  isMaxed(talent: TalentId): boolean {
    return this.talents[talent] >= Config.TALENT_MAX[talent];
  }

  applyUpgrade(talent: TalentId): void {
    this.talents[talent] += 1;
  }

  rollInterval(): number {
    return Math.max(
      Config.ROLL_INTERVAL_MIN,
      Config.ROLL_INTERVAL_BASE - this.talents.speed * Config.ROLL_INTERVAL_PER_LEVEL,
    );
  }

  luckBonus(): number {
    return this.talents.luck * Config.LUCK_PER_LEVEL;
  }

  rollsPerTick(): number {
    return 1 + this.talents.multi;
  }

  talentEffectText(talent: TalentId): string {
    switch (talent) {
      case "speed": return `One roll every ${this.rollInterval().toFixed(1)}s`;
      case "luck":  return `+${Math.round(this.luckBonus() * 100)}% toward rarer pulls`;
      case "multi": return `${this.rollsPerTick()} cards per roll`;
    }
  }

  // ---------------- TOWER ----------------

  isUnlocked(floorNumber: number): boolean {
    return floorNumber <= this.highestFloor + 1;
  }

  isBossFloor(floorNumber: number): boolean {
    return floorNumber % Config.BOSS_EVERY === 0;
  }

  enemyCount(floorNumber: number): number {
    return this.isBossFloor(floorNumber) ? 6 : 5;
  }

  statMultiplier(floorNumber: number): number {
    return 1.0 + (floorNumber - 1) * Config.FLOOR_STAT_SCALE;
  }

  packForFloor(floorNumber: number): string {
    if (floorNumber >= 45) return "boss";
    if (floorNumber >= 20) return "gold";
    return "bronze";
  }

  /** Returns the rewards earned; the caller credits the currency. */
  clearFloor(floorNumber: number): FloorRewards {
    const rewards: FloorRewards = {
      gems: Config.FLOOR_GEM_BASE + floorNumber * Config.FLOOR_GEM_PER,
      gold: Config.FLOOR_GOLD_BASE + floorNumber * Config.FLOOR_GOLD_PER,
      pack: "",
    };

    if (this.isBossFloor(floorNumber)) {
      const pack = this.packForFloor(floorNumber);
      this.rollPacks[pack] = (this.rollPacks[pack] ?? 0) + 1;
      rewards.pack = pack;
    }

    if (floorNumber > this.highestFloor) this.highestFloor = floorNumber;
    return rewards;
  }

  // ---------------- ROLL PACKS ----------------

  packCount(packId: string): number {
    return this.rollPacks[packId] ?? 0;
  }

  consumePack(packId: string): boolean {
    if (this.packCount(packId) <= 0) return false;
    this.rollPacks[packId] -= 1;
    return true;
  }
}
