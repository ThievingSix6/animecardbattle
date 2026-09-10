class_name GachaSystem
extends RefCounted

# =========================================================
# Owns the card pool and every form of rolling: single pulls,
# banner-filtered pulls, and statistically simulated bulk rolls.
# =========================================================

var pool: Dictionary = {}          # rarity -> Array[CardData] templates
var boss_pool_unlocked := false

# Pulls since the last Epic+ / Legendary+, tracked per banner. Chasing a
# banner is progress toward that banner, and switching away does not
# throw the progress out.
var pity: Dictionary = {}          # banner_id -> {"epic": int, "legendary": int}

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

# `floor_rarity` is the lowest tier the draw may produce - the legends
# banner uses it to guarantee Epic or better. `at_least` is the pity
# system forcing a floor for this one pull.
func roll_rarity(luck: float = 0.0, floor_rarity: String = "Common", at_least: String = "") -> String:
	var lowest := Config.rarity_index(floor_rarity)
	if at_least != "":
		lowest = maxi(lowest, Config.rarity_index(at_least))

	var weights := {}
	var total := 0.0
	for r in Config.RARITY_ORDER:
		if Config.rarity_index(r) < lowest:
			continue
		var w: float = Config.RARITY_WEIGHTS[r]
		if r != "Common":
			w *= (1.0 + luck)
		weights[r] = w
		total += w

	if total <= 0.0:
		return Config.RARITY_ORDER[lowest]

	var roll := randf() * total
	var cumulative := 0.0
	for r in Config.RARITY_ORDER:
		if not weights.has(r):
			continue
		cumulative += weights[r]
		if roll <= cumulative:
			return r
	return Config.RARITY_ORDER[lowest]


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

	var bucket := candidates(card.rarity, Banners.STANDARD)
	if bucket.is_empty() or total <= 0.0:
		return 0.0

	var rarity_weight: float = Config.RARITY_WEIGHTS.get(card.rarity, 0.0)
	var base := (rarity_weight / total) * (1.0 / bucket.size())
	return base * Mutations.chance_of(card.modifier)


# ---------------- CANDIDATE SELECTION ----------------

# Every card of this rarity the given banner is willing to produce.
func candidates(rarity: String, banner_id: String) -> Array:
	var out: Array = []
	for c in pool.get(rarity, []):
		if c.locked:
			continue
		if banner_id != "" and not Banners.accepts(banner_id, c):
			continue
		out.append(c)
	return out


# The draw bag: the banner's rate-up repeats its own themed cards, and
# the active weather event repeats cards of the boosted element. A card
# that is both appears many times over.
func weighted_candidates(rarity: String, banner_id: String) -> Array:
	var base := candidates(rarity, banner_id)
	if base.is_empty():
		return base

	var boost: String = _element_boost_provider.call()

	var weighted: Array = []
	for c in base:
		var entries := 1
		if banner_id != "":
			entries = Banners.entries(banner_id, c)
		if boost != "" and c.element == boost:
			entries *= Config.EVENT_ELEMENT_WEIGHT
		for i in entries:
			weighted.append(c)
	return weighted


# How many of the banner's own themed cards exist, for the banner panel.
func featured_cards(banner_id: String) -> Array[CardData]:
	var out: Array[CardData] = []
	for c in all_templates():
		if c.locked:
			continue
		if Banners.is_featured(banner_id, c):
			out.append(c)
	out.sort_custom(func(a, b):
		var ra := Config.rarity_index(a.rarity)
		var rb := Config.rarity_index(b.rarity)
		if ra != rb:
			return ra > rb
		return a.card_name.naturalnocasecmp_to(b.card_name) < 0)
	return out


func banner_pool_size(banner_id: String) -> int:
	var n := 0
	for rarity in Config.RARITY_ORDER:
		n += candidates(rarity, banner_id).size()
	return n


# ---------------- PULLING ----------------

# ---------------- PITY ----------------

func pity_for(banner_id: String) -> Dictionary:
	if not pity.has(banner_id):
		pity[banner_id] = {"epic": 0, "legendary": 0}
	return pity[banner_id]


