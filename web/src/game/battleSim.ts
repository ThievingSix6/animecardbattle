// Ported from scripts/battle/battle_sim.gd + combatant.gd
//
// The battle rules engine. Runs a lane duel: only the front card on each
// side fights; when one falls the next steps up. Emits events describing
// what happened so a view can animate them.
//
// Contains zero UI code, which keeps the combat rules testable and lets
// the presentation change without touching balance.

import * as Config from "./config";
import type { CardData } from "./cardData";
import { rng } from "./rng";

export type Side = "player" | "enemy";

export class Combatant {
  hp: number;
  maxHp: number;
  energy = 0;
  attackCount = 0;
  alive = true;

  constructor(
    readonly data: CardData,
    readonly side: Side,
    readonly index: number,
  ) {
    this.maxHp = data.health;
    this.hp = data.health;
  }

  /** Returns true when this hit was the killing blow. */
  takeDamage(amount: number): boolean {
    this.hp = Math.max(0, this.hp - amount);
    if (this.hp === 0 && this.alive) {
      this.alive = false;
      return true;
    }
    return false;
  }

  heal(amount: number): number {
    const before = this.hp;
    this.hp = Math.min(this.maxHp, this.hp + amount);
    return this.hp - before;
  }

  gainEnergy(amount: number): void {
    this.energy = Math.min(Config.ENERGY_MAX, this.energy + amount);
  }

  hpRatio(): number {
    return this.hp / Math.max(1, this.maxHp);
  }
}

export type BattleEvent =
  | { type: "attack"; attacker: Combatant; target: Combatant; damage: number }
  | { type: "ability"; user: Combatant; ability: string; targets: Combatant[]; damage: number; kind: "basic" | "ultimate" }
  | { type: "passive"; source: Combatant; amount: number; note: string }
  | { type: "healed"; target: Combatant; amount: number }
  | { type: "died"; who: Combatant }
  | { type: "actives"; playerIndex: number; enemyIndex: number }
  | { type: "ended"; playerWon: boolean };

export type BattleListener = (event: BattleEvent) => void;

export function computeDamage(attack: number, defense: number): number {
  return Math.max(1, attack - Math.floor(defense * Config.DEFENSE_FACTOR));
}

export class BattleSim {
  players: Combatant[] = [];
  enemies: Combatant[] = [];
  playerIndex = 0;
  enemyIndex = 0;
  running = false;

  private listeners: BattleListener[] = [];

  on(listener: BattleListener): void {
    this.listeners.push(listener);
  }

  private emit(event: BattleEvent): void {
    for (const listener of this.listeners) listener(event);
  }

  setup(playerCards: CardData[], enemyCards: CardData[]): void {
    this.players = playerCards.map((c, i) => new Combatant(c, "player", i));
    this.enemies = enemyCards.map((c, i) => new Combatant(c, "enemy", i));
    this.playerIndex = 0;
    this.enemyIndex = 0;
    this.running = true;
  }

  team(side: Side): Combatant[] {
    return side === "player" ? this.players : this.enemies;
  }

  opposing(side: Side): Combatant[] {
    return side === "player" ? this.enemies : this.players;
  }

  activeIndex(side: Side): number {
    return side === "player" ? this.playerIndex : this.enemyIndex;
  }

  setActiveIndex(side: Side, value: number): void {
    if (side === "player") this.playerIndex = value;
    else this.enemyIndex = value;
  }

  /** Lanes only advance forward — a fallen card is replaced permanently. */
  advance(list: Combatant[], from: number): number {
    for (let i = Math.max(0, from); i < list.length; i++) {
      if (list[i].alive) return i;
    }
    return -1;
  }

  anyAlive(list: Combatant[]): boolean {
    return list.some((c) => c.alive);
  }

  /**
   * Advances the lanes and reports who acts, in order. The view drives the
   * actual turns so it can pace them; the rules stay in here.
   */
  prepareRound(): Side[] {
    if (!this.running) return [];

    this.playerIndex = this.advance(this.players, this.playerIndex);
    this.enemyIndex = this.advance(this.enemies, this.enemyIndex);

    if (this.playerIndex === -1) {
      this.finish(false);
      return [];
    }
    if (this.enemyIndex === -1) {
      this.finish(true);
      return [];
    }

    this.emit({ type: "actives", playerIndex: this.playerIndex, enemyIndex: this.enemyIndex });

    const playerFirst =
      this.players[this.playerIndex].data.speed >= this.enemies[this.enemyIndex].data.speed;
    return playerFirst ? ["player", "enemy"] : ["enemy", "player"];
  }

