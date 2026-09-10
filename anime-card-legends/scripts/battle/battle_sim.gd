class_name BattleSim
extends RefCounted

# =========================================================
# The battle rules engine. Runs a lane duel: only the front card on
# each side fights; when one falls the next steps up. Emits events
# describing what happened so a view can animate them.
#
# Contains zero UI code, which makes the combat rules testable and
# lets the presentation change without touching balance.
#
# Skills hook into named points in the flow (entry, turn start,
# outgoing and incoming damage, kills, deaths). This file owns
# sequencing; SkillEffects owns behaviour.
# =========================================================

signal attack_performed(attacker: Combatant, target: Combatant, damage: int, kind: String)
signal ability_used(user: Combatant, ability: String, targets: Array, damage: int, kind: String)
signal skill_triggered(source: Combatant, skill: String, note: String, amount: int)
signal healed(target: Combatant, amount: int)
signal combatant_died(who: Combatant)
signal combatant_summoned(owner: Combatant, who: Combatant)
signal actives_changed(player_index: int, enemy_index: int)
signal battle_ended(player_won: bool)

var players: Array[Combatant] = []
var enemies: Array[Combatant] = []
var player_index := 0
var enemy_index := 0
var running := false
var turn := 0

# Total damage the player's side has dealt this battle. Used by the clan
# raid to credit a contribution; ordinary fights ignore it.
var player_damage_dealt := 0

var _entered: Dictionary = {}


func setup(player_cards: Array, enemy_cards: Array) -> void:
	players.clear()
	enemies.clear()
	for i in player_cards.size():
		players.append(Combatant.new(player_cards[i], "player", i))
	for i in enemy_cards.size():
		enemies.append(Combatant.new(enemy_cards[i], "enemy", i))
	player_index = 0
	enemy_index = 0
	turn = 0
	player_damage_dealt = 0
	_entered.clear()
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
	for i in range(maxi(0, from), list.size()):
		if list[i].alive:
			return i
	return -1


func any_alive(list: Array[Combatant]) -> bool:
	for c in list:
		if c.alive:
			return true
	return false


# --- helpers used by skills -------------------------------------------

func allies_of(unit: Combatant) -> Array[Combatant]:
	return team(unit.side)


func enemies_of(unit: Combatant) -> Array[Combatant]:
	return opposing(unit.side)


func active_enemy(unit: Combatant) -> Combatant:
	var list := opposing(unit.side)
	var idx := advance(list, 0)
	if idx == -1:
		return null
	return list[idx]


func lowest_hp_ally(unit: Combatant, include_self: bool) -> Combatant:
	var best: Combatant = null
	for a in team(unit.side):
		if not a.alive:
			continue
		if not include_self and a.id() == unit.id():
			continue
		if best == null or a.hp_ratio() < best.hp_ratio():
			best = a
	return best


func strongest_ally(unit: Combatant, include_self: bool) -> Combatant:
	var best: Combatant = null
	for a in team(unit.side):
		if not a.alive:
			continue
		if not include_self and a.id() == unit.id():
			continue
		if best == null or a.attack_power() > best.attack_power():
			best = a
	return best


func next_ally(unit: Combatant) -> Combatant:
	var list := team(unit.side)
	for i in range(unit.index + 1, list.size()):
		if list[i].alive:
			return list[i]
	return null


func note(source: Combatant, text: String, amount: int = 0) -> void:
	var label: String = Skills.display_name(source.data.skill_id)
	if label == "":
		label = "Passive"
	skill_triggered.emit(source, label, text, amount)


# --- skill dispatch ----------------------------------------------------

func _ctx(unit: Combatant) -> SkillCtx:
	return SkillCtx.new(self, unit)


func _fire(hook: String, unit: Combatant, ctx: SkillCtx) -> SkillCtx:
	var skill_id := unit.data.skill_id
	if skill_id == "" or not Skills.has(skill_id):
		return ctx
	if not unit.alive and hook != "death":
		return ctx

	match hook:
		"entry":
			SkillEffects.entry(skill_id, ctx)
		"turn_start":
			SkillEffects.turn_start(skill_id, ctx)
		"outgoing":
			SkillEffects.outgoing(skill_id, ctx)
		"incoming":
			SkillEffects.incoming(skill_id, ctx)
		"dealt":
			SkillEffects.dealt(skill_id, ctx)
		"taken":
			SkillEffects.taken(skill_id, ctx)
		"lethal":
			SkillEffects.lethal(skill_id, ctx)
		"kill":
			SkillEffects.kill(skill_id, ctx)
		"death":
			SkillEffects.death(skill_id, ctx)
		"ally_death":
			SkillEffects.ally_death(skill_id, ctx)
	return ctx


