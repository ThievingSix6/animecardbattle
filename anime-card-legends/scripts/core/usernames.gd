class_name Usernames
extends RefCounted

# =========================================================
# Generates the kind of handle a real player would pick: prefixes,
# mashed nouns, stream tags, leetspeak and trailing numbers.
#
# Seeded generation is supported so a clan's roster is rebuilt
# identically from a save file rather than reshuffling every launch.
# =========================================================

const PREFIXES: Array[String] = [
	"xX", "Lil", "Big", "Dark", "Shadow", "Toxic", "Sleepy", "Based", "Silent",
	"Cyber", "Frost", "Void", "Ghost", "Rogue", "Turbo", "Mega", "Ultra", "Zero",
	"Iron", "Blood", "Night", "Solar", "Hyper", "Grim", "Feral",
]

const CORES: Array[String] = [
	"Reaper", "Sniper", "Slayer", "Blade", "Wolf", "Dragon", "Phantom", "Samurai",
	"Ronin", "Senpai", "Otaku", "Kitsune", "Shogun", "Ninja", "Titan", "Havoc",
	"Vortex", "Raven", "Storm", "Fang", "Onyx", "Crimson", "Katana", "Yokai",
	"Oni", "Sakura", "Kaiju", "Nova", "Ember", "Wraith", "Saber", "Hollow",
	"Bishop", "Comet", "Drift", "Echo", "Jinx", "Karma", "Lotus", "Mecha",
]

const SUFFIXES: Array[String] = [
	"TTV", "YT", "OwO", "UwU", "Gaming", "Prime", "Main", "Diff", "GG",
	"Sama", "Chan", "Kun", "Senpai", "TV", "Live",
]

const LEET := {"a": "4", "e": "3", "i": "1", "o": "0", "s": "5", "t": "7"}


# Returns a fresh handle. Pass an rng for reproducible output.
static func generate(rng: RandomNumberGenerator = null) -> String:
	var style := _pick_index(6, rng)
	var name := ""

	match style:
		0:
			name = "xX_%s%s_Xx" % [_core(rng), _core(rng)]
		1:
			name = "%s%s%s" % [_prefix(rng), _core(rng), _number(rng)]
		2:
			name = "%s_%s" % [_core(rng), _from(SUFFIXES, rng)]
		3:
			name = "%s%s" % [_core(rng), _core(rng)]
		4:
			name = "%s%s" % [_prefix(rng), _core(rng)]
		_:
			name = "%s_%s%s" % [_prefix(rng), _core(rng), _number(rng)]

	# A minority go full leetspeak, the way a real roster looks.
	if _chance(0.18, rng):
		name = leetify(name)

	if _chance(0.22, rng) and not name.ends_with("_"):
		name += _number(rng)

	return name


# Generates `count` handles with no duplicates.
static func generate_many(count: int, rng: RandomNumberGenerator = null) -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	var attempts := 0
	var limit := count * 40

	while out.size() < count and attempts < limit:
		attempts += 1
		var candidate := generate(rng)
		if seen.has(candidate):
			continue
		seen[candidate] = true
		out.append(candidate)

	return out


static func leetify(text: String) -> String:
	var out := ""
	for i in text.length():
		var ch := text[i]
		var lower := ch.to_lower()
		if LEET.has(lower):
			out += str(LEET[lower])
		else:
			out += ch
	return out


# --- helpers ----------------------------------------------------------

static func _pick_index(size: int, rng: RandomNumberGenerator) -> int:
	if rng != null:
		return rng.randi() % size
	return randi() % size


static func _from(pool: Array[String], rng: RandomNumberGenerator) -> String:
	return pool[_pick_index(pool.size(), rng)]


static func _prefix(rng: RandomNumberGenerator) -> String:
	return _from(PREFIXES, rng)


static func _core(rng: RandomNumberGenerator) -> String:
	return _from(CORES, rng)


static func _number(rng: RandomNumberGenerator) -> String:
	var options: Array[String] = ["69", "420", "1337", "99", "007", "42", "13", "88", "21", "77"]
	return _from(options, rng)


static func _chance(probability: float, rng: RandomNumberGenerator) -> bool:
	if rng != null:
		return rng.randf() < probability
	return randf() < probability


# --- clan names --------------------------------------------------------

const CLAN_ADJECTIVES: Array[String] = [
	"Eternal", "Crimson", "Silent", "Ashen", "Radiant", "Fallen", "Iron", "Obsidian",
	"Wandering", "Endless", "Hollow", "Gilded", "Frozen", "Savage", "Astral",
]

const CLAN_NOUNS: Array[String] = [
	"Ronin", "Covenant", "Vanguard", "Ascendants", "Dominion", "Legion", "Choir",
	"Syndicate", "Order", "Pact", "Wardens", "Reverie", "Requiem", "Apex", "Horizon",
]


static func clan_name(rng: RandomNumberGenerator = null) -> String:
	return "%s %s" % [_from(CLAN_ADJECTIVES, rng), _from(CLAN_NOUNS, rng)]


# A short tag, the way clans are shown next to a handle: [ASH]
static func clan_tag(name_text: String) -> String:
	var parts := name_text.split(" ", false)
	if parts.is_empty():
		return "CLAN"
	if parts.size() == 1:
		return str(parts[0]).substr(0, 3).to_upper()
	return (str(parts[0]).substr(0, 2) + str(parts[1]).substr(0, 1)).to_upper()
