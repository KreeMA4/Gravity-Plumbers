class_name GameHUD
extends CanvasLayer
## In-level HUD, kept uncluttered:
##  top:    sludge meter + timer (+ storm countdown)
##  left:   collapsible work-order checklist
##  bottom: gravity arrow with boot-charge ring, held-tool name
##  toasts: DISPATCH-O-TRON subtitles; big "GRAVITY SHIFT" warning with a
##          screen-edge colour pulse; off-screen pointers to teammates.

var sludge: float = 0.0
var time_left: float = -1.0      ## <0 hides the timer
var elapsed: float = 0.0
var gravity_hud: GravityHUD
var tool_label: Label
var checklist_box: VBoxContainer
var checklist_panel: PanelContainer
var camera: Camera3D = null
var local_plumber: Plumber = null
var teammates: Array = []        ## Array of Plumber

var _root: Control
var _bar: SludgeBar
var _timer_label: Label
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_queue: Array = []
var _toast_time: float = 0.0
var _warn_label: Label
var _edge: EdgePulse
var _pointers: TeammatePointers
var _orders_open: bool = true
var _order_lines: Dictionary = {}


func _ready() -> void:
	layer = 4
	_root = UITheme.make_screen_root()
	add_child(_root)
	_edge = EdgePulse.new()
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_edge)
	_pointers = TeammatePointers.new()
	_pointers.hud = self
	_pointers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pointers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pointers)
	var margin: MarginContainer = UITheme.safe_margin()
	_root.add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)
	# --- Top row: orders toggle | sludge bar | timer
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var toggle: Button = UITheme.small_button("ORDERS")
	toggle.custom_minimum_size = Vector2(190, 84)
	toggle.add_theme_font_size_override("font_size", 26)
	toggle.pressed.connect(func() -> void:
		_orders_open = not _orders_open
		checklist_panel.visible = _orders_open)
	top.add_child(toggle)
	var center: HBoxContainer = HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(center)
	_bar = SludgeBar.new()
	_bar.custom_minimum_size = Vector2(520, 64)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_bar)
	_timer_label = UITheme.label("0:00", 40)
	_timer_label.custom_minimum_size = Vector2(150, 0)
	center.add_child(_timer_label)
	var spacer_r: Control = Control.new()
	spacer_r.custom_minimum_size = Vector2(190, 0)
	spacer_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer_r)
	# --- Toast (dispatcher subtitles)
	var toast_row: HBoxContainer = HBoxContainer.new()
	toast_row.alignment = BoxContainer.ALIGNMENT_CENTER
	toast_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(toast_row)
	_toast_panel = PanelContainer.new()
	_toast_panel.add_theme_stylebox_override("panel", UITheme.make_box(Color(0.1, 0.1, 0.22, 0.88), 22, 4, UITheme.C_TEAL))
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	toast_row.add_child(_toast_panel)
	_toast_label = UITheme.label("", 28)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.custom_minimum_size = Vector2(900, 0)
	_toast_panel.add_child(_toast_label)
	# --- Middle: checklist on the left, warning in the centre
	var mid: HBoxContainer = HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(mid)
	checklist_panel = PanelContainer.new()
	checklist_panel.add_theme_stylebox_override("panel", UITheme.make_box(Color(0.08, 0.09, 0.2, 0.7), 20, 3))
	checklist_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checklist_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mid.add_child(checklist_panel)
	checklist_box = VBoxContainer.new()
	checklist_box.add_theme_constant_override("separation", 6)
	checklist_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checklist_panel.add_child(checklist_box)
	_warn_label = UITheme.label("", 72, Color(1.0, 0.35, 0.3))
	_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warn_label.add_theme_constant_override("outline_size", 18)
	mid.add_child(_warn_label)
	# --- Bottom: gravity arrow + tool
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bottom)
	gravity_hud = GravityHUD.new()
	bottom.add_child(gravity_hud)
	tool_label = UITheme.label("", 26, UITheme.C_ACCENT)
	bottom.add_child(tool_label)


