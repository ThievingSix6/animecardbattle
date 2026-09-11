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

var _car: CarBody
var _cases: Array[Dictionary] = []
var _index := -1
var _frames := 0
var _passes := 0
# The slowest the car got during a case, for the tests that are about
# something happening DURING the run rather than at the end of it.
var _slowest := INF
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
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FLOOR_SIZE, FLOOR_DEPTH, FLOOR_SIZE)
	shape.shape = box
	shape.position.y = -FLOOR_DEPTH * 0.5
	body.add_child(shape)


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
	if _frames < int(case["frames"]):
		return

	var problem := str((case["check"] as Callable).call())
	if problem == "":
		_passes += 1
		print("  PASS  ", case["name"])
	else:
		_failures.append("%s: %s" % [case["name"], problem])
		print("  FAIL  ", case["name"], " -- ", problem)

	_next()


func _report() -> void:
	_running = false
	print("")
	print("=== %d passed, %d failed ===" % [_passes, _failures.size()])
	for line in _failures:
		print("  ", line)
	get_tree().quit(1 if _failures.size() > 0 else 0)
