// The battle rules engine. Runs a lane duel: only the front card on each
// side fights; when one falls the next steps up. Emits events describing
// what happened so a view can animate them.
//
// Contains zero UI code, which keeps the combat rules testable and lets
// the presentation change without touching balance.
//
// Skills hook into the flow at named points (entry, turn start, outgoing
// and incoming damage, kills, deaths). The engine owns sequencing and the
// skill library owns behaviour, so a new passive is a new entry in
// skills.ts and no change here.

import * as Config from "./config";
import { makeCard, type CardData } from "./cardData";
import { Combatant, type Side } from "./combatant";
import { rng } from "./rng";
import { skillById, type SkillApi, type SkillCtx, type SkillHooks } from "./skills";

export { Combatant } from "./combatant";
export type { Side } from "./combatant";

export type BattleEvent =
  | { type: "attack"; attacker: Combatant; target: Combatant; damage: number }
  | { type: "ability"; user: Combatant; ability: string; targets: Combatant[]; damage: number; kind: "basic" | "ultimate" }
  | { type: "skill"; source: Combatant; skill: string; note: string; amount: number }
  | { type: "healed"; target: Combatant; amount: number }
  | { type: "died"; who: Combatant }
  | { type: "summoned"; owner: Combatant; who: Combatant }
  | { type: "actives"; playerIndex: number; enemyIndex: number }
  | { type: "ended"; playerWon: boolean };

export type BattleListener = (event: BattleEvent) => void;

export function computeDamage(attack: number, defense: number): number {
  return Math.max(1, attack - Math.floor(defense * Config.DEFENSE_FACTOR));
}

type HookName = keyof SkillHooks;

export class BattleSim {
  players: Combatant[] = [];
  enemies: Combatant[] = [];
  playerIndex = 0;
  enemyIndex = 0;
  running = false;
  turn = 0;

  private listeners: BattleListener[] = [];
  private entered = new Set<string>();

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
    this.turn = 0;
    this.entered.clear();
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

  // --- skill plumbing ---------------------------------------------------

  private api: SkillApi = {
    turn: 0,
    random: () => rng.randf(),
    allies: (of) => this.team(of.side),
    enemies: (of) => this.opposing(of.side),
    activeEnemy: (of) => {
      const list = this.opposing(of.side);
      const idx = this.advance(list, 0);
      return idx === -1 ? null : list[idx];
    },
    lowestHpAlly: (of, includeSelf = true) => {
      const pool = this.team(of.side).filter((a) => a.alive && (includeSelf || a.id !== of.id));
      if (pool.length === 0) return null;
      return pool.reduce((a, b) => (a.hpRatio() <= b.hpRatio() ? a : b));
    },
    strongestAlly: (of, includeSelf = true) => {
      const pool = this.team(of.side).filter((a) => a.alive && (includeSelf || a.id !== of.id));
      if (pool.length === 0) return null;
      return pool.reduce((a, b) => (a.attack >= b.attack ? a : b));
    },
    nextAlly: (of) => {
      const list = this.team(of.side);
      for (let i = of.index + 1; i < list.length; i++) if (list[i].alive) return list[i];
      return null;
    },
    note: (source, text, amount = 0) => {
      const skill = skillById(source.data.skillId);
      this.emit({ type: "skill", source, skill: skill?.name ?? "Passive", note: text, amount });
    },
    summon: (owner, name, statPct, lifespan, count) => this.doSummon(owner, name, statPct, lifespan, count),
    damage: (source, target, amount, label) => this.directDamage(source, target, amount, label),
  };

  private newCtx(self: Combatant, patch: Partial<SkillCtx> = {}): SkillCtx {
    this.api.turn = this.turn;
    return { self, api: this.api, damage: 0, blocked: false, prevented: false, ...patch };
  }

