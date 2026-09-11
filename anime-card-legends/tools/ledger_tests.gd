extends Node

# =========================================================
# LEDGER ACCEPTANCE TESTS.
#
#   godot --headless --path . tools/LedgerTests.tscn
#
# The Ledger is written now and read months from now, which is the worst
# possible shape for a bug: nothing reads it, so nothing notices when it
# breaks, and by the time something does the damage is in everyone's save
# file and cannot be undone.
#
# So the round trip is tested harder than the writing. A record that
# survives JSON is a record that is still there in a year.
# =========================================================

var _passes := 0
var _failures: Array[String] = []


func _ready() -> void:
	GameState.open_slot(1)

	_blank_record_is_empty_but_dated()
	_counters_count()
	_tallies_group()
	_deepest_is_a_high_water_mark()
	_bosses_are_named_once()
	_json_round_trip_keeps_integers()
	_json_round_trip_survives_a_full_record()
	_a_card_with_no_ledger_gets_one()
	_prose_reads_as_prose()
	_new_cards_are_stamped_on_acquisition()
	_a_real_battle_writes_a_real_record()

	print("")
	print("=== %d passed, %d failed ===" % [_passes, _failures.size()])
	for line in _failures:
		print("  ", line)
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _card() -> CardData:
	var card := CardData.new()
	card.card_id = "test_card"
	card.card_name = "Test Card"
	return card


# --- Cases --------------------------------------------------------------

func _blank_record_is_empty_but_dated() -> void:
	var card := _card()
	var record := Ledger.of(card)
	_judge("a new record is empty",
		"battles started at %d" % record[Ledger.BATTLES]
			if int(record[Ledger.BATTLES]) != 0 else "")
	_judge("a new record knows when it started",
		"first_seen was not stamped" if int(record[Ledger.FIRST_SEEN]) <= 0 else "")


func _counters_count() -> void:
	var card := _card()
	for i in 7:
		Ledger.bump(card, Ledger.BATTLES)
	Ledger.bump(card, Ledger.KILLS, 3)
	_judge("counters count",
		"battles %d, kills %d" % [Ledger.count(card, Ledger.BATTLES), Ledger.count(card, Ledger.KILLS)]
			if Ledger.count(card, Ledger.BATTLES) != 7 or Ledger.count(card, Ledger.KILLS) != 3 else "")


func _tallies_group() -> void:
	var card := _card()
	Ledger.tally(card, Ledger.ZONES, "Emberfall")
	Ledger.tally(card, Ledger.ZONES, "Emberfall")
	Ledger.tally(card, Ledger.ZONES, "Duskmire")
	# An empty entry is not a place and must not become one.
	Ledger.tally(card, Ledger.ZONES, "")

	var zones: Dictionary = Ledger.of(card)[Ledger.ZONES]
	var problem := ""
	if int(zones.get("Emberfall", 0)) != 2:
		problem = "Emberfall counted %d" % int(zones.get("Emberfall", 0))
	elif zones.has(""):
		problem = "an empty zone name was recorded"
	_judge("tallies group by name and ignore blanks", problem)


func _deepest_is_a_high_water_mark() -> void:
	var card := _card()
	Ledger.reach(card, Ledger.DEEPEST, 40)
	Ledger.reach(card, Ledger.DEEPEST, 12)
	Ledger.reach(card, Ledger.DEEPEST, 87)
	Ledger.reach(card, Ledger.DEEPEST, 3)
	_judge("deepest keeps the deepest",
		"ended at %d, should be 87" % Ledger.count(card, Ledger.DEEPEST)
			if Ledger.count(card, Ledger.DEEPEST) != 87 else "")


func _bosses_are_named_once() -> void:
	var card := _card()
	Ledger.note_boss(card, "Diablo")
	Ledger.note_boss(card, "Diablo")
	Ledger.note_boss(card, "The Choir")
	Ledger.note_boss(card, "")
	var beaten := Ledger.bosses(card)
	_judge("a boss is listed once, blanks never",
		"listed %s" % str(beaten) if beaten.size() != 2 else "")


# The one that matters. JSON has a single number type, so every count
# comes back as a float and an unrepaired record poisons itself the first
# time something increments it.
func _json_round_trip_keeps_integers() -> void:
	var card := _card()
	Ledger.bump(card, Ledger.BATTLES, 214)
	Ledger.tally(card, Ledger.ZONES, "Emberfall")

	var revived := Ledger.repair(JSON.parse_string(JSON.stringify(card.ledger)))

	var problem := ""
	if typeof(revived[Ledger.BATTLES]) != TYPE_INT:
		problem = "battles came back as %s" % type_string(typeof(revived[Ledger.BATTLES]))
	elif int(revived[Ledger.BATTLES]) != 214:
		problem = "battles came back as %d" % int(revived[Ledger.BATTLES])
	else:
		var zones: Dictionary = revived[Ledger.ZONES]
		if typeof(zones.get("Emberfall")) != TYPE_INT:
			problem = "a zone count came back as %s" % type_string(typeof(zones.get("Emberfall")))
	_judge("counts survive JSON as integers", problem)


