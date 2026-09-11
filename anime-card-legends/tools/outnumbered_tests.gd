extends Node

# =========================================================
# OUTNUMBERED ACCEPTANCE TESTS.
#
#   godot --headless --path . tools/OutnumberedTests.tscn
#
# Two halves. The arithmetic is easy to check and easy to get wrong. The
# part that actually matters is whether a short bench is a BUILD or a
# TRAP, and the only way to know that is to run real battles with teams
# of every size and see what happens.
# =========================================================

const FIGHT_FLOOR := 4
# The band a short bench has to price inside.
#
# MAX_PRICE stops it being a trap: need much more than this and nobody
# would ever bring fewer cards on purpose.
#
# MIN_PRICE is the guard that matters, and it is the one the first pass
# at these numbers failed. If a short bench is CHEAPER than a full one
# it is not a build, it is the only correct answer, and every player
# converges on a duo. A trade has to cost something.
const MAX_PRICE := 1.45
const MIN_PRICE := 0.85

var _passes := 0
var _failures: Array[String] = []


func _ready() -> void:
	GameState.open_slot(1)

	_a_full_team_gets_nothing()
	_bonuses_grow_as_the_bench_shrinks()
	_health_scales_hardest()
	_energy_never_reaches_a_free_ultimate()
	_apply_to_leaves_the_stored_card_alone()
	_the_lineup_has_a_name()
	_the_summary_says_what_it_does()
	_a_combatant_starts_with_the_energy()
	_the_whole_chain_composes()
	_a_short_bench_is_a_build_not_a_trap()

	print("")
	print("=== %d passed, %d failed ===" % [_passes, _failures.size()])
	for line in _failures:
		print("  ", line)
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _card(attack: int = 100, defense: int = 80, health: int = 500) -> CardData:
	var card := CardData.new()
	card.card_id = "outnumbered_test"
	card.card_name = "Test Card"
	card.attack = attack
	card.defense = defense
	card.health = health
	card.speed = 10
	return card


# --- Arithmetic ---------------------------------------------------------

func _a_full_team_gets_nothing() -> void:
	var card := _card()
	var same := Outnumbered.apply_to(card, 5)
	var problem := ""
	if Outnumbered.is_active(5):
		problem = "a full lineup counted as outnumbered"
	elif same.attack != 100 or same.health != 500:
		problem = "a full lineup was buffed to %d/%d" % [same.attack, same.health]
	_judge("a full lineup gets no bonus", problem)


func _bonuses_grow_as_the_bench_shrinks() -> void:
	var last := 0.0
	var problem := ""
	for size in [5, 4, 3, 2, 1]:
		var here := Outnumbered.health_bonus(size)
		if here < last:
			problem = "a team of %d got less than a bigger one" % size
			break
		last = here
	_judge("every card removed makes the rest tougher", problem)


# The design decision worth guarding: what a short bench lacks is LIVES,
# not damage, so the compensation leans on surviving.
func _health_scales_hardest() -> void:
	var problem := ""
	if Outnumbered.HEALTH_PER_SLOT <= Outnumbered.DEFENSE_PER_SLOT:
		problem = "health no longer scales hardest"
	elif Outnumbered.DEFENSE_PER_SLOT <= Outnumbered.ATTACK_PER_SLOT:
		problem = "defense no longer outscales attack"
	_judge("the bonus leans on surviving, not on damage", problem)


func _energy_never_reaches_a_free_ultimate() -> void:
	var problem := ""
	for size in [1, 2, 3, 4, 5]:
		if Outnumbered.starting_energy(size) >= Config.ENERGY_MAX:
			problem = "a team of %d starts with a full bar" % size
			break
	_judge("nobody opens the fight with a free ultimate", problem)


func _apply_to_leaves_the_stored_card_alone() -> void:
	var card := _card()
	var _lone := Outnumbered.apply_to(card, 1)
	_judge("applying the bonus does not touch the stored card",
		"the stored card became %d/%d/%d" % [card.attack, card.defense, card.health]
			if card.attack != 100 or card.defense != 80 or card.health != 500 else "")


func _the_lineup_has_a_name() -> void:
	var problem := ""
	if Outnumbered.lineup_name(1) != "Alone":
		problem = "a team of one is called '%s'" % Outnumbered.lineup_name(1)
	elif Outnumbered.lineup_name(3) != "Trio":
		problem = "a team of three is called '%s'" % Outnumbered.lineup_name(3)
	_judge("a short lineup has a name, not just a number", problem)


func _the_summary_says_what_it_does() -> void:
	var line := Outnumbered.summary(2)
	var problem := ""
	if not line.contains("%"):
		problem = "the summary does not say what it is worth: %s" % line
	elif not line.contains("energy"):
		problem = "the summary does not mention the energy: %s" % line
	_judge("the summary states the whole trade", problem)


# The per-fight field has to reach the combatant, or the energy half of
# the trade silently does nothing.
func _a_combatant_starts_with_the_energy() -> void:
	var lone := Outnumbered.apply_to(_card(), 1)
	var unit := Combatant.new(lone, "player", 0)
	var want := Outnumbered.starting_energy(1)
	_judge("a short-handed card walks in with energy",
		"started on %d, expected %d" % [unit.energy, want] if unit.energy != want else "")


