// THE SKILL LIBRARY — 100 passives across nine effect families.
//
// ---------------------------------------------------------------------
// TRANSLATION NOTES
//
// The designs are written for a real-time auto-battler; combat here
// resolves in discrete turns. Rather than rewrite the engine (every
// balance number in config assumes turns), each real-time concept maps
// onto its turn-based equivalent:
//
//   "N seconds"      -> turns(N), i.e. one turn per two seconds
//   "attack speed"   -> energyRate, how fast the ultimate charges
//   "movement speed" -> speed, which decides turn order
//   "armor"          -> defense
//   "ability charge" -> energy
//   "nearby enemies" -> every living enemy
//   "adjacent ally"  -> the next living ally in the lane
//   "displacement"   -> not modelled; those skills grant the closest
//                       equivalent (stun resistance) instead
//
// Every description below states what the simulation actually does, in
// turns. If a skill's behaviour changes, its text has to change with it.
// ---------------------------------------------------------------------

import { turns, type Combatant } from "./combatant";

export type SkillFamily =
  | "defense" | "offense" | "element" | "death" | "summon"
  | "support" | "control" | "risk" | "legendary";

export const FAMILY_LABEL: Record<SkillFamily, string> = {
  defense: "Defense", offense: "Offense", element: "Element", death: "Death",
  summon: "Summon", support: "Support", control: "Control", risk: "Risk",
  legendary: "Legendary",
};

export const FAMILY_ICON: Record<SkillFamily, string> = {
  defense: "🛡", offense: "⚔", element: "🔥", death: "☠", summon: "👹",
  support: "❤", control: "🧠", risk: "🩸", legendary: "👑",
};

export const FAMILY_COLOR: Record<SkillFamily, string> = {
  defense: "#3ecf7e", offense: "#ef4444", element: "#e0532c", death: "#7a4ae0",
  summon: "#8a6a42", support: "#3b82f6", control: "#3ac9a6", risk: "#f5c518",
  legendary: "#ff2d95",
};

export interface SkillApi {
  turn: number;
  random(): number;
  allies(of: Combatant): Combatant[];
  enemies(of: Combatant): Combatant[];
  activeEnemy(of: Combatant): Combatant | null;
  lowestHpAlly(of: Combatant, includeSelf?: boolean): Combatant | null;
  strongestAlly(of: Combatant, includeSelf?: boolean): Combatant | null;
  nextAlly(of: Combatant): Combatant | null;
  note(source: Combatant, text: string, amount?: number): void;
  summon(owner: Combatant, name: string, statPct: number, lifespan: number, count: number): void;
  damage(source: Combatant, target: Combatant, amount: number, label: string): void;
}

export interface SkillCtx {
  self: Combatant;
  api: SkillApi;
  /** The card being attacked (on outgoing hooks). */
  target?: Combatant;
  /** The card doing the attacking (on incoming hooks). */
  attacker?: Combatant;
  /** The ally or enemy the event concerns. */
  other?: Combatant;
  /** Mutable damage for this event. */
  damage: number;
  /** Set true to negate the hit entirely. */
  blocked: boolean;
  /** Set true to cancel a lethal blow. */
  prevented: boolean;
}

export interface SkillHooks {
  /** The card becomes the active fighter. */
  entry?(c: SkillCtx): void;
  /** Start of this card's turn. */
  turnStart?(c: SkillCtx): void;
  /** About to deal damage — may modify c.damage. */
  outgoing?(c: SkillCtx): void;
  /** About to receive damage — may modify c.damage or set c.blocked. */
  incoming?(c: SkillCtx): void;
  /** Damage has landed on c.target. */
  dealt?(c: SkillCtx): void;
  /** Damage has landed on this card. */
  taken?(c: SkillCtx): void;
  /** A blow that would reduce this card to 0 — may set c.prevented. */
  lethal?(c: SkillCtx): void;
  /** This card killed c.other. */
  kill?(c: SkillCtx): void;
  /** This card died. */
  death?(c: SkillCtx): void;
  /** An ally died. */
  allyDeath?(c: SkillCtx): void;
}

export interface SkillDef {
  id: string;
  name: string;
  family: SkillFamily;
  text: string;
  hooks: SkillHooks;
}

// --- small helpers -----------------------------------------------------

const pctMax = (c: Combatant, p: number) => Math.round(c.maxHp * p);
const roll = (ctx: SkillCtx, p: number) => ctx.api.random() < p;

function def(
  id: string, name: string, family: SkillFamily, text: string, hooks: SkillHooks,
): SkillDef {
  return { id, name, family, text, hooks };
}

// =======================================================================
// 🛡 DEFENSE
// =======================================================================

