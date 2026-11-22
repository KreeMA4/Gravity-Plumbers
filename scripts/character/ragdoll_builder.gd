class_name RagdollBuilder
extends RefCounted
## Builds the plumber's physics rig: RigidBody3D parts + joints.
##
## Full rig (11 bodies): pelvis, chest, head, upper_arm_l/r, lower_arm_l/r
## (forearm + hand), thigh_l/r, shin_l/r (shin + foot).
## Simple rig (7 bodies, Quality "Simple ragdoll"): pelvis, chest, head,
## arm_l/r (whole arm + hand), leg_l/r (whole leg + foot).
##
## Rest pose: standing upright facing -Z, feet at y = 0, every body with the
## SAME rotation as the root. So a joint target of IDENTITY means "rest pose".
##
## Joint notes (Godot 4 + Jolt):
##  - ConeTwistJoint3D twists around the joint's local X axis, so we point X
##    along the bone.
##  - HingeJoint3D hinges around the joint's local Z axis, so we point Z
##    along the body's left-right axis.
##  - MEASURED (gameplay E2E, Jolt): the hinge's own angle runs OPPOSITE to the
##    muscles' rotation about +X (LimbController targets). So a knee that the
##    muscles bend with a NEGATIVE X rotation needs hinge limits [-0.1, +2.4],
##    and an elbow bent with a POSITIVE X rotation needs [-2.5, +0.15]. (The
##    old limits had the signs the other way round: knees and elbows could only
##    bend the wrong way and were pinned straight at the +0.1 stop, which is a
##    big part of why the walk looked stiff and floaty.)
##  - node_a = parent body, node_b = child body. Both bodies are placed BEFORE
##    the joint gets its node paths, because the joint remembers their relative
##    positions at that moment.

const ROLE_HAND_L: String = "hand_l"
const ROLE_HAND_R: String = "hand_r"


## Name of the body that carries the foot on a side.
static func foot_name(side: String, simple: bool) -> String:
	return ("leg_" if simple else "shin_") + side


