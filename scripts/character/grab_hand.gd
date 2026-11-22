class_name GrabHand
extends Node
## One plumber hand. While its Grab button is held, the arm reaches where the
## camera looks (the Human Fall Flat feel). When the palm touches something
## grabbable, a PinJoint3D glues hand and target together at that point.
## Static things (pipes, ledges, walls) pin the hand to the world, which
## also counts as "bracing" against gravity shifts. Letting go destroys the
## joint; whatever you were swinging keeps its momentum (= throwing).
##
## Targets can react: if the grabbed body (or its owner) has
##   on_grab(plumber, side) / on_release(plumber, side)
## those are called (tools, valve handles, switches use this).

signal grabbed(target: Node)
signal released(target: Node)

var plumber: Plumber
var side: String = "l"
var bit: int = PlumberInput.GRAB_L
var joint: Joint3D = null
var target: PhysicsBody3D = null
var target_owner: Node = null        ## node that receives on_grab/on_release
var hold_time: float = 0.0
var tool: Node = null                ## a ToolBase held in this hand (right hand only)

var _shape: SphereShape3D = SphereShape3D.new()
var _cooldown: float = 0.0
var _prev_held: bool = false


func init_hand(p: Plumber, hand_side: String) -> void:
	plumber = p
	side = hand_side
	bit = PlumberInput.GRAB_L if side == "l" else PlumberInput.GRAB_R
	_shape.radius = Tuning.GRAB_RADIUS


func is_holding() -> bool:
	return joint != null and is_instance_valid(joint)


## Holding something that won't move with us = bracing.
func is_anchored() -> bool:
	if tool != null and is_instance_valid(tool) and tool.has_method("is_anchoring") and bool(tool.call("is_anchoring")):
		return true   # e.g. a plunger stuck to the wall
	if not is_holding() or not is_instance_valid(target):
		return false
	if target is StaticBody3D:
		return true
	if target is RigidBody3D:
		var rb: RigidBody3D = target as RigidBody3D
		if rb.freeze or rb.mass > Tuning.MAX_CARRY_MASS:
			return true
		# Holding a teammate who is themselves braced also counts.
		var other: Variant = rb.get_meta("plumber", null)
		if other is Plumber and other != plumber:
			var op: Plumber = other as Plumber
			for gh: Variant in op.grab_hands.values():
				var h: GrabHand = gh as GrabHand
				if h.is_holding() and h.target is StaticBody3D:
					return true
	return false


func get_hand_body() -> RigidBody3D:
	return plumber.hand_bodies.get(side) as RigidBody3D


func _physics_process(dt: float) -> void:
	if plumber == null or plumber.is_puppet:
		return
	_cooldown = maxf(0.0, _cooldown - dt)
	var lc_key: String = "shoulder_" + side
	var shoulder: LimbController = plumber.limbs.get(lc_key) as LimbController
	var active: bool = plumber.state == Plumber.State.ACTIVE or plumber.state == Plumber.State.GETTING_UP
	var held_now: bool = plumber.input.held(bit)
	var pressed: bool = held_now and not _prev_held
	_prev_held = held_now
	var wants: bool = held_now and active
	if tool != null and is_instance_valid(tool):
		# Holding a tool: the arm points where you aim so Use hits the right spot.
		# Tap Grab R again to drop it. Going limp drops it too.
		_aim_arm(shoulder, true)
		if pressed or plumber.state == Plumber.State.RAGDOLL or plumber.state == Plumber.State.FLUSHED:
			drop_tool()
			_cooldown = 0.4
		return
	if not wants:
		if is_holding():
			release(true)
		if shoulder != null:
			shoulder.use_world = false
		return
	_aim_arm(shoulder, true)
	if is_holding():
		hold_time += dt
		plumber.grab_time_total += dt
		# Break the grab if the hand got yanked far from the grab point.
		if not is_instance_valid(target):
			release(false)
			return
		var hand_pos: Vector3 = plumber.get_hand_position(side)
		var anchor: Vector3 = (joint as Node3D).global_position
		if hand_pos.distance_to(anchor) > Tuning.GRAB_BREAK_DISTANCE:
			release(false)
		return
	if _cooldown <= 0.0:
		_try_grab()


