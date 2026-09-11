extends Node

# =========================================================
# CAR PHYSICS ACCEPTANCE TESTS.
#
#   godot --headless --path . tools/CarTests.tscn
#
# Real physics, stepped for real, on a real floor - headless only skips
# the drawing. Every case drives the car through CarInput exactly as a
# player or an agent would, waits a fixed number of physics frames, and
# then asserts on what actually happened to the body.
#
# What this CANNOT tell you is whether the car feels good. That is the
# part that needs a human. What it can tell you is that the car reaches
# the speed it should, stops when asked, turns at the rate it should,
# leaves the ground when it jumps and - the one that kept coming back -
# does not sink into the floor.
#
# Exits non-zero if any case fails, so it works as a pre-commit gate.
# =========================================================

const FLOOR_SIZE := 4000.0
const FLOOR_DEPTH := 24.0
const SETTLE_FRAMES := 90

# The extra geometry Phase 4 needs: a slope, a wall and a ceiling, each
# far enough from the others that a test cannot accidentally touch two.
const SLOPE_AT := 600.0
const SLOPE_DEGREES := 25.0
const WALL_AT := 1200.0
const WALL_THICKNESS := 20.0
const CEILING_AT := 60.0
const CEILING_Z := -1200.0

var _car: CarBody
var _cases: Array[Dictionary] = []
var _index := -1
var _frames := 0
var _passes := 0
# The slowest the car got during a case, for the tests that are about
# something happening DURING the run rather than at the end of it.
var _slowest := INF
var _roof_from := Vector3.UP
var _failures: Array[String] = []
var _running := false


