class_name EnemyFactory
extends RefCounted

# =========================================================
# Builds the opposing team for a floor. Separated from both the
# simulation and the view so encounter design can evolve on its own.
#
# Enemy identity comes from the campaign zone that owns the floor, so a
# zone's roster is declared in exactly one place (scripts/core/campaign.gd)
# and the 3D world, the zone select, and the fight always agree.
# =========================================================

const BASE := {"attack": 18.0, "defense": 20.0, "health": 200.0, "speed": 8.0}


static func tier_for(floor_number: int) -> Dictionary:
	return Campaign.zone_for_floor(floor_number)


static func build_floor(floor_number: int, progression: ProgressionSystem) -> Array[CardData]:
	var tier := tier_for(floor_number)
	var count := progression.enemy_count(floor_number)
	var scale := progression.stat_multiplier(floor_number)

	var out: Array[CardData] = []
	for i in count:
		var is_boss: bool = (i == count - 1) and progression.is_boss_floor(floor_number)
		out.append(_build(tier, floor_number, i, scale, is_boss))
	return out


# The clan raid boss: one enormous target, scaled by clan level. Its HP
# here is only what the player fights through in a single sortie - the
# shared pool the whole clan chips away at lives on ClanSystem.
static func build_raid(clan_level: int, boss_name: String) -> Array[CardData]:
	var scale := 1.0 + float(clan_level) * 0.45

	var boss := CardData.new()
	boss.card_id = "raid_boss"
	boss.card_name = boss_name
	boss.role = "Tank"
	boss.rarity = "Mythic"
	boss.modifier = "Normal"
	boss.element = "Dark"
	boss.origin_tag = "raid"
	boss.basic_ability = "Sunder"
	boss.ultimate_ability = "World Ender"
	boss.basic_target_mode = "aoe"
	boss.ultimate_target_mode = "aoe"
	boss.skill_id = "ironhide"

	var shape: Dictionary = Config.ROLE_STATS["Tank"]
	boss.attack  = max(5,  int(BASE["attack"]  * scale * 1.8 * shape["attack"]))
	boss.defense = max(3,  int(BASE["defense"] * scale * 1.8 * shape["defense"]))
	boss.health  = max(60, int(BASE["health"]  * scale * 9.0 * shape["health"]))
	boss.speed   = max(4,  int(BASE["speed"]   * scale * shape["speed"]))

	var out: Array[CardData] = [boss]
	return out


# ---------------- THE HELLFIRE GAUNTLET ----------------

# One wave of Diablo's challenge. The captain of each wave is the named
# enemy from the wave table; the rest are its rank and file.
static func build_gauntlet_wave(wave_index: int) -> Array[CardData]:
	var wave := Gauntlet.wave(wave_index)
	var count: int = int(wave["count"])
	var scale: float = float(wave["scale"])
	var is_final := Gauntlet.is_final(wave_index)

	var out: Array[CardData] = []
	for i in count:
		var is_captain := i == count - 1
		out.append(_build_hellfire(wave_index, i, scale, is_captain, is_final))
	return out


static func _build_hellfire(wave_index: int, slot: int, scale: float, is_captain: bool, is_final: bool) -> CardData:
	var enemy := CardData.new()
	enemy.card_id = "gauntlet_%d_%d" % [wave_index, slot]
	enemy.element = Gauntlet.ELEMENT
	enemy.origin_tag = "gauntlet"
	enemy.modifier = "Normal"

	var role := "DPS"
	var role_pool: Array[String] = ["DPS", "Tank", "Assassin", "Support"]
	if not is_captain:
		role = role_pool[randi() % role_pool.size()]
		enemy.card_name = Gauntlet.MINION_NAMES[randi() % Gauntlet.MINION_NAMES.size()]
		enemy.rarity = "Rare"
		enemy.basic_ability = "Sear"
		enemy.ultimate_ability = "Immolate"
		enemy.skill_id = "cinderbrand"
	else:
		role = "Tank"
		enemy.card_name = str(Gauntlet.wave(wave_index)["captain"])
		enemy.rarity = "Legendary"
		enemy.basic_ability = "Hateful Blow"
		enemy.ultimate_ability = "Hellfire"
		enemy.basic_target_mode = "aoe"
		enemy.ultimate_target_mode = "aoe"
		enemy.skill_id = "ironhide"

	# Diablo himself: the only enemy in the game that is genuinely
	# supposed to feel unfair on the first attempt.
	var captain_mult := 1.0
	if is_captain:
		captain_mult = 1.7
	if is_captain and is_final:
		captain_mult = 2.6
		enemy.rarity = "Mythic"
		enemy.card_name = Gauntlet.BOSS_NAME
		enemy.skill_id = "last_stand"

	enemy.role = role
	var shape: Dictionary = Config.ROLE_STATS.get(role, Config.ROLE_STATS["DPS"])

	enemy.attack  = max(5,  int(BASE["attack"]  * scale * captain_mult * shape["attack"] * 1.35))
	enemy.defense = max(3,  int(BASE["defense"] * scale * captain_mult * shape["defense"] * 1.2))
	enemy.health  = max(60, int(BASE["health"]  * scale * captain_mult * shape["health"] * 1.5))
	enemy.speed   = max(4,  int(BASE["speed"]   * scale * shape["speed"]))

	Leveling.apply(enemy)
	return enemy


