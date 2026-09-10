class_name ChatSystem
extends RefCounted

# =========================================================
# CLAN CHAT - the roster talks, and talks back.
#
# Two things happen here. The AI members chatter among themselves on a
# timer, and when the player says something, one or two of them reply
# after a short delay so it reads like typing rather than an echo.
#
# Every line is built from real state - the actual raid boss, the actual
# clan level, actual member names - so the chat cannot claim something
# the game is not doing.
# =========================================================

const HISTORY_LIMIT := 60

# Seconds between unprompted member-to-member lines.
const IDLE_MIN := 9.0
const IDLE_MAX := 26.0

# How long a member "types" before their reply lands.
const REPLY_MIN := 1.2
const REPLY_MAX := 3.6

# Each entry: {"author": String, "text": String, "player": bool}
var history: Array[Dictionary] = []

var _idle_timer := 0.0
var _next_idle := 12.0

# Replies waiting to land: {"author": String, "text": String, "delay": float}
var _pending: Array[Dictionary] = []


# --- Banter -------------------------------------------------------------

const GREETINGS: Array[String] = [
	"anyone on?", "yo", "morning", "back", "gm", "hey hey",
]

const IDLE_LINES: Array[String] = [
	"pulled nothing but commons for an hour straight",
	"my luck stat is a lie",
	"anyone else stuck on this stage",
	"brb feeding the cat",
	"that ultimate animation never gets old",
	"i keep forgetting to set my team before a run",
	"merging 100 copies should be illegal",
	"the drop rates in this game are criminal",
	"just got a shiny, im never selling it",
	"how do people have this much gold",
	"i respect the grind honestly",
	"whoever designed the boss floors hates us",
]

const REPLY_LINES: Array[String] = [
	"fair", "true", "lmao same", "real", "yeah pretty much",
	"o7", "based", "couldnt agree more", "this",
]


# --- Player message topics ---------------------------------------------
#
# Each topic is a set of trigger words and the replies it can draw. The
# first topic whose words appear wins; anything unmatched falls through
# to a generic acknowledgement.
const TOPICS: Array[Dictionary] = [
	{
		"words": ["hi", "hello", "hey", "yo", "sup", "gm", "morning"],
		"replies": ["hey", "yo", "sup", "welcome back", "o/"],
	},
	{
		"words": ["raid", "boss", "fight"],
		"replies": [
			"im throwing everything i have at it",
			"that thing has way too much hp",
			"hit it once and got deleted, gl",
			"whole clan needs to pile on this one",
		],
	},
	{
		"words": ["help", "how", "stuck", "cant", "advice"],
		"replies": [
			"merge your dupes before anything else, it snowballs",
			"put your tank first in the lane, it buys the rest time",
			"upgrade luck before roll speed imo",
			"if a stage walls you just summon for a bit and come back",
		],
	},
	{
		"words": ["pull", "summon", "roll", "luck", "gacha", "banner"],
		"replies": [
			"the pity in this game is a myth",
			"just went 900 gems for nothing",
			"pulled a legendary off a single roll once, never again",
			"weather events are the only time i summon now",
		],
	},
	{
		"words": ["clan", "perk", "level", "contribute"],
		"replies": [
			"we should push the next perk this week",
			"contributions have been solid honestly",
			"clan perks carried my whole account",
		],
	},
	{
		"words": ["card", "skill", "passive", "deck", "team"],
		"replies": [
			"passives matter way more than raw stats",
			"lifesteal builds are disgusting right now",
			"guardian tanks completely invalidate assassins",
			"whats your team looking like",
		],
	},
	{
		"words": ["thanks", "thank", "ty", "appreciate"],
		"replies": ["np", "anytime", "gg", "happy to help"],
	},
	{
		"words": ["bye", "gn", "night", "later", "cya"],
		"replies": ["gn", "later", "o7", "cya"],
	},
]

const GENERIC_REPLIES: Array[String] = [
	"fair enough", "yeah", "hm", "makes sense", "true", "lol",
	"i mean, valid", "no notes",
]


# --- Sending -------------------------------------------------------------

func post(author: String, text: String, from_player: bool) -> Dictionary:
	var entry := {"author": author, "text": text, "player": from_player}
	history.append(entry)
	while history.size() > HISTORY_LIMIT:
		history.remove_at(0)
	return entry


