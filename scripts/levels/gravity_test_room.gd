extends Node3D
## M1 test room: a closed box room full of crates. Use the buttons to rotate
## gravity through all 6 directions, trigger a telegraphed shift, and toggle a
## zero-G zone and a planetoid field. The HUD arrow shows gravity at the centre.

const ROOM: Vector3 = Vector3(14, 10, 14)

var _ui: DebugRoomUI
var _hud: GravityHUD
var _zero_g: GravityField
var _planet: GravityField
var _cam: OrbitCamera
var _props: Node3D


func _ready() -> void:
	GravityManager.reset_all()
	LevelBounds.set_bounds(Vector3.ZERO, 60.0)
	Geo.basic_environment(self)
	Geo.room(self, Vector3.ZERO, ROOM, Color(0.3, 0.34, 0.5))
	# Coloured marker on each wall so you can tell which way is which.
	var markers: Array = [
		[Vector3(0, -ROOM.y * 0.5 + 0.05, 0), Color(0.3, 0.9, 0.4)],
		[Vector3(0, ROOM.y * 0.5 - 0.05, 0), Color(0.9, 0.3, 0.3)],
		[Vector3(ROOM.x * 0.5 - 0.05, 0, 0), Color(1.0, 0.8, 0.2)],
		[Vector3(-ROOM.x * 0.5 + 0.05, 0, 0), Color(0.3, 0.6, 1.0)],
		[Vector3(0, 0, ROOM.z * 0.5 - 0.05), Color(1.0, 0.5, 0.9)],
		[Vector3(0, 0, -ROOM.z * 0.5 + 0.05), Color(1.0, 0.55, 0.2)],
	]
	for m: Variant in markers:
		var arr: Array = m as Array
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.6
		sm.height = 1.2
		mi.mesh = sm
		mi.material_override = Mats.glow(arr[1] as Color)
		mi.position = arr[0] as Vector3
		add_child(mi)
	_props = Node3D.new()
	_props.name = "Props"
	add_child(_props)
	_spawn_boxes()

	_zero_g = GravityField.create(GravityFieldData.make_zero_g("test_zero_g", Vector3(-3.5, 0, 0), Vector3(2.5, 4.5, 2.5)))
	_zero_g.data.enabled = false
	add_child(_zero_g)
	var rock_center: Vector3 = Vector3(3.5, 0, 3.5)
	var rock: StaticBody3D = StaticBody3D.new()
	rock.position = rock_center
	var rcs: CollisionShape3D = CollisionShape3D.new()
	var rshape: SphereShape3D = SphereShape3D.new()
	rshape.radius = 1.2
	rcs.shape = rshape
	rock.add_child(rcs)
	var rmi: MeshInstance3D = MeshInstance3D.new()
	var rsm: SphereMesh = SphereMesh.new()
	rsm.radius = 1.2
	rsm.height = 2.4
	rmi.mesh = rsm
	rmi.material_override = Mats.solid(Color(0.55, 0.4, 0.7))
	rock.add_child(rmi)
	add_child(rock)
	_planet = GravityField.create(GravityFieldData.make_sphere("test_planet", rock_center, 1.2, 3.0))
	_planet.data.enabled = false
	add_child(_planet)

	_cam = OrbitCamera.new()
	add_child(_cam)

	_ui = DebugRoomUI.new()
	add_child(_ui)
	_ui.add_button("Cycle gravity", GravityManager.cycle_debug)
	_ui.add_button("Shift (warned)", _random_shift)
	_ui.add_button("Zero-G zone", func() -> void: _toggle(_zero_g))
	_ui.add_button("Planetoid", func() -> void: _toggle(_planet))
	_ui.add_button("More boxes", _spawn_boxes)
	_hud = GravityHUD.new()
	_ui.bottom.add_child(_hud)


func _spawn_boxes() -> void:
	var colors: Array = [UITheme.C_PIPE, UITheme.C_TEAL, UITheme.C_ACCENT, UITheme.C_LEAK, UITheme.C_SLUDGE]
	for i: int in 10:
		if _props.get_child_count() >= Tuning.MAX_AWAKE_PROPS:
			return
		var p: Vector3 = Vector3(randf_range(-5, 5), randf_range(-3, 3), randf_range(-5, 5))
		var s: float = randf_range(0.5, 1.1)
		Geo.dynamic_box(_props, p, Vector3(s, s, s), colors[i % colors.size()] as Color, s * 6.0)


func _random_shift() -> void:
	var cur: int = GravityMath.nearest_axis_index(GravityManager.global_dir)
	var pick: int = (cur + 1 + randi() % 5) % 6
	GravityManager.request_shift(GravityMath.AXES[pick] as Vector3)


func _toggle(f: GravityField) -> void:
	GravityManager.set_field_enabled(f.data.id, not f.data.enabled)


func _process(_delta: float) -> void:
	GravityManager.debug_probe = Vector3.ZERO
	_hud.probe = Vector3.ZERO
	var g: Vector3 = GravityManager.global_dir
	_ui.info.text = "Gravity test room\nGlobal down: (%.0f, %.0f, %.0f)\nPhase: %s" % [g.x, g.y, g.z, GravityManager.Phase.keys()[GravityManager.phase]]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_gravity"):
		GravityManager.cycle_debug()


func _exit_tree() -> void:
	GravityManager.reset_all()
