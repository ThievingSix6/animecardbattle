class_name Outnumbered
extends RefCounted

# =========================================================
# BRINGING FEWER CARDS ON PURPOSE.
#
# A battle here is a RELAY: one card is active per side and the next one
# steps up when it falls. So a five-card team is not five attackers - it
# is five lives. Bringing three is not a weaker team, it is a shorter
# bench, and that is a completely different kind of decision.
#
# It already worked, mechanically. set_team() never enforced a minimum
# and the sim never cared. What was missing is that it was indis-
# tinguishable from having forgotten to fill your team in: no
# compensation, no acknowledgement, nothing to tell a player that three
# cards was a CHOICE rather than an oversight.
#
# Outnumbered is that acknowledgement. Every empty slot makes the cards
# you did bring harder to kill.
#
# WHY HEALTH SCALES HARDEST. The thing a small team actually lacks is
# lives, not damage - only one card swings at a time either way. So the
# compensation is weighted toward surviving the relay rather than winning
# it faster, and a solo run is a question about whether one card can
# outlast five rather than whether it can out-damage them.
#
# AND WHY IT IS NOT FREE. A solo card at four empty slots has roughly
# half the effective health of a full bench, bought back through defense.
# It is close to break-even on paper and wildly different to play, which
# is what a build is supposed to be. One bad matchup and there is nobody
# behind it.
#
# This is the only axis in the game where having LESS is the
# optimisation. Everything else - levels, stars, equipment, mutations -
# is addition.
# =========================================================

# The lineup a full team fills.
const FULL_TEAM := 5

# Per empty slot. Health hardest, then defense, then attack: see above.
#
# THESE WERE MEASURED, NOT GUESSED, and the first guess was wrong by
# about double. tools/OutnumberedTests.tscn binary-searches the weakest
# cards each lineup size can still win floor 4 with, which prices the
# trade directly. With no bonus at all:
#
#   Full 1.00x   Four 1.06x   Trio 1.21x   Duo 1.41x   Alone 1.68x
#
# - a short bench costs more, exactly as it should, because what it
# lacks is lives. The first pass at these numbers (0.22 / 0.26 / 0.34)
# over-corrected hard and inverted it:
#
#   Full 1.00x   Four 0.82x   Trio 0.76x   Duo 0.75x   Alone 0.86x
#
# - every short lineup strictly better than a full one, which is not a
# build, it is the only correct answer. Roughly halved to land near even
# with a modest premium at the extreme, which is what a choice looks
# like.
const ATTACK_PER_SLOT := 0.10
const DEFENSE_PER_SLOT := 0.12
const HEALTH_PER_SLOT := 0.16

# Ultimates charge at 25 energy an attack out of 100, so a card four
# slots short opens its first fight most of the way to an ultimate. That
# is the qualitative half of the trade - a solo card does not just have
# bigger numbers, it comes out swinging.
const ENERGY_PER_SLOT := 10


static func empty_slots(team_size: int) -> int:
	return clampi(FULL_TEAM - team_size, 0, FULL_TEAM - 1)


static func is_active(team_size: int) -> bool:
	return empty_slots(team_size) > 0


# --- The numbers --------------------------------------------------------

static func attack_bonus(team_size: int) -> float:
	return 1.0 + ATTACK_PER_SLOT * float(empty_slots(team_size))


static func defense_bonus(team_size: int) -> float:
	return 1.0 + DEFENSE_PER_SLOT * float(empty_slots(team_size))


static func health_bonus(team_size: int) -> float:
	return 1.0 + HEALTH_PER_SLOT * float(empty_slots(team_size))


static func starting_energy(team_size: int) -> int:
	return mini(ENERGY_PER_SLOT * empty_slots(team_size), Config.ENERGY_MAX - 1)


# --- Applying -----------------------------------------------------------

# A copy of the card as it goes into a fight with `team_size` cards
# behind it. Same shape and same contract as EquipmentSystem.apply_to()
# and Grudges.apply_to(), so the battle team is built by one readable
# chain of "give me this card as it is for THIS fight".
static func apply_to(card: CardData, team_size: int) -> CardData:
	if card == null or not is_active(team_size):
		return card

	var lone: CardData = card.duplicate()
	lone.attack = maxi(1, int(round(float(card.attack) * attack_bonus(team_size))))
	lone.defense = maxi(0, int(round(float(card.defense) * defense_bonus(team_size))))
	lone.health = maxi(1, int(round(float(card.health) * health_bonus(team_size))))
	lone.starting_energy = starting_energy(team_size)

	# The record travels with the copy, so anything downstream that asks
	# this combatant about its history still gets the truth.
	lone.ledger = card.ledger
	return lone


# --- Wording ------------------------------------------------------------

# What a lineup of this size is called. Named sizes are what turn "I
# forgot to add cards" into "I run a duo", which is the entire point of
# the system.
const NAMES := {
	1: "Alone",
	2: "Duo",
	3: "Trio",
	4: "Four",
	5: "Full lineup",
}


static func lineup_name(team_size: int) -> String:
	return str(NAMES.get(clampi(team_size, 1, FULL_TEAM), "Full lineup"))


# The one-line summary the team screen shows under the slots.
static func summary(team_size: int) -> String:
	if not is_active(team_size):
		return "A full lineup. No Outnumbered bonus."

	return "Outnumbered ×%d — %+d%% attack, %+d%% defense, %+d%% health, and %d energy to start." % [
		empty_slots(team_size),
		int(round((attack_bonus(team_size) - 1.0) * 100.0)),
		int(round((defense_bonus(team_size) - 1.0) * 100.0)),
		int(round((health_bonus(team_size) - 1.0) * 100.0)),
		starting_energy(team_size),
	]
