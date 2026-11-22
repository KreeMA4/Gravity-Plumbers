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
var walk_phase: float = 0.0          ## gait cycle (radians); left leg at walk_phase, right at +PI
var gait_amount: float = 0.0         ## 0 standing .. 1 full stride (smoothed)
var gait_run: float = 0.0            ## 0 walk .. 1 run (smoothed)
var gait_ride: float = 0.86          ## pelvis ride height the gait asks for this tick
var land_squash: float = 0.0         ## > 0 right after a landing: knees soak it up
var emote_time: float = 0.0
var emote_id: int = 0
var celebrate_time: float = 0.0
var hand_full_remote: bool = false   ## clients: host says our right hand holds an item/tool
var held_by: Dictionary = {}         ## Plumber -> true while someone grabs us (M4)
var flush_count: int = 0
var grab_time_total: float = 0.0     ## for the silly end-of-level awards
var ragdoll_count: int = 0

var puppet_velocity: Vector3 = Vector3.ZERO
var _blob: MeshInstance3D = null
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
var _leg_l1: float = 0.38            ## thigh length
var _leg_l2: float = 0.38            ## knee to sole
var _hip_off: Dictionary = {}        ## side -> hip joint, local to the pelvis
var _sole_off: Dictionary = {}       ## side -> sole point, local to the foot body
var _stance_prev: Dictionary = {"l": true, "r": true}
var _land_t: float = 0.0


## The plumber a physics body belongs to, or null. (Uses has_meta first:
## get_meta(key, null) prints an error in Godot 4 when the key is missing.)
static func of(obj: Object) -> Plumber:
	if obj == null or not is_instance_valid(obj) or not obj.has_meta("plumber"):
		return null
	return obj.get_meta("plumber") as Plumber


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
	# Network clients build puppets with the HOST's rig type so poses line up.
	simple_rig = NetManager.puppet_simple_rig if NetManager.is_client() else Quality.simple_ragdoll
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
	for role: String in ["hip_l", "hip_r", "knee_l", "knee_r"]:
		if limbs.has(role):
			(limbs[role] as LimbController).feed_forward = true
	for role: String in ["hip_l", "hip_r"]:
		if limbs.has(role):
			# Leg swings must not pitch the pelvis forward (that tipped the whole body
			# over while walking); the upright controller alone keeps the pelvis level.
			(limbs[role] as LimbController).reaction = 0.0
	for side: String in ["l", "r"]:
		var h: Array = rig["hand_" + side]
		hand_bodies[side] = bodies[str(h[0])]
		hand_offsets[side] = h[1]
	cosmetics = PlumberMeshBuilder.build(bodies, look, simple_rig, Quality.outlines_on_players)
	face = PlumberFace.new(self, cosmetics)
	boots_charge = Tuning.BOOTS_CHARGE_MAX
	local_up = spawn_transform.basis.y.normalized()
	facing = -spawn_transform.basis.z.normalized()
	_setup_leg_geometry()
	_setup_grab_hands()
	if Quality.blob_shadows:
		_blob = MeshInstance3D.new()
		_blob.name = "BlobShadow"
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(0.9, 0.9)
		_blob.mesh = pm
		_blob.material_override = Mats.blob_shadow()
		_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_blob.top_level = true
		add_child(_blob)
	GravityManager.shift_started.connect(_on_gravity_shift)


## Leg measurements for the gait IK (must match RagdollBuilder's proportions).
func _setup_leg_geometry() -> void:
	var sc: Vector4 = PlumberLook.build_scales(look.get_v("build") if look != null else 0)
	var hs: float = sc.x
	var ws: float = sc.y
	var hip_y: float = 0.76 * hs
	if simple_rig:
		_leg_l1 = hip_y * 0.5
		_leg_l2 = hip_y * 0.5
	else:
		_leg_l1 = hip_y - 0.38 * hs
		_leg_l2 = 0.38 * hs
	for side: String in ["l", "r"]:
		var sx: float = -1.0 if side == "l" else 1.0
		_hip_off[side] = Vector3(sx * 0.1 * ws, hip_y - 0.86 * hs, 0)
		if simple_rig:
			var leg_len: float = hip_y - 0.08
			_sole_off[side] = Vector3(0, -leg_len * 0.5 - 0.08, -0.05)
		else:
			var sh_len: float = 0.38 * hs - 0.07
			_sole_off[side] = Vector3(0, -sh_len * 0.5 - 0.07, -0.05)
	gait_ride = Tuning.RIDE_HEIGHT * height_scale


