class_name Config
extends RefCounted

# =========================================================
# GAME TUNING - every balance number in one auditable place.
# Systems read from here; they never define their own constants.
# =========================================================

# ---------------- RARITY ----------------
const RARITY_ORDER: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Awakened"]

# Relative pull weights. Deliberately astronomical at the top end so the
# highest tier sits around a one-in-a-trillion pull.
const RARITY_WEIGHTS := {
	"Common":    1000000.0,
	"Uncommon":   200000.0,
	"Rare":        40000.0,
	"Epic":         8000.0,
	"Legendary":    1600.0,
	"Mythic":        100.0,
	"Secret":          0.000001,
	"Awakened":        0.00000001,
}

# Rarities that can never appear from an ordinary roll of the name pool -
# they are reserved for cards explicitly marked in their art filename.
const ART_ONLY_RARITIES: Array[String] = ["Awakened"]

# ---------------- STAT SCALING ----------------
# Common is the baseline; each tier multiplies it. Speed grows far more
# slowly than power so turn order stays meaningful at high rarity.
const BASE_STATS := {
	"attack": [12, 18], "defense": [6, 12], "health": [80, 110], "speed": [6, 10],
}
const STAT_GROWTH := 1.8
const SPEED_GROWTH := 1.12
const SELL_BASE := 10.0
const SELL_GROWTH := 4.0

const ROLE_STATS := {
	"Tank":     {"attack": 0.55, "defense": 1.8,  "health": 1.7,  "speed": 0.65},
	"DPS":      {"attack": 1.15, "defense": 0.75, "health": 0.95, "speed": 1.0},
	"Assassin": {"attack": 1.25, "defense": 0.5,  "health": 0.75, "speed": 1.35},
	"Healer":   {"attack": 0.6,  "defense": 0.9,  "health": 1.1,  "speed": 1.1},
	"Support":  {"attack": 0.75, "defense": 0.9,  "health": 1.0,  "speed": 1.15},
}

const ROLES: Array[String] = ["Tank", "DPS", "Assassin", "Healer", "Support"]
const ELEMENTS: Array[String] = ["Fire", "Water", "Earth", "Wind", "Light", "Dark"]
const FACTIONS: Array[String] = ["Ember Order", "Voidbound Covenant", "Silver Choir", "Wraithspire Legion", "Sunfall Dominion"]

# ---------------- ECONOMY ----------------
const START_GEMS := 1000
const START_GOLD := 10000
const SUMMON_COST_X1 := 100
const SUMMON_COST_X10 := 900

const MERGE_REQUIREMENT := 100
const MERGE_STAT_GROWTH := 1.8
const MERGE_SPEED_GROWTH := 1.12
const MERGE_SELL_GROWTH := 4.0

# ---------------- TALENTS ----------------
const TALENT_MAX := {"speed": 20, "luck": 20, "multi": 2}
const TALENT_BASE_COST := {"speed": 200, "luck": 250, "multi": 8000}
const TALENT_COST_GROWTH := 1.35

const ROLL_INTERVAL_BASE := 3.0
const ROLL_INTERVAL_MIN := 0.4
const ROLL_INTERVAL_PER_LEVEL := 0.13
const LUCK_PER_LEVEL := 0.02

# ---------------- TOWER / CAMPAIGN ----------------
# Six zones of seven stages. BOSS_EVERY matches Campaign.STAGES_PER_ZONE,
# which is what makes the last stage of every zone a boss fight.
const MAX_FLOOR := 42
const BOSS_EVERY := 7
const FLOOR_STAT_SCALE := 0.12
const BOSS_STAT_MULT := 1.6
const FLOOR_GEM_BASE := 20
const FLOOR_GEM_PER := 5
const FLOOR_GOLD_BASE := 200
const FLOOR_GOLD_PER := 50

# ---------------- BATTLE ----------------
const ROUND_INTERVAL := 1.0
const BASIC_ABILITY_EVERY := 3
const ENERGY_PER_ATTACK := 25
const ENERGY_MAX := 100
const DEFENSE_FACTOR := 0.35
const BASIC_ABILITY_MULT := 1.5
const ULTIMATE_MULT := 3.0

