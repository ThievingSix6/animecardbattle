class_name Ledger
extends RefCounted

# =========================================================
# WHAT A CARD HAS LIVED THROUGH.
#
# Every other autobattler treats a card as a row in a table: two copies
# of the same card are the same card, so the only thing that makes yours
# yours is the number on it - and numbers always lose to bigger numbers.
# That is the whole reason old cards become trash.
#
# The Ledger is the fix. Each owned card carries a private record of what
# it has actually DONE: battles entered, battles lost, who it killed,
# which named bosses it finished, how deep it has been, which weather it
# fought under, how long it has sat unused. None of it is a stat. None of
# it makes the card stronger on its own.
#
# It is EVIDENCE, and other systems read it. An evolution that asks for
# "a card that has lost forty battles" cannot be bought, rerolled or
# rushed - only lived. A fresh Legendary has a blank record; the Common
# you have carried since hour two has a two-hundred-hour one, and for a
# growing number of things it will be the only card that qualifies.
#
# WRITE IT EARLY, READ IT LATER. Nothing in the game keys off this yet.
# That is deliberate and it is the entire reason to build it first: a
# history is only worth anything if it started before anyone was looking.
# Every hour this ships ahead of its first consumer is an hour of record
# every player already has when that consumer arrives.
#
# STORAGE. One Dictionary hanging off CardData, JSON-safe all the way
# down, so it rides the existing save format with one entry added to
# CARD_FIELDS. It survives the round trip through JSON, which turns every
# number into a float - see repair().
# =========================================================

# --- Keys ---------------------------------------------------------------
#
# Named rather than inlined, because these strings end up in save files
# and a typo in one becomes a silently-lost record that nobody notices
# for a month.
const BATTLES := "battles"          # fights entered
const WINS := "wins"                # fights the team won
const LOSSES := "losses"            # fights the team lost
const SURVIVED := "survived"        # fights it was still standing at the end of
const FELLED := "felled"            # times it was defeated
const KILLS := "kills"              # enemies it personally finished
const BOSSES := "bosses"            # names of bosses it landed the last hit on
const DEEPEST := "deepest"          # deepest floor it has been taken to
const ZONES := "zones"              # zone name -> fights there
const WEATHER := "weather"          # weather event id -> fights under it
const FIRST_SEEN := "first_seen"    # unix seconds, when it was obtained
const LAST_FIELDED := "last_fielded" # unix seconds, last fight it was in
const MOMENTUM := "momentum"        # metres carried as a Passenger (the arena)
const SPARED := "spared"            # times the sell screen was opened and backed out of
const GRUDGES := "grudges"          # boss name -> how deep the grudge runs

# Every integer key, for repair() and for a clean empty record.
const COUNTERS: Array[String] = [
	BATTLES, WINS, LOSSES, SURVIVED, FELLED, KILLS, DEEPEST,
	FIRST_SEEN, LAST_FIELDED, SPARED,
]
# Every {name -> count} map. Grudges live here because that is exactly
# their shape, which means they save, load and repair for free.
const TALLIES: Array[String] = [ZONES, WEATHER, GRUDGES]


# A blank record. `now` is passed in rather than read here so a batch of
# cards pulled together share one timestamp exactly.
static func blank(now: int = 0) -> Dictionary:
	var when := now
	if when <= 0:
		when = int(Time.get_unix_time_from_system())

	var record := {}
	for key in COUNTERS:
		record[key] = 0
	for key in TALLIES:
		record[key] = {}
	record[BOSSES] = []
	record[MOMENTUM] = 0.0
	record[FIRST_SEEN] = when
	return record


# The record on a card, created on first touch. Everything else here goes
# through this, so a card that predates the Ledger gets one the moment
# anything asks - no migration pass needed.
static func of(card: CardData) -> Dictionary:
	if card == null:
		return blank()
	if not (card.ledger is Dictionary) or card.ledger.is_empty():
		card.ledger = blank()
	return card.ledger


# --- Writing ------------------------------------------------------------