const DEFENSE: SkillDef[] = [
  def("ironhide", "Ironhide", "defense",
    "20% chance to block an attack outright. After 3 blocks, gain 30% damage reduction for 2 turns.", {
    incoming(c) {
      if (!roll(c, 0.20)) return;
      c.blocked = true;
      const blocks = c.self.bump("ironhide");
      c.api.note(c.self, `${c.self.data.cardName} blocks the blow`);
      if (blocks % 3 === 0) {
        c.self.addBuff({ stat: "damageTaken", amount: -0.30, turns: turns(4), key: "ironhide" }, 1);
      }
    },
  }),
  def("last_stand", "Last Stand", "defense",
    "The first lethal blow leaves this card at 1 HP and grants 25% faster ultimate charge for 3 turns.", {
    lethal(c) {
      if (!c.self.claim("last_stand")) return;
      c.prevented = true;
      c.self.hp = 1;
      c.self.addBuff({ stat: "energyRate", amount: 0.25, turns: turns(5) });
      c.api.note(c.self, `${c.self.data.cardName} refuses to fall`);
    },
  }),
  def("gravebound", "Gravebound", "defense",
    "Falling below 20% HP grants a shield worth 12% of max HP. Once per battle.", {
    taken(c) {
      if (c.self.hpRatio() >= 0.20 || !c.self.claim("gravebound")) return;
      const gained = c.self.addShield(pctMax(c.self, 0.12));
      c.api.note(c.self, `${c.self.data.cardName} raises a grave shield`, gained);
    },
  }),
  def("stoneheart", "Stoneheart", "defense",
    "Every 5th attack against this card deals 40% less damage.", {
    incoming(c) {
      if (c.self.bump("stoneheart") % 5 !== 0) return;
      c.damage = Math.round(c.damage * 0.6);
    },
  }),
  def("second_wind", "Second Wind", "defense",
    "Falling below 35% HP restores 10% max HP and grants 15% speed for 2 turns. Once per battle.", {
    taken(c) {
      if (c.self.hpRatio() >= 0.35 || !c.self.claim("second_wind")) return;
      const healed = c.self.heal(pctMax(c.self, 0.10));
      c.self.addBuff({ stat: "speed", amount: 0.15, turns: turns(4) });
      c.api.note(c.self, `${c.self.data.cardName} catches a second wind`, healed);
    },
  }),
  // Self-contained on purpose: the engine has no innate block chance, so a
  // skill that only reacts to blocking would be dead weight on its own.
  def("thornmail", "Thornmail", "defense",
    "15% chance to block an attack outright and return 20% of this card's attack to the attacker.", {
    incoming(c) {
      if (!c.attacker || !roll(c, 0.15)) return;
      c.blocked = true;
      c.api.damage(c.self, c.attacker, Math.round(c.self.attack * 0.2), "Thornmail");
    },
  }),
  def("bloodguard", "Bloodguard", "defense",
    "Below 50% HP, gain 10% lifesteal for the rest of the battle.", {
    taken(c) {
      if (c.self.hpRatio() >= 0.5 || !c.self.claim("bloodguard")) return;
      c.self.addBuff({ stat: "lifesteal", amount: 0.10, turns: Infinity });
      c.api.note(c.self, `${c.self.data.cardName} fights on blood`);
    },
  }),
  def("unbroken", "Unbroken", "defense",
    "Cannot be stunned more than once every 4 turns.", {
    turnStart(c) {
      if (c.self.stunTurns > 0 && c.self.count("unbroken_cd") > 0) c.self.stunTurns = 0;
      if (c.self.count("unbroken_cd") > 0) c.self.bump("unbroken_cd", -1);
      else if (c.self.stunTurns > 0) c.self.counters["unbroken_cd"] = turns(8);
    },
  }),
  def("guardians_oath", "Guardian's Oath", "defense",
    "While this card lives, the lowest-HP ally takes 15% less damage.", {
    entry(c) {
      const ally = c.api.lowestHpAlly(c.self, false);
      if (!ally || ally.hasBuff("oath")) return;
      ally.addBuff({ stat: "damageTaken", amount: -0.15, turns: Infinity, key: "oath" }, 1);
      c.api.note(c.self, `${c.self.data.cardName} swears to guard ${ally.data.cardName}`);
    },
  }),
  def("fading_shield", "Fading Shield", "defense",
    "On entry, gain a shield worth 15% of max HP. It fades after 3 turns.", {
    entry(c) {
      const gained = c.self.addShield(pctMax(c.self, 0.15));
      c.self.counters["fading"] = turns(6);
      c.api.note(c.self, `${c.self.data.cardName} conjures a fading shield`, gained);
    },
    turnStart(c) {
      if (c.self.count("fading") <= 0) return;
      if (c.self.bump("fading", -1) <= 0) c.self.shield = 0;
    },
  }),
  def("bulwark", "Bulwark", "defense",
    "Every 3rd hit received grants 5% defense, stacking up to 3 times.", {
    taken(c) {
      if (c.self.bump("bulwark") % 3 !== 0) return;
      c.self.addBuff({ stat: "defense", amount: 0.05, turns: Infinity, key: "bulwark" }, 3);
    },
  }),
  def("death_denied", "Death Denied", "defense",
    "Once per battle, a lethal blow instead leaves this card at 5% HP.", {
    lethal(c) {
      if (!c.self.claim("death_denied")) return;
      c.prevented = true;
      c.self.hp = Math.max(1, pctMax(c.self, 0.05));
      c.api.note(c.self, `${c.self.data.cardName} denies death`);
    },
  }),
  def("heavy_soul", "Heavy Soul", "defense",
    "Immune to stun, but the ultimate charges 8% slower.", {
    entry(c) {
      if (!c.self.claim("heavy_soul")) return;
      c.self.addBuff({ stat: "energyRate", amount: -0.08, turns: Infinity });
    },
    turnStart(c) { c.self.stunTurns = 0; },
  }),
  def("mirror_guard", "Mirror Guard", "defense",
    "15% chance to reflect half of an incoming attack back at the attacker.", {
    incoming(c) {
      if (!c.attacker || !roll(c, 0.15)) return;
      const back = Math.round(c.damage * 0.5);
      c.damage -= back;
      c.api.damage(c.self, c.attacker, back, "Mirror Guard");
    },
  }),
  def("undying_ember", "Undying Ember", "defense",
    "On death, burn the whole enemy team for 10% of this card's max HP over 2 turns.", {
    death(c) {
      const burn = Math.round(pctMax(c.self, 0.10) / turns(4));
      for (const e of c.api.enemies(c.self)) {
        if (e.alive) e.applyDot({ kind: "burn", turns: turns(4), perTurn: burn, sourceId: c.self.id });
      }
      c.api.note(c.self, `${c.self.data.cardName} bursts into embers`);
    },
  }),
];

// =======================================================================
// ⚔ OFFENSE
// =======================================================================

