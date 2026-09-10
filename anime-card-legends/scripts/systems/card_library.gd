class_name CardLibrary
extends RefCounted

# =========================================================
# Builds the card roster directly from the images in res://art/cards/.
#
# Drop in "ashen_knight.png" and you get a card called "Ashen Knight"
# using that image. Nothing to register, no list to maintain.
#
# FILENAME RULES
#   ashen_knight.png            -> "Ashen Knight", rarity rolled from the name
#   ashen_knight_awakened.png   -> "Ashen Knight" at AWAKENED rarity (apex tier)
#   ashen_knight_legendary.png  -> "Ashen Knight" forced to Legendary
#   ashen_knight_shiny.png      -> "Ashen Knight" with the Shiny modifier
#
# Everything about a card - rarity, role, element, stats, abilities -
# is derived deterministically from its filename, so a given image
# always produces exactly the same card on every launch and across
# save files.
# =========================================================

const MODIFIER_SUFFIXES: Array[String] = ["awakened", "shiny", "golden", "corrupted", "divine"]

# Small words that stay lowercase inside a name.
const MINOR_WORDS: Array[String] = ["of", "the", "and", "in", "from", "de", "la"]


# The opening hand.
#
# When the player has supplied artwork, the starters come from it too, so
# every name in the game traces back to a file on disk. The five lowest
# rarities are taken, deterministically, so a fresh profile does not open
# holding a Mythic. With no art at all, the archetype hand in
# CardGenerator stands in.
static func starter_templates(count: int) -> Array[CardData]:
	var from_art := build_from_art()
	if from_art.size() < count:
		return CardGenerator.build_starters()

	from_art.sort_custom(func(a, b):
		var ra := Config.rarity_index(a.rarity)
		var rb := Config.rarity_index(b.rarity)
		if ra != rb:
			return ra < rb
		return a.card_name.naturalnocasecmp_to(b.card_name) < 0)

	var out: Array[CardData] = []
	for i in count:
		out.append(from_art[i])
	return out


static func build_from_art() -> Array[CardData]:
	var cards: Array[CardData] = []
	var files := CardArt.list_files()

	for path in files:
		var card := card_from_path(path)
		if card != null:
			cards.append(card)

	return cards


static func card_from_path(path: String) -> CardData:
	var stem := path.get_file().get_basename().to_lower()
	if stem == "":
		return null

	var parsed := parse_stem(stem)
	var display_name: String = parsed["name"]
	if display_name == "":
		return null

	# Deterministic RNG seeded by filename: same file -> same card, always.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(stem)

	var card := CardData.new()
	card.card_id = "art_" + stem
	card.card_name = display_name
	card.rarity = parsed["rarity"]
	card.modifier = parsed["modifier"]
	card.origin_tag = "art"

	# The name is read first: "Ember Witch" should be Fire, "Grave Knight"
	# should be Dark. Only a name with nothing recognisable in it falls
	# back to the deterministic roll.
	card.role = role_for_name(display_name, rng)
	card.element = element_for_name(display_name, rng)
	card.faction = Config.FACTIONS[rng.randi() % Config.FACTIONS.size()]
	card.description = _flavour(display_name, card.rarity, rng)
	card.sell_value = Config.sell_value_for_rarity(card.rarity)

	# Pin the exact image. Without this, "grave_knight_awakened" resolves
	# by name back to grave_knight's picture.
	card.art_path = path
	card.banner_id = Banners.banner_for(card.element, card.role)

	_apply_stats(card, rng)
	_apply_abilities(card, rng)
	Leveling.apply(card)

	return card


# --- Reading the name --------------------------------------------------
#
# Keyword tables, longest match first. These are matched against whole
# words in the card name, so "Frostbound Warlord" is Water because of
# "frostbound", not because "war" appears somewhere inside it.