  takeTurn(side: Side): void {
    if (!this.running) return;

    const attackers = this.team(side);
    const defenders = this.opposing(side);

    const attackerIdx = this.advance(attackers, this.activeIndex(side));
    this.setActiveIndex(side, attackerIdx);
    if (attackerIdx === -1) return;

    const defenderSide: Side = side === "player" ? "enemy" : "player";
    const defenderIdx = this.advance(defenders, this.activeIndex(defenderSide));
    this.setActiveIndex(defenderSide, defenderIdx);
    if (defenderIdx === -1) return;

    const attacker = attackers[attackerIdx];
    const target = defenders[defenderIdx];

    // Basic attack, unless a guardian intercepts it.
    if (!this.tryGuardian(defenders, target)) {
      const damage = computeDamage(attacker.data.attack, target.data.defense);
      this.deal(attacker, target, damage);
      this.emit({ type: "attack", attacker, target, damage });
    }

    attacker.attackCount++;
    let energy = Config.ENERGY_PER_ATTACK;
    if (attacker.data.passiveType === "energy_surge") {
      energy += Math.floor(attacker.data.passiveValue);
    }
    attacker.gainEnergy(energy);

    if (!this.checkEnd()) return;

    // Basic ability on a cadence.
    if (attacker.attackCount >= Config.BASIC_ABILITY_EVERY) {
      attacker.attackCount = 0;
      this.useAbility(attacker, defenders, false);
      if (!this.checkEnd()) return;
    }

    // Ultimate at full energy.
    if (attacker.alive && attacker.energy >= Config.ENERGY_MAX) {
      attacker.energy = 0;
      this.useAbility(attacker, defenders, true);
      this.checkEnd();
    }
  }

  private useAbility(user: Combatant, defenders: Combatant[], ultimate: boolean): void {
    const mode = ultimate ? user.data.ultimateTargetMode : user.data.basicTargetMode;
    const abilityName = ultimate ? user.data.ultimateAbility : user.data.basicAbility;
    const multiplier = ultimate ? Config.ULTIMATE_MULT : Config.BASIC_ABILITY_MULT;

    const targets = this.resolveTargets(defenders, mode);
    if (targets.length === 0) return;

    const damage = Math.floor(user.data.attack * multiplier);
    const struck: Combatant[] = [];
    for (const t of targets) {
      if (this.tryGuardian(defenders, t)) continue;
      this.deal(user, t, damage);
      struck.push(t);
    }

    if (struck.length > 0) {
      this.emit({
        type: "ability", user, ability: abilityName, targets: struck,
        damage, kind: ultimate ? "ultimate" : "basic",
      });
    }
  }

  resolveTargets(defenders: Combatant[], mode: string): Combatant[] {
    switch (mode) {
      case "aoe":
        return defenders.filter((d) => d.alive);
      case "backline": {
        for (let i = defenders.length - 1; i >= 0; i--) {
          if (defenders[i].alive) return [defenders[i]];
        }
        return [];
      }
      default: {
        const idx = this.advance(defenders, 0);
        return idx !== -1 ? [defenders[idx]] : [];
      }
    }
  }

  private deal(attacker: Combatant, target: Combatant, damage: number): void {
    const died = target.takeDamage(damage);

    if (attacker.data.passiveType === "lifesteal" && attacker.alive) {
      const healedAmount = attacker.heal(Math.floor(damage * attacker.data.passiveValue));
      if (healedAmount > 0) {
        this.emit({ type: "healed", target: attacker, amount: healedAmount });
      }
    }

    if (died) this.emit({ type: "died", who: target });
  }

  /** A living, non-active ally may intercept an incoming hit entirely. */
  private tryGuardian(defenders: Combatant[], target: Combatant): boolean {
    for (const guardian of defenders) {
      if (!guardian.alive || guardian === target) continue;
      if (guardian.data.passiveType !== "guardian_block_heal") continue;
      if (rng.randf() > guardian.data.passiveChance) continue;

      const amount = guardian.heal(Math.floor(guardian.maxHp * guardian.data.passiveValue));
      this.emit({
        type: "passive", source: guardian, amount,
        note: `${guardian.data.cardName} intercepts the blow aimed at ${target.data.cardName}`,
      });
      return true;
    }
    return false;
  }

  private checkEnd(): boolean {
    if (!this.running) return false;
    if (!this.anyAlive(this.players)) {
      this.finish(false);
      return false;
    }
    if (!this.anyAlive(this.enemies)) {
      this.finish(true);
      return false;
    }
    return true;
  }

  private finish(playerWon: boolean): void {
    if (!this.running) return;
    this.running = false;
    this.emit({ type: "ended", playerWon });
  }
}
