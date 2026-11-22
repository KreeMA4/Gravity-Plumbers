class_name Leak
extends LevelObject
## A burst pipe spraying sludge. While open it raises the sludge meter and
## sometimes spits goo blobs. Hold Use with Duct Tape on it to seal it.

var normal: Vector3 = Vector3.FORWARD
var seal_progress: float = 0.0
var goo_pool: GooPool = null

var _spray: CPUParticles3D
var _patch: MeshInstance3D
var _ring: MeshInstance3D
var _hiss_t: float = 0.0
var _blob_t: float = 2.0
var _crack: MeshInstance3D


func _init() -> void:
	super._init()
	add_to_group("leaks")


func _ready() -> void:
	# Broken flange.
	_crack = MeshInstance3D.new()
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = 0.22
	c.bottom_radius = 0.22
	c.height = 0.12
	_crack.mesh = c
	_crack.material_override = Mats.toon_glow(UITheme.C_LEAK, 0.35, Quality.outlines_on_props)
	_crack.basis = PipeBuilder.basis_along(normal)
	add_child(_crack)
	# Spray.
	_spray = CPUParticles3D.new()
	_spray.amount = int(24 * Quality.particle_scale) + 4
	_spray.lifetime = 0.8
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = Mats.goo()
	_spray.mesh = sm
	_spray.direction = Vector3(0, 1, 0)
	_spray.spread = 18.0
	_spray.initial_velocity_min = 3.0
	_spray.initial_velocity_max = 5.0
	_spray.basis = PipeBuilder.basis_along(normal)
	_spray.local_coords = false
	add_child(_spray)
	# Tape patch (shown when sealed) and a progress ring.
	_patch = MeshInstance3D.new()
	var pb: BoxMesh = BoxMesh.new()
	pb.size = Vector3(0.5, 0.06, 0.5)
	_patch.mesh = pb
	_patch.material_override = Mats.toon(Color(0.72, 0.74, 0.8))
	_patch.basis = PipeBuilder.basis_along(normal)
	_patch.visible = false
	add_child(_patch)
	_ring = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.36
	_ring.mesh = tm
	_ring.material_override = Mats.glow(UITheme.C_GOOD)
	_ring.basis = PipeBuilder.basis_along(normal)
	_ring.position = normal * 0.1
	_ring.visible = false
	add_child(_ring)
	_refresh_visuals()


func is_open() -> bool:
	return active and not done


func tape(dt: float, _p: Plumber) -> void:
	if not is_host() or not is_open():
		return
	seal_progress = minf(1.0, seal_progress + dt / Tuning.LEAK_SEAL_TIME)
	if seal_progress >= 1.0:
		AudioManager.play_at("tape_rip", global_position, 2.0)
		mark_done()
	_refresh_visuals()


func _on_activated() -> void:
	AudioManager.play_at("leak_spray", global_position)
	_refresh_visuals()


func _on_done() -> void:
	FX.stars(get_parent(), global_position + normal * 0.2)
	_refresh_visuals()


func _refresh_visuals() -> void:
	if _spray == null:
		return
	_spray.emitting = is_open()
	_spray.visible = is_open()
	_crack.visible = active
	_patch.visible = done
	_ring.visible = is_open() and seal_progress > 0.0
	_ring.scale = Vector3.ONE * maxf(0.05, seal_progress)
	_spray.gravity = GravityManager.get_gravity_at(global_position)


func _physics_process(dt: float) -> void:
	if not is_open():
		return
	_spray.gravity = GravityManager.get_gravity_at(global_position)
	_hiss_t -= dt
	if _hiss_t <= 0.0:
		_hiss_t = 1.2
		AudioManager.play_at("leak_hiss", global_position, -8.0)
	if is_host() and goo_pool != null:
		_blob_t -= dt
		if _blob_t <= 0.0:
			_blob_t = randf_range(2.5, 4.5)
			goo_pool.spawn(global_position + normal * 0.3, normal * 3.0)


func get_net_state() -> Array:
	return [active, done, seal_progress]


func apply_net_state(s: Array) -> void:
	super.apply_net_state(s)
	if s.size() > 2:
		seal_progress = clampf(float(s[2]), 0.0, 1.0)
	_refresh_visuals()
