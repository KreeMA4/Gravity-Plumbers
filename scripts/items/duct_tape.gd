class_name DuctTape
extends ToolBase
## Duct tape: hold Use on a leak to seal it. Tap it on a crate to tape the
## crate in place for a few seconds (handy when gravity is about to flip).

const TAPE_PROP_TIME: float = 10.0

var _taped: Dictionary = {}   ## RigidBody3D -> seconds left


func _build() -> void:
	tool_id = "tape"
	display_name = "Duct Tape"
	grip_offset = Vector3(0, 0, 0.05)
	tip_offset = Vector3(0, 0, -0.18)
	var roll: TorusMesh = TorusMesh.new()
	roll.inner_radius = 0.06
	roll.outer_radius = 0.13
	add_mesh(roll, Color(0.72, 0.74, 0.8), Vector3(0, 0, -0.08), Vector3(0, 0, PI * 0.5))
	add_mesh(boxm(Vector3(0.1, 0.01, 0.12)), Color(0.75, 0.77, 0.82), Vector3(0, -0.12, -0.16))
	add_box_shape(Vector3(0.12, 0.26, 0.26), Vector3(0, 0, -0.08))
	mass = 1.0


func get_use_label() -> String:
	return "TAPE"


func _use_held(dt: float) -> void:
	var leak: Node3D = find_near_tip("leaks", 1.0)
	if leak != null and leak.has_method("tape"):
		leak.call("tape", dt, holder)
		if randf() < dt * 3.0:
			AudioManager.play_at("tape_rip", tip_position(), -6.0, 1.0, 0.2)


func _use_pressed() -> void:
	if find_near_tip("leaks", 1.0) != null:
		AudioManager.play_at("tape_rip", tip_position())
		return
	var hit: Dictionary = ray_from_tip(0.6, Layers.PROPS)
	if hit.is_empty():
		return
	var col: Object = hit.get("collider")
	if col is RigidBody3D and not (col is ToolBase) and (col as RigidBody3D).get_meta("plumber", null) == null:
		var rb: RigidBody3D = col as RigidBody3D
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rb.freeze = true
		_taped[rb] = TAPE_PROP_TIME
		AudioManager.play_at("tape_rip", hit["position"] as Vector3)


func _physics_process(dt: float) -> void:
	super._physics_process(dt)
	for rb: Variant in _taped.keys():
		var body: RigidBody3D = rb as RigidBody3D
		if not is_instance_valid(body):
			_taped.erase(rb)
			continue
		var left: float = float(_taped[rb]) - dt
		if left <= 0.0:
			body.freeze = false
			_taped.erase(rb)
		else:
			_taped[rb] = left
