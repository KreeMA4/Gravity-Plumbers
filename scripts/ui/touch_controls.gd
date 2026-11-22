class_name TouchControls
extends Control
## On-screen thumb controls (landscape):
##  - LEFT half: a floating joystick appears where your thumb lands.
##  - RIGHT half: big buttons (Jump, Grab L, Grab R, Use, Boots, Flop, Get Up,
##    Emote, Pause). Dragging anywhere on the right that isn't a button looks around.
## Multi-touch: every finger (touch index) owns ONE control until it lifts,
## so you can move, look, jump and grab at the same time.
## Options from Settings: left-handed swap, single Grab button, size, opacity.

signal pause_pressed

const BUTTON_DEFS: Array = [
	# id, label, bit, position (fraction of a 1080-high "thumb area" from bottom-right), size mult, colour
	["jump", "JUMP", PlumberInput.JUMP, Vector2(-170, -170), 1.15, Color(0.3, 0.85, 0.45)],
	["grab_r", "GRAB R", PlumberInput.GRAB_R, Vector2(-170, -400), 1.0, Color(1.0, 0.55, 0.2)],
	["grab_l", "GRAB L", PlumberInput.GRAB_L, Vector2(-400, -170), 1.0, Color(1.0, 0.55, 0.2)],
	["use", "USE", PlumberInput.USE, Vector2(-390, -390), 0.95, Color(0.2, 0.75, 0.85)],
	["boots", "BOOTS", PlumberInput.BOOTS, Vector2(-610, -150), 0.8, Color(0.6, 0.45, 0.9)],
	["flop", "FLOP", PlumberInput.FLOP, Vector2(-160, -610), 0.7, Color(1.0, 0.4, 0.55)],
	["get_up", "UP!", PlumberInput.GET_UP, Vector2(-360, -600), 0.7, Color(0.95, 0.85, 0.3)],
	["emote", ":)", PlumberInput.EMOTE, Vector2(-560, -560), 0.55, Color(0.7, 0.7, 0.8)],
]

var buttons_held: int = 0          ## current button bits from touches
var joystick: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO
var use_label: String = "USE"      ## context label (e.g. "TAPE", "TURN")
var enabled: bool = true
var boots_lit: bool = false        ## draws the Boots button highlighted while on

var _owners: Dictionary = {}       ## touch index -> "joy" / "look" / button id
var _joy_center: Vector2 = Vector2.ZERO
var _joy_pos: Vector2 = Vector2.ZERO
var _joy_index: int = -1
var _buttons: Array = []           ## runtime: [id, label, bit, center, radius, colour]
var _pause_rect: Rect2 = Rect2()
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	resized.connect(_layout)
	SaveData.settings_changed.connect(_layout)
	_layout()


func _layout() -> void:
	_buttons.clear()
	var scale_k: float = clampf(SaveData.setting_f("button_scale"), 0.6, 1.6)
	var lefty: bool = SaveData.setting_b("left_handed")
	var single_grab: bool = SaveData.setting_b("single_grab")
	var pad: Vector4 = UITheme.safe_area_padding()
	var s: Vector2 = size
	var corner: Vector2 = Vector2(s.x - pad.z, s.y - pad.w)
	for d: Variant in BUTTON_DEFS:
		var def: Array = d as Array
		var id: String = str(def[0])
		var label_text: String = str(def[1])
		if single_grab and id == "grab_l":
			continue
		if single_grab and id == "grab_r":
			label_text = "GRAB"
		var off: Vector2 = (def[3] as Vector2) * scale_k
		var center: Vector2 = corner + off
		if lefty:
			center.x = s.x - center.x
		var r: float = Tuning.BUTTON_SIZE * 0.5 * float(def[4]) * scale_k
		_buttons.append([id, label_text, int(def[2]), center, r, def[5] as Color])
	var pr: float = 46.0 * scale_k
	var pause_pos: Vector2 = Vector2(s.x * 0.5, pad.y + 60.0)
	_pause_rect = Rect2(pause_pos - Vector2(pr, pr), Vector2(pr, pr) * 2.0)
	queue_redraw()


func _is_left_zone(p: Vector2) -> bool:
	var lefty: bool = SaveData.setting_b("left_handed")
	return (p.x > size.x * 0.5) if lefty else (p.x < size.x * 0.5)


func _button_at(p: Vector2) -> Array:
	for b: Variant in _buttons:
		var arr: Array = b as Array
		if p.distance_to(arr[3] as Vector2) <= float(arr[4]) * 1.1:
			return arr
	return []


