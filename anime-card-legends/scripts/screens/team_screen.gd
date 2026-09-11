extends Screen

var _slots: HBoxContainer
var _grid: GridContainer
var _status: Label
var _outnumbered: Label
var _team: Array[String] = []


func screen_title() -> String: return "Team"
# This screen scrolls its own list region, so the base page scroll
# would just nest one scroll inside another.
func scrolls_content() -> bool: return false



func build_content() -> void:
	_team = GameState.collection.team_ids.duplicate()

	header_actions.add_child(UI.primary_button("Save", _save, Vector2(110, 44)))

	var header := UI.hbox(Design.S3)
	header.add_child(UI.heading("Lineup"))
	_status = UI.caption("")
	header.add_child(_status)
	content.add_child(header)

	content.add_child(UI.caption("Slot 1 fights first. Tap a card below to add or remove it."))

	_slots = UI.hbox(Design.S3)
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(_slots)

	# Updates live as cards come out, so the bonus is visible while you
	# are deciding rather than discovered after the fight starts.
	_outnumbered = UI.label("", Design.FS_SMALL, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_outnumbered.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(_outnumbered)

	content.add_child(UI.separator())
	content.add_child(UI.section("Your cards"))

	var scroll := UI.scroll()
	_grid = UI.grid(6, Design.S5)
	scroll.add_child(_grid)
	content.add_child(scroll)

	_refresh()


func _refresh() -> void:
	_refresh_slots()
	_refresh_grid()
	# Named, not counted. "Trio" is a build; "3 / 5" is a mistake you
	# have not finished making yet, and the whole point of Outnumbered is
	# that bringing fewer cards is a decision.
	_status.text = "%s — %d / %d" % [
		Outnumbered.lineup_name(_team.size()), _team.size(), CollectionSystem.TEAM_SIZE]
	if _outnumbered != null:
		_outnumbered.text = Outnumbered.summary(_team.size())
		_outnumbered.add_theme_color_override("font_color",
			Design.ACCENT if Outnumbered.is_active(_team.size()) else Design.TEXT_MUTED)


func _refresh_slots() -> void:
	clear(_slots)
	for i in CollectionSystem.TEAM_SIZE:
		if i < _team.size() and GameState.collection.has(_team[i]):
			var card: CardData = GameState.collection.owned[_team[i]]
			var view := CardView.create(card)
			view.pressed.connect(func():
				_team.erase(card.card_id)
				_refresh()
			)
			_slots.add_child(view)
		else:
			_slots.add_child(_empty_slot(i + 1))


func _empty_slot(number: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(Design.CARD_W, Design.CARD_H)
	slot.add_theme_stylebox_override("panel",
		ThemeBuilder.bordered_style(Design.alpha(Design.SURFACE, 0.5), Design.HAIRLINE, 2, Design.R_LG))

	var body := UI.vbox(Design.S2)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(UI.label("＋", Design.FS_DISPLAY, Design.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UI.caption("Slot " + str(number)))
	if Outnumbered.is_active(_team.size()):
		var mark := UI.label("OUTNUMBERED", Design.FS_SMALL, Design.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		body.add_child(mark)
	slot.add_child(body)
	return slot


func _refresh_grid() -> void:
	clear(_grid)
	for card in GameState.collection.sorted("rarity"):
		var view := CardView.create(card, true)
		view.selected = _team.has(card.card_id)
		view.pressed.connect(_toggle.bind(card.card_id))
		_grid.add_child(view)


func _toggle(card_id: String) -> void:
	if _team.has(card_id):
		_team.erase(card_id)
	elif _team.size() >= CollectionSystem.TEAM_SIZE:
		EventBus.toast("Your lineup is full — remove a card first.", "error")
		return
	else:
		_team.append(card_id)
	_refresh()


# Removing the last card is not allowed, but removing the other four is.
# The empty-slot placeholder says so, so an empty slot reads as a choice
# rather than as something still to be filled in.


func _save() -> void:
	if _team.is_empty():
		EventBus.toast("Add at least one card before saving.", "error")
		return
	GameState.collection.set_team(_team)
	GameState.save_now()
	EventBus.toast("Team saved.", "success")
