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
const THE_BOY_DARK := "the_boy_dark"
const THE_BOSS := "the_boss"
const TITAN := "titan"


const DEFINITIONS: Array[Dictionary] = [
	{
		"id": "diablo",
		"name": "Diablo",
		"title": "Lord of Hatred",
		"tint": Color("#ef4444"),
		# Five times what he was. He is the Lord of Hatred; he should
		# read as a landmark from across the plaza.
		"height": 17.0,
		"wanders": false,
	},
	{
		"id": "the_boy",
		"name": "The Boy",
		"title": "undefeated",
		"tint": Color("#f5a623"),
		# Double his original 1.6, to stand alongside a 5.7 m player.
		"height": 3.2,
		"wanders": true,
	},
	{
		"id": "the_jokester",
		"name": "The Jokester",
		"title": "reliable source",
		"tint": Color("#a855f7"),
		# Double her original 1.8.
		"height": 3.6,
		"wanders": false,
	},
	{
		"id": "the_boy_dark",
		"name": "The Boy, Dark",
		"title": "what he could have been",
		"tint": Color("#7a4ae0"),
		# Same build as The Boy - he is a version of him, not a giant.
		"height": 3.2,
		"wanders": true,
	},
	{
		"id": "the_boss",
		"name": "The Boss",
		"title": "guards the Rocket Arena",
		"tint": Color("#3b82f6"),
		"height": 3.4,
		"wanders": false,
	},
	{
		"id": "titan",
		"name": "Titan",
		"title": "knows how this all works",
		"tint": Color("#3ecf7e"),
		"height": 3.4,
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


# --- The Boy, Dark ----------------------------------------------------------
#
# Not a rematch. A different fight - the same shape as The Boy, built to
# be worse in every way that matters.

const BOY_DARK_GREETING: Array[String] = [
	"He never had to be like this.",
	"You beat him once. That doesn't mean anything here.",
	"I don't lose. I don't warm up to it either.",
	"Whatever you brought for him won't be enough for me.",
]

const BOY_DARK_REMATCH: Array[String] = [
	"Again, then.",
	"You're still standing. Fix that.",
	"That was luck. This won't be.",
]

const BOY_DARK_WIN: Array[String] = [
	"Not even close.",
	"He would have lost that too.",
	"Come back when it isn't a joke.",
]

const BOY_DARK_LOSS: Array[String] = [
	"...",
	"That's not supposed to happen.",
	"Fine. Once.",
]

# Beating him pays better than The Boy - he is meant to be the harder
# fight of the two.
const BOY_DARK_REWARD_GEMS := 900
const BOY_DARK_REWARD_GOLD := 27000


# --- The Boss -----------------------------------------------------------
#
# Guards the Rocket Arena. A real fight, not a superboss - somewhere in
# the middle of the campaign's own difficulty curve.

const BOSS_GREETING: Array[String] = [
	"Nobody drives in without going through me first.",
	"You want the Arena? Earn it.",
	"House rules. Beat me, or turn around.",
]

const BOSS_REMATCH: Array[String] = [
	"Back again. Good.",
	"Let's see if that was a fluke.",
]

const BOSS_WIN: Array[String] = [
	"Rules are rules. Better luck next time.",
	"The Arena's still mine.",
]

const BOSS_LOSS: Array[String] = [
	"...huh. Fair enough. Go on.",
	"Not bad. Go race.",
]

const BOSS_REWARD_GEMS := 450
const BOSS_REWARD_GOLD := 12000


# --- Titan ----------------------------------------------------------------
#
# Everything The Jokester says is wrong on purpose. Everything Titan
# says is right on purpose - real advice, not a fake tip in disguise.

const TITAN_TIPS: Array[String] = [
	"Merge a card to 100 copies and it ascends - that's the real way past its rarity ceiling, not luck.",
	"A banner's featured cards get extra pull weight while it's up. Everything else still drops, just rarer.",
	"Grudges build from fights you've actually had. Bring a card back against something it's lost to before.",
	"The Legends banner never drops below Epic, but it costs three times as much per pull. Budget for it.",
	"Passives are grouped by family for a reason - reading the family tells you what a new card is FOR before you check its number.",
	"A short bench isn't a mistake the game punishes quietly. Outnumbered is named and paid for on purpose.",
	"Weather boosts one element's pull rate for a while. Worth checking before you spend gems.",
	"Talents make rolling faster and luckier over time - gold well spent early compounds the whole run.",
]

const TITAN_SIGNOFF: Array[String] = [
	"That's really how it works.",
	"Ask if you want the details.",
	"Good hunting out there.",
]


static func titan_line(rng: RandomNumberGenerator) -> String:
	var tip: String = TITAN_TIPS[rng.randi() % TITAN_TIPS.size()]
	var signoff: String = TITAN_SIGNOFF[rng.randi() % TITAN_SIGNOFF.size()]
	return tip + "\n\n" + signoff


static func pick(lines: Array[String], rng: RandomNumberGenerator) -> String:
	if lines.is_empty():
		return ""
	return lines[rng.randi() % lines.size()]
