class_name InteractPrompt
extends Control
## On-screen interaction prompt. When there's something to pick up or use in
## reach, a bouncing arrow points at it and a pill reads e.g.
##   (o) PICK UP  Plunger         (touch: the white Interact button's icon)
##   [C] PICK UP  Plunger         (keyboard / gamepad: the key to press)
## Hidden as soon as the item is out of range, taken, or picked up.
## The pill stays out of the top HUD strip and the bottom control area.

var action: Interaction = null
var camera: Camera3D = null
var touch_mode: bool = true
var _t: float = 0.0
var _fade: float = 0.0
var _font: Font
var _pill_rect: Rect2 = Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	touch_mode = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func show_action(a: Interaction, cam: Camera3D) -> void:
	action = a
	camera = cam


## Prompts worth a floating label: pick up, and use an object. (DROP lives on
## the button itself on touch screens; keyboard players get a small hint.)
func is_showing() -> bool:
	if action == null or action.is_none():
		return false
	if action.kind == Interaction.Kind.DROP:
		return not touch_mode
	return true


## Where the pill is drawn (canvas pixels); used by the automated tests.
func pill_rect() -> Rect2:
	return _pill_rect if is_showing() else Rect2()


func _process(delta: float) -> void:
	_t += delta
	_fade = move_toward(_fade, 1.0 if is_showing() else 0.0, delta * 8.0)
	if _fade > 0.0 or _pill_rect.size != Vector2.ZERO:
		queue_redraw()


func _draw() -> void:
	if _fade <= 0.01 or action == null or action.is_none():
		_pill_rect = Rect2()
		return
	var view: Vector2 = size
	var a: float = _fade
	var target: Vector2 = Vector2(view.x * 0.5, view.y * 0.72)
	var has_marker: bool = false
	if action.kind != Interaction.Kind.DROP and camera != null and is_instance_valid(action.node):
		var world: Vector3 = action.node.global_position + camera.global_basis.y * 0.45
		if not camera.is_position_behind(world):
			target = camera.unproject_position(world)
			has_marker = true
	# Marker: a bobbing yellow arrow pointing down at the thing.
	var bob: float = sin(_t * 6.0) * 6.0
	if has_marker and Rect2(Vector2.ZERO, view).has_point(target):
		var tip: Vector2 = target + Vector2(0, bob)
		var arrow: PackedVector2Array = PackedVector2Array([tip, tip + Vector2(-20, -26), tip + Vector2(20, -26)])
		draw_colored_polygon(PackedVector2Array([arrow[0] + Vector2(0, 4), arrow[1] + Vector2(-3, 1), arrow[2] + Vector2(3, 1)]), Color(0, 0, 0, 0.5 * a))
		draw_colored_polygon(arrow, Color(UITheme.C_ACCENT.r, UITheme.C_ACCENT.g, UITheme.C_ACCENT.b, a))
		draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color(0.05, 0.05, 0.12, a), 3.0, true)
	# Pill: [icon] VERB  name
	var fs: int = 34
	var verb: String = action.verb
	var nm: String = action.item_name
	var vw: float = _font.get_string_size(verb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var nw: float = _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if nm != "" else 0.0
	var icon_r: float = 22.0
	var pad: float = 18.0
	var w: float = pad + icon_r * 2.0 + 14.0 + vw + (16.0 + nw if nm != "" else 0.0) + pad
	var h: float = 64.0
	var center: Vector2 = target + Vector2(0, -26.0 - 18.0 - h * 0.5) if has_marker else target
	var top_limit: float = view.y * 0.17          # keep clear of the HUD's top strip
	var bottom_limit: float = view.y * 0.74       # and of the thumb controls
	var x0: float = clampf(center.x - w * 0.5, 16.0, maxf(16.0, view.x - 16.0 - w))
	var y0: float = clampf(center.y - h * 0.5, top_limit, maxf(top_limit, bottom_limit - h))
	_pill_rect = Rect2(x0, y0, w, h)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.2, 0.86 * a)
	sb.set_corner_radius_all(int(h * 0.5))
	sb.border_color = Color(1, 1, 1, 0.9 * a)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.3 * a)
	sb.shadow_size = 6
	draw_style_box(sb, _pill_rect)
	# Button hint
	var ic: Vector2 = Vector2(x0 + pad + icon_r, y0 + h * 0.5)
	if touch_mode:
		draw_circle(ic, icon_r, Color(1, 1, 1, a))
		draw_arc(ic, icon_r + 3.0, 0.0, TAU, 32, Color(UITheme.C_ACCENT.r, UITheme.C_ACCENT.g, UITheme.C_ACCENT.b, a), 3.0, true)
		draw_circle(ic, 6.0, Color(0.08, 0.1, 0.25, a))
	else:
		var key_rect: Rect2 = Rect2(ic - Vector2(icon_r, icon_r), Vector2(icon_r, icon_r) * 2.0)
		var kb: StyleBoxFlat = StyleBoxFlat.new()
		kb.bg_color = Color(1, 1, 1, a)
		kb.set_corner_radius_all(8)
		draw_style_box(kb, key_rect)
		var kfs: int = 28
		var kw: float = _font.get_string_size("C", HORIZONTAL_ALIGNMENT_LEFT, -1, kfs).x
		draw_string(_font, ic + Vector2(-kw * 0.5, kfs * 0.36), "C", HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, Color(0.08, 0.1, 0.25, a))
	var tx: float = ic.x + icon_r + 14.0
	var ty: float = y0 + h * 0.5 + fs * 0.36
	draw_string_outline(_font, Vector2(tx, ty), verb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, a))
	draw_string(_font, Vector2(tx, ty), verb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UITheme.C_ACCENT.r, UITheme.C_ACCENT.g, UITheme.C_ACCENT.b, a))
	if nm != "":
		draw_string_outline(_font, Vector2(tx + vw + 16.0, ty), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, a))
		draw_string(_font, Vector2(tx + vw + 16.0, ty), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