func _ready() -> void:
	_build_floor()

	_car = CarBody.create()
	add_child(_car)
	_car.take_control()
	_reset()

	_cases = [
		{
			"name": "rests one ride height above the floor",
			"frames": SETTLE_FRAMES,
			"drive": func(_i: CarInput): pass,
			"check": func() -> String:
				var y := _car.global_position.y
				var want := CarBody.RIDE_HEIGHT
				# The springs sag a little under the car's weight, which
				# is correct - they only push once compressed.
				if y < want * 0.75:
					return "sat at %.2f m, expected about %.2f m" % [y, want]
				if y > want * 1.35:
					return "floated at %.2f m, expected about %.2f m" % [y, want]
				return "",
		},
		{
			"name": "does not sink through the floor when left alone",
			"frames": 600,
			"drive": func(_i: CarInput): pass,
			"check": func() -> String:
				if _car.global_position.y < 0.0:
					return "fell to %.2f m - it is under the floor" % _car.global_position.y
				if not _car.is_grounded():
					return "lost the ground entirely"
				return "",
		},
		{
			"name": "does not sink after ten seconds of driving",
			"frames": 600,
			"drive": func(i: CarInput): i.throttle = 1.0,
			"check": func() -> String:
				if _car.global_position.y < 0.0:
					return "melted to %.2f m" % _car.global_position.y
				if not _car.is_grounded():
					return "left the ground without being asked to"
				return "",
		},
		{
			"name": "reaches the no-boost ceiling on throttle alone",
			"frames": 420,
			"drive": func(i: CarInput): i.throttle = 1.0,
			"check": func() -> String:
				var top := _car.max_speed_no_boost()
				var got := _car.speed()
				if got < top * 0.9:
					return "only got to %.1f m/s of %.1f" % [got, top]
				if got > top * 1.05:
					return "overshot to %.1f m/s, ceiling is %.1f" % [got, top]
				return "",
		},
		{
			"name": "boost goes past the no-boost ceiling, not past the real one",
			"frames": 420,
			"drive": func(i: CarInput):
				i.throttle = 1.0
				i.boost_held = true,
			"check": func() -> String:
				var got := _car.speed()
				if got <= _car.max_speed_no_boost() * 1.02:
					return "boost added nothing: %.1f m/s" % got
				if got > _car.max_speed() * 1.05:
					return "exceeded top speed: %.1f of %.1f" % [got, _car.max_speed()]
				return "",
		},
		{
			# Watched every frame, not checked at the end: braking from
			# 30 m/s at RL's 3500 uu/s^2 takes about a tenth of a second,
			# and then full reverse throttle takes over and the car
			# drives away backwards. Sampling only the last frame said
			# "still doing 112 m/s" of a car that had stopped perfectly
			# well four seconds earlier.
			"name": "brakes to a stop from speed",
			"frames": 120,
			"before": func(): _launch(30.0),
			"drive": func(i: CarInput): i.throttle = -1.0,
			"watch": func():
				var forward := -_car.global_transform.basis.z
				_slowest = minf(_slowest, absf(_car.linear_velocity.dot(forward))),
			"check": func() -> String:
				# The tolerance is one physics tick of braking, derived
				# rather than guessed: at 3500 uu/s^2 a 60 Hz step changes
				# the car's speed by about 4.7 m/s, so it can pass
				# straight through zero without ever being sampled there.
				# A fixed 1.0 m/s threshold was tighter than the
				# simulation can resolve and failed a car that stopped.
				var step := _car.brake_strength_uu * CarBody.UU / float(Engine.physics_ticks_per_second)
				if _slowest > step:
					return "never got below %.1f m/s along its nose (one tick is %.1f)" % [_slowest, step]
				return "",
		},
		{
			"name": "reverses",
			"frames": 240,
			"drive": func(i: CarInput): i.throttle = -1.0,
			"check": func() -> String:
				var forward := -_car.global_transform.basis.z
				var along := _car.linear_velocity.dot(forward)
				if along > -1.0:
					return "went %.2f m/s along its nose, expected negative" % along
				return "",
		},
		{
			"name": "steers left at about the configured yaw rate",
			"frames": 180,
			"before": func(): _launch(20.0),
			"drive": func(i: CarInput):
				i.throttle = 1.0
				i.steer = 1.0,
			"check": func() -> String:
				var yaw := _car.angular_velocity.y
				if yaw < 0.2:
					return "barely turned: %.2f rad/s" % yaw
				if yaw > _car.steering_yaw_rate * 1.5:
					return "spun at %.2f rad/s, limit is %.2f" % [yaw, _car.steering_yaw_rate]
				return "",
		},
		{
			"name": "stays upright while cornering hard",
			"frames": 300,
			"before": func(): _launch(25.0),
			"drive": func(i: CarInput):
				i.throttle = 1.0
				i.steer = 1.0,
			"check": func() -> String:
				var up := _car.global_transform.basis.y.dot(Vector3.UP)
				if up < 0.85:
					return "tipped over: roof is %.2f off vertical" % up
				return "",
		},
		{
			"name": "jumps, and comes back down",
			"frames": 6,
			"drive": func(i: CarInput):
				i.jump_held = true
				i.jump_pressed = _frames == 0,
			"check": func() -> String:
				if _car.global_position.y <= CarBody.RIDE_HEIGHT * 1.2:
					return "never left the ground: %.2f m" % _car.global_position.y
				return "",
		},
		{
			"name": "lands stable after the jump",
			"frames": 240,
			"drive": func(_i: CarInput): pass,
			"check": func() -> String:
				if not _car.is_grounded():
					return "never landed"
				if _car.global_transform.basis.y.dot(Vector3.UP) < 0.9:
					return "landed on its side"
				return "",
		},
		{
			# Directly exercises the path that used to be a one-way trap,
			# and that the ceiling fix just rewrote: put the car UNDER
			# the floor on purpose and check it gets itself out.
			"name": "digs itself out when placed under the floor",
			"frames": 120,
			"before": func():
				_car.global_transform = Transform3D(
					Basis.IDENTITY, Vector3(0.0, -FLOOR_DEPTH * 0.5, 0.0))
				_car.linear_velocity = Vector3.ZERO,
			"check": func() -> String:
				if _car.global_position.y < 0.0:
					return "still at %.2f m, under the floor" % _car.global_position.y
				if not _car.is_grounded():
					return "got out but is not on anything"
				return "",
		},
		{
			"name": "all four wheels report flat floor, none reset-eligible",
			"frames": SETTLE_FRAMES,
			"drive": func(_i: CarInput): pass,
			"check": func() -> String:
				if _car.touching_wheels() != 4:
					return "only %d wheels touching" % _car.touching_wheels()
				if _car.grounded_wheels() != 4:
					return "only %d wheels drivable" % _car.grounded_wheels()
				if _car.surface_kind() != WheelContact.Kind.FLOOR:
					return "called flat ground '%s' (%s)" % [
						WheelContact.KIND_NAMES[_car.surface_kind()], _kinds()]
				if _car.reset_eligible_wheels() != 0:
					return "ordinary floor granted %d reset contacts" % _car.reset_eligible_wheels()
				return "",
		},
		{
			"name": "springs are loaded but not bottomed out at rest",
			"frames": SETTLE_FRAMES,
			"drive": func(_i: CarInput): pass,
			"check": func() -> String:
				for wheel in _car.wheels:
					if wheel.compression <= 0.0:
						return "wheel %d carries no load" % wheel.index
					if wheel.compression >= 0.999:
						return "wheel %d is fully bottomed out" % wheel.index
				return "",
		},
		{
			"name": "a 25 degree slope is a slope, and still drives",
			"frames": SETTLE_FRAMES,
			"before": func():
				_car.global_transform = Transform3D(
					Basis(Vector3.BACK, deg_to_rad(SLOPE_DEGREES)),
					Vector3(SLOPE_AT, CarBody.RIDE_HEIGHT * 2.0, 0.0))
				_car.linear_velocity = Vector3.ZERO,
			"check": func() -> String:
				if _car.grounded_wheels() < 3:
					return "only %d wheels hold the slope (%s)" % [_car.grounded_wheels(), _kinds()]
				if _car.surface_kind() != WheelContact.Kind.SLOPE:
					return "called a %.0f degree slope '%s'" % [
						SLOPE_DEGREES, WheelContact.KIND_NAMES[_car.surface_kind()]]
				return "",
		},
		{
			"name": "a wall will not hold a slow car",
			"frames": 2,
			"before": func(): _stand_on(
				Vector3(WALL_AT, 100.0, 0.0), Vector3.LEFT, Vector3.FORWARD, 0.0),
			"check": func() -> String:
				if _car.touching_wheels() == 0:
					return "the wheels never reached the wall"
				if _car.grounded_wheels() > 0:
					return "%d wheels gripped a wall at a standstill" % _car.grounded_wheels()
				return "",
		},
		{
			"name": "a wall holds a fast car",
			"frames": 2,
			"before": func(): _stand_on(
				Vector3(WALL_AT, 100.0, 0.0), Vector3.LEFT, Vector3.FORWARD, 60.0),
			"check": func() -> String:
				if _car.grounded_wheels() < 3:
					return "only %d wheels held the wall (%s)" % [_car.grounded_wheels(), _kinds()]
				if _car.surface_kind() != WheelContact.Kind.WALL:
					return "called a wall '%s'" % WheelContact.KIND_NAMES[_car.surface_kind()]
				return "",
		},
		{
			"name": "a wall grants reset contacts, unlike the floor",
			"frames": 2,
			"before": func(): _stand_on(
				Vector3(WALL_AT, 100.0, 0.0), Vector3.LEFT, Vector3.FORWARD, 60.0),
			"check": func() -> String:
				var eligible := _car.reset_eligible_wheels()
				if eligible < _car.minimum_reset_wheels:
					return "only %d reset-eligible wheels, need %d" % [
						eligible, _car.minimum_reset_wheels]
				return "",
		},
		{
			"name": "a ceiling is a ceiling, and holds a fast car",
			"frames": 2,
			"before": func(): _stand_on(
				Vector3(0.0, CEILING_AT, CEILING_Z), Vector3.DOWN, Vector3.FORWARD, 60.0),
			"check": func() -> String:
				if _car.grounded_wheels() < 3:
					return "only %d wheels held the ceiling (%s)" % [_car.grounded_wheels(), _kinds()]
				if _car.surface_kind() != WheelContact.Kind.CEILING:
					return "called a ceiling '%s'" % WheelContact.KIND_NAMES[_car.surface_kind()]
				return "",
		},
		{
			# Measured as the SIGN OF THE SPIN AXIS, not as a snapshot of
			# where the roof ended up. The car rolls continuously, so
			# after about half a turn the roof passes back through level
			# and a snapshot reads zero - which is what the first version
			# of this test did, and it failed a car that was rolling
			# perfectly well.
			#
			# A positive angular velocity about the car's own FORWARD
			# axis tilts its roof toward its own +X, which is right.
			"name": "air roll right rolls the car RIGHT",
			"frames": 30,
			"before": func():
				_car.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 400.0, 0.0))
				_car.linear_velocity = Vector3.ZERO
				_car.angular_velocity = Vector3.ZERO,
			# What read_player() produces for a held air-roll-right,
			# including the sign flip that was missing.
			"drive": func(i: CarInput): i.roll = -1.0,
			"check": func() -> String:
				var forward := -_car.global_transform.basis.z
				var about := _car.angular_velocity.dot(forward)
				if absf(about) < 1.0:
					return "barely rolling (%.2f rad/s)" % about
				if about < 0.0:
					return "rolling LEFT when asked for right (%.2f rad/s)" % about
				return "",
		},
		{
			"name": "air roll left rolls the car LEFT",
			"frames": 30,
			"before": func():
				_car.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 400.0, 0.0))
				_car.linear_velocity = Vector3.ZERO
				_car.angular_velocity = Vector3.ZERO,
			"drive": func(i: CarInput): i.roll = 1.0,
			"check": func() -> String:
				var forward := -_car.global_transform.basis.z
				var about := _car.angular_velocity.dot(forward)
				if absf(about) < 1.0:
					return "barely rolling (%.2f rad/s)" % about
				if about > 0.0:
					return "rolling RIGHT when asked for left (%.2f rad/s)" % about
				return "",
		},
		{
			# The other half of the same guarantee: the BUTTON named
			# "air roll right" has to survive Controls -> CarInput -> the
			# physics with its sign intact. air_roll() answers +1 for the
			# right button; the struct is positive-left; so the two must
			# disagree in sign, and if anyone ever "tidies" that away
			# both buttons invert again.
			"name": "the air-roll-right button maps to a rightward roll",
			"frames": 1,
			"check": func() -> String:
				var from_button := 1.0        # Controls.air_roll(), right held
				var into_struct := -from_button
				if into_struct >= 0.0:
					return "the sign flip between Controls and CarInput is gone"
				return "",
		},
		{
			"name": "an agent drives through the same physics as a player",
			"frames": 420,
			"agent": true,
			"check": func() -> String:
				var top := _car.max_speed_no_boost()
				if _car.speed() < top * 0.9:
					return "agent only reached %.1f m/s of %.1f" % [_car.speed(), top]
				return "",
		},
	]

	_running = true
	_next()