# The rarity this pull is owed, if any counter has run out.
func _pity_floor(banner_id: String) -> String:
	var banner := Banners.get_banner(banner_id)
	var counters := pity_for(banner_id)

	if int(counters["legendary"]) + 1 >= int(banner["pity_legendary"]):
		return "Legendary"
	if int(counters["epic"]) + 1 >= int(banner["pity_epic"]):
		return "Epic"
	return ""


func _record_pull(banner_id: String, rarity: String) -> void:
	var counters := pity_for(banner_id)
	var tier := Config.rarity_index(rarity)

	if tier >= Config.rarity_index("Epic"):
		counters["epic"] = 0
	else:
		counters["epic"] = int(counters["epic"]) + 1

	if tier >= Config.rarity_index("Legendary"):
		counters["legendary"] = 0
	else:
		counters["legendary"] = int(counters["legendary"]) + 1


# Pulls until the guaranteed tier is reachable, in case a banner has no
# card at all in the tier the pity system just demanded.
func pulls_until_legendary(banner_id: String) -> int:
	var banner := Banners.get_banner(banner_id)
	return maxi(0, int(banner["pity_legendary"]) - int(pity_for(banner_id)["legendary"]))


# ---------------- PULLING ----------------

func pull(banner_id: String = "", forced_rarity: String = "") -> CardData:
	if banner_id == "":
		banner_id = Banners.STANDARD

	var owed := _pity_floor(banner_id)
	var rarity := forced_rarity

	if rarity == "":
		rarity = roll_rarity(
			_luck_provider.call(), Banners.floor_rarity(banner_id), owed)
	elif owed != "" and Config.rarity_index(owed) > Config.rarity_index(rarity):
		# A caller-imposed floor must never cancel a bigger one the pity
		# system already owes - the ten-pull's Rare guarantee should not
		# eat the Legendary that was due on that exact pull.
		rarity = roll_rarity(
			_luck_provider.call(), Banners.floor_rarity(banner_id), owed)

	# Degrade gracefully. A banner that owns nothing at the rolled rarity
	# falls back down the tiers rather than dropping the pull entirely,
	# so an early roster of a dozen images still summons. It never falls
	# below the banner's own floor - the legends banner promises Epic and
	# has to keep that promise even when it is short of cards.
	var lowest := Config.rarity_index(Banners.floor_rarity(banner_id))
	var options := weighted_candidates(rarity, banner_id)
	var tier := Config.rarity_index(rarity)
	while options.is_empty() and tier > lowest:
		tier -= 1
		rarity = Config.RARITY_ORDER[tier]
		options = weighted_candidates(rarity, banner_id)
	if options.is_empty():
		return null

	_record_pull(banner_id, rarity)
	return _collection.add(options[randi() % options.size()])


func pull_many(count: int, banner_id: String = "") -> Array[CardData]:
	if banner_id == "":
		banner_id = Banners.STANDARD

	var results: Array[CardData] = []
	var best := -1

	for i in count:
		# The last card of a ten-pull is floored at Rare if nothing good
		# has turned up yet, so a full-price ten never comes back as ten
		# Commons. It replaces that pull rather than adding an eleventh.
		var forced := ""
		if count >= 10 and i == count - 1 and best < Config.rarity_index("Rare"):
			forced = "Rare"

		var card := pull(banner_id, forced)
		if card == null:
			continue
		results.append(card)
		best = maxi(best, Config.rarity_index(card.rarity))

	return results


# ---------------- BULK ROLLING ----------------

# Resolves millions/billions of rolls without looping. For each card we
# compute the expected number of hits and sample it; large expectations
# converge to their mean, small ones use a Poisson draw so rare cards
# still feel genuinely random.
func bulk(total_rolls: int, banner_id: String = "") -> Dictionary:
	if banner_id == "":
		banner_id = Banners.STANDARD

	var total_weight := 0.0
	for w in Config.RARITY_WEIGHTS.values():
		total_weight += w

	var luck: float = _luck_provider.call()
	var summary := {}

	for rarity in Config.RARITY_ORDER:
		var bucket := candidates(rarity, banner_id)
		if bucket.is_empty():
			bucket = candidates(rarity, Banners.STANDARD)
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
