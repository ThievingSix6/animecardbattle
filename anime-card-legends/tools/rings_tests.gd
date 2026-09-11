extends Node

# =========================================================
# RINGS COURSE ACCEPTANCE TESTS.
#
#   godot --headless --path . tools/RingsTests.tscn
#
# Builds the real course and checks the things that would make it
# unplayable and are invisible from the code: that all thirty rings
# exist, that they get harder rather than just further away, that the
# gaps are flyable at the speed the car can actually reach, and that
# flying through them in order clears the course while flying through
# them out of order does not.
# =========================================================

var _world: Node3D
var _passes := 0
var _failures: Array[String] = []
var _frames := 0


func _ready() -> void:
	GameState.open_slot(1)
	_world = load("res://scenes/Rings.tscn").instantiate()
	add_child(_world)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 4:
		return

	var gates: Array = []
	for child in _world.get_children():
		if child is RingGate:
			gates.append(child)
	gates.sort_custom(func(a, b): return a.index < b.index)

	_judge("builds every ring",
		"found %d" % gates.size() if gates.size() != 30 else "")

	if gates.is_empty():
		_report()
		return

	# Rings shrink.
	var first: RingGate = gates[0]
	var last: RingGate = gates[gates.size() - 1]
	_judge("rings get tighter towards the end",
		"first %.1f m, last %.1f m" % [first.radius, last.radius]
			if last.radius >= first.radius else "")

	# Every ring is reachable: the gap to the next one is never longer
	# than the car can cross, and never so short the rings overlap.
	var worst_gap := 0.0
	var tightest := INF
	for i in gates.size() - 1:
		var gap: float = gates[i].global_position.distance_to(gates[i + 1].global_position)
		worst_gap = maxf(worst_gap, gap)
		tightest = minf(tightest, gap)
	_judge("rings are spaced to be flyable",
		"widest gap %.0f m, tightest %.0f m" % [worst_gap, tightest]
			if worst_gap > 140.0 or tightest < 12.0 else "")

	# The course climbs rather than running along the floor.
	var highest := -INF
	var lowest := INF
	for gate in gates:
		highest = maxf(highest, gate.global_position.y)
		lowest = minf(lowest, gate.global_position.y)
	_judge("the course is flown, not driven",
		"only %.0f m of height across the whole course" % (highest - lowest)
			if highest - lowest < 20.0 else "")

	# Out of order does nothing.
	var third: RingGate = gates[2]
	third._on_entered(_world.get("car"))
	_judge("a ring taken out of order does not count",
		"ring 3 cleared while ring 1 was still next" if third.is_cleared() else "")

	# In order does.
	var opening: RingGate = gates[0]
	opening.set_next(true)
	opening._on_entered(_world.get("car"))
	_judge("the next ring in sequence counts",
		"flying the first ring did nothing" if not opening.is_cleared() else "")

	# Unlimited boost.
	var car: CarBody = _world.get("car")
	car.boost = 0.0
	_world._process(0.016)
	_judge("boost never runs out",
		"tank stayed at %.0f" % car.boost if car.boost < CarBody.BOOST_MAX else "")

	# A start pad to fall back to.
	var pad_found := false
	for child in _world.get_children():
		if child is StaticBody3D:
			pad_found = true
	_judge("there is a start pad", "" if pad_found else "no solid pad in the scene")

	_report()


func _judge(what: String, problem: String) -> void:
	if problem == "":
		_passes += 1
		print("  PASS  ", what)
	else:
		_failures.append("%s: %s" % [what, problem])
		print("  FAIL  ", what, " -- ", problem)


func _report() -> void:
	print("")
	print("=== %d passed, %d failed ===" % [_passes, _failures.size()])
	for line in _failures:
		print("  ", line)
	get_tree().quit(1 if _failures.size() > 0 else 0)