const OFFENSE: SkillDef[] = [
  def("executioners_mark", "Executioner's Mark", "offense",
    "Attacks against enemies below 25% HP deal 25% bonus damage.", {
    outgoing(c) {
      if (c.target && c.target.hpRatio() < 0.25) c.damage = Math.round(c.damage * 1.25);
    },
  }),
  def("blood_rush", "Blood Rush", "offense",
    "Each consecutive attack on the same enemy deals 5% more damage, up to 20%.", {
    outgoing(c) {
      if (!c.target) return;
      const last = c.self.counters["rush_target"];
      const same = String(last) === c.target.id;
      c.self.counters["rush_target"] = c.target.id as unknown as number;
      const stacks = same ? Math.min(4, c.self.bump("rush")) : (c.self.counters["rush"] = 0);
      c.damage = Math.round(c.damage * (1 + stacks * 0.05));
    },
  }),
  def("third_strike", "Third Strike", "offense",
    "Every 3rd attack deals 75% bonus damage.", {
    outgoing(c) {
      if (c.self.bump("third") % 3 === 0) c.damage = Math.round(c.damage * 1.75);
    },
  }),
  def("crushing_blow", "Crushing Blow", "offense",
    "12% chance to deal 150% damage and stun the target for a turn.", {
    outgoing(c) {
      if (!roll(c, 0.12)) return;
      c.damage = Math.round(c.damage * 1.5);
      if (c.target) c.target.stunTurns = Math.max(c.target.stunTurns, 1);
      c.api.note(c.self, `${c.self.data.cardName} lands a crushing blow`);
    },
  }),
  def("momentum", "Momentum", "offense",
    "Killing an enemy grants 15% faster ultimate charge for 3 turns.", {
    kill(c) {
      c.self.addBuff({ stat: "energyRate", amount: 0.15, turns: turns(5) });
    },
  }),
  def("predator", "Predator", "offense",
    "Deals 20% bonus damage to enemies with more current HP than this card.", {
    outgoing(c) {
      if (c.target && c.target.hp > c.self.hp) c.damage = Math.round(c.damage * 1.2);
    },
  }),
  def("backstab", "Backstab", "offense",
    "Deals 25% bonus damage to enemies that are not the active fighter.", {
    outgoing(c) {
      const active = c.api.activeEnemy(c.self);
      if (c.target && active && c.target.id !== active.id) c.damage = Math.round(c.damage * 1.25);
    },
  }),
  def("overcharge", "Overcharge", "offense",
    "Every 8th attack deals 200% damage but costs 3% of max HP.", {
    outgoing(c) {
      if (c.self.bump("overcharge") % 8 !== 0) return;
      c.damage = Math.round(c.damage * 2.0);
      c.self.hp = Math.max(1, c.self.hp - pctMax(c.self, 0.03));
      c.api.note(c.self, `${c.self.data.cardName} overcharges`);
    },
  }),
  def("rend", "Rend", "offense",
    "Every 4th attack bleeds the target for 3% of its max HP over 2 turns.", {
    dealt(c) {
      if (!c.target || c.self.bump("rend") % 4 !== 0) return;
      const total = pctMax(c.target, 0.03);
      c.target.applyDot({ kind: "bleed", turns: turns(4), perTurn: Math.round(total / turns(4)), sourceId: c.self.id });
    },
  }),
  def("bonebreaker", "Bonebreaker", "offense",
    "Every 5th attack strips 8% defense from the target for 2 turns.", {
    dealt(c) {
      if (!c.target || c.self.bump("bone") % 5 !== 0) return;
      c.target.addBuff({ stat: "defense", amount: -0.08, turns: turns(4), key: "bone" }, 3);
    },
  }),
  def("wild_swing", "Wild Swing", "offense",
    "10% chance to also strike a second enemy for half damage.", {
    dealt(c) {
      if (!roll(c, 0.10)) return;
      const others = c.api.enemies(c.self).filter((e) => e.alive && e.id !== c.target?.id);
      if (others.length === 0) return;
      c.api.damage(c.self, others[0], Math.round(c.damage * 0.5), "Wild Swing");
    },
  }),
  def("bloodied_blade", "Bloodied Blade", "offense",
    "Deals 10% more damage while below 50% HP.", {
    outgoing(c) {
      if (c.self.hpRatio() < 0.5) c.damage = Math.round(c.damage * 1.1);
    },
  }),
  def("marked_prey", "Marked Prey", "offense",
    "The first enemy attacked is marked; this card deals 15% bonus damage to it.", {
    outgoing(c) {
      if (!c.target) return;
      if (c.self.marked.size === 0) c.self.marked.add(c.target.id);
      if (c.self.marked.has(c.target.id)) c.damage = Math.round(c.damage * 1.15);
    },
  }),
  def("reckless_fury", "Reckless Fury", "offense",
    "Ultimate charges 20% faster, but this card takes 10% more damage.", {
    entry(c) {
      if (!c.self.claim("reckless")) return;
      c.self.addBuff({ stat: "energyRate", amount: 0.20, turns: Infinity });
      c.self.addBuff({ stat: "damageTaken", amount: 0.10, turns: Infinity });
    },
  }),
  def("finisher", "Finisher", "offense",
    "Attacks against enemies below 15% HP deal 50% bonus damage.", {
    outgoing(c) {
      if (c.target && c.target.hpRatio() < 0.15) c.damage = Math.round(c.damage * 1.5);
    },
  }),
];

// =======================================================================
// 🔥 ELEMENT — burn, bleed, poison
// =======================================================================

