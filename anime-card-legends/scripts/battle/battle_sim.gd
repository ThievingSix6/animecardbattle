class_name BattleSim
extends RefCounted

# =========================================================
# The battle rules engine. Runs a lane duel: only the front card on
# each side fights; when one falls the next steps up. Emits events
# describing what happened so a view can animate them.
#
# Contains zero UI code, which makes the combat rules testable and
# lets the presentation change without touching balance.
# =========================================================

signal attack_performed(attacker: Combatant, target: Combatant, damage: int, kind: String)
signal ability_used(user: Combatant, ability: String, targets: Array, damage: int, kind: String)
signal passive_triggered(source: Combatant, kind: String, amount: int, note: String)
signal healed(target: Combatant, amount: int)
signal combatant_died(who: Combatant)
signal actives_changed(player_index: int, enemy_index: int)
signal battle_ended(player_won: bool)

var players: Array[Combatant] = []
var enemies: Array[Combatant] = []
var player_index := 0
var enemy_index := 0
var running := false


func setup(player_cards: Array, enemy_cards: Array) -> void:
	players.clear()
	enemies.clear()
	for i in player_cards.size():
		players.append(Combatant.new(player_cards[i], "player", i))
	for i in enemy_cards.size():
		enemies.append(Combatant.new(enemy_cards[i], "enemy", i))
	player_index = 0
	enemy_index = 0
	running = true


func team(side: String) -> Array[Combatant]:
	if side == "player":
		return players
	return enemies


func opposing(side: String) -> Array[Combatant]:
	if side == "player":
		return enemies
	return players


func active_index(side: String) -> int:
	if side == "player":
		return player_index
	return enemy_index


func set_active_index(side: String, value: int) -> void:
	if side == "player":
		player_index = value
	else:
		enemy_index = value


# Lanes only advance forward - a fallen card is replaced permanently.
func advance(list: Array[Combatant], from: int) -> int:
	for i in range(max(0, from), list.size()):
		if list[i].alive:
			return i
	return -1


func any_alive(list: Array[Combatant]) -> bool:
	for c in list:
		if c.alive:
			return true
	return false


# --- Round loop ---------------------------------------------------

# Advances the lanes and reports who acts, in order. The view drives
# the actual turns so it can pace them; the rules stay in here.
func prepare_round() -> Array[String]:
	if not running:
		return []

	player_index = advance(players, player_index)
	enemy_index = advance(enemies, enemy_index)

	if player_index == -1:
		_finish(false)
		return []
	if enemy_index == -1:
		_finish(true)
		return []

	actives_changed.emit(player_index, enemy_index)

	var player_first: bool = players[player_index].data.speed >= enemies[enemy_index].data.speed
	var order: Array[String] = ["enemy", "player"]
	if player_first:
		order = ["player", "enemy"]
	return order


func take_turn(side: String) -> void:
	if not running:
		return

	var attackers := team(side)
	var defenders := opposing(side)

	var attacker_idx := advance(attackers, active_index(side))
	set_active_index(side, attacker_idx)
	if attacker_idx == -1:
		return

	var defender_side := "player"
	if side == "player":
		defender_side = "enemy"
	var defender_idx := advance(defenders, active_index(defender_side))
	set_active_index(defender_side, defender_idx)
	if defender_idx == -1:
		return

	var attacker := attackers[attacker_idx]
	var target := defenders[defender_idx]

	# Basic attack, unless a guardian intercepts it.
	if not _try_guardian(defenders, target):
		var damage := compute_damage(attacker.data.attack, target.data.defense)
		_deal(attacker, target, damage, "basic")
		attack_performed.emit(attacker, target, damage, "basic")

	attacker.attack_count += 1
	var energy := Config.ENERGY_PER_ATTACK
	if attacker.data.passive_type == "energy_surge":
		energy += int(attacker.data.passive_value)
	attacker.gain_energy(energy)

	if not _check_end():
		return

	# Basic ability on a cadence.
	if attacker.attack_count >= Config.BASIC_ABILITY_EVERY:
		attacker.attack_count = 0
		_use_ability(attacker, defenders, false)
		if not _check_end():
			return

	# Ultimate at full energy.
	if attacker.alive and attacker.energy >= Config.ENERGY_MAX:
		attacker.energy = 0
		_use_ability(attacker, defenders, true)
		_check_end()


func _use_ability(user: Combatant, defenders: Array[Combatant], ultimate: bool) -> void:
	var mode: String = user.data.basic_target_mode
	var ability_name: String = user.data.basic_ability
	var multiplier: float = Config.BASIC_ABILITY_MULT
	if ultimate:
		mode = user.data.ultimate_target_mode
		ability_name = user.data.ultimate_ability
		multiplier = Config.ULTIMATE_MULT

	var targets := resolve_targets(defenders, mode)
	if targets.is_empty():
		return

	var damage := int(user.data.attack * multiplier)
	var struck: Array = []
	for t in targets:
		if _try_guardian(defenders, t):
			continue
		_deal(user, t, damage, "ability")
		struck.append(t)

	if not struck.is_empty():
		var kind := "basic"
		if ultimate:
			kind = "ultimate"
		ability_used.emit(user, ability_name, struck, damage, kind)


func resolve_targets(defenders: Array[Combatant], mode: String) -> Array[Combatant]:
	var out: Array[Combatant] = []
	match mode:
		"aoe":
			for d in defenders:
				if d.alive:
					out.append(d)
		"backline":
			for i in range(defenders.size() - 1, -1, -1):
				if defenders[i].alive:
					out.append(defenders[i])
					break
		_:
			var idx := advance(defenders, 0)
			if idx != -1:
				out.append(defenders[idx])
	return out


func _deal(attacker: Combatant, target: Combatant, damage: int, _kind: String) -> void:
	var died := target.take_damage(damage)

	if attacker.data.passive_type == "lifesteal" and attacker.alive:
		var healed_amount := attacker.heal(int(damage * attacker.data.passive_value))
		if healed_amount > 0:
			healed.emit(attacker, healed_amount)

	if died:
		combatant_died.emit(target)


# A living, non-active ally may intercept an incoming hit entirely.
func _try_guardian(defenders: Array[Combatant], target: Combatant) -> bool:
	for guardian in defenders:
		if not guardian.alive or guardian == target:
			continue
		if guardian.data.passive_type != "guardian_block_heal":
			continue
		if randf() > guardian.data.passive_chance:
			continue

		var amount := guardian.heal(int(guardian.max_hp * guardian.data.passive_value))
		passive_triggered.emit(guardian, "guardian_block_heal", amount,
			"%s intercepts the blow aimed at %s" % [guardian.data.card_name, target.data.card_name])
		return true
	return false


static func compute_damage(attack: int, defense: int) -> int:
	return max(1, attack - int(defense * Config.DEFENSE_FACTOR))


func _check_end() -> bool:
	if not running:
		return false
	if not any_alive(players):
		_finish(false)
		return false
	if not any_alive(enemies):
		_finish(true)
		return false
	return true


func _finish(player_won: bool) -> void:
	if not running:
		return
	running = false
	battle_ended.emit(player_won)
