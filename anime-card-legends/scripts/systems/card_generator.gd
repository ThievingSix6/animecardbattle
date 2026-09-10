class_name CardGenerator
extends RefCounted

# =========================================================
# Procedurally generates flavourful, mechanically distinct cards so
# the pool can hold hundreds of pulls without hand-authoring each one.
# All balance numbers come from Config; this file owns only flavour.
# =========================================================

const NAME_POOLS := {
	"demon": [
		"Azmodeus", "Belphegor", "Mammon", "Asmodai", "Baalzeth", "Moloch", "Abaddon",
		"Naberius", "Furfur", "Malzeth", "Vorkanth", "Drazuul", "Kaz'rok", "Xanathis", "Grimwrath",
	],
	"angel": [
		"Seraphiel", "Uriel", "Raziel", "Ariel", "Michaela", "Gabriela", "Zophiel",
		"Camael", "Haniel", "Metatron", "Ithuriel", "Sariel", "Remiel", "Jerahmeel", "Azrael",
	],
	"lord": [
		"Thane", "Varek", "Osric", "Dravyn", "Kestrel", "Isolde", "Brannor",
		"Sable", "Rowena", "Alaric", "Corvin", "Elowen", "Tamsin", "Ysolde", "Baldric",
	],
	"anime": [
		"Sora", "Kaida", "Yumeko", "Haru", "Akira", "Rin", "Suzume",
		"Kenji", "Nagisa", "Tsubaki", "Ryunosuke", "Aoi", "Hikari", "Shirou", "Yuzuki",
	],
	"primordial": [
		"Nyx", "Erebos", "Lilith", "Astaroth", "Ishtar", "Morrigan", "Hecate",
		"Persepha", "Tiamat", "Ereshkigal", "Nemhain", "Hel", "Kali", "Circe", "Medea",
		"Lucienne", "Aurelia", "Cassiel", "Solveig", "Thoril", "Grendal", "Vashti",
		"Zaruel", "Ophira", "Malakor", "Fenwick", "Ondine", "Rhiannon", "Caspian", "Nerissa",
	],
}

const ORIGINS: Array[String] = ["demon", "angel", "lord", "anime", "primordial"]

const TITLES: Array[String] = [
	"the Demon Lord", "the Fallen Seraph", "the Dawnbringer", "the Voidwalker", "the Ashen King",
	"the Stormcaller", "the Cursed", "the Unbroken", "the Wraith King", "the Sky Empress",
	"the Ember Sovereign", "the Nightblade", "of the Abyss", "the Ironheart", "the Sunfire Saint",
	"the Hollow Prince", "the Frost Warden", "the Bloodmoon", "the Silverwing", "the Gravekeeper",
	"the Oathbreaker", "the Ashfall", "the Starforged", "the Duskwalker", "the Ravenlord",
]

const DESCRIPTIONS: Array[String] = [
	"A wanderer whose blade has ended a thousand battles.",
	"Bound by an ancient pact, their power comes at a price.",
	"Cast out from their kin, they fight for a new purpose.",
	"A relic of a forgotten age, awakened for one final war.",
	"Feared and revered in equal measure across every realm.",
	"Once a guardian of the old order, now a legend reborn.",
	"Their name alone is enough to silence a battlefield.",
	"Neither wholly good nor evil — only relentless.",
]

const MODIFIERS: Array[String] = ["Normal", "Normal", "Normal", "Normal", "Shiny", "Golden", "Awakened"]

const ABILITIES := {
	"Tank": {
		"basic": ["Shield Bash", "Iron Slam", "Bulwark Strike", "Guard Break", "Stonefist"],
		"ult":   ["Fortress Stand", "Unbreakable Wall", "Titan's Resolve", "Last Bastion", "Aegis Overload"],
	},
	"DPS": {
		"basic": ["Power Blast", "Flame Strike", "Frost Nova", "Blade Rush", "Piercing Shot"],
		"ult":   ["Inferno Breaker", "Absolute Zero", "Meteor Fall", "Ravaging Storm", "Judgment Beam"],
	},
	"Assassin": {
		"basic": ["Shadow Strike", "Dawnpiercer", "Silent Fang", "Backstab", "Venom Edge"],
		"ult":   ["Thousand Cuts", "Judgment of Dawn", "Death's Embrace", "Nightfall Execution", "Reaper's Waltz"],
	},
	"Healer": {
		"basic": ["Healing Wave", "Mending Light", "Restorative Pulse", "Sacred Touch", "Verdant Bloom"],
		"ult":   ["Radiant Rebirth", "Dawn's Grace", "Miracle of Life", "Sanctuary Blessing", "Eternal Spring"],
	},
	"Support": {
		"basic": ["Rally Cry", "Encouraging Verse", "Windsong", "Battle Hymn", "Guiding Light"],
		"ult":   ["Crescendo", "Ballad of Courage", "Anthem of Ages", "Unity Surge", "Grand Overture"],
	},
}