const ELEMENT: SkillDef[] = [
  def("cinderbrand", "Cinderbrand", "element",
    "20% chance to burn the target for 3% of this card's attack per turn, for 2 turns.", {
    dealt(c) {
      if (!c.target || !roll(c, 0.20)) return;
      c.target.applyDot({ kind: "burn", turns: turns(4), perTurn: Math.max(1, Math.round(c.self.attack * 0.03)), sourceId: c.self.id });
    },
  }),
  def("ashen_touch", "Ashen Touch", "element",
    "Every 3rd attack burns the target. Burning enemies deal 5% less damage.", {
    dealt(c) {
      if (!c.target || c.self.bump("ashen") % 3 !== 0) return;
      c.target.applyDot({ kind: "burn", turns: turns(4), perTurn: Math.max(1, Math.round(c.self.attack * 0.04)), sourceId: c.self.id });
      c.target.addBuff({ stat: "damageDealt", amount: -0.05, turns: turns(4), key: "ashen" }, 1);
    },
  }),
  def("kindled_rage", "Kindled Rage", "element",
    "Gain 4% ultimate charge rate per burning enemy, up to 12%.", {
    turnStart(c) {
      const burning = c.api.enemies(c.self).filter((e) => e.alive && e.hasDot("burn")).length;
      c.self.buffs = c.self.buffs.filter((b) => b.key !== "kindled");
      if (burning > 0) {
        c.self.addBuff({ stat: "energyRate", amount: Math.min(0.12, burning * 0.04), turns: 2, key: "kindled" }, 1);
      }
    },
  }),
  def("scorching_death", "Scorching Death", "element",
    "On death, burn the killer for 8% of this card's max HP over 3 turns.", {
    death(c) {
      if (!c.attacker) return;
      const total = pctMax(c.self, 0.08);
      c.attacker.applyDot({ kind: "burn", turns: turns(5), perTurn: Math.round(total / turns(5)), sourceId: c.self.id });
    },
  }),
  def("ember_chain", "Ember Chain", "element",
    "When a burning enemy dies, the burn jumps to another enemy at 60% strength.", {
    kill(c) {
      if (!c.other || !c.other.hasDot("burn")) return;
      const next = c.api.enemies(c.self).find((e) => e.alive);
      if (!next) return;
      const src = c.other.dots.find((d) => d.kind === "burn");
      if (!src) return;
      next.applyDot({ kind: "burn", turns: src.turns, perTurn: Math.round(src.perTurn * 0.6), sourceId: c.self.id });
    },
  }),
  def("firebrand", "Firebrand", "element",
    "Attacks that roll a critical apply a strong burn for 2 turns.", {
    dealt(c) {
      if (!c.target || !roll(c, 0.15)) return;
      c.target.applyDot({ kind: "burn", turns: turns(3), perTurn: Math.max(1, Math.round(c.self.attack * 0.08)), sourceId: c.self.id });
    },
  }),
  def("smoldering_armor", "Smoldering Armor", "element",
    "Attackers have a 15% chance to catch fire for 2 turns.", {
    taken(c) {
      if (!c.attacker || !roll(c, 0.15)) return;
      c.attacker.applyDot({ kind: "burn", turns: turns(4), perTurn: Math.max(1, Math.round(c.self.attack * 0.03)), sourceId: c.self.id });
    },
  }),
  def("inferno_pulse", "Inferno Pulse", "element",
    "Every 5 turns, scorch every enemy and burn them for a turn.", {
    turnStart(c) {
      if (c.self.bump("pulse") % turns(10) !== 0) return;
      for (const e of c.api.enemies(c.self)) {
        if (!e.alive) continue;
        c.api.damage(c.self, e, Math.round(c.self.attack * 0.4), "Inferno Pulse");
        e.applyDot({ kind: "burn", turns: 1, perTurn: Math.round(c.self.attack * 0.05), sourceId: c.self.id });
      }
    },
  }),
  def("blackened_wound", "Blackened Wound", "element",
    "Burning enemies receive 8% less healing.", {
    dealt(c) {
      if (!c.target || !c.target.hasDot("burn") || c.target.hasBuff("blackened")) return;
      c.target.addBuff({ stat: "healingReceived", amount: -0.08, turns: turns(6), key: "blackened" }, 1);
    },
  }),
  def("funeral_flame", "Funeral Flame", "element",
    "When a burning enemy dies, every other enemy takes 5% of its max HP as fire damage.", {
    kill(c) {
      if (!c.other || !c.other.hasDot("burn")) return;
      const blast = pctMax(c.other, 0.05);
      for (const e of c.api.enemies(c.self)) {
        if (e.alive && e.id !== c.other.id) c.api.damage(c.self, e, blast, "Funeral Flame");
      }
    },
  }),
];

// =======================================================================
// ☠ DEATH
// =======================================================================

const DEATH: SkillDef[] = [
  def("grave_gift", "Grave Gift", "death",
    "On death, restore 8% max HP to the lowest-HP ally.", {
    death(c) {
      const ally = c.api.lowestHpAlly(c.self, false);
      if (!ally) return;
      const healed = ally.heal(pctMax(ally, 0.08));
      c.api.note(c.self, `${c.self.data.cardName} leaves a parting gift to ${ally.data.cardName}`, healed);
    },
  }),
  def("dead_mans_hand", "Dead Man's Hand", "death",
    "On death, the killer's ultimate charges 10% slower for 3 turns.", {
    death(c) {
      c.attacker?.addBuff({ stat: "energyRate", amount: -0.10, turns: turns(5) });
    },
  }),
  def("final_offering", "Final Offering", "death",
    "On death, the next ally gains 15% attack for 3 turns.", {
    death(c) {
      const ally = c.api.nextAlly(c.self);
      ally?.addBuff({ stat: "attack", amount: 0.15, turns: turns(6) });
    },
  }),
  def("corpsewalker", "Corpsewalker", "death",
    "Each allied death grants 5% faster ultimate charge, stacking twice.", {
    allyDeath(c) {
      c.self.addBuff({ stat: "energyRate", amount: 0.05, turns: Infinity, key: "corpse" }, 2);
    },
  }),
  def("soul_shard", "Soul Shard", "death",
    "On death, the next ally to enter combat gains 10% max HP as a shield.", {
    death(c) {
      const ally = c.api.nextAlly(c.self);
      if (ally) ally.addShield(pctMax(ally, 0.10));
    },
  }),
  def("blood_pact", "Blood Pact", "death",
    "On entry, spend 5% max HP to grant the strongest ally 8% attack.", {
    entry(c) {
      if (!c.self.claim("blood_pact")) return;
      const ally = c.api.strongestAlly(c.self, false);
      if (!ally) return;
      c.self.hp = Math.max(1, c.self.hp - pctMax(c.self, 0.05));
      ally.addBuff({ stat: "attack", amount: 0.08, turns: Infinity });
      c.api.note(c.self, `${c.self.data.cardName} seals a pact with ${ally.data.cardName}`);
    },
  }),
  def("martyr", "Martyr", "death",
    "Takes 40% of the damage aimed at the lowest-HP ally.", {
    entry(c) {
      const ally = c.api.lowestHpAlly(c.self, false);
      if (!ally || ally.hasBuff("martyr")) return;
      ally.addBuff({ stat: "damageTaken", amount: -0.40, turns: Infinity, key: "martyr" }, 1);
    },
  }),
  def("rotting_curse", "Rotting Curse", "death",
    "On death, the killer receives 20% less healing for 3 turns.", {
    death(c) {
      c.attacker?.addBuff({ stat: "healingReceived", amount: -0.20, turns: turns(5) });
    },
  }),
  def("death_echo", "Death Echo", "death",
    "On death, strike the active enemy once more for 50% of this card's attack.", {
    death(c) {
      const enemy = c.api.activeEnemy(c.self);
      if (enemy) c.api.damage(c.self, enemy, Math.round(c.self.attack * 0.5), "Death Echo");
    },
  }),
  def("grim_inheritance", "Grim Inheritance", "death",
    "On death, pass this card's remaining buffs to the next ally.", {
    death(c) {
      const ally = c.api.nextAlly(c.self);
      if (!ally) return;
      const positive = c.self.buffs.filter((b) => b.amount > 0 && b.turns !== Infinity);
      for (const b of positive) ally.addBuff(b);
      if (positive.length > 0) {
        c.api.note(c.self, `${c.self.data.cardName} bequeaths its power to ${ally.data.cardName}`);
      }
    },
  }),
];

