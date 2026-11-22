extends Node3D
## Automated physics soak test: 4 bot plumbers, 30 crates and goo blobs in a
## closed room while gravity flips randomly every 2-4 s for 2 minutes.
## Every physics tick it checks every body for NaN / infinite values and for
## escaping the playable volume, and it records FPS and physics time.
## Run from Debug rooms, or headless:  godot -- --soak   (exit code 0 = pass)

const DURATION: float = 120.0

var _t: float = 0.0
var _next_flip: float = 2.0
var _nan_count: int = 0
var _oob_count: int = 0
var _frames: int = 0
var _fps_sum: float = 0.0
var _phys_max: float = 0.0
var _phys_sum: float = 0.0
var _ticks: int = 0
var _label: Label
var _done: bool = false
var _pool: GooPool
var _cam: OrbitCamera
var _seed: int = 0
var _reported: int = 0   ## how many problem bodies were described in the log


func _ready() -> void:
	# Random but reproducible: the seed is logged, and --soak-seed=N replays a run.
	_seed = randi()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--soak-seed="):
			_seed = a.substr(12).to_int()
	seed(_seed)
	GameLog.info("Soak test seed %d" % _seed)
	GravityManager.reset_all()
	LevelBounds.set_bounds(Vector3(0, 6, 0), 30.0)
	Geo.basic_environment(self)
	Geo.room(self, Vector3(0, 6, 0), Vector3(20, 12, 20), Color(0.35, 0.38, 0.55))
	for i: int in 30:
		var s: float = randf_range(0.4, 0.9)
		var rb: RigidBody3D = Geo.dynamic_box(self, Vector3(randf_range(-8, 8), randf_range(1, 10), randf_range(-8, 8)), Vector3(s, s, s),
			[UITheme.C_PIPE, UITheme.C_TEAL, UITheme.C_ACCENT][i % 3] as Color, s * 6.0)
		rb.collision_layer = Layers.PROPS
		rb.collision_mask = Layers.MASK_SOLID
	_pool = GooPool.new()
	add_child(_pool)
	for i: int in 40:
		_pool.spawn(Vector3(randf_range(-6, 6), randf_range(2, 9), randf_range(-6, 6)), Vector3.ZERO)
	for i: int in 4:
		var p: Plumber = Plumber.new()
		p.setup(Transform3D(Basis.IDENTITY, Vector3(-3 + i * 2, 0.05, 0)), PlumberLook.default_for(i), 1, i)
		add_child(p)
		var bot: BotBrain = BotBrain.new()
		bot.name = "SoakBot_%d" % i
		bot.plumber = p
		add_child(bot)
	_cam = OrbitCamera.new()
	_cam.target = Vector3(0, 6, 0)
	_cam.distance = 24.0
	add_child(_cam)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var root: Control = UITheme.make_screen_root()
	layer.add_child(root)
	_label = UITheme.label("", 30)
	_label.position = Vector2(40, 40)
	root.add_child(_label)
	var back: Button = UITheme.small_button("< Back")
	back.position = Vector2(40, 900)
	back.custom_minimum_size = Vector2(240, 96)
	back.pressed.connect(func() -> void: GameState.goto_screen("main_menu"))
	root.add_child(back)
	GameLog.info("Soak test started")


func _physics_process(dt: float) -> void:
	if _done:
		return
	_t += dt
	_ticks += 1
	var phys: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_phys_sum += phys
	_phys_max = maxf(_phys_max, phys)
	_next_flip -= dt
	if _next_flip <= 0.0:
		_next_flip = randf_range(2.0, 4.0)
		GravityManager.request_shift(GravityMath.AXES[randi() % 6] as Vector3, 0.5, true)
	for group: String in ["plumber_parts", "props", "goo"]:
		for n: Node in get_tree().get_nodes_in_group(group):
			var rb: RigidBody3D = n as RigidBody3D
			if rb == null or not rb.is_inside_tree() or rb.process_mode == Node.PROCESS_MODE_DISABLED:
				continue
			if not rb.global_position.is_finite() or not rb.linear_velocity.is_finite() or not rb.angular_velocity.is_finite():
				_nan_count += 1
				_report("NaN", rb)
			elif rb.global_position.distance_to(LevelBounds.center) > LevelBounds.radius:
				_oob_count += 1
				_report("out of bounds", rb)
	if _t >= DURATION:
		_finish()


func _process(_delta: float) -> void:
	_frames += 1
	_fps_sum += Engine.get_frames_per_second()
	if _label != null:
		_label.text = "PHYSICS SOAK TEST  %d / %d s\nNaN bodies: %d   out of bounds: %d\nFPS avg %.1f   physics avg %.2f ms  max %.2f ms\nBodies awake: %d" % [
			int(_t), int(DURATION), _nan_count, _oob_count, _fps_sum / float(maxi(1, _frames)),
			_phys_sum / float(maxi(1, _ticks)), _phys_max, int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))]


## Describe the first few problem bodies so a failure can be diagnosed from the log.
func _report(kind: String, rb: RigidBody3D) -> void:
	if _reported >= 12:
		return
	_reported += 1
	var groups: PackedStringArray = PackedStringArray()
	for g: StringName in rb.get_groups():
		if not str(g).begins_with("_"):
			groups.append(str(g))
	GameLog.info("Soak problem: %s at t=%.2fs body=%s groups=%s pos=%s vel=%s gravity=%s" % [kind, _t, rb.name,
		",".join(groups), str(rb.global_position), str(rb.linear_velocity), str(GravityManager.global_dir)])


func _finish() -> void:
	_done = true
	var ok: bool = _nan_count == 0 and _oob_count == 0
	var summary: String = "Soak test (seed %d) %s: NaN %d, out-of-bounds %d, avg FPS %.1f, physics avg %.2f ms max %.2f ms" % [
		_seed, "PASSED" if ok else "FAILED", _nan_count, _oob_count, _fps_sum / float(maxi(1, _frames)),
		_phys_sum / float(maxi(1, _ticks)), _phys_max]
	GameLog.info(summary)
	if _label != null:
		_label.text += "\n\n" + summary
		_label.add_theme_color_override("font_color", UITheme.C_GOOD if ok else UITheme.C_DANGER)
	if OS.get_cmdline_user_args().has("--soak"):
		GameState.quit_game(0 if ok else 1)


func _exit_tree() -> void:
	GravityManager.reset_all()
