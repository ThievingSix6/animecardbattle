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
		"label": "Forward",
		"group": "On foot",
		"keys": [KEY_W, KEY_UP],
		"buttons": [JOY_BUTTON_DPAD_UP],
		"axis": [[JOY_AXIS_LEFT_Y, -1.0]],
	},
	{
		"name": "acl_back",
		"label": "Back",
		"group": "On foot",
		"keys": [KEY_S, KEY_DOWN],
		"buttons": [JOY_BUTTON_DPAD_DOWN],
		"axis": [[JOY_AXIS_LEFT_Y, 1.0]],
	},
	{
		"name": "acl_left",
		"label": "Left",
		"group": "On foot",
		"keys": [KEY_A, KEY_LEFT],
		"buttons": [JOY_BUTTON_DPAD_LEFT],
		"axis": [[JOY_AXIS_LEFT_X, -1.0]],
	},
	{
		"name": "acl_right",
		"label": "Right",
		"group": "On foot",
		"keys": [KEY_D, KEY_RIGHT],
		"buttons": [JOY_BUTTON_DPAD_RIGHT],
		"axis": [[JOY_AXIS_LEFT_X, 1.0]],
	},
	{
		# Cross on a PlayStation pad. Godot's JOY_BUTTON_A is the
		# bottom face button on every controller.
		"name": "acl_jump",
		"label": "Jump",
		"group": "Driving",
		"keys": [KEY_SPACE],
		"buttons": [JOY_BUTTON_A],
		"axis": [],
	},
	{
		# Triangle. Getting in and out of the car is its own action, not
		# the interact button, so boost and exit can never be the same
		# press.
		"name": "acl_vehicle",
		"label": "Enter / leave car",
		"group": "Driving",
		"keys": [KEY_F, KEY_ENTER, KEY_KP_ENTER],
		"buttons": [JOY_BUTTON_Y],
		"axis": [],
	},
	{
		# Right trigger. A trigger is an axis, not a button, so it reads
		# as an analogue throttle rather than on-or-off.
		"name": "acl_throttle",
		"label": "Throttle",
		"group": "Driving",
		"keys": [KEY_W, KEY_UP],
		"buttons": [],
		"axis": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	},
	{
		# Left trigger: brake, and reverse once stopped.
		"name": "acl_brake",
		"label": "Brake / reverse",
		"group": "Driving",
		"keys": [KEY_S, KEY_DOWN],
		"buttons": [],
		"axis": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
	},
	{
		# On foot only. L3, so it is nowhere near the driving controls.
		"name": "acl_sprint",
		"label": "Sprint",
		"group": "On foot",
		"keys": [KEY_SHIFT],
		"buttons": [JOY_BUTTON_LEFT_STICK],
		"axis": [],
	},
	{
		# Deliberately not the same button as jump: standing on a portal
		# pad and jumping should not open the travel menu.
		"name": "acl_interact",
		"label": "Interact",
		"group": "On foot",
		"keys": [KEY_E, KEY_ENTER, KEY_KP_ENTER],
		"buttons": [JOY_BUTTON_X],
		"axis": [],
	},
	{
		# L1. R1 is powerslide, so the two shoulders are the two things
		# you hold while cornering.
		"name": "acl_boost",
		"label": "Boost",
		"group": "Driving",
		"keys": [KEY_SHIFT],
		"buttons": [JOY_BUTTON_LEFT_SHOULDER],
		"axis": [],
	},
	{
		# R1: powerslide on the ground, air roll in the air. One button
		# for both, the way Rocket League does it.
		"name": "acl_drift",
		"label": "Powerslide / air roll",
		"group": "Driving",
		"keys": [KEY_CTRL],
		"buttons": [JOY_BUTTON_RIGHT_SHOULDER],
		"axis": [],
	},
	{
		# DIRECTIONAL AIR ROLL, Rocket League's "Air Roll Right".
		# Hold it and the car rolls right on its own; the stick still
		# pitches and yaws underneath. R1 keeps its powerslide job on the
		# ground, so the shoulder means "rotate" either way up.
		"name": "acl_air_roll_right",
		"label": "Air roll right",
		"group": "Driving",
		"keys": [KEY_E],
		"buttons": [JOY_BUTTON_RIGHT_SHOULDER],
		"axis": [],
	},
	{
		# Square, the same button as interact. They can never collide:
		# interact is only read on foot, air roll only with the wheels
		# off the ground.
		"name": "acl_air_roll_left",
		"label": "Air roll left",
		"group": "Driving",
		"keys": [KEY_Q],
		"buttons": [JOY_BUTTON_X],
		"axis": [],
	},
	{
		# Rocket League's ball camera: right-stick click, and C on a
		# keyboard. Held or toggled, the view swings round to keep the
		# ball in frame.
		"name": "acl_ball_cam",
		"label": "Ball camera",
		"group": "Camera",
		"keys": [KEY_C],
		"buttons": [JOY_BUTTON_RIGHT_STICK],
		"axis": [],
	},
	{
		"name": "acl_cancel",
		"label": "Menu / back",
		"group": "On foot",
		"keys": [KEY_ESCAPE],
		"buttons": [JOY_BUTTON_B],
		"axis": [],
	},
	# Right stick look. The mouse is handled separately, as relative
	# motion rather than an action.
	{
		"name": "acl_look_left",
		"label": "Look left",
		"group": "Camera",
		"keys": [],
		"buttons": [],
		"axis": [[JOY_AXIS_RIGHT_X, -1.0]],
	},
	{
		"name": "acl_look_right",
		"label": "Look right",
		"group": "Camera",
		"keys": [],
		"buttons": [],
		"axis": [[JOY_AXIS_RIGHT_X, 1.0]],
	},
	{
		"name": "acl_look_up",
		"label": "Look up",
		"group": "Camera",
		"keys": [],
		"buttons": [],
		"axis": [[JOY_AXIS_RIGHT_Y, -1.0]],
	},
	{
		"name": "acl_look_down",
		"label": "Look down",
		"group": "Camera",
		"keys": [],
		"buttons": [],
		"axis": [[JOY_AXIS_RIGHT_Y, 1.0]],
	},
]