// =======================================================================
// 👹 SUMMON
// =======================================================================

const SUMMON: SkillDef[] = [
  def("broodmother", "Broodmother", "summon",
    "On entry, summon 2 broodlings with 40% of this card's stats.", {
    entry(c) {
      if (!c.self.claim("broodmother")) return;
      c.api.summon(c.self, "Broodling", 0.4, turns(20), 2);
    },
  }),
  def("battle_standard", "Battle Standard", "summon",
    "On entry, plant a standard; allies gain 8% faster ultimate charge while it stands.", {
    entry(c) {
      if (!c.self.claim("standard")) return;
      c.api.summon(c.self, "War Standard", 0.25, turns(24), 1);
      for (const a of c.api.allies(c.self)) {
        if (a.alive) a.addBuff({ stat: "energyRate", amount: 0.08, turns: turns(24), key: "standard" }, 1);
      }
    },
  }),
  def("gravecaller", "Gravecaller", "summon",
    "The first allied death raises a skeleton with 30% of that card's stats.", {
    allyDeath(c) {
      if (!c.self.claim("gravecaller")) return;
      c.api.summon(c.self, "Risen Skeleton", 0.3, turns(10), 1);
    },
  }),
  def("nest_of_thorns", "Nest of Thorns", "summon",
    "Every 6 turns, summon a thornling with 25% of this card's stats.", {
    turnStart(c) {
      if (c.self.bump("thorns") % turns(12) !== 0) return;
      c.api.summon(c.self, "Thornling", 0.25, turns(12), 1);
    },
  }),
  def("splitspawn", "Splitspawn", "summon",
    "Below 40% HP, split off a copy with 20% of this card's stats. Once per battle.", {
    taken(c) {
      if (c.self.hpRatio() >= 0.40 || !c.self.claim("splitspawn")) return;
      c.api.summon(c.self, `${c.self.data.cardName} Spawn`, 0.2, turns(20), 1);
    },
  }),
  def("familiar", "Familiar", "summon",
    "On entry, summon a familiar. It restores 2% max HP to this card each turn.", {
    entry(c) {
      if (!c.self.claim("familiar")) return;
      c.api.summon(c.self, "Familiar", 0.15, turns(30), 1);
    },
    turnStart(c) {
      if (!c.self.spent.has("familiar")) return;
      c.self.heal(pctMax(c.self, 0.02));
    },
  }),
  def("war_hounds", "War Hounds", "summon",
    "On entry, summon 2 hounds with 30% of this card's stats. They last 6 turns.", {
    entry(c) {
      if (!c.self.claim("hounds")) return;
      c.api.summon(c.self, "War Hound", 0.3, turns(12), 2);
    },
  }),
  def("last_brood", "Last Brood", "summon",
    "On death, summon 3 broodlings with 15% of this card's stats.", {
    death(c) {
      c.api.summon(c.self, "Broodling", 0.15, turns(16), 3);
    },
  }),
  def("soul_collector", "Soul Collector", "summon",
    "Each kill strengthens this card's summons by 10%, up to 30%.", {
    kill(c) {
      c.self.bump("souls");
    },
  }),
  def("swarmkeeper", "Swarmkeeper", "summon",
    "Every 7 turns, summon a swarmling with 20% of this card's stats.", {
    turnStart(c) {
      if (c.self.bump("swarm") % turns(15) !== 0) return;
      c.api.summon(c.self, "Swarmling", 0.2, turns(15), 1);
    },
  }),
];

// =======================================================================
// ❤ SUPPORT
// =======================================================================

