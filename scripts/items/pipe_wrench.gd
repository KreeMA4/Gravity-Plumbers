class_name PipeWrench
extends ToolBase
## Pipe wrench: hold Use on a valve to turn it (some valves need two players),
## hold it on a loose pipe joint to tighten it, or tap it at a friend (or a
## crate) to BONK them. Bonked plumbers go floppy and bounce. Comedy!

const BONK_RADIUS: float = 0.45


func _build() -> void:
	tool_id = "wrench"
	display_name = "Pipe Wrench"
	grip_offset = Vector3(0, 0, 0.2)
	tip_offset = Vector3(0, 0, -0.38)
	add_mesh(boxm(Vector3(0.06, 0.04, 0.55)), Color(0.85, 0.2, 0.22), Vector3.ZERO)
	add_mesh(boxm(Vector3(0.2, 0.06, 0.08)), Color(0.7, 0.72, 0.78), Vector3(0.04, 0, -0.3))
	add_mesh(boxm(Vector3(0.06, 0.06, 0.12)), Color(0.7, 0.72, 0.78), Vector3(0.12, 0, -0.36))
	add_box_shape(Vector3(0.08, 0.06, 0.55), Vector3.ZERO)
	add_box_shape(Vector3(0.22, 0.08, 0.12), Vector3(0.05, 0, -0.32))
	mass = 3.0


func get_use_label() -> String:
	if find_near_tip("valves", 1.0) != null:
		return "TURN"
	if find_near_tip("loose_joints", 0.9) != null:
		return "TIGHTEN"
	return "BONK"


func _use_held(dt: float) -> void:
	var v: Node3D = find_near_tip("valves", 1.0)
	if v != null and v.has_method("wrench_turn"):
		v.call("wrench_turn", dt, holder)
		return
	var lj: Node3D = find_near_tip("loose_joints", 0.9)
	if lj != null and lj.has_method("tighten"):
		lj.call("tighten", dt, holder)


func _use_pressed() -> void:
	if find_near_tip("valves", 1.0) != null or find_near_tip("loose_joints", 0.9) != null:
		AudioManager.play_at("wrench_clank", tip_position(), -4.0)
		return
	if cooldown > 0.0:
		return
	cooldown = 0.5
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = BONK_RADIUS
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, tip_position())
	q.collision_mask = Layers.PROPS | Layers.PLUMBERS
	var ex: Array[RID] = [get_rid()]
	ex.append_array(holder._exclude)
	q.exclude = ex
	var hits: Array[Dictionary] = space.intersect_shape(q, 6)
	var bonked: Dictionary = {}
	for h: Dictionary in hits:
		var col: Object = h.get("collider")
		if not (col is RigidBody3D):
			continue
		var rb: RigidBody3D = col as RigidBody3D
		var op: Variant = Plumber.of(rb)
		var push: Vector3 = (aim_dir() + holder.local_up * 0.4).normalized() * 5.0
		if op is Plumber:
			var other: Plumber = op as Plumber
			if bonked.has(other):
				continue
			bonked[other] = true
			other.go_ragdoll(1.0)
			other.face.squash(0.5)
			for orb: RigidBody3D in other.body_list:
				orb.linear_velocity += push
		else:
			rb.apply_central_impulse(push * rb.mass * 0.5)
	if hits.size() > 0:
		AudioManager.play_at("wrench_clank", tip_position(), 0.0, 1.2)
		FX.stars(get_parent(), tip_position())
	else:
		AudioManager.play_at("whoosh", tip_position(), -6.0)
