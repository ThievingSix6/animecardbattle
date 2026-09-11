class_name LedgerRecorder
extends RefCounted

# =========================================================
# Watches one battle and writes what happened into the Ledger.
#
# Lives outside BattleSim on purpose. The sim already emits everything
# needed, and a recorder that reaches in from outside can be added,
# changed or deleted without touching combat - which matters, because
# combat is the part of this project it is most expensive to break.
#
# KILL ATTRIBUTION WITHOUT CHANGING THE SIM. combatant_died() says who
# died, not who killed them. Rather than widen that signal and ripple
# through every listener, the recorder remembers the last combatant to
# damage each target - from attack_performed and ability_used, which it
# is already listening to - and credits that one when the target falls.
# Slightly approximate for damage-over-time, exactly right otherwise, and
# it costs the sim nothing.
#
# WRITES TO THE COLLECTION, NOT TO THE COMBATANT. A Combatant's CardData
# is a working copy with levelling and equipment folded in; the record
# belongs to the card the player actually owns, so everything is resolved
# back through card_id at the end.
#
# COMMITS ONCE, AT THE END. A battle the player quits out of leaves no
# trace, which is the right call: a fight that did not finish is not
# something the card lived through.
# =========================================================

# What this fight was, for the parts of the record that need context.
var zone := ""
var weather := ""
var floor_number := 0
var boss_name := ""

var _sim: BattleSim
var _last_hit: Dictionary = {}        # Combatant -> Combatant that hit it last
var _kills: Dictionary = {}           # card_id -> enemies finished
var _boss_kills: Dictionary = {}      # card_id -> true
var _fell: Dictionary = {}            # card_id -> true
var _roster: Dictionary = {}          # card_id -> true, everyone who started
var _committed := false


# `context` carries what the battle screen knows and the sim does not:
# which zone, which sky, how deep, and whether the thing on the other
# side has a name worth remembering.
static func watch(sim: BattleSim, context: Dictionary) -> LedgerRecorder:
	var recorder := LedgerRecorder.new()
	recorder.zone = str(context.get("zone", ""))
	recorder.weather = str(context.get("weather", ""))
	recorder.floor_number = int(context.get("floor", 0))
	recorder.boss_name = str(context.get("boss", ""))
	recorder._attach(sim)
	return recorder


func _attach(sim: BattleSim) -> void:
	_sim = sim
	for unit in sim.players:
		_roster[unit.data.card_id] = true

	sim.attack_performed.connect(_on_attack)
	sim.ability_used.connect(_on_ability)
	sim.combatant_died.connect(_on_died)
	sim.battle_ended.connect(_on_ended)


# --- Attribution --------------------------------------------------------

func _on_attack(attacker: Combatant, target: Combatant, damage: int, _kind: String) -> void:
	if damage > 0:
		_last_hit[target] = attacker


func _on_ability(user: Combatant, _ability: String, targets: Array, damage: int, _kind: String) -> void:
	if damage <= 0:
		return
	for target in targets:
		if target is Combatant:
			_last_hit[target] = user


func _on_died(who: Combatant) -> void:
	# One of ours went down.
	if who.side == "player":
		_fell[who.data.card_id] = true
		return

	# One of theirs did. Credit whoever hit it last, if that was a card
	# the player owns rather than a summon or an enemy's own damage.
	var killer: Combatant = _last_hit.get(who)
	if killer == null or killer.side != "player":
		return

	var id := killer.data.card_id
	if not _roster.has(id):
		return

	_kills[id] = int(_kills.get(id, 0)) + 1
	# The name of the thing on the other side only counts for the unit
	# that actually finished it.
	if boss_name != "" and _is_last_standing(who):
		_boss_kills[id] = true


# A boss is credited when the unit that fell was the last one on its
# side - anything else is a minion on the way there.
func _is_last_standing(who: Combatant) -> bool:
	for unit in _sim.enemies:
		if unit != who and unit.alive:
			return false
	return true


# --- Committing ---------------------------------------------------------

func _on_ended(player_won: bool) -> void:
	if _committed:
		return
	_committed = true

	var now := int(Time.get_unix_time_from_system())
	var collection := GameState.collection

	for id in _roster:
		var card: CardData = collection.owned.get(id)
		if card == null:
			continue

		Ledger.bump(card, Ledger.BATTLES)
		Ledger.touch(card, now)
		Ledger.tally(card, Ledger.ZONES, zone)
		Ledger.tally(card, Ledger.WEATHER, weather)
		if floor_number > 0:
			Ledger.reach(card, Ledger.DEEPEST, floor_number)

		if player_won:
			Ledger.bump(card, Ledger.WINS)
		else:
			Ledger.bump(card, Ledger.LOSSES)

		if _fell.has(id):
			Ledger.bump(card, Ledger.FELLED)
		else:
			Ledger.bump(card, Ledger.SURVIVED)

		var finished := int(_kills.get(id, 0))
		if finished > 0:
			Ledger.bump(card, Ledger.KILLS, finished)
		if _boss_kills.has(id):
			Ledger.note_boss(card, boss_name)

	GameState.request_save()
