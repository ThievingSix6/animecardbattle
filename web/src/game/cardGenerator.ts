// Ported from scripts/systems/card_generator.gd — procedurally generates
// flavourful, mechanically distinct cards. All balance numbers come from
// config; this file owns only flavour.

import * as Config from "./config";
import type { Rarity, Role } from "./config";
import { makeCard, type CardData } from "./cardData";
import { Rng, rng } from "./rng";
import { ROLE_FAMILIES, skillsInFamily, type SkillFamily } from "./skills";

export const NAME_POOLS: Record<string, string[]> = {
  demon: [
    "Azmodeus", "Belphegor", "Mammon", "Asmodai", "Baalzeth", "Moloch", "Abaddon",
    "Naberius", "Furfur", "Malzeth", "Vorkanth", "Drazuul", "Kaz'rok", "Xanathis", "Grimwrath",
  ],
  angel: [
    "Seraphiel", "Uriel", "Raziel", "Ariel", "Michaela", "Gabriela", "Zophiel",
    "Camael", "Haniel", "Metatron", "Ithuriel", "Sariel", "Remiel", "Jerahmeel", "Azrael",
  ],
  lord: [
    "Thane", "Varek", "Osric", "Dravyn", "Kestrel", "Isolde", "Brannor",
    "Sable", "Rowena", "Alaric", "Corvin", "Elowen", "Tamsin", "Ysolde", "Baldric",
  ],
  anime: [
    "Sora", "Kaida", "Yumeko", "Haru", "Akira", "Rin", "Suzume",
    "Kenji", "Nagisa", "Tsubaki", "Ryunosuke", "Aoi", "Hikari", "Shirou", "Yuzuki",
  ],
  primordial: [
    "Nyx", "Erebos", "Lilith", "Astaroth", "Ishtar", "Morrigan", "Hecate",
    "Persepha", "Tiamat", "Ereshkigal", "Nemhain", "Hel", "Kali", "Circe", "Medea",
    "Lucienne", "Aurelia", "Cassiel", "Solveig", "Thoril", "Grendal", "Vashti",
    "Zaruel", "Ophira", "Malakor", "Fenwick", "Ondine", "Rhiannon", "Caspian", "Nerissa",
  ],
};

export const ORIGINS = ["demon", "angel", "lord", "anime", "primordial"];

export const ORIGIN_LABELS: Record<string, string> = {
  "": "All Origins", demon: "Demon", angel: "Angel",
  lord: "Lords", anime: "Anime", primordial: "Primordial",
};

export const TITLES = [
  "the Demon Lord", "the Fallen Seraph", "the Dawnbringer", "the Voidwalker", "the Ashen King",
  "the Stormcaller", "the Cursed", "the Unbroken", "the Wraith King", "the Sky Empress",
  "the Ember Sovereign", "the Nightblade", "of the Abyss", "the Ironheart", "the Sunfire Saint",
  "the Hollow Prince", "the Frost Warden", "the Bloodmoon", "the Silverwing", "the Gravekeeper",
  "the Oathbreaker", "the Ashfall", "the Starforged", "the Duskwalker", "the Ravenlord",
];

export const DESCRIPTIONS = [
  "A wanderer whose blade has ended a thousand battles.",
  "Bound by an ancient pact, their power comes at a price.",
  "Cast out from their kin, they fight for a new purpose.",
  "A relic of a forgotten age, awakened for one final war.",
  "Feared and revered in equal measure across every realm.",
  "Once a guardian of the old order, now a legend reborn.",
  "Their name alone is enough to silence a battlefield.",
  "Neither wholly good nor evil — only relentless.",
];

export const ABILITIES: Record<Role, { basic: string[]; ult: string[] }> = {
  Tank: {
    basic: ["Shield Bash", "Iron Slam", "Bulwark Strike", "Guard Break", "Stonefist"],
    ult: ["Fortress Stand", "Unbreakable Wall", "Titan's Resolve", "Last Bastion", "Aegis Overload"],
  },
  DPS: {
    basic: ["Power Blast", "Flame Strike", "Frost Nova", "Blade Rush", "Piercing Shot"],
    ult: ["Inferno Breaker", "Absolute Zero", "Meteor Fall", "Ravaging Storm", "Judgment Beam"],
  },
  Assassin: {
    basic: ["Shadow Strike", "Dawnpiercer", "Silent Fang", "Backstab", "Venom Edge"],
    ult: ["Thousand Cuts", "Judgment of Dawn", "Death's Embrace", "Nightfall Execution", "Reaper's Waltz"],
  },
  Healer: {
    basic: ["Healing Wave", "Mending Light", "Restorative Pulse", "Sacred Touch", "Verdant Bloom"],
    ult: ["Radiant Rebirth", "Dawn's Grace", "Miracle of Life", "Sanctuary Blessing", "Eternal Spring"],
  },
  Support: {
    basic: ["Rally Cry", "Encouraging Verse", "Windsong", "Battle Hymn", "Guiding Light"],
    ult: ["Crescendo", "Ballad of Courage", "Anthem of Ages", "Unity Surge", "Grand Overture"],
  },
};

/**
 * Chance a card that qualifies rolls a build-defining legendary skill.
 * Gated behind the top rarities, so pulling one is an event.
 */
const LEGENDARY_SKILL_CHANCE = 0.4;

/**
 * Picks the card's passive.
 *
 * Every card gets one. The rarity curve is deliberately brutal — roughly
 * four cards in five are Common — so gating passives behind rarity, as the
 * old three-passive system did, left about 2% of the roster carrying a
 * skill and made the library effectively invisible. Rarity instead governs
 * which families are reachable and how hard the card's stats hit; the
 * passive is what makes each card mechanically distinct.
 */
