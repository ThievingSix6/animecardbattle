class_name EnemyFactory
extends RefCounted

# =========================================================
# Builds the opposing team for a tower floor. Separated from both
# the simulation and the view so encounter design can evolve on its own.
# =========================================================

const TIERS: Array[Dictionary] = [
	{"upto": 9,   "element": "",      "boss": "Golem Warlord", "names": ["Training Golem", "Rusted Automaton", "Stone Sentinel"], "roles": ["Tank", "DPS"]},
	{"upto": 19,  "element": "Earth", "boss": "Alpha Direwolf", "names": ["Feral Wolf", "Bandit Scout", "Marsh Lurker"], "roles": ["DPS", "Assassin", "Support"]},
	{"upto": 29,  "element": "Dark",  "boss": "The Bandit Kingpin", "names": ["Bandit Raider", "Rogue Mercenary", "Cutthroat"], "roles": ["DPS", "Assassin", "Tank"]},
	{"upto": 39,  "element": "Dark",  "boss": "High Cultist Mordrai", "names": ["Dark Cultist", "Shadow Acolyte", "Void Priest"], "roles": ["DPS", "Healer", "Support"]},
	{"upto": 49,  "element": "Light", "boss": "The Ancient Titan", "names": ["Ancient Guardian", "Fallen Knight", "Wraith Sentinel"], "roles": ["Tank", "DPS", "Assassin"]},
	{"upto": 9999,"element": "Dark",  "boss": "The Tower's Heart", "names": ["Tower Wraith", "Voidbound Horror", "Nameless Sentinel"], "roles": ["Tank", "DPS", "Assassin"]},
]

const BASE := {"attack": 18.0, "defense": 20.0, "health": 200.0, "speed": 8.0}


static func tier_for(floor_number: int) -> Dictionary:
	for tier in TIERS:
		if floor_number <= tier["upto"]:
			return tier
	return TIERS[-1]


static func build_floor(floor_number: int, progression: ProgressionSystem) -> Array[CardData]:
	var tier := tier_for(floor_number)
	var count := progression.enemy_count(floor_number)
	var scale := progression.stat_multiplier(floor_number)

	var out: Array[CardData] = []
	for i in count:
		var is_boss: bool = (i == count - 1) and progression.is_boss_floor(floor_number)
		out.append(_build(tier, floor_number, i, scale, is_boss))
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
