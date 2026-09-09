extends Screen

var _ticker: Label

const MENU: Array[Dictionary] = [
	{"label": "Play",       "icon": "⚔️", "route": "battle"},
	{"label": "Lobby",      "icon": "🏛️", "route": Routes.LOBBY},
	{"label": "Collection", "icon": "🎴", "route": Routes.COLLECT},
	{"label": "Summon",     "icon": "🔮", "route": Routes.PACKS},
	{"label": "Team",       "icon": "🛡️", "route": Routes.TEAM},
	{"label": "Character",  "icon": "💍", "route": Routes.CHARACTER},
	{"label": "Talents",    "icon": "⭐", "route": Routes.TALENTS},
	{"label": "Tower",      "icon": "🗼", "route": Routes.TOWER},
]


func screen_title() -> String: return "Anime Card Legends"
func back_route() -> String: return ""


func build_content() -> void:
	Audio.play_music("music_menu")

	header_actions.add_child(UI.button("Profiles", _switch_profile, Vector2(110, 44)))

	var hero := UI.vbox(Design.S1)
	hero.add_child(UI.body("Collect, build a team, and climb the tower."))
	_ticker = UI.label("", Design.FS_SMALL, Design.ACCENT)
	hero.add_child(_ticker)
	content.add_child(hero)

	content.add_child(UI.separator())

	var grid := UI.grid(4, Design.S3)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for entry in MENU:
		grid.add_child(_build_tile(entry))
	content.add_child(grid)

	EventBus.auto_rolled.connect(_on_rolled)
	_refresh_ticker()


func _exit_tree() -> void:
	super()
	unbind(EventBus.auto_rolled, _on_rolled)


func _build_tile(entry: Dictionary) -> Button:
	var route: String = entry["route"]
	var tile := UI.button("", func(): _navigate(route), Vector2(0, 108))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var body := UI.vbox(Design.S1)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_text: String = entry["icon"]
	var label_text: String = entry["label"]
	body.add_child(UI.label(icon_text, Design.FS_TITLE, Design.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UI.label(label_text, Design.FS_BODY, Design.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	tile.add_child(body)
	return tile


func _switch_profile() -> void:
	GameState.close_slot()
	Routes.go(self, Routes.SLOTS)


func _navigate(route: String) -> void:
	if route == "battle":
		GameState.progression.pending_floor = GameState.progression.highest_floor + 1
		Routes.go(self, Routes.BATTLE)
	else:
		Routes.go(self, route)


func _refresh_ticker() -> void:
	var p: ProgressionSystem = GameState.progression
	var plural := "s"
	if p.rolls_per_tick() == 1:
		plural = ""
	_ticker.text = "🎲 Auto-rolling %d card%s every %ss" % [p.rolls_per_tick(), plural, String.num(p.roll_interval(), 1)]


func _on_rolled(cards: Array) -> void:
	var best: CardData = cards[0]
	for c in cards:
		if Config.rarity_index(c.rarity) > Config.rarity_index(best.rarity):
			best = c
	_ticker.text = "🎲 Just rolled: %s — %s" % [best.card_name, best.rarity]
