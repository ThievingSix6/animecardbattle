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
