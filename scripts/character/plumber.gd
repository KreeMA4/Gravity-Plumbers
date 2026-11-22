class_name Plumber
extends Node3D
## A wobbly space plumber: an active ragdoll made of 11 (or 7) RigidBody3D
## parts held together by joints.
##
## ONE physics rig, three "modes", blended by stiffness:
##   ACTIVE     joints are muscles (PD controllers) pulling toward a walk pose,
##              a hover spring holds the pelvis at standing height and an
##              upright controller keeps chest and pelvis pointing along local up.
##   RAGDOLL    almost limp (a little leftover muscle). Triggered by hard hits,
##              unbraced gravity shifts, hazards, being swung, or the Flop button.
##   GETTING_UP muscles ramp back up (with a dizzy wobble afterwards).
##
## "Local up" is the opposite of gravity at the pelvis (or the surface normal
## when magnetic boots are on), so plumbers stand on walls, ceilings and
## planetoids. The host runs all of this; network clients only see puppets.

signal state_changed(new_state: int)
signal flushed(plumber: Plumber)
signal respawned(plumber: Plumber)
signal impact(strength: float, at: Vector3)
signal jumped(plumber: Plumber)
signal landed(plumber: Plumber)

enum State { ACTIVE, RAGDOLL, GETTING_UP, FLUSHED }

var peer_id: int = 1
var net_id: int = 0
var player_index: int = 0
var display_name: String = "Plumber"
var look: PlumberLook = null
var input: PlumberInput = PlumberInput.new()
var is_puppet: bool = false
var simple_rig: bool = false
var spawn_transform: Transform3D = Transform3D.IDENTITY
var respawn_provider: Callable = Callable()   ## optional () -> Transform3D

# Rig
var bodies: Dictionary = {}          ## part name -> RigidBody3D
var body_list: Array[RigidBody3D] = []
var gravity_bodies: Array[GravityBody] = []
var rest: Dictionary = {}            ## part name -> Transform3D relative to the spawn frame
var limbs: Dictionary = {}           ## role -> LimbController
var pelvis: RigidBody3D
var chest: RigidBody3D
var head: RigidBody3D
var hand_bodies: Dictionary = {}     ## "l"/"r" -> RigidBody3D
var hand_offsets: Dictionary = {}    ## "l"/"r" -> Vector3 (local palm position)
var total_mass: float = 1.0
var height_scale: float = 1.0
var cosmetics: Dictionary = {}
var face: PlumberFace = null
var grab_hands: Dictionary = {}      ## "l"/"r" -> GrabHand (set up in M4)

# State
var state: State = State.ACTIVE
var state_time: float = 0.0
var joint_stiffness: float = 1.0
var support: float = 1.0
var dizzy_time: float = 0.0
var ragdoll_min_time: float = 1.2
var local_up: Vector3 = Vector3.UP
var facing: Vector3 = Vector3.FORWARD
var move_dir: Vector3 = Vector3.ZERO
var grounded: bool = false
var near_ground: bool = false
var ground_dist: float = 99.0
var ground_normal: Vector3 = Vector3.UP
var ground_body: Object = null
var in_zero_g: bool = false
var boots_on: bool = false
var boots_active: bool = false       ## boots on AND stuck to a surface
var boots_charge: float = 6.0
var boots_normal: Vector3 = Vector3.UP
var walk_phase: float = 0.0
var emote_time: float = 0.0
var emote_id: int = 0
var celebrate_time: float = 0.0
var held_by: Dictionary = {}         ## Plumber -> true while someone grabs us (M4)
var flush_count: int = 0
var grab_time_total: float = 0.0     ## for the silly end-of-level awards
var ragdoll_count: int = 0

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _jump_hold: float = 0.0
var _no_hover: float = 0.0
var _prev_buttons: int = 0
var _prev_v_pelvis: Vector3 = Vector3.ZERO
var _prev_v_chest: Vector3 = Vector3.ZERO
var _skip_impact: int = 2
var _was_grounded: bool = false
var _exclude: Array[RID] = []


