extends Screen

# =========================================================
# THE GARAGE - pick which car you drive.
#
# Every model in res://art/models/props/cars/ is a choice. The preview is
# a real SubViewport with the real model turning in it rather than a
# rendered picture, so a car dropped in ten seconds ago shows up without
# anyone having to make art for it.
#
# The choice is a SETTING, not save data: it belongs to the person
# playing, the same as their camera and their keybindings, and it applies
# to every car in the game at once - the city, the arena and the rings.
# =========================================================

const PREVIEW_SIZE := Vector2(560, 320)
const PREVIEW_SPIN := 0.6          # radians per second
const CAR_LENGTH := 4.0            # metres, in preview space
const CAMERA_BACK := 7.4
const CAMERA_UP := 2.5

var _chosen := ""
var _passenger_label: Label
var _passenger_row: HBoxContainer
var _momentum: ProgressBar
var _turntable: Node3D
var _preview_host: SubViewport
var _name_label: Label
var _count_label: Label
var _pick_row: HBoxContainer


func screen_title() -> String:
	return "Garage"


func shows_weather() -> bool:
	return false


func build_content() -> void:
	_chosen = Cars.selected()

	var pool := Cars.list()
	if pool.is_empty():
		content.add_child(UI.heading("No cars yet"))
		content.add_child(UI.wrapped_caption(
			"Drop a .glb in res://art/models/props/cars/ and it shows up here. "
			+ "The filename becomes the name, and the model is measured and "
			+ "turned to face forwards on its own - nothing else to set up."))
		return

	content.add_child(_build_preview())

	_name_label = UI.title(Cars.display_name(_chosen))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_name_label)

	_count_label = UI.caption("")
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_count_label)

	var arrows := UI.hbox(Design.S3)
	arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	arrows.add_child(UI.button("◀", func(): _step(-1), Vector2(72, 52)))
	arrows.add_child(UI.button("▶", func(): _step(1), Vector2(72, 52)))
	content.add_child(arrows)

	content.add_child(UI.separator())
	content.add_child(_build_passenger())

	content.add_child(UI.separator())
	content.add_child(UI.section("EVERY CAR"))

	_pick_row = UI.hbox(Design.S2)
	_pick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var strip := UI.scroll()
	strip.custom_minimum_size = Vector2(0, 76)
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.add_child(_pick_row)
	content.add_child(strip)

	_refresh()


# --- The passenger -------------------------------------------------------
#
# One card rides with you. It gains Momentum, which the card game cannot
# produce at any rate by any means - the only way a card gets any is to
# have been in the car while someone drove.
#
# The seat is chosen here rather than in the collection because it is a
# fact about the CAR. You are deciding who comes along.
func _build_passenger() -> Control:
	var panel := UI.vbox(Design.S2)
	panel.add_child(UI.section("PASSENGER"))

	var riding := Passenger.card()

	_passenger_label = UI.label("", Design.FS_BODY, Design.TEXT)
	_passenger_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(_passenger_label)

	_momentum = ProgressBar.new()
	_momentum.max_value = Passenger.FULL
	_momentum.show_percentage = false
	_momentum.custom_minimum_size.y = 10
	panel.add_child(_momentum)

	panel.add_child(UI.wrapped_caption(
		"Momentum comes from driving, goals and rings — and from nowhere else "
		+ "in the game. It makes the card no stronger. A full card stops "
		+ "gaining, so filling one means choosing another."))

	var row := UI.hbox(Design.S2)
	row.add_child(UI.button("Choose…", _open_picker))
	if riding != null:
		row.add_child(UI.button("Empty the seat", func():
			Passenger.clear_seat()
			_refresh_passenger()))
	panel.add_child(row)

	_passenger_row = row
	_refresh_passenger()
	return panel


func _refresh_passenger() -> void:
	if _passenger_label == null:
		return
	var riding := Passenger.card()
	_passenger_label.text = Passenger.summary(riding)
	_momentum.value = Passenger.carried(riding)
	_momentum.modulate = Passenger.tint()


