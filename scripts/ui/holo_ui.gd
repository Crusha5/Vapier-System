class_name HoloUI
extends RefCounted
## Hologramm-Oberfläche: Farben, Schriften, Theme und Bausteine.

const CYAN := Color(0.28, 0.92, 1.0)
const CYAN_DIM := Color(0.28, 0.92, 1.0, 0.35)
const RED := Color(1.0, 0.16, 0.26)
const RED_DIM := Color(1.0, 0.16, 0.26, 0.4)
const GOLD := Color(1.0, 0.8, 0.32)
const PURPLE := Color(0.78, 0.45, 1.0)
const TEAL := Color(0.3, 1.0, 0.78)
const FG := Color(0.9, 0.94, 0.98)
const MUTED := Color(0.55, 0.62, 0.7)
const PANEL := Color(0.02, 0.04, 0.07, 0.86)

const F_REG := preload("res://fonts/ChakraPetch-Regular.ttf")
const F_SEMI := preload("res://fonts/ChakraPetch-SemiBold.ttf")
const F_BOLD := preload("res://fonts/ChakraPetch-Bold.ttf")
const F_MONO := preload("res://fonts/IBMPlexMono-Medium.ttf")

static func box(bg: Color, border: Color, bw := 1, radius := 3, pad := Vector2(12, 8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	s.anti_aliasing = true
	return s

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = F_SEMI
	t.default_font_size = 15
	var normal := box(Color(0.28, 0.92, 1.0, 0.06), CYAN_DIM)
	var pressed := box(Color(0.28, 0.92, 1.0, 0.28), CYAN)
	var disabled := box(Color(0.02, 0.04, 0.07, 0.5), Color(1, 1, 1, 0.08))
	for st in [["normal", normal], ["hover", normal], ["pressed", pressed], ["disabled", disabled], ["hover_pressed", pressed]]:
		t.set_stylebox(st[0], "Button", st[1])
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color"]:
		t.set_color(c, "Button", CYAN)
	t.set_color("font_pressed_color", "Button", FG)
	t.set_color("font_hover_pressed_color", "Button", FG)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.62, 0.7, 0.5))
	t.set_font_size("font_size", "Button", 14)
	t.set_type_variation("BtnRed", "Button")
	var rn := box(Color(1.0, 0.16, 0.26, 0.12), RED_DIM)
	var rp := box(Color(1.0, 0.16, 0.26, 0.35), RED)
	for st in [["normal", rn], ["hover", rn], ["pressed", rp], ["hover_pressed", rp]]:
		t.set_stylebox(st[0], "BtnRed", st[1])
	t.set_color("font_color", "BtnRed", Color(1.0, 0.5, 0.55))
	t.set_color("font_hover_color", "BtnRed", Color(1.0, 0.5, 0.55))
	t.set_type_variation("Tab", "Button")
	var tn := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, Vector2(10, 6))
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		t.set_stylebox(st, "Tab", tn)
	t.set_color("font_color", "Tab", MUTED)
	t.set_color("font_hover_color", "Tab", MUTED)
	t.set_type_variation("TabOn", "Button")
	var ton := box(Color(0.28, 0.92, 1.0, 0.1), Color(0, 0, 0, 0), 0, 0, Vector2(10, 6))
	ton.border_width_bottom = 2
	ton.border_color = CYAN
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		t.set_stylebox(st, "TabOn", ton)
	t.set_color("font_color", "TabOn", CYAN)
	t.set_color("font_hover_color", "TabOn", CYAN)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box(Color(0.28, 0.92, 1.0, 0.035), Color(0.28, 0.92, 1.0, 0.16), 1, 2, Vector2(10, 7)))
	t.set_type_variation("CardOn", "PanelContainer")
	t.set_stylebox("panel", "CardOn", box(Color(1.0, 0.16, 0.26, 0.07), RED_DIM, 1, 2, Vector2(10, 7)))
	t.set_type_variation("CardDim", "PanelContainer")
	t.set_stylebox("panel", "CardDim", box(Color(1, 1, 1, 0.015), Color(1, 1, 1, 0.06), 1, 2, Vector2(10, 7)))
	t.set_stylebox("panel", "PanelContainer", box(Color(0.015, 0.035, 0.06, 0.93), CYAN_DIM, 1, 4, Vector2(16, 12)))
	t.set_color("font_color", "Label", FG)
	var grab := box(Color(0.28, 0.92, 1.0, 0.35), Color(0, 0, 0, 0), 0, 3, Vector2(2, 2))
	var track := box(Color(1, 1, 1, 0.03), Color(0, 0, 0, 0), 0, 3, Vector2(2, 2))
	for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(st, "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", track)
	return t

static func lbl(text: String, size := 14, color := FG, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func caps(text: String, color := MUTED, size := 11) -> Label:
	return lbl(text.to_upper(), size, color, F_SEMI)

static func wrap(text: String, size := 13, color := MUTED) -> Label:
	var l := lbl(text, size, color, F_REG)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func btn(text: String, cb: Callable, variation := "", disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if variation != "":
		b.theme_type_variation = variation
	b.disabled = disabled
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(func():
		if cb.is_valid() and TouchScroll.tap_ok():
			cb.call())
	return b

static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func card(variation := "Card") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p

static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

class Bar extends Control:
	var frac := 0.0
	var color := Color.WHITE
	func _init(w := 90.0, h := 6.0) -> void:
		custom_minimum_size = Vector2(w, h)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_value(f: float, c: Color) -> void:
		frac = clampf(f, 0.0, 1.0)
		color = c
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.07))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), color)