# --- The rig ----------------------------------------------------------

func _build_floor() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	_slab(body, Vector3(0.0, -FLOOR_DEPTH * 0.5, 0.0),
		Vector3(FLOOR_SIZE, FLOOR_DEPTH, FLOOR_SIZE), Basis.IDENTITY)

	# A slope to drive up. Tilted about Z, so its normal leans in X.
	_slab(body, Vector3(SLOPE_AT, 0.0, 0.0), Vector3(300.0, FLOOR_DEPTH, 300.0),
		Basis(Vector3.BACK, deg_to_rad(SLOPE_DEGREES)))

	# A wall, standing clear of everything else. The car drives on its
	# -X face, which is at WALL_AT.
	_slab(body, Vector3(WALL_AT + WALL_THICKNESS * 0.5, 200.0, 0.0),
		Vector3(WALL_THICKNESS, 400.0, 800.0), Basis.IDENTITY)

	# A ceiling, with its underside at CEILING_AT.
	_slab(body, Vector3(0.0, CEILING_AT + FLOOR_DEPTH * 0.5, CEILING_Z),
		Vector3(800.0, FLOOR_DEPTH, 800.0), Basis.IDENTITY)


func _slab(body: StaticBody3D, at: Vector3, size: Vector3, turn: Basis) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = Transform3D(turn, at)
	body.add_child(shape)


