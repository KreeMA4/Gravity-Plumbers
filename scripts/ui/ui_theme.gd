class_name UITheme
extends RefCounted
## Builds the game's chunky, rounded, high-contrast UI theme in code.
## Uses Godot's built-in default font with thick outlines (no downloads).
## Also holds the shared UI colours and a few helper constructors so every
## screen looks the same.

const C_BG: Color = Color(0.09, 0.1, 0.2, 0.92)
const C_PANEL: Color = Color(0.16, 0.19, 0.36, 0.95)
const C_BUTTON: Color = Color(0.2, 0.62, 0.72)
const C_BUTTON_HOVER: Color = Color(0.27, 0.74, 0.84)
const C_BUTTON_PRESSED: Color = Color(0.13, 0.45, 0.55)
const C_ACCENT: Color = Color(1.0, 0.82, 0.2)       # switches / highlights (yellow)
const C_PIPE: Color = Color(1.0, 0.55, 0.2)         # warm orange
const C_TEAL: Color = Color(0.15, 0.75, 0.75)
const C_SLUDGE: Color = Color(0.6, 1.0, 0.25)       # glowing lime
const C_SLUDGE_DARK: Color = Color(0.55, 0.2, 0.75) # purple
const C_LEAK: Color = Color(1.0, 0.3, 0.6)          # hot pink
const C_DANGER: Color = Color(1.0, 0.3, 0.25)
const C_GOOD: Color = Color(0.4, 0.95, 0.45)
const C_TEXT: Color = Color(1, 1, 1)
const C_OUTLINE: Color = Color(0.04, 0.04, 0.1)

const FONT_SIZE: int = 34
const FONT_SIZE_BIG: int = 64
const FONT_SIZE_SMALL: int = 26
const MIN_TOUCH: float = 150.0   # px at 1080p, comfortably over 56dp on phones

static var _theme: Theme = null


static func clear_cache() -> void:
	_theme = null


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font_size = FONT_SIZE
	for cls: String in ["Label", "Button", "CheckBox", "CheckButton", "OptionButton", "LineEdit"]:
		t.set_constant("outline_size", cls, 8)
		t.set_color("font_outline_color", cls, C_OUTLINE)
		t.set_color("font_color", cls, C_TEXT)
	t.set_color("font_hover_color", "Button", C_TEXT)
	t.set_color("font_pressed_color", "Button", C_TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.75, 0.75, 0.8))
	t.set_stylebox("normal", "Button", make_box(C_BUTTON, 28, 4))
	t.set_stylebox("hover", "Button", make_box(C_BUTTON_HOVER, 28, 4))
	t.set_stylebox("pressed", "Button", make_box(C_BUTTON_PRESSED, 28, 4))
	t.set_stylebox("disabled", "Button", make_box(Color(0.3, 0.32, 0.4), 28, 4))
	t.set_stylebox("focus", "Button", make_box(Color(0, 0, 0, 0), 28, 6, C_ACCENT))
	t.set_stylebox("panel", "PanelContainer", make_box(C_PANEL, 32, 4))
	t.set_stylebox("panel", "Panel", make_box(C_PANEL, 32, 4))
	t.set_stylebox("normal", "LineEdit", make_box(Color(0.06, 0.07, 0.14), 18, 4, C_TEAL))
	t.set_stylebox("focus", "LineEdit", make_box(Color(0.06, 0.07, 0.14), 18, 6, C_ACCENT))
	t.set_stylebox("normal", "OptionButton", make_box(C_BUTTON, 22, 4))
	t.set_stylebox("hover", "OptionButton", make_box(C_BUTTON_HOVER, 22, 4))
	t.set_stylebox("pressed", "OptionButton", make_box(C_BUTTON_PRESSED, 22, 4))
	t.set_constant("separation", "VBoxContainer", 18)
	t.set_constant("separation", "HBoxContainer", 18)
	t.set_constant("h_separation", "GridContainer", 14)
	t.set_constant("v_separation", "GridContainer", 14)
	# Sliders: thick grabber area.
	t.set_stylebox("slider", "HSlider", make_box(Color(0.06, 0.07, 0.14), 12, 0))
	t.set_stylebox("grabber_area", "HSlider", make_box(C_TEAL, 12, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", make_box(C_BUTTON_HOVER, 12, 0))
	_theme = t
	return t


static func make_box(color: Color, radius: int, border: int, border_color: Color = C_OUTLINE) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.anti_aliasing = true
	return sb


static func big_button(text: String, color: Color = C_BUTTON) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 120)
	b.add_theme_font_size_override("font_size", 40)
	if color != C_BUTTON:
		b.add_theme_stylebox_override("normal", make_box(color, 28, 4))
		b.add_theme_stylebox_override("hover", make_box(color.lightened(0.15), 28, 4))
		b.add_theme_stylebox_override("pressed", make_box(color.darkened(0.2), 28, 4))
	b.pressed.connect(func() -> void: AudioManager.play_ui("ui_click"))
	return b


static func small_button(text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 110)
	b.pressed.connect(func() -> void: AudioManager.play_ui("ui_click"))
	return b


static func label(text: String, size: int = FONT_SIZE, color: Color = C_TEXT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(6, int(float(size) * 0.2)))
	return l


static func title(text: String) -> Label:
	var l: Label = label(text, FONT_SIZE_BIG, C_ACCENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 16)
	return l


## A full-screen Control root with the theme applied and safe-area margins.
static func make_screen_root() -> Control:
	var root: Control = Control.new()
	root.theme = get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return root


## A MarginContainer that keeps content out of notches / rounded corners.
static func safe_margin() -> MarginContainer:
	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pad: Vector4 = safe_area_padding()
	m.add_theme_constant_override("margin_left", int(pad.x) + 32)
	m.add_theme_constant_override("margin_top", int(pad.y) + 24)
	m.add_theme_constant_override("margin_right", int(pad.z) + 32)
	m.add_theme_constant_override("margin_bottom", int(pad.w) + 24)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


## Safe-area insets (left, top, right, bottom) in UI pixels.
static func safe_area_padding() -> Vector4:
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0:
		return Vector4.ZERO
	# Convert from screen pixels to our 1080-high UI pixels.
	var k: float = 1080.0 / float(maxi(1, screen.y))
	return Vector4(
		maxf(0.0, float(safe.position.x)) * k,
		maxf(0.0, float(safe.position.y)) * k,
		maxf(0.0, float(screen.x - safe.end.x)) * k,
		maxf(0.0, float(screen.y - safe.end.y)) * k)