static func bump(card: CardData, key: String, by: int = 1) -> void:
	var record := of(card)
	record[key] = int(record.get(key, 0)) + by


static func tally(card: CardData, key: String, entry: String) -> void:
	if entry == "":
		return
	var record := of(card)
	var counts: Dictionary = record.get(key, {})
	counts[entry] = int(counts.get(entry, 0)) + 1
	record[key] = counts


# Highest-water marks rather than counts: the deepest floor it has been
# taken to, not how many times.
static func reach(card: CardData, key: String, value: int) -> void:
	var record := of(card)
	if value > int(record.get(key, 0)):
		record[key] = value


static func add_momentum(card: CardData, metres: float) -> void:
	var record := of(card)
	record[MOMENTUM] = float(record.get(MOMENTUM, 0.0)) + maxf(metres, 0.0)


# A boss it finished off. Recorded by name and only once each, so the
# record reads as a list of things it has beaten rather than a counter.
static func note_boss(card: CardData, boss_name: String) -> void:
	if boss_name == "":
		return
	var record := of(card)
	var beaten: Array = record.get(BOSSES, [])
	if not beaten.has(boss_name):
		beaten.append(boss_name)
		record[BOSSES] = beaten


static func touch(card: CardData, now: int = 0) -> void:
	var when := now
	if when <= 0:
		when = int(Time.get_unix_time_from_system())
	of(card)[LAST_FIELDED] = when


# --- Reading ------------------------------------------------------------

static func count(card: CardData, key: String) -> int:
	return int(of(card).get(key, 0))


static func momentum(card: CardData) -> float:
	return float(of(card).get(MOMENTUM, 0.0))


static func bosses(card: CardData) -> Array:
	return of(card).get(BOSSES, [])


# Days since it was last in a fight. A card that has never been fielded
# returns the days since it was obtained, which is the honest answer.
static func days_idle(card: CardData) -> int:
	var record := of(card)
	var last := int(record.get(LAST_FIELDED, 0))
	if last <= 0:
		last = int(record.get(FIRST_SEEN, 0))
	if last <= 0:
		return 0
	var seconds := int(Time.get_unix_time_from_system()) - last
	return maxi(0, seconds / 86400)


static func days_owned(card: CardData) -> int:
	var first := int(of(card).get(FIRST_SEEN, 0))
	if first <= 0:
		return 0
	return maxi(0, (int(Time.get_unix_time_from_system()) - first) / 86400)


# Has this card done anything at all? Used to decide whether a card back
# is worth showing a record on.
static func has_history(card: CardData) -> bool:
	return count(card, BATTLES) > 0 or momentum(card) > 0.0


# --- The card's back ----------------------------------------------------
#
# The record is shown as PROSE, never as a stat block. "Fought in 214
# battles. Fell 31 times." reads as a life; "battles: 214" reads as a
# column, and a column invites optimising. The distinction matters more
# than it sounds - it is the difference between a player protecting a
# card and a player farming one.

