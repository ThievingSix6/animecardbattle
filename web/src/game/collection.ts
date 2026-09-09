// Ported from scripts/systems/collection.gd — owns the player's cards and
// their team. Knows nothing about rolling, currency sources, or UI.

import * as Config from "./config";
import { cloneCard, type CardData } from "./cardData";

export const TEAM_SIZE = 5;

export const SORTS = [
  { label: "Rarity", key: "rarity" },
  { label: "Attack", key: "attack" },
  { label: "Defense", key: "defense" },
  { label: "Health", key: "health" },
  { label: "Speed", key: "speed" },
  { label: "Copies", key: "copies" },
  { label: "Name (A-Z)", key: "name" },
] as const;

export class CollectionSystem {
  owned = new Map<string, CardData>();
  duplicates = new Map<string, number>();
  teamIds: string[] = [];

  add(template: CardData, copies = 1): CardData | null {
    if (copies <= 0) return null;

    const isNew = !this.owned.has(template.cardId);
    if (isNew) {
      const copy = cloneCard(template);
      this.owned.set(copy.cardId, copy);
      if (copies > 1) this.duplicates.set(copy.cardId, copies - 1);
    } else {
      this.duplicates.set(template.cardId, (this.duplicates.get(template.cardId) ?? 0) + copies);
    }
    return this.owned.get(template.cardId) ?? null;
  }

  getAll(): CardData[] {
    return [...this.owned.values()];
  }

  has(cardId: string): boolean {
    return this.owned.has(cardId);
  }

  copiesOf(cardId: string): number {
    return (this.duplicates.get(cardId) ?? 0) + (this.owned.has(cardId) ? 1 : 0);
  }

  duplicateCount(cardId: string): number {
    return this.duplicates.get(cardId) ?? 0;
  }

  uniqueCount(): number {
    return this.owned.size;
  }

  /**
   * Sells one copy: a duplicate if any exist, otherwise the last copy
   * (which also drops it from the team). Returns gold earned.
   */
  sell(cardId: string): number {
    const card = this.owned.get(cardId);
    if (!card) return 0;

    const value = card.sellValue;
    if ((this.duplicates.get(cardId) ?? 0) > 0) {
      this.duplicates.set(cardId, this.duplicates.get(cardId)! - 1);
    } else {
      this.owned.delete(cardId);
      this.duplicates.delete(cardId);
      this.teamIds = this.teamIds.filter((id) => id !== cardId);
    }
    return value;
  }

  canMerge(cardId: string): boolean {
    const card = this.owned.get(cardId);
    if (!card) return false;
    if (Config.nextRarity(card.rarity) === "") return false;
    return this.copiesOf(cardId) >= Config.MERGE_REQUIREMENT;
  }

  merge(cardId: string): boolean {
    if (!this.canMerge(cardId)) return false;

    const card = this.owned.get(cardId)!;
    this.duplicates.set(cardId, (this.duplicates.get(cardId) ?? 0) - (Config.MERGE_REQUIREMENT - 1));

    card.rarity = Config.nextRarity(card.rarity) as Config.Rarity;
    card.attack = Math.round(card.attack * Config.MERGE_STAT_GROWTH);
    card.defense = Math.round(card.defense * Config.MERGE_STAT_GROWTH);
    card.health = Math.round(card.health * Config.MERGE_STAT_GROWTH);
    card.speed = Math.round(card.speed * Config.MERGE_SPEED_GROWTH);
    card.sellValue = Math.round(card.sellValue * Config.MERGE_SELL_GROWTH);
    return true;
  }

  getTeam(): CardData[] {
    const team: CardData[] = [];
    for (const id of this.teamIds) {
      const card = this.owned.get(id);
      if (card) team.push(card);
    }

    // Fall back to the first few owned cards so battle is never empty.
    if (team.length === 0) {
      return this.getAll().slice(0, TEAM_SIZE);
    }
    return team;
  }

  setTeam(ids: string[]): void {
    this.teamIds = [...ids];
  }

  inTeam(cardId: string): boolean {
    return this.teamIds.includes(cardId);
  }

  toggleTeam(cardId: string): boolean {
    if (this.inTeam(cardId)) {
      this.teamIds = this.teamIds.filter((id) => id !== cardId);
      return true;
    }
    if (this.teamIds.length >= TEAM_SIZE) return false;
    this.teamIds.push(cardId);
    return true;
  }

  sorted(key: string): CardData[] {
    const list = this.getAll();
    switch (key) {
      case "rarity":
        return list.sort((a, b) => {
          const ra = Config.rarityIndex(a.rarity);
          const rb = Config.rarityIndex(b.rarity);
          return ra !== rb ? rb - ra : b.attack - a.attack;
        });
      case "name":
        return list.sort((a, b) => a.cardName.localeCompare(b.cardName, undefined, { numeric: true }));
      case "copies":
        return list.sort((a, b) => this.copiesOf(b.cardId) - this.copiesOf(a.cardId));
      default:
        return list.sort((a, b) => {
          const av = (a as unknown as Record<string, number>)[key] ?? 0;
          const bv = (b as unknown as Record<string, number>)[key] ?? 0;
          return bv - av;
        });
    }
  }
}