const SUPPORT: SkillDef[] = [
  def("lifebloom", "Lifebloom", "support",
    "Every 3 turns, heal the lowest-HP ally for 5% of their max HP.", {
    turnStart(c) {
      if (c.self.bump("lifebloom") % turns(6) !== 0) return;
      const ally = c.api.lowestHpAlly(c.self, true);
      if (!ally) return;
      const healed = ally.heal(pctMax(ally, 0.05));
      if (healed > 0) c.api.note(c.self, `${c.self.data.cardName} mends ${ally.data.cardName}`, healed);
    },
  }),
  def("blood_leech", "Blood Leech", "support",
    "Converts 8% of damage dealt into healing.", {
    entry(c) {
      if (!c.self.claim("leech")) return;
      c.self.addBuff({ stat: "lifesteal", amount: 0.08, turns: Infinity });
    },
  }),
  def("rejuvenation", "Rejuvenation", "support",
    "On entry, restore 8% max HP to every ally.", {
    entry(c) {
      if (!c.self.claim("rejuv")) return;
      for (const a of c.api.allies(c.self)) if (a.alive) a.heal(pctMax(a, 0.08));
      c.api.note(c.self, `${c.self.data.cardName} rejuvenates the team`);
    },
  }),
  def("pulse_healer", "Pulse Healer", "support",
    "Every 5 turns, heal every ally for 6% of their max HP.", {
    turnStart(c) {
      if (c.self.bump("pulseheal") % turns(10) !== 0) return;
      for (const a of c.api.allies(c.self)) if (a.alive) a.heal(pctMax(a, 0.06));
      c.api.note(c.self, `${c.self.data.cardName} pulses healing light`);
    },
  }),
  def("desperate_medic", "Desperate Medic", "support",
    "Allies below 30% HP receive 20% more healing.", {
    turnStart(c) {
      for (const a of c.api.allies(c.self)) {
        if (!a.alive) continue;
        const wants = a.hpRatio() < 0.30;
        if (wants && !a.hasBuff("medic")) a.addBuff({ stat: "healingReceived", amount: 0.20, turns: 2, key: "medic" }, 1);
      }
    },
  }),
  def("soul_mend", "Soul Mend", "support",
    "When an ally dies, restore 12% max HP to the lowest-HP survivor.", {
    allyDeath(c) {
      const ally = c.api.lowestHpAlly(c.self, true);
      if (!ally) return;
      const healed = ally.heal(pctMax(ally, 0.12));
      if (healed > 0) c.api.note(c.self, `${c.self.data.cardName} mends a broken soul`, healed);
    },
  }),
  def("regrowth", "Regrowth", "support",
    "After taking damage, regenerate 1% max HP per turn for 3 turns.", {
    taken(c) {
      if (c.self.hasBuff("regrowth")) return;
      c.self.addBuff({ stat: "healingReceived", amount: 0, turns: turns(5), key: "regrowth" }, 1);
      c.self.counters["regrow"] = turns(5);
    },
    turnStart(c) {
      if (c.self.count("regrow") <= 0) return;
      c.self.bump("regrow", -1);
      c.self.heal(pctMax(c.self, 0.01));
    },
  }),
  def("vital_link", "Vital Link", "support",
    "Each turn, share 10% of this card's max HP as healing with the lowest-HP ally.", {
    turnStart(c) {
      const ally = c.api.lowestHpAlly(c.self, false);
      if (!ally || c.self.bump("vital") % turns(6) !== 0) return;
      ally.heal(pctMax(c.self, 0.10));
    },
  }),
  def("warm_blood", "Warm Blood", "support",
    "Allies regenerate 1% max HP every turn while this card lives.", {
    turnStart(c) {
      for (const a of c.api.allies(c.self)) if (a.alive) a.heal(pctMax(a, 0.01));
    },
  }),
  def("last_remedy", "Last Remedy", "support",
    "Once per battle, when an ally drops below 10% HP, heal them for 15% max HP.", {
    turnStart(c) {
      const ally = c.api.allies(c.self).find((a) => a.alive && a.hpRatio() < 0.10);
      if (!ally || !c.self.claim("remedy")) return;
      const healed = ally.heal(pctMax(ally, 0.15));
      c.api.note(c.self, `${c.self.data.cardName} applies a last remedy to ${ally.data.cardName}`, healed);
    },
  }),
];

// =======================================================================
// 🧠 CONTROL
// =======================================================================

const CONTROL: SkillDef[] = [
  def("hexbreaker", "Hexbreaker", "control",
    "Every 4 turns, clear one negative effect from this card.", {
    turnStart(c) {
      if (c.self.bump("hex") % turns(8) !== 0) return;
      const bad = c.self.buffs.findIndex((b) => b.amount < 0);
      if (bad >= 0) c.self.buffs.splice(bad, 1);
      else if (c.self.dots.length > 0) c.self.dots.shift();
    },
  }),
  def("timekeeper", "Timekeeper", "control",
    "Every 6 turns, slow every enemy by 20% for a turn.", {
    turnStart(c) {
      if (c.self.bump("timekeeper") % turns(12) !== 0) return;
      for (const e of c.api.enemies(c.self)) {
        if (e.alive) e.addBuff({ stat: "speed", amount: -0.20, turns: 1, key: "slow" }, 1);
      }
      c.api.note(c.self, `${c.self.data.cardName} bends time`);
    },
  }),
  def("silencer", "Silencer", "control",
    "Every 5th attack has a 25% chance to silence the target for a turn.", {
    dealt(c) {
      if (!c.target || c.self.bump("silencer") % 5 !== 0 || !roll(c, 0.25)) return;
      c.target.silenceTurns = Math.max(c.target.silenceTurns, 1);
      c.api.note(c.self, `${c.target.data.cardName} is silenced`);
    },
  }),
  def("disruptor", "Disruptor", "control",
    "On entry, slow the enemy's ultimate charge by 10% for 2 turns.", {
    entry(c) {
      for (const e of c.api.enemies(c.self)) {
        if (e.alive) e.addBuff({ stat: "energyRate", amount: -0.10, turns: turns(4), key: "disrupt" }, 1);
      }
    },
  }),
  def("phasewalker", "Phasewalker", "control",
    "Every 5 turns, become untargetable for a turn.", {
    turnStart(c) {
      if (c.self.bump("phase") % turns(10) !== 0) return;
      c.self.untargetableTurns = 1;
      c.api.note(c.self, `${c.self.data.cardName} phases out`);
    },
  }),
  def("blinkstrike", "Blinkstrike", "control",
    "Every 6 turns, strike the lowest-HP enemy for 75% of this card's attack.", {
    turnStart(c) {
      if (c.self.bump("blink") % turns(12) !== 0) return;
      const living = c.api.enemies(c.self).filter((e) => e.alive);
      if (living.length === 0) return;
      const weakest = living.reduce((a, b) => (a.hp <= b.hp ? a : b));
      c.api.damage(c.self, weakest, Math.round(c.self.attack * 0.75), "Blinkstrike");
    },
  }),
  def("gravity_well", "Gravity Well", "control",
    "Every 7 turns, slow every enemy by 20% for 2 turns.", {
    turnStart(c) {
      if (c.self.bump("gravity") % turns(15) !== 0) return;
      for (const e of c.api.enemies(c.self)) {
        if (e.alive) e.addBuff({ stat: "speed", amount: -0.20, turns: turns(3), key: "gravity" }, 1);
      }
    },
  }),
  def("mana_leech", "Mana Leech", "control",
    "Whenever an enemy lands a hit, gain 5% ultimate charge.", {
    taken(c) {
      c.self.energy = Math.min(100, c.self.energy + 5);
    },
  }),
  def("null_field", "Null Field", "control",
    "Enemy attack buffs are 10% less effective while this card lives.", {
    turnStart(c) {
      for (const e of c.api.enemies(c.self)) {
        if (!e.alive || e.hasBuff("null")) continue;
        e.addBuff({ stat: "damageDealt", amount: -0.10, turns: 2, key: "null" }, 1);
      }
    },
  }),
  def("spell_mirror", "Spell Mirror", "control",
    "12% chance to reflect half of an incoming ability back at the caster.", {
    incoming(c) {
      if (!c.attacker || !roll(c, 0.12)) return;
      const back = Math.round(c.damage * 0.5);
      c.api.damage(c.self, c.attacker, back, "Spell Mirror");
    },
  }),
];

