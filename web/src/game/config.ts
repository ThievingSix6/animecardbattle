// Ported from scripts/core/config.gd — every balance number in one place.
// Values are kept identical to the Godot project so the prototype plays
// the same as the source game.

export type Rarity =
  | "Common" | "Uncommon" | "Rare" | "Epic"
  | "Legendary" | "Mythic" | "Secret" | "Awakened";

export type Role = "Tank" | "DPS" | "Assassin" | "Healer" | "Support";
export type Element = "Fire" | "Water" | "Earth" | "Wind" | "Light" | "Dark";
export type TargetMode = "active" | "backline" | "aoe";

export const RARITY_ORDER: Rarity[] = [
  "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Awakened",
];

export const RARITY_WEIGHTS: Record<Rarity, number> = {
  Common: 1_000_000, Uncommon: 200_000, Rare: 40_000, Epic: 8_000,
  Legendary: 1_600, Mythic: 100, Secret: 0.000001, Awakened: 0.00000001,
};

export const ART_ONLY_RARITIES: Rarity[] = ["Awakened"];

export const BASE_STATS = {
  attack: [12, 18], defense: [6, 12], health: [80, 110], speed: [6, 10],
} as const;

export const STAT_GROWTH = 1.8;
export const SPEED_GROWTH = 1.12;
export const SELL_BASE = 10.0;
export const SELL_GROWTH = 4.0;

export const ROLE_STATS: Record<Role, Record<"attack" | "defense" | "health" | "speed", number>> = {
  Tank:     { attack: 0.55, defense: 1.8,  health: 1.7,  speed: 0.65 },
  DPS:      { attack: 1.15, defense: 0.75, health: 0.95, speed: 1.0 },
  Assassin: { attack: 1.25, defense: 0.5,  health: 0.75, speed: 1.35 },
  Healer:   { attack: 0.6,  defense: 0.9,  health: 1.1,  speed: 1.1 },
  Support:  { attack: 0.75, defense: 0.9,  health: 1.0,  speed: 1.15 },
};

export const ROLES: Role[] = ["Tank", "DPS", "Assassin", "Healer", "Support"];
export const ELEMENTS: Element[] = ["Fire", "Water", "Earth", "Wind", "Light", "Dark"];
export const FACTIONS = [
  "Ember Order", "Voidbound Covenant", "Silver Choir",
  "Wraithspire Legion", "Sunfall Dominion",
];

// ---------------- ECONOMY ----------------
export const START_GEMS = 1000;
export const START_GOLD = 10000;
export const SUMMON_COST_X1 = 100;
export const SUMMON_COST_X10 = 900;

export const MERGE_REQUIREMENT = 100;
export const MERGE_STAT_GROWTH = 1.8;
export const MERGE_SPEED_GROWTH = 1.12;
export const MERGE_SELL_GROWTH = 4.0;

// ---------------- TALENTS ----------------
export const TALENT_MAX = { speed: 20, luck: 20, multi: 2 } as const;
export const TALENT_BASE_COST = { speed: 200, luck: 250, multi: 8000 } as const;
export const TALENT_COST_GROWTH = 1.35;

export const ROLL_INTERVAL_BASE = 3.0;
export const ROLL_INTERVAL_MIN = 0.4;
export const ROLL_INTERVAL_PER_LEVEL = 0.13;
export const LUCK_PER_LEVEL = 0.02;

// ---------------- TOWER / CAMPAIGN ----------------
// Six zones of seven stages. BOSS_EVERY matches STAGES_PER_ZONE, which is
// what makes the last stage of every zone a boss fight.
export const MAX_FLOOR = 42;
export const BOSS_EVERY = 7;
export const FLOOR_STAT_SCALE = 0.12;
export const BOSS_STAT_MULT = 1.6;
export const FLOOR_GEM_BASE = 20;
export const FLOOR_GEM_PER = 5;
export const FLOOR_GOLD_BASE = 200;
export const FLOOR_GOLD_PER = 50;