## Call before add_child().
func setup(xform: Transform3D, plumber_look: PlumberLook, peer: int, index: int) -> void:
	spawn_transform = xform
	look = plumber_look if plumber_look != null else PlumberLook.default_for(index)
	peer_id = peer
	player_index = index
	name = "Plumber_%d" % index


func _ready() -> void:
	add_to_group("plumbers")
	global_transform = spawn_transform
	simple_rig = Quality.simple_ragdoll
	height_scale = PlumberLook.build_scales(look.get_v("build")).x
	var rig: Dictionary = RagdollBuilder.build(self, look, simple_rig)
	bodies = rig["bodies"]
	rest = rig["rest"]
	total_mass = float(rig["total_mass"])
	pelvis = bodies["pelvis"]
	chest = bodies["chest"]
	head = bodies["head"]
	for b: Variant in bodies.values():
		var rb: RigidBody3D = b as RigidBody3D
		body_list.append(rb)
		_exclude.append(rb.get_rid())
		rb.set_meta("plumber", self)
		for child: Node in rb.get_children():
			if child is GravityBody:
				var gb: GravityBody = child as GravityBody
				gravity_bodies.append(gb)
				gb.out_of_bounds.connect(_on_part_out_of_bounds)
	var limb_defs: Dictionary = rig["limbs"]
	for role: String in limb_defs.keys():
		var d: Array = limb_defs[role]
		limbs[role] = LimbController.new(bodies[str(d[0])] as RigidBody3D, bodies[str(d[1])] as RigidBody3D, float(d[2]))
	for side: String in ["l", "r"]:
		var h: Array = rig["hand_" + side]
		hand_bodies[side] = bodies[str(h[0])]
		hand_offsets[side] = h[1]
	cosmetics = PlumberMeshBuilder.build(bodies, look, simple_rig, Quality.outlines_on_players)
	face = PlumberFace.new(self, cosmetics)
	boots_charge = Tuning.BOOTS_CHARGE_MAX
	local_up = spawn_transform.basis.y.normalized()
	facing = -spawn_transform.basis.z.normalized()
	_setup_grab_hands()
	GravityManager.shift_started.connect(_on_gravity_shift)


## One GrabHand per arm (see grab_hand.gd).
func _setup_grab_hands() -> void:
	for side: String in ["l", "r"]:
		var gh: GrabHand = GrabHand.new()
		gh.name = "GrabHand_" + side
		add_child(gh)
		gh.init_hand(self, side)
		grab_hands[side] = gh


# --- Public API ----------------------------------------------------------------

func get_center() -> Vector3:
	return pelvis.global_position if is_instance_valid(pelvis) else global_position


## Interpolated position for cameras (smooth at any frame rate).
func get_center_interpolated() -> Vector3:
	if not is_instance_valid(pelvis):
		return global_position
	return pelvis.get_global_transform_interpolated().origin


func get_hand_position(side: String) -> Vector3:
	var b: RigidBody3D = hand_bodies.get(side) as RigidBody3D
	if b == null:
		return get_center()
	return b.global_transform * (hand_offsets[side] as Vector3)


func get_velocity() -> Vector3:
	return pelvis.linear_velocity if is_instance_valid(pelvis) else Vector3.ZERO


func is_ragdoll() -> bool:
	return state == State.RAGDOLL


func is_flushed() -> bool:
	return state == State.FLUSHED


## Braced plumbers don't fly away when gravity shifts.
func is_braced() -> bool:
	if boots_active:
		return true
	for gh: Variant in grab_hands.values():
		if (gh as GrabHand).is_anchored():
			return true
	return false


## Go limp for at least `min_time` seconds.
func go_ragdoll(min_time: float = -1.0) -> void:
	if state == State.FLUSHED or is_puppet:
		return
	ragdoll_min_time = min_time if min_time > 0.0 else Tuning.RAGDOLL_MIN_TIME
	if state != State.RAGDOLL:
		ragdoll_count += 1
	_set_state(State.RAGDOLL)


## A little victory grin + hop (work order done).
func celebrate() -> void:
	celebrate_time = 1.5


