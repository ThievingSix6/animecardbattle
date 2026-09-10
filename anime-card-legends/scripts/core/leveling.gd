class_name Leveling
extends RefCounted

# =========================================================
# CARD LEVELS - gold turned into stats.
#
# A card's four combat stats are always derived, never accumulated:
#
#     attack = base_attack * multiplier(level)
#
# so levelling ten times in a row produces exactly the same numbers as
# levelling once ten times over, and a card loaded from an old save
# (which has no base stats recorded) simply adopts its current stats as
# its level-1 baseline the first time it is touched.
#
# The level ceiling rises with rarity: a Common tops out early, an
# Awakened has a very long road. That keeps a lucky pull meaningfully
# better than a heavily invested Common without making the Common
# worthless.
# =========================================================

# Each level adds this fraction of the card's level-1 stats.
const GROWTH_PER_LEVEL := 0.08
# Speed is deliberately flatter, so levelling never scrambles turn order.
const SPEED_GROWTH_PER_LEVEL := 0.02

const MAX_LEVEL_BASE := 20
const MAX_LEVEL_PER_RARITY := 10

const COST_BASE := 200.0
const COST_GROWTH := 1.14
const COST_PER_RARITY := 1.9

# How much of the gold spent comes back when a card is sold.
const REFUND_RATE := 0.5


static func max_level_for(rarity: String) -> int:
	return MAX_LEVEL_BASE + Config.rarity_index(rarity) * MAX_LEVEL_PER_RARITY


static func multiplier(level: int) -> float:
	return 1.0 + float(maxi(level, 1) - 1) * GROWTH_PER_LEVEL


static func speed_multiplier(level: int) -> float:
	return 1.0 + float(maxi(level, 1) - 1) * SPEED_GROWTH_PER_LEVEL


# Gold to go from the card's current level to the next one.
static func cost(card: CardData) -> int:
	return cost_for(card.rarity, card.level)


static func cost_for(rarity: String, level: int) -> int:
	var rarity_mult: float = pow(COST_PER_RARITY, float(Config.rarity_index(rarity)))
	var curve: float = pow(COST_GROWTH, float(maxi(level, 1) - 1))
	return int(round(COST_BASE * rarity_mult * curve))


# Total gold to take a card from its current level up to `target`.
static func cost_to_reach(card: CardData, target: int) -> int:
	var total := 0
	var level := card.level
	while level < target:
		total += cost_for(card.rarity, level)
		level += 1
	return total


# Every level bought so far, valued in gold. Used for the sell price.
static func invested_gold(card: CardData) -> int:
	var total := 0
	for level in range(1, card.level):
		total += cost_for(card.rarity, level)
	return total


static func is_maxed(card: CardData) -> bool:
	return card.level >= effective_max(card)


static func effective_max(card: CardData) -> int:
	# Older cards were saved with the old flat ceiling of 100; the rarity
	# curve is authoritative now.
	return max_level_for(card.rarity)


# --- Applying ---------------------------------------------------------

# Records the card's level-1 stats if that has not happened yet. Safe to
# call on any card, at any time, however it was created.
static func ensure_base(card: CardData) -> void:
	if card.base_attack > 0:
		return
	# A card that arrives already levelled (an old save) has its baseline
	# reconstructed rather than being silently promoted.
	var m := multiplier(card.level)
	var sm := speed_multiplier(card.level)
	card.base_attack = maxi(1, int(round(float(card.attack) / m)))
	card.base_defense = maxi(1, int(round(float(card.defense) / m)))
	card.base_health = maxi(1, int(round(float(card.health) / m)))
	card.base_speed = maxi(1, int(round(float(card.speed) / sm)))


# Recomputes the live stats from the baseline and the current level.
static func apply(card: CardData) -> void:
	ensure_base(card)
	card.max_level = effective_max(card)
	card.level = clampi(card.level, 1, card.max_level)

	var m := multiplier(card.level)
	var sm := speed_multiplier(card.level)
	card.attack = maxi(1, int(round(float(card.base_attack) * m)))
	card.defense = maxi(1, int(round(float(card.base_defense) * m)))
	card.health = maxi(1, int(round(float(card.base_health) * m)))
	card.speed = maxi(1, int(round(float(card.base_speed) * sm)))


# Scales the level-1 baseline itself - what a merge does. Levels are
# preserved, so a merged card keeps every level it was bought.
static func scale_base(card: CardData, stat_growth: float, speed_growth: float) -> void:
	ensure_base(card)
	card.base_attack = maxi(1, int(round(float(card.base_attack) * stat_growth)))
	card.base_defense = maxi(1, int(round(float(card.base_defense) * stat_growth)))
	card.base_health = maxi(1, int(round(float(card.base_health) * stat_growth)))
	card.base_speed = maxi(1, int(round(float(card.base_speed) * speed_growth)))
	apply(card)


# What one more level would add, for the preview line on the detail sheet.
static func preview_gain(card: CardData) -> Dictionary:
	if is_maxed(card):
		return {}
	var next := card.level + 1
	var m := multiplier(next)
	var sm := speed_multiplier(next)
	return {
		"attack":  maxi(1, int(round(float(card.base_attack) * m))) - card.attack,
		"defense": maxi(1, int(round(float(card.base_defense) * m))) - card.defense,
		"health":  maxi(1, int(round(float(card.base_health) * m))) - card.health,
		"speed":   maxi(1, int(round(float(card.base_speed) * sm))) - card.speed,
	}