// =======================================================================
// 🩸 RISK
// =======================================================================

const RISK: SkillDef[] = [
  def("glass_cannon", "Glass Cannon", "risk",
    "25% more attack, but 10% less max HP.", {
    entry(c) {
      if (!c.self.claim("glass")) return;
      c.self.addBuff({ stat: "attack", amount: 0.25, turns: Infinity });
      c.self.maxHp = Math.max(1, Math.round(c.self.maxHp * 0.9));
      c.self.hp = Math.min(c.self.hp, c.self.maxHp);
    },
  }),
  def("blood_price", "Blood Price", "risk",
    "Every 6th attack costs 2% max HP and deals 50% bonus damage.", {
    outgoing(c) {
      if (c.self.bump("bloodprice") % 6 !== 0) return;
      c.damage = Math.round(c.damage * 1.5);
      c.self.hp = Math.max(1, c.self.hp - pctMax(c.self, 0.02));
    },
  }),
  def("desperation", "Desperation", "risk",
    "Below 25% HP, the ultimate charges 30% faster.", {
    turnStart(c) {
      const low = c.self.hpRatio() < 0.25;
      if (low && !c.self.hasBuff("desperation")) {
        c.self.addBuff({ stat: "energyRate", amount: 0.30, turns: Infinity, key: "desperation" }, 1);
      }
    },
  }),
  def("cursed_strength", "Cursed Strength", "risk",
    "20% more attack, but 25% less healing received.", {
    entry(c) {
      if (!c.self.claim("cursed")) return;
      c.self.addBuff({ stat: "attack", amount: 0.20, turns: Infinity });
      c.self.addBuff({ stat: "healingReceived", amount: -0.25, turns: Infinity });
    },
  }),
  def("soul_burn", "Soul Burn", "risk",
    "Ultimate charges 15% faster, but this card loses 1% max HP every 4 turns.", {
    entry(c) {
      if (!c.self.claim("soulburn")) return;
      c.self.addBuff({ stat: "energyRate", amount: 0.15, turns: Infinity });
    },
    turnStart(c) {
      if (c.self.bump("soulburn_t") % turns(8) !== 0) return;
      c.self.hp = Math.max(1, c.self.hp - pctMax(c.self, 0.01));
    },
  }),
  def("rage_engine", "Rage Engine", "risk",
    "Every 10% of max HP lost grants 3% faster ultimate charge, up to 15%.", {
    taken(c) {
      const lost = Math.floor((1 - c.self.hpRatio()) * 10);
      const have = c.self.buffs.filter((b) => b.key === "rage").length;
      if (lost > have && have < 5) {
        c.self.addBuff({ stat: "energyRate", amount: 0.03, turns: Infinity, key: "rage" }, 5);
      }
    },
  }),
  def("frenzy", "Frenzy", "risk",
    "Taking damage grants 5% faster ultimate charge for 2 turns, stacking twice.", {
    taken(c) {
      c.self.addBuff({ stat: "energyRate", amount: 0.05, turns: turns(3), key: "frenzy" }, 2);
    },
  }),
  def("blood_debt", "Blood Debt", "risk",
    "Stores 5% of damage taken; the next attack deals it as bonus damage.", {
    taken(c) {
      c.self.bump("debt", Math.round(c.damage * 0.05));
    },
    outgoing(c) {
      const owed = c.self.count("debt");
      if (owed <= 0) return;
      c.damage += owed;
      c.self.counters["debt"] = 0;
    },
  }),
  def("doomsday_clock", "Doomsday Clock", "risk",
    "Gain 2% attack every 3 turns; after 15 turns, lose 10% max HP.", {
    turnStart(c) {
      const t = c.self.bump("doom");
      if (t % turns(5) === 0) c.self.addBuff({ stat: "attack", amount: 0.02, turns: Infinity, key: "doom" }, 10);
      if (t === turns(30)) {
        c.self.maxHp = Math.max(1, Math.round(c.self.maxHp * 0.9));
        c.self.hp = Math.min(c.self.hp, c.self.maxHp);
        c.api.note(c.self, `${c.self.data.cardName}'s clock strikes midnight`);
      }
    },
  }),
  def("unstable_core", "Unstable Core", "risk",
    "Every 5 turns, gain 10% attack, defense, or charge rate at random for 2 turns.", {
    turnStart(c) {
      if (c.self.bump("unstable") % turns(10) !== 0) return;
      const stats: Array<"attack" | "defense" | "energyRate"> = ["attack", "defense", "energyRate"];
      const pick = stats[Math.floor(c.api.random() * stats.length)];
      c.self.addBuff({ stat: pick, amount: 0.10, turns: turns(5), key: "unstable" }, 1);
    },
  }),
];

// =======================================================================
// 👑 LEGENDARY
// =======================================================================

