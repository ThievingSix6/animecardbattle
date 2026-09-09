class_name Combatant
extends RefCounted

# =========================================================
# One fighter's runtime state. Pure data - no UI references.
# =========================================================

var data: CardData
var side: String          # "player" | "enemy"
var index: int

var hp: int
var max_hp: int
var energy: int = 0
var attack_count: int = 0
var alive: bool = true


func _init(card: CardData, which_side: String, slot: int) -> void:
	data = card
	side = which_side
	index = slot
	max_hp = card.health
	hp = card.health


func take_damage(amount: int) -> bool:
	hp = max(0, hp - amount)
	if hp == 0 and alive:
		alive = false
		return true   # died from this hit
	return false


func heal(amount: int) -> int:
	var before := hp
	hp = min(max_hp, hp + amount)
	return hp - before


func gain_energy(amount: int) -> void:
	energy = min(Config.ENERGY_MAX, energy + amount)


func hp_ratio() -> float:
	return float(hp) / float(max(1, max_hp))
