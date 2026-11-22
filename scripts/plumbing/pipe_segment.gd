class_name PipeSegment
extends RigidBody3D
## A loose pipe piece you carry to a PipePort ("Reconnect the pipe").
## It snaps in when close enough and roughly aligned, then locks in place.

var piece_id: String = ""
var length: float = 1.2
var radius: float = 0.16
var is_locked: bool = false
var net_id: int = 0


func _init() -> void:
	mass = 6.0
	collision_layer = Layers.PROPS
	collision_mask = Layers.MASK_SOLID
	add_to_group("grabbable")
	add_to_group("props")
	add_to_group("pipe_pieces")
	add_to_group("pickups")


func _ready() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var pts: PackedVector3Array = PackedVector3Array([Vector3(0, -length * 0.5, 0), Vector3(0, length * 0.5, 0)])
	mi.mesh = PipeBuilder.tube(pts, radius)
	mi.material_override = Mats.toon(LevelBuilder.PIPE_COLORS["teal"] as Color, Quality.outlines_on_props)
	add_child(mi)
	for sy: float in [-1.0, 1.0]:
		var f: MeshInstance3D = MeshInstance3D.new()
		f.mesh = PipeBuilder.flange_mesh(radius)
		f.material_override = Mats.toon((LevelBuilder.PIPE_COLORS["teal"] as Color).darkened(0.3))
		f.position = Vector3(0, sy * length * 0.45, 0)
		add_child(f)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var c: CylinderShape3D = CylinderShape3D.new()
	c.radius = radius * 1.3
	c.height = length
	cs.shape = c
	add_child(cs)
	add_child(GravityBody.new())


func can_pick_up() -> bool:
	return not is_locked


func get_interact_name() -> String:
	return "Pipe Piece"


## Carried crossways in front of you (the pipe's axis is its local Y).
func carry_rotation() -> Quaternion:
	return Quaternion(Vector3.BACK, -PI * 0.5)


## True while a plumber carries it (picked up with Interact).
func is_carried() -> bool:
	for p: Node in get_tree().get_nodes_in_group("plumbers"):
		var pl: Plumber = p as Plumber
		if pl != null and pl.held_item() == self:
			return true
	return false


func lock_into(xform: Transform3D) -> void:
	is_locked = true
	# Let go of every hand holding us.
	for p: Node in get_tree().get_nodes_in_group("plumbers"):
		var pl: Plumber = p as Plumber
		for gh: Variant in pl.grab_hands.values():
			var hand: GrabHand = gh as GrabHand
			if hand.target == self:
				hand.release()
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	global_transform = xform
	reset_physics_interpolation()
	remove_from_group("grabbable")
	remove_from_group("pickups")
	add_to_group("grabbable_static")
