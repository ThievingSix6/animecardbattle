class_name WheelContact
extends RefCounted

# =========================================================
# WHAT ONE WHEEL IS TOUCHING.
#
# The car used to collapse all four raycasts into a single `_grounded`
# bool and one averaged normal, which threw away everything interesting:
# which corner is down, how hard each spring is loaded, what KIND of
# surface each wheel is on. Flip resets are built on exactly that
# information, so it is kept per wheel now.
#
# SURFACES ARE NOT ALL GROUND. A raycast hit used to mean "grounded",
# full stop, so a car brushing a wall at walking pace got the same
# traction it gets on the road. Each contact is classified:
#
#   FLOOR     within floor_max_angle of world up. Always drivable.
#   SLOPE     a floor, steep enough to be worth naming separately.
#   WALL      roughly vertical. Drivable only ABOVE a speed, which is
#             what makes a wall something you can drive up but not park
#             on, the way Rocket League does it.
#   CEILING   pointing down. Same speed rule.
#
# Nothing here applies force or decides anything. It is a measurement,
# filled once per physics frame and read by the parts that do.
# =========================================================

enum Kind { NONE, FLOOR, SLOPE, WALL, CEILING }

const KIND_NAMES: Array[String] = ["none", "floor", "slope", "wall", "ceiling"]

# Which corner this is: 0 front-left, 1 front-right, 2 rear-left,
# 3 rear-right.
var index := 0

# --- Raw contact -------------------------------------------------------
var grounded := false
var position := Vector3.ZERO       # world-space contact point
var normal := Vector3.UP           # world-space surface normal
var collider: Object = null
var distance := 0.0                # from the ray's start to the contact
# The ray BEGAN inside the collider - the wheel is under the surface
# rather than resting on it. Godot reports no usable normal in that case,
# which is how it is detected, and it is the one unambiguous sign that
# the car has gone through the world.
var inside_surface := false

# --- Suspension --------------------------------------------------------
# 0 fully extended, 1 fully compressed.
var compression := 0.0
# The car's own velocity at the contact point, and the part of it along
# the car's up - which is what the damper resists.
var point_velocity := Vector3.ZERO
var closing_speed := 0.0
# The velocity of the SURFACE at that point. Zero for the arena; not
# zero for the ball, which is the whole reason a flip reset off a moving
# ball has to be measured rather than assumed.
var surface_velocity := Vector3.ZERO

# --- Classification ----------------------------------------------------
var surface_angle := 0.0           # radians between the normal and world up
var kind := Kind.NONE
# Can the car drive on this - steer, accelerate, be held up by its
# spring? A wall below the stick speed is touched but not drivable.
var drivable := false
# Can this contact grant a flip reset? Ordinary floor never does.
var reset_eligible := false


func clear() -> void:
	grounded = false
	position = Vector3.ZERO
	normal = Vector3.UP
	collider = null
	distance = 0.0
	inside_surface = false
	compression = 0.0
	point_velocity = Vector3.ZERO
	closing_speed = 0.0
	surface_velocity = Vector3.ZERO
	surface_angle = 0.0
	kind = Kind.NONE
	drivable = false
	reset_eligible = false


func kind_name() -> String:
	return KIND_NAMES[kind]


# Sorts one contact into a kind from its normal alone.
static func classify(surface_normal: Vector3, floor_max: float, ceiling_min: float,
		slope_min: float) -> int:
	var angle := surface_normal.angle_to(Vector3.UP)
	if angle <= slope_min:
		return Kind.FLOOR
	if angle <= floor_max:
		return Kind.SLOPE
	if angle >= ceiling_min:
		return Kind.CEILING
	return Kind.WALL


# A one-line summary for the debug overlay.
func describe() -> String:
	if not grounded:
		return "%d: air" % index
	return "%d: %s %.0f deg  c=%.2f%s" % [
		index, kind_name(), rad_to_deg(surface_angle), compression,
		"  RESET" if reset_eligible else ""]
