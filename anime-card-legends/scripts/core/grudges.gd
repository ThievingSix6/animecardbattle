class_name Grudges
extends RefCounted

# =========================================================
# CARDS THAT REMEMBER WHO KILLED THEM.
#
# The first system to read the Ledger, and the reason the Ledger was
# worth writing before anything read it: a grudge cannot be bought,
# crafted or rolled for. The only way to get one is to have lost.
#
# HOW ONE FORMS. A card takes a grudge when all three are true:
#
#   the fight was against a boss with a NAME,
#   the card fell in it,
#   and the team lost.
#
# Not "died to a boss" - died to a boss in a fight you LOST. That is a
# specific, memorable evening, and it is deterministic: no roll, no
# chance, no wondering whether it triggered. You know exactly what you
# did to earn it.
#
# WHAT IT DOES. Against that boss, the card is far more dangerous.
# Everywhere else it is slightly worse, forever, and the penalties from
# every grudge it holds stack. A card with six grudges is a blunt
# instrument in ordinary fights and a scalpel against six specific
# enemies.
#
# That trade is the point. It is the answer to "why would I keep this
# card" that does not involve the card being strong: it is not strong,
# it is SPECIFIC, and the thing it is specific about is a wall you are
# currently stuck on.
#
# A grudge cannot be removed. Selling the card is the only way out, and
# the Ledger already records how many times you nearly did.
# =========================================================

# Stored in the card's own Ledger, so it saves, loads and repairs with
# everything else and needs no storage of its own.
const KEY := Ledger.GRUDGES

# How far a grudge can deepen. Falling to the same boss a sixth time
# changes nothing - otherwise the optimal play is to throw a card at a
# boss repeatedly, which is farming, not a grudge.
const MAX_DEPTH := 5

# Per depth, against the named boss only.
const BONUS_PER_DEPTH := 0.18

# Per depth, against everything else, and it stacks across every grudge
# the card holds.
const PENALTY_PER_DEPTH := 0.025

# However many grudges a card collects, it never drops below this much of
# its attack. A card ruined past usefulness stops being a decision.
const MIN_ATTACK_FRACTION := 0.6


# --- Reading ------------------------------------------------------------

static func all(card: CardData) -> Dictionary:
	if card == null:
		return {}
	return Ledger.of(card).get(KEY, {})


static func depth(card: CardData, boss_name: String) -> int:
	if boss_name == "":
		return 0
	return int(all(card).get(boss_name, 0))


static func has_any(card: CardData) -> bool:
	return not all(card).is_empty()


# Every depth added together, which is what the everywhere-else penalty
# is charged on.
static func total_depth(card: CardData) -> int:
	var sum := 0
	for boss_name in all(card):
		sum += int(all(card)[boss_name])
	return sum


# The multiplier this card's attack and defense get against `boss_name`.
static func bonus_against(card: CardData, boss_name: String) -> float:
	return 1.0 + BONUS_PER_DEPTH * float(depth(card, boss_name))


# The multiplier its attack gets against everything else. Never below
# MIN_ATTACK_FRACTION however many grudges it holds.
static func general_penalty(card: CardData) -> float:
	var loss := PENALTY_PER_DEPTH * float(total_depth(card))
	return maxf(1.0 - loss, MIN_ATTACK_FRACTION)


# --- Forming ------------------------------------------------------------

# Returns true if a grudge was taken or deepened, so the caller can say so.
static func take(card: CardData, boss_name: String) -> bool:
	if card == null or boss_name == "":
		return false

	var held := all(card)
	var now := int(held.get(boss_name, 0))
	if now >= MAX_DEPTH:
		return false

	held[boss_name] = now + 1
	Ledger.of(card)[KEY] = held
	return true


# --- Applying -----------------------------------------------------------

# A copy of the card with its grudges folded in, for one specific fight.
# Mirrors EquipmentSystem.apply_to() deliberately - same shape, same
# contract, so the battle team is built by one readable chain of
# "give me this card as it is for THIS fight".
#
# `against` is the name of the boss on the other side, or "" for a fight
# with nobody in particular in it. Note that a card with grudges is worse
# in an ordinary fight even though nothing on the other side did anything
# to it - that cost is what makes the bonus mean something.
static func apply_to(card: CardData, against: String = "") -> CardData:
	if card == null or not has_any(card):
		return card

	var sharpened: CardData = card.duplicate()
	var focus := bonus_against(card, against)

	if focus > 1.0:
		sharpened.attack = int(round(float(card.attack) * focus))
		sharpened.defense = int(round(float(card.defense) * focus))
	else:
		sharpened.attack = maxi(1, int(round(float(card.attack) * general_penalty(card))))

	# The record travels with the copy, so anything downstream that asks
	# the combatant about its grudges gets the truth.
	sharpened.ledger = card.ledger
	return sharpened


# --- Wording ------------------------------------------------------------

# Depth as a word rather than a number. "Bears a deep grudge against the
# Cinder Tyrant" is a thing a player repeats; "grudge depth: 4" is not.
const WEIGHT: Array[String] = ["", "a grudge", "a bitter grudge", "a deep grudge",
	"an old grudge", "an unforgiving grudge"]


static func weight_of(level: int) -> String:
	return WEIGHT[clampi(level, 0, WEIGHT.size() - 1)]


# One line per grudge, for the card's detail panel.
static func lines(card: CardData) -> Array[String]:
	var out: Array[String] = []
	for boss_name in all(card):
		var level := int(all(card)[boss_name])
		out.append("%s against %s — %+d%% there, %+d%% everywhere else" % [
			weight_of(level).capitalize(), boss_name,
			int(round(BONUS_PER_DEPTH * float(level) * 100.0)),
			int(round((general_penalty(card) - 1.0) * 100.0))])
	out.sort()
	return out
