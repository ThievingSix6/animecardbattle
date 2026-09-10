class_name Npcs
extends RefCounted

# =========================================================
# The people in the city.
#
# Models go in res://art/models/npc/<id>.glb - the ids are the
# constants below. Each finds its own AnimationPlayer and matches clips
# by keyword, the same way the player model does, so "Run", "run_loop"
# and "Armature|Running" all bind.
#
# With no model an NPC still stands there as a coloured marker and
# still talks, so the writing can be tested before the art lands.
# =========================================================

const DIABLO := "diablo"
const THE_BOY := "the_boy"
const THE_JOKESTER := "the_jokester"


const DEFINITIONS: Array[Dictionary] = [
	{
		"id": "diablo",
		"name": "Diablo",
		"title": "Lord of Hatred",
		"tint": Color("#ef4444"),
		"height": 3.4,
		"wanders": false,
	},
	{
		"id": "the_boy",
		"name": "The Boy",
		"title": "undefeated",
		"tint": Color("#f5a623"),
		"height": 1.6,
		"wanders": true,
	},
	{
		"id": "the_jokester",
		"name": "The Jokester",
		"title": "reliable source",
		"tint": Color("#a855f7"),
		"height": 1.8,
		"wanders": false,
	},
]


static func get_npc(id: String) -> Dictionary:
	for npc in DEFINITIONS:
		if str(npc["id"]) == id:
			return npc
	return DEFINITIONS[0]


static func display_name(id: String) -> String:
	return str(get_npc(id)["name"])


static func title(id: String) -> String:
	return str(get_npc(id)["title"])


static func tint(id: String) -> Color:
	return get_npc(id)["tint"]


static func height(id: String) -> float:
	return float(get_npc(id)["height"])


# --- The Boy --------------------------------------------------------------
#
# He does not talk much. He does not have to.

const BOY_GREETING: Array[String] = [
	"...you want to go?",
	"I've beaten everyone in this city.",
	"Nobody's taken a round off me yet.",
	"You look like the last guy. He's not around any more.",
	"Sure. Bring your best five.",
]

const BOY_REMATCH: Array[String] = [
	"Again?",
	"You got lucky. Once.",
	"I've been practising.",
]

const BOY_WIN: Array[String] = [
	"Told you.",
	"Come back when you've levelled those.",
	"That wasn't close.",
]

const BOY_LOSS: Array[String] = [
	"...huh.",
	"Okay. Okay. That's fair.",
	"Nobody's done that before.",
]

# What beating him is worth. He is the hardest single fight in the game
# outside the gauntlet's last wave.
const BOY_REWARD_GEMS := 600
const BOY_REWARD_GOLD := 18000


# --- The Jokester ----------------------------------------------------------
#
# Every one of these is false. She says them with total conviction, and
# the game never implements a single one. That is the joke - and it is
# why they are all things that cost nothing to try and quietly waste a
# minute of your life.

const JOKESTER_TIPS: Array[String] = [
	"If you sell a card at exactly midnight it comes back Legendary. Every time.",
	"Hold the summon button for nine seconds before letting go. The pity counter doubles. Everyone knows this.",
	"There's a seventh zone. You get there by losing on purpose to the same boss three times.",
	"Name a card after yourself and it gets a hidden stat. I've seen the code.",
	"The weather events are on a real clock. Set your PC to 3AM and it's always Meteor Storm.",
	"Diablo has a secret good ending where he joins your clan. You just have to lose politely.",
	"Cards you never put in your team gain experience faster. It's called jealousy scaling.",
	"If your clan hits level 10 the developer personally messages you.",
	"Walking backwards through the portal takes you to the zone BEFORE the first one.",
	"There's a card called The Jokester. She's the rarest one. Keep rolling.",
	"Equipping nothing at all counts as a full set bonus. Look it up.",
	"The boy is beatable if you talk to him exactly eleven times first.",
	"Every hundredth pull is guaranteed Secret. I've been counting since I got here.",
	"Your gold earns interest while the game is closed. That's why I never close it.",
	"The tower has a basement.",
]

const JOKESTER_SIGNOFF: Array[String] = [
	"Don't tell anyone I told you.",
	"I'd act on that fast, personally.",
	"Anyway. Good luck out there.",
	"You didn't hear it from me.",
	"I'm never wrong about this stuff.",
]


# A tip and a sign-off, picked together so a second conversation is a
# different one.
static func jokester_line(rng: RandomNumberGenerator) -> String:
	var tip: String = JOKESTER_TIPS[rng.randi() % JOKESTER_TIPS.size()]
	var signoff: String = JOKESTER_SIGNOFF[rng.randi() % JOKESTER_SIGNOFF.size()]
	return tip + "\n\n" + signoff


static func pick(lines: Array[String], rng: RandomNumberGenerator) -> String:
	if lines.is_empty():
		return ""
	return lines[rng.randi() % lines.size()]
