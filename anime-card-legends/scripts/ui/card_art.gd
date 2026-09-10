class_name CardArt
extends RefCounted

# =========================================================
# Resolves artwork for a card.
#
# Drop images into res://art/cards/ and every card is assigned one
# deterministically (the same card always shows the same art). To pin
# a specific image to a specific card, name the file after the card:
# "Ashen Knight, the Unbroken" -> ashen_knight_the_unbroken.png
# =========================================================

const FOLDER := "res://art/cards/"
const EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]

static var _files: Array[String] = []
static var _scanned := false
static var _cache: Dictionary = {}


static func scan() -> void:
	_scanned = true
	_files.clear()

	var dir := DirAccess.open(FOLDER)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower := file_name.to_lower()
			for ext in EXTENSIONS:
				if lower.ends_with("." + ext):
					_files.append(FOLDER + file_name)
					break
		file_name = dir.get_next()
	dir.list_dir_end()
	_files.sort()


static func list_files() -> Array[String]:
	if not _scanned:
		scan()
	return _files.duplicate()


static func has_custom_art() -> bool:
	if not _scanned:
		scan()
	return not _files.is_empty()


static func slug(text: String) -> String:
	var s := text.to_lower().strip_edges()
	var punctuation: Array[String] = [",", "'", ".", ":", "!", "?"]
	for ch in punctuation:
		s = s.replace(ch, "")
	return s.replace(" ", "_")


static func for_card(card: CardData) -> Texture2D:
	if not _scanned:
		scan()

	if _cache.has(card.card_id):
		return _cache[card.card_id]

	var texture := _resolve(card)
	_cache[card.card_id] = texture
	return texture


static func _resolve(card: CardData) -> Texture2D:
	# 1. Explicit filename match wins.
	var candidates: Array[String] = [slug(card.card_name), card.card_id]
	for candidate in candidates:
		for ext in EXTENSIONS:
			var path: String = FOLDER + candidate + "." + ext
			if ResourceLoader.exists(path):
				return load(path)

	# 2. Otherwise assign deterministically from the pool.
	if not _files.is_empty():
		var index: int = abs(hash(card.card_id)) % _files.size()
		return load(_files[index])

	# 3. No art supplied: the card frame renders on its own.
	return null


# With no artwork the frame is bare, so tint it by element to keep cards
# visually distinguishable.
static func tint_for(card: CardData) -> Color:
	if has_custom_art():
		return Color.WHITE
	return Design.element_color(card.element).lerp(Color.WHITE, 0.35)
