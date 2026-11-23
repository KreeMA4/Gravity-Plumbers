class_name Geo
extends RefCounted
## Small helpers for building level geometry and props in code.

## A static (non-moving) box with collision and a mesh. Returns the StaticBody3D.
static func static_box(parent: Node, pos: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, mat: Material = null) -> StaticBody3D:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.position = pos
	sb.rotation = rot
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat if mat != null else Mats.solid(color)
	sb.add_child(mi)
	parent.add_child(sb)
	return sb


## A dynamic box prop that obeys GravityManager. Returns the RigidBody3D.
static func dynamic_box(parent: Node, pos: Vector3, size: Vector3, color: Color, mass: float = 5.0) -> RigidBody3D:
	var rb: RigidBody3D = RigidBody3D.new()
	rb.position = pos
	rb.mass = mass
	# Crates falling across a room under sideways gravity reach 20+ m/s = one
	# wall thickness (0.4 m) per physics tick; without CCD they can tunnel out
	# (the soak test caught one at 24 m/s leaving the room).
	rb.continuous_cd = true
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	rb.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Mats.solid(color)
	rb.add_child(mi)
	rb.add_child(GravityBody.new())
	rb.add_to_group("props")
	parent.add_child(rb)
	return rb


## A closed hollow room (6 walls) centred at `center` with inner size `inner`.
static func room(parent: Node, center: Vector3, inner: Vector3, color: Color, wall: float = 0.4) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = "Room"
	parent.add_child(n)
	var h: Vector3 = inner * 0.5
	var t: float = wall
	var c_floor: Color = color
	var c_wall: Color = color.lightened(0.12)
	static_box(n, center + Vector3(0, -h.y - t * 0.5, 0), Vector3(inner.x + 2 * t, t, inner.z + 2 * t), c_floor)
	static_box(n, center + Vector3(0, h.y + t * 0.5, 0), Vector3(inner.x + 2 * t, t, inner.z + 2 * t), c_floor.darkened(0.1))
	static_box(n, center + Vector3(-h.x - t * 0.5, 0, 0), Vector3(t, inner.y, inner.z + 2 * t), c_wall)
	static_box(n, center + Vector3(h.x + t * 0.5, 0, 0), Vector3(t, inner.y, inner.z + 2 * t), c_wall)
	static_box(n, center + Vector3(0, 0, -h.z - t * 0.5), Vector3(inner.x, inner.y, t), c_wall.darkened(0.05))
	static_box(n, center + Vector3(0, 0, h.z + t * 0.5), Vector3(inner.x, inner.y, t), c_wall.darkened(0.05))
	return n


## Standard light + environment for test rooms (levels use LevelBuilder).
static func basic_environment(parent: Node) -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.9)
	LevelBuilder.apply_exposure(e)
	env.environment = e
	parent.add_child(env)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation = Vector3(-1.0, 0.5, 0.0)
	LevelBuilder.setup_sun(light)
	parent.add_child(light)
