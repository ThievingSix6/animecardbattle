extends Node

# =========================================================
# SMOKE TEST - builds every scene for real and reports anything Godot
# complains about while it does.
#
#   godot --headless --path . tools/Smoke.tscn
#
# Headless means nothing is drawn, but every node is still constructed,
# every MultiMesh still filled, every ArrayMesh still built and physics
# still stepped - which is where the bugs are. Compiling clean says the
# code parses; this says it runs.
#
# A save slot is opened first, because the worlds bounce straight back
# to the title screen without one.
# =========================================================

# Scene, and how many physics frames to let it run before moving on.
const CASES: Array[Dictionary] = [
	{"scene": "res://scenes/Lobby.tscn", "frames": 90},
	{"scene": "res://scenes/Arena.tscn", "frames": 180},
	{"scene": "res://scenes/Zone.tscn", "frames": 60},
	{"scene": "res://scenes/Title.tscn", "frames": 20},
	{"scene": "res://scenes/Main.tscn", "frames": 20},
	{"scene": "res://scenes/Settings.tscn", "frames": 20},
	{"scene": "res://scenes/CardCollection.tscn", "frames": 20},
	{"scene": "res://scenes/Battle.tscn", "frames": 60},
]

var _index := 0
var _left := 0
var _current: Node


# The driver is parented to the tree's ROOT rather than left as the
# current scene.
#
# Any screen that navigates calls change_scene_to_file(), which frees
# whatever is currently the scene - and when the harness IS the current
# scene, that is the harness. The run stopped dead the first time a
# screen routed anywhere. A direct child of root is not the current
# scene, so it survives every scene change the test provokes.
func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return

	var driver: Node = get_script().new()
	driver.name = "SmokeDriver"
	get_tree().root.add_child.call_deferred(driver)


func _run() -> void:
	# Slots are ONE-based - has_active_slot() is `active_slot >= 1`. Slot
	# zero opened nothing, so every world bounced to the title screen and
	# the scene change took this node down with it.
	GameState.open_slot(1)
	print("[smoke] slot open: ", GameState.has_active_slot())
	_next()


func _physics_process(_delta: float) -> void:
	if _current == null:
		return
	_left -= 1
	if _left <= 0:
		print("[smoke] ok   ", CASES[_index - 1]["scene"])
		_current.queue_free()
		_current = null
		_next()


func _next() -> void:
	if _index >= CASES.size():
		print("")
		print("=== smoke test finished, %d scenes built ===" % CASES.size())
		get_tree().quit(0)
		return

	var case: Dictionary = CASES[_index]
	_index += 1

	var path := str(case["scene"])
	print("[smoke] load ", path)

	var packed: PackedScene = load(path)
	if packed == null:
		print("[smoke] FAILED to load ", path)
		_next()
		return

	_current = packed.instantiate()
	_left = int(case["frames"])
	add_child(_current)
