class_name ArenaSettings
extends CanvasLayer

# =========================================================
# THE ROCKET ARENA MENU.
#
# Escape opens it mid-match. Three tabs, laid out the way Rocket League
# lays the same things out:
#
#   CAMERA    RL's seven camera numbers, with RL's ranges and RL's
#             defaults, plus the ball camera. Everything is live - drag a
#             slider and the view behind the car moves while you watch.
#   CONTROLS  every rebindable action, its key and its controller
#             button, each changed by pressing the one you want.
#   MATCH     1v1 or 2v2, and restart.
#
# The tree is paused while it is up, so nothing moves behind it and the
# clock does not run down while you are reading.
# =========================================================

signal leave_requested
signal restart_requested

const TABS: Array[String] = ["Camera", "Controls", "Match"]

const PANEL_WIDTH := 720
const PANEL_HEIGHT := 560
const ROW_HEIGHT := 34

var _root: Control
var _body: VBoxContainer
var _tab_buttons: Array[Button] = []
var _tab := 0
var _open := false

# The action waiting for a button press, "" when nothing is.
var _capturing := ""
var _capture_label: Label


func _ready() -> void:
	# The menu itself has to keep running while the tree it paused is
	# stopped, or it could never be closed again.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_build()
	_root.visible = false


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_show_tab(_tab)


