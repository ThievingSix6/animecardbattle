class_name UI
extends RefCounted

# =========================================================
# WIDGET FACTORY - declarative helpers so screens describe what they
# want, not how to configure it. Replaces raw Label.new() + four
# theme override calls repeated 75 times across the codebase.
# =========================================================

static func label(text: String, size: int = Design.FS_BODY, color: Color = Design.TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	return l


static func display(text: String) -> Label:
	return label(text, Design.FS_DISPLAY, Design.TEXT)

static func title(text: String) -> Label:
	return label(text, Design.FS_TITLE, Design.TEXT)

static func heading(text: String) -> Label:
	return label(text, Design.FS_HEADING, Design.ACCENT)

static func body(text: String) -> Label:
	return label(text, Design.FS_BODY, Design.TEXT_DIM)

static func caption(text: String) -> Label:
	return label(text, Design.FS_SMALL, Design.TEXT_MUTED)


# A caption that wraps rather than running off the edge. For anything
# whose length is not known in advance - a list of filenames, a report
# line, a sentence built at runtime.
static func wrapped_caption(text: String) -> Label:
	var l := caption(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# Small-caps section header with letter spacing - a cheap, high-impact
# typography trick that stops headings looking like ordinary body text.
static func section(text: String) -> Label:
	var spaced := ""
	for i in text.length():
		spaced += text[i]
		if i < text.length() - 1:
			spaced += " "
	var l := label(spaced.to_upper(), Design.FS_MICRO, Design.TEXT_MUTED)
	l.add_theme_constant_override("line_spacing", 2)
	return l


static func button(text: String, on_press: Callable = Callable(), min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	if min_size != Vector2.ZERO:
		b.custom_minimum_size = min_size
	if on_press.is_valid():
		b.pressed.connect(on_press)
	# Every button gets feedback without each caller wiring it up.
	b.pressed.connect(func(): Audio.play("click"))
	b.mouse_entered.connect(func(): Audio.play("hover"))
	return b


static func primary_button(text: String, on_press: Callable = Callable(), min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := button(text, on_press, min_size)
	var style := ThemeBuilder.bordered_style(Design.ACCENT_SOFT, Design.ACCENT, 2)
	style.content_margin_left = Design.S4
	style.content_margin_right = Design.S4
	style.content_margin_top = Design.S3
	style.content_margin_bottom = Design.S3
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = Design.ACCENT
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", style)
	b.add_theme_color_override("font_hover_color", Design.TEXT_INVERT)
	return b


static func vbox(gap: int = Design.S3) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	return v


static func hbox(gap: int = Design.S3) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	return h


static func grid(columns: int, gap: int = Design.S3) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", gap)
	g.add_theme_constant_override("v_separation", gap)
	return g


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


static func panel(bg: Color = Design.SURFACE, pad: int = Design.S4, radius: int = Design.R_MD) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.panel_style(bg, radius, pad))
	return p


static func accent_panel(accent: Color = Design.ACCENT, pad: int = Design.S4) -> PanelContainer:
	var p := PanelContainer.new()
	var style := ThemeBuilder.bordered_style(Design.SURFACE, accent, 1, Design.R_MD)
	style.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", style)
	return p


static func pill(text: String, color: Color = Design.TEXT_DIM, bg: Color = Design.SURFACE_3) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style := ThemeBuilder.panel_style(bg, 999, Design.S1)
	style.content_margin_left = Design.S2
	style.content_margin_right = Design.S2
	p.add_theme_stylebox_override("panel", style)
	p.add_child(label(text, Design.FS_MICRO, color))
	return p


static func badge(text: String, bg: Color, fg: Color = Design.TEXT_INVERT, size: int = 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(int(size / 2.0))
	p.add_theme_stylebox_override("panel", style)
	var l := label(text, Design.FS_MICRO, fg, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


# A labelled value column, e.g. ATK / 128
static func stat_block(name: String, value: String, color: Color) -> VBoxContainer:
	var col := vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := label(value, Design.FS_HEADING, color, HORIZONTAL_ALIGNMENT_CENTER)
	var n := label(name, Design.FS_MICRO, Design.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(v)
	col.add_child(n)
	return col


static func separator() -> HSeparator:
	return HSeparator.new()


static func margin(all: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", all)
	m.add_theme_constant_override("margin_right", all)
	m.add_theme_constant_override("margin_top", all)
	m.add_theme_constant_override("margin_bottom", all)
	return m


static func make_ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		make_ignore_mouse(child)
