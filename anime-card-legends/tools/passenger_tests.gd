extends Node

# =========================================================
# PASSENGER ACCEPTANCE TESTS.
#
#   godot --headless --path . tools/PassengerTests.tscn
#
# The Passenger is the bridge between the two halves of the game, and it
# only works if two promises hold: that Momentum comes from NOWHERE but
# the car, and that it cannot be farmed. Most of these guard those two.
# =========================================================

var _passes := 0
var _failures: Array[String] = []


func _ready() -> void:
	GameState.open_slot(1)

	_an_empty_seat_banks_nothing()
	_driving_banks_distance()
	_idling_banks_nothing()
	_momentum_stops_at_the_cap()
	_a_full_card_cannot_be_farmed()
	_the_seat_holds_one_card()
	_selling_the_passenger_empties_the_seat()
	_momentum_survives_the_save_round_trip()
	_the_trail_takes_the_passengers_colour()
	_carrying_a_card_changes_no_stat()
	_the_card_game_cannot_make_momentum()

	print("")
	print("=== %d passed, %d failed ===" % [_passes, _failures.size()])
	for line in _failures:
		print("  ", line)
	get_tree().quit(1 if _failures.size() > 0 else 0)


# A card in the collection, so Passenger.seat() can find it.
func _owned(suffix: String) -> CardData:
	var template := CardData.new()
	template.card_id = "passenger_%s_%d" % [suffix, randi()]
	template.card_name = "Rider " + suffix
	template.attack = 100
	template.defense = 80
	template.health = 500
	template.modifier = "void"
	return GameState.collection.add(template)


# --- Cases --------------------------------------------------------------

func _an_empty_seat_banks_nothing() -> void:
	Passenger.clear_seat()
	Passenger.add(5000.0)
	Passenger.travelled(100.0, 1.0)
	_judge("an empty seat banks nothing",
		"something was credited with no passenger" if Passenger.card() != null else "")


func _driving_banks_distance() -> void:
	var rider := _owned("drive")
	Passenger.seat(rider.card_id)
	var before := Passenger.carried(rider)
	Passenger.travelled(100.0, 1.0)
	var gained := Passenger.carried(rider) - before
	_judge("driving banks the distance covered",
		"gained %.1f m from 100 m of driving" % gained if absf(gained - 100.0) > 0.5 else "")


# Without this you could wedge the car against a wall, hold the throttle
# and fill a card while making a sandwich.
func _idling_banks_nothing() -> void:
	var rider := _owned("idle")
	Passenger.seat(rider.card_id)
	var before := Passenger.carried(rider)
	for i in 600:
		Passenger.travelled(Passenger.MIN_SPEED - 0.1, 0.016)
	_judge("crawling banks nothing",
		"gained %.1f m at a standstill" % (Passenger.carried(rider) - before)
			if Passenger.carried(rider) > before else "")


func _momentum_stops_at_the_cap() -> void:
	var rider := _owned("cap")
	Passenger.seat(rider.card_id)
	Passenger.add(Passenger.FULL * 3.0)
	var problem := ""
	if Passenger.carried(rider) > Passenger.FULL:
		problem = "banked %.0f m past a cap of %.0f" % [Passenger.carried(rider), Passenger.FULL]
	elif not Passenger.is_full(rider):
		problem = "did not fill on three times the cap"
	_judge("Momentum stops at the cap", problem)


# THE ANTI-GRIND PROMISE. A full card gaining nothing is what forces the
# choice of who rides next - it is the entire reason the mechanic has a
# decision in it at all.
func _a_full_card_cannot_be_farmed() -> void:
	var rider := _owned("farm")
	Passenger.seat(rider.card_id)
	Passenger.add(Passenger.FULL)
	var full := Passenger.carried(rider)

	for i in 500:
		Passenger.travelled(180.0, 0.016)
		Passenger.add(Passenger.GOAL_BONUS)

	_judge("a full card cannot be farmed further",
		"crept to %.0f m from %.0f" % [Passenger.carried(rider), full]
			if Passenger.carried(rider) > full else "")


