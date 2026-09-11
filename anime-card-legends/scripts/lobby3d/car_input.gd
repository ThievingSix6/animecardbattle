class_name CarInput
extends RefCounted

# =========================================================
# WHAT THE CAR IS BEING TOLD TO DO - and nothing about who is telling it.
#
# The physics used to read Input.is_action_pressed() from inside
# _handle_jump(), which meant the car could only ever be driven by a
# person at a keyboard. Everything the car reacts to is in this struct
# now, filled either from the InputMap or by an agent, and the physics
# cannot tell the difference.
#
# SIGNS. Every axis runs -1 to 1 and follows Godot's own right-handed,
# Y-up convention, which is that a POSITIVE rotation about an axis is
# counter-clockwise looking down it:
#
#   steer   positive is LEFT      (positive yaw about +Y)
#   yaw     positive is LEFT
#   pitch   positive is NOSE UP   (the car's own +X runs right, so this
#                                  is negated where the torque is applied)
#   roll    positive is LEFT      (the roof tilts left)
#
# All three turning axes are positive-left, which is the one thing that
# keeps them consistent. Working it out for roll: the torque is applied
# about the car's +Z, and +Z points BACKWARDS, so a positive rotation
# takes the roof (+Y) toward -X, which is the car's left.
#
# Left-positive steering looks wrong written down and is right in the
# maths. It is the same sign the bot already computes from a cross
# product, so changing it would silently invert the AI.
#
# THE ACTION NAMES. The brief for this mode asks for car_throttle,
# car_steer and so on. They are not registered as separate actions,
# because that would leave two InputMaps fighting over the same physical
# buttons and the rebinding screen only knows about one of them. The
# mapping is here instead, in one place:
#
#   car_throttle   acl_throttle / acl_brake (analogue on the triggers)
#   car_brake      acl_brake
#   car_steer      acl_left / acl_right
#   car_jump       acl_jump
#   car_boost      acl_boost
#   car_handbrake  acl_drift
#   car_pitch      acl_back / acl_forward
#   car_yaw        acl_left / acl_right
#   car_roll       acl_air_roll_left / acl_air_roll_right
# =========================================================

# Ground.
var throttle := 0.0          # -1 reverse, 1 forward
var steer := 0.0             # -1 right, 1 left
var handbrake_held := false  # powerslide

# Air. The stick does pitch and yaw; roll needs its own button because a
# stick that rolled as well would have nothing left to aim with.
var pitch := 0.0
var yaw := 0.0
var roll := 0.0

# Shared.
var jump_held := false
var jump_pressed := false    # this frame only
var boost_held := false

# Where the flip goes when jump is pressed a second time. Kept apart
# from steer/throttle because a flip reads the stick at one instant
# rather than continuously.
var flip_forward := 0.0
var flip_side := 0.0


func clear() -> void:
	throttle = 0.0
	steer = 0.0
	handbrake_held = false
	pitch = 0.0
	yaw = 0.0
	roll = 0.0
	jump_held = false
	jump_pressed = false
	boost_held = false
	flip_forward = 0.0
	flip_side = 0.0


# Fills from the InputMap. `was_jump_held` is last frame's jump state,
# which is what turns a held button into a single press - the physics
# owns that history, not this struct.
func read_player(was_jump_held: bool) -> void:
	throttle = Controls.throttle()
	steer = Input.get_axis("acl_right", "acl_left")
	handbrake_held = Input.is_action_pressed("acl_drift")
	boost_held = Input.is_action_pressed("acl_boost")

	pitch = Input.get_axis("acl_back", "acl_forward")
	yaw = steer
	# NEGATED. Controls.air_roll() answers the question the BUTTONS ask -
	# "+1 means the player pressed air roll right" - and this struct
	# answers the question the physics asks, where every turning axis is
	# positive-left. Without the sign flip both buttons rolled the car
	# the opposite way to their name.
	roll = -Controls.air_roll()

	jump_held = Input.is_action_pressed("acl_jump")
	jump_pressed = jump_held and not was_jump_held

	flip_forward = pitch
	flip_side = steer


# An agent's turn. Same struct, same physics, no privileged access - a
# bot that wants to flip has to press jump twice like anyone else.
func drive(new_throttle: float, new_steer: float, boosting: bool,
		handbrake: bool, jumping: bool, was_jump_held: bool) -> void:
	throttle = clampf(new_throttle, -1.0, 1.0)
	steer = clampf(new_steer, -1.0, 1.0)
	boost_held = boosting
	handbrake_held = handbrake

	jump_held = jumping
	jump_pressed = jumping and not was_jump_held

	pitch = 0.0
	yaw = steer
	roll = 0.0
	flip_forward = 0.0
	flip_side = 0.0


# True when the stick is far enough from centre to mean a DIRECTION
# rather than a straight second jump.
func flip_aimed(deadzone: float) -> bool:
	return absf(flip_forward) >= deadzone or absf(flip_side) >= deadzone