static func record_lines(card: CardData) -> Array[String]:
	var lines: Array[String] = []
	if card == null:
		return lines

	var record := of(card)
	var battles := int(record.get(BATTLES, 0))

	if battles <= 0:
		var held := days_owned(card)
		if held >= 1:
			lines.append("Has never been fielded. %s in the vault." % _days(held))
		else:
			lines.append("Has never been fielded.")
		# Falls through rather than returning: a card can hold a grudge
		# and have no battles behind it - one taken, then the fight
		# reset, or a card handed a history by something other than
		# combat. Who it hates is part of its story either way.
		_append_grudges(record, lines)
		return lines

	var won := int(record.get(WINS, 0))
	lines.append("Fought %s, won %d." % [_plural(battles, "battle"), won])

	var felled := int(record.get(FELLED, 0))
	if felled > 0:
		lines.append("Fell %s." % _plural(felled, "time"))
	else:
		lines.append("Has never fallen.")

	var kills := int(record.get(KILLS, 0))
	if kills > 0:
		lines.append("Finished %s." % _plural(kills, "opponent"))

	var beaten: Array = record.get(BOSSES, [])
	if not beaten.is_empty():
		lines.append("Landed the last blow on %s." % _list(beaten))

	var deepest := int(record.get(DEEPEST, 0))
	if deepest > 0:
		lines.append("Been as deep as floor %d." % deepest)

	var home: String = _most(record.get(ZONES, {}))
	if home != "":
		lines.append("Fought most often in %s." % home)

	var sky: String = _most(record.get(WEATHER, {}))
	if sky != "":
		lines.append("Has seen %s more than any other sky." % sky)

	var carried := momentum(card)
	if carried > 0.0:
		lines.append("Carried %s as a passenger." % _distance(carried))

	var idle := days_idle(card)
	if idle >= 7:
		lines.append("Untouched for %s." % _days(idle))

	var spared := int(record.get(SPARED, 0))
	if spared > 0:
		lines.append("Nearly sold %s." % _plural(spared, "time"))

	_append_grudges(record, lines)
	return lines


# Named, not counted. WHO it hates belongs in the story of the card; what
# the hatred is worth belongs in the grudges panel, with numbers.
static func _append_grudges(record: Dictionary, lines: Array[String]) -> void:
	var held: Array[String] = []
	var grudges: Variant = record.get(GRUDGES, {})
	if grudges is Dictionary:
		for boss_name in grudges:
			held.append(str(boss_name))
	if held.is_empty():
		return
	held.sort()
	lines.append("Has not forgotten %s." % _list(held))


# --- Save round trip ----------------------------------------------------

# JSON has one number type, so every integer in a saved record comes back
# as a float and every count silently becomes 214.0. Left alone that is
# harmless until something does `record[BATTLES] += 1` and writes 215.0,
# and then compares it against an int somewhere and gets a type error a
# hundred hours into someone's save.
#
# Repaired on load rather than defended against at every read site.
static func repair(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return blank()

	var record: Dictionary = raw
	var fixed: Dictionary = blank(int(record.get(FIRST_SEEN, 0)))

	for key in COUNTERS:
		if record.has(key):
			fixed[key] = int(record[key])

	for key in TALLIES:
		var counts := {}
		var stored: Variant = record.get(key, {})
		if stored is Dictionary:
			for entry in stored:
				counts[str(entry)] = int(stored[entry])
		fixed[key] = counts

	var beaten: Array = []
	var stored_bosses: Variant = record.get(BOSSES, [])
	if stored_bosses is Array:
		for name in stored_bosses:
			beaten.append(str(name))
	fixed[BOSSES] = beaten

	fixed[MOMENTUM] = float(record.get(MOMENTUM, 0.0))
	return fixed


# --- Wording ------------------------------------------------------------

static func _plural(n: int, word: String) -> String:
	if n == 1:
		return "1 " + word
	return "%d %ss" % [n, word]


static func _days(n: int) -> String:
	if n >= 365:
		return _plural(n / 365, "year")
	if n >= 60:
		return _plural(n / 30, "month")
	return _plural(n, "day")


static func _distance(metres: float) -> String:
	if metres >= 1000.0:
		return "%.1f km" % (metres / 1000.0)
	return "%d m" % int(metres)


# The entry with the highest count, or "" for an empty tally.
static func _most(counts: Variant) -> String:
	if not (counts is Dictionary):
		return ""
	var best := ""
	var most := 0
	for entry in counts:
		var n := int(counts[entry])
		if n > most:
			most = n
			best = str(entry)
	return best


static func _list(items: Array) -> String:
	if items.is_empty():
		return ""
	if items.size() == 1:
		return str(items[0])
	if items.size() == 2:
		return "%s and %s" % [str(items[0]), str(items[1])]

	var head: Array[String] = []
	for i in items.size() - 1:
		head.append(str(items[i]))
	return "%s and %s" % [", ".join(head), str(items[items.size() - 1])]