# Puts the car on a surface: `up` is the surface normal, `facing` the way
# the nose should point along it. Used to test walls and ceilings, where
# the car's own up is nothing like the world's.
func _stand_on(contact: Vector3, up: Vector3, facing: Vector3, along: float) -> void:
	var y := up.normalized()
	var z := -facing.normalized()
	var x := y.cross(z).normalized()
	z = x.cross(y).normalized()

	_car.global_transform = Transform3D(Basis(x, y, z), contact + y * CarBody.RIDE_HEIGHT)
	_car.linear_velocity = -z * along
	_car.angular_velocity = Vector3.ZERO


func _kinds() -> String:
	var out: Array[String] = []
	for wheel in _car.wheels:
		out.append(wheel.kind_name())
	return ", ".join(out)


func _reset() -> void:
	_car.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, CarBody.RIDE_HEIGHT, 0.0))
	_car.linear_velocity = Vector3.ZERO
	_car.angular_velocity = Vector3.ZERO
	_car.boost = CarBody.BOOST_MAX
	_car.ai_driven = false
	_car.input.clear()


# Starts the case already moving, for the ones that are about what
# happens at speed rather than about getting there.
func _launch(metres_per_second: float) -> void:
	_car.linear_velocity = -_car.global_transform.basis.z * metres_per_second


