class_name SkillCtx
extends RefCounted

# =========================================================
# What a skill hook is handed. Carries the fighters involved and the
# mutable outcome of the event: a hook may raise or lower `damage`,
# negate the hit with `blocked`, or cancel a killing blow with
# `prevented`.
#
# `sim` is the BattleSim, which exposes the helpers skills need
# (allies, enemies, direct damage, summons, log notes).
# =========================================================

var sim                     # BattleSim - untyped to avoid a cyclic dependency
var unit: Combatant         # the card whose skill is running
var target: Combatant       # the card being attacked, on outgoing hooks
var attacker: Combatant     # the card doing the attacking, on incoming hooks
var other: Combatant        # the ally or enemy the event concerns

var damage: int = 0
var blocked: bool = false
var prevented: bool = false


func _init(battle_sim, source: Combatant) -> void:
	sim = battle_sim
	unit = source


func chance(probability: float) -> bool:
	return randf() < probability


# Percentage of the unit's max HP, rounded to a whole number.
func pct_max(who: Combatant, fraction: float) -> int:
	return int(round(float(who.max_hp) * fraction))
