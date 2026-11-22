class_name FX
extends RefCounted
## Cartoon particle bursts built from CPUParticles3D (works everywhere,
## including the Compatibility renderer). Each burst frees itself.
## Particle counts are scaled by Quality.particle_scale.

static var _mesh_cache: Dictionary = {}


static func _quad_mesh(size: float, color: Color) -> Mesh:
	var key: String = "%.2f_%s" % [size, color.to_html()]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as Mesh
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	q.material = m
	_mesh_cache[key] = q
	return q


static func _sphere_mesh(r: float, mat: Material) -> Mesh:
	var key: String = "s%.2f_%d" % [r, mat.get_instance_id()]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as Mesh
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	s.material = mat
	_mesh_cache[key] = s
	return s


## Generic burst. Returns the particles node (already emitting).
static func burst(parent: Node, pos: Vector3, mesh: Mesh, amount: int, speed: float, life: float,
		gravity: Vector3, spread: float = 180.0, dir: Vector3 = Vector3.UP, color_ramp: Gradient = null) -> CPUParticles3D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var n: int = maxi(1, int(float(amount) * Quality.particle_scale))
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = 0.95
	p.mesh = mesh
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	if color_ramp != null:
		p.color_ramp = color_ramp
	p.local_coords = false
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


static func _fade(c: Color) -> Gradient:
	var g: Gradient = Gradient.new()
	g.set_color(0, c)
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	return g


static func dust(parent: Node, pos: Vector3, up: Vector3) -> void:
	burst(parent, pos, _quad_mesh(0.18, Color(1, 1, 1)), 8, 1.5, 0.5, up * 0.5, 80.0, up, _fade(Color(0.9, 0.9, 0.95, 0.8)))


static func stars(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, _quad_mesh(0.14, Color(1, 1, 1)), 10, 3.5, 0.6, Vector3.ZERO, 180.0, Vector3.UP, _fade(Color(1.0, 0.9, 0.3)))


static func splat(parent: Node, pos: Vector3, normal: Vector3) -> void:
	burst(parent, pos, _sphere_mesh(0.06, Mats.goo()), 10, 3.0, 0.7, GravityManager.get_gravity_at(pos) * 0.6, 70.0, normal, null)


static func sparks(parent: Node, pos: Vector3, normal: Vector3) -> void:
	burst(parent, pos, _quad_mesh(0.08, Color(1, 1, 1)), 12, 5.0, 0.35, GravityManager.get_gravity_at(pos) * 0.4, 50.0, normal, _fade(Color(1.0, 0.75, 0.3)))


static func boing_ring(parent: Node, pos: Vector3, up: Vector3) -> void:
	burst(parent, pos, _quad_mesh(0.12, Color(1, 1, 1)), 14, 3.0, 0.4, Vector3.ZERO, 5.0, up.cross(GravityMath.perpendicular(up)), _fade(Color(0.5, 1.0, 1.0)))


static func confetti(parent: Node, pos: Vector3) -> void:
	for col: Color in [Color(1, 0.4, 0.6), Color(0.4, 0.9, 1.0), Color(1, 0.85, 0.2), Color(0.5, 1.0, 0.4)]:
		burst(parent, pos, _quad_mesh(0.12, Color(1, 1, 1)), 10, 5.0, 1.2, GravityManager.get_gravity_at(pos) * 0.3, 60.0, -GravityManager.get_gravity_at(pos).normalized(), _fade(col))


## The "flushed" effect: a swirl of sludge spiralling away.
static func flush_swirl(parent: Node, pos: Vector3) -> void:
	var p: CPUParticles3D = burst(parent, pos, _sphere_mesh(0.08, Mats.goo()), 24, 2.0, 1.2, Vector3.ZERO, 180.0, Vector3.UP, null)
	if p != null:
		p.orbit_velocity_min = 1.5
		p.orbit_velocity_max = 2.5
		p.tangential_accel_min = 4.0
		p.tangential_accel_max = 6.0
		p.radial_accel_min = -3.0
		p.radial_accel_max = -1.0