func _next() -> void:
	_index += 1
	_frames = 0

	if _index >= _cases.size():
		_report()
		return

	_slowest = INF

	var case: Dictionary = _cases[_index]
	# The jump cases run on from the one before rather than resetting, so
	# "lands stable" is testing the landing from the jump above it.
	if not case.has("continues"):
		_reset()
	if case.has("before"):
		(case["before"] as Callable).call()


func _physics_process(_delta: float) -> void:
	if not _running or _index >= _cases.size():
		return

	var case: Dictionary = _cases[_index]

	if case.get("agent", false):
		# Through the agent interface, which fills the same struct.
		_car.drive_inputs(1.0, 0.0, false, false, false)
	elif case.has("drive"):
		_car.ai_driven = true      # stops read_player() overwriting us
		_car.input.clear()
		(case["drive"] as Callable).call(_car.input)

	if case.has("watch"):
		(case["watch"] as Callable).call()

	_frames += 1
	if _frames < _ticks(int(case["frames"])):
		return

	var problem := str((case["check"] as Callable).call())
	if problem == "":
		_passes += 1
		print("  PASS  ", case["name"])
	else:
		_failures.append("%s: %s" % [case["name"], problem])
		print("  FAIL  ", case["name"], " -- ", problem)

	_next()


# Case durations are written as frames AT 60 Hz and scaled to whatever
# the project actually runs at. The project moved to 120 Hz, which would
# otherwise have silently halved every test's wall-clock duration - the
# "reaches top speed in 7 seconds" case would have been given 3.5.
func _ticks(frames_at_60: int) -> int:
	return maxi(1, int(round(float(frames_at_60) * float(Engine.physics_ticks_per_second) / 60.0)))


func _report() -> void:
	_running = false
	print("")
	print("=== %d passed, %d failed ===" % [_passes, _failures.size()])
	for line in _failures:
		print("  ", line)
	get_tree().quit(1 if _failures.size() > 0 else 0)
