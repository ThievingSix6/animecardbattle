extends Screen

var _rows := {}
var _packs := {}
var _status: Label
var _feed: RichTextLabel

const TALENT_META := {
	"speed": {"label": "Roll Speed", "icon": "⏱️", "desc": "Cards roll in faster."},
	"luck":  {"label": "Luck",       "icon": "🍀", "desc": "Better odds on every roll."},
	"multi": {"label": "Multi-Roll", "icon": "🎲", "desc": "Roll more cards at once."},
}


func screen_title() -> String: return "Talents"
# This screen scrolls its own list region, so the base page scroll
# would just nest one scroll inside another.
func scrolls_content() -> bool: return false



func build_content() -> void:
	var scroll := UI.scroll()
	var body := UI.vbox(Design.S4)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	content.add_child(scroll)

	body.add_child(_build_status())
	body.add_child(UI.section("Talent tree"))
	var talent_ids: Array[String] = ["speed", "luck", "multi"]
	for talent in talent_ids:
		body.add_child(_build_talent(talent))

	body.add_child(UI.section("Roll packs"))
	body.add_child(UI.caption("Earned from boss floors. Each resolves its rolls instantly."))
	for pack_id in Config.ROLL_PACKS.keys():
		body.add_child(_build_pack(pack_id))

	EventBus.auto_rolled.connect(_on_rolled)
	EventBus.talent_upgraded.connect(_on_upgraded)
	_refresh()


func _exit_tree() -> void:
	super()
	unbind(EventBus.auto_rolled, _on_rolled)
	unbind(EventBus.talent_upgraded, _on_upgraded)


func _build_status() -> Control:
	var panel := UI.accent_panel(Design.ACCENT, Design.S4)
	var body := UI.vbox(Design.S2)

	body.add_child(UI.label("🎲 Rolling in the background", Design.FS_HEADING, Design.ACCENT))
	_status = UI.body("")
	body.add_child(_status)

	body.add_child(UI.caption("Recent pulls"))
	_feed = RichTextLabel.new()
	_feed.bbcode_enabled = true
	_feed.scroll_following = true
	_feed.fit_content = false
	_feed.custom_minimum_size = Vector2(0, 76)
	body.add_child(_feed)

	panel.add_child(body)
	return panel


func _build_talent(talent: String) -> Control:
	var meta: Dictionary = TALENT_META[talent]
	var panel := UI.panel(Design.SURFACE, Design.S3)
	var row := UI.hbox(Design.S3)

	row.add_child(UI.label(meta["icon"], Design.FS_TITLE))

	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(meta["label"], Design.FS_HEADING, Design.TEXT))
	var detail := UI.caption("")
	info.add_child(detail)
	row.add_child(info)

	var action := UI.button("", func(): GameState.upgrade_talent(talent), Vector2(160, 48))
	row.add_child(action)

	panel.add_child(row)
	_rows[talent] = {"detail": detail, "button": action}
	return panel


func _build_pack(pack_id: String) -> Control:
	var meta: Dictionary = Config.ROLL_PACKS[pack_id]
	var panel := UI.panel(Design.SURFACE, Design.S3)
	var row := UI.hbox(Design.S3)

	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label("🎁 " + meta["label"], Design.FS_HEADING, Design.TEXT))
	info.add_child(UI.caption(Fmt.commas(meta["rolls"]) + " rolls, resolved instantly"))
	row.add_child(info)

	var count := UI.label("", Design.FS_HEADING, Design.ACCENT)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count)

	var use := UI.button("Use", func(): _use_pack(pack_id), Vector2(96, 48))
	row.add_child(use)

	panel.add_child(row)
	_packs[pack_id] = {"count": count, "button": use}
	return panel


func _refresh() -> void:
	var p: ProgressionSystem = GameState.progression
	var plural := "s"
	if p.rolls_per_tick() == 1:
		plural = ""
	var weather_note := ""
	if GameState.weather.is_active():
		weather_note = "  (2× from weather)"
	_status.text = "%d card%s every %ss  ·  +%s luck%s" % [
		p.rolls_per_tick(), plural, String.num(p.roll_interval(), 1),
		Fmt.percent(GameState.effective_luck()), weather_note,
	]

	for talent in _rows.keys():
		_rows[talent]["detail"].text = "%s   ·   Lv %d/%d" % [
			p.talent_effect_text(talent), p.talents[talent], Config.TALENT_MAX[talent]]
		var button: Button = _rows[talent]["button"]
		if p.is_maxed(talent):
			button.text = "Maxed"
			button.disabled = true
		else:
			button.text = "Upgrade\n🪙 " + Fmt.compact(p.cost(talent))
			button.disabled = false

	for pack_id in _packs.keys():
		var owned: int = p.pack_count(pack_id)
		_packs[pack_id]["count"].text = "×" + str(owned)
		_packs[pack_id]["button"].disabled = owned <= 0


func _use_pack(pack_id: String) -> void:
	var summary := GameState.use_roll_pack(pack_id)
	_refresh()
	if summary.is_empty():
		EventBus.toast("You don't have that pack.", "error")
		return

	var lines := []
	for rarity in Config.RARITY_ORDER:
		if not summary.has(rarity) or summary[rarity]["copies"] <= 0:
			continue
		var entry: Dictionary = summary[rarity]
		lines.append("%s: %s pulled (%d new)" % [
			rarity, Fmt.compact(entry["copies"]), entry["new_unique"]])

	var dialog := AcceptDialog.new()
	dialog.title = Config.ROLL_PACKS[pack_id]["label"]
	dialog.dialog_text = "\n".join(lines)
	add_child(dialog)
	dialog.popup_centered()


func _on_rolled(cards: Array) -> void:
	for card in cards:
		var color := Design.rarity_color(card.rarity).to_html(false)
		_feed.append_text("\n[color=#%s]%s — %s[/color]" % [color, card.card_name, card.rarity])
	_refresh()


func _on_upgraded(_talent: String, _level: int) -> void:
	_refresh()