## World position of the bottom of a foot (tests and footstep effects).
func foot_sole_position(side: String) -> Vector3:
	var foot: RigidBody3D = bodies.get(RagdollBuilder.foot_name(side, simple_rig)) as RigidBody3D
	if foot == null:
		return get_center()
	return foot.global_transform * (_sole_off.get(side, Vector3.ZERO) as Vector3)


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
	if is_puppet:
		return puppet_velocity
	return pelvis.linear_velocity if is_instance_valid(pelvis) else Vector3.ZERO


## Network clients: copy the host's view of this plumber (for face, camera, HUD).
func apply_puppet_state(new_state: int, flags: int, up: Vector3, vel: Vector3) -> void:
	var s: State = clampi(new_state, 0, 3) as State
	if s != state:
		state = s
		state_time = 0.0
		state_changed.emit(int(s))
	visible = s != State.FLUSHED
	boots_on = (flags & SnapshotSync.F_BOOTS_ON) != 0
	boots_active = (flags & SnapshotSync.F_BOOTS_ACTIVE) != 0
	celebrate_time = 1.0 if (flags & SnapshotSync.F_CELEBRATE) != 0 else 0.0
	hand_full_remote = (flags & SnapshotSync.F_HAND_FULL) != 0
	if (flags & SnapshotSync.F_EMOTE) != 0:
		emote_time = 1.0
		emote_id = (flags >> 4) & 7
	else:
		emote_time = 0.0
	if up.is_finite() and up.length_squared() > 0.5:
		local_up = up.normalized()
	puppet_velocity = vel


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
		if get_velocity().length() > 4.0:
			AudioManager.play_at("whoosh", get_center(), -4.0)
			AudioManager.speak("aaah", look.voice_pitch() * 1.3, get_center())
	_set_state(State.RAGDOLL)


func has_tool() -> bool:
	var gh: GrabHand = grab_hands.get("r") as GrabHand
	return gh != null and gh.tool != null and is_instance_valid(gh.tool)


func get_tool() -> ToolBase:
	if not has_tool():
		return null
	return (grab_hands["r"] as GrabHand).tool as ToolBase


## Right hand busy with something picked up (a tool or a carried item)?
func is_hand_full() -> bool:
	if is_puppet:
		return hand_full_remote
	return held_item() != null


## The tool or item picked up with Interact (null if none / unknown on clients).
func held_item() -> Node3D:
	var gh: GrabHand = grab_hands.get("r") as GrabHand
	if gh == null:
		return null
	if gh.tool != null and is_instance_valid(gh.tool):
		return gh.tool as Node3D
	return gh.carried_item()


## Interact: tools go into the right hand as an equipped tool, anything else is carried.
func pick_up(item: Node3D) -> bool:
	var gh: GrabHand = grab_hands.get("r") as GrabHand
	if gh == null or item == null or not is_instance_valid(item) or is_hand_full():
		return false
	if item.has_method("can_pick_up") and not bool(item.call("can_pick_up")):
		return false
	if gh.is_holding():
		gh.release(false)   # the right hand lets go of a ledge to take the item
	if item is ToolBase:
		(item as ToolBase).equip(self, gh)
		return has_tool()
	if item is RigidBody3D:
		return gh.carry(item as RigidBody3D)
	return false