## The hub has no sludge, clock or orders.
func set_hub_mode(on: bool) -> void:
	_bar.visible = not on
	_timer_label.visible = not on
	checklist_panel.visible = not on


## Rebuild the checklist from WorkOrderManager.orders.
func set_orders(orders: Array) -> void:
	for c: Node in checklist_box.get_children():
		c.queue_free()
	_order_lines.clear()
	var head: Label = UITheme.label("WORK ORDERS", 26, UITheme.C_ACCENT)
	checklist_box.add_child(head)
	for o: Variant in orders:
		var w: WorkOrder = o as WorkOrder
		var l: Label = UITheme.label("", 24)
		l.custom_minimum_size = Vector2(430, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		checklist_box.add_child(l)
		_order_lines[w.id] = l
	refresh_orders(orders)


func refresh_orders(orders: Array) -> void:
	for o: Variant in orders:
		var w: WorkOrder = o as WorkOrder
		var l: Label = _order_lines.get(w.id) as Label
		if l == null:
			continue
		match w.status:
			WorkOrder.Status.DONE:
				l.text = "[x] " + w.text
				l.add_theme_color_override("font_color", UITheme.C_GOOD)
			WorkOrder.Status.ACTIVE:
				var pct: String = ""
				if w.targets.size() > 1:
					pct = "  (%d/%d)" % [w.done_targets.size(), w.targets.size()]
				l.text = "[ ] " + w.text + pct
				l.add_theme_color_override("font_color", Color(1, 1, 1))
			_:
				l.text = "[~] " + w.text
				l.add_theme_color_override("font_color", Color(0.6, 0.62, 0.72))


## Show a DISPATCH-O-TRON line (subtitles are always on; the voice is blips).
func say(text: String, seconds: float = 4.0) -> void:
	_toast_queue.append([text, seconds])
	if not _toast_panel.visible:
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_panel.visible = false
		return
	var t: Array = _toast_queue.pop_front()
	_toast_label.text = "DISPATCH-O-TRON: " + str(t[0])
	_toast_time = float(t[1])
	_toast_panel.visible = true
	AudioManager.speak(str(t[0]), 1.35)


func _process(delta: float) -> void:
	_bar.value = sludge
	elapsed += delta
	if time_left >= 0.0:
		var s: int = int(ceilf(time_left))
		_timer_label.text = "%d:%02d" % [floori(s / 60.0), s % 60]
		_timer_label.add_theme_color_override("font_color", UITheme.C_DANGER if time_left < 30.0 else Color(1, 1, 1))
	else:
		var e: int = int(elapsed)
		_timer_label.text = "%d:%02d" % [floori(e / 60.0), e % 60]
	if _toast_panel.visible:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_next_toast()
	# Gravity warning.
	var warn: bool = GravityManager.phase == GravityManager.Phase.WARNING
	_warn_label.visible = warn
	if warn:
		_warn_label.text = "GRAVITY SHIFT!\n%d" % ceili(GravityManager.warning_left)
		_warn_label.modulate.a = 0.6 + 0.4 * sin(elapsed * 14.0)
	_edge.intensity = 1.0 if warn else maxf(0.0, _edge.intensity - delta * 2.0)
	if GravityManager.phase == GravityManager.Phase.SHIFTING:
		_edge.intensity = 1.0
	_edge.queue_redraw()
	if local_plumber != null and is_instance_valid(local_plumber):
		gravity_hud.probe = local_plumber.get_center()
		gravity_hud.boots_charge = local_plumber.boots_charge / Tuning.BOOTS_CHARGE_MAX if (local_plumber.boots_on or local_plumber.boots_charge < Tuning.BOOTS_CHARGE_MAX) else -1.0
		var t: ToolBase = local_plumber.get_tool()
		tool_label.text = ("Holding: " + t.display_name) if t != null else ""
	_pointers.queue_redraw()


class SludgeBar extends Control:
	var value: float = 0.0

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_style_box(UITheme.make_box(Color(0.06, 0.06, 0.12, 0.85), 24, 4), r)
		var fill: Rect2 = Rect2(Vector2(6, 6), Vector2((size.x - 12.0) * clampf(value / 100.0, 0.0, 1.0), size.y - 12.0))
		var col: Color = UITheme.C_SLUDGE.lerp(UITheme.C_SLUDGE_DARK, clampf(value / 100.0, 0.0, 1.0))
		if value > 80.0 and fmod(Time.get_ticks_msec() * 0.001, 0.6) < 0.3:
			col = UITheme.C_DANGER
		if fill.size.x > 2.0:
			draw_style_box(UITheme.make_box(col, 18, 0), fill)
		var font: Font = ThemeDB.fallback_font
		var txt: String = "SLUDGE %d%%" % int(value)
		var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var pos: Vector2 = Vector2((size.x - w) * 0.5, size.y * 0.5 + 11.0)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Color(0, 0, 0))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1))

	func _process(_delta: float) -> void:
		queue_redraw()