func _fire_team(hook: String, list: Array[Combatant]) -> void:
	var snapshot := list.duplicate()
	for c in snapshot:
		if not c.alive:
			continue
		_fire(hook, c, _ctx(c))


# --- Round loop ---------------------------------------------------

# Advances the lanes and reports who acts, in order. The view drives
# the actual turns so it can pace them; the rules stay in here.
func prepare_round() -> Array[String]:
	if not running:
		return []

	turn += 1
	player_index = advance(players, player_index)
	enemy_index = advance(enemies, enemy_index)

	if player_index == -1:
		_finish(false)
		return []
	if enemy_index == -1:
		_finish(true)
		return []

	var player := players[player_index]
	var enemy := enemies[enemy_index]

	# Entry hooks fire once, the first time a card reaches the front.
	var front: Array[Combatant] = [player, enemy]
	for c in front:
		if _entered.has(c.id()):
			continue
		_entered[c.id()] = true
		_fire("entry", c, _ctx(c))

	_upkeep()
	if not _check_end():
		return []

	actives_changed.emit(player_index, enemy_index)

	var order: Array[String] = ["enemy", "player"]
	if player.speed_value() >= enemy.speed_value():
		order = ["player", "enemy"]
	return order


# Damage over time, buff expiry, summon lifespans, per-turn skills.
func _upkeep() -> void:
	var everyone: Array[Combatant] = []
	everyone.append_array(players)
	everyone.append_array(enemies)

	for c in everyone:
		if not c.alive:
			continue

		var dot := c.tick_durations()
		if dot > 0:
			var died := c.take_damage(dot)
			skill_triggered.emit(c, "Damage over time",
				"%s suffers %d from lingering wounds" % [c.data.card_name, dot], dot)
			if died:
				_on_death(c, null)

		if c.summoned and c.alive:
			if c.bump("lifespan", -1) <= 0:
				c.alive = false
				combatant_died.emit(c)

	_fire_team("turn_start", players)
	_fire_team("turn_start", enemies)


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

	if attacker.stun_turns > 0:
		skill_triggered.emit(attacker, "Stunned",
			"%s is stunned and loses the turn" % attacker.data.card_name, 0)
		return

	_strike(attacker, target, compute_damage(attacker.attack_power(), target.defense_power()), "basic")

	attacker.attack_count += 1
	attacker.gain_energy(Config.ENERGY_PER_ATTACK)

	if not _check_end():
		return

	# Basic ability on a cadence.
	if attacker.attack_count >= Config.BASIC_ABILITY_EVERY and attacker.silence_turns <= 0:
		attacker.attack_count = 0
		_use_ability(attacker, defenders, false)
		if not _check_end():
			return

	# Ultimate at full energy.
	if attacker.alive and attacker.energy >= Config.ENERGY_MAX and attacker.silence_turns <= 0:
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

	var base := int(float(user.attack_power()) * multiplier)
	var struck: Array = []
	for t in targets:
		if _strike(user, t, base, "ability"):
			struck.append(t)

	if not struck.is_empty():
		var kind := "basic"
		if ultimate:
			kind = "ultimate"
		ability_used.emit(user, ability_name, struck, base, kind)


func resolve_targets(defenders: Array[Combatant], mode: String) -> Array[Combatant]:
	var out: Array[Combatant] = []
	match mode:
		"aoe":
			for d in defenders:
				if d.is_targetable():
					out.append(d)
		"backline":
			for i in range(defenders.size() - 1, -1, -1):
				if defenders[i].is_targetable():
					out.append(defenders[i])
					break
		_:
			for d in defenders:
				if d.is_targetable():
					out.append(d)
					break
	return out


