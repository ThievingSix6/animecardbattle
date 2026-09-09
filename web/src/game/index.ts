// Barrel for the pure game logic — everything that has no DOM dependency.
// The headless simulator (scripts/simulate.mjs) bundles from here.
//
// Re-exports are explicit: `mutations` and `enemyFactory` both export a
// `TIERS`, so the two are namespaced rather than flattened.

export * as Config from "./config";
export * as Mutations from "./mutations";
export * as EnemyFactory from "./enemyFactory";

export { makeCard, cloneCard } from "./cardData";
export type { CardData, PassiveType } from "./cardData";

export { Rng, rng, hashString } from "./rng";
export { buildStarters, generateBatch, generateOne } from "./cardGenerator";
export { BattleSim, Combatant, computeDamage } from "./battleSim";
export type { BattleEvent, Side } from "./battleSim";
export { buildFloor, tierFor } from "./enemyFactory";
export { ProgressionSystem } from "./progression";
export { CollectionSystem, TEAM_SIZE, SORTS } from "./collection";
export { GachaSystem } from "./gacha";
export { WeatherSystem } from "./weather";