func start_emote(id: int) -> void:
	emote_id = clampi(id, 0, 4)
	emote_time = 2.0


## Teleport the whole ragdoll so its pelvis frame matches `xform`.
func teleport(xform: Transform3D) -> void:
	for gh: Variant in grab_hands.values():
		(gh as GrabHand).release()
	for part: String in bodies.keys():
		var rb: RigidBody3D = bodies[part]
		rb.global_transform = xform * (rest[part] as Transform3D)
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.reset_physics_interpolation()
	local_up = xform.basis.y.normalized()
	facing = -xform.basis.z.normalized()
	_prev_v_pelvis = Vector3.ZERO
	_prev_v_chest = Vector3.ZERO
	_skip_impact = 3


## Out of bounds / kill volume: swirl away and respawn after a delay.
func flush() -> void:
	if state == State.FLUSHED or is_puppet:
		return
	flush_count += 1
	for gh: Variant in grab_hands.values():
		(gh as GrabHand).release()
	FX.flush_swirl(get_parent(), get_center())
	AudioManager.play_at("flush", get_center())
	_set_state(State.FLUSHED)
	visible = false
	for rb: RigidBody3D in body_list:
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.freeze = true
	flushed.emit(self)


func respawn() -> void:
	var xform: Transform3D = spawn_transform
	if respawn_provider.is_valid():
		var v: Variant = respawn_provider.call(self)
		if v is Transform3D:
			xform = v as Transform3D
	for rb: RigidBody3D in body_list:
		rb.freeze = false
	teleport(xform)
	visible = true
	_set_state(State.GETTING_UP)
	respawned.emit(self)


## Client-side puppets: frozen kinematic bodies moved by network snapshots.
func set_puppet(on: bool) -> void:
	is_puppet = on
	for rb: RigidBody3D in body_list:
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rb.freeze = on
	for gb: GravityBody in gravity_bodies:
		gb.set_physics_process(not on)


# --- Main loop -----------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if not is_instance_valid(pelvis):
		return
	if is_puppet:
		face.update(dt)
		return
	state_time += dt
	if state == State.FLUSHED:
		if state_time >= Tuning.RESPAWN_DELAY:
			respawn()
		return
	_update_up(dt)
	_probe_ground()
	_handle_buttons(dt)
	_update_state(dt)
	_apply_support(dt)
	_apply_movement(dt)
	_apply_jump(dt)
	_update_limb_targets(dt)
	for role: Variant in limbs.keys():
		(limbs[role] as LimbController).update(dt, joint_stiffness)
	_check_impacts()
	face.update(dt)
	_prev_buttons = input.buttons
	if emote_time > 0.0:
		emote_time -= dt
	if celebrate_time > 0.0:
		celebrate_time -= dt


func _pressed(bit: int) -> bool:
	return input.held(bit) and (_prev_buttons & bit) == 0


func _set_state(s: State) -> void:
	if state == s:
		return
	state = s
	state_time = 0.0
	state_changed.emit(int(s))


func _update_up(dt: float) -> void:
	var g: Vector3 = GravityManager.get_gravity_at(pelvis.global_position)
	for gb: GravityBody in gravity_bodies:
		if gb.has_override():
			g = gb.current_gravity()
			break
	in_zero_g = g.length_squared() < 0.25 and not boots_active
	# Magnetic boots: find a surface and make its normal our "up".
	boots_active = false
	if boots_on and boots_charge > 0.0 and state != State.RAGDOLL:
		var hit: Dictionary = _find_boot_surface()
		if not hit.is_empty():
			boots_active = true
			boots_normal = (hit["normal"] as Vector3).normalized()
		boots_charge = maxf(0.0, boots_charge - dt)
		if boots_charge <= 0.0:
			boots_on = false
	elif not boots_on:
		boots_charge = minf(Tuning.BOOTS_CHARGE_MAX, boots_charge + Tuning.BOOTS_RECHARGE_RATE * dt)
	for gb2: GravityBody in gravity_bodies:
		gb2.cancel_field = boots_active
	var target: Vector3 = local_up
	if boots_active:
		target = boots_normal
	elif not in_zero_g:
		target = -g.normalized()
	var rate: float = Tuning.BOOTS_UP_SMOOTH if boots_active else 10.0
	local_up = GravityMath.rotate_dir(local_up, target, 1.0 - exp(-dt * rate)).normalized()
	GravityManager.debug_probe = pelvis.global_position if player_index == 0 else GravityManager.debug_probe


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.PROPS | Layers.PLUMBERS, _exclude)
	return space.intersect_ray(q)


