extends Node3D
## Ragdoll Playground (debug/tuning scene): ramps, steps, a ledge to hang
## from, a grab bar, crates to carry, gravity controls and a button to spawn
## up to 4 plumbers (you + 3 wandering bots). Use it with tuning.gd open.

var _local: LocalPlayer
var _hud: GravityHUD
var _info: Label
var _plumbers: Array = []
var _props: Node3D


func _ready() -> void:
	GravityManager.reset_all()
	LevelBounds.set_bounds(Vector3(0, 4, 0), 70.0)
	var palette: Dictionary = LevelBuilder.DEFAULT_PALETTE
	LevelBuilder.build_environment(self, palette)
	LevelBuilder.build_room(self, {"id": "play", "center": Vector3(0, 5, 0), "size": Vector3(30, 10, 30),
		"openings": [{"wall": "-z", "at": Vector2(0, 1), "size": Vector2(12, 5), "window": true}]}, palette)
	# Ramps and steps.
	Geo.static_box(self, Vector3(-8, 0.6, -4), Vector3(4, 0.3, 8), Color(0.95, 0.6, 0.3), Vector3(0.28, 0, 0))
	Geo.static_box(self, Vector3(8, 0.9, -6), Vector3(5, 0.3, 7), Color(0.4, 0.7, 0.9), Vector3(-0.42, 0, 0))
	for i: int in 4:
		Geo.static_box(self, Vector3(-9, 0.15 + i * 0.15, 6 + i * 0.8), Vector3(4, 0.3 + i * 0.3, 0.8), Color(0.7, 0.7, 0.85))
	# A ledge wall to hang from, and a grab bar.
	Geo.static_box(self, Vector3(6, 1.6, 7), Vector3(6, 3.2, 1.5), Color(0.55, 0.6, 0.75))
	LevelBuilder.build_pipe(self, {"points": [Vector3(-3, 2.4, 3), Vector3(3, 2.4, 3)], "radius": 0.08, "color": "grey"})
	LevelBuilder.build_pipe(self, {"points": [Vector3(-14.5, 0.4, -14.5), Vector3(-14.5, 8, -14.5), Vector3(14.5, 8, -14.5)], "radius": 0.15, "color": "orange", "glow": true})
	_props = Node3D.new()
	_props.name = "Props"
	add_child(_props)
	_spawn_crates()
	# The local player.
	_local = LocalPlayer.new()
	add_child(_local)
	_local.touch.pause_pressed.connect(_back)
	_spawn_plumber(0)
	_local.attach(_plumbers[0] as Plumber)
	_build_ui()
	AudioManager.play_music("game")


func _spawn_plumber(index: int) -> Plumber:
	var p: Plumber = Plumber.new()
	var at: Vector3 = Vector3(-2.0 + index * 1.4, 0.05, 0)
	p.setup(Transform3D(Basis.IDENTITY, at), PlumberLook.default_for(index), 1, index)
	add_child(p)
	_plumbers.append(p)
	if index > 0:
		var bot: BotBrain = BotBrain.new()
		bot.name = "Bot_%d" % index
		bot.plumber = p
		add_child(bot)
	return p


func _spawn_crates() -> void:
	var colors: Array = [UITheme.C_PIPE, UITheme.C_TEAL, UITheme.C_ACCENT, UITheme.C_LEAK]
	for i: int in 8:
		var s: float = 0.5 + 0.1 * float(i % 3)
		var rb: RigidBody3D = Geo.dynamic_box(_props, Vector3(-4 + i * 1.1, 0.6, -2.5), Vector3(s, s, s), colors[i % 4] as Color, 4.0 + i)
		rb.collision_layer = Layers.PROPS
		rb.collision_mask = Layers.MASK_SOLID
		rb.add_to_group("grabbable")


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var root: Control = UITheme.make_screen_root()
	layer.add_child(root)
	var margin: MarginContainer = UITheme.safe_margin()
	root.add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	for entry: Array in [["< Back", _back], ["Gravity", GravityManager.cycle_debug], ["Shift!", _warned_shift],
			["+ Bots", _add_bots], ["Respawn", _respawn_me], ["Crates", _spawn_crates]]:
		var b: Button = UITheme.small_button(str(entry[0]))
		b.custom_minimum_size = Vector2(170, 90)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(entry[1] as Callable)
		bar.add_child(b)
	_info = UITheme.label("", 24)
	col.add_child(_info)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bottom)
	_hud = GravityHUD.new()
	bottom.add_child(_hud)


func _warned_shift() -> void:
	var cur: int = GravityMath.nearest_axis_index(GravityManager.global_dir)
	GravityManager.request_shift(GravityMath.AXES[(cur + 1 + randi() % 5) % 6] as Vector3)


func _add_bots() -> void:
	while _plumbers.size() < 4:
		_spawn_plumber(_plumbers.size())


func _respawn_me() -> void:
	var p: Plumber = _plumbers[0] as Plumber
	GravityManager.set_global_immediate(Vector3.DOWN)
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))


func _back() -> void:
	GameState.goto_screen("main_menu")


func _process(_delta: float) -> void:
	var p: Plumber = _plumbers[0] as Plumber
	if p == null or not is_instance_valid(p):
		return
	_hud.probe = p.get_center()
	_hud.boots_charge = p.boots_charge / Tuning.BOOTS_CHARGE_MAX
	_info.text = "%s  stiff %.2f  support %.2f  grounded %s  boots %s  braced %s" % [
		Plumber.State.keys()[p.state], p.joint_stiffness, p.support, str(p.grounded),
		"ON" if p.boots_active else ("on" if p.boots_on else "off"), str(p.is_braced())]
	_local.touch.use_label = "USE"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_gravity"):
		GravityManager.cycle_debug()
	elif event.is_action_pressed("debug_spawn"):
		_add_bots()
	elif event.is_action_pressed("pause"):
		_back()


func _exit_tree() -> void:
	GravityManager.reset_all()
