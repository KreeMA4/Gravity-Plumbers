extends Node
## Customise your plumber (landscape):
##  left:   category tabs (each with a lock for the randomizer)
##  centre: 3D turntable preview (drag to spin; hops when something changes)
##  right:  option grid for the selected category (locked items show how to unlock)
##  bottom: big RANDOMIZE dice (+ colours-only, undo), 3 outfit slots, name, Done.
## Works as its own screen (from the main menu) or as an overlay (hub mirror,
## lobby) via set_overlay(true).

const CATEGORY_NAMES: Dictionary = {
	"build": "Body", "colors": "Colours", "face": "Face", "headgear": "Hats",
	"backpack": "Backpack", "pattern": "Pattern", "boots": "Boots & Gloves", "extras": "Extras",
}
const FIELD_NAMES: Dictionary = {
	"skin": "Skin", "overalls": "Overalls", "gloves_col": "Gloves", "boots_col": "Boots", "accent": "Shirt",
	"eyes": "Eyes", "expression": "Expression", "nose": "Nose", "mustache": "Mustache", "brows": "Eyebrows",
	"boots": "Boots", "gloves": "Gloves", "tag": "Name tag", "emote": "Favourite emote", "voice": "Voice",
	"build": "Body", "headgear": "Headgear", "backpack": "Backpack", "pattern": "Pattern",
}

var look: PlumberLook
var overlay: bool = false
var locks: Dictionary = {}           ## category -> true (kept fixed by the randomizer)
var _category: String = "build"
var _undo: Array = []                ## previous looks (bytes) for Undo
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _layer: CanvasLayer
var _root: Control
var _viewport: SubViewport
var _turntable: Node3D
var _preview: Node3D = null
var _spin: float = 0.0
var _spin_vel: float = 0.6
var _hop: float = 0.0
var _tabs_box: VBoxContainer
var _options_box: VBoxContainer
var _dice: Button
var _dice_t: float = 0.0
var _name_edit: LineEdit
var _ducks: int = 0
var _drag_index: int = -1


func set_overlay(on: bool) -> void:
	overlay = on


func _ready() -> void:
	_rng.randomize()
	_ducks = SaveData.duck_count()
	var b: PackedByteArray = SaveData.get_look_bytes()
	look = PlumberLook.from_bytes(b) if b.size() >= 2 else PlumberLook.default_for(0)
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	_root = UITheme.make_screen_root()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_root)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.17)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var margin: MarginContainer = UITheme.safe_margin()
	_root.add_child(margin)
	var main_col: VBoxContainer = VBoxContainer.new()
	margin.add_child(main_col)
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_col.add_child(row)
	# Left: tabs.
	var tabs_scroll: ScrollContainer = ScrollContainer.new()
	tabs_scroll.custom_minimum_size = Vector2(380, 0)
	tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(tabs_scroll)
	_tabs_box = VBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 10)
	tabs_scroll.add_child(_tabs_box)
	# Centre: 3D preview.
	var svc: SubViewportContainer = SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.custom_minimum_size = Vector2(520, 560)
	svc.gui_input.connect(_on_preview_input)
	row.add_child(svc)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	svc.add_child(_viewport)
	_build_stage()
	# Right: options.
	var opt_scroll: ScrollContainer = ScrollContainer.new()
	opt_scroll.custom_minimum_size = Vector2(640, 0)
	opt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(opt_scroll)
	_options_box = VBoxContainer.new()
	_options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_scroll.add_child(_options_box)
	# Bottom bar.
	var bottom: HBoxContainer = HBoxContainer.new()
	main_col.add_child(bottom)
	_dice = UITheme.big_button("RANDOMIZE!", UITheme.C_LEAK.darkened(0.15))
	_dice.custom_minimum_size = Vector2(340, 110)
	_dice.pivot_offset = Vector2(170, 55)
	_dice.pressed.connect(func() -> void: _randomize(false))
	bottom.add_child(_dice)
	var colors_b: Button = UITheme.small_button("Colours only")
	colors_b.custom_minimum_size = Vector2(220, 110)
	colors_b.add_theme_font_size_override("font_size", 26)
	colors_b.pressed.connect(func() -> void: _randomize(true))
	bottom.add_child(colors_b)
	var undo_b: Button = UITheme.small_button("Undo")
	undo_b.custom_minimum_size = Vector2(150, 110)
	undo_b.pressed.connect(_on_undo)
	bottom.add_child(undo_b)
	for i: int in 3:
		var slot: int = i
		var sb: Button = UITheme.small_button("Outfit %d" % (i + 1))
		sb.custom_minimum_size = Vector2(150, 110)
		sb.add_theme_font_size_override("font_size", 24)
		sb.tooltip_text = "Tap: wear. Hold: save current outfit here."
		sb.button_down.connect(func() -> void: sb.set_meta("down_t", Time.get_ticks_msec()))
		sb.button_up.connect(func() -> void: _outfit_slot(slot, Time.get_ticks_msec() - int(sb.get_meta("down_t", 0)) > 600))
		bottom.add_child(sb)
	_name_edit = LineEdit.new()
	_name_edit.text = str(SaveData.data.get("player_name", "Plumber"))
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(260, 110)
	_name_edit.add_theme_font_size_override("font_size", 32)
	bottom.add_child(_name_edit)
	var done: Button = UITheme.big_button("Done", UITheme.C_GOOD.darkened(0.3))
	done.custom_minimum_size = Vector2(200, 110)
	done.pressed.connect(_on_done)
	bottom.add_child(done)
	_build_tabs()
	_show_category(_category)
	_rebuild_preview()
	if not overlay:
		AudioManager.play_music("menu")


