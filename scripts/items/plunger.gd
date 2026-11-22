class_name Plunger
extends ToolBase
## Plunger: push it onto a flat surface (tap Use) and it sticks with suction,
## anchoring you (counts as bracing!) or letting you drag heavy things.
## Release Use to unstick; in zero-G that pops you toward the surface.
## Stabbing a clog with it clears the clog.

var _suction: PinJoint3D = null
var _stuck_to: PhysicsBody3D = null
var _stuck_point: Vector3 = Vector3.ZERO


func _build() -> void:
	tool_id = "plunger"
	display_name = "Plunger"
	grip_offset = Vector3(0, 0, 0.22)
	tip_offset = Vector3(0, 0, -0.42)
	add_mesh(cyl(0.03, 0.62), Color(0.78, 0.55, 0.3), Vector3(0, 0, 0), Vector3(PI * 0.5, 0, 0))
	var cup: CylinderMesh = CylinderMesh.new()
	cup.top_radius = 0.07
	cup.bottom_radius = 0.15
	cup.height = 0.14
	add_mesh(cup, Color(0.9, 0.15, 0.2), Vector3(0, 0, -0.36), Vector3(-PI * 0.5, 0, 0))
	add_box_shape(Vector3(0.08, 0.08, 0.62), Vector3.ZERO)
	add_box_shape(Vector3(0.26, 0.26, 0.12), Vector3(0, 0, -0.36))


func get_use_label() -> String:
	if is_anchoring() or _suction != null:
		return "UNSTICK"
	var clog: Node3D = find_near_tip("clogs", 0.9)
	return "PLUNGE" if clog != null else "STICK"


func is_anchoring() -> bool:
	return _suction != null and is_instance_valid(_stuck_to) and (_stuck_to is StaticBody3D or (_stuck_to is RigidBody3D and (_stuck_to as RigidBody3D).mass > Tuning.MAX_CARRY_MASS))


func _use_pressed() -> void:
	var clog: Node3D = find_near_tip("clogs", 0.9)
	if clog != null and clog.has_method("plunge"):
		clog.call("plunge", holder)
		AudioManager.play_at("plunger_thwock", tip_position())
		return
	var hit: Dictionary = ray_from_tip(0.4)
	if hit.is_empty():
		return
	var col: Object = hit.get("collider")
	if not (col is PhysicsBody3D):
		return
	_stuck_to = col as PhysicsBody3D
	_stuck_point = hit["position"] as Vector3
	var j: PinJoint3D = PinJoint3D.new()
	j.name = "Suction"
	get_parent().add_child(j)
	j.global_position = _stuck_point
	j.node_a = j.get_path_to(self)
	j.node_b = j.get_path_to(_stuck_to)
	_suction = j
	AudioManager.play_at("plunger_thwock", _stuck_point)


func _use_released() -> void:
	_unstick(true)


func _unstick(pop: bool) -> void:
	if _suction == null:
		return
	if is_instance_valid(_suction):
		_suction.queue_free()
	_suction = null
	AudioManager.play_at("plunger_suck", _stuck_point)
	if pop and holder != null and holder.in_zero_g:
		var dir: Vector3 = (_stuck_point - holder.get_center()).normalized()
		for rb: RigidBody3D in holder.body_list:
			rb.linear_velocity += dir * 4.0
	_stuck_to = null


func _on_unequipped() -> void:
	_unstick(false)
