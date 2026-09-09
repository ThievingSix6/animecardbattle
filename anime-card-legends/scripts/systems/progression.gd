class_name ProgressionSystem
extends RefCounted

# =========================================================
# Talents, tower progress, and roll-pack inventory.
# =========================================================

var talents := {"speed": 0, "luck": 0, "multi": 0}
var highest_floor := 0
var pending_floor := 1
var roll_packs: Dictionary = {}


# ---------------- TALENTS ----------------

func cost(talent: String) -> int:
	var base: float = Config.TALENT_BASE_COST[talent]
	return int(base * pow(Config.TALENT_COST_GROWTH, talents[talent]))


func is_maxed(talent: String) -> bool:
	return talents[talent] >= Config.TALENT_MAX[talent]


func apply_upgrade(talent: String) -> void:
	talents[talent] += 1
	EventBus.talent_upgraded.emit(talent, talents[talent])


func roll_interval() -> float:
	return max(
		Config.ROLL_INTERVAL_MIN,
		Config.ROLL_INTERVAL_BASE - float(talents["speed"]) * Config.ROLL_INTERVAL_PER_LEVEL
	)


func luck_bonus() -> float:
	return float(talents["luck"]) * Config.LUCK_PER_LEVEL


func rolls_per_tick() -> int:
	return 1 + talents["multi"]


func talent_effect_text(talent: String) -> String:
	match talent:
		"speed":
			return "One roll every " + String.num(roll_interval(), 1) + "s"
		"luck":
			return "+" + Fmt.percent(luck_bonus(), 0) + " toward rarer pulls"
		"multi":
			return str(rolls_per_tick()) + " cards per roll"
	return ""


# ---------------- TOWER ----------------

func is_unlocked(floor_number: int) -> bool:
	return floor_number <= highest_floor + 1


func is_boss_floor(floor_number: int) -> bool:
	return floor_number % Config.BOSS_EVERY == 0


func enemy_count(floor_number: int) -> int:
	if is_boss_floor(floor_number):
		return 6
	return 5


func stat_multiplier(floor_number: int) -> float:
	return 1.0 + float(floor_number - 1) * Config.FLOOR_STAT_SCALE


func pack_for_floor(floor_number: int) -> String:
	if floor_number >= 45:
		return "boss"
	if floor_number >= 20:
		return "gold"
	return "bronze"


# Returns the rewards earned; caller credits the currency.
func clear_floor(floor_number: int) -> Dictionary:
	var rewards := {
		"gems": Config.FLOOR_GEM_BASE + floor_number * Config.FLOOR_GEM_PER,
		"gold": Config.FLOOR_GOLD_BASE + floor_number * Config.FLOOR_GOLD_PER,
		"pack": "",
	}

	if is_boss_floor(floor_number):
		var pack := pack_for_floor(floor_number)
		roll_packs[pack] = roll_packs.get(pack, 0) + 1
		rewards["pack"] = pack
		EventBus.roll_pack_granted.emit(pack)

	if floor_number > highest_floor:
		highest_floor = floor_number

	EventBus.floor_cleared.emit(floor_number, rewards)
	return rewards


# ---------------- ROLL PACKS ----------------

func pack_count(pack_id: String) -> int:
	return roll_packs.get(pack_id, 0)


func consume_pack(pack_id: String) -> bool:
	if pack_count(pack_id) <= 0:
		return false
	roll_packs[pack_id] -= 1
	return true