func _find_boot_surface() -> Dictionary:
	var from: Vector3 = pelvis.global_position
	var reach: float = Tuning.RIDE_HEIGHT * height_scale + Tuning.BOOTS_RANGE
	var hit: Dictionary = _ray(from, from - local_up * reach)
	if not hit.is_empty():
		return hit
	# Nothing under us: look around for the nearest surface (walls, ceilings).
	var best: Dictionary = {}
	var best_d: float = 999.0
	for axis: Variant in GravityMath.AXES:
		var d: Vector3 = axis as Vector3
		var h: Dictionary = _ray(from, from + d * reach)
		if not h.is_empty():
			var dist: float = from.distance_to(h["position"] as Vector3)
			if dist < best_d:
				best_d = dist
				best = h
	return best


func _probe_ground() -> void:
	var from: Vector3 = pelvis.global_position
	var length: float = Tuning.GROUND_PROBE_LENGTH * height_scale
	var hit: Dictionary = _ray(from, from - local_up * length)
	_was_grounded = grounded
	if hit.is_empty():
		near_ground = false
		grounded = false
		ground_dist = 99.0
		ground_body = null
		return
	near_ground = true
	ground_dist = from.distance_to(hit["position"] as Vector3)
	ground_normal = hit["normal"] as Vector3
	ground_body = hit.get("collider")
	grounded = ground_dist <= Tuning.RIDE_HEIGHT * height_scale + 0.2 and ground_normal.dot(local_up) > 0.45
	if grounded and not _was_grounded and state == State.ACTIVE:
		landed.emit(self)


func _handle_buttons(dt: float) -> void:
	if _pressed(PlumberInput.JUMP):
		_jump_buffer = Tuning.JUMP_BUFFER_TIME
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - dt)
	if _pressed(PlumberInput.BOOTS):
		boots_on = not boots_on and boots_charge > 0.5
		AudioManager.play_at("boots_clamp" if boots_on else "ui_back", get_center(), -4.0)
	if _pressed(PlumberInput.FLOP):
		go_ragdoll(0.8)
	if _pressed(PlumberInput.GET_UP) and state == State.RAGDOLL and state_time > 0.4:
		_set_state(State.GETTING_UP)
	if _pressed(PlumberInput.EMOTE):
		start_emote(input.emote_id if input.emote_id > 0 else look.get_v("emote"))


func _update_state(dt: float) -> void:
	match state:
		State.ACTIVE:
			if dizzy_time > 0.0:
				dizzy_time -= dt
				var t: float = 1.0 - clampf(dizzy_time / Tuning.DIZZY_TIME, 0.0, 1.0)
				joint_stiffness = lerpf(Tuning.STIFFNESS_DIZZY, Tuning.STIFFNESS_ACTIVE, t)
			else:
				joint_stiffness = Tuning.STIFFNESS_ACTIVE
			support = 1.0
			# Being swung around hard by a friend makes you go limp.
			if held_by.size() > 0 and pelvis.linear_velocity.length() > Tuning.SWING_RAGDOLL_SPEED:
				go_ragdoll()
		State.RAGDOLL:
			joint_stiffness = Tuning.STIFFNESS_RAGDOLL
			support = 0.0
			var slow: bool = pelvis.linear_velocity.length() < Tuning.RECOVER_MAX_SPEED
			var can_stand: bool = near_ground or in_zero_g or boots_on
			if state_time >= ragdoll_min_time and slow and can_stand and held_by.is_empty():
				_set_state(State.GETTING_UP)
			elif state_time >= Tuning.RAGDOLL_MAX_TIME and can_stand:
				_set_state(State.GETTING_UP)
		State.GETTING_UP:
			var t2: float = clampf(state_time / Tuning.GET_UP_TIME, 0.0, 1.0)
			var e: float = t2 * t2 * (3.0 - 2.0 * t2)
			support = e
			joint_stiffness = lerpf(Tuning.STIFFNESS_RAGDOLL, Tuning.STIFFNESS_DIZZY, e)
			if t2 >= 1.0:
				dizzy_time = Tuning.DIZZY_TIME
				_set_state(State.ACTIVE)