func _build_stage() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.13, 0.27)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.9)
	e.ambient_light_energy = 0.6
	env.environment = e
	_viewport.add_child(env)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation = Vector3(-0.7, 0.5, 0)
	_viewport.add_child(light)
	var floor_m: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 1.0
	cm.height = 0.15
	floor_m.mesh = cm
	floor_m.material_override = Mats.toon(UITheme.C_TEAL.darkened(0.3))
	floor_m.position = Vector3(0, -0.075, 0)
	_viewport.add_child(floor_m)
	_turntable = Node3D.new()
	_viewport.add_child(_turntable)
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0, 1.05, 3.1)
	cam.rotation = Vector3(-0.08, 0, 0)
	cam.fov = 45.0
	_viewport.add_child(cam)
	cam.current = true


func _build_tabs() -> void:
	for c: Node in _tabs_box.get_children():
		c.queue_free()
	for cat: String in PlumberLook.CATEGORIES.keys():
		var r: HBoxContainer = HBoxContainer.new()
		_tabs_box.add_child(r)
		var b: Button = UITheme.small_button(str(CATEGORY_NAMES.get(cat, cat)))
		b.custom_minimum_size = Vector2(250, 96)
		b.toggle_mode = true
		b.button_pressed = cat == _category
		b.add_theme_font_size_override("font_size", 28)
		var c2: String = cat
		b.pressed.connect(func() -> void: _show_category(c2))
		r.add_child(b)
		var lock: Button = UITheme.small_button("LOCK" if locks.has(cat) else "lock")
		lock.custom_minimum_size = Vector2(110, 96)
		lock.add_theme_font_size_override("font_size", 22)
		lock.toggle_mode = true
		lock.button_pressed = locks.has(cat)
		lock.tooltip_text = "Locked categories stay the same when you randomize."
		lock.toggled.connect(func(on: bool) -> void:
			if on:
				locks[c2] = true
			else:
				locks.erase(c2)
			lock.text = "LOCK" if on else "lock")
		r.add_child(lock)


func _show_category(cat: String) -> void:
	_category = cat
	for r: Node in _tabs_box.get_children():
		var b: Button = r.get_child(0) as Button
		if b != null:
			b.button_pressed = b.text == str(CATEGORY_NAMES.get(cat, cat))
	for c: Node in _options_box.get_children():
		c.queue_free()
	for f: Variant in PlumberLook.CATEGORIES[cat]:
		var field: String = str(f)
		var title: Label = UITheme.label(str(FIELD_NAMES.get(field, field)), 30, UITheme.C_ACCENT)
		_options_box.add_child(title)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 3 if not PlumberLook.COLOR_SLOTS.has(field) else 6
		_options_box.add_child(grid)
		if PlumberLook.COLOR_SLOTS.has(field):
			for idx: Variant in PlumberLook.SLOT_SWATCHES[field]:
				var sw: int = int(idx)
				var cb: Button = Button.new()
				cb.custom_minimum_size = Vector2(92, 92)
				var col: Color = PlumberLook.SWATCHES[sw] as Color
				var selected: bool = look.get_v(field) == sw
				cb.add_theme_stylebox_override("normal", UITheme.make_box(col, 46, 8 if selected else 3, UITheme.C_ACCENT if selected else UITheme.C_OUTLINE))
				cb.add_theme_stylebox_override("hover", UITheme.make_box(col.lightened(0.1), 46, 6, UITheme.C_ACCENT))
				cb.add_theme_stylebox_override("pressed", UITheme.make_box(col.darkened(0.1), 46, 8, UITheme.C_ACCENT))
				cb.pressed.connect(func() -> void: _set_option(field, sw))
				grid.add_child(cb)
		else:
			var names: Array = PlumberLook.OPTIONS.get(field, [])
			for i: int in names.size():
				var opt: int = i
				var unlocked: bool = PlumberLook.is_unlocked(field, i, _ducks)
				var txt: String = str(names[i])
				if not unlocked:
					txt = "LOCKED\n%d ducks" % PlumberLook.ducks_needed(field, i)
				var ob: Button = UITheme.small_button(txt)
				ob.custom_minimum_size = Vector2(196, 96)
				ob.add_theme_font_size_override("font_size", 22)
				ob.disabled = not unlocked
				ob.toggle_mode = true
				ob.button_pressed = look.get_v(field) == i
				ob.pressed.connect(func() -> void: _set_option(field, opt))
				grid.add_child(ob)