const ELEMENT_WORDS := {
	"Fire":  ["ember", "emberfall", "flame", "crimson", "phoenix", "blaze", "cinder",
		"ash", "ashen", "pyre", "inferno", "scorch", "solar", "sun", "sunforged",
		"magma", "forge", "wildfire"],
	"Water": ["frost", "frostbound", "tide", "abyss", "abyssal", "glacier", "glacial",
		"ice", "rime", "mist", "wave", "coral", "deep", "drown", "torrent", "glass"],
	"Earth": ["stone", "titan", "iron", "ironroot", "root", "forest", "mushroom", "grove",
		"mountain", "granite", "bramble", "thorn", "venom", "verdant", "moss", "oak",
		"wild", "wildfang", "beast", "fang", "claw", "savage", "boar", "tusk"],
	"Wind":  ["storm", "stormcaller", "gale", "tempest", "sky", "wind", "cyclone",
		"feather", "swift", "cloud", "thunder", "lightning"],
	"Light": ["moon", "moonblade", "lumen", "radiant", "dawn", "saint", "priestess",
		"halo", "seraph", "angel", "star", "prism", "crystal", "silver", "divine",
		"sacred", "paladin", "time", "dream", "dreamweaver", "chrono", "aether", "arcane"],
	"Dark":  ["shadow", "grave", "void", "reaper", "wraith", "phantom", "nightmare",
		"night", "dusk", "crow", "raven", "blood", "bone", "curse", "hex",
		"dread", "gloom", "obsidian", "duskmire"],
}

const ROLE_WORDS := {
	"Tank":     ["knight", "titan", "warden", "guardian", "bulwark", "sentinel",
		"paladin", "warlord", "bastion", "colossus", "shield", "juggernaut"],
	"DPS":      ["duelist", "berserker", "slayer", "blade", "swordsman", "gunner",
		"champion", "warrior", "brawler", "striker", "lancer", "fang"],
	"Assassin": ["assassin", "reaper", "rogue", "stalker", "hunter", "shade",
		"ronin", "shinobi", "ninja", "thief", "phantom", "blademaster"],
	"Healer":   ["healer", "priestess", "priest", "saint", "cleric", "medic",
		"oracle", "shepherd", "mender", "seraph"],
	"Support":  ["witch", "sage", "mage", "magus", "warlock", "weaver", "seer",
		"summoner", "scholar", "enchanter", "dreamweaver", "caller",
		"stormcaller", "conjurer", "bard"],
}


static func _words_of(display_name: String) -> Array[String]:
	var out: Array[String] = []
	for part in display_name.to_lower().split(" ", false):
		out.append(str(part))
	return out


# Longest keyword wins, so "moonblade" beats a bare "blade".
static func _match_table(display_name: String, table: Dictionary) -> String:
	var words := _words_of(display_name)
	var best := ""
	var best_length := 0

	for key in table.keys():
		var keywords: Array = table[key]
		for keyword in keywords:
			var needle := str(keyword)
			for word in words:
				if word == needle or word.contains(needle):
					if needle.length() > best_length:
						best_length = needle.length()
						best = str(key)
	return best


static func element_for_name(display_name: String, rng: RandomNumberGenerator) -> String:
	var found := _match_table(display_name, ELEMENT_WORDS)
	if found != "":
		return found
	return Config.ELEMENTS[rng.randi() % Config.ELEMENTS.size()]


static func role_for_name(display_name: String, rng: RandomNumberGenerator) -> String:
	var found := _match_table(display_name, ROLE_WORDS)
	if found != "":
		return found
	return Config.ROLES[rng.randi() % Config.ROLES.size()]


# --- Filename parsing ----------------------------------------------

static func parse_stem(stem: String) -> Dictionary:
	var parts := stem.split("_", false)
	var words: Array[String] = []
	for p in parts:
		words.append(str(p))

	var rarity := ""
	var modifier := "Normal"

	# Trailing tokens can declare a rarity and/or a modifier, in any order.
	var keep_scanning := true
	while keep_scanning and words.size() > 1:
		keep_scanning = false
		var last: String = words[words.size() - 1].to_lower()

		for r in Config.RARITY_ORDER:
			if last == r.to_lower():
				rarity = r
				words.remove_at(words.size() - 1)
				keep_scanning = true
				break
		if keep_scanning:
			continue

		if last in MODIFIER_SUFFIXES:
			modifier = last.capitalize()
			# "awakened" is both a modifier and the apex rarity.
			if last == "awakened":
				rarity = "Awakened"
			words.remove_at(words.size() - 1)
			keep_scanning = true

	if rarity == "":
		rarity = _roll_rarity_for(stem)

	return {"name": _title_case(words), "rarity": rarity, "modifier": modifier}