# ---------------- THE BOY ----------------

# The strongest deck in the game, and deliberately not scaled off the
# player's own team: he is a wall you come back to, not a mirror match.
# Five apex cards, each built to be the best example of its role.
const BOY_DECK: Array[Dictionary] = [
	{"name": "First Light",    "role": "Tank",     "element": "Light", "skill": "ironhide"},
	{"name": "Nine Cuts",      "role": "Assassin", "element": "Dark",  "skill": "executioners_mark"},
	{"name": "The Long Note",  "role": "Support",  "element": "Wind",  "skill": "rallying_cry"},
	{"name": "Quiet Hour",     "role": "Healer",   "element": "Water", "skill": "lifebloom"},
	{"name": "Last Word",      "role": "DPS",      "element": "Fire",  "skill": "kingbreaker"},
]

const BOY_SCALE := 5.2


static func build_boy_deck() -> Array[CardData]:
	var out: Array[CardData] = []

	for i in BOY_DECK.size():
		var entry: Dictionary = BOY_DECK[i]
		var role := str(entry["role"])
		var shape: Dictionary = Config.ROLE_STATS.get(role, Config.ROLE_STATS["DPS"])

		var card := CardData.new()
		card.card_id = "boy_%d" % i
		card.card_name = str(entry["name"])
		card.role = role
		card.element = str(entry["element"])
		card.rarity = "Secret"
		card.modifier = "Normal"
		card.origin_tag = "boy"
		card.basic_ability = "Perfect Form"
		card.ultimate_ability = "Nothing Wasted"
		card.basic_target_mode = "active"
		card.ultimate_target_mode = "aoe"
		card.skill_id = str(entry["skill"])

		card.attack  = max(5,  int(BASE["attack"]  * BOY_SCALE * shape["attack"] * 1.4))
		card.defense = max(3,  int(BASE["defense"] * BOY_SCALE * shape["defense"] * 1.3))
		card.health  = max(60, int(BASE["health"]  * BOY_SCALE * shape["health"] * 1.6))
		card.speed   = max(4,  int(BASE["speed"]   * BOY_SCALE * shape["speed"]))

		Leveling.apply(card)
		out.append(card)

	return out


static func _build(tier: Dictionary, floor_number: int, slot: int, scale: float, is_boss: bool) -> CardData:
	var names: Array = tier["names"]
	var roles: Array = tier["roles"]
	var role: String = "Tank"
	if not is_boss:
		role = str(roles[randi() % roles.size()])
	var shape: Dictionary = Config.ROLE_STATS.get(role, Config.ROLE_STATS["DPS"])
	var boss_mult := 1.0
	if is_boss:
		boss_mult = Config.BOSS_STAT_MULT

	var enemy := CardData.new()
	enemy.card_id = "enemy_%d_%d" % [floor_number, slot]
	enemy.card_name = str(names[randi() % names.size()])
	if is_boss:
		enemy.card_name = str(tier["boss"])
	enemy.role = role
	enemy.rarity = "Common"
	if is_boss:
		enemy.rarity = "Legendary"
	enemy.modifier = "Normal"
	enemy.element = str(tier["element"])
	enemy.basic_ability = "Strike"
	enemy.ultimate_ability = "Heavy Strike"
	if is_boss:
		enemy.basic_ability = "Crushing Blow"
		enemy.ultimate_ability = "Devastation"

	enemy.attack  = max(5,  int(BASE["attack"]  * scale * boss_mult * shape["attack"]))
	enemy.defense = max(3,  int(BASE["defense"] * scale * boss_mult * shape["defense"]))
	enemy.health  = max(60, int(BASE["health"]  * scale * boss_mult * shape["health"]))
	enemy.speed   = max(4,  int(BASE["speed"]   * scale * shape["speed"]))

	return enemy