# The player speaks. Queues replies from one or two members; the caller
# gets the player's own message back to render immediately.
func send(text: String, members: Array[Dictionary]) -> Dictionary:
	var trimmed := text.strip_edges()
	if trimmed == "":
		return {}

	var entry := post("You", trimmed, true)

	if members.is_empty():
		return entry

	var replies := _replies_for(trimmed)
	var responders := 1
	if replies.size() > 1 and randf() < 0.45:
		responders = 2

	for i in mini(responders, replies.size()):
		var member: Dictionary = members[randi() % members.size()]
		_pending.append({
			"author": str(member["username"]),
			"text": replies[i],
			"delay": randf_range(REPLY_MIN, REPLY_MAX) * float(i + 1),
		})

	return entry


# Picks reply lines for whatever the player said.
func _replies_for(text: String) -> Array[String]:
	var lower := text.to_lower()

	for topic in TOPICS:
		var words: Array = topic["words"]
		for word in words:
			if _mentions(lower, str(word)):
				var pool: Array = topic["replies"]
				return _pick_two(pool)

	return _pick_two(GENERIC_REPLIES)


# Whole-word match, so "hitting" does not trigger on "hi".
func _mentions(haystack: String, needle: String) -> bool:
	var padded := " " + haystack.replace(",", " ").replace(".", " ").replace("?", " ").replace("!", " ") + " "
	return padded.contains(" " + needle + " ")


func _pick_two(pool: Array) -> Array[String]:
	var out: Array[String] = []
	if pool.is_empty():
		return out

	var first: int = randi() % pool.size()
	out.append(str(pool[first]))

	if pool.size() > 1:
		var second: int = randi() % pool.size()
		if second == first:
			second = (second + 1) % pool.size()
		out.append(str(pool[second]))

	return out


# --- Background ------------------------------------------------------------

# Advances pending replies and unprompted chatter. Returns any messages
# that landed this frame, so the caller can announce them.
func update(delta: float, members: Array[Dictionary], context: Dictionary) -> Array[Dictionary]:
	var landed: Array[Dictionary] = []

	# Replies the player is waiting on come first.
	var still_pending: Array[Dictionary] = []
	for reply in _pending:
		reply["delay"] = float(reply["delay"]) - delta
		if float(reply["delay"]) <= 0.0:
			landed.append(post(str(reply["author"]), str(reply["text"]), false))
		else:
			still_pending.append(reply)
	_pending = still_pending

	if members.is_empty():
		return landed

	_idle_timer += delta
	if _idle_timer < _next_idle:
		return landed

	_idle_timer = 0.0
	_next_idle = randf_range(IDLE_MIN, IDLE_MAX)

	var member: Dictionary = members[randi() % members.size()]
	landed.append(post(str(member["username"]), _idle_line(context), false))

	# Sometimes somebody answers, so the room feels like a conversation
	# rather than a queue of announcements.
	if members.size() > 1 and randf() < 0.4:
		var other: Dictionary = members[randi() % members.size()]
		if str(other["username"]) != str(member["username"]):
			_pending.append({
				"author": str(other["username"]),
				"text": REPLY_LINES[randi() % REPLY_LINES.size()],
				"delay": randf_range(REPLY_MIN, REPLY_MAX),
			})

	return landed


# Chatter that knows what is actually happening in the game.
func _idle_line(context: Dictionary) -> String:
	var raid_boss := str(context.get("raid_boss", ""))
	var clan_level := int(context.get("clan_level", 1))
	var newest_card := str(context.get("newest_card", ""))

	var options: Array[String] = []
	options.append_array(IDLE_LINES)

	if raid_boss != "":
		options.append("%s is not going down easy" % raid_boss)
		options.append("someone help me on %s" % raid_boss)
		options.append("who else is hitting %s" % raid_boss)

	if clan_level >= 2:
		options.append("clan level %d feels good" % clan_level)

	if newest_card != "":
		options.append("just pulled %s, thoughts?" % newest_card)
		options.append("is %s any good or did i waste gems" % newest_card)

	if history.is_empty():
		options.append_array(GREETINGS)

	return options[randi() % options.size()]


# --- Serialization -----------------------------------------------------------

func to_array() -> Array:
	return history.duplicate(true)


func from_array(stored) -> void:
	history.clear()
	_pending.clear()
	if typeof(stored) != TYPE_ARRAY:
		return
	for entry in stored:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		history.append({
			"author": str(entry.get("author", "")),
			"text": str(entry.get("text", "")),
			"player": bool(entry.get("player", false)),
		})