# Every owned card, so the choice is the whole collection rather than the
# battle team - a card you never field is exactly the sort of thing you
# might send out to see the world.
func _open_picker() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Who is coming along?"
	dialog.ok_button_text = "Close"

	var page := UI.scroll()
	page.custom_minimum_size = Vector2(520, 420)

	var list := UI.vbox(Design.S1)
	page.add_child(list)
	dialog.add_child(page)

	for card in GameState.collection.sorted("rarity"):
		var here := card
		var label := card.card_name
		if Passenger.is_full(here):
			label += "  ·  full"
		elif Passenger.carried(here) > 0.0:
			label += "  ·  " + Passenger.distance_text(Passenger.carried(here))

		var pick := UI.button(label, func():
			Passenger.seat(here.card_id)
			_refresh_passenger()
			dialog.queue_free())
		pick.disabled = Passenger.is_seated(here.card_id)
		list.add_child(pick)

	add_child(dialog)
	dialog.popup_centered()


# --- The preview ---------------------------------------------------------

func _build_preview() -> Control:
	var frame := UI.panel(Design.SURFACE_2, Design.S2)

	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = PREVIEW_SIZE
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.add_child(box)

	_preview_host = SubViewport.new()
	_preview_host.size = PREVIEW_SIZE
	_preview_host.transparent_bg = true
	# UPDATE_ALWAYS, or the turntable renders one frame and stops.
	_preview_host.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(_preview_host)

	var world := Node3D.new()
	_preview_host.add_child(world)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, CAMERA_UP, CAMERA_BACK)
	camera.look_at_from_position(
		Vector3(0.0, CAMERA_UP, CAMERA_BACK), Vector3(0.0, 0.6, 0.0), Vector3.UP)
	camera.fov = 42.0
	world.add_child(camera)

	# Lit from two sides so a dark car is not a silhouette.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -42.0, 0.0)
	key.light_energy = RenderMode.light(1.2)
	world.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 130.0, 0.0)
	fill.light_energy = RenderMode.light(0.55)
	fill.light_color = Color("#8fb6ff")
	world.add_child(fill)

	_turntable = Node3D.new()
	world.add_child(_turntable)

	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = CAR_LENGTH * 0.62
	disc.bottom_radius = CAR_LENGTH * 0.62
	disc.height = 0.08
	pad.mesh = disc
	pad.position.y = -0.04
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color("#1b2238")
	pad.material_override = pad_mat
	_turntable.add_child(pad)

	return frame


func _show_car(model_name: String) -> void:
	if _turntable == null:
		return

	for child in _turntable.get_children():
		if child.name == "Car":
			child.queue_free()

	var model := Cars.spawn(model_name)
	if model == null:
		return
	model.name = "Car"
	_turntable.add_child(model)
	Models.fit_length(model, CAR_LENGTH)


func _process(delta: float) -> void:
	if _turntable != null:
		_turntable.rotation.y += PREVIEW_SPIN * delta


# --- Choosing ------------------------------------------------------------

func _step(direction: int) -> void:
	_chosen = Cars.next(_chosen, direction)
	Audio.play("hover")
	_refresh()


func _pick(model_name: String) -> void:
	_chosen = model_name
	Audio.play("click")
	_refresh()


# The choice takes effect the moment it is made - there is no Confirm
# button, because there is nothing to confirm and nothing to lose.
func _refresh() -> void:
	Cars.select(_chosen)
	_show_car(_chosen)

	var pool := Cars.list()
	if _name_label != null:
		_name_label.text = Cars.display_name(_chosen)
	if _count_label != null:
		_count_label.text = "%d of %d  ·  drives in the city, the arena and the rings" % [
			pool.find(_chosen) + 1, pool.size()]

	if _pick_row == null:
		return
	clear(_pick_row)
	for model_name in pool:
		var here := model_name
		var button := UI.button(Cars.display_name(here), func(): _pick(here))
		button.disabled = here == _chosen
		_pick_row.add_child(button)