# Equipment, then grudges, then Outnumbered - and the collection's own
# card untouched at the end of it.
func _the_whole_chain_composes() -> void:
	var team := GameState.collection.get_team()
	if team.is_empty():
		_judge("the whole chain composes", "the save slot has no team")
		return

	var stored: CardData = team[0]
	var before := stored.attack
	var built := GameState.get_battle_team("Cinder Tyrant")

	var problem := ""
	if built.size() != team.size():
		problem = "built %d cards from a team of %d" % [built.size(), team.size()]
	elif stored.attack != before:
		problem = "the stored card was modified: %d -> %d" % [before, stored.attack]
	_judge("the whole chain composes without touching the collection", problem)


# THE ONE THAT MATTERS.
#
# Arithmetic cannot tell you whether three cards is a build or a mistake.
# This measures the trade directly, in real battles.
#
# HOW, and why not the obvious way. The obvious test is "set up a fair
# fight and see who wins more" - but this combat is very nearly
# deterministic, so a win rate jumps from nothing to everything with
# almost no middle, and no power level exists where a full lineup wins
# about half. Two earlier versions of this test foundered on that: one
# reported every lineup losing every fight and passed anyway.
#
# So instead it binary-searches the WEAKEST CARDS each lineup size can
# still win floor 4 with. That number is the honest price of the trade:
# if a solo card needs three times the raw power of a full bench, then
# Outnumbered is not paying enough, and if it needs the same, bringing
# fewer cards is free and everyone will do it.
func _a_short_bench_is_a_build_not_a_trap() -> void:
	var needed: Array[float] = []
	print("")
	print("  weakest cards that can still win floor %d:" % FIGHT_FLOOR)
	for size in [5, 4, 3, 2, 1]:
		var price := _threshold(size)
		needed.append(price)
		if price <= 0.0:
			print("  %-12s never wins at any power" % Outnumbered.lineup_name(size))
		else:
			print("  %-12s power %.2f   (%.2fx a full lineup)" % [
				Outnumbered.lineup_name(size), price,
				price / maxf(needed[0], 0.001)])

	var problem := ""
	var full := needed[0]
	if full <= 0.0:
		problem = "a full lineup cannot win floor %d at any power" % FIGHT_FLOOR
	else:
		for i in needed.size():
			var size := 5 - i
			if needed[i] <= 0.0:
				problem = "a team of %d cannot win at any power" % size
				break
			# The trade has to be a trade, in both directions.
			var price := needed[i] / full
			if price > MAX_PRICE:
				problem = "a team of %d needs %.2fx the power of a full one - a trap; turn the per-slot bonuses UP" % [size, price]
				break
			if price < MIN_PRICE:
				problem = "a team of %d wins on %.2fx the power of a full one - strictly better; turn the per-slot bonuses DOWN" % [size, price]
				break
	_judge("every lineup size is a trade, not a trap or a free win", problem)


# The weakest card power this lineup size can still win with, or 0.0 if
# it cannot win at any power in range.
func _threshold(size: int) -> float:
	var low := 0.02
	var high := 12.0
	if not _wins(size, high):
		return 0.0
	if _wins(size, low):
		return low

	# Twelve halvings of a 600x range lands inside a few per cent, which
	# is far finer than the difference being looked for.
	for step in 12:
		var middle := (low + high) * 0.5
		if _wins(size, middle):
			high = middle
		else:
			low = middle
	return high


func _wins(size: int, power: float) -> bool:
	return _fight(_make_team(power, size))


# `size` identical cards at a given power. Identical on purpose - the
# question is what the LINEUP SIZE does, and five different cards would
# lay their own variance over the answer.
func _make_team(power: float, size: int) -> Array[CardData]:
	var team: Array[CardData] = []
	for i in size:
		var card := _card(
			maxi(1, int(round(60.0 * power))),
			maxi(0, int(round(30.0 * power))),
			maxi(1, int(round(600.0 * power))))
		card.card_id = "calibrated_%d" % i
		team.append(Outnumbered.apply_to(card, size))
	return team


# One battle, driven the way the battle screen drives it.
func _fight(roster: Array[CardData]) -> bool:
	var sim := BattleSim.new()
	sim.setup(roster, EnemyFactory.build_floor(FIGHT_FLOOR, GameState.progression))

	# The result is read off the SIM afterwards, never through a lambda.
	# GDScript closures capture locals BY VALUE, so
	# `sim.battle_ended.connect(func(w): won = w)` assigns to a copy and
	# the caller always sees false - which is exactly how the first
	# version of this sweep reported every lineup losing every fight,
	# including the full one, and passed.
	var guard := 0
	while sim.running and guard < 600:
		var order := sim.prepare_round()
		if not sim.running or order.is_empty():
			break
		for side in order:
			sim.take_turn(side)
			if not sim.running:
				break
		guard += 1
	return not sim.any_alive(sim.enemies)


# --- Reporting ----------------------------------------------------------

func _judge(what: String, problem: String) -> void:
	if problem == "":
		_passes += 1
		print("  PASS  ", what)
	else:
		_failures.append("%s: %s" % [what, problem])
		print("  FAIL  ", what, " -- ", problem)