func _set_option(field: String, v: int) -> void:
	_undo.append(look.to_bytes())
	look.set_v(field, v)
	AudioManager.play_ui("ui_click", 0.0, 1.0 + randf() * 0.2)
	_rebuild_preview()
	_show_category(_category)


func _randomize(colors_only: bool) -> void:
	_undo.append(look.to_bytes())
	look.randomize_look(_rng, locks.keys(), _ducks, colors_only)
	AudioManager.play_ui("dice_rattle")
	_dice_t = 0.5
	_rebuild_preview()
	_show_category(_category)


func _on_undo() -> void:
	if _undo.is_empty():
		return
	look = PlumberLook.from_bytes(_undo.pop_back() as PackedByteArray)
	AudioManager.play_ui("ui_back")
	_rebuild_preview()
	_show_category(_category)


func _outfit_slot(slot: int, save_here: bool) -> void:
	var outfits: Array = SaveData.data.get("outfits", [[], [], []])
	while outfits.size() < 3:
		outfits.append([])
	if save_here:
		var arr: Array = []
		for v: int in look.to_bytes():
			arr.append(v)
		outfits[slot] = arr
		SaveData.data["outfits"] = outfits
		SaveData.save()
		AudioManager.play_ui("ui_confirm")
		return
	var saved: Array = outfits[slot] as Array
	if saved.size() < 2:
		AudioManager.play_ui("ui_back")
		return
	var b: PackedByteArray = PackedByteArray()
	for v2: Variant in saved:
		b.append(clampi(int(v2), 0, 255))
	_undo.append(look.to_bytes())
	look = PlumberLook.from_bytes(b)
	look.enforce_unlocks(_ducks)
	_rebuild_preview()
	_show_category(_category)


func _rebuild_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = PlumberMeshBuilder.build_preview(look)
	_turntable.add_child(_preview)
	_hop = 1.0
	_spin_vel += 3.0


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		_spin_vel = d.relative.x * 0.6
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask != 0:
		_spin_vel = (event as InputEventMouseMotion).relative.x * 0.6


func _process(delta: float) -> void:
	_spin += _spin_vel * delta
	_spin_vel = lerpf(_spin_vel, 0.4, 1.0 - exp(-delta * 2.0))
	_hop = maxf(0.0, _hop - delta * 2.5)
	if _turntable != null:
		_turntable.rotation = Vector3(0, _spin, 0)
		var h: float = sin((1.0 - _hop) * PI) * 0.25 * _hop
		_turntable.position = Vector3(0, h, 0)
		var sq: float = 1.0 + 0.15 * sin(_hop * 20.0) * _hop
		_turntable.scale = Vector3(1.0 / sqrt(sq), sq, 1.0 / sqrt(sq))
	if _dice_t > 0.0:
		_dice_t -= delta
		_dice.rotation = sin(_dice_t * 60.0) * 0.12 * (_dice_t / 0.5)
	elif _dice != null:
		_dice.rotation = 0.0


func _on_done() -> void:
	SaveData.set_look_bytes(look.to_bytes())
	var n: String = _name_edit.text.strip_edges().substr(0, 16)
	if n != "":
		SaveData.data["player_name"] = n
	SaveData.save()
	NetManager.update_my_info()
	AudioManager.play_ui("ui_confirm")
	if overlay:
		queue_free()
	else:
		GameState.goto_screen("main_menu")