  /** Runs one hook for one combatant and returns the (possibly edited) ctx. */
  private fire(hook: HookName, self: Combatant, patch: Partial<SkillCtx> = {}): SkillCtx {
    const ctx = this.newCtx(self, patch);
    if (!self.alive && hook !== "death") return ctx;

    const skill = skillById(self.data.skillId);
    const fn = skill?.hooks[hook];
    if (fn) fn(ctx);
    return ctx;
  }

  private fireTeam(hook: HookName, list: Combatant[], patch: Partial<SkillCtx> = {}): void {
    for (const c of [...list]) {
      if (!c.alive) continue;
      this.fire(hook, c, patch);
    }
  }

  // --- round loop -------------------------------------------------------

  /**
   * Advances the lanes and reports who acts, in order. The view drives the
   * actual turns so it can pace them; the rules stay in here.
   */
  prepareRound(): Side[] {
    if (!this.running) return [];

    this.turn++;
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

    const player = this.players[this.playerIndex];
    const enemy = this.enemies[this.enemyIndex];

    // Entry hooks fire once, the first time a card reaches the front.
    for (const c of [player, enemy]) {
      if (this.entered.has(c.id)) continue;
      this.entered.add(c.id);
      this.fire("entry", c);
    }

    this.upkeep();
    if (!this.checkEnd()) return [];

    this.emit({ type: "actives", playerIndex: this.playerIndex, enemyIndex: this.enemyIndex });

    const playerFirst = player.speed >= enemy.speed;
    return playerFirst ? ["player", "enemy"] : ["enemy", "player"];
  }

