class_name GooPool
extends Node3D
## A pool of sludge blobs (cheap fluid!). Blobs are small RigidBody3D
## spheres with a GravityBody and the goo shader. Inactive blobs are removed
## from physics (process_mode DISABLED) and hidden, so the budget of
## Tuning.GOO_BLOB_COUNT is never exceeded and nothing is created mid-game.

var blobs: Array = []        ## Array of RigidBody3D
var _free: Array = []
var _life: Dictionary = {}   ## blob -> seconds left (blobs fade after a while)

const LIFETIME: float = 40.0


func _ready() -> void:
	name = "GooPool"
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = Tuning.GOO_BLOB_RADIUS
	mesh.height = Tuning.GOO_BLOB_RADIUS * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = Tuning.GOO_BLOB_RADIUS
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.6
	for i: int in Tuning.GOO_BLOB_COUNT:
		var rb: RigidBody3D = RigidBody3D.new()
		rb.name = "Goo_%d" % i
		rb.mass = 0.3
		rb.collision_layer = Layers.GOO
		rb.collision_mask = Layers.WORLD | Layers.PROPS | Layers.PLUMBERS | Layers.GOO
		rb.physics_material_override = pm
		rb.linear_damp = 0.3
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = shape
		rb.add_child(cs)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = Mats.goo()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rb.add_child(mi)
		var gb: GravityBody = GravityBody.new()
		rb.add_child(gb)
		rb.add_to_group("goo")
		rb.set_meta("goo_index", i)
		rb.position = Vector3(0, -500 - i, 0)
		rb.process_mode = Node.PROCESS_MODE_DISABLED
		rb.visible = false
		add_child(rb)
		gb.out_of_bounds.connect(func(b: RigidBody3D) -> void: release(b))
		blobs.append(rb)
		_free.append(rb)


func active_count() -> int:
	return blobs.size() - _free.size()


## Spawn a blob (returns null when the pool is empty).
func spawn(pos: Vector3, vel: Vector3) -> RigidBody3D:
	if _free.is_empty():
		return null
	var rb: RigidBody3D = _free.pop_back()
	rb.process_mode = Node.PROCESS_MODE_INHERIT
	rb.global_position = pos
	rb.linear_velocity = vel
	rb.angular_velocity = Vector3.ZERO
	rb.visible = true
	rb.reset_physics_interpolation()
	_life[rb] = LIFETIME
	return rb


func release(rb: RigidBody3D) -> void:
	if rb == null or _free.has(rb):
		return
	rb.linear_velocity = Vector3.ZERO
	rb.visible = false
	rb.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	rb.set_deferred("global_position", Vector3(0, -500, 0))
	_life.erase(rb)
	_free.append(rb)


func burst(pos: Vector3, dir: Vector3, count: int, speed: float) -> void:
	for i: int in count:
		var r: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.5
		spawn(pos + r * 0.2, (dir.normalized() + r).normalized() * speed * randf_range(0.6, 1.0))


func _physics_process(dt: float) -> void:
	for rb: Variant in _life.keys():
		var left: float = float(_life[rb]) - dt
		if left <= 0.0:
			release(rb as RigidBody3D)
		else:
			_life[rb] = left


## Network: positions of active blobs [index, pos] for snapshots.
func get_active() -> Array:
	var out: Array = []
	for rb: Variant in _life.keys():
		var b: RigidBody3D = rb as RigidBody3D
		out.append([int(b.get_meta("goo_index")), b.global_position])
	return out


# --- Network clients: blobs are just shown where the host says ---------------

func client_show(index: int, pos: Vector3) -> void:
	if index < 0 or index >= blobs.size() or not pos.is_finite():
		return
	var rb: RigidBody3D = blobs[index] as RigidBody3D
	if _free.has(rb):
		_free.erase(rb)
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rb.freeze = true
		rb.process_mode = Node.PROCESS_MODE_INHERIT
		rb.visible = true
		rb.global_position = pos
		rb.reset_physics_interpolation()
	else:
		rb.global_position = pos


func client_hide_except(seen: Dictionary) -> void:
	for i: int in blobs.size():
		if seen.has(i):
			continue
		var rb: RigidBody3D = blobs[i] as RigidBody3D
		if not _free.has(rb):
			rb.visible = false
			rb.process_mode = Node.PROCESS_MODE_DISABLED
			_free.append(rb)
