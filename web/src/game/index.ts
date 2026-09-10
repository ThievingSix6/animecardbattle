// Barrel for the pure game logic — everything that has no DOM dependency.
// The headless simulator (scripts/simulate.mjs) bundles from here.
//
// Re-exports are explicit: `mutations` and `enemyFactory` both export a
// `TIERS`, so the two are namespaced rather than flattened.

export * as Config from "./config";
export * as Mutations from "./mutations";
export * as EnemyFactory from "./enemyFactory";

export { makeCard, cloneCard } from "./cardData";
export type { CardData } from "./cardData";

export { Rng, rng, hashString } from "./rng";
export { buildStarters, generateBatch, generateOne, pickSkillId } from "./cardGenerator";
export { BattleSim, computeDamage } from "./battleSim";
export { Combatant, turns, SECONDS_PER_TURN } from "./combatant";
export * as Skills from "./skills";
export * as Campaign from "./campaign";
export * as AbilityText from "./abilityText";
export type { BattleEvent } from "./battleSim";
export type { Side } from "./combatant";
export { buildFloor, tierFor } from "./enemyFactory";
export { ProgressionSystem } from "./progression";
export { CollectionSystem, TEAM_SIZE, SORTS } from "./collection";
export { GachaSystem } from "./gacha";
export { WeatherSystem } from "./weather";
