class_name GachaSystem
extends RefCounted

# =========================================================
# Owns the card pool and every form of rolling: single pulls,
# banner-filtered pulls, and statistically simulated bulk rolls.
# =========================================================

var pool: Dictionary = {}          # rarity -> Array[CardData] templates
var boss_pool_unlocked := false

var _collection: CollectionSystem
var _luck_provider: Callable       # () -> float, supplied by GameState
var _element_boost_provider: Callable  # () -> String


func _init(collection: CollectionSystem, luck_provider: Callable, element_boost_provider: Callable) -> void:
	_collection = collection
	_luck_provider = luck_provider
	_element_boost_provider = element_boost_provider
	_build_pool()


# ---------------- POOL ----------------

func _build_pool() -> void:
	for r in Config.RARITY_ORDER:
		pool[r] = []

	# Cards derived from the player's own artwork are the roster. Their
	# names come from the filenames, so the pool is whatever is in
	# res://art/cards/.
	var from_art := CardLibrary.build_from_art()
	for card in from_art:
		_add_to_pool(card)

	if not from_art.is_empty():
		# Real art is present: do not dilute it with procedural filler,
		# or the cards the player actually drew would be a minority of
		# their own pulls.
		return

	# No artwork supplied yet - fall back to procedural names so the game
	# is still playable, and keep the archetype starters pullable.
	for template in CardGenerator.build_starters():
		_add_to_pool(template)
	_generate(Config.GENERATED_CARD_COUNT)


func _add_to_pool(card: CardData) -> void:
	if not pool.has(card.rarity):
		pool[card.rarity] = []
	pool[card.rarity].append(card)


func _generate(count: int) -> void:
	var used := {}
	for template in all_templates():
		used[template.card_name] = true
	for card in CardGenerator.generate_batch(count, used):
		_add_to_pool(card)


func all_templates() -> Array[CardData]:
	var all: Array[CardData] = []
	for arr in pool.values():
		for c in arr:
			all.append(c)
	return all


func total_pool_size() -> int:
	var n := 0
	for arr in pool.values():
		n += arr.size()
	return n


func unlock_boss_pool() -> void:
	boss_pool_unlocked = true
	for arr in pool.values():
		for c in arr:
			if c.origin_tag == "boss":
				c.locked = false


# ---------------- ODDS ----------------

func roll_rarity(luck: float = 0.0) -> String:
	var weights := {}
	var total := 0.0
	for r in Config.RARITY_ORDER:
		var w: float = Config.RARITY_WEIGHTS[r]
		if r != "Common":
			w *= (1.0 + luck)
		weights[r] = w
		total += w

	var roll := randf() * total
	var cumulative := 0.0
	for r in Config.RARITY_ORDER:
		cumulative += weights[r]
		if roll <= cumulative:
			return r
	return "Common"


# Probability that any single pull lands in this rarity band.
func card_odds_for_rarity(rarity: String) -> float:
	var total := 0.0
	for w in Config.RARITY_WEIGHTS.values():
		total += w
	if total <= 0.0:
		return 0.0
	return float(Config.RARITY_WEIGHTS.get(rarity, 0.0)) / total


# Probability of pulling this exact card - its rarity band, divided by
# how many cards share that band, multiplied by its mutation's chance.
# This is the number printed on the card face.
func card_odds(card: CardData) -> float:
	var total := 0.0
	for w in Config.RARITY_WEIGHTS.values():
		total += w

	var bucket := candidates(card.rarity, "")
	if bucket.is_empty() or total <= 0.0:
		return 0.0

	var rarity_weight: float = Config.RARITY_WEIGHTS.get(card.rarity, 0.0)
	var base := (rarity_weight / total) * (1.0 / bucket.size())
	return base * Mutations.chance_of(card.modifier)


# ---------------- CANDIDATE SELECTION ----------------

func candidates(rarity: String, origin: String) -> Array:
	var out: Array = []
	for c in pool.get(rarity, []):
		if c.locked:
			continue
		if origin != "" and c.origin_tag != origin:
			continue
		out.append(c)
	return out


# Applies the active weather element boost by repeating matching cards.
func weighted_candidates(rarity: String, origin: String) -> Array:
	var base := candidates(rarity, origin)
	var boost: String = _element_boost_provider.call()
	if base.is_empty() or boost == "":
		return base

	var weighted: Array = []
	for c in base:
		weighted.append(c)
		if c.element == boost:
			for i in Config.EVENT_ELEMENT_WEIGHT - 1:
				weighted.append(c)
	return weighted


# ---------------- PULLING ----------------

func pull(origin: String = "") -> CardData:
	var rarity := roll_rarity(_luck_provider.call())

	# Degrade gracefully: banner -> unfiltered -> Common.
	var options := weighted_candidates(rarity, origin)
	if options.is_empty():
		options = weighted_candidates(rarity, "")
	if options.is_empty():
		options = weighted_candidates("Common", "")
	if options.is_empty():
		return null

	return _collection.add(options[randi() % options.size()])


func pull_many(count: int, origin: String = "") -> Array[CardData]:
	var results: Array[CardData] = []
	for i in count:
		var card := pull(origin)
		if card:
			results.append(card)
	return results


# ---------------- BULK ROLLING ----------------

# Resolves millions/billions of rolls without looping. For each card we
# compute the expected number of hits and sample it; large expectations
# converge to their mean, small ones use a Poisson draw so rare cards
# still feel genuinely random.
func bulk(total_rolls: int, origin: String = "") -> Dictionary:
	var total_weight := 0.0
	for w in Config.RARITY_WEIGHTS.values():
		total_weight += w

	var luck: float = _luck_provider.call()
	var summary := {}

	for rarity in Config.RARITY_ORDER:
		var bucket := candidates(rarity, origin)
		if bucket.is_empty():
			bucket = candidates(rarity, "")
		if bucket.is_empty():
			continue

		var weight: float = Config.RARITY_WEIGHTS.get(rarity, 0.0)
		var luck_mult := 1.0
		if rarity != "Common":
			luck_mult = 1.0 + luck
		var rolls_here: float = float(total_rolls) * (weight * luck_mult / total_weight)
		var per_card: float = rolls_here / bucket.size()

		var new_unique := 0
		var copies_total := 0

		for template in bucket:
			var copies := _poisson(per_card)
			if per_card >= 8.0:
				copies = int(round(per_card))
			if copies <= 0:
				continue
			# Split the copies across mutation tiers by their real odds so a
			# huge bulk roll can genuinely surface a Prismatic or Celestial.
			for mutation_id in Mutations.all_ids():
				var share := Mutations.chance_of(mutation_id)
				var mutated_copies := int(round(copies * share))
				if mutated_copies <= 0 and share * copies > 0.0:
					mutated_copies = _poisson(share * copies)
				if mutated_copies <= 0:
					continue

				var variant := Mutations.apply(template, mutation_id)
				if not _collection.has(variant.card_id):
					new_unique += 1
				_collection.add(variant, mutated_copies)
				copies_total += mutated_copies

		summary[rarity] = {
			"rolls": int(round(rolls_here)),
			"new_unique": new_unique,
			"copies": copies_total,
			"pool_size": bucket.size(),
		}

	EventBus.bulk_roll_finished.emit(summary)
	return summary


func _poisson(lambda: float) -> int:
	if lambda <= 0.0:
		return 0
	var l := exp(-lambda)
	var k := 0
	var p := 1.0
	while true:
		k += 1
		p *= randf()
		if p <= l:
			break
	return k - 1
