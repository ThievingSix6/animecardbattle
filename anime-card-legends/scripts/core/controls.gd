extends Node

# =========================================================
# INPUT MAP (autoload) - registered in code rather than baked into
# project.godot.
#
# The built-in ui_* actions are arrow keys plus the controller's d-pad,
# and nothing else. That is why WASD did nothing: it was never bound.
# Reusing ui_* for gameplay is a trap anyway - those actions also drive
# menu navigation, so a joystick resting slightly off-centre both walks
# the player and scrolls whatever UI is open.
#
# Everything below is registered on startup if it is not already there,
# so a binding changed in the editor's Input Map is respected and
# nothing is clobbered.
#
# Keyboard and controller are both live at once - no mode to toggle.
# =========================================================

const DEADZONE := 0.22

# One action -> the keys, buttons and stick directions that fire it.
#
# "keys"    physical scancodes, so WASD stays WASD on an AZERTY keyboard
# "buttons" JoyButton values
# "axis"    [JoyAxis, direction] where direction is -1.0 or 1.0
const ACTIONS: Array[Dictionary] = [
	{
		"name": "acl_forward",
		"keys": [KEY_W, KEY_UP],
		"buttons": [JOY_BUTTON_DPAD_UP],
		"axis": [[JOY_AXIS_LEFT_Y, -1.0]],
	},
	{
		"name": "acl_back",
		"keys": [KEY_S, KEY_DOWN],
		"buttons": [JOY_BUTTON_DPAD_DOWN],
		"axis": [[JOY_AXIS_LEFT_Y, 1.0]],
	},
	{
		"name": "acl_left",
		"keys": [KEY_A, KEY_LEFT],
		"buttons": [JOY_BUTTON_DPAD_LEFT],
		"axis": [[JOY_AXIS_LEFT_X, -1.0]],
	},
	{
		"name": "acl_right",
		"keys": [KEY_D, KEY_RIGHT],
		"buttons": [JOY_BUTTON_DPAD_RIGHT],
		"axis": [[JOY_AXIS_LEFT_X, 1.0]],
	},
	{
		# Cross on a PlayStation pad. Godot's JOY_BUTTON_A is the
		# bottom face button on every controller.
		"name": "acl_jump",
		"keys": [KEY_SPACE],
		"buttons": [JOY_BUTTON_A],
		"axis": [],
	},
	{
		# Triangle. Getting in and out of the car is its own action, not
		# the interact button, so boost and exit can never be the same
		# press.
		"name": "acl_vehicle",
		"keys": [KEY_F, KEY_ENTER, KEY_KP_ENTER],
		"buttons": [JOY_BUTTON_Y],
		"axis": [],
	},
	{
		# Right trigger. A trigger is an axis, not a button, so it reads
		# as an analogue throttle rather than on-or-off.
		"name": "acl_throttle",
		"keys": [KEY_W, KEY_UP],
		"buttons": [],
		"axis": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	},
	{
		# Left trigger: brake, and reverse once stopped.
		"name": "acl_brake",
		"keys": [KEY_S, KEY_DOWN],
		"buttons": [],
		"axis": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
	},
	{
		# On foot only. L3, so it is nowhere near the driving controls.
		"name": "acl_sprint",
		"keys": [KEY_SHIFT],
		"buttons": [JOY_BUTTON_LEFT_STICK],
		"axis": [],
	},
	{
		# Deliberately not the same button as jump: standing on a portal
		# pad and jumping should not open the travel menu.
		"name": "acl_interact",
		"keys": [KEY_E, KEY_ENTER, KEY_KP_ENTER],
		"buttons": [JOY_BUTTON_X],
		"axis": [],
	},
	{
		# Circle. Not a shoulder button, because R1 is powerslide.
		"name": "acl_boost",
		"keys": [KEY_SHIFT],
		"buttons": [JOY_BUTTON_B],
		"axis": [],
	},
	{
		# R1: powerslide on the ground, air roll in the air. One button
		# for both, the way Rocket League does it.
		"name": "acl_drift",
		"keys": [KEY_CTRL],
		"buttons": [JOY_BUTTON_RIGHT_SHOULDER],
		"axis": [],
	},
	{
		"name": "acl_cancel",
		"keys": [KEY_ESCAPE],
		"buttons": [JOY_BUTTON_B],
		"axis": [],
	},
	# Right stick look. The mouse is handled separately, as relative
	# motion rather than an action.
	{
		"name": "acl_look_left",
		"keys": [],
		"buttons": [],
		"axis": [[JOY_AXIS_RIGHT_X, -1.0]],
	},
	{
		"name": "acl_look_right",
		"keys": [],
		"buttons": [],
		"axis": [[JOY_AXIS_RIGHT_X, 1.0]],
	},
	{
		"name": "acl_look_up",
		"keys": [],
		"buttons": [],
		"axis": [[JOY_AXIS_RIGHT_Y, -1.0]],
	},
	{
		"name": "acl_look_down",
		"keys": [],
		"buttons": [],
		"axis": [[JOY_AXIS_RIGHT_Y, 1.0]],
	},
]


func _ready() -> void:
	for action in ACTIONS:
		_register(action)


func _register(action: Dictionary) -> void:
	var action_name := str(action["name"])

	# An action already defined in the editor's Input Map wins, so a
	# rebind made there is never overwritten on the next launch.
	if InputMap.has_action(action_name):
		return

	InputMap.add_action(action_name, DEADZONE)

	for code in action["keys"]:
		var key := InputEventKey.new()
		key.physical_keycode = int(code) as Key
		InputMap.action_add_event(action_name, key)

	for button in action["buttons"]:
		var pad := InputEventJoypadButton.new()
		pad.button_index = int(button) as JoyButton
		InputMap.action_add_event(action_name, pad)

	for entry in action["axis"]:
		var pair: Array = entry
		var motion := InputEventJoypadMotion.new()
		motion.axis = int(pair[0]) as JoyAxis
		motion.axis_value = float(pair[1])
		InputMap.action_add_event(action_name, motion)


# --- Convenience ---------------------------------------------------------

# Movement on the ground plane. x is strafe, y is forward.
func move_vector() -> Vector2:
	return Input.get_vector("acl_left", "acl_right", "acl_forward", "acl_back")


# Right-stick look, already scaled to a per-frame delta.
func look_vector() -> Vector2:
	return Input.get_vector("acl_look_left", "acl_look_right", "acl_look_up", "acl_look_down")


func interact_pressed() -> bool:
	return Input.is_action_just_pressed("acl_interact")


func vehicle_pressed() -> bool:
	return Input.is_action_just_pressed("acl_vehicle")


# Analogue on a trigger, digital on a key. Positive is forward.
func throttle() -> float:
	return Input.get_action_strength("acl_throttle") - Input.get_action_strength("acl_brake")


func cancel_pressed() -> bool:
	return Input.is_action_just_pressed("acl_cancel")


# True while any controller is attached, so prompts can name the right
# button instead of always saying ENTER.
func using_controller() -> bool:
	return not Input.get_connected_joypads().is_empty()


func interact_prompt() -> String:
	if using_controller():
		return "SQUARE / E"
	return "E"


func vehicle_prompt() -> String:
	if using_controller():
		return "TRIANGLE"
	return "F"