func close() -> void:
	if not _open:
		return
	_open = false
	_capturing = ""
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Chrome ------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Design.alpha(Design.BG, 0.82)
	_root.add_child(scrim)

	var frame := UI.panel(Design.SURFACE, Design.S4)
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	frame.offset_left = -PANEL_WIDTH * 0.5
	frame.offset_right = PANEL_WIDTH * 0.5
	frame.offset_top = -PANEL_HEIGHT * 0.5
	frame.offset_bottom = PANEL_HEIGHT * 0.5
	_root.add_child(frame)

	var column := UI.vbox(Design.S3)
	frame.add_child(column)

	column.add_child(UI.title("ROCKET ARENA"))

	var tabs := UI.hbox(Design.S2)
	column.add_child(tabs)
	for i in TABS.size():
		var index := i
		var button := UI.button(TABS[i], func(): _show_tab(index))
		tabs.add_child(button)
		_tab_buttons.append(button)

	column.add_child(UI.separator())

	var page := UI.scroll()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(page)

	_body = UI.vbox(Design.S3)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_body)

	column.add_child(UI.separator())

	var footer := UI.hbox(Design.S2)
	column.add_child(footer)
	footer.add_child(UI.primary_button("Resume", close))
	footer.add_child(UI.spacer())
	footer.add_child(UI.button("Leave arena", func(): leave_requested.emit()))

	# The "press a button" prompt, over everything else.
	_capture_label = UI.label("", Design.FS_HEADING, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_capture_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_capture_label.offset_top = -90
	_capture_label.offset_left = -PANEL_WIDTH * 0.5
	_capture_label.offset_right = PANEL_WIDTH * 0.5
	_capture_label.visible = false
	_root.add_child(_capture_label)


func _show_tab(index: int) -> void:
	_tab = clampi(index, 0, TABS.size() - 1)
	for i in _tab_buttons.size():
		_tab_buttons[i].disabled = i == _tab

	for child in _body.get_children():
		child.queue_free()

	match _tab:
		0: _build_camera()
		1: _build_controls()
		_: _build_match()


# --- Camera -------------------------------------------------------------

func _build_camera() -> void:
	_body.add_child(UI.wrapped_caption(
		"Rocket League's own camera settings, in Rocket League's units. "
		+ "Everything here is live - the view behind the car moves as you drag."))

	for key in Settings.CAMERA_KEYS:
		_body.add_child(_camera_row(key))

	_body.add_child(UI.separator())
	_body.add_child(_ball_cam_row())
	_body.add_child(UI.button("Reset camera", func():
		Settings.reset_camera()
		_show_tab(_tab)))


func _camera_row(key: String) -> Control:
	var span: Array = Settings.CAMERA_RANGES[key]
	var low := float(span[0])
	var high := float(span[1])

	var row := UI.hbox(Design.S3)

	var name_label := UI.label(str(Settings.CAMERA_LABELS[key]))
	name_label.custom_minimum_size.x = 190
	row.add_child(name_label)

	var value_label := UI.label("", Design.FS_BODY, Design.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.custom_minimum_size.x = 70

	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	# Whole numbers for the big ranges, tenths for the 0-1 ones, which
	# is the granularity RL gives each of them.
	slider.step = 1.0 if high - low > 5.0 else 0.05
	slider.value = Settings.camera_value(key)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = ROW_HEIGHT
	slider.value_changed.connect(func(value: float):
		Settings.set_camera_value(key, value)
		value_label.text = _format(key, value))
	row.add_child(slider)

	value_label.text = _format(key, slider.value)
	row.add_child(value_label)
	return row


func _format(key: String, value: float) -> String:
	var span: Array = Settings.CAMERA_RANGES[key]
	if float(span[1]) - float(span[0]) > 5.0:
		return "%d" % int(roundf(value))
	return "%.2f" % value


func _ball_cam_row() -> Control:
	var row := UI.hbox(Design.S3)
	var name_label := UI.label("Ball camera")
	name_label.custom_minimum_size.x = 190
	row.add_child(name_label)

	var toggle := CheckButton.new()
	toggle.button_pressed = Settings.ball_cam
	toggle.toggled.connect(Settings.set_ball_cam)
	row.add_child(toggle)

	row.add_child(UI.caption("Toggle in-match with " + Controls.binding_text("acl_ball_cam")))
	row.add_child(UI.spacer())
	return row


# --- Controls -----------------------------------------------------------

func _build_controls() -> void:
	_body.add_child(UI.wrapped_caption(
		"Press Rebind, then press the key or the controller button you want. "
		+ "A key replaces the key and a button replaces the button, so both "
		+ "can be set without either clearing the other. Escape cancels."))

	var group := ""
	for action in Controls.rebindable():
		var action_group: String = str(action.get("group", ""))
		if action_group != group:
			group = action_group
			_body.add_child(UI.section(group.to_upper()))
		_body.add_child(_binding_row(action))

	_body.add_child(UI.separator())
	_body.add_child(UI.button("Reset all controls", func():
		Controls.reset_all_bindings()
		_show_tab(_tab)))


func _binding_row(action: Dictionary) -> Control:
	var action_name := str(action["name"])

	var row := UI.hbox(Design.S3)

	var label_text := str(action.get("label", action_name))
	var name_label := UI.label(label_text)
	name_label.custom_minimum_size.x = 210
	row.add_child(name_label)

	var bound := UI.label(Controls.binding_text(action_name), Design.FS_BODY, Design.TEXT_DIM)
	bound.custom_minimum_size.x = 190
	row.add_child(bound)

	row.add_child(UI.spacer())
	row.add_child(UI.button("Rebind", func(): _start_capture(action_name)))
	row.add_child(UI.button("Default", func():
		Controls.reset_action(action_name)
		_show_tab(_tab)))
	return row


func _start_capture(action_name: String) -> void:
	_capturing = action_name
	_capture_label.text = "Press a key or a controller button…"
	_capture_label.visible = true


# Captured here rather than in _gui_input so a controller button, which
# no Control ever receives, is caught as well as a key.
func _input(event: InputEvent) -> void:
	if not _open:
		return

	var is_key := event is InputEventKey and event.is_pressed() and not event.is_echo()
	var is_button := event is InputEventJoypadButton and event.is_pressed()
	if not is_key and not is_button:
		return

	# Nothing to capture: escape and the pad's cancel button close the
	# menu. The arena cannot do this itself - the tree is paused, so its
	# _process is not running to read the action.
	if _capturing == "":
		var escaping := is_key and (event as InputEventKey).physical_keycode == KEY_ESCAPE
		var cancelling := is_button and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
		if escaping or cancelling:
			get_viewport().set_input_as_handled()
			close()
		return

	get_viewport().set_input_as_handled()

	# Escape is the way out of a capture, so it is never bound from here.
	if is_key and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_finish_capture()
		return

	Controls.rebind(_capturing, event.duplicate())
	_finish_capture()
	_show_tab(_tab)


func _finish_capture() -> void:
	_capturing = ""
	_capture_label.visible = false


# --- Match --------------------------------------------------------------

func _build_match() -> void:
	_body.add_child(UI.wrapped_caption(
		"Team size takes effect at the start of a match, because it changes "
		+ "how many cars are on the pitch."))

	var row := UI.hbox(Design.S3)
	var name_label := UI.label("Team size")
	name_label.custom_minimum_size.x = 190
	row.add_child(name_label)

	for entry in Settings.TEAM_SIZES:
		var value := entry
		var label := "%dv%d" % [value, value]
		var button := UI.button(label, func():
			Settings.set_team_size(value)
			_show_tab(_tab))
		button.disabled = Settings.team_size == value
		row.add_child(button)

	row.add_child(UI.spacer())
	_body.add_child(row)

	_body.add_child(UI.separator())
	_body.add_child(UI.primary_button("Restart match", func(): restart_requested.emit()))


# Leaving the scene with the tree still paused would take the pause with
# us into the city.
func _exit_tree() -> void:
	if _open:
		get_tree().paused = false