  /** Damage over time, buff expiry, summon lifespans, per-turn skills. */
  private upkeep(): void {
    for (const c of [...this.players, ...this.enemies]) {
      if (!c.alive) continue;

      const dot = c.tickDurations();
      if (dot > 0) {
        const died = c.takeDamage(dot);
        this.emit({ type: "skill", source: c, skill: "Damage over time", note: `${c.data.cardName} suffers ${dot} from lingering wounds`, amount: dot });
        if (died) this.onDeath(c, undefined);
      }

      if (c.summoned && c.alive) {
        if (c.bump("lifespan", -1) <= 0) {
          c.alive = false;
          this.emit({ type: "died", who: c });
        }
      }
    }

    this.fireTeam("turnStart", this.players);
    this.fireTeam("turnStart", this.enemies);
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

    if (attacker.stunTurns > 0) {
      this.emit({ type: "skill", source: attacker, skill: "Stunned", note: `${attacker.data.cardName} is stunned and loses the turn`, amount: 0 });
      return;
    }

    this.strike(attacker, target, computeDamage(attacker.attack, target.defense), "basic");

    attacker.attackCount += 1;
    attacker.gainEnergy(Config.ENERGY_PER_ATTACK, Config.ENERGY_MAX);

    if (!this.checkEnd()) return;

    // Basic ability on a cadence.
    if (attacker.attackCount >= Config.BASIC_ABILITY_EVERY && attacker.silenceTurns <= 0) {
      attacker.attackCount = 0;
      this.useAbility(attacker, defenders, false);
      if (!this.checkEnd()) return;
    }

    // Ultimate at full energy.
    if (attacker.alive && attacker.energy >= Config.ENERGY_MAX && attacker.silenceTurns <= 0) {
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

    const base = Math.floor(user.attack * multiplier);
    const struck: Combatant[] = [];
    for (const t of targets) {
      if (this.strike(user, t, base, "ability")) struck.push(t);
    }

    if (struck.length > 0) {
      this.emit({
        type: "ability", user, ability: abilityName, targets: struck,
        damage: base, kind: ultimate ? "ultimate" : "basic",
      });
    }
  }

  resolveTargets(defenders: Combatant[], mode: string): Combatant[] {
    switch (mode) {
      case "aoe":
        return defenders.filter((d) => d.isTargetable());
      case "backline": {
        for (let i = defenders.length - 1; i >= 0; i--) {
          if (defenders[i].isTargetable()) return [defenders[i]];
        }
        return [];
      }
      default: {
        const idx = defenders.findIndex((d) => d.isTargetable());
        return idx === -1 ? [] : [defenders[idx]];
      }
    }
  }

  // --- damage pipeline ---------------------------------------------------

  /**
   * One hit, start to finish: outgoing skills, incoming skills, lethal
   * cancellation, lifesteal, and the follow-up hooks. Returns false when
   * the hit was blocked or the target could not be touched.
   */
  private strike(attacker: Combatant, target: Combatant, baseDamage: number, kind: "basic" | "ability"): boolean {
    if (!target.isTargetable()) return false;

    const out = this.fire("outgoing", attacker, { target, damage: baseDamage });
    let damage = Math.max(1, Math.round(out.damage * (1 + attacker.modifier("damageDealt"))));

    const inc = this.fire("incoming", target, { attacker, damage });
    if (inc.blocked) {
      this.emit({ type: "skill", source: target, skill: "Blocked", note: `${target.data.cardName} blocks ${attacker.data.cardName}`, amount: 0 });
      return false;
    }
    damage = Math.max(1, inc.damage);

    const wouldKill = damage >= target.hp + target.shield;
    if (wouldKill) {
      const save = this.fire("lethal", target, { attacker, damage });
      if (save.prevented) {
        if (kind === "basic") this.emit({ type: "attack", attacker, target, damage: target.hp });
        this.afterHit(attacker, target, damage);
        return true;
      }
    }

    const died = target.takeDamage(damage);
    if (kind === "basic") this.emit({ type: "attack", attacker, target, damage });

    this.afterHit(attacker, target, damage);
    if (died) this.onDeath(target, attacker);
    return true;
  }

  private afterHit(attacker: Combatant, target: Combatant, damage: number): void {
    const steal = attacker.modifier("lifesteal");
    if (steal > 0 && attacker.alive) {
      const healed = attacker.heal(Math.floor(damage * steal));
      if (healed > 0) this.emit({ type: "healed", target: attacker, amount: healed });
    }

    this.fire("dealt", attacker, { target, damage });
    this.fire("taken", target, { attacker, damage });
  }

  /** Damage from a skill rather than an attack — skips the attack hooks. */
  private directDamage(source: Combatant, target: Combatant, amount: number, label: string): void {
    if (!target.alive || amount <= 0) return;
    const died = target.takeDamage(amount);
    this.emit({ type: "skill", source, skill: label, note: `${label}: ${target.data.cardName} takes ${amount}`, amount });
    if (died) this.onDeath(target, source);
  }

  private onDeath(who: Combatant, killer: Combatant | undefined): void {
    this.emit({ type: "died", who });
    this.fire("death", who, { attacker: killer });

    for (const ally of this.team(who.side)) {
      if (ally.alive && ally.id !== who.id) this.fire("allyDeath", ally, { other: who });
    }

    if (killer && killer.alive) this.fire("kill", killer, { other: who });
  }

  // --- summons ------------------------------------------------------------

  private doSummon(owner: Combatant, name: string, statPct: number, lifespan: number, count: number): void {
    const list = this.team(owner.side);
    const bonus = 1 + Math.min(0.3, owner.count("souls") * 0.1);

    for (let i = 0; i < count; i++) {
      const card = makeCard({
        cardId: `${owner.data.cardId}~summon${list.length}`,
        cardName: name,
        role: owner.data.role,
        rarity: owner.data.rarity,
        element: owner.data.element,
        originTag: "summon",
        basicAbility: "Strike",
        ultimateAbility: "Strike",
        attack: Math.max(1, Math.round(owner.data.attack * statPct * bonus)),
        defense: Math.max(0, Math.round(owner.data.defense * statPct * bonus)),
        health: Math.max(1, Math.round(owner.data.health * statPct * bonus)),
        speed: owner.data.speed,
      });

      const minion = new Combatant(card, owner.side, list.length);
      minion.summoned = true;
      minion.counters["lifespan"] = lifespan;
      list.push(minion);
      this.emit({ type: "summoned", owner, who: minion });
    }
  }

  // --- end ---------------------------------------------------------------

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
