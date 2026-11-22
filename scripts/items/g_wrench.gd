class_name GWrench
extends ToolBase
## The G-Wrench, the gravity tool! Aim at a crate or a teammate and tap Use:
## its gravity now points along the world axis closest to where you aimed,
## for 8 s (15 s cooldown). Aim at a wall/ceiling instead to give YOURSELF a
## custom "down" toward that surface. The host decides; everyone sees it.

signal zapped(target: Node3D, dir: Vector3)

var _beam: MeshInstance3D = null
var _beam_time: float = 0.0


func _build() -> void:
	tool_id = "gwrench"
	display_name = "G-Wrench"
	grip_offset = Vector3(0, 0, 0.2)
	tip_offset = Vector3(0, 0, -0.42)
	add_mesh(boxm(Vector3(0.07, 0.05, 0.55)), Color(0.35, 0.3, 0.55), Vector3.ZERO)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.07
	ring.outer_radius = 0.12
	add_mesh(ring, Color(1.0, 0.85, 0.2), Vector3(0, 0, -0.34), Vector3(PI * 0.5, 0, 0), 0.6)
	var orb: SphereMesh = SphereMesh.new()
	orb.radius = 0.05
	orb.height = 0.1
	add_mesh(orb, Color(0.4, 1.0, 1.0), Vector3(0, 0, -0.34), Vector3.ZERO, 1.0)
	add_box_shape(Vector3(0.1, 0.08, 0.55), Vector3.ZERO)
	add_box_shape(Vector3(0.24, 0.24, 0.08), Vector3(0, 0, -0.34))
	_beam = MeshInstance3D.new()
	var cm: CylinderMesh = cyl(0.03, 1.0)
	_beam.mesh = cm
	_beam.material_override = Mats.glow(Color(0.5, 1.0, 1.0, 0.8))
	_beam.visible = false
	_beam.top_level = true
	add_child(_beam)


func get_use_label() -> String:
	if cooldown > 0.0:
		return "%ds" % ceili(cooldown)
	return "ZAP"


func _use_pressed() -> void:
	if cooldown > 0.0:
		AudioManager.play_ui("ui_back", -4.0)
		return
	var hit: Dictionary = ray_from_tip(Tuning.G_WRENCH_RANGE)
	if hit.is_empty():
		return
	var col: Object = hit.get("collider")
	var at: Vector3 = hit["position"] as Vector3
	var axis: Vector3 = GravityMath.AXES[GravityMath.nearest_axis_index(aim_dir())] as Vector3
	var applied: bool = false
	if col is RigidBody3D:
		var rb: RigidBody3D = col as RigidBody3D
		var op: Variant = rb.get_meta("plumber", null)
		if op is Plumber:
			var other: Plumber = op as Plumber
			for gb: GravityBody in other.gravity_bodies:
				gb.set_override(axis, Tuning.G_WRENCH_DURATION, Tuning.GRAVITY_STRENGTH)
			other.go_ragdoll(0.8)
			zapped.emit(other, axis)
			applied = true
		else:
			for child: Node in rb.get_children():
				if child is GravityBody:
					(child as GravityBody).set_override(axis, Tuning.G_WRENCH_DURATION, Tuning.GRAVITY_STRENGTH)
					zapped.emit(rb, axis)
					applied = true
	elif col is StaticBody3D:
		# Custom stick direction for yourself: "down" = into that surface.
		var n: Vector3 = hit["normal"] as Vector3
		for gb2: GravityBody in holder.gravity_bodies:
			gb2.set_override(-n, Tuning.G_WRENCH_DURATION, Tuning.GRAVITY_STRENGTH)
		zapped.emit(holder, -n)
		applied = true
	if applied:
		cooldown = Tuning.G_WRENCH_COOLDOWN
		_show_beam(tip_position(), at)
		AudioManager.play_at("gravity_whoomp", at, -2.0, 1.4)
		FX.sparks(get_parent(), at, hit["normal"] as Vector3)


func _show_beam(a: Vector3, b: Vector3) -> void:
	var length: float = a.distance_to(b)
	if length < 0.05:
		return
	_beam.global_transform = Transform3D(PipeBuilder.basis_along(b - a) * Basis.from_scale(Vector3(1, length, 1)), (a + b) * 0.5)
	_beam.visible = true
	_beam_time = 0.25


func _process(delta: float) -> void:
	if _beam_time > 0.0:
		_beam_time -= delta
		if _beam_time <= 0.0:
			_beam.visible = false