## Hover spring + upright torque. This is what keeps the ragdoll standing.
func _apply_support(dt: float) -> void:
	if support <= 0.0:
		return
	var up: Vector3 = local_up
	if grounded and _no_hover <= 0.0:
		var ride: float = Tuning.RIDE_HEIGHT * height_scale
		var v_up: float = pelvis.linear_velocity.dot(up)
		var g: Vector3 = GravityManager.get_gravity_at(pelvis.global_position)
		var hold: float = -g.dot(up)
		if boots_active:
			hold = Tuning.BOOTS_STICK_ACCEL
		var spring: float = minf(Tuning.RIDE_SPRING * (ride - ground_dist), 30.0)
		var accel: float = spring - Tuning.RIDE_DAMP * v_up + maxf(0.0, hold)
		accel = maxf(0.0, accel) * support
		pelvis.apply_central_force(up * accel * total_mass)
	_no_hover = maxf(0.0, _no_hover - dt)
	if boots_active:
		# Pull every part toward the surface (field gravity is cancelled).
		for rb: RigidBody3D in body_list:
			rb.apply_central_force(-boots_normal * Tuning.BOOTS_STICK_ACCEL * rb.mass)
	# Upright: rotate pelvis and chest so their Y follows local up and they face `facing`.
	var target: Basis = _target_basis(up, facing)
	var tq: Quaternion = target.get_rotation_quaternion()
	var k: float = support
	_upright(pelvis, tq, k, dt)
	var lean: float = -0.12 * clampf(move_dir.length(), 0.0, 1.0)
	_upright(chest, tq * Quaternion(Vector3.RIGHT, lean), k * 0.8, dt)


func _upright(rb: RigidBody3D, goal: Quaternion, k: float, dt: float) -> void:
	var err: Vector3 = LimbController.rotation_error(rb.global_basis.get_rotation_quaternion(), goal)
	var acc: Vector3 = err * Tuning.UPRIGHT_KP * k - rb.angular_velocity * Tuning.UPRIGHT_KD * sqrt(k)
	acc = acc.limit_length(Tuning.JOINT_MAX_ANG_ACCEL)
	var dw: Vector3 = acc * dt
	if dw.is_finite():
		rb.angular_velocity += dw


static func _target_basis(up: Vector3, fwd: Vector3) -> Basis:
	var y: Vector3 = up.normalized()
	var f: Vector3 = fwd - y * fwd.dot(y)
	if f.length_squared() < 0.0001:
		f = GravityMath.perpendicular(y)
	var z: Vector3 = -f.normalized()
	var x: Vector3 = y.cross(z).normalized()
	z = x.cross(y).normalized()
	return Basis(x, y, z)