func _aim_arm(shoulder: LimbController, on: bool) -> void:
	if shoulder == null:
		return
	shoulder.use_world = on
	if not on:
		return
	var aim: Vector3 = plumber.input.aim.normalized()
	# Reach a bit lower than the camera line so grabbing the floor/props in front works.
	var dir: Vector3 = (aim - plumber.local_up * 0.15).normalized()
	var chest_q: Quaternion = plumber.chest.global_basis.get_rotation_quaternion()
	var down_now: Vector3 = chest_q * Vector3.DOWN
	shoulder.target_world = GravityMath.quat_between(down_now, dir) * chest_q
	# Straighten the elbow while reaching.
	var elbow: LimbController = plumber.limbs.get("elbow_" + side) as LimbController
	if elbow != null:
		elbow.target = Quaternion(Vector3.RIGHT, 0.1)


func _try_grab() -> void:
	var hand: RigidBody3D = get_hand_body()
	if hand == null:
		return
	var pos: Vector3 = plumber.get_hand_position(side)
	var space: PhysicsDirectSpaceState3D = plumber.get_world_3d().direct_space_state
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = _shape
	q.transform = Transform3D(Basis.IDENTITY, pos)
	q.collision_mask = Layers.WORLD | Layers.PROPS | Layers.PLUMBERS | Layers.GOO
	q.exclude = plumber._exclude
	var hits: Array[Dictionary] = space.intersect_shape(q, 8)
	var best: PhysicsBody3D = null
	var best_score: float = -1.0
	for h: Dictionary in hits:
		var col: Object = h.get("collider")
		if not (col is PhysicsBody3D):
			continue
		var pb: PhysicsBody3D = col as PhysicsBody3D
		var score: float = 1.0
		if pb is RigidBody3D:
			var rb: RigidBody3D = pb as RigidBody3D
			if rb.mass > Tuning.MAX_CARRY_MASS and not rb.freeze:
				score = 0.5        # too heavy to carry, but you can hang on
			else:
				score = 3.0
			if rb.is_in_group("tools") and side == "r":
				score = 5.0
		elif pb.is_in_group("grab_handles"):
			score = 4.0
		if score > best_score:
			best_score = score
			best = pb
	if best == null:
		return
	# Tools go into the right hand as an equipped tool instead of a plain grab.
	if best.is_in_group("tools") and side == "r" and best.has_method("equip"):
		best.call("equip", plumber, self)
		return
	_attach(hand, best, pos)


func _attach(hand: RigidBody3D, other: PhysicsBody3D, at: Vector3) -> void:
	var j: PinJoint3D = PinJoint3D.new()
	j.name = "Grab_" + side
	plumber.add_child(j)
	j.global_position = at
	j.exclude_nodes_from_collision = true
	j.node_a = j.get_path_to(hand)
	j.node_b = j.get_path_to(other)
	joint = j
	target = other
	hold_time = 0.0
	target_owner = _find_owner(other)
	var op: Variant = other.get_meta("plumber", null)
	if op is Plumber:
		(op as Plumber).held_by[plumber] = true
	if target_owner != null and target_owner.has_method("on_grab"):
		target_owner.call("on_grab", plumber, side)
	AudioManager.play_at("grab", at, -4.0)
	grabbed.emit(other)


## Gameplay objects put their logic on the body itself or a parent with on_grab().
func _find_owner(n: Node) -> Node:
	var cur: Node = n
	for i: int in 3:
		if cur == null:
			return null
		if cur.has_method("on_grab"):
			return cur
		cur = cur.get_parent()
	return null


func release(throw: bool = false) -> void:
	if joint != null and is_instance_valid(joint):
		joint.queue_free()
	joint = null
	if target != null and is_instance_valid(target):
		var op: Variant = target.get_meta("plumber", null)
		if op is Plumber:
			(op as Plumber).held_by.erase(plumber)
		if throw and target is RigidBody3D:
			var rb: RigidBody3D = target as RigidBody3D
			if rb.linear_velocity.length() > 2.0:
				rb.linear_velocity *= Tuning.THROW_BOOST
		if target_owner != null and is_instance_valid(target_owner) and target_owner.has_method("on_release"):
			target_owner.call("on_release", plumber, side)
		AudioManager.play_at("release", plumber.get_hand_position(side), -6.0)
		released.emit(target)
	target = null
	target_owner = null
	_cooldown = 0.15


## Called by ToolBase when it gets equipped / dropped.
func set_tool(t: Node) -> void:
	tool = t


func drop_tool() -> void:
	if tool != null and is_instance_valid(tool) and tool.has_method("unequip"):
		tool.call("unequip")
	tool = null