static func _title_case(words: Array[String]) -> String:
	var out: Array[String] = []
	for i in words.size():
		var w: String = words[i]
		if w == "":
			continue
		if i > 0 and w.to_lower() in MINOR_WORDS:
			out.append(w.to_lower())
		else:
			out.append(w.substr(0, 1).to_upper() + w.substr(1).to_lower())
	return " ".join(out)


# Deterministic rarity from the filename, so an unmarked image always
# lands on the same tier.
#
# This draws on the ROSTER curve, not the pull curve. Using the pull
# weights here would make around four in five images Common and leave
# nothing above Epic in the collection at all.
static func _roll_rarity_for(stem: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rarity:" + stem)

	var total := 0.0
	for r in Config.RARITY_ORDER:
		if r in Config.ART_ONLY_RARITIES:
			continue
		total += float(Config.ROSTER_RARITY_WEIGHTS[r])

	var roll := rng.randf() * total
	var cumulative := 0.0
	for r in Config.RARITY_ORDER:
		if r in Config.ART_ONLY_RARITIES:
			continue
		cumulative += float(Config.ROSTER_RARITY_WEIGHTS[r])
		if roll <= cumulative:
			return r
	return "Common"


# --- Card content ---------------------------------------------------

static func _apply_stats(card: CardData, rng: RandomNumberGenerator) -> void:
	var base := Config.stats_for_rarity(card.rarity)
	var shape: Dictionary = Config.ROLE_STATS[card.role]

	card.attack  = max(5,  int(rng.randf_range(base["attack"][0],  base["attack"][1])  * shape["attack"]))
	card.defense = max(3,  int(rng.randf_range(base["defense"][0], base["defense"][1]) * shape["defense"]))
	card.health  = max(60, int(rng.randf_range(base["health"][0],  base["health"][1])  * shape["health"]))
	card.speed   = max(4,  int(rng.randf_range(base["speed"][0],   base["speed"][1])   * shape["speed"]))


static func _apply_abilities(card: CardData, rng: RandomNumberGenerator) -> void:
	var options: Dictionary = CardGenerator.ABILITIES.get(card.role, CardGenerator.ABILITIES["DPS"])
	card.basic_ability = options["basic"][rng.randi() % options["basic"].size()]
	card.ultimate_ability = options["ult"][rng.randi() % options["ult"].size()]
	card.skill_id = Skills.pick_for(card.role, card.rarity, rng)

	card.basic_target_mode = "active"
	card.ultimate_target_mode = "active"

	var tier := Config.rarity_index(card.rarity)
	match card.role:
		"Assassin":
			if rng.randf() < 0.6:
				card.basic_target_mode = "backline"
			if rng.randf() < 0.35:
				card.ultimate_target_mode = "aoe"
		"DPS":
			if rng.randf() < 0.25:
				card.basic_target_mode = "aoe"
			if rng.randf() < 0.4:
				card.ultimate_target_mode = "aoe"
		_:
			if rng.randf() < 0.15:
				card.ultimate_target_mode = "aoe"

	# Apex cards always get a sweeping ultimate - they should feel special.
	if tier >= Config.rarity_index("Secret"):
		card.ultimate_target_mode = "aoe"




static func _flavour(display_name: String, rarity: String, rng: RandomNumberGenerator) -> String:
	if rarity == "Awakened":
		return "%s, awakened. Whatever limits once bound this power are gone." % display_name
	var pool := CardGenerator.DESCRIPTIONS
	return pool[rng.randi() % pool.size()]
