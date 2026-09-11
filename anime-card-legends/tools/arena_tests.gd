extends Node

# =========================================================
# ARENA ACCEPTANCE TESTS.
#
#   godot --headless --path . tools/ArenaTests.tscn
#
# Drives the REAL Arena scene hard at the places the old box arena
# failed. It was six slabs with nothing in the corners and collision
# smaller than the stadium you could see, so driving out there dropped
# the car into the void. These cases go looking for that.
# =========================================================

var _arena: Node3D
var _car: CarBody
var _stage := 0
var _frames := 0
var _lo := INF
var _hi := -INF
var _airborne := 0
var _samples := 0
var _lowest := INF
var _lost := false
var _passes := 0
var _failures: Array[String] = []


func _ready() -> void:
	GameState.open_slot(1)
	_arena = load("res://scenes/Arena.tscn").instantiate()
	add_child(_arena)


func _physics_process(_delta: float) -> void:
	if _car == null:
		_car = _arena.get("car")
		if _car == null:
			return
		var ball: Node = _arena.get("ball")
		if ball != null:
			ball.queue_free()
		for other in _arena.get("orange_team"):
			(other as Node).queue_free()
		_begin()
		return

	# Without this the car reads the (empty) InputMap every frame and
	# throws the test's input away - which reads as "the car will not
	# move" rather than as a broken harness.
	_car.ai_driven = true
	_car.driver_seated = true
	_car.input.clear()
	_car.input.throttle = 1.0
	_car.input.boost_held = true
	_car.boost = CarBody.BOOST_MAX
	_frames += 1

	var y := _car.global_position.y
	_lowest = minf(_lowest, y)
	if y < -20.0:
		_lost = true

	if _stage == 0:
		if _car.global_position.z < -300.0:
			var back := _car.global_transform
			back.origin.z = 380.0
			back.origin.x = 200.0
			_car.global_transform = back
			return
		if _frames > 260:
			_lo = minf(_lo, y)
			_hi = maxf(_hi, y)
			_samples += 1
			if not _car.is_grounded():
				_airborne += 1
		if _frames > _ticks(900):
			var bounce := _hi - _lo
			_judge("holds the ride height flat out at %.0f m/s" % _car.speed(),
				"bounced %.3f m, %d%% airborne" % [bounce, 100 * _airborne / maxi(_samples, 1)]
					if bounce > 0.15 or _airborne > _samples / 20 else "")
			_next()
	elif _stage == 1:
		# Aimed at the side wall to see whether it climbs or clips out.
		if _frames > 220:
			print("INTO WALL  height %.1f m   surface '%s'   wheels %d   grounded %s" % [
				_car.global_position.y,
				WheelContact.KIND_NAMES[_car.surface_kind()],
				_car.grounded_wheels(), str(_car.is_grounded())])
			_next()
	elif _stage == 2:
		# Aimed diagonally into a corner, which the old box arena had
		# nothing in at all.
		if _frames > 240:
			print("INTO CORNER height %.1f m   surface '%s'   wheels %d" % [
				_car.global_position.y,
				WheelContact.KIND_NAMES[_car.surface_kind()],
				_car.grounded_wheels()])
			_next()
	else:
		_judge("never falls out of the world",
			"reached %.2f m" % _lowest if _lost else "")
		var pads: Array = _arena.get("boost_pads")
		_judge("builds the boost pads",
			"only %d pads" % pads.size() if pads.size() < 30 else "")

		print("")
		print("=== %d passed, %d failed ===" % [_passes, _failures.size()])
		for line in _failures:
			print("  ", line)
		print("lowest point reached: %.2f m" % _lowest)
		get_tree().quit(1 if _failures.size() > 0 else 0)


# Durations are written as frames at 60 Hz; the project runs at 120.
func _ticks(frames_at_60: int) -> int:
	return maxi(1, int(round(float(frames_at_60) * float(Engine.physics_ticks_per_second) / 60.0)))


func _judge(what: String, problem: String) -> void:
	if problem == "":
		_passes += 1
		print("  PASS  ", what)
	else:
		_failures.append("%s: %s" % [what, problem])
		print("  FAIL  ", what, " -- ", problem)


func _begin() -> void:
	_frames = 0
	if _stage == 0:
		_place(Vector3(200.0, CarBody.RIDE_HEIGHT, 380.0), Vector3.FORWARD)
	elif _stage == 1:
		_place(Vector3(0.0, CarBody.RIDE_HEIGHT, 0.0), Vector3.RIGHT)
	elif _stage == 2:
		_place(Vector3(0.0, CarBody.RIDE_HEIGHT, 0.0), Vector3(1.0, 0.0, 1.0).normalized())


func _place(at: Vector3, facing: Vector3) -> void:
	var z := -facing.normalized()
	var x := Vector3.UP.cross(z).normalized()
	_car.global_transform = Transform3D(Basis(x, Vector3.UP, z), at)
	_car.linear_velocity = Vector3.ZERO
	_car.angular_velocity = Vector3.ZERO


func _next() -> void:
	_stage += 1
	_begin()
