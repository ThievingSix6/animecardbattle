class_name ThemeBuilder
extends RefCounted

# =========================================================
# Builds the application Theme from design tokens. Applied once at
# the tree root, so every default control inherits it. Replaces 218
# scattered add_theme_*_override() calls.
# =========================================================

static func panel_style(bg: Color, radius: int = Design.R_MD, pad: int = Design.S3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func bordered_style(bg: Color, border: Color, width: int, radius: int = Design.R_MD) -> StyleBoxFlat:
	var s := panel_style(bg, radius)
	s.set_border_width_all(width)
	s.border_color = border
	return s


static func aura_style(bg: Color, accent: Color, border_width: int, aura: int, radius: int = Design.R_LG) -> StyleBoxFlat:
	var s := bordered_style(bg, accent, border_width, radius)
	if aura > 0:
		s.shadow_color = Design.alpha(accent, 0.75)
		s.shadow_size = aura
	return s


# --- Fonts ---------------------------------------------------------
# Any .ttf/.otf dropped into res://art/fonts/ is picked up automatically.
# Files named "bold" are used for headings; anything else becomes body.

const FONT_FOLDER := "res://art/fonts/"


static func _find_fonts() -> Dictionary:
	var result := {"regular": null, "bold": null}

	var dir := DirAccess.open(FONT_FOLDER)
	if dir == null:
		return result

	var found: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower := file_name.to_lower()
			if lower.ends_with(".ttf") or lower.ends_with(".otf"):
				found.append(FONT_FOLDER + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	found.sort()

	for path in found:
		var font: FontFile = load(path)
		if font == null:
			continue
		if path.to_lower().contains("bold"):
			result["bold"] = font
		elif result["regular"] == null:
			result["regular"] = font

	# One font present -> use it for everything.
	if result["regular"] == null and result["bold"] != null:
		result["regular"] = result["bold"]
	if result["bold"] == null and result["regular"] != null:
		result["bold"] = result["regular"]

	return result


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = Design.FS_BODY

	var fonts := _find_fonts()
	if fonts["regular"] != null:
		t.default_font = fonts["regular"]
		var typed_names: Array[String] = ["Label", "Button", "RichTextLabel", "OptionButton", "LineEdit", "PopupMenu"]
		for type_name in typed_names:
			t.set_font("font", type_name, fonts["regular"])
		t.set_font("normal_font", "RichTextLabel", fonts["regular"])
	if fonts["bold"] != null:
		t.set_font("bold_font", "RichTextLabel", fonts["bold"])

	_build_button(t)
	_build_labels(t)
	_build_containers(t)
	_build_inputs(t)
	_build_bars(t)
	return t


static func _build_button(t: Theme) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Design.SURFACE_2
	normal.set_corner_radius_all(Design.R_MD)
	normal.content_margin_left = Design.S4
	normal.content_margin_right = Design.S4
	normal.content_margin_top = Design.S3
	normal.content_margin_bottom = Design.S3
	# A single lit top edge reads as depth without a boxy outline.
	normal.border_width_top = 1
	normal.border_color = Design.alpha(Color.WHITE, 0.07)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Design.SURFACE_3
	hover.border_color = Design.alpha(Design.ACCENT, 0.5)
	hover.shadow_color = Design.alpha(Design.ACCENT, 0.18)
	hover.shadow_size = 6

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Design.ACCENT
	pressed.border_color = Design.alpha(Color.WHITE, 0.25)

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Design.alpha(Design.SURFACE, 0.55)
	disabled.border_color = Design.alpha(Color.WHITE, 0.03)

	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)

	t.set_color("font_color", "Button", Design.TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Design.TEXT_INVERT)
	t.set_color("font_disabled_color", "Button", Design.TEXT_MUTED)
	t.set_font_size("font_size", "Button", Design.FS_BODY)


static func _build_labels(t: Theme) -> void:
	t.set_color("font_color", "Label", Design.TEXT)
	t.set_font_size("font_size", "Label", Design.FS_BODY)
	t.set_color("default_color", "RichTextLabel", Design.TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", Design.FS_SMALL)


static func _build_containers(t: Theme) -> void:
	var surface := panel_style(Design.SURFACE)
	surface.shadow_color = Design.alpha(Color.BLACK, 0.35)
	surface.shadow_size = 5
	surface.shadow_offset = Vector2(0, 2)
	surface.border_width_top = 1
	surface.border_color = Design.alpha(Color.WHITE, 0.05)
	t.set_stylebox("panel", "PanelContainer", surface)
	t.set_stylebox("panel", "Panel", surface)

	var sep := StyleBoxFlat.new()
	sep.bg_color = Design.alpha(Color.WHITE, 0.07)
	sep.content_margin_top = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", Design.S3)


static func _build_inputs(t: Theme) -> void:
	var normal := bordered_style(Design.SURFACE_2, Design.HAIRLINE, 1, Design.R_SM)
	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", bordered_style(Design.SURFACE_3, Design.ACCENT, 1, Design.R_SM))
	t.set_stylebox("pressed", "OptionButton", normal)
	t.set_stylebox("focus", "OptionButton", normal)
	t.set_color("font_color", "OptionButton", Design.TEXT)

	t.set_stylebox("normal", "LineEdit", normal)
	t.set_color("font_color", "LineEdit", Design.TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Design.TEXT_MUTED)

	t.set_stylebox("panel", "PopupMenu", panel_style(Design.SURFACE_2, Design.R_SM, Design.S2))
	t.set_color("font_color", "PopupMenu", Design.TEXT)


static func _build_bars(t: Theme) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Design.SURFACE_3
	bg.set_corner_radius_all(Design.R_SM)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Design.ACCENT
	fill.set_corner_radius_all(Design.R_SM)

	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_font_size("font_size", "ProgressBar", Design.FS_MICRO)
