class_name ProgressionSystem
extends RefCounted

# =========================================================
# Talents, tower progress, and roll-pack inventory.
# =========================================================

var talents := {"speed": 0, "luck": 0, "multi": 0}
var highest_floor := 0
var pending_floor := 1
var pending_zone := 0        # transient: which zone the 3D world should build
var roll_packs: Dictionary = {}

# What the next battle actually is. Transient - the battle screen
# consumes it on entry so a later ordinary fight cannot inherit it.
#   "floor"    a campaign stage, using pending_floor
#   "raid"     the clan raid boss
#   "gauntlet" a wave of the Hellfire Gauntlet, using gauntlet_wave
#   "duel"     The Boy
var pending_mode := "floor"

# ---------------- HELLFIRE GAUNTLET ----------------

# Which wave the current run is on, 0-based. -1 means no run.
var gauntlet_wave := -1
# card_id -> fraction of max HP the card carries into the next wave.
var gauntlet_hp: Dictionary = {}
# Best wave ever reached, kept across runs and saved.
var gauntlet_best := 0
var gauntlet_cleared := false

# Has The Boy ever been beaten? Kept for his dialogue, and saved.
var boy_defeated := false
# Transient: set by the duel and consumed by the city, so he is found
# on the floor the one time you walk back in having just beaten him.
var boy_just_lost := false


func queue_floor(floor_number: int) -> void:
	pending_mode = "floor"
	pending_floor = floor_number


func queue_raid() -> void:
	pending_mode = "raid"


func queue_duel() -> void:
	pending_mode = "duel"


# Starts a fresh gauntlet run: full health, wave one.
func start_gauntlet() -> void:
	gauntlet_wave = 0
	gauntlet_hp.clear()
	pending_mode = "gauntlet"


func queue_gauntlet_wave() -> void:
	pending_mode = "gauntlet"


func gauntlet_running() -> bool:
	return gauntlet_wave >= 0


# Records what the team has left, so the next wave starts wounded.
func store_gauntlet_health(fractions: Dictionary) -> void:
	gauntlet_hp = fractions.duplicate()


# The fraction a card should start the next wave on: what it had left,
# mended a little. A card that died stays dead for the rest of the run.
func gauntlet_health_for(card_id: String) -> float:
	if not gauntlet_hp.has(card_id):
		return 1.0
	var left := float(gauntlet_hp[card_id])
	if left <= 0.0:
		return 0.0
	return minf(1.0, left + (1.0 - left) * Gauntlet.MEND_BETWEEN_WAVES)


func advance_gauntlet() -> bool:
	gauntlet_wave += 1
	gauntlet_best = maxi(gauntlet_best, gauntlet_wave)
	if gauntlet_wave >= Gauntlet.WAVES:
		gauntlet_cleared = true
		end_gauntlet()
		return false
	return true


func end_gauntlet() -> void:
	gauntlet_wave = -1
	gauntlet_hp.clear()
	pending_mode = "floor"


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
	if floor_number >= 35:
		return "boss"
	if floor_number >= 15:
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