# One hit, start to finish: outgoing skills, incoming skills, lethal
# cancellation, lifesteal, and the follow-up hooks. Returns false when
# the hit was blocked or the target could not be touched.
func _strike(attacker: Combatant, target: Combatant, base_damage: int, kind: String) -> bool:
	if not target.is_targetable():
		return false

	var out_ctx := _ctx(attacker)
	out_ctx.target = target
	out_ctx.damage = base_damage
	_fire("outgoing", attacker, out_ctx)

	var damage: int = maxi(1, int(round(float(out_ctx.damage) * (1.0 + attacker.modifier("damageDealt")))))

	var in_ctx := _ctx(target)
	in_ctx.attacker = attacker
	in_ctx.damage = damage
	_fire("incoming", target, in_ctx)

	if in_ctx.blocked:
		skill_triggered.emit(target, "Blocked",
			"%s blocks %s" % [target.data.card_name, attacker.data.card_name], 0)
		return false

	damage = maxi(1, in_ctx.damage)

	if damage >= target.hp + target.shield:
		var save_ctx := _ctx(target)
		save_ctx.attacker = attacker
		save_ctx.damage = damage
		_fire("lethal", target, save_ctx)
		if save_ctx.prevented:
			if kind == "basic":
				attack_performed.emit(attacker, target, target.hp, kind)
			_after_hit(attacker, target, damage)
			return true

	var died := target.take_damage(damage)
	if attacker.side == "player":
		player_damage_dealt += damage
	if kind == "basic":
		attack_performed.emit(attacker, target, damage, kind)

	_after_hit(attacker, target, damage)
	if died:
		_on_death(target, attacker)
	return true


func _after_hit(attacker: Combatant, target: Combatant, damage: int) -> void:
	var steal := attacker.modifier("lifesteal")
	if steal > 0.0 and attacker.alive:
		var healed_amount := attacker.heal(int(float(damage) * steal))
		if healed_amount > 0:
			healed.emit(attacker, healed_amount)

	var dealt_ctx := _ctx(attacker)
	dealt_ctx.target = target
	dealt_ctx.damage = damage
	_fire("dealt", attacker, dealt_ctx)

	var taken_ctx := _ctx(target)
	taken_ctx.attacker = attacker
	taken_ctx.damage = damage
	_fire("taken", target, taken_ctx)


# Damage from a skill rather than an attack - skips the attack hooks.
func direct_damage(source: Combatant, target: Combatant, amount: int, label: String) -> void:
	if not target.alive or amount <= 0:
		return
	var died := target.take_damage(amount)
	skill_triggered.emit(source, label,
		"%s: %s takes %d" % [label, target.data.card_name, amount], amount)
	if died:
		_on_death(target, source)


func _on_death(who: Combatant, killer: Combatant) -> void:
	combatant_died.emit(who)

	var death_ctx := _ctx(who)
	death_ctx.attacker = killer
	_fire("death", who, death_ctx)

	for ally in team(who.side):
		if ally.alive and ally.id() != who.id():
			var ally_ctx := _ctx(ally)
			ally_ctx.other = who
			_fire("ally_death", ally, ally_ctx)

	if killer != null and killer.alive:
		var kill_ctx := _ctx(killer)
		kill_ctx.other = who
		_fire("kill", killer, kill_ctx)


# --- summons ------------------------------------------------------------

func summon(owner: Combatant, minion_name: String, stat_pct: float, lifespan: int, count: int) -> void:
	var list := team(owner.side)
	var bonus: float = 1.0 + minf(0.3, float(owner.count("souls")) * 0.1)

	for i in count:
		var card := CardData.new()
		card.card_id = "%s~summon%d" % [owner.data.card_id, list.size()]
		card.card_name = minion_name
		card.role = owner.data.role
		card.rarity = owner.data.rarity
		card.element = owner.data.element
		card.origin_tag = "summon"
		card.basic_ability = "Strike"
		card.ultimate_ability = "Strike"
		card.attack = maxi(1, int(round(float(owner.data.attack) * stat_pct * bonus)))
		card.defense = maxi(0, int(round(float(owner.data.defense) * stat_pct * bonus)))
		card.health = maxi(1, int(round(float(owner.data.health) * stat_pct * bonus)))
		card.speed = owner.data.speed

		var minion := Combatant.new(card, owner.side, list.size())
		minion.summoned = true
		minion.counters["lifespan"] = lifespan
		list.append(minion)
		combatant_summoned.emit(owner, minion)


static func compute_damage(attack: int, defense: int) -> int:
	return maxi(1, attack - int(float(defense) * Config.DEFENSE_FACTOR))


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
