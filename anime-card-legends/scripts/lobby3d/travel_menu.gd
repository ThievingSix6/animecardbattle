class_name TravelMenu
extends CanvasLayer

# =========================================================
# What the portal opens: the city, plus every campaign zone, with the
# ones you have not reached shown locked rather than hidden - a locked
# destination you can see is a goal.
#
# The tree is paused while this is up, so the player is not still
# walking around underneath it.
# =========================================================

signal closed

# Which destination the player is standing in, so it can be marked
# rather than offered. -1 means the city.
var here := -1

var _rows: VBoxContainer


static func open(host: Node, current_zone: int) -> TravelMenu:
	var menu := TravelMenu.new()
	menu.here = current_zone
	host.add_child(menu)
	return menu


func _init() -> void:
	layer = 20
	# Runs while the world behind it is frozen.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func _ready() -> void:
	_build()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Design.OVERLAY
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := UI.accent_panel(Color("#5ad1ff"), Design.S5)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var body := UI.vbox(Design.S3)
	panel.add_child(body)

	var header := UI.hbox(Design.S3)
	header.add_child(UI.title("◈  Travel"))
	header.add_child(UI.spacer())
	header.add_child(UI.button("✕", close, Vector2(40, 40)))
	body.add_child(header)

	body.add_child(UI.caption(
		"The portal network links the city to every zone you have opened."))
	body.add_child(UI.separator())

	# The list can outgrow a short window once there are more zones.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 420)
	body.add_child(scroll)

	_rows = UI.vbox(Design.S2)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)

	_rows.add_child(_city_row())
	_rows.add_child(_arena_row())
	_rows.add_child(_rings_row())
	_rows.add_child(_garage_row())
	for zone_index in Campaign.ZONES.size():
		_rows.add_child(_zone_row(zone_index))


# --- Rows ----------------------------------------------------------------

func _city_row() -> Control:
	var accent := Color("#5ad1ff")
	return _row(
		"🏙  The City",
		"Summon, collection, talents, clan — everything that is not a fight.",
		accent, true, here == -1, func(): _travel_to_city())


# The extra mode, alongside the campaign rather than buried in a menu.
func _arena_row() -> Control:
	return _row(
		"🚀  Rocket Arena",
		"Five minutes, one ball, one opponent. Bring the car.",
		Color("#ff6b35"), true, false, func(): _travel_to_arena())


# Flying practice, and the only place in the game with unlimited boost.
func _rings_row() -> Control:
	return _row(
		"💫  The Rings",
		"Thirty rings, unlimited boost, no floor. Fly the line.",
		Color("#35d6ff"), true, false, func(): _travel_to_rings())


func _garage_row() -> Control:
	return _row(
		"🔧  Garage",
		"Pick the car you drive. Every model in art/models/props/cars/.",
		Color("#b04cff"), true, false, func(): _travel_to_garage())


func _zone_row(zone_index: int) -> Control:
	var zone := Campaign.zone_at(zone_index)
	var accent := Color(str(zone["accent"]))

	var first_floor := Campaign.floor_for(zone_index, 0)
	var unlocked: bool = GameState.progression.is_unlocked(first_floor)
	var cleared := Campaign.stages_cleared_in(zone_index, GameState.progression.highest_floor)

	var blurb := str(zone["subtitle"])
	if unlocked:
		blurb += "   ·   %d/%d stages cleared" % [cleared, Campaign.STAGES_PER_ZONE]
	else:
		blurb = "Locked — clear zone %d to open this one." % zone_index

	return _row(
		"%s  %s" % [_zone_mark(zone), str(zone["name"])],
		blurb, accent, unlocked, here == zone_index,
		func(): _travel_to_zone(zone_index))


func _zone_mark(zone: Dictionary) -> String:
	return str(Design.ELEMENT_ICON.get(str(zone["element"]), "◆"))


func _row(title: String, blurb: String, accent: Color, unlocked: bool, is_here: bool, on_go: Callable) -> Control:
	var panel := UI.panel(Design.SURFACE, Design.S3)

	var row := UI.hbox(Design.S3)
	panel.add_child(row)

	var text := UI.vbox(Design.S1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_color := Design.TEXT
	if not unlocked:
		title_color = Design.TEXT_MUTED
	text.add_child(UI.label(title, Design.FS_HEADING, title_color))
	text.add_child(UI.caption(blurb))
	row.add_child(text)

	if is_here:
		row.add_child(UI.pill("you are here", accent))
		return panel

	if not unlocked:
		row.add_child(UI.pill("🔒 locked", Design.TEXT_MUTED))
		return panel

	var go := UI.primary_button("Travel", on_go, Vector2(120, 44))
	row.add_child(go)
	return panel


# --- Travel ---------------------------------------------------------------

func _travel_to_city() -> void:
	_leave(Routes.LOBBY)


func _travel_to_arena() -> void:
	_leave(Routes.ARENA)


func _travel_to_rings() -> void:
	_leave(Routes.RINGS)


func _travel_to_garage() -> void:
	_leave(Routes.GARAGE)


func _travel_to_zone(zone_index: int) -> void:
	GameState.progression.pending_zone = zone_index
	_leave(Routes.ZONE)


# Unpausing before the scene swap matters: a scene change does not clear
# the paused flag, and the next world would open frozen.
func _leave(route: String) -> void:
	Audio.play("summon")
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(route)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