// ---------------- BATTLE ----------------
export const ROUND_INTERVAL = 1.0;
export const BASIC_ABILITY_EVERY = 3;
export const ENERGY_PER_ATTACK = 25;
export const ENERGY_MAX = 100;
export const DEFENSE_FACTOR = 0.35;
export const BASIC_ABILITY_MULT = 1.5;
export const ULTIMATE_MULT = 3.0;

// ---------------- WEATHER EVENTS ----------------
export const EVENT_LUCK_MULT = 2.0;
export const EVENT_ELEMENT_WEIGHT = 3;

export interface WeatherEvent {
  id: string; name: string; element: Element; desc: string;
}

export const WEATHER_EVENTS: WeatherEvent[] = [
  { id: "meteor_storm",  name: "☄️ Meteor Storm",  element: "Fire",  desc: "Fire-aligned units surge in power and appear far more often." },
  { id: "lunar_eclipse", name: "🌑 Lunar Eclipse",  element: "Dark",  desc: "Dark-aligned units are unusually common right now." },
  { id: "aurora_veil",   name: "🌌 Aurora Veil",    element: "Light", desc: "Light-aligned units shine brighter than usual." },
  { id: "tempest",       name: "🌪️ Tempest",        element: "Wind",  desc: "Wind-aligned units are swept into abundance." },
  { id: "tidal_surge",   name: "🌊 Tidal Surge",    element: "Water", desc: "Water-aligned units flood the pool." },
  { id: "tremor",        name: "⛰️ Tremor",         element: "Earth", desc: "Earth-aligned units rise up." },
];

// ---------------- ROLL PACKS ----------------
export const ROLL_PACKS: Record<string, { label: string; rolls: number }> = {
  bronze: { label: "Bronze Roll Pack",   rolls: 10_000 },
  gold:   { label: "Gold Roll Pack",     rolls: 1_000_000 },
  boss:   { label: "Boss Conquest Pack", rolls: 100_000_000 },
};

// ---------------- STARTING ROSTER ----------------
// Plain archetype data, matching Config.STARTER_ARCHETYPES in the Godot
// project. Stats derive from the curves below, never hand-authored.
export interface StarterArchetype {
  name: string; role: Role; element: Element; rarity: Rarity;
}

export const STARTER_ARCHETYPES: StarterArchetype[] = [
  { name: "Vanguard Recruit",    role: "Tank",     element: "Earth", rarity: "Rare" },
  { name: "Emberblade Cadet",    role: "DPS",      element: "Fire",  rarity: "Rare" },
  { name: "Duskstep Adept",      role: "Assassin", element: "Dark",  rarity: "Rare" },
  { name: "Lightwarden Acolyte", role: "Healer",   element: "Light", rarity: "Rare" },
  { name: "Galewind Herald",     role: "Support",  element: "Wind",  rarity: "Rare" },
];

// The Godot build pads to 200; the prototype uses a smaller roster so the
// collection screen stays readable without virtualised scrolling.
export const GENERATED_CARD_COUNT = 120;

export function rarityIndex(rarity: string): number {
  const i = RARITY_ORDER.indexOf(rarity as Rarity);
  return i >= 0 ? i : 0;
}

export function nextRarity(rarity: string): Rarity | "" {
  const i = rarityIndex(rarity);
  return i >= RARITY_ORDER.length - 1 ? "" : RARITY_ORDER[i + 1];
}

export interface StatRanges {
  attack: [number, number]; defense: [number, number];
  health: [number, number]; speed: [number, number];
}

export function statsForRarity(rarity: string): StatRanges {
  const t = rarityIndex(rarity);
  const m = Math.pow(STAT_GROWTH, t);
  const sm = Math.pow(SPEED_GROWTH, t);
  return {
    attack:  [BASE_STATS.attack[0] * m,  BASE_STATS.attack[1] * m],
    defense: [BASE_STATS.defense[0] * m, BASE_STATS.defense[1] * m],
    health:  [BASE_STATS.health[0] * m,  BASE_STATS.health[1] * m],
    speed:   [BASE_STATS.speed[0] * sm,  BASE_STATS.speed[1] * sm],
  };
}

export function sellValueForRarity(rarity: string): number {
  return Math.round(SELL_BASE * Math.pow(SELL_GROWTH, rarityIndex(rarity)));
}
