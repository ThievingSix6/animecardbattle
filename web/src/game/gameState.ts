// Ported from scripts/game_state.gd — a thin coordinator, not a god
// object. Owns the wallet and drives the background auto-roll loop;
// everything else is delegated to a focused system.

import * as Config from "./config";
import type { CardData } from "./cardData";
import { CollectionSystem, TEAM_SIZE } from "./collection";
import { GachaSystem } from "./gacha";
import { ProgressionSystem, type TalentId } from "./progression";
import { WeatherSystem } from "./weather";
import * as CardGenerator from "./cardGenerator";

export type EventName =
  | "currency" | "collection" | "team" | "autoRolled"
  | "toast" | "weather" | "packGranted";

export type EventHandler = (payload?: unknown) => void;

export interface Toast {
  text: string; kind: "info" | "success" | "error";
}

export class GameState {
  collection = new CollectionSystem();
  progression = new ProgressionSystem();
  weather = new WeatherSystem();
  gacha: GachaSystem;

  wallet = { gems: Config.START_GEMS, gold: Config.START_GOLD };
  started = false;

  private listeners = new Map<EventName, EventHandler[]>();
  private rollTimer = 0;

  constructor() {
    this.gacha = new GachaSystem(
      this.collection,
      () => this.effectiveLuck(),
      () => this.weather.boostedElement(),
    );
  }

  // ---------------- EVENTS ----------------

  on(event: EventName, handler: EventHandler): void {
    const list = this.listeners.get(event) ?? [];
    list.push(handler);
    this.listeners.set(event, list);
  }

  off(event: EventName, handler: EventHandler): void {
    const list = this.listeners.get(event);
    if (!list) return;
    const i = list.indexOf(handler);
    if (i >= 0) list.splice(i, 1);
  }

  emit(event: EventName, payload?: unknown): void {
    for (const handler of this.listeners.get(event) ?? []) handler(payload);
  }

  toast(text: string, kind: Toast["kind"] = "info"): void {
    this.emit("toast", { text, kind } satisfies Toast);
  }

  // ---------------- SESSION ----------------

  /** Grants the opening hand and starts the background loop. */
  start(): void {
    if (this.started) return;
    this.started = true;

    const ids: string[] = [];
    for (const template of CardGenerator.buildStarters()) {
      const card = this.collection.add(template);
      if (card && ids.length < TEAM_SIZE) ids.push(card.cardId);
    }
    this.collection.setTeam(ids);

    this.emit("currency");
    this.emit("collection");
    this.emit("team");
  }

  /** Drives the background auto-roll and weather clocks. */
  tick(delta: number): void {
    if (!this.started) return;

    if (this.weather.update(delta)) this.emit("weather");

    this.rollTimer += delta;
    const interval = this.progression.rollInterval();
    if (this.rollTimer < interval) return;

    this.rollTimer -= interval;
    const pulled = this.gacha.pullMany(this.progression.rollsPerTick());
    if (pulled.length === 0) return;

    this.emit("autoRolled", pulled);
    this.emit("collection");
  }

  effectiveLuck(): number {
    return this.progression.luckBonus() * this.weather.luckMultiplier();
  }

  // ---------------- WALLET ----------------

  get gems(): number { return this.wallet.gems; }
  get gold(): number { return this.wallet.gold; }

  spendGems(amount: number): boolean {
    if (this.wallet.gems < amount) return false;
    this.wallet.gems -= amount;
    this.emit("currency");
    return true;
  }

  spendGold(amount: number): boolean {
    if (this.wallet.gold < amount) return false;
    this.wallet.gold -= amount;
    this.emit("currency");
    return true;
  }

  addGems(amount: number): void {
    this.wallet.gems += amount;
    this.emit("currency");
  }

  addGold(amount: number): void {
    this.wallet.gold += amount;
    this.emit("currency");
  }

  // ---------------- ACTIONS ----------------

  summon(count: number, origin = ""): CardData[] {
    const cost = count === 1 ? Config.SUMMON_COST_X1 : Config.SUMMON_COST_X10;
    if (!this.spendGems(cost)) {
      this.toast(`Not enough gems — you need ${cost.toLocaleString()}.`, "error");
      return [];
    }

    const pulled = this.gacha.pullMany(count, origin);
    this.emit("collection");
    return pulled;
  }

  sellCard(cardId: string): number {
    const earned = this.collection.sell(cardId);
    if (earned > 0) {
      this.addGold(earned);
      this.toast(`Sold for ${earned.toLocaleString()} gold.`, "success");
      this.emit("collection");
      this.emit("team");
    }
    return earned;
  }

  mergeCard(cardId: string): boolean {
    if (!this.collection.canMerge(cardId)) return false;
    const card = this.collection.owned.get(cardId)!;
    const newRarity = Config.nextRarity(card.rarity);
    if (this.collection.merge(cardId)) {
      this.toast(`${card.cardName} ascended to ${newRarity}!`, "success");
      this.emit("collection");
      return true;
    }
    return false;
  }

  toggleTeam(cardId: string): void {
    if (!this.collection.toggleTeam(cardId)) {
      this.toast(`Your team is full — ${TEAM_SIZE} cards maximum.`, "error");
      return;
    }
    this.emit("team");
    this.emit("collection");
  }

  getBattleTeam(): CardData[] {
    return this.collection.getTeam();
  }

  upgradeTalent(talent: TalentId): boolean {
    if (this.progression.isMaxed(talent)) return false;
    const cost = this.progression.cost(talent);
    if (!this.spendGold(cost)) {
      this.toast(`Not enough gold — you need ${cost.toLocaleString()}.`, "error");
      return false;
    }
    this.progression.applyUpgrade(talent);
    return true;
  }

  useRollPack(packId: string): Record<string, unknown> | null {
    if (!this.progression.consumePack(packId)) return null;
    const summary = this.gacha.bulk(Config.ROLL_PACKS[packId].rolls);
    this.emit("collection");
    return summary;
  }

  clearFloor(floorNumber: number) {
    const rewards = this.progression.clearFloor(floorNumber);
    this.addGems(rewards.gems);
    this.addGold(rewards.gold);
    if (rewards.pack !== "") this.emit("packGranted", rewards.pack);
    return rewards;
  }
}

export const game = new GameState();
