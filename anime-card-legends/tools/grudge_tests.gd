extends Node

# =========================================================
# GRUDGE ACCEPTANCE TESTS.
#
#   godot --headless --path . tools/GrudgeTests.tscn
#
# Grudges are the first system to read the Ledger and the first to change
# a stat off the back of it, so these cover both halves: that one forms
# only under the exact conditions it should, and that what it then does
# to the card is what the panel says it does.
# =========================================================

const BOSS := "Cinder Tyrant"
const OTHER := "Golem Warlord"

var _passes := 0
var _failures: Array[String] = []


func _ready() -> void:
	GameState.open_slot(1)

	_no_grudge_without_a_name()
	_grudge_deepens_then_caps()
	_bonus_applies_only_to_its_own_boss()
	_penalty_applies_everywhere_else()
	_penalty_has_a_floor()
	_apply_to_leaves_the_stored_card_alone()
	_a_card_with_no_grudges_is_untouched()
	_grudges_survive_the_save_round_trip()
	_lost_fight_forms_it_won_fight_does_not()
	_wording_names_the_boss()

	print("")
	print("=== %d passed, %d failed ===" % [_passes, _failures.size()])
	for line in _failures:
		print("  ", line)
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _card(attack: int = 100, defense: int = 80) -> CardData:
	var card := CardData.new()
	card.card_id = "grudge_test"
	card.card_name = "Test Card"
	card.attack = attack
	card.defense = defense
	card.health = 500
	return card


# --- Cases --------------------------------------------------------------

func _no_grudge_without_a_name() -> void:
	var card := _card()
	var took := Grudges.take(card, "")
	_judge("an unnamed enemy cannot be hated",
		"a grudge formed against nothing" if took or Grudges.has_any(card) else "")


func _grudge_deepens_then_caps() -> void:
	var card := _card()
	for i in 8:
		Grudges.take(card, BOSS)
	_judge("a grudge deepens on each fall and then stops",
		"reached depth %d, cap is %d" % [Grudges.depth(card, BOSS), Grudges.MAX_DEPTH]
			if Grudges.depth(card, BOSS) != Grudges.MAX_DEPTH else "")


func _bonus_applies_only_to_its_own_boss() -> void:
	var card := _card(100, 80)
	Grudges.take(card, BOSS)
	Grudges.take(card, BOSS)

	var focused := Grudges.apply_to(card, BOSS)
	var elsewhere := Grudges.apply_to(card, OTHER)

	var want := int(round(100.0 * (1.0 + Grudges.BONUS_PER_DEPTH * 2.0)))
	var problem := ""
	if focused.attack != want:
		problem = "against its boss it hit %d, expected %d" % [focused.attack, want]
	elif elsewhere.attack >= 100:
		problem = "against a different boss it was not blunted (%d)" % elsewhere.attack
	_judge("the bonus lands on its own boss and nowhere else", problem)


func _penalty_applies_everywhere_else() -> void:
	var card := _card(100)
	Grudges.take(card, BOSS)
	Grudges.take(card, OTHER)
	Grudges.take(card, OTHER)

	# Three depth in total, charged wherever the grudges do not apply.
	var want := int(round(100.0 * (1.0 - Grudges.PENALTY_PER_DEPTH * 3.0)))
	var plain := Grudges.apply_to(card, "")
	_judge("penalties from every grudge stack in an ordinary fight",
		"hit %d, expected %d" % [plain.attack, want] if plain.attack != want else "")


func _penalty_has_a_floor() -> void:
	var card := _card(100)
	# Twenty depth across four bosses - far past what the floor allows.
	for boss in ["A", "B", "C", "D"]:
		for i in Grudges.MAX_DEPTH:
			Grudges.take(card, boss)

	var plain := Grudges.apply_to(card, "")
	var floor_attack := int(round(100.0 * Grudges.MIN_ATTACK_FRACTION))
	_judge("a card cannot be ground below the attack floor",
		"fell to %d, floor is %d" % [plain.attack, floor_attack]
			if plain.attack != floor_attack else "")


# The card in the collection must never be modified by a fight.
func _apply_to_leaves_the_stored_card_alone() -> void:
	var card := _card(100, 80)
	Grudges.take(card, BOSS)
	var _sharpened := Grudges.apply_to(card, BOSS)
	_judge("applying a grudge does not touch the stored card",
		"the stored card became %d/%d" % [card.attack, card.defense]
			if card.attack != 100 or card.defense != 80 else "")


func _a_card_with_no_grudges_is_untouched() -> void:
	var card := _card(100, 80)
	var same := Grudges.apply_to(card, BOSS)
	_judge("a card with no grudges is handed back unchanged",
		"was altered to %d/%d" % [same.attack, same.defense]
			if same.attack != 100 or same.defense != 80 else "")


# Grudges live inside the Ledger, so they ride its save path - including
# the JSON repair that turns every count back into an integer.
func _grudges_survive_the_save_round_trip() -> void:
	var card := _card()
	Grudges.take(card, BOSS)
	Grudges.take(card, BOSS)
	Grudges.take(card, OTHER)

	var revived := _card()
	revived.ledger = Ledger.repair(JSON.parse_string(JSON.stringify(card.ledger)))

	var problem := ""
	if Grudges.depth(revived, BOSS) != 2:
		problem = "%s came back at depth %d" % [BOSS, Grudges.depth(revived, BOSS)]
	elif Grudges.depth(revived, OTHER) != 1:
		problem = "%s came back at depth %d" % [OTHER, Grudges.depth(revived, OTHER)]
	elif typeof(Grudges.all(revived).get(BOSS)) != TYPE_INT:
		problem = "depth came back as %s" % type_string(typeof(Grudges.all(revived).get(BOSS)))
	_judge("grudges survive the save round trip as integers", problem)


# The rule that makes a grudge mean something: you have to have LOST.
func _lost_fight_forms_it_won_fight_does_not() -> void:
	var won := _card()
	var lost := _card()

	# Exactly the branch LedgerRecorder runs when a card falls.
	var player_won := true
	if not player_won and BOSS != "":
		Grudges.take(won, BOSS)
	player_won = false
	if not player_won and BOSS != "":
		Grudges.take(lost, BOSS)

	var problem := ""
	if Grudges.has_any(won):
		problem = "falling in a fight the team won formed a grudge"
	elif not Grudges.has_any(lost):
		problem = "falling in a lost fight formed nothing"
	_judge("only a lost fight leaves a grudge", problem)


func _wording_names_the_boss() -> void:
	var card := _card()
	Grudges.take(card, BOSS)
	Grudges.take(card, BOSS)
	Grudges.take(card, BOSS)

	var lines := Grudges.lines(card)
	var problem := ""
	if lines.is_empty():
		problem = "no lines at all"
	elif not lines[0].contains(BOSS):
		problem = "the line does not name the boss: %s" % lines[0]
	elif not lines[0].contains("%"):
		problem = "the line does not say what it is worth: %s" % lines[0]

	if problem == "":
		var prose := " ".join(Ledger.record_lines(card))
		if not prose.contains(BOSS):
			problem = "the card's record does not mention it: %s" % prose
	_judge("a grudge says who it is against and what it is worth", problem)


# --- Reporting ----------------------------------------------------------

func _judge(what: String, problem: String) -> void:
	if problem == "":
		_passes += 1
		print("  PASS  ", what)
	else:
		_failures.append("%s: %s" % [what, problem])
		print("  FAIL  ", what, " -- ", problem)