func _apply_movement(dt: float) -> void:
	var up: Vector3 = local_up
	var aim: Vector3 = input.aim
	var fwd: Vector3 = aim - up * aim.dot(up)
	if fwd.length_squared() < 0.0025:
		fwd = facing
	fwd = fwd.normalized()
	var right: Vector3 = fwd.cross(up).normalized()
	var mv: Vector2 = input.move.limit_length(1.0)
	move_dir = right * mv.x + fwd * mv.y
	if state == State.RAGDOLL or state == State.FLUSHED:
		return
	# Turn to face the walking direction (or the aim while grabbing).
	var face_goal: Vector3 = move_dir
	if _any_grab_held():
		face_goal = fwd
	if face_goal.length_squared() > 0.01:
		facing = GravityMath.rotate_dir(facing, face_goal.normalized(), 1.0 - exp(-dt * Tuning.TURN_RATE)).normalized()
	facing = (facing - up * facing.dot(up))
	if facing.length_squared() < 0.0001:
		facing = fwd
	facing = facing.normalized()
	if in_zero_g and not near_ground:
		# Floating: weak thrusters in the full 3D aim direction.
		var thrust: Vector3 = right * mv.x + aim.normalized() * mv.y
		pelvis.apply_central_force(thrust * Tuning.ZERO_G_THRUST * total_mass * support)
		return
	var speed_max: float = Tuning.WALK_SPEED
	if boots_active:
		speed_max *= Tuning.BOOTS_SPEED_MULT
	if dizzy_time > 0.0 or state == State.GETTING_UP:
		speed_max *= 0.6
	var v: Vector3 = pelvis.linear_velocity
	var v_h: Vector3 = v - up * v.dot(up)
	var desired: Vector3 = move_dir * speed_max
	var control: float = 1.0 if grounded else Tuning.AIR_CONTROL
	if not grounded and mv.length() < 0.1:
		return   # no braking in the air without input
	var accel: Vector3 = (desired - v_h) * Tuning.WALK_ACCEL * control * support
	accel = accel.limit_length(Tuning.WALK_ACCEL * speed_max * 1.5)
	pelvis.apply_central_force(accel * total_mass * 0.6)
	chest.apply_central_force(accel * total_mass * 0.4)
	if grounded:
		walk_phase += dt * v_h.length() * Tuning.WALK_CYCLE_RATE * PI * 0.5


func _apply_jump(dt: float) -> void:
	if grounded:
		_coyote = Tuning.COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - dt)
	var can_jump: bool = state == State.ACTIVE and (_coyote > 0.0) and support > 0.9
	if _jump_buffer > 0.0 and can_jump:
		var mult: float = Tuning.BOOTS_JUMP_MULT if boots_active else 1.0
		if boots_active:
			boots_on = false   # jumping off a wall pops your boots
		var jv: float = Tuning.JUMP_SPEED * mult
		for rb: RigidBody3D in body_list:
			var vu: float = rb.linear_velocity.dot(local_up)
			rb.linear_velocity += local_up * maxf(0.0, jv - vu)
		_jump_buffer = 0.0
		_coyote = 0.0
		_jump_hold = Tuning.JUMP_HOLD_TIME
		_no_hover = 0.3
		_skip_impact = 2
		AudioManager.play_at("jump", get_center(), -2.0, look.voice_pitch())
		jumped.emit(self)
	if _jump_hold > 0.0:
		_jump_hold -= dt
		if input.held(PlumberInput.JUMP):
			pelvis.apply_central_force(local_up * Tuning.JUMP_HOLD_FORCE * total_mass)
		else:
			_jump_hold = 0.0


func _any_grab_held() -> bool:
	return input.held(PlumberInput.GRAB_L) or input.held(PlumberInput.GRAB_R)


