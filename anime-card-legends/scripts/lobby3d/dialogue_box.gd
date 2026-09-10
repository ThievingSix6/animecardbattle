class_name DialogueBox
extends CanvasLayer

# =========================================================
# What an NPC says, and what you can say back.
#
# Pauses the world underneath, the same way the travel menu does, so
# the player is not still walking while somebody is talking to them.
#
#   DialogueBox.open(self, "Diablo", "Lord of Hatred", line, tint)
#       .option("Start the gauntlet", callable)
#       .option("Not yet", Callable())
# =========================================================

signal closed

var speaker := ""
var speaker_title := ""
var line := ""
var tint := Color("#f5a623")

var _options: Array[Dictionary] = []
var _built := false


static func open(host: Node, who: String, title: String, text: String, accent: Color) -> DialogueBox:
	var box := DialogueBox.new()
	box.speaker = who
	box.speaker_title = title
	box.line = text
	box.tint = accent
	host.add_child(box)
	return box


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


# Chainable, and callable before or after the box enters the tree - the
# panel is not built until the first frame.
func option(label: String, on_choose: Callable) -> DialogueBox:
	_options.append({"label": label, "action": on_choose})
	return self


func _ready() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Deferred so every option() added in the same statement is included.
	call_deferred("_build")


func _build() -> void:
	if _built:
		return
	_built = true

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Design.OVERLAY
	add_child(scrim)

	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(anchor)

	# Sits low on the screen, the way a conversation should - the NPC
	# stays visible above it.
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -340
	holder.offset_bottom = -Design.S6
	anchor.add_child(holder)

	var panel := UI.accent_panel(tint, Design.S5)
	panel.custom_minimum_size = Vector2(680, 0)
	holder.add_child(panel)

	var body := UI.vbox(Design.S3)
	panel.add_child(body)

	var header := UI.hbox(Design.S2)
	header.add_child(UI.label(speaker, Design.FS_TITLE, tint))
	if speaker_title != "":
		header.add_child(UI.pill(speaker_title, tint))
	header.add_child(UI.spacer())
	header.add_child(UI.button("✕", close, Vector2(40, 40)))
	body.add_child(header)

	var text := UI.label(line, Design.FS_HEADING, Design.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(0, 90)
	body.add_child(text)

	var actions := UI.hbox(Design.S3)
	actions.alignment = BoxContainer.ALIGNMENT_END

	for i in _options.size():
		var entry: Dictionary = _options[i]
		var action: Callable = entry["action"]
		var handler := func(): _choose(action)

		# The last option is the affirmative one, so it reads as primary.
		if i == _options.size() - 1:
			actions.add_child(UI.primary_button(str(entry["label"]), handler, Vector2(0, 46)))
		else:
			actions.add_child(UI.button(str(entry["label"]), handler, Vector2(0, 46)))

	if _options.is_empty():
		actions.add_child(UI.primary_button("Right.", close, Vector2(140, 46)))

	body.add_child(actions)


# Unpauses before running the choice: an option that changes scene must
# not leave the next one frozen.
func _choose(action: Callable) -> void:
	get_tree().paused = false
	closed.emit()
	if action.is_valid():
		action.call()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
