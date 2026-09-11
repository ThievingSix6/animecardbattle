class_name ArenaHUD
extends CanvasLayer

# =========================================================
# Scoreboard, clock, boost meter and the end-of-match card.
# =========================================================

var _blue: Label
var _orange: Label
var _clock: Label
var _shout: Label
var _boost_bar: ProgressBar
var _speed: Label
var _result: Control


func _init() -> void:
	layer = 12


func _ready() -> void:
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Scoreboard, centred at the top the way every sports game puts it.
	var board := UI.accent_panel(Design.ACCENT, Design.S3)
	board.set_anchors_preset(Control.PRESET_CENTER_TOP)
	board.offset_left = -190
	board.offset_right = 190
	board.offset_top = Design.S4
	board.offset_bottom = 96
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(board)

	var row := UI.hbox(Design.S4)
	board.add_child(row)

	_blue = UI.label("0", Design.FS_DISPLAY, Color("#3b82f6"), HORIZONTAL_ALIGNMENT_CENTER)
	_blue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_blue)

	var middle := UI.vbox(0)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock = UI.label("5:00", Design.FS_HEADING, Design.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	middle.add_child(_clock)
	middle.add_child(UI.label("ROCKET ARENA", Design.FS_MICRO, Design.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(middle)

	_orange = UI.label("0", Design.FS_DISPLAY, Color("#f5a623"), HORIZONTAL_ALIGNMENT_CENTER)
	_orange.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_orange)

	_shout = UI.label("", Design.FS_DISPLAY, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_shout.set_anchors_preset(Control.PRESET_CENTER)
	_shout.offset_left = -400
	_shout.offset_right = 400
	_shout.offset_top = -40
	_shout.offset_bottom = 40
	_shout.add_theme_color_override("font_outline_color", Design.BG)
	_shout.add_theme_constant_override("outline_size", 10)
	_shout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shout)

	root.add_child(_build_boost())

	var hint := UI.caption(
		"R2 accelerate  ·  L2 brake  ·  R1 air roll  ·  Cross jump / flip  ·  "
		+ "Circle boost  ·  Esc to leave")
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -Design.S6
	hint.offset_bottom = -Design.S4
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)


func _build_boost() -> Control:
	var panel := UI.accent_panel(Design.ACCENT, Design.S3)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -260
	panel.offset_right = -Design.S5
	panel.offset_top = -128
	panel.offset_bottom = -60
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body := UI.vbox(Design.S1)
	panel.add_child(body)

	var row := UI.hbox(Design.S2)
	row.add_child(UI.label("BOOST", Design.FS_MICRO, Design.ACCENT))
	row.add_child(UI.spacer())
	_speed = UI.label("", Design.FS_MICRO, Design.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(_speed)
	body.add_child(row)

	_boost_bar = ProgressBar.new()
	_boost_bar.min_value = 0.0
	_boost_bar.max_value = 1.0
	_boost_bar.show_percentage = false
	_boost_bar.custom_minimum_size = Vector2(0, 14)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Design.ACCENT
	fill.set_corner_radius_all(4)
	_boost_bar.add_theme_stylebox_override("fill", fill)
	body.add_child(_boost_bar)

	return panel


# --- Updates ------------------------------------------------------------

func set_score(blue: int, orange: int) -> void:
	if _blue:
		_blue.text = str(blue)
	if _orange:
		_orange.text = str(orange)


func set_clock(seconds: float) -> void:
	if _clock == null:
		return
	var whole := int(ceil(seconds))
	_clock.text = "%d:%02d" % [int(whole / 60.0), whole % 60]


func show_boost(fraction: float, speed: float) -> void:
	if _boost_bar:
		_boost_bar.value = fraction
	if _speed:
		_speed.text = "%d km/h" % int(round(speed * 3.6))


# Fades on its own, so callers never have to clear it.
func announce(text: String) -> void:
	if _shout == null or _shout.text == text:
		return
	_shout.text = text
	_shout.modulate.a = 1.0
	if text == "":
		return

	var tween := create_tween()
	tween.tween_interval(1.1)
	tween.tween_property(_shout, "modulate:a", 0.0, 0.6)


func finish(verdict: String, blue: int, orange: int) -> void:
	announce("")

	_result = Control.new()
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_result)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Design.OVERLAY
	_result.add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.add_child(centre)

	var panel := UI.accent_panel(Design.ACCENT, Design.S5)
	panel.custom_minimum_size = Vector2(420, 0)
	centre.add_child(panel)

	var body := UI.vbox(Design.S4)
	panel.add_child(body)
	body.add_child(UI.label(verdict, Design.FS_DISPLAY, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UI.label("%d — %d" % [blue, orange], Design.FS_TITLE, Design.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER))

	var actions := UI.hbox(Design.S3)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(UI.primary_button("Play again", func():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().reload_current_scene()
	, Vector2(160, 48)))
	actions.add_child(UI.button("Back to the city", func():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(Routes.LOBBY)
	, Vector2(180, 48)))
	body.add_child(actions)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