## Procedural poses: walk cycle, air flail, emotes. Grab arms are aimed by GrabHand.
func _update_limb_targets(_dt: float) -> void:
	var ident: Quaternion = Quaternion.IDENTITY
	if state == State.RAGDOLL:
		for role: Variant in limbs.keys():
			var lc: LimbController = limbs[role]
			lc.target = ident
			lc.use_world = false
		return
	var v: Vector3 = pelvis.linear_velocity
	var v_h: Vector3 = v - local_up * v.dot(local_up)
	var spd: float = clampf(v_h.length() / Tuning.WALK_SPEED, 0.0, 1.0)
	var s: float = sin(walk_phase)
	var c: float = cos(walk_phase)
	var airborne: bool = not grounded and not in_zero_g
	var leg_swing: float = s * Tuning.WALK_LEG_SWING * spd
	_set_target("hip_l", Quaternion(Vector3.RIGHT, leg_swing if not airborne else 0.5))
	_set_target("hip_r", Quaternion(Vector3.RIGHT, -leg_swing if not airborne else -0.2))
	_set_target("knee_l", Quaternion(Vector3.RIGHT, -(maxf(0.0, c) * 1.1 * spd + 0.08) if not airborne else -0.9))
	_set_target("knee_r", Quaternion(Vector3.RIGHT, -(maxf(0.0, -c) * 1.1 * spd + 0.08) if not airborne else -0.4))
	_set_target("spine", ident)
	_set_target("neck", ident)
	var arm_swing: float = s * Tuning.WALK_ARM_SWING * spd
	for side: String in ["l", "r"]:
		var sx: float = -1.0 if side == "l" else 1.0
		var shoulder: Quaternion
		if airborne:
			# Arms flail upward when falling (comedy!).
			var flap: float = sin(state_time * 14.0 + sx) * 0.4
			shoulder = Quaternion(Vector3.BACK, sx * (2.0 + flap))
		elif in_zero_g:
			shoulder = Quaternion(Vector3.BACK, sx * 1.2) * Quaternion(Vector3.RIGHT, sin(state_time * 3.0 + sx) * 0.3)
		else:
			# Arms swing opposite to the leg on the same side.
			var swing: float = -arm_swing if side == "l" else arm_swing
			shoulder = Quaternion(Vector3.RIGHT, swing) * Quaternion(Vector3.BACK, sx * 0.14)
		if emote_time > 0.0:
			shoulder = _emote_pose(side, sx)
		elif celebrate_time > 0.0:
			shoulder = Quaternion(Vector3.BACK, sx * (2.6 + sin(state_time * 12.0) * 0.2))
		_set_target("shoulder_" + side, shoulder)
		_set_target("elbow_" + side, Quaternion(Vector3.RIGHT, 0.35 + spd * 0.35))


func _emote_pose(side: String, sx: float) -> Quaternion:
	var t: float = state_time
	match emote_id:
		0:  # dance: arms pump up and down
			return Quaternion(Vector3.BACK, sx * (1.4 + sin(t * 10.0 + sx * 1.5) * 0.9))
		1:  # wave with the right arm
			if side == "r":
				return Quaternion(Vector3.BACK, 2.7) * Quaternion(Vector3.RIGHT, sin(t * 12.0) * 0.5)
		2:  # flex
			return Quaternion(Vector3.BACK, sx * 1.55)
		3:  # cry: hands to face
			return Quaternion(Vector3.RIGHT, 2.2) * Quaternion(Vector3.BACK, -sx * 0.5)
		4:  # point forward
			if side == "r":
				return Quaternion(Vector3.RIGHT, 1.55)
	return Quaternion(Vector3.BACK, sx * 0.14)


func _set_target(role: String, q: Quaternion) -> void:
	var lc: LimbController = limbs.get(role) as LimbController
	if lc != null and not lc.use_world:
		lc.target = q


func _check_impacts() -> void:
	var vp: Vector3 = pelvis.linear_velocity
	var vc: Vector3 = chest.linear_velocity
	if _skip_impact > 0:
		_skip_impact -= 1
	else:
		var dv: float = maxf((vp - _prev_v_pelvis).length(), (vc - _prev_v_chest).length())
		if dv > 3.0:
			impact.emit(dv, get_center())
			face.squash(clampf(dv / 12.0, 0.1, 0.5))
			AudioManager.play_at("impact_%d" % (1 if dv < 6.0 else (2 if dv < 10.0 else 3)), get_center(), -3.0)
		if dv > Tuning.RAGDOLL_IMPACT_DV and state != State.RAGDOLL:
			go_ragdoll()
	_prev_v_pelvis = vp
	_prev_v_chest = vc


func _on_gravity_shift(_new_dir: Vector3) -> void:
	if is_puppet or state == State.FLUSHED:
		return
	if not is_braced():
		go_ragdoll(1.4)


func _on_part_out_of_bounds(_body: RigidBody3D) -> void:
	flush()


func _exit_tree() -> void:
	if GravityManager.shift_started.is_connected(_on_gravity_shift):
		GravityManager.shift_started.disconnect(_on_gravity_shift)
