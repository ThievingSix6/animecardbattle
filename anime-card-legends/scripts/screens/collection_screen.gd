extends Screen

var _grid: GridContainer
var _count: Label
var _sort_key := "rarity"


func screen_title() -> String: return "Collection"


func build_content() -> void:
	header_actions.add_child(UI.button("Team", func(): Routes.go(self, Routes.TEAM), Vector2(96, 44)))

	var toolbar := UI.hbox(Design.S3)

	var sorter := OptionButton.new()
	sorter.custom_minimum_size = Vector2(170, 40)
	for option in CollectionSystem.SORTS:
		sorter.add_item(option["label"])
	sorter.item_selected.connect(func(i: int):
		_sort_key = CollectionSystem.SORTS[i]["key"]
		_refresh()
	)
	toolbar.add_child(UI.caption("Sort"))
	toolbar.add_child(sorter)
	toolbar.add_child(UI.spacer())

	_count = UI.caption("")
	toolbar.add_child(_count)
	content.add_child(toolbar)

	var scroll := UI.scroll()
	_grid = UI.grid(5, Design.S3)
	scroll.add_child(_grid)
	content.add_child(scroll)

	EventBus.collection_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	super()
	unbind(EventBus.collection_changed, _refresh)


func _refresh() -> void:
	clear(_grid)

	var cards := GameState.collection.sorted(_sort_key)
	for card in cards:
		var view := CardView.create(card)
		view.pressed.connect(_inspect.bind(card))
		_grid.add_child(view)

	_count.text = "%s of %s discovered" % [
		Fmt.commas(cards.size()), Fmt.commas(GameState.gacha.total_pool_size())]


func _inspect(card: CardData) -> void:
	CardDetail.open(self, card).changed.connect(_refresh)