## Put the held tool/item down just in front of you.
func drop_item() -> void:
	var gh: GrabHand = grab_hands.get("r") as GrabHand
	if gh == null:
		return
	var it: Node3D = held_item()
	if gh.tool != null and is_instance_valid(gh.tool):
		gh.drop_tool()
	elif gh.carrying:
		gh.release(false)
	var rb: RigidBody3D = it as RigidBody3D
	if rb != null and is_instance_valid(rb):
		rb.linear_velocity = get_velocity() + facing * 1.2 + local_up * 0.8
	AudioManager.play_at("release", get_center(), -4.0)


## What the Interact button does right now (host side; the prompt uses the same query).
func _do_interact() -> void:
	var act: Interaction = Interaction.find(self, input.aim)
	match act.kind:
		Interaction.Kind.PICKUP:
			pick_up(act.node)
		Interaction.Kind.DROP:
			drop_item()
		Interaction.Kind.USE_OBJECT:
			act.node.call("interact", self)


## Is the Use button meaningful right now (held tool or a switch in reach)?
func can_use() -> bool:
	var tool_in_hand: bool = hand_full_remote if is_puppet else has_tool()
	return tool_in_hand or find_interactable() != null


## Nearest thing in group "interactables" (switches, buttons...) within reach.
func find_interactable() -> Node3D:
	var best: Node3D = null
	var best_d: float = 1.8
	var c: Vector3 = get_center()
	for n: Node in get_tree().get_nodes_in_group("interactables"):
		var n3: Node3D = n as Node3D
		if n3 == null or not n3.has_method("interact"):
			continue
		var d: float = n3.global_position.distance_to(c)
		if d < best_d:
			best_d = d
			best = n3
	return best


## What the Use button would do right now (shown on the button).
func get_use_label() -> String:
	var t: ToolBase = get_tool()
	if t != null:
		return t.get_use_label()
	var it: Node3D = find_interactable()
	if it != null and it.has_method("get_use_label"):
		return str(it.call("get_use_label"))
	return "USE"


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
	if _blob != null:
		_blob.visible = not on
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
		if _blob != null:
			_blob.visible = false
		near_ground = false
		grounded = false
		ground_dist = 99.0
		ground_body = null
		return
	near_ground = true
	ground_dist = from.distance_to(hit["position"] as Vector3)
	if _blob != null:
		var n: Vector3 = (hit["normal"] as Vector3).normalized()
		_blob.global_transform = Transform3D(PipeBuilder.basis_along(n), (hit["position"] as Vector3) + n * 0.02)
		_blob.visible = visible
		var k: float = clampf(1.0 - ground_dist / (length + 0.01), 0.3, 1.0)
		_blob.scale = Vector3(k, 1.0, k)
	ground_normal = hit["normal"] as Vector3
	ground_body = hit.get("collider")
	grounded = ground_dist <= Tuning.RIDE_HEIGHT * height_scale + 0.2 and ground_normal.dot(local_up) > 0.45
	if grounded and not _was_grounded and state == State.ACTIVE:
		landed.emit(self)
		var fall: float = -pelvis.linear_velocity.dot(local_up)
		if fall > 1.0:
			_land_t = 0.3
			land_squash = clampf(fall / 7.0, 0.15, 1.0)
		if pelvis.linear_velocity.dot(local_up) < -2.5:
			AudioManager.play_at("land", get_center(), -4.0)
			FX.dust(get_parent(), hit["position"] as Vector3, local_up)


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
	if _pressed(PlumberInput.INTERACT):
		_do_interact()
	if _pressed(PlumberInput.USE) and not has_tool():
		var it: Node3D = find_interactable()
		if it != null:
			it.call("interact", self)
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
		var ride: float = gait_ride
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
	# Weight shift: the hips roll a little toward the planted foot while walking.
	var roll: float = 0.0
	if grounded:
		roll = -sin(walk_phase) * 0.06 * gait_amount * (1.0 - gait_run)
	_upright(pelvis, tq * Quaternion(Vector3.BACK, roll), k, dt)
	# Lean into the movement: a little when walking, more when running.
	var lean: float = -(0.06 + 0.2 * gait_run) * gait_amount - 0.06 * clampf(move_dir.length(), 0.0, 1.0)
	if not grounded:
		lean = -0.12 * clampf(move_dir.length(), 0.0, 1.0)
	_upright(chest, tq * Quaternion(Vector3.RIGHT, lean) * Quaternion(Vector3.BACK, -roll * 0.6), k * 0.8, dt)


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
		FX.boing_ring(get_parent(), get_center() - local_up * Tuning.RIDE_HEIGHT * height_scale, local_up)
		jumped.emit(self)
	if _jump_hold > 0.0:
		_jump_hold -= dt
		if input.held(PlumberInput.JUMP):
			pelvis.apply_central_force(local_up * Tuning.JUMP_HOLD_FORCE * total_mass)
		else:
			_jump_hold = 0.0