func _the_seat_holds_one_card() -> void:
	var first := _owned("one")
	var second := _owned("two")
	Passenger.seat(first.card_id)
	Passenger.seat(second.card_id)

	var problem := ""
	if Passenger.is_seated(first.card_id):
		problem = "two cards are in the seat at once"
	elif not Passenger.is_seated(second.card_id):
		problem = "the second card never took the seat"
	_judge("the seat holds exactly one card", problem)


func _selling_the_passenger_empties_the_seat() -> void:
	var rider := _owned("sold")
	Passenger.seat(rider.card_id)
	GameState.collection.sell(rider.card_id)
	_judge("selling the passenger empties the seat",
		"the seat still holds a card that is gone" if Passenger.card() != null else "")


func _momentum_survives_the_save_round_trip() -> void:
	var rider := _owned("saved")
	Passenger.seat(rider.card_id)
	Passenger.add(4321.0)

	var revived := Ledger.repair(JSON.parse_string(JSON.stringify(rider.ledger)))
	var problem := ""
	if absf(float(revived[Ledger.MOMENTUM]) - 4321.0) > 0.5:
		problem = "came back as %s" % str(revived[Ledger.MOMENTUM])
	elif typeof(revived[Ledger.MOMENTUM]) != TYPE_FLOAT:
		problem = "came back as %s" % type_string(typeof(revived[Ledger.MOMENTUM]))
	_judge("Momentum survives the save round trip", problem)


func _the_trail_takes_the_passengers_colour() -> void:
	var rider := _owned("tint")
	rider.modifier = "void"
	Passenger.seat(rider.card_id)
	var riding := Passenger.tint()
	Passenger.clear_seat()
	var empty := Passenger.tint()
	_judge("the car burns in the passenger's colour",
		"an empty seat and a Void passenger look the same" if riding.is_equal_approx(empty) else "")


# THE OTHER PROMISE. The instant carrying a card makes it stronger, the
# arcade mode stops being optional and becomes homework.
func _carrying_a_card_changes_no_stat() -> void:
	var rider := _owned("stats")
	Passenger.seat(rider.card_id)
	Passenger.add(Passenger.FULL)

	var problem := ""
	if rider.attack != 100 or rider.defense != 80 or rider.health != 500:
		problem = "a full card became %d/%d/%d" % [rider.attack, rider.defense, rider.health]
	else:
		# And through the whole battle-team chain, where the stat
		# modifiers actually live.
		var built := Grudges.apply_to(GameState.equipment.apply_to(rider), "")
		built = Outnumbered.apply_to(built, 5)
		if built.attack != rider.attack:
			problem = "the battle chain gave a full card %d attack" % built.attack
	_judge("carrying a card changes no stat", problem)


# The promise the whole bridge rests on: no amount of card-game play
# produces a single metre.
func _the_card_game_cannot_make_momentum() -> void:
	var rider := _owned("pure")
	Passenger.seat(rider.card_id)
	var before := Passenger.carried(rider)

	GameState.add_gold(500000)
	GameState.add_gems(5000)
	Ledger.bump(rider, Ledger.BATTLES, 50)
	Ledger.bump(rider, Ledger.KILLS, 200)
	Ledger.note_boss(rider, "Cinder Tyrant")
	Grudges.take(rider, "Cinder Tyrant")
	GameState.collection.level_up(rider.card_id)

	_judge("nothing in the card game produces Momentum",
		"gained %.1f m without ever being driven" % (Passenger.carried(rider) - before)
			if Passenger.carried(rider) > before else "")


# --- Reporting ----------------------------------------------------------

func _judge(what: String, problem: String) -> void:
	if problem == "":
		_passes += 1
		print("  PASS  ", what)
	else:
		_failures.append("%s: %s" % [what, problem])
		print("  FAIL  ", what, " -- ", problem)
