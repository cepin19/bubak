class_name UI
## Theme and small widget helpers shared by all screens.

const INK := Color("#4f3d33")
const CREAM := Color("#fff8ef")
const PEACH := Color("#ffe6c4")
const PEACH_HOVER := Color("#ffdaa8")
const PEACH_DOWN := Color("#f6c483")
const PINK := Color("#f08a9c")
const GOLD := Color("#f3cf7a")
const RED := Color("#c0392b")
const GREEN := Color("#7fcfb8")
const NEED_COLORS := {"food": Color("#f4a259"), "water": Color("#62c3ea"),
	"fun": Color("#e2c04f"), "clean": Color("#7fcfb8"), "energy": Color("#a99be0")}


static func box(bg: Color, radius := 22, border := 3, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = INK
	s.set_content_margin_all(12)
	s.anti_aliasing = true
	if shadow:
		s.shadow_color = Color(0.31, 0.2, 0.14, 0.18)
		s.shadow_size = 5
		s.shadow_offset = Vector2(0, 4)
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Fredoka.ttf")
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 560}
	t.default_font = f
	t.default_font_size = 22
	t.set_color("font_color", "Label", INK)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.45))
	t.set_stylebox("panel", "PanelContainer", box(CREAM))
	t.set_stylebox("panel", "Panel", box(CREAM))
	var normal := box(PEACH, 18, 3, false)
	normal.shadow_color = Color(0.31, 0.2, 0.14, 0.25)
	normal.shadow_size = 1
	normal.shadow_offset = Vector2(0, 4)
	t.set_stylebox("normal", "Button", normal)
	var hover := normal.duplicate()
	hover.bg_color = PEACH_HOVER
	t.set_stylebox("hover", "Button", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = PEACH_DOWN
	pressed.shadow_offset = Vector2(0, 1)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	var disabled := normal.duplicate()
	disabled.bg_color = Color("#efe4d6")
	disabled.border_color = Color(INK, 0.4)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("icon_max_width", "Button", 48)
	var bar_bg := box(Color("#efe2d0"), 8, 2, false)
	bar_bg.set_content_margin_all(0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill(PINK))
	var edit := box(Color.WHITE, 14, 3, false)
	edit.content_margin_left = 14
	# chunky scroll bars that a finger can grab
	var track := box(Color(INK, 0.08), 8, 0, false)
	track.set_content_margin_all(0)
	track.content_margin_left = 14
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll_focus", "VScrollBar", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var g := box(Color("#d9a07a") if state == "grabber" else Color("#c98a62"), 8, 0, false)
		g.set_content_margin_all(0)
		g.content_margin_left = 14
		t.set_stylebox(state, "VScrollBar", g)
	t.set_stylebox("normal", "LineEdit", edit)
	var edit_focus := edit.duplicate()
	edit_focus.border_color = PINK
	t.set_stylebox("focus", "LineEdit", edit_focus)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(INK, 0.45))
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("selection_color", "LineEdit", Color(PINK, 0.35))
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("h_separation", "GridContainer", 12)
	t.set_constant("v_separation", "GridContainer", 12)
	return t


static func label(text: String, size := 22, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, size := 18, width := 200.0) -> Label:
	var l := label(text, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func icon_rect(name: String, size := 40.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Catalog.icon(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A chunky square button with an icon above a caption, sized for thumbs.
## Buttons squish a little when pressed and bounce back.
static func bouncy(b: BaseButton) -> void:
	b.button_down.connect(func():
		Sfx.play("tap")
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2(0.92, 0.92), 0.06))
	b.button_up.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## Progress-bar fill with a light, shiny top edge.
static func bar_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(8)
	s.border_width_top = 3
	s.border_color = color.lightened(0.45)
	s.anti_aliasing = true
	return s


static func big_button(icon_name: String, caption: String, size := 92.0) -> Button:
	var b := Button.new()
	b.icon = Catalog.icon(icon_name)
	b.text = caption
	b.expand_icon = true
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(size, size)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_constant_override("icon_max_width", int(size * 0.5))
	b.focus_mode = Control.FOCUS_NONE
	bouncy(b)
	return b


static func text_button(text: String, icon_name := "", font_size := 22) -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = Catalog.icon(icon_name)
		b.add_theme_constant_override("icon_max_width", 30)
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	bouncy(b)
	return b


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func pop_in(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(0.85, 0.85)
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel()
	t.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 1.0, 0.15)