func _ready() -> void:
	for action in ACTIONS:
		_register(action)
	apply_saved_bindings()


# --- Rebinding -----------------------------------------------------------
#
# Every action keeps at most ONE key and ONE controller button that the
# player can change. Stick axes are not rebindable: a throttle that is a
# trigger and a look that is the right stick are not things a rebind
# screen has anything useful to say about, and leaving them alone means
# rebinding can never take the car's steering away.

# The actions the settings screen offers, in the order it shows them.
const GROUP_ORDER: Array[String] = ["Driving", "Camera", "On foot"]


func rebindable() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for group in GROUP_ORDER:
		for action in ACTIONS:
			if str(action.get("group", "")) != group:
				continue
			if action["keys"].is_empty() and action["buttons"].is_empty():
				continue
			out.append(action)
	return out


# What the player has this action on right now, written the way a
# settings row wants to read it.
func binding_text(action_name: String) -> String:
	var parts: Array[String] = []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key: InputEventKey = event
			parts.append(OS.get_keycode_string(
				DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)))
		elif event is InputEventJoypadButton:
			var pad: InputEventJoypadButton = event
			parts.append(button_name(pad.button_index))
	if parts.is_empty():
		return "—"
	return " / ".join(parts)


# PlayStation names, because that is the pad the controls were written
# for and "Square" is a great deal clearer than "Joypad Button 2".
const BUTTON_NAMES := {
	JOY_BUTTON_A: "Cross",
	JOY_BUTTON_B: "Circle",
	JOY_BUTTON_X: "Square",
	JOY_BUTTON_Y: "Triangle",
	JOY_BUTTON_LEFT_SHOULDER: "L1 / LB",
	JOY_BUTTON_RIGHT_SHOULDER: "R1 / RB",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "Share",
	JOY_BUTTON_START: "Options",
	JOY_BUTTON_DPAD_UP: "D-Pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
}


func button_name(index: int) -> String:
	if BUTTON_NAMES.has(index):
		return str(BUTTON_NAMES[index])
	return "Button %d" % index


# Puts `event` on `action_name`, replacing whatever of the same KIND was
# there. Rebinding a key leaves the controller button alone and the other
# way round, so one screen can rebind both without either wiping the
# other out. Returns false for anything that is not a key or a button.
func rebind(action_name: String, event: InputEvent) -> bool:
	if not InputMap.has_action(action_name):
		return false

	var is_key := event is InputEventKey
	var is_button := event is InputEventJoypadButton
	if not is_key and not is_button:
		return false

	for existing in InputMap.action_get_events(action_name):
		if (is_key and existing is InputEventKey) or (is_button and existing is InputEventJoypadButton):
			InputMap.action_erase_event(action_name, existing)

	InputMap.action_add_event(action_name, event)
	_remember(action_name)
	return true


func reset_action(action_name: String) -> void:
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)
	for action in ACTIONS:
		if str(action["name"]) == action_name:
			_register(action)
			break
	Settings.clear_binding(action_name)


func reset_all_bindings() -> void:
	Settings.clear_bindings()
	for action in ACTIONS:
		var action_name := str(action["name"])
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
		_register(action)


# The first key and the first button currently on an action, written back
# to Settings so they survive a restart.
func _remember(action_name: String) -> void:
	var key := 0
	var button := -1
	for event in InputMap.action_get_events(action_name):
		if key == 0 and event is InputEventKey:
			key = int((event as InputEventKey).physical_keycode)
		elif button < 0 and event is InputEventJoypadButton:
			button = int((event as InputEventJoypadButton).button_index)
	Settings.set_binding(action_name, key, button)


# Replays what the player changed last time over the defaults registered
# above. Anything they never touched is left exactly as it was.
func apply_saved_bindings() -> void:
	for action_name in Settings.bindings:
		var name_text := str(action_name)
		if not InputMap.has_action(name_text):
			continue
		var entry: Dictionary = Settings.bindings[action_name]

		var key := int(entry.get("key", 0))
		if key != 0:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = key as Key
			_swap(name_text, key_event)

		var button := int(entry.get("button", -1))
		if button >= 0:
			var pad := InputEventJoypadButton.new()
			pad.button_index = button as JoyButton
			_swap(name_text, pad)


# rebind() without writing back to Settings - used while loading, where
# writing back would be circular.
func _swap(action_name: String, event: InputEvent) -> void:
	var is_key := event is InputEventKey
	for existing in InputMap.action_get_events(action_name):
		if (is_key and existing is InputEventKey) or (not is_key and existing is InputEventJoypadButton):
			InputMap.action_erase_event(action_name, existing)
	InputMap.action_add_event(action_name, event)


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


# Directional air roll: -1 rolling left, +1 rolling right, 0 for neither.
# Both held cancel out, which is better than picking a winner.
func air_roll() -> float:
	var left := Input.is_action_pressed("acl_air_roll_left")
	var right := Input.is_action_pressed("acl_air_roll_right")
	if left == right:
		return 0.0
	return 1.0 if right else -1.0


func cancel_pressed() -> bool:
	return Input.is_action_just_pressed("acl_cancel")


func ball_cam_pressed() -> bool:
	return Input.is_action_just_pressed("acl_ball_cam")


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