## Returns a Dictionary:
##  "bodies": {name: RigidBody3D}, "rest": {name: Transform3D (local to root)},
##  "limbs": {role: [child_name, parent_name, strength]},
##  "hand_l"/"hand_r": [body_name, local offset Vector3 of the palm],
##  "foot_l"/"foot_r": body name, "joints": Array of Joint3D, "total_mass": float
static func build(root: Node3D, look: PlumberLook, simple: bool) -> Dictionary:
	var sc: Vector4 = PlumberLook.build_scales(look.get_v("build") if look != null else 0)
	var hs: float = sc.x     # height
	var ws: float = sc.y     # width
	var ls: float = sc.z     # limb thickness
	var head_s: float = sc.w
	var out: Dictionary = {"bodies": {}, "rest": {}, "limbs": {}, "joints": [], "total_mass": 0.0}
	var hip_y: float = 0.76 * hs
	var waist_y: float = 0.97 * hs
	var neck_y: float = 1.31 * hs
	var shoulder_y: float = 1.26 * hs
	var arm_x: float = 0.29 * ws
	var leg_x: float = 0.1 * ws
	# --- torso ---
	_body(root, out, "pelvis", Vector3(0, 0.86 * hs, 0), Tuning.PLUMBER_MASS_PELVIS,
		[_box(Vector3(0.34 * ws, 0.2 * hs, 0.24 * ws))], Tuning.BODY_FRICTION)
	_body(root, out, "chest", Vector3(0, 1.14 * hs, 0), Tuning.PLUMBER_MASS_CHEST,
		[_box(Vector3(0.42 * ws, 0.32 * hs, 0.28 * ws))], Tuning.BODY_FRICTION)
	_body(root, out, "head", Vector3(0, neck_y + 0.2 * head_s, 0), Tuning.PLUMBER_MASS_HEAD,
		[_sphere(0.21 * head_s, Vector3.ZERO)], Tuning.BODY_FRICTION)
	_cone(root, out, "pelvis", "chest", Vector3(0, waist_y, 0), Vector3.UP, 0.45, 0.4)
	_cone(root, out, "chest", "head", Vector3(0, neck_y, 0), Vector3.UP, 0.6, 0.8)
	out["limbs"]["spine"] = ["chest", "pelvis", 1.2]
	out["limbs"]["neck"] = ["head", "chest", 0.6]
	var arm_r: float = 0.065 * ls
	var leg_r: float = 0.085 * ls
	for side: String in ["l", "r"]:
		var sx: float = -1.0 if side == "l" else 1.0
		if simple:
			var arm_len: float = 0.58 * hs
			var arm_c: Vector3 = Vector3(sx * arm_x, shoulder_y - arm_len * 0.5, 0)
			_body(root, out, "arm_" + side, arm_c, Tuning.PLUMBER_MASS_LIMB * 2.0,
				[_capsule(arm_r, arm_len, Vector3.ZERO), _sphere(0.08 * ls, Vector3(0, -arm_len * 0.5, 0))],
				Tuning.BODY_FRICTION, true)
			_cone(root, out, "chest", "arm_" + side, Vector3(sx * arm_x, shoulder_y, 0), Vector3.DOWN, 2.4, 1.0)
			out["limbs"]["shoulder_" + side] = ["arm_" + side, "chest", 1.0]
			out["hand_" + side] = ["arm_" + side, Vector3(0, -arm_len * 0.5 - 0.03, 0)]
			var leg_len: float = hip_y - 0.08
			var leg_c: Vector3 = Vector3(sx * leg_x, hip_y - leg_len * 0.5, 0)
			_body(root, out, "leg_" + side, leg_c, Tuning.PLUMBER_MASS_LIMB * 2.5,
				[_capsule(leg_r, leg_len, Vector3.ZERO),
				_box(Vector3(0.13 * ws, 0.08, 0.26), Vector3(0, -leg_len * 0.5 - 0.04, -0.05))],
				Tuning.FOOT_FRICTION)
			_cone(root, out, "pelvis", "leg_" + side, Vector3(sx * leg_x, hip_y, 0), Vector3.DOWN, 1.5, 0.4)
			out["limbs"]["hip_" + side] = ["leg_" + side, "pelvis", 1.2]
			out["foot_" + side] = "leg_" + side
		else:
			var up_len: float = 0.29 * hs
			var lo_len: float = 0.27 * hs
			var elbow_y: float = shoulder_y - up_len
			_body(root, out, "upper_arm_" + side, Vector3(sx * arm_x, shoulder_y - up_len * 0.5, 0),
				Tuning.PLUMBER_MASS_LIMB, [_capsule(arm_r, up_len, Vector3.ZERO)], Tuning.BODY_FRICTION)
			_body(root, out, "lower_arm_" + side, Vector3(sx * arm_x, elbow_y - lo_len * 0.5, 0),
				Tuning.PLUMBER_MASS_LIMB, [_capsule(arm_r * 0.92, lo_len, Vector3.ZERO), _sphere(0.08 * ls, Vector3(0, -lo_len * 0.5 - 0.02, 0))],
				Tuning.BODY_FRICTION, true)
			_cone(root, out, "chest", "upper_arm_" + side, Vector3(sx * arm_x, shoulder_y, 0), Vector3.DOWN, 2.4, 1.0)
			# Elbow: hinge around the left-right (X) axis; the muscles bend the forearm
			# forward with a positive X rotation (= negative hinge angle, see notes above).
			_hinge(root, out, "upper_arm_" + side, "lower_arm_" + side, Vector3(sx * arm_x, elbow_y, 0), Vector3.RIGHT, -2.5, 0.15)
			out["limbs"]["shoulder_" + side] = ["upper_arm_" + side, "chest", 1.0]
			out["limbs"]["elbow_" + side] = ["lower_arm_" + side, "upper_arm_" + side, 0.8]
			out["hand_" + side] = ["lower_arm_" + side, Vector3(0, -lo_len * 0.5 - 0.05, 0)]
			var th_len: float = hip_y - 0.38 * hs
			var knee_y: float = hip_y - th_len
			var sh_len: float = knee_y - 0.07
			_body(root, out, "thigh_" + side, Vector3(sx * leg_x, hip_y - th_len * 0.5, 0),
				Tuning.PLUMBER_MASS_LIMB * 1.5, [_capsule(leg_r, th_len, Vector3.ZERO)], Tuning.BODY_FRICTION)
			_body(root, out, "shin_" + side, Vector3(sx * leg_x, knee_y - sh_len * 0.5, 0),
				Tuning.PLUMBER_MASS_LIMB * 1.3,
				[_capsule(leg_r * 0.9, sh_len, Vector3.ZERO),
				_box(Vector3(0.13 * ws, 0.08, 0.26), Vector3(0, -sh_len * 0.5 - 0.03, -0.05))],
				Tuning.FOOT_FRICTION)
			_cone(root, out, "pelvis", "thigh_" + side, Vector3(sx * leg_x, hip_y, 0), Vector3.DOWN, 1.6, 0.4)
			# Knee: the muscles bend the shin backward with a negative X rotation
			# (= positive hinge angle, see notes above), like a real knee.
			_hinge(root, out, "thigh_" + side, "shin_" + side, Vector3(sx * leg_x, knee_y, 0), Vector3.RIGHT, -0.1, 2.4)
			out["limbs"]["hip_" + side] = ["thigh_" + side, "pelvis", 1.3]
			out["limbs"]["knee_" + side] = ["shin_" + side, "thigh_" + side, 1.0]
			out["foot_" + side] = "shin_" + side
	# No self-collision between a plumber's own parts (stable and less jittery).
	var list: Array = (out["bodies"] as Dictionary).values()
	for i: int in list.size():
		for j: int in range(i + 1, list.size()):
			(list[i] as RigidBody3D).add_collision_exception_with(list[j] as RigidBody3D)
	return out