func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			if _pause_rect.has_point(t.position):
				pause_pressed.emit()
				get_viewport().set_input_as_handled()
				return
			var b: Array = _button_at(t.position)
			if b.is_empty() and t.position.y < size.y * 0.16:
				return   # leave the top strip to HUD buttons (checklist, etc.)
			if not b.is_empty():
				_owners[t.index] = str(b[0])
				if Engine.get_frames_drawn() > 0 and SaveData.setting_b("haptics") and OS.has_feature("mobile"):
					Input.vibrate_handheld(15)
			elif _is_left_zone(t.position) and _joy_index == -1:
				_owners[t.index] = "joy"
				_joy_index = t.index
				_joy_center = t.position
				_joy_pos = t.position
			else:
				_owners[t.index] = "look"
		else:
			var who: String = str(_owners.get(t.index, ""))
			if not _owners.has(t.index):
				return   # this finger wasn't ours (e.g. it pressed a HUD button)
			if who == "joy":
				_joy_index = -1
				joystick = Vector2.ZERO
			_owners.erase(t.index)
		_recompute_buttons()
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		var own: String = str(_owners.get(d.index, ""))
		if own == "joy":
			_joy_pos = d.position
			var v: Vector2 = (_joy_pos - _joy_center) / Tuning.JOYSTICK_RADIUS
			if v.length() > 1.0:
				# Let the base follow the thumb so you never "run out" of stick.
				_joy_center = _joy_pos - v.normalized() * Tuning.JOYSTICK_RADIUS
				v = v.normalized()
			var dz: float = SaveData.setting_f("joystick_deadzone")
			var l: float = v.length()
			joystick = Vector2.ZERO if l < dz else v.normalized() * ((l - dz) / (1.0 - dz))
			joystick.y = -joystick.y   # screen up = forward
			get_viewport().set_input_as_handled()
			queue_redraw()
		elif own == "look":
			look_delta += d.relative
			get_viewport().set_input_as_handled()
		elif own != "":
			# A finger sliding off a button onto another one (e.g. jump -> grab) switches it.
			var b2: Array = _button_at(d.position)
			if not b2.is_empty() and str(b2[0]) != own:
				_owners[d.index] = str(b2[0])
				_recompute_buttons()
				queue_redraw()
			get_viewport().set_input_as_handled()


func _recompute_buttons() -> void:
	var bits: int = 0
	for idx: Variant in _owners.keys():
		var own: String = str(_owners[idx])
		for b: Variant in _buttons:
			var arr: Array = b as Array
			if str(arr[0]) == own:
				bits |= int(arr[2])
	if SaveData.setting_b("single_grab") and (bits & PlumberInput.GRAB_R) != 0:
		bits |= PlumberInput.GRAB_L
	buttons_held = bits


## Called when the controls are hidden (pause, menus): forget every finger.
func reset() -> void:
	_owners.clear()
	_joy_index = -1
	joystick = Vector2.ZERO
	buttons_held = 0
	look_delta = Vector2.ZERO
	queue_redraw()


func take_look_delta() -> Vector2:
	var d: Vector2 = look_delta
	look_delta = Vector2.ZERO
	return d


func _draw() -> void:
	if not enabled:
		return
	var alpha: float = clampf(SaveData.setting_f("button_opacity"), 0.2, 1.0)
	# Joystick
	if _joy_index != -1:
		draw_circle(_joy_center, Tuning.JOYSTICK_RADIUS, Color(1, 1, 1, 0.12 * alpha))
		draw_arc(_joy_center, Tuning.JOYSTICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.5 * alpha), 4.0, true)
		var knob: Vector2 = _joy_center + (_joy_pos - _joy_center).limit_length(Tuning.JOYSTICK_RADIUS)
		draw_circle(knob, 56.0, Color(1, 1, 1, 0.55 * alpha))
	else:
		# Hint where to put the thumb.
		var lefty: bool = SaveData.setting_b("left_handed")
		var hint: Vector2 = Vector2(size.x - 260.0 if lefty else 260.0, size.y - 260.0)
		draw_arc(hint, Tuning.JOYSTICK_RADIUS * 0.8, 0.0, TAU, 40, Color(1, 1, 1, 0.18 * alpha), 4.0, true)
	# Buttons
	for b: Variant in _buttons:
		var arr: Array = b as Array
		var id: String = str(arr[0])
		var c: Vector2 = arr[3] as Vector2
		var r: float = float(arr[4])
		var col: Color = arr[5] as Color
		var pressed: bool = (buttons_held & int(arr[2])) != 0 or (id == "boots" and boots_lit)
		var fill: Color = col if pressed else col.darkened(0.35)
		fill.a = (0.9 if pressed else 0.55) * alpha
		draw_circle(c, r, fill)
		draw_arc(c, r, 0.0, TAU, 40, Color(0.02, 0.02, 0.08, 0.9 * alpha), 5.0, true)
		var txt: String = use_label if id == "use" else str(arr[1])
		var fs: int = int(clampf(r * 0.42, 18.0, 40.0))
		var w: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(_font, c + Vector2(-w * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, alpha))
		draw_string(_font, c + Vector2(-w * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))
	# Pause button (two bars)
	var pc: Vector2 = _pause_rect.get_center()
	draw_circle(pc, _pause_rect.size.x * 0.5, Color(0.1, 0.1, 0.2, 0.6 * alpha))
	draw_rect(Rect2(pc + Vector2(-14, -16), Vector2(9, 32)), Color(1, 1, 1, alpha))
	draw_rect(Rect2(pc + Vector2(5, -16), Vector2(9, 32)), Color(1, 1, 1, alpha))
