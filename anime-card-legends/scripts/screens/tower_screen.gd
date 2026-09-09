extends Screen

var _grid: GridContainer


func screen_title() -> String: return "Tower"


func build_content() -> void:
	var p: ProgressionSystem = GameState.progression

	var header := UI.hbox(Design.S3)
	header.add_child(UI.caption("Every %dth floor is a boss. Clear floors in order to climb." % Config.BOSS_EVERY))
	header.add_child(UI.spacer())
	header.add_child(UI.label("%d / %d cleared" % [p.highest_floor, Config.MAX_FLOOR], Design.FS_BODY, Design.ACCENT))
	content.add_child(header)

	var scroll := UI.scroll()
	_grid = UI.grid(10, Design.S2)
	scroll.add_child(_grid)
	content.add_child(scroll)

	for floor_number in range(1, Config.MAX_FLOOR + 1):
		_grid.add_child(_build_node(floor_number))


func _build_node(floor_number: int) -> Button:
	var p: ProgressionSystem = GameState.progression
	var cleared := floor_number <= p.highest_floor
	var unlocked := p.is_unlocked(floor_number)
	var is_next := floor_number == p.highest_floor + 1
	var boss := p.is_boss_floor(floor_number)

	var accent := Design.HAIRLINE
	var bg := Design.alpha(Design.SURFACE, 0.5)
	var icon := "🔒"

	if cleared:
		accent = Design.SUCCESS
		bg = Design.alpha(Design.SUCCESS, 0.12)
		icon = "✓"
	elif unlocked:
		accent = Design.INFO
		if boss:
			accent = Design.DANGER
		elif is_next:
			accent = Design.ACCENT
		bg = Design.SURFACE_2
		icon = "⚔️"
		if boss:
			icon = "☠️"

	var node := Button.new()
	node.custom_minimum_size = Vector2(84, 84)
	node.text = ""
	node.disabled = not unlocked
	node.focus_mode = Control.FOCUS_NONE

	var edge := 2
	var glow := 0
	if is_next:
		edge = 3
		glow = 10
	var style := ThemeBuilder.aura_style(bg, accent, edge, glow, Design.R_MD)
	var states: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]
	for state in states:
		node.add_theme_stylebox_override(state, style)

	var body := UI.vbox(0)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(UI.label(icon, Design.FS_HEADING, Design.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var number_color := Design.TEXT
	if not unlocked:
		number_color = Design.TEXT_MUTED
	body.add_child(UI.label(str(floor_number), Design.FS_SMALL, number_color, HORIZONTAL_ALIGNMENT_CENTER))
	node.add_child(body)

	if unlocked:
		node.pressed.connect(func():
			GameState.progression.pending_floor = floor_number
			Routes.go(self, Routes.BATTLE)
		)

	return node