# The opening hand. Seeded per name so a starter rolls identical stats on
# every launch and across save files.
static func build_starters() -> Array[CardData]:
	var out: Array[CardData] = []
	for archetype in Config.STARTER_ARCHETYPES:
		var name_text := str(archetype["name"])
		var role := str(archetype["role"])
		var rarity := str(archetype["rarity"])

		var rng := RandomNumberGenerator.new()
		rng.seed = hash("starter:" + name_text)

		var card := CardData.new()
		card.card_id = "starter_" + name_text.to_lower().replace(" ", "_")
		card.card_name = name_text
		card.role = role
		card.rarity = rarity
		card.element = str(archetype["element"])
		card.modifier = "Normal"
		card.origin_tag = "starter"
		card.faction = Config.FACTIONS[rng.randi() % Config.FACTIONS.size()]
		card.description = DESCRIPTIONS[rng.randi() % DESCRIPTIONS.size()]
		card.sell_value = Config.sell_value_for_rarity(rarity)

		var base := Config.stats_for_rarity(rarity)
		var shape: Dictionary = Config.ROLE_STATS[role]
		card.attack  = max(5,  int(rng.randf_range(base["attack"][0],  base["attack"][1])  * shape["attack"]))
		card.defense = max(3,  int(rng.randf_range(base["defense"][0], base["defense"][1]) * shape["defense"]))
		card.health  = max(60, int(rng.randf_range(base["health"][0],  base["health"][1])  * shape["health"]))
		card.speed   = max(4,  int(rng.randf_range(base["speed"][0],   base["speed"][1])   * shape["speed"]))

		var options: Dictionary = ABILITIES.get(role, ABILITIES["DPS"])
		card.basic_ability = options["basic"][rng.randi() % options["basic"].size()]
		card.ultimate_ability = options["ult"][rng.randi() % options["ult"].size()]
		card.skill_id = Skills.pick_for(role, rarity, rng)
		card.basic_target_mode = "active"
		card.ultimate_target_mode = "active"
		card.banner_id = Banners.banner_for(card.element, role)
		Leveling.apply(card)

		out.append(card)
	return out


static func generate_batch(count: int, used_names: Dictionary) -> Array[CardData]:
	var results: Array[CardData] = []
	var attempts := 0
	var limit := count * 25

	while results.size() < count and attempts < limit:
		attempts += 1
		var card := generate_one(used_names)
		if card:
			results.append(card)

	return results


static func generate_one(used_names: Dictionary) -> CardData:
	var named := roll_name()
	if used_names.has(named["name"]):
		return null
	used_names[named["name"]] = true

	var rarity := roll_rarity()
	var role: String = Config.ROLES[randi() % Config.ROLES.size()]

	var card := CardData.new()
	card.card_id = "gen_%d_%d" % [Time.get_ticks_usec(), randi() % 100000]
	card.card_name = named["name"]
	card.origin_tag = named["origin"]
	card.description = DESCRIPTIONS[randi() % DESCRIPTIONS.size()]
	card.faction = Config.FACTIONS[randi() % Config.FACTIONS.size()]
	card.element = Config.ELEMENTS[randi() % Config.ELEMENTS.size()]
	card.role = role
	card.rarity = rarity
	card.modifier = MODIFIERS[randi() % MODIFIERS.size()]
	card.sell_value = Config.sell_value_for_rarity(rarity)

	_apply_stats(card, rarity, role)
	_apply_abilities(card, role)
	_apply_targeting(card, role)
	card.banner_id = Banners.banner_for(card.element, role)
	Leveling.apply(card)
	return card


static func roll_name() -> Dictionary:
	var origin: String = ORIGINS[randi() % ORIGINS.size()]
	var pool: Array = NAME_POOLS[origin]
	var chosen: String = pool[randi() % pool.size()]
	if randf() < 0.55:
		chosen += " " + TITLES[randi() % TITLES.size()]
	return {"name": chosen, "origin": origin}


# Awakened is reserved for cards the player supplies artwork for, so
# procedurally-named filler can never occupy the apex tier.
static func roll_rarity() -> String:
	var total := 0.0
	for rarity in Config.RARITY_ORDER:
		if rarity in Config.ART_ONLY_RARITIES:
			continue
		total += Config.RARITY_WEIGHTS[rarity]

	var roll := randf() * total
	var cumulative := 0.0
	for rarity in Config.RARITY_ORDER:
		if rarity in Config.ART_ONLY_RARITIES:
			continue
		cumulative += Config.RARITY_WEIGHTS[rarity]
		if roll <= cumulative:
			return rarity
	return "Common"


static func _apply_stats(card: CardData, rarity: String, role: String) -> void:
	var base := Config.stats_for_rarity(rarity)
	var shape: Dictionary = Config.ROLE_STATS[role]

	card.attack  = max(5,  int(randf_range(base["attack"][0],  base["attack"][1])  * shape["attack"]))
	card.defense = max(3,  int(randf_range(base["defense"][0], base["defense"][1]) * shape["defense"]))
	card.health  = max(60, int(randf_range(base["health"][0],  base["health"][1])  * shape["health"]))
	card.speed   = max(4,  int(randf_range(base["speed"][0],   base["speed"][1])   * shape["speed"]))


static func _apply_abilities(card: CardData, role: String) -> void:
	var options: Dictionary = ABILITIES.get(role, ABILITIES["DPS"])
	card.basic_ability = options["basic"][randi() % options["basic"].size()]
	card.ultimate_ability = options["ult"][randi() % options["ult"].size()]
	card.skill_id = Skills.pick_for(role, card.rarity)


static func _apply_targeting(card: CardData, role: String) -> void:
	card.basic_target_mode = "active"
	card.ultimate_target_mode = "active"
	match role:
		"Assassin":
			if randf() < 0.6:
				card.basic_target_mode = "backline"
			if randf() < 0.35:
				card.ultimate_target_mode = "aoe"
		"DPS":
			if randf() < 0.25:
				card.basic_target_mode = "aoe"
			if randf() < 0.4:
				card.ultimate_target_mode = "aoe"
		_:
			if randf() < 0.15:
				card.ultimate_target_mode = "aoe"