func _json_round_trip_survives_a_full_record() -> void:
	var card := _card()
	Ledger.bump(card, Ledger.BATTLES, 40)
	Ledger.bump(card, Ledger.WINS, 25)
	Ledger.bump(card, Ledger.FELLED, 9)
	Ledger.bump(card, Ledger.KILLS, 61)
	Ledger.reach(card, Ledger.DEEPEST, 73)
	Ledger.tally(card, Ledger.ZONES, "Hollow")
	Ledger.tally(card, Ledger.WEATHER, "Lunar Eclipse")
	Ledger.note_boss(card, "Diablo")
	Ledger.add_momentum(card, 1250.5)
	Ledger.touch(card)

	var before := card.ledger.duplicate(true)
	var after := Ledger.repair(JSON.parse_string(JSON.stringify(before)))

	var problem := ""
	for key in [Ledger.BATTLES, Ledger.WINS, Ledger.FELLED, Ledger.KILLS,
			Ledger.DEEPEST, Ledger.FIRST_SEEN, Ledger.LAST_FIELDED]:
		if int(after.get(key, -1)) != int(before.get(key, -2)):
			problem = "%s changed: %s -> %s" % [key, str(before.get(key)), str(after.get(key))]
			break
	if problem == "" and absf(float(after[Ledger.MOMENTUM]) - 1250.5) > 0.01:
		problem = "momentum changed: %s" % str(after[Ledger.MOMENTUM])
	if problem == "" and Array(after[Ledger.BOSSES]) != ["Diablo"]:
		problem = "bosses changed: %s" % str(after[Ledger.BOSSES])
	_judge("a full record survives the save round trip intact", problem)


# A card pulled before the Ledger existed has no record. Asking for one
# has to work rather than crash, so no migration pass is ever needed.
func _a_card_with_no_ledger_gets_one() -> void:
	var card := _card()
	card.ledger = {}
	Ledger.bump(card, Ledger.BATTLES)
	_judge("a card with no record grows one on demand",
		"stayed empty" if Ledger.count(card, Ledger.BATTLES) != 1 else "")


func _prose_reads_as_prose() -> void:
	var fresh := _card()
	var untouched := Ledger.record_lines(fresh)
	var problem := ""
	if untouched.is_empty():
		problem = "an unfielded card said nothing at all"
	elif not untouched[0].contains("never been fielded"):
		problem = "an unfielded card said: %s" % untouched[0]

	if problem == "":
		var veteran := _card()
		Ledger.bump(veteran, Ledger.BATTLES, 214)
		Ledger.bump(veteran, Ledger.WINS, 138)
		Ledger.bump(veteran, Ledger.FELLED, 31)
		Ledger.note_boss(veteran, "Diablo")
		var lines := Ledger.record_lines(veteran)
		var prose := " ".join(lines)
		# The point of the record is that it never reads as a stat block.
		if prose.contains(":"):
			problem = "the record reads like a stat block: %s" % prose
		elif not prose.contains("214 battles"):
			problem = "the record lost its battle count: %s" % prose
	_judge("the record reads as a life, not a column", problem)


func _new_cards_are_stamped_on_acquisition() -> void:
	var template := _card()
	template.card_id = "ledger_probe_%d" % randi()
	var added := GameState.collection.add(template)
	var problem := ""
	if added == null:
		problem = "the card was not added"
	elif int(Ledger.of(added)[Ledger.FIRST_SEEN]) <= 0:
		problem = "a freshly acquired card has no start date"
	_judge("a card's record starts when you acquire it", problem)


# THE ONE THE UNIT TESTS CANNOT COVER.
#
# Everything above tests the data model in isolation. This runs an actual
# BattleSim with an actual team against actual enemies, with the recorder
# attached exactly as the battle screen attaches it, and then checks the
# records landed on the cards the player OWNS - not on the working copies
# the sim was handed.
#
# That last part is the whole risk: a Combatant's CardData has levelling
# and equipment folded into it and is not the collection's instance, so a
# recorder that writes to combatant.data writes to something that is
# thrown away when the fight ends. It would look like it worked.
func _a_real_battle_writes_a_real_record() -> void:
	var team := GameState.get_battle_team()
	if team.is_empty():
		_judge("a real battle writes a real record", "the save slot has no team")
		return

	var before: Dictionary = {}
	for card in team:
		var owned: CardData = GameState.collection.owned.get(card.card_id)
		if owned != null:
			before[card.card_id] = Ledger.count(owned, Ledger.BATTLES)

	var sim := BattleSim.new()
	sim.setup(team, EnemyFactory.build_floor(1, GameState.progression))
	var recorder := LedgerRecorder.watch(sim, {
		"zone": "Emberfall", "weather": "Meteor Storm", "floor": 12, "boss": "",
	})

	# Driven the way the battle screen drives it, minus the waiting.
	var guard := 0
	while sim.running and guard < 400:
		var order := sim.prepare_round()
		if not sim.running or order.is_empty():
			break
		for side in order:
			sim.take_turn(side)
			if not sim.running:
				break
		guard += 1

	var problem := ""
	if recorder == null:
		problem = "the recorder was collected mid-fight"
	elif sim.running:
		problem = "the battle never ended after %d rounds" % guard

	if problem == "":
		var written := 0
		var placed := 0
		for id in before:
			var owned: CardData = GameState.collection.owned.get(id)
			if owned == null:
				continue
			if Ledger.count(owned, Ledger.BATTLES) == int(before[id]) + 1:
				written += 1
			var zones: Dictionary = Ledger.of(owned)[Ledger.ZONES]
			if int(zones.get("Emberfall", 0)) > 0:
				placed += 1
			if Ledger.count(owned, Ledger.DEEPEST) < 12:
				problem = "%s did not record the floor it reached" % id

		if problem == "":
			if written != before.size():
				problem = "only %d of %d team cards recorded the battle" % [written, before.size()]
			elif placed != before.size():
				problem = "only %d of %d recorded where they fought" % [placed, before.size()]

	_judge("a real battle writes a real record to the owned cards", problem)


# --- Reporting ----------------------------------------------------------

func _judge(what: String, problem: String) -> void:
	if problem == "":
		_passes += 1
		print("  PASS  ", what)
	else:
		_failures.append("%s: %s" % [what, problem])
		print("  FAIL  ", what, " -- ", problem)
