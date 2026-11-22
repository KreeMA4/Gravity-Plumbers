class_name ToolBase
extends RigidBody3D
## Base class for the four tools. A tool is a normal prop until a plumber
## grabs it with the RIGHT hand: then it gets "equipped" - glued to the hand
## with a Generic6DOFJoint3D (all axes locked) so it follows the arm.
## Hold / tap Use to use it (subclasses implement _use_pressed/_use_held).
## Tap Grab R again to drop it. Lost tools return to their rack after a while.

signal used(tool: ToolBase)

var tool_id: String = "tool"
var display_name: String = "Tool"
var holder: Plumber = null
var hand: GrabHand = null
var grip_offset: Vector3 = Vector3.ZERO   ## local point that sits in the palm
var tip_offset: Vector3 = Vector3(0, 0, -0.5)  ## local point that does the work
var cooldown: float = 0.0
var net_id: int = 0
var rack_transform: Transform3D = Transform3D.IDENTITY

var _joint: Generic6DOFJoint3D = null
var _prev_use: bool = false
var _lost_timer: float = -1.0
var _gravity: GravityBody


func _init() -> void:
	mass = 2.0
	collision_layer = Layers.PROPS
	collision_mask = Layers.MASK_SOLID
	continuous_cd = true
	add_to_group("tools")
	add_to_group("grabbable")
	add_to_group("props")


func _ready() -> void:
	_build()
	_gravity = GravityBody.new()
	add_child(_gravity)
	_gravity.out_of_bounds.connect(_on_lost)
	rack_transform = global_transform


## Subclasses add meshes and collision shapes here.
func _build() -> void:
	pass


## Label shown on the Use button while holding this tool.
func get_use_label() -> String:
	return "USE"


func tip_position() -> Vector3:
	return global_transform * tip_offset


func aim_dir() -> Vector3:
	if holder != null:
		return holder.input.aim.normalized()
	return -global_basis.z


func equip(p: Plumber, h: GrabHand) -> void:
	if holder != null or p == null:
		return
	if h.tool != null:
		return
	holder = p
	hand = h
	var hand_body: RigidBody3D = h.get_hand_body()
	for rb: RigidBody3D in p.body_list:
		add_collision_exception_with(rb)
	# Line the tool up with the forearm: tool -Z (its "forward") along the arm's down.
	var hb: Basis = hand_body.global_basis
	var tool_basis: Basis = Basis(hb.x, -hb.z, hb.y).orthonormalized()
	var palm: Vector3 = p.get_hand_position(h.side)
	global_transform = Transform3D(tool_basis, palm - tool_basis * grip_offset)
	linear_velocity = hand_body.linear_velocity
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()
	var j: Generic6DOFJoint3D = Generic6DOFJoint3D.new()
	j.name = "ToolJoint"
	p.add_child(j)
	j.global_position = palm
	j.node_a = j.get_path_to(hand_body)
	j.node_b = j.get_path_to(self)
	_joint = j
	h.set_tool(self)
	_prev_use = true
	AudioManager.play_at("grab", palm, -2.0)
	_on_equipped()


func unequip() -> void:
	if _joint != null and is_instance_valid(_joint):
		_joint.queue_free()
	_joint = null
	if holder != null and is_instance_valid(holder):
		for rb: RigidBody3D in holder.body_list:
			if is_instance_valid(rb):
				remove_collision_exception_with(rb)
	_on_unequipped()
	if hand != null and is_instance_valid(hand):
		hand.tool = null
	holder = null
	hand = null


func _on_equipped() -> void:
	pass


func _on_unequipped() -> void:
	pass


func _use_pressed() -> void:
	pass


func _use_held(_dt: float) -> void:
	pass


func _use_released() -> void:
	pass


func _physics_process(dt: float) -> void:
	cooldown = maxf(0.0, cooldown - dt)
	if _lost_timer >= 0.0:
		_lost_timer -= dt
		if _lost_timer < 0.0:
			_return_to_rack()
		return
	if holder == null:
		return
	if not is_instance_valid(holder) or holder.is_puppet:
		unequip()
		return
	var use_now: bool = holder.input.held(PlumberInput.USE)
	if use_now and not _prev_use:
		_use_pressed()
	elif use_now:
		_use_held(dt)
	elif _prev_use:
		_use_released()
	_prev_use = use_now


## Something within `radius` of the tip that is in `group`, or null.
func find_near_tip(group: String, radius: float) -> Node3D:
	var tip: Vector3 = tip_position()
	var best: Node3D = null
	var best_d: float = radius
	for n: Node in get_tree().get_nodes_in_group(group):
		var n3: Node3D = n as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		var d: float = n3.global_position.distance_to(tip)
		if n3.has_method("interact_distance"):
			d = float(n3.call("interact_distance", tip))
		if d < best_d:
			best_d = d
			best = n3
	return best


## Ray from the tip along the aim (excluding the holder and this tool).
func ray_from_tip(length: float, mask: int = Layers.WORLD | Layers.PROPS | Layers.PLUMBERS) -> Dictionary:
	var from: Vector3 = tip_position()
	var to: Vector3 = from + aim_dir() * length
	var ex: Array[RID] = [get_rid()]
	if holder != null:
		ex.append_array(holder._exclude)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, mask, ex)
	return get_world_3d().direct_space_state.intersect_ray(q)


func _on_lost(_b: RigidBody3D) -> void:
	if holder != null:
		unequip()
	freeze = true
	visible = false
	_lost_timer = Tuning.TOOL_RESPAWN_TIME


func _return_to_rack() -> void:
	_lost_timer = -1.0
	global_transform = rack_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	visible = true
	reset_physics_interpolation()
	FX.stars(get_parent(), global_position)


# --- mesh helpers for subclasses ----------------------------------------------

func add_box_shape(size: Vector3, at: Vector3) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = at
	add_child(cs)


func add_mesh(mesh: Mesh, color: Color, at: Vector3, rot: Vector3 = Vector3.ZERO, glow: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	var outline: bool = Quality.outlines_on_props
	mi.material_override = Mats.toon_glow(color, glow, outline) if glow > 0.0 else Mats.toon(color, outline)
	mi.position = at
	mi.rotation = rot
	add_child(mi)
	return mi


static func cyl(r: float, h: float) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	return c


static func boxm(size: Vector3) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	return b