# ---------------- WEATHER EVENTS ----------------
const EVENT_DURATION := 300.0
const EVENT_CHECK_MIN := 300.0
const EVENT_CHECK_MAX := 900.0
const EVENT_CHANCE := 0.35
const EVENT_LUCK_MULT := 2.0
const EVENT_ELEMENT_WEIGHT := 3   # boosted element counts this many times in the pool

const WEATHER_EVENTS: Array[Dictionary] = [
	{"id": "meteor_storm",  "name": "☄️ Meteor Storm",  "element": "Fire",  "desc": "Fire-aligned units surge in power and appear far more often."},
	{"id": "lunar_eclipse", "name": "🌑 Lunar Eclipse",  "element": "Dark",  "desc": "Dark-aligned units are unusually common right now."},
	{"id": "aurora_veil",   "name": "🌌 Aurora Veil",    "element": "Light", "desc": "Light-aligned units shine brighter than usual."},
	{"id": "tempest",       "name": "🌪️ Tempest",        "element": "Wind",  "desc": "Wind-aligned units are swept into abundance."},
	{"id": "tidal_surge",   "name": "🌊 Tidal Surge",    "element": "Water", "desc": "Water-aligned units flood the pool."},
	{"id": "tremor",        "name": "⛰️ Tremor",         "element": "Earth", "desc": "Earth-aligned units rise up."},
]

# ---------------- ROLL PACKS ----------------
const ROLL_PACKS := {
	"bronze": {"label": "Bronze Roll Pack", "rolls": 10000},
	"gold":   {"label": "Gold Roll Pack",   "rolls": 1000000},
	"boss":   {"label": "Boss Conquest Pack", "rolls": 100000000},
}

# ---------------- BANNERS ----------------
const ORIGINS: Array[String] = ["", "demon", "angel", "lord", "anime", "primordial"]
const ORIGIN_LABELS := {
	"": "All Origins", "demon": "Demon", "angel": "Angel",
	"lord": "Lords", "anime": "Anime", "primordial": "Primordial",
}

# ---------------- STARTING ROSTER ----------------
# Declared as plain data rather than resource files: stats are derived
# from the rarity/role curves above, so a starter can never drift out of
# balance with the rest of the roster.
const STARTER_ARCHETYPES: Array[Dictionary] = [
	{"name": "Vanguard Recruit",    "role": "Tank",     "element": "Earth", "rarity": "Rare"},
	{"name": "Emberblade Cadet",    "role": "DPS",      "element": "Fire",  "rarity": "Rare"},
	{"name": "Duskstep Adept",      "role": "Assassin", "element": "Dark",  "rarity": "Rare"},
	{"name": "Lightwarden Acolyte", "role": "Healer",   "element": "Light", "rarity": "Rare"},
	{"name": "Galewind Herald",     "role": "Support",  "element": "Wind",  "rarity": "Rare"},
]

const GENERATED_CARD_COUNT := 200


static func rarity_index(rarity: String) -> int:
	var i := RARITY_ORDER.find(rarity)
	if i >= 0:
		return i
	return 0

static func next_rarity(rarity: String) -> String:
	var i := rarity_index(rarity)
	if i >= RARITY_ORDER.size() - 1:
		return ""
	return RARITY_ORDER[i + 1]

# Stat range for a rarity, derived from the Common baseline.
static func stats_for_rarity(rarity: String) -> Dictionary:
	var t := rarity_index(rarity)
	var m: float = pow(STAT_GROWTH, t)
	var sm: float = pow(SPEED_GROWTH, t)
	return {
		"attack":  [BASE_STATS["attack"][0] * m,  BASE_STATS["attack"][1] * m],
		"defense": [BASE_STATS["defense"][0] * m, BASE_STATS["defense"][1] * m],
		"health":  [BASE_STATS["health"][0] * m,  BASE_STATS["health"][1] * m],
		"speed":   [BASE_STATS["speed"][0] * sm,  BASE_STATS["speed"][1] * sm],
	}

static func sell_value_for_rarity(rarity: String) -> int:
	return int(round(SELL_BASE * pow(SELL_GROWTH, rarity_index(rarity))))
