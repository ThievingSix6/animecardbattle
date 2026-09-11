class_name Passenger
extends RefCounted

# =========================================================
# ONE CARD RIDES IN THE CAR.
#
# The bridge between the two halves of this game, and the whole point of
# its shape: MOMENTUM IS THE ONE THING THE AUTOBATTLER CANNOT PRODUCE.
# No amount of gold, gems, levels, floors or summons makes any. The only
# way a card gets it is to have been in the car while someone drove.
#
# That is deliberately the opposite of a daily quest. Nothing tells you
# to go and play the arena; the arena is just where a particular kind of
# experience exists, and cards that have been there are visibly different
# from cards that have not.
#
# NOTHING CONSUMES IT YET. Same discipline as the Ledger, for the same
# reason: a card's mileage is only worth anything if it started
# accumulating before the first thing that reads it existed. Every hour
# this ships early is an hour of road on everyone's favourite card.
#
# AND IT IS NOT A STAT. It will never be one. The moment carrying a
# passenger makes a card hit harder, the arcade mode stops being optional
# and becomes homework - which is exactly what this game is trying not to
# be. What Momentum buys is a mark on the card and, later, access to
# things that cannot be bought at all.
#
# WHY IT CAPS. A card that is full stops gaining, so you cannot leave one
# card in the seat forever and farm it. Filling one means choosing
# another, which is the decision the mechanic exists to create. You bring
# one card. You pick which.
# =========================================================

# Metres before a card is full. About one arena match of hard driving, or
# a couple of clean rings runs - enough to be a commitment, short enough
# that it is not a second job.
const FULL := 25000.0

# Below this the car is idling, parked, or being nudged around, and none
# of that is a journey. Without it you could hold the throttle against a
# wall and fill a card.
const MIN_SPEED := 12.0

# Notable things are worth more than the distance they cover. A goal is a
# few hundred metres of driving; it should feel like more than that.
const GOAL_BONUS := 900.0
const RING_BONUS := 220.0
const COURSE_BONUS := 4000.0


# --- Who is riding ------------------------------------------------------

static func card() -> CardData:
	if not GameState.has_active_slot():
		return null
	var id := GameState.collection.passenger_id
	if id == "":
		return null
	return GameState.collection.owned.get(id)


static func seat(card_id: String) -> void:
	if not GameState.has_active_slot():
		return
	GameState.collection.passenger_id = card_id
	GameState.request_save()


static func clear_seat() -> void:
	seat("")


static func is_seated(card_id: String) -> bool:
	return GameState.has_active_slot() and GameState.collection.passenger_id == card_id


# --- Momentum -----------------------------------------------------------

static func carried(who: CardData) -> float:
	if who == null:
		return 0.0
	return Ledger.momentum(who)


static func fraction(who: CardData) -> float:
	return clampf(carried(who) / FULL, 0.0, 1.0)


static func is_full(who: CardData) -> bool:
	return carried(who) >= FULL


# Everything that adds Momentum comes through here, so the cap is in one
# place and cannot be routed around.
static func add(metres: float) -> void:
	var who := card()
	if who == null or metres <= 0.0:
		return

	var room := FULL - carried(who)
	if room <= 0.0:
		return

	var before := is_full(who)
	Ledger.add_momentum(who, minf(metres, room))

	if not before and is_full(who):
		EventBus.toast("%s has ridden the full distance." % who.card_name, "success")
		GameState.request_save()


# Distance covered this frame, ignored entirely below walking pace.
static func travelled(speed: float, delta: float) -> void:
	if speed < MIN_SPEED:
		return
	add(speed * delta)


# --- The look of it -----------------------------------------------------

# The passenger's mutation colour, for the boost trail and the goal
# explosion. This is the whole of the immediate payoff and it is
# deliberately cosmetic: a Void card in the seat makes the car burn
# Void-coloured, and a Celestial one is unmistakable from across the
# pitch.
static func tint() -> Color:
	var who := card()
	if who == null:
		return Color(0.75, 0.55, 1.0)
	return Mutations.color(who.modifier)


static func has_tint() -> bool:
	return card() != null


# --- Wording ------------------------------------------------------------

static func distance_text(metres: float) -> String:
	if metres >= 1000.0:
		return "%.1f km" % (metres / 1000.0)
	return "%d m" % int(metres)


static func summary(who: CardData) -> String:
	if who == null:
		return "No passenger. The seat is empty."
	if is_full(who):
		return "%s has ridden the full %s. Seat someone else." % [
			who.card_name, distance_text(FULL)]
	return "%s — %s of %s" % [
		who.card_name, distance_text(carried(who)), distance_text(FULL)]