class EdgePulse extends Control:
	var intensity: float = 0.0

	func _draw() -> void:
		if intensity <= 0.01:
			return
		var a: float = intensity * (0.25 + 0.2 * sin(Time.get_ticks_msec() * 0.015))
		var c: Color = Color(1.0, 0.25, 0.2, a)
		var w: float = 26.0
		draw_rect(Rect2(0, 0, size.x, w), c)
		draw_rect(Rect2(0, size.y - w, size.x, w), c)
		draw_rect(Rect2(0, 0, w, size.y), c)
		draw_rect(Rect2(size.x - w, 0, w, size.y), c)


class TeammatePointers extends Control:
	var hud: GameHUD

	func _draw() -> void:
		if hud == null or hud.camera == null or not is_instance_valid(hud.camera):
			return
		var cam: Camera3D = hud.camera
		var font: Font = ThemeDB.fallback_font
		var rect: Rect2 = Rect2(Vector2(60, 140), size - Vector2(120, 280))
		for t: Variant in hud.teammates:
			var p: Plumber = t as Plumber
			if p == null or not is_instance_valid(p) or p == hud.local_plumber or p.is_flushed():
				continue
			var world: Vector3 = p.get_center() + p.local_up * 1.0
			var behind: bool = cam.is_position_behind(world)
			var sp: Vector2 = cam.unproject_position(world)
			# unproject_position returns viewport pixels; convert into this canvas.
			var vp_size: Vector2 = get_viewport().get_visible_rect().size
			sp = sp / vp_size * size
			if behind:
				sp = size - sp
			var col: Color = _tag_color(p)
			if rect.has_point(sp) and not behind:
				continue   # visible: the 3D name tag is enough
			var c: Vector2 = size * 0.5
			var dir: Vector2 = (sp - c).normalized()
			var edge: Vector2 = c + dir * minf(rect.size.x * 0.5 / maxf(0.01, absf(dir.x)), rect.size.y * 0.5 / maxf(0.01, absf(dir.y)))
			var side: Vector2 = Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([edge + dir * 26.0, edge - dir * 10.0 + side * 18.0, edge - dir * 10.0 - side * 18.0]), col)
			draw_string_outline(font, edge - dir * 40.0 + Vector2(-40, 8), p.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0))
			draw_string(font, edge - dir * 40.0 + Vector2(-40, 8), p.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)

	static func _tag_color(p: Plumber) -> Color:
		var tags: Array = [Color(1.0, 0.85, 0.2), Color(0.2, 0.85, 0.85), Color(1.0, 0.45, 0.7), Color(1.0, 0.55, 0.2),
			Color(0.55, 1.0, 0.3), Color(0.7, 0.45, 1.0), Color(1, 1, 1), Color(1.0, 0.3, 0.3)]
		return tags[clampi(p.look.get_v("tag"), 0, tags.size() - 1)] as Color
