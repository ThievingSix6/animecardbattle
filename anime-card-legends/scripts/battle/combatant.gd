class_name Combatant
extends RefCounted

# =========================================================
# One fighter's runtime state. Pure data - no UI references.
#
# TURNS, NOT SECONDS. The skill designs are written in real time but
# combat resolves in discrete turns, so every duration is converted on
# the way in - see Skills.turns().
# =========================================================

const INFINITE := 1000000

var data: CardData
var side: String          # "player" | "enemy"
var index: int

var hp: int
var max_hp: int
var energy: int = 0
var attack_count: int = 0
var alive: bool = true

# Absorbs damage before HP does.
var shield: int = 0

# Each entry: {"stat": String, "amount": float, "turns": int, "key": String}
var buffs: Array[Dictionary] = []

# Each entry: {"kind": String, "turns": int, "per_turn": int}
var dots: Array[Dictionary] = []

var stun_turns: int = 0
var silence_turns: int = 0
var untargetable_turns: int = 0

# Arbitrary named tallies used by skills (blocks landed, hits taken...).
var counters: Dictionary = {}

# Skill keys that have already spent their one-per-battle trigger.
var spent: Dictionary = {}

# Ids of combatants this fighter has marked.
var marked: Dictionary = {}

# True for temporary bodies created by summon skills.
var summoned: bool = false


func _init(card: CardData, which_side: String, slot: int) -> void:
	data = card
	side = which_side
	index = slot
	max_hp = card.health
	hp = card.health


func id() -> String:
	return "%s:%d:%s" % [side, index, data.card_id]


# --- modifiers ------------------------------------------------------

func modifier(stat: String) -> float:
	var total := 0.0
	for buff in buffs:
		if buff["stat"] == stat:
			total += float(buff["amount"])
	return total


func attack_power() -> int:
	return maxi(1, int(round(float(data.attack) * (1.0 + modifier("attack")))))


func defense_power() -> int:
	return maxi(0, int(round(float(data.defense) * (1.0 + modifier("defense")))))


func speed_value() -> int:
	return maxi(1, int(round(float(data.speed) * (1.0 + modifier("speed")))))


# Energy gained per attack scales with the "attack speed" analogue.
func energy_rate() -> float:
	return maxf(0.1, 1.0 + modifier("energyRate"))


func add_buff(stat: String, amount: float, duration: int, key: String = "", max_stacks: int = INFINITE) -> void:
	if key != "":
		var existing: Array[Dictionary] = []
		for buff in buffs:
			if buff["key"] == key:
				existing.append(buff)
		if existing.size() >= max_stacks:
			# Refresh the oldest rather than exceeding the cap.
			existing[0]["turns"] = duration
			return

	buffs.append({"stat": stat, "amount": amount, "turns": duration, "key": key})


func has_buff(key: String) -> bool:
	for buff in buffs:
		if buff["key"] == key:
			return true
	return false


func clear_buffs_with_key(key: String) -> void:
	var kept: Array[Dictionary] = []
	for buff in buffs:
		if buff["key"] != key:
			kept.append(buff)
	buffs = kept


func count_buffs_with_key(key: String) -> int:
	var total := 0
	for buff in buffs:
		if buff["key"] == key:
			total += 1
	return total


func bump(counter: String, by: int = 1) -> int:
	var current: int = counters.get(counter, 0)
	counters[counter] = current + by
	return counters[counter]


func count(counter: String) -> int:
	return counters.get(counter, 0)


# Returns true the first time a given once-per-battle key is claimed.
func claim(key: String) -> bool:
	if spent.has(key):
		return false
	spent[key] = true
	return true


# --- damage ----------------------------------------------------------

# Applies damage through the shield. Returns true if this was lethal.
func take_damage(amount: int) -> bool:
	var remaining: int = maxi(0, int(round(float(amount) * (1.0 + modifier("damageTaken")))))

	if shield > 0:
		var absorbed: int = mini(shield, remaining)
		shield -= absorbed
		remaining -= absorbed

	hp = maxi(0, hp - remaining)
	if hp == 0 and alive:
		alive = false
		return true
	return false


func heal(amount: int) -> int:
	if not alive:
		return 0
	var scaled := int(round(float(amount) * (1.0 + modifier("healingReceived"))))
	var before := hp
	hp = mini(max_hp, hp + scaled)
	return hp - before


func add_shield(amount: int) -> int:
	var gain: int = maxi(0, amount)
	shield += gain
	return gain


func gain_energy(amount: int) -> void:
	energy = mini(Config.ENERGY_MAX, energy + int(round(float(amount) * energy_rate())))


func hp_ratio() -> float:
	return float(hp) / float(maxi(1, max_hp))


func is_targetable() -> bool:
	return alive and untargetable_turns <= 0


# --- per-turn upkeep ---------------------------------------------------

# Expires buffs and statuses. Returns damage owed by damage-over-time.
func tick_durations() -> int:
	var kept_buffs: Array[Dictionary] = []
	for buff in buffs:
		buff["turns"] = int(buff["turns"]) - 1
		if int(buff["turns"]) > 0:
			kept_buffs.append(buff)
	buffs = kept_buffs

	var dot_damage := 0
	var kept_dots: Array[Dictionary] = []
	for dot in dots:
		dot_damage += int(dot["per_turn"])
		dot["turns"] = int(dot["turns"]) - 1
		if int(dot["turns"]) > 0:
			kept_dots.append(dot)
	dots = kept_dots

	if stun_turns > 0:
		stun_turns -= 1
	if silence_turns > 0:
		silence_turns -= 1
	if untargetable_turns > 0:
		untargetable_turns -= 1

	return dot_damage


func has_dot(kind: String) -> bool:
	for dot in dots:
		if dot["kind"] == kind:
			return true
	return false


func first_dot(kind: String) -> Dictionary:
	for dot in dots:
		if dot["kind"] == kind:
			return dot
	return {}


func apply_dot(kind: String, duration: int, per_turn: int) -> void:
	dots.append({"kind": kind, "turns": duration, "per_turn": maxi(1, per_turn)})
