// One fighter's runtime state.
//
// TURNS, NOT SECONDS. The skill designs are written in real time ("for 4
// seconds", "every 10 seconds") but combat resolves in discrete turns, so
// every duration is converted on the way in: TURNS_PER_SECOND below is the
// single place that conversion lives. Two seconds of real time is one turn.

import type { CardData } from "./cardData";

export const SECONDS_PER_TURN = 2;

/** Converts a real-time duration from a skill design into whole turns. */
export function turns(seconds: number): number {
  return Math.max(1, Math.round(seconds / SECONDS_PER_TURN));
}

export type BuffStat =
  | "attack" | "defense" | "speed" | "energyRate"
  | "damageDealt" | "damageTaken" | "healingReceived" | "lifesteal"
  | "armorPen" | "blockChance";

export interface Buff {
  stat: BuffStat;
  /** Fractional modifier: 0.2 means +20%. */
  amount: number;
  /** Remaining turns; Infinity lasts the whole battle. */
  turns: number;
  /** Optional key used to cap how many times a buff can stack. */
  key?: string;
}

export type DotKind = "burn" | "bleed" | "poison";

export interface Dot {
  kind: DotKind;
  turns: number;
  perTurn: number;
  sourceId: string;
}

export type Side = "player" | "enemy";

export class Combatant {
  hp: number;
  maxHp: number;
  energy = 0;
  attackCount = 0;
  alive = true;

  /** Absorbs damage before HP does. */
  shield = 0;

  buffs: Buff[] = [];
  dots: Dot[] = [];

  stunTurns = 0;
  silenceTurns = 0;
  untargetableTurns = 0;

  /** Arbitrary named tallies used by skills (blocks landed, hits taken...). */
  counters: Record<string, number> = {};

  /** Skill ids that have already spent their one-per-battle trigger. */
  spent = new Set<string>();

  /** Ids of combatants this fighter has marked. */
  marked = new Set<string>();

  /** True for temporary bodies created by summon skills. */
  summoned = false;

  constructor(
    readonly data: CardData,
    readonly side: Side,
    public index: number,
  ) {
    this.maxHp = data.health;
    this.hp = data.health;
  }

  get id(): string {
    return `${this.side}:${this.index}:${this.data.cardId}`;
  }

  // --- modifiers ------------------------------------------------------

  private sum(stat: BuffStat): number {
    let total = 0;
    for (const b of this.buffs) if (b.stat === stat) total += b.amount;
    return total;
  }

  modifier(stat: BuffStat): number {
    return this.sum(stat);
  }

  get attack(): number {
    return Math.max(1, Math.round(this.data.attack * (1 + this.sum("attack"))));
  }

  get defense(): number {
    return Math.max(0, Math.round(this.data.defense * (1 + this.sum("defense"))));
  }

  get speed(): number {
    return Math.max(1, Math.round(this.data.speed * (1 + this.sum("speed"))));
  }

  /** Energy gained per attack scales with the "attack speed" analogue. */
  get energyRate(): number {
    return Math.max(0.1, 1 + this.sum("energyRate"));
  }

  addBuff(buff: Buff, maxStacks = Infinity): void {
    if (buff.key !== undefined) {
      const existing = this.buffs.filter((b) => b.key === buff.key);
      if (existing.length >= maxStacks) {
        // Refresh the oldest rather than exceeding the cap.
        existing[0].turns = buff.turns;
        return;
      }
    }
    this.buffs.push({ ...buff });
  }

  hasBuff(key: string): boolean {
    return this.buffs.some((b) => b.key === key);
  }

  bump(counter: string, by = 1): number {
    this.counters[counter] = (this.counters[counter] ?? 0) + by;
    return this.counters[counter];
  }

  count(counter: string): number {
    return this.counters[counter] ?? 0;
  }

  /** Returns true the first time a given once-per-battle key is claimed. */
  claim(key: string): boolean {
    if (this.spent.has(key)) return false;
    this.spent.add(key);
    return true;
  }

  // --- damage ----------------------------------------------------------

  /** Applies damage through the shield. Returns true if this was lethal. */
  takeDamage(amount: number): boolean {
    let remaining = Math.max(0, Math.round(amount * (1 + this.modifier("damageTaken"))));

    if (this.shield > 0) {
      const absorbed = Math.min(this.shield, remaining);
      this.shield -= absorbed;
      remaining -= absorbed;
    }

    this.hp = Math.max(0, this.hp - remaining);
    if (this.hp === 0 && this.alive) {
      this.alive = false;
      return true;
    }
    return false;
  }

  heal(amount: number): number {
    if (!this.alive) return 0;
    const scaled = Math.round(amount * (1 + this.modifier("healingReceived")));
    const before = this.hp;
    this.hp = Math.min(this.maxHp, this.hp + scaled);
    return this.hp - before;
  }

  addShield(amount: number): number {
    const gain = Math.max(0, Math.round(amount));
    this.shield += gain;
    return gain;
  }

  gainEnergy(amount: number, max: number): void {
    this.energy = Math.min(max, this.energy + Math.round(amount * this.energyRate));
  }

  hpRatio(): number {
    return this.hp / Math.max(1, this.maxHp);
  }

  isTargetable(): boolean {
    return this.alive && this.untargetableTurns <= 0;
  }

  // --- per-turn upkeep ---------------------------------------------------

  /** Expires buffs and statuses. Returns damage owed by damage-over-time. */
  tickDurations(): number {
    for (const b of this.buffs) b.turns -= 1;
    this.buffs = this.buffs.filter((b) => b.turns > 0);

    let dotDamage = 0;
    for (const d of this.dots) {
      dotDamage += d.perTurn;
      d.turns -= 1;
    }
    this.dots = this.dots.filter((d) => d.turns > 0);

    if (this.stunTurns > 0) this.stunTurns -= 1;
    if (this.silenceTurns > 0) this.silenceTurns -= 1;
    if (this.untargetableTurns > 0) this.untargetableTurns -= 1;

    return Math.round(dotDamage);
  }

  hasDot(kind: DotKind): boolean {
    return this.dots.some((d) => d.kind === kind);
  }

  applyDot(dot: Dot): void {
    this.dots.push({ ...dot });
  }
}
