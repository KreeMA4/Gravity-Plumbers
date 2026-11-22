extends Node
## Settings: graphics (quality preset, 3D resolution, shadows), comfort
## (camera, screen shake, hit-stop), sound volumes, controls (layout, single
## grab, button size/opacity, joystick deadzone, look sensitivity, haptics),
## and misc (show FPS, tutorial prompts, random outfit on join, language,
## debug overlay, recent log). Works as a screen or as an overlay (pause menu).

var overlay: bool = false
var _layer: CanvasLayer
var _box: VBoxContainer
var _log_label: Label


func set_overlay(on: bool) -> void:
	overlay = on


func _ready() -> void:
	if not overlay:
		var backdrop_script: GDScript = load("res://scripts/ui/menu_backdrop.gd") as GDScript
		add_child(backdrop_script.new() as Node)
	_layer = CanvasLayer.new()
	_layer.layer = 40
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var root: Control = UITheme.make_screen_root()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.1, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var margin: MarginContainer = UITheme.safe_margin()
	root.add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	margin.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	col.add_child(top)
	var back: Button = UITheme.small_button("< Done")
	back.custom_minimum_size = Vector2(240, 96)
	back.pressed.connect(_close)
	top.add_child(back)
	top.add_child(UITheme.title("SETTINGS"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)

	_section("Graphics")
	_choice("Quality", "quality", ["auto", "low", "medium", "high"], ["Auto", "Low", "Medium", "High"])
	_slider("3D resolution (0 = preset)", "render_scale", 0.0, 1.0, 0.05)
	_toggle("Shadows (High quality only)", "shadows")
	_section("Comfort")
	_toggle("Comfort camera (no rolling)", "comfort_camera")
	_toggle("Reduce screen shake", "reduce_shake")
	_toggle("Hit-stop on big hits", "hit_stop")
	_section("Sound")
	_slider("Master", "vol_master", 0.0, 1.0, 0.05)
	_slider("Music", "vol_music", 0.0, 1.0, 0.05)
	_slider("Sound effects", "vol_sfx", 0.0, 1.0, 0.05)
	_slider("Voices", "vol_voice", 0.0, 1.0, 0.05)
	_section("Controls")
	_toggle("Left-handed layout", "left_handed")
	_toggle("Single GRAB button (both hands)", "single_grab")
	_slider("Button size", "button_scale", 0.6, 1.6, 0.05)
	_slider("Button opacity", "button_opacity", 0.2, 1.0, 0.05)
	_slider("Joystick deadzone", "joystick_deadzone", 0.0, 0.5, 0.01)
	_slider("Look sensitivity", "look_sensitivity", 0.3, 3.0, 0.05)
	_toggle("Vibration (haptics)", "haptics")
	_section("Other")
	_toggle("Show FPS", "show_fps")
	_toggle("Tutorial prompts", "tutorial_prompts")
	_toggle("Random outfit every match", "random_on_join")
	_choice("Language", "language", ["en"], ["English"])
	var dbg: Button = UITheme.small_button("Toggle debug overlay")
	dbg.custom_minimum_size = Vector2(420, 90)
	dbg.pressed.connect(func() -> void:
		var main: Node = get_tree().root.get_node_or_null("Main")
		if main != null and main.has_method("get_debug_overlay"):
			(main.call("get_debug_overlay") as Node).call("toggle"))
	_box.add_child(dbg)
	var log_b: Button = UITheme.small_button("Show recent log")
	log_b.custom_minimum_size = Vector2(420, 90)
	log_b.pressed.connect(_show_log)
	_box.add_child(log_b)
	_log_label = UITheme.label("", 20, Color(0.8, 1.0, 0.8))
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(1500, 0)
	_box.add_child(_log_label)
	var reset: Button = UITheme.small_button("Reset settings")
	reset.custom_minimum_size = Vector2(420, 90)
	reset.pressed.connect(func() -> void:
		SaveData.data["settings"] = SaveLogic.default_settings()
		SaveData.settings_changed.emit()
		SaveData.save()
		_close())
	_box.add_child(reset)
	var ver: Label = UITheme.label("Gravity Plumbers v%s (%s). Logs: user://logs/" % [Tuning.GAME_VERSION, Tuning.MILESTONE_ID], 22)
	_box.add_child(ver)


func _section(title: String) -> void:
	_box.add_child(UITheme.label(title, 40, UITheme.C_ACCENT))


func _row(text: String) -> HBoxContainer:
	var r: HBoxContainer = HBoxContainer.new()
	_box.add_child(r)
	var l: Label = UITheme.label(text, 30)
	l.custom_minimum_size = Vector2(640, 0)
	r.add_child(l)
	return r


func _toggle(text: String, key: String) -> void:
	var r: HBoxContainer = _row(text)
	var b: CheckButton = CheckButton.new()
	b.button_pressed = SaveData.setting_b(key)
	b.custom_minimum_size = Vector2(160, 80)
	b.toggled.connect(func(on: bool) -> void: SaveData.set_setting(key, on))
	r.add_child(b)


func _slider(text: String, key: String, lo: float, hi: float, step: float) -> void:
	var r: HBoxContainer = _row(text)
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = SaveData.setting_f(key)
	s.custom_minimum_size = Vector2(600, 70)
	var val: Label = UITheme.label("%.2f" % s.value, 28)
	s.value_changed.connect(func(v: float) -> void:
		val.text = "%.2f" % v
		SaveData.set_setting(key, v))
	r.add_child(s)
	r.add_child(val)


func _choice(text: String, key: String, values: Array, labels: Array) -> void:
	var r: HBoxContainer = _row(text)
	var ob: OptionButton = OptionButton.new()
	ob.custom_minimum_size = Vector2(360, 84)
	ob.add_theme_font_size_override("font_size", 28)
	for l: Variant in labels:
		ob.add_item(str(l))
	ob.selected = maxi(0, values.find(str(SaveData.get_setting(key))))
	ob.item_selected.connect(func(i: int) -> void:
		var v: String = str(values[i])
		if key == "quality" and v == "auto":
			SaveData.set_setting("quality_auto_done", false)
		SaveData.set_setting(key, v)
		if key == "quality" and v != "auto":
			Quality.apply_preset(v)
		elif key == "quality":
			Quality.maybe_start_auto_benchmark())
	r.add_child(ob)


func _show_log() -> void:
	var text: String = FileAccess.get_file_as_string(GameLog.LOG_PATH)
	var lines: PackedStringArray = text.split("\n")
	var start: int = maxi(0, lines.size() - 25)
	_log_label.text = "\n".join(lines.slice(start))


func _close() -> void:
	SaveData.save()
	if overlay:
		queue_free()
	else:
		GameState.goto_screen("main_menu")