const LEGENDARY: SkillDef[] = [
  def("echo_blade", "Echo Blade", "legendary",
    "Every 7th attack strikes again for 40% damage.", {
    dealt(c) {
      if (!c.target || c.self.bump("echo") % 7 !== 0) return;
      c.api.damage(c.self, c.target, Math.round(c.damage * 0.4), "Echo Blade");
    },
  }),
  def("blood_trail", "Blood Trail", "legendary",
    "Enemies hit take 5% more damage from all sources for 2 turns.", {
    dealt(c) {
      if (!c.target || c.target.hasBuff("trail")) return;
      c.target.addBuff({ stat: "damageTaken", amount: 0.05, turns: turns(3), key: "trail" }, 1);
    },
  }),
  def("chainbreaker", "Chainbreaker", "legendary",
    "Breaks a stun immediately and grants 10% faster charge for 2 turns.", {
    turnStart(c) {
      if (c.self.stunTurns <= 0) return;
      c.self.stunTurns = 0;
      c.self.addBuff({ stat: "energyRate", amount: 0.10, turns: turns(3) });
      c.api.note(c.self, `${c.self.data.cardName} breaks free`);
    },
  }),
  def("hollow_crown", "Hollow Crown", "legendary",
    "Gains 5% of the strongest enemy's attack as bonus attack.", {
    entry(c) {
      if (!c.self.claim("crown")) return;
      const living = c.api.enemies(c.self).filter((e) => e.alive);
      if (living.length === 0) return;
      const best = living.reduce((a, b) => (a.attack >= b.attack ? a : b));
      c.self.addBuff({ stat: "attack", amount: (best.attack * 0.05) / Math.max(1, c.self.data.attack), turns: Infinity });
    },
  }),
  def("soul_anchor", "Soul Anchor", "legendary",
    "Immune to stun above 50% HP; below it, gain 10% speed.", {
    turnStart(c) {
      if (c.self.hpRatio() > 0.5) {
        c.self.stunTurns = 0;
      } else if (!c.self.hasBuff("anchor")) {
        c.self.addBuff({ stat: "speed", amount: 0.10, turns: Infinity, key: "anchor" }, 1);
      }
    },
  }),
  def("predators_mark", "Predator's Mark", "legendary",
    "Damaging an enemy below 30% HP makes the next attack 15% stronger.", {
    dealt(c) {
      if (c.target && c.target.hpRatio() < 0.30) c.self.counters["predmark"] = 1;
    },
    outgoing(c) {
      if (c.self.count("predmark") <= 0) return;
      c.damage = Math.round(c.damage * 1.15);
      c.self.counters["predmark"] = 0;
    },
  }),
  def("echo_of_pain", "Echo of Pain", "legendary",
    "The first attacker is marked; every later hit costs them 3% of their attack.", {
    taken(c) {
      if (!c.attacker) return;
      if (c.self.marked.size === 0) {
        c.self.marked.add(c.attacker.id);
        return;
      }
      if (c.self.marked.has(c.attacker.id)) {
        c.api.damage(c.self, c.attacker, Math.max(1, Math.round(c.attacker.attack * 0.03)), "Echo of Pain");
      }
    },
  }),
  def("rallying_cry", "Rallying Cry", "legendary",
    "Below 50% HP, every ally gains 8% faster charge for 3 turns. Once per battle.", {
    taken(c) {
      if (c.self.hpRatio() >= 0.5 || !c.self.claim("rally")) return;
      for (const a of c.api.allies(c.self)) {
        if (a.alive) a.addBuff({ stat: "energyRate", amount: 0.08, turns: turns(5) });
      }
      c.api.note(c.self, `${c.self.data.cardName} rallies the team`);
    },
  }),
  def("ashes_to_ashes", "Ashes to Ashes", "legendary",
    "On death, deal 10% of max HP to every enemy and burn them for a turn.", {
    death(c) {
      const blast = pctMax(c.self, 0.10);
      for (const e of c.api.enemies(c.self)) {
        if (!e.alive) continue;
        c.api.damage(c.self, e, blast, "Ashes to Ashes");
        e.applyDot({ kind: "burn", turns: turns(3), perTurn: Math.round(blast * 0.1), sourceId: c.self.id });
      }
    },
  }),
  def("kingbreaker", "Kingbreaker", "legendary",
    "Deals 15% bonus damage to enemies with more max HP. Killing one grants 5% max HP for the battle.", {
    outgoing(c) {
      if (c.target && c.target.maxHp > c.self.maxHp) c.damage = Math.round(c.damage * 1.15);
    },
    kill(c) {
      if (!c.other || c.other.maxHp <= c.self.maxHp) return;
      const gain = pctMax(c.self, 0.05);
      c.self.maxHp += gain;
      c.self.heal(gain);
      c.api.note(c.self, `${c.self.data.cardName} breaks a king`, gain);
    },
  }),
];

// =======================================================================

export const ALL_SKILLS: SkillDef[] = [
  ...DEFENSE, ...OFFENSE, ...ELEMENT, ...DEATH,
  ...SUMMON, ...SUPPORT, ...CONTROL, ...RISK, ...LEGENDARY,
];

const BY_ID = new Map(ALL_SKILLS.map((s) => [s.id, s]));

export function skillById(id: string): SkillDef | null {
  return BY_ID.get(id) ?? null;
}

export function skillsInFamily(family: SkillFamily): SkillDef[] {
  return ALL_SKILLS.filter((s) => s.family === family);
}

/** Families a role naturally draws from, so a Tank feels like a Tank. */
export const ROLE_FAMILIES: Record<string, SkillFamily[]> = {
  Tank:     ["defense", "defense", "control", "death"],
  DPS:      ["offense", "offense", "element", "risk"],
  Assassin: ["offense", "risk", "control", "element"],
  Healer:   ["support", "support", "defense", "death"],
  Support:  ["support", "control", "summon", "death"],
};

/** Only the top rarities may roll a build-defining legendary skill. */
export const LEGENDARY_MIN_RARITY = "Legendary";