func _any_grab_held() -> bool:
	return input.held(PlumberInput.GRAB_L) or input.held(PlumberInput.GRAB_R)


## Procedural poses: gait (walk/run with planted feet), jump/fall/land, idle,
## emotes. Grab arms are aimed by GrabHand. All of these are only TARGETS for
## the joint muscles (LimbController), so the body stays fully physical.
func _update_limb_targets(dt: float) -> void:
	var ident: Quaternion = Quaternion.IDENTITY
	if state == State.RAGDOLL:
		_set_foot_grip("l", Tuning.FOOT_FRICTION)
		_set_foot_grip("r", Tuning.FOOT_FRICTION)
		for role: Variant in limbs.keys():
			var lc: LimbController = limbs[role]
			lc.target = ident
			lc.use_world = false
			lc.boost = 1.0   # limp means limp
		return
	var up: Vector3 = local_up
	var v: Vector3 = pelvis.linear_velocity
	var v_up: float = v.dot(up)
	var v_h: Vector3 = v - up * v_up
	var speed: float = v_h.length()
	var airborne: bool = not grounded and not in_zero_g
	# --- gait state (smoothed so idle <-> walk <-> run blend) ---
	var on_feet: bool = grounded and not in_zero_g
	gait_amount = move_toward(gait_amount, Gait.amount(speed) if on_feet else 0.0, dt * 4.0)
	gait_run = move_toward(gait_run, Gait.run_blend(speed), dt * 2.5)
	var duty: float = Gait.duty(gait_run)
	if on_feet:
		walk_phase = fposmod(walk_phase + TAU * Gait.cadence(speed, height_scale) * dt, TAU * 64.0)
	_land_t = maxf(0.0, _land_t - dt)
	var squash: float = land_squash * (_land_t / 0.3)
	# Leg targets live in the UPRIGHT walking frame (local up + facing), not the
	# actual pelvis: if the pelvis wobbles, the feet still go where they should.
	var upq: Quaternion = _target_basis(up, facing).get_rotation_quaternion()
	var pinv: Basis = Basis(upq).inverse()
	# Stride direction in that frame (feet step the way you actually move).
	var dir_l: Vector3 = pinv * v_h
	dir_l.y = 0.0
	var dir2: Vector3 = dir_l.normalized() if dir_l.length() > 0.05 else Vector3.FORWARD
	var half: float = Gait.stance_length(speed, height_scale) * 0.5 * gait_amount
	var lift_h: float = Gait.lift_height(gait_run, height_scale) * gait_amount
	var hip_h: float = Gait.hip_height_for(0.0, _leg_l1, _leg_l2)
	var cyc: Dictionary = {}
	for side: String in ["l", "r"]:
		var ph: float = walk_phase + (0.0 if side == "l" else PI)
		var fc: Vector2 = Gait.foot_cycle(ph, duty)
		cyc[side] = fc
		var stance: bool = Gait.in_stance(ph, duty)
		if stance:
			# The pelvis rides only as high as the planted leg reaches: the walk bob.
			hip_h = minf(hip_h, Gait.hip_height_for(fc.x * half, _leg_l1, _leg_l2))
			if not bool(_stance_prev[side]) and gait_amount > 0.4 and on_feet:
				# A squelchy rubber footstep each time a foot comes down.
				AudioManager.play_at("footstep", foot_sole_position(side), -10.0, 1.0, 0.15)
		_stance_prev[side] = stance
		# The plumber is pushed along by forces on the body, not by the feet, so a
		# gripping foot acts as a pivot and tips the body forward (measured: the
		# pelvis pitched 50-60 deg). While walking, feet only PLACE themselves:
		# a planted foot slides a little, a swinging one slides freely. Standing
		# still, both feet grip fully again.
		var grip: float = Tuning.FOOT_FRICTION
		if on_feet and gait_amount >= 0.3:
			grip = Tuning.STANCE_FOOT_FRICTION if stance else Tuning.SWING_FOOT_FRICTION
		_set_foot_grip(side, grip)
	hip_h -= (0.035 * gait_run * gait_amount + 0.16 * squash) * height_scale   # run crouch, landing squash
	gait_ride = hip_h - (_hip_off["l"] as Vector3).y
	# --- legs --- (stronger leg muscles on foot so they keep up with the step cycle)
	var leg_boost: float = Tuning.LEG_STRENGTH_ON_FEET if on_feet else 1.5
	for role: String in ["hip_l", "hip_r", "knee_l", "knee_r"]:
		var llc: LimbController = limbs.get(role) as LimbController
		if llc != null:
			llc.boost = leg_boost
			llc.feed_forward = Tuning.LEG_FEED_FORWARD
	var hips_world: bool = on_feet and Tuning.HIPS_UPRIGHT_FRAME
	_hips_in_world(hips_world)
	if on_feet:
		var floor_h: float = pelvis.global_position.dot(up) - ground_dist
		for side: String in ["l", "r"]:
			var fc2: Vector2 = cyc[side]
			var hip_above: float = (pelvis.global_transform * (_hip_off[side] as Vector3)).dot(up) - floor_h
			# A planted foot aims a little below the floor so it really presses on it
			# (carries weight, grips) instead of hovering on a target exactly at floor level.
			var press: float = Tuning.STANCE_PRESS * height_scale if fc2.y <= 0.0001 else 0.0
			# Foot target relative to the hip joint (upright frame: +x right, +y up, -z forward).
			var foot: Vector3 = dir2 * (fc2.x * half) + Vector3(0, -hip_above - press + fc2.y * lift_h, 0)
			var down: float = maxf(-foot.y, 0.05)
			var abd: float = atan2(foot.x, down)
			var sag_down: float = sqrt(foot.x * foot.x + down * down)
			var ik: Vector2
			if simple_rig:
				ik = Vector2(atan2(-foot.z, sag_down), 0.0)   # one-piece legs can't bend
			else:
				ik = Gait.leg_ik(-foot.z, sag_down, _leg_l1, _leg_l2)
			var hq: Quaternion = Quaternion(Vector3.BACK, abd) * Quaternion(Vector3.RIGHT, ik.x)
			var hlc: LimbController = limbs.get("hip_" + side) as LimbController
			if hlc != null and hips_world:
				hlc.target_world = upq * hq
			else:
				_set_target("hip_" + side, hq)
			_set_target("knee_" + side, Quaternion(Vector3.RIGHT, ik.y))
	elif in_zero_g:
		var drift: float = sin(state_time * 1.6) * 0.15
		_set_target("hip_l", Quaternion(Vector3.RIGHT, 0.25 + drift))
		_set_target("hip_r", Quaternion(Vector3.RIGHT, 0.1 - drift))
		_set_target("knee_l", Quaternion(Vector3.RIGHT, -0.6))
		_set_target("knee_r", Quaternion(Vector3.RIGHT, -0.45))
	elif v_up > 0.5:
		# Jumping up: tuck the knees.
		_set_target("hip_l", Quaternion(Vector3.RIGHT, 1.0))
		_set_target("hip_r", Quaternion(Vector3.RIGHT, 0.35))
		_set_target("knee_l", Quaternion(Vector3.RIGHT, -1.5))
		_set_target("knee_r", Quaternion(Vector3.RIGHT, -0.75))
	else:
		# Falling: legs reach down for the floor, the faster the straighter.
		var fall: float = clampf(-v_up / 6.0, 0.0, 1.0)
		_set_target("hip_l", Quaternion(Vector3.RIGHT, lerpf(0.6, 0.22, fall)))
		_set_target("hip_r", Quaternion(Vector3.RIGHT, lerpf(0.1, -0.12, fall)))
		_set_target("knee_l", Quaternion(Vector3.RIGHT, lerpf(-1.0, -0.3, fall)))
		_set_target("knee_r", Quaternion(Vector3.RIGHT, lerpf(-0.6, -0.25, fall)))
	# --- torso: breathing when idle, head up when running, squash on landing ---
	var breathe: float = sin(state_time * 2.2) * 0.035 * (1.0 - gait_amount)
	_set_target("spine", Quaternion(Vector3.RIGHT, breathe - 0.25 * squash))
	_set_target("neck", Quaternion(Vector3.RIGHT, 0.1 * gait_run * gait_amount + 0.15 * squash))
	# --- arms ---
	for side: String in ["l", "r"]:
		var sx: float = -1.0 if side == "l" else 1.0
		var shoulder: Quaternion
		var elbow: float
		if airborne:
			if v_up < -2.0:
				# Arms flail upward when falling (comedy!).
				var flap: float = sin(state_time * 14.0 + sx) * 0.4
				shoulder = Quaternion(Vector3.BACK, sx * (2.0 + flap))
			else:
				shoulder = Quaternion(Vector3.BACK, sx * 1.25) * Quaternion(Vector3.RIGHT, 0.35)   # arms up for balance
			elbow = 0.6
		elif in_zero_g:
			shoulder = Quaternion(Vector3.BACK, sx * 1.2) * Quaternion(Vector3.RIGHT, sin(state_time * 3.0 + sx) * 0.3)
			elbow = 0.5
		else:
			# Arms swing opposite to the leg on the same side; bigger and bent when running.
			var fc3: Vector2 = cyc[side]
			var swing: float = -fc3.x * lerpf(0.35, 0.8, gait_run) * gait_amount
			var sway: float = sin(state_time * 1.7 + sx) * 0.035 * (1.0 - gait_amount)
			shoulder = Quaternion(Vector3.RIGHT, swing + sway) * Quaternion(Vector3.BACK, sx * (0.13 + 0.08 * gait_run + 0.3 * squash))
			elbow = 0.3 + gait_amount * lerpf(0.25, 1.15, gait_run)
		if emote_time > 0.0:
			shoulder = _emote_pose(side, sx)
		elif celebrate_time > 0.0:
			shoulder = Quaternion(Vector3.BACK, sx * (2.6 + sin(state_time * 12.0) * 0.2))
		_set_target("shoulder_" + side, shoulder)
		_set_target("elbow_" + side, Quaternion(Vector3.RIGHT, elbow))


func _set_foot_grip(side: String, want: float) -> void:
	var foot: RigidBody3D = bodies.get(RagdollBuilder.foot_name(side, simple_rig)) as RigidBody3D
	if foot == null or foot.physics_material_override == null:
		return
	if not is_equal_approx(foot.physics_material_override.friction, want):
		foot.physics_material_override.friction = want


## Hips aim in the world (upright frame) while walking, relative to the pelvis otherwise.
func _hips_in_world(on: bool) -> void:
	for role: String in ["hip_l", "hip_r"]:
		var lc: LimbController = limbs.get(role) as LimbController
		if lc != null:
			lc.use_world = on


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