# --- helpers -------------------------------------------------------------------

static func _box(size: Vector3, offset: Vector3 = Vector3.ZERO) -> Array:
	var s: BoxShape3D = BoxShape3D.new()
	s.size = size
	return [s, offset]


static func _sphere(radius: float, offset: Vector3) -> Array:
	var s: SphereShape3D = SphereShape3D.new()
	s.radius = radius
	return [s, offset]


static func _capsule(radius: float, length: float, offset: Vector3) -> Array:
	var s: CapsuleShape3D = CapsuleShape3D.new()
	s.radius = radius
	s.height = maxf(length, radius * 2.0 + 0.01)
	return [s, offset]


static func _body(root: Node3D, out: Dictionary, body_name: String, local_pos: Vector3, mass: float,
		shapes: Array, friction: float, ccd: bool = false) -> RigidBody3D:
	var rb: RigidBody3D = RigidBody3D.new()
	rb.name = body_name.capitalize().replace(" ", "")
	rb.mass = mass
	rb.can_sleep = false
	rb.linear_damp = Tuning.PLUMBER_LINEAR_DAMP
	rb.angular_damp = Tuning.PLUMBER_ANGULAR_DAMP
	rb.continuous_cd = ccd
	rb.collision_layer = Layers.PLUMBERS
	rb.collision_mask = Layers.MASK_SOLID
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = friction
	pm.bounce = 0.05
	rb.physics_material_override = pm
	for sh: Variant in shapes:
		var pair: Array = sh as Array
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = pair[0] as Shape3D
		cs.position = pair[1] as Vector3
		rb.add_child(cs)
	rb.position = local_pos
	rb.add_child(GravityBody.new())
	rb.add_to_group("plumber_parts")
	root.add_child(rb)
	(out["bodies"] as Dictionary)[body_name] = rb
	(out["rest"] as Dictionary)[body_name] = Transform3D(Basis.IDENTITY, local_pos)
	out["total_mass"] = float(out["total_mass"]) + mass
	return rb


static func _basis_with_x(x_axis: Vector3) -> Basis:
	var x: Vector3 = x_axis.normalized()
	var y: Vector3 = GravityMath.perpendicular(x)
	var z: Vector3 = x.cross(y).normalized()
	return Basis(x, y, z)


static func _basis_with_z(z_axis: Vector3) -> Basis:
	var z: Vector3 = z_axis.normalized()
	var x: Vector3 = GravityMath.perpendicular(z)
	var y: Vector3 = z.cross(x).normalized()
	return Basis(x, y, z)


static func _cone(root: Node3D, out: Dictionary, a_name: String, b_name: String, local_pos: Vector3,
		twist_axis: Vector3, swing: float, twist: float) -> void:
	var a: RigidBody3D = (out["bodies"] as Dictionary)[a_name]
	var b: RigidBody3D = (out["bodies"] as Dictionary)[b_name]
	var j: ConeTwistJoint3D = ConeTwistJoint3D.new()
	j.name = "J_" + b_name
	root.add_child(j)
	j.global_transform = root.global_transform * Transform3D(_basis_with_x(twist_axis), local_pos)
	j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, swing)
	j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, twist)
	j.exclude_nodes_from_collision = true
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)
	(out["joints"] as Array).append(j)


static func _hinge(root: Node3D, out: Dictionary, a_name: String, b_name: String, local_pos: Vector3,
		axis: Vector3, lower: float, upper: float) -> void:
	var a: RigidBody3D = (out["bodies"] as Dictionary)[a_name]
	var b: RigidBody3D = (out["bodies"] as Dictionary)[b_name]
	var j: HingeJoint3D = HingeJoint3D.new()
	j.name = "J_" + b_name
	root.add_child(j)
	j.global_transform = root.global_transform * Transform3D(_basis_with_z(axis), local_pos)
	j.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	j.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, lower)
	j.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, upper)
	j.exclude_nodes_from_collision = true
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)
	(out["joints"] as Array).append(j)
