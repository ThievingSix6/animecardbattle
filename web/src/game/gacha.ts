// Ported from scripts/systems/gacha.gd — owns the card pool and every
// form of rolling: single pulls, banner-filtered pulls, and statistically
// simulated bulk rolls.

import * as Config from "./config";
import type { Rarity } from "./config";
import type { CardData } from "./cardData";
import type { CollectionSystem } from "./collection";
import * as CardGenerator from "./cardGenerator";
import * as Mutations from "./mutations";
import { rng } from "./rng";

export interface BulkSummary {
  [rarity: string]: { rolls: number; newUnique: number; copies: number; poolSize: number };
}

export class GachaSystem {
  pool = new Map<string, CardData[]>();
  bossPoolUnlocked = false;

  constructor(
    private collection: CollectionSystem,
    private luckProvider: () => number,
    private elementBoostProvider: () => string,
  ) {
    this.buildPool();
  }

  private buildPool(): void {
    for (const r of Config.RARITY_ORDER) this.pool.set(r, []);

    // The starting roster is always pullable, so duplicates of it can be
    // merged like any other card.
    for (const template of CardGenerator.buildStarters()) {
      this.addToPool(template);
    }

    // In the Godot project cards derived from the player's own artwork are
    // added here; the browser prototype ships no art, so the roster is
    // filled entirely by the procedural generator.
    this.generate(Config.GENERATED_CARD_COUNT);
  }

  private addToPool(card: CardData): void {
    const bucket = this.pool.get(card.rarity);
    if (bucket) bucket.push(card);
    else this.pool.set(card.rarity, [card]);
  }

  private generate(count: number): void {
    const used = new Set(this.allTemplates().map((t) => t.cardName));
    for (const card of CardGenerator.generateBatch(count, used)) {
      this.addToPool(card);
    }
  }

  allTemplates(): CardData[] {
    return [...this.pool.values()].flat();
  }

  totalPoolSize(): number {
    return this.allTemplates().length;
  }

  unlockBossPool(): void {
    this.bossPoolUnlocked = true;
    for (const card of this.allTemplates()) {
      if (card.originTag === "boss") card.locked = false;
    }
  }

  // ---------------- ODDS ----------------

  rollRarity(luck = 0): Rarity {
    let total = 0;
    const weights = Config.RARITY_ORDER.map((r) => {
      const w = r === "Common" ? Config.RARITY_WEIGHTS[r] : Config.RARITY_WEIGHTS[r] * (1 + luck);
      total += w;
      return w;
    });

    let roll = rng.randf() * total;
    for (let i = 0; i < Config.RARITY_ORDER.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return Config.RARITY_ORDER[i];
    }
    return "Common";
  }

  /**
   * Probability of pulling this exact card — its rarity band, divided by
   * how many cards share that band, times its mutation's chance.
   */
  cardOdds(card: CardData): number {
    const total = Object.values(Config.RARITY_WEIGHTS).reduce((a, b) => a + b, 0);
    const bucket = this.candidates(card.rarity, "");
    if (bucket.length === 0 || total <= 0) return 0;

    const base = (Config.RARITY_WEIGHTS[card.rarity] / total) * (1 / bucket.length);
    return base * Mutations.chanceOf(card.modifier);
  }

  // ---------------- CANDIDATE SELECTION ----------------

  candidates(rarity: string, origin: string): CardData[] {
    return (this.pool.get(rarity) ?? []).filter(
      (c) => !c.locked && (origin === "" || c.originTag === origin),
    );
  }

  /** Applies the active weather element boost by repeating matching cards. */
  weightedCandidates(rarity: string, origin: string): CardData[] {
    const base = this.candidates(rarity, origin);
    const boost = this.elementBoostProvider();
    if (base.length === 0 || boost === "") return base;

    const weighted: CardData[] = [];
    for (const c of base) {
      weighted.push(c);
      if (c.element === boost) {
        for (let i = 0; i < Config.EVENT_ELEMENT_WEIGHT - 1; i++) weighted.push(c);
      }
    }
    return weighted;
  }

  // ---------------- PULLING ----------------

  pull(origin = ""): CardData | null {
    const rarity = this.rollRarity(this.luckProvider());

    // Degrade gracefully: banner -> unfiltered -> Common.
    let options = this.weightedCandidates(rarity, origin);
    if (options.length === 0) options = this.weightedCandidates(rarity, "");
    if (options.length === 0) options = this.weightedCandidates("Common", "");
    if (options.length === 0) return null;

    const template = options[rng.randi(options.length)];
    const mutationId = Mutations.roll(this.luckProvider());
    return this.collection.add(Mutations.apply(template, mutationId));
  }

  pullMany(count: number, origin = ""): CardData[] {
    const results: CardData[] = [];
    for (let i = 0; i < count; i++) {
      const card = this.pull(origin);
      if (card) results.push(card);
    }
    return results;
  }

  // ---------------- BULK ROLLING ----------------

  /**
   * Resolves millions of rolls without looping. For each card we compute
   * the expected number of hits and sample it; large expectations converge
   * to their mean, small ones use a Poisson draw so rare cards still feel
   * genuinely random.
   */
  bulk(totalRolls: number, origin = ""): BulkSummary {
    const totalWeight = Object.values(Config.RARITY_WEIGHTS).reduce((a, b) => a + b, 0);
    const luck = this.luckProvider();
    const summary: BulkSummary = {};

    for (const rarity of Config.RARITY_ORDER) {
      let bucket = this.candidates(rarity, origin);
      if (bucket.length === 0) bucket = this.candidates(rarity, "");
      if (bucket.length === 0) continue;

      const weight = Config.RARITY_WEIGHTS[rarity];
      const luckMult = rarity === "Common" ? 1.0 : 1.0 + luck;
      const rollsHere = totalRolls * ((weight * luckMult) / totalWeight);
      const perCard = rollsHere / bucket.length;

      let newUnique = 0;
      let copiesTotal = 0;

      for (const template of bucket) {
        let copies = perCard >= 8.0 ? Math.round(perCard) : poisson(perCard);
        if (copies <= 0) continue;

        // Split copies across mutation tiers by their real odds so a huge
        // bulk roll can genuinely surface a Prismatic or Celestial.
        for (const mutationId of Mutations.allIds()) {
          const share = Mutations.chanceOf(mutationId);
          let mutatedCopies = Math.round(copies * share);
          if (mutatedCopies <= 0 && share * copies > 0) {
            mutatedCopies = poisson(share * copies);
          }
          if (mutatedCopies <= 0) continue;

          const variant = Mutations.apply(template, mutationId);
          if (!this.collection.has(variant.cardId)) newUnique++;
          this.collection.add(variant, mutatedCopies);
          copiesTotal += mutatedCopies;
        }
      }

      summary[rarity] = {
        rolls: Math.round(rollsHere),
        newUnique,
        copies: copiesTotal,
        poolSize: bucket.length,
      };
    }

    return summary;
  }
}

function poisson(lambda: number): number {
  if (lambda <= 0) return 0;
  // Large lambda would underflow exp(-lambda); the caller already rounds
  // those to the mean, but guard anyway.
  if (lambda > 30) return Math.round(lambda);

  const l = Math.exp(-lambda);
  let k = 0;
  let p = 1.0;
  do {
    k++;
    p *= rng.randf();
  } while (p > l);
  return k - 1;
}
