class_name Mutations
extends RefCounted

# =========================================================
# MUTATIONS - a second axis of rarity, rolled independently of the
# card's tier. A Common card can roll Celestial; the mutation
# multiplies its stats and gives it a distinct glowing border.
#
# Total odds of a specific card = rarity odds x pool size x mutation
# odds, which is what gets printed on the card face.
# =========================================================

const TIERS: Array[Dictionary] = [
	{"id": "normal",    "name": "",          "weight": 1000000.0, "mult": 1.00, "color": "#8a8f9a", "glow": 0,  "rainbow": false},
	{"id": "silver",    "name": "Silver",    "weight":  180000.0, "mult": 1.18, "color": "#c8d2e0", "glow": 6,  "rainbow": false},
	{"id": "gold",      "name": "Gold",      "weight":   45000.0, "mult": 1.40, "color": "#f5c518", "glow": 10, "rainbow": false},
	{"id": "platinum",  "name": "Platinum",  "weight":    9000.0, "mult": 1.70, "color": "#7fe7e0", "glow": 14, "rainbow": false},
	{"id": "obsidian",  "name": "Obsidian",  "weight":    1800.0, "mult": 2.10, "color": "#6b4ea8", "glow": 18, "rainbow": false},
	{"id": "radiant",   "name": "Radiant",   "weight":     320.0, "mult": 2.60, "color": "#fff3c4", "glow": 22, "rainbow": false},
	{"id": "void",      "name": "Void",      "weight":      55.0, "mult": 3.30, "color": "#3b1a5c", "glow": 26, "rainbow": false},
	{"id": "prismatic", "name": "Prismatic", "weight":       8.0, "mult": 4.40, "color": "#ff6bd6", "glow": 32, "rainbow": true},
	{"id": "celestial", "name": "Celestial", "weight":       0.6, "mult": 6.00, "color": "#ffffff", "glow": 40, "rainbow": true},
]

const DEFAULT_ID := "normal"


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for tier in TIERS:
		ids.append(str(tier["id"]))
	return ids


static func data(mutation_id: String) -> Dictionary:
	for tier in TIERS:
		if tier["id"] == mutation_id:
			return tier
	return TIERS[0]


static func index_of(mutation_id: String) -> int:
	for i in TIERS.size():
		if TIERS[i]["id"] == mutation_id:
			return i
	return 0


static func display_name(mutation_id: String) -> String:
	return str(data(mutation_id)["name"])


static func multiplier(mutation_id: String) -> float:
	return float(data(mutation_id)["mult"])


static func color(mutation_id: String) -> Color:
	return Color(str(data(mutation_id)["color"]))


static func glow(mutation_id: String) -> int:
	return int(data(mutation_id)["glow"])


static func is_rainbow(mutation_id: String) -> bool:
	return bool(data(mutation_id)["rainbow"])


static func is_mutated(mutation_id: String) -> bool:
	return mutation_id != DEFAULT_ID and mutation_id != ""


static func total_weight() -> float:
	var total := 0.0
	for tier in TIERS:
		total += float(tier["weight"])
	return total


static func chance_of(mutation_id: String) -> float:
	var total := total_weight()
	if total <= 0.0:
		return 0.0
	return float(data(mutation_id)["weight"]) / total


# Luck skews mutation rolls the same way it skews rarity.
static func roll(luck: float = 0.0) -> String:
	var weights: Array[float] = []
	var total := 0.0
	for tier in TIERS:
		var w := float(tier["weight"])
		if tier["id"] != DEFAULT_ID:
			w *= (1.0 + luck)
		weights.append(w)
		total += w

	var pick := randf() * total
	var cumulative := 0.0
	for i in TIERS.size():
		cumulative += weights[i]
		if pick <= cumulative:
			return str(TIERS[i]["id"])
	return DEFAULT_ID


# Produces the mutated variant of a template. Mutated copies are separate
# collection entries, so a Gold copy and a plain copy coexist.
static func apply(template: CardData, mutation_id: String) -> CardData:
	if not is_mutated(mutation_id):
		return template

	var card: CardData = template.duplicate()
	card.card_id = template.card_id + "#" + mutation_id
	card.modifier = mutation_id

	var mult := multiplier(mutation_id)
	card.sell_value = int(round(card.sell_value * mult * 2.0))

	# Scales the level-1 baseline rather than the live stats. Touching the
	# live stats alone would make the bonus vanish the next time the card
	# was levelled or reloaded, since those numbers are recomputed from
	# the baseline every time.
	Leveling.scale_base(card, mult, 1.0 + (mult - 1.0) * 0.25)

	return card