export function pickSkillId(role: Role, rarity: Rarity, r: Rng | typeof rng): string {
  const apex = Config.rarityIndex(rarity) >= Config.rarityIndex("Legendary");

  let family: SkillFamily;
  if (apex && r.randf() < LEGENDARY_SKILL_CHANCE) {
    family = "legendary";
  } else {
    const pool = ROLE_FAMILIES[role] ?? ["offense"];
    family = pool[r.randi(pool.length)];
  }

  const options = skillsInFamily(family);
  if (options.length === 0) return "";
  return options[r.randi(options.length)].id;
}

/**
 * The opening hand. Seeded per name so a starter rolls identical stats on
 * every launch — mirrors CardGenerator.build_starters() in the Godot project.
 */
export function buildStarters(): CardData[] {
  return Config.STARTER_ARCHETYPES.map((archetype) => {
    const r = new Rng(`starter:${archetype.name}`);
    const base = Config.statsForRarity(archetype.rarity);
    const shape = Config.ROLE_STATS[archetype.role];
    const options = ABILITIES[archetype.role];

    return makeCard({
      cardId: `starter_${archetype.name.toLowerCase().replace(/ /g, "_")}`,
      cardName: archetype.name,
      role: archetype.role,
      rarity: archetype.rarity,
      element: archetype.element,
      modifier: "Normal",
      originTag: "starter",
      faction: r.pick(Config.FACTIONS),
      description: r.pick(DESCRIPTIONS),
      sellValue: Config.sellValueForRarity(archetype.rarity),
      attack: Math.max(5, Math.floor(r.randfRange(base.attack[0], base.attack[1]) * shape.attack)),
      defense: Math.max(3, Math.floor(r.randfRange(base.defense[0], base.defense[1]) * shape.defense)),
      health: Math.max(60, Math.floor(r.randfRange(base.health[0], base.health[1]) * shape.health)),
      speed: Math.max(4, Math.floor(r.randfRange(base.speed[0], base.speed[1]) * shape.speed)),
      basicAbility: r.pick(options.basic),
      ultimateAbility: r.pick(options.ult),
      skillId: pickSkillId(archetype.role, archetype.rarity, r),
      basicTargetMode: "active",
      ultimateTargetMode: "active",
    });
  });
}

export function generateBatch(count: number, usedNames: Set<string>): CardData[] {
  const results: CardData[] = [];
  const limit = count * 25;
  let attempts = 0;

  while (results.length < count && attempts < limit) {
    attempts++;
    const card = generateOne(usedNames);
    if (card) results.push(card);
  }
  return results;
}

let generatedSequence = 0;

export function generateOne(usedNames: Set<string>): CardData | null {
  const named = rollName();
  if (usedNames.has(named.name)) return null;
  usedNames.add(named.name);

  const rarity = rollRarity();
  const role = rng.pick(Config.ROLES);
  const base = Config.statsForRarity(rarity);
  const shape = Config.ROLE_STATS[role];
  const options = ABILITIES[role];

  const card = makeCard({
    cardId: `gen_${generatedSequence++}`,
    cardName: named.name,
    originTag: named.origin,
    description: rng.pick(DESCRIPTIONS),
    faction: rng.pick(Config.FACTIONS),
    element: rng.pick(Config.ELEMENTS),
    role,
    rarity,
    modifier: "Normal",
    sellValue: Config.sellValueForRarity(rarity),
    attack: Math.max(5, Math.floor(rng.randfRange(base.attack[0], base.attack[1]) * shape.attack)),
    defense: Math.max(3, Math.floor(rng.randfRange(base.defense[0], base.defense[1]) * shape.defense)),
    health: Math.max(60, Math.floor(rng.randfRange(base.health[0], base.health[1]) * shape.health)),
    speed: Math.max(4, Math.floor(rng.randfRange(base.speed[0], base.speed[1]) * shape.speed)),
    basicAbility: rng.pick(options.basic),
    ultimateAbility: rng.pick(options.ult),
    skillId: pickSkillId(role, rarity, rng),
  });

  applyTargeting(card, role);
  return card;
}

export function rollName(): { name: string; origin: string } {
  const origin = rng.pick(ORIGINS);
  let chosen = rng.pick(NAME_POOLS[origin]);
  if (rng.randf() < 0.55) chosen += ` ${rng.pick(TITLES)}`;
  return { name: chosen, origin };
}

/**
 * Awakened is reserved for cards the player supplies artwork for, so
 * procedurally-named filler can never occupy the apex tier.
 */
export function rollRarity(): Rarity {
  const eligible = Config.RARITY_ORDER.filter((r) => !Config.ART_ONLY_RARITIES.includes(r));
  const total = eligible.reduce((sum, r) => sum + Config.RARITY_WEIGHTS[r], 0);

  let roll = rng.randf() * total;
  for (const rarity of eligible) {
    roll -= Config.RARITY_WEIGHTS[rarity];
    if (roll <= 0) return rarity;
  }
  return "Common";
}

function applyTargeting(card: CardData, role: Role): void {
  card.basicTargetMode = "active";
  card.ultimateTargetMode = "active";

  if (role === "Assassin") {
    if (rng.randf() < 0.6) card.basicTargetMode = "backline";
    if (rng.randf() < 0.35) card.ultimateTargetMode = "aoe";
  } else if (role === "DPS") {
    if (rng.randf() < 0.25) card.basicTargetMode = "aoe";
    if (rng.randf() < 0.4) card.ultimateTargetMode = "aoe";
  } else if (rng.randf() < 0.15) {
    card.ultimateTargetMode = "aoe";
  }
}

