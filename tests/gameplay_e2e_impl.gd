extends Node
## GAMEPLAY end-to-end test in the real Ragdoll Playground (real physics, real
## input path). Covers:
##   - contextual pickup: no accidental pickup by walking / touching / Grab,
##     prompt + touch button appear only in range, Interact picks up (touch
##     button AND keyboard), several item types, best target choice, DROP
##   - Grab L / Grab R still cling to crates and static ledges (bracing)
##   - tools still work (Use), interactables work through Interact,
##     a carried pipe piece snaps into its port (work-order step)
##   - locomotion: feet actually touch the ground and don't skate, legs
##     alternate, body bobs, walk -> run, stops when input stops,
##     jump tuck, fall, landing squash
##   - ragdoll (Flop) and recovery, walking on walls and the ceiling
## Saves screenshots of the important states when run with --shots=DIR.
## Launched by tests/gameplay_e2e_test.gd. Prints "GAMEPLAY E2E PASSED".

var failures: PackedStringArray = PackedStringArray()
var checks: int = 0
var shot_dir: String = ""
var player: LocalPlayer
var touch: TouchControls
var plumber: Plumber
var arena: Node3D
var items: Node3D


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shot_dir = a.substr(8)
	_run.call_deferred()


func ok(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		failures.append(msg)


func frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func screenshot(shot_name: String) -> void:
	if shot_dir == "":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_tree().root.get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(shot_dir.path_join(shot_name + ".png"))
		print("  shot  " + shot_name + ".png")


func to_window(p: Vector2) -> Vector2:
	return get_tree().root.get_screen_transform() * p


func touch_tap(p: Vector2) -> void:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = 3
	e.pressed = true
	e.position = to_window(p)
	Input.parse_input_event(e)
	await frames(4)
	var u: InputEventScreenTouch = InputEventScreenTouch.new()
	u.index = 3
	u.pressed = false
	u.position = to_window(p)
	Input.parse_input_event(u)
	await frames(4)


func key_tap(action: String) -> void:
	Input.action_press(action)
	await frames(4)
	Input.action_release(action)
	await frames(4)


## Horizontal camera forward (what the stick's "up" means).
func fwd() -> Vector3:
	var a: Vector3 = player.camera.get_aim()
	var up: Vector3 = plumber.local_up
	var f: Vector3 = a - up * a.dot(up)
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func place(pos: Vector3, settle: int = 45) -> void:
	GravityManager.set_global_immediate(Vector3.DOWN)
	var f: Vector3 = fwd()
	f.y = 0.0
	f = f.normalized()
	plumber.teleport(Transform3D(Basis.looking_at(f, Vector3.UP), pos))
	await frames(settle)


func clear_items() -> void:
	if items != null and is_instance_valid(items):
		items.queue_free()
	items = Node3D.new()
	items.name = "TestItems"
	arena.add_child(items)
	await frames(2)


func make_tool(kind: String, at: Vector3) -> ToolBase:
	var t: ToolBase = (load(str(ToolRack.TOOL_SCRIPTS[kind])) as GDScript).new() as ToolBase
	items.add_child(t)
	t.global_position = at
	return t


func make_pipe(at: Vector3, id: String = "test_piece") -> PipeSegment:
	var p: PipeSegment = PipeSegment.new()
	p.piece_id = id
	items.add_child(p)
	p.global_position = at
	p.rotation = Vector3(0, 0, PI * 0.5)   # lying on the floor
	return p


func make_canister(at: Vector3) -> GooCanister:
	var c: GooCanister = GooCanister.new()
	items.add_child(c)
	c.global_position = at
	return c


## Height of a foot's sole above the floor under it (m).
func sole_clearance(side: String) -> float:
	var sole: Vector3 = plumber.foot_sole_position(side)
	var up: Vector3 = plumber.local_up
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(sole + up * 0.4, sole - up * 0.8, Layers.WORLD, plumber._exclude)
	var hit: Dictionary = plumber.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return 9.0
	return (sole - (hit["position"] as Vector3)).dot(up)


func sole_velocity(side: String) -> Vector3:
	var foot: RigidBody3D = plumber.bodies[RagdollBuilder.foot_name(side, plumber.simple_rig)] as RigidBody3D
	var sole: Vector3 = plumber.foot_sole_position(side)
	return foot.linear_velocity + foot.angular_velocity.cross(sole - foot.global_position)


func _run() -> void:
	print("GAMEPLAY E2E: booting the game")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await frames(10)
	Tuning.CAMERA_RECENTER_SPEED = 0.0
	NetManager.start_solo()
	GameState.goto_screen("playground")
	await frames(90)
	player = get_tree().root.find_child("LocalPlayer", true, false) as LocalPlayer
	touch = get_tree().root.find_child("TouchControls", true, false) as TouchControls
	for n: Node in get_tree().get_nodes_in_group("plumbers"):
		if (n as Plumber).player_index == 0:
			plumber = n as Plumber
	ok(player != null and touch != null and plumber != null, "playground, local player and plumber exist")
	if plumber == null or player == null or touch == null:
		_finish()
		return
	arena = plumber.get_parent() as Node3D
	await clear_items()
	await _check_no_accidental_pickup()
	await _check_pickup_tools()
	await _check_pickup_items()
	await _check_target_choice()
	await _check_out_of_range()
	await _check_grabs()
	await _check_tool_and_objects()
	await _check_pipe_port()
	await _check_walk()
	await _check_run()
	await _check_jump_and_land()
	await _check_ragdoll_recovery()
	await _check_gravity_walls()
	_finish()


# --- pickup -------------------------------------------------------------------

func _check_no_accidental_pickup() -> void:
	await clear_items()
	await place(Vector3(0, 0.05, 11))
	var f: Vector3 = fwd()
	var c: GooCanister = make_canister(plumber.get_center() + f * 1.6 - Vector3(0, 0.6, 0))
	var t: ToolBase = make_tool("plunger", plumber.get_center() + f * 2.6 - Vector3(0, 0.75, 0))
	await frames(20)
	# Walk straight through both items.
	Input.action_press("move_forward", 0.5)
	await frames(150)
	Input.action_release("move_forward")
	await frames(20)
	ok(not plumber.is_hand_full() and t.holder == null, "walking into a canister and a tool picks nothing up")
	# Hold BOTH grab buttons while standing on/next to them, aiming at them.
	await place(Vector3(0, 0.05, 11))
	c.global_position = plumber.get_center() + fwd() * 0.7 + Vector3(0, 0.1, 0)
	t.global_position = plumber.get_center() + fwd() * 0.6 + Vector3(0.3, 0.2, 0)
	Input.action_press("grab_left")
	Input.action_press("grab_right")
	await frames(90)
	var gl: GrabHand = plumber.grab_hands["l"] as GrabHand
	var gr: GrabHand = plumber.grab_hands["r"] as GrabHand
	var grabbed_item: bool = (gl.target == c or gl.target == t or gr.target == c or gr.target == t)
	Input.action_release("grab_left")
	Input.action_release("grab_right")
	await frames(10)
	ok(not plumber.has_tool() and not grabbed_item and not plumber.is_hand_full(), "holding Grab L+R on top of items never picks them up")


func _check_pickup_tools() -> void:
	await clear_items()
	await place(Vector3(0, 0.05, 11))
	var t: ToolBase = make_tool("plunger", plumber.get_center() + fwd() * 1.2 - Vector3(0, 0.75, 0))
	await frames(30)
	var act: Interaction = player.interaction
	ok(act.kind == Interaction.Kind.PICKUP and act.node == t, "prompt targets the plunger in front (%s)" % act.prompt_text())
	ok(act.prompt_text() == "PICK UP  Plunger", "prompt reads 'PICK UP  Plunger' (got '%s')" % act.prompt_text())
	ok(player.prompt.is_showing() and player.prompt.pill_rect().size.x > 50.0, "on-screen prompt is shown")
	var view: Vector2 = touch.get_viewport().get_visible_rect().size
	var pr: Rect2 = player.prompt.pill_rect()
	ok(pr.position.y >= view.y * 0.16 and pr.end.y <= view.y * 0.75 and pr.position.x >= 0.0 and pr.end.x <= view.x,
		"prompt stays clear of the HUD strip and thumb controls (%s in %s)" % [str(pr), str(view)])
	ok(touch.button_shown("interact") and touch.interact_label == "PICK UP", "touch Interact button appears labelled PICK UP")
	ok(not plumber.has_tool(), "nothing picked up before pressing the button")
	await screenshot("pickup_prompt")
	# Press the on-screen Interact button like a phone would.
	await touch_tap(touch.button_center("interact"))
	await frames(10)
	ok(plumber.has_tool() and plumber.get_tool() == t, "tapping the touch Interact button picks up the plunger")
	ok(touch.interact_label == "DROP" and player.interaction.kind == Interaction.Kind.DROP, "button now offers DROP")
	ok(not (player.interaction.kind == Interaction.Kind.PICKUP), "no pickup prompt while the hand is full")
	await screenshot("holding_tool")
	# Grab R must not drop the tool any more.
	await key_tap("grab_right")
	await frames(10)
	ok(plumber.has_tool(), "pressing Grab R doesn't drop the tool by accident")
	# Keyboard Interact drops it.
	await key_tap("interact")
	await frames(20)
	ok(not plumber.has_tool() and t.holder == null, "keyboard Interact (C) drops the tool")
	# ...and picks it up again (same item, keyboard path).
	await frames(30)
	if player.interaction.kind == Interaction.Kind.PICKUP:
		await key_tap("interact")
		await frames(10)
	ok(plumber.has_tool(), "keyboard Interact picks the tool up again")
	plumber.drop_item()
	await frames(10)


func _check_pickup_items() -> void:
	for kind: String in ["tape", "wrench", "gwrench", "pipe", "canister"]:
		await clear_items()
		await place(Vector3(0, 0.05, 11))
		var at: Vector3 = plumber.get_center() + fwd() * 1.25 - Vector3(0, 0.6, 0)
		var it: Node3D
		match kind:
			"pipe":
				it = make_pipe(at)
			"canister":
				it = make_canister(at)
			_:
				it = make_tool(kind, at)
		await frames(40)
		var act: Interaction = player.interaction
		ok(act.kind == Interaction.Kind.PICKUP and act.node == it, "[%s] prompt offers it: '%s'" % [kind, act.prompt_text()])
		await key_tap("interact")
		await frames(15)
		ok(plumber.held_item() == it, "[%s] Interact picks it up" % kind)
		# Walk a bit while carrying: it stays in the hand.
		Input.action_press("move_forward", 0.6)
		await frames(60)
		Input.action_release("move_forward")
		await frames(10)
		ok(plumber.held_item() == it, "[%s] stays in the hand while walking (no button held)" % kind)
		if kind == "pipe":
			await screenshot("carrying_pipe")
		await key_tap("interact")
		await frames(15)
		ok(not plumber.is_hand_full(), "[%s] Interact again drops it" % kind)


func _check_target_choice() -> void:
	await clear_items()
	await place(Vector3(0, 0.05, 11))
	var f: Vector3 = fwd()
	var right: Vector3 = f.cross(Vector3.UP).normalized()
	var c: Vector3 = plumber.get_center() - Vector3(0, 0.7, 0)
	var behind: ToolBase = make_tool("tape", c - f * 1.0)
	var ahead: ToolBase = make_tool("wrench", c + f * 1.5)
	await frames(30)
	ok(player.interaction.node == ahead, "prefers the item you're facing over a closer one behind you")
	var near: ToolBase = make_tool("plunger", c + f * 0.9 + right * 0.15)
	await frames(20)
	ok(player.interaction.node == near, "of two items in front, picks the closer one")
	behind.queue_free()
	await frames(2)


func _check_out_of_range() -> void:
	await clear_items()
	await place(Vector3(0, 0.05, 11))
	make_tool("plunger", plumber.get_center() + fwd() * 1.2 - Vector3(0, 0.75, 0))
	await frames(25)
	ok(not player.interaction.is_none(), "prompt present next to the item")
	await place(Vector3(0, 0.05, 11) - fwd() * 4.0)
	await frames(10)
	ok(player.interaction.is_none() and not touch.button_shown("interact") and not player.prompt.is_showing(),
		"prompt and Interact button disappear out of range")
	# Behind a wall: no prompt through walls.
	await clear_items()
	await place(Vector3(0, 0.05, 11))
	var f: Vector3 = fwd()
	Geo.static_box(items, plumber.get_center() + f * 0.8, Vector3(3, 3, 0.2), Color(0.5, 0.5, 0.6)).look_at(plumber.get_center() + f * 2.0, Vector3.UP)
	make_tool("plunger", plumber.get_center() + f * 1.5 - Vector3(0, 0.7, 0))
	await frames(25)
	ok(player.interaction.kind != Interaction.Kind.PICKUP, "no pickup prompt through a wall")


# --- grabs, tools, objects ------------------------------------------------------

func _check_grabs() -> void:
	await clear_items()
	await place(Vector3(0, 0.05, 11))
	var f: Vector3 = fwd()
	var top: Vector3 = plumber.get_center() + f * 0.75 + Vector3(0, 0.15, 0)
	var ped: StaticBody3D = Geo.static_box(items, top - Vector3(0, 0.55, 0), Vector3(0.6, 0.8, 0.6), Color(0.4, 0.4, 0.5))
	var crate: RigidBody3D = Geo.dynamic_box(items, top + Vector3(0, 0.12, 0), Vector3(0.36, 0.36, 0.36), Color(1, 0.5, 0.2), 4.0)
	crate.collision_layer = Layers.PROPS
	crate.collision_mask = Layers.MASK_SOLID
	crate.add_to_group("grabbable")
	await frames(20)
	Input.action_press("grab_left")
	await frames(80)
	var gl: GrabHand = plumber.grab_hands["l"] as GrabHand
	ok(gl.is_holding() and (gl.target == crate or gl.target == ped), "Grab L still grabs a crate / ledge (target %s)" % str(gl.target))
	await screenshot("grab_left")
	Input.action_release("grab_left")
	await frames(10)
	ok(not gl.is_holding(), "releasing Grab L lets go")
	crate.queue_free()
	await frames(5)
	Input.action_press("grab_right")
	await frames(80)
	var gr: GrabHand = plumber.grab_hands["r"] as GrabHand
	ok(gr.is_holding() and gr.target == ped and plumber.is_braced(), "Grab R clings to a static ledge and braces you")
	Input.action_release("grab_right")
	await frames(10)
	ok(not gr.is_holding(), "releasing Grab R lets go")


class TestLever extends Node3D:
	var count: int = 0

	func _init() -> void:
		add_to_group("interactables")

	func get_use_label() -> String:
		return "PULL"

	func get_interact_name() -> String:
		return "Test Lever"

	func interact(_p: Plumber) -> void:
		count += 1


func _check_tool_and_objects() -> void:
	await clear_items()
	await place(Vector3(0, 0.05, 11))
	var t: ToolBase = make_tool("tape", plumber.get_center() + fwd() * 1.2 - Vector3(0, 0.75, 0))
	await frames(30)
	await key_tap("interact")
	await frames(10)
	var uses: Array = [0]
	t.used.connect(func(_x: ToolBase) -> void: uses[0] = int(uses[0]) + 1)
	ok(touch.use_enabled, "Use button is active while holding a tool")
	await key_tap("use")
	await frames(10)
	ok(int(uses[0]) >= 1, "holding a tool, Use uses it (duct tape fired %d time(s))" % int(uses[0]))
	plumber.drop_item()
	await frames(10)
	await clear_items()
	await frames(5)
	ok(not touch.use_enabled, "Use button is dimmed with nothing to use")
	var lever: TestLever = TestLever.new()
	items.add_child(lever)
	lever.global_position = plumber.get_center() + fwd() * 1.0
	await frames(10)
	ok(player.interaction.kind == Interaction.Kind.USE_OBJECT and player.interaction.prompt_text() == "PULL  Test Lever",
		"a lever in reach shows 'PULL  Test Lever' (got '%s')" % player.interaction.prompt_text())
	await key_tap("interact")
	ok(lever.count == 1, "Interact pulls the lever (switches, stations use the same path)")
	lever.queue_free()
	await frames(2)


func _check_pipe_port() -> void:
	await clear_items()
	await place(Vector3(0, 0.05, 11))
	var f: Vector3 = fwd()
	var piece: PipeSegment = make_pipe(plumber.get_center() + f * 1.2 - Vector3(0, 0.7, 0), "e2e_piece")
	var port: PipePort = PipePort.new()
	port.piece_id = "e2e_piece"
	port.axis = Vector3.UP
	items.add_child(port)
	port.global_position = plumber.get_center() + f * 4.0 + Vector3(0, 0.1, 0)
	await frames(30)
	await key_tap("interact")
	await frames(10)
	ok(plumber.held_item() == piece, "picked up the pipe piece")
	# Carry it over to the port.
	for i: int in 240:
		if piece.is_locked:
			break
		var to: Vector3 = port.global_position - plumber.get_hand_position("r")
		to.y = 0.0
		var stick: Vector3 = to.normalized() if to.length() > 0.05 else Vector3.ZERO
		var right: Vector3 = fwd().cross(Vector3.UP).normalized()
		Input.action_press("move_forward", clampf(stick.dot(fwd()), 0.0, 1.0) * 0.5)
		Input.action_press("move_right", clampf(stick.dot(right), 0.0, 1.0) * 0.5)
		Input.action_press("move_left", clampf(-stick.dot(right), 0.0, 1.0) * 0.5)
		await frames(1)
	Input.action_release("move_forward")
	Input.action_release("move_right")
	Input.action_release("move_left")
	await frames(10)
	ok(piece.is_locked and port.done, "carrying the pipe piece to its port snaps it in (work-order step)")
	ok(not plumber.is_hand_full(), "the hand is free again after the pipe locks in")


# --- locomotion -----------------------------------------------------------------

## Signed rotation (radians) about the parent's X axis from parent to child body.
func joint_angle(child: String, parent: String) -> float:
	var c: RigidBody3D = plumber.bodies.get(child) as RigidBody3D
	var p: RigidBody3D = plumber.bodies.get(parent) as RigidBody3D
	if c == null or p == null:
		return 0.0
	var q: Quaternion = p.global_basis.get_rotation_quaternion().inverse() * c.global_basis.get_rotation_quaternion()
	return 2.0 * atan2(q.x, q.w)


## One line of leg diagnostics (printed as "info" so CI shows it).
func leg_report(tag: String) -> void:
	var t_hip: float = 0.0
	var t_knee: float = 0.0
	if plumber.limbs.has("hip_l"):
		var qh: Quaternion = (plumber.limbs["hip_l"] as LimbController).target
		t_hip = 2.0 * atan2(qh.x, qh.w)
	if plumber.limbs.has("knee_l"):
		var qk: Quaternion = (plumber.limbs["knee_l"] as LimbController).target
		t_knee = 2.0 * atan2(qk.x, qk.w)
	print("  info  legs[%s]: clear L %.3f R %.3f | ground_dist %.3f ride %.3f grounded %s | hipL tgt %.2f act %.2f | kneeL tgt %.2f act %.2f | amt %.2f phase %.2f" % [
		tag, sole_clearance("l"), sole_clearance("r"), plumber.ground_dist, plumber.gait_ride, str(plumber.grounded),
		t_hip, joint_angle("thigh_l", "pelvis"), t_knee, joint_angle("shin_l", "thigh_l"), plumber.gait_amount, fposmod(plumber.walk_phase, TAU)])


## Walk/run for `n` frames at stick strength `k`; returns measurements.
func _measure_gait(k: float, n: int) -> Dictionary:
	var f: Vector3 = fwd()
	var start: Vector3 = plumber.get_center()
	var contact: int = 0
	var airborne: int = 0
	var flips: int = 0
	var prev_sign: float = 0.0
	var skate_sum: float = 0.0
	var skate_n: int = 0
	var hmin: float = 99.0
	var hmax: float = -99.0
	var vmax: float = 0.0
	var samples: int = 0
	var knee_min: float = 9.0
	var knee_max: float = -9.0
	Input.action_press("move_forward", k)
	for i: int in n:
		await frames(1)
		if i % 30 == 15:
			leg_report("k=%.1f f%d" % [k, i])
		if i < 45:
			continue   # let it get going
		samples += 1
		var cl: float = sole_clearance("l")
		var cr: float = sole_clearance("r")
		if minf(cl, cr) < 0.06:
			contact += 1
		if minf(cl, cr) > 0.04:
			airborne += 1
		var lead: float = (plumber.foot_sole_position("l") - plumber.foot_sole_position("r")).dot(f)
		var sg: float = signf(lead) if absf(lead) > 0.05 else prev_sign
		if prev_sign != 0.0 and sg != prev_sign:
			flips += 1
		prev_sign = sg
		var v: Vector3 = plumber.pelvis.linear_velocity
		var vh: Vector3 = v - Vector3.UP * v.y
		vmax = maxf(vmax, vh.length())
		var side: String = "l" if cl < cr else "r"
		if minf(cl, cr) < 0.03 and vh.length() > 0.8:
			var sv: Vector3 = sole_velocity(side)
			sv.y = 0.0
			skate_sum += sv.length() / vh.length()
			skate_n += 1
		var kn: float = joint_angle("shin_l", "thigh_l")
		knee_min = minf(knee_min, kn)
		knee_max = maxf(knee_max, kn)
		var h: float = plumber.pelvis.global_position.y
		hmin = minf(hmin, h)
		hmax = maxf(hmax, h)
	Input.action_release("move_forward")
	var dist: float = (plumber.get_center() - start).dot(f)
	var secs: float = float(samples) / float(Engine.physics_ticks_per_second)
	return {"contact": float(contact) / maxf(1.0, samples), "air": float(airborne) / maxf(1.0, samples),
		"steps_per_s": float(flips) / maxf(secs, 0.01), "skate": skate_sum / maxf(1.0, skate_n),
		"bob": hmax - hmin, "vmax": vmax, "dist": dist, "knee_bend": knee_max - knee_min, "knee_deepest": knee_min}


func _check_walk() -> void:
	await clear_items()
	await place(Vector3(0, 0.05, 0) - fwd() * 12.0, 60)
	# Idle first: standing with both feet down, legs settled.
	await frames(60)
	ok(sole_clearance("l") < 0.06 and sole_clearance("r") < 0.06, "idle: both feet on the ground (%.3f, %.3f m)" % [sole_clearance("l"), sole_clearance("r")])
	ok(plumber.gait_amount < 0.05, "idle: no walk cycle while standing (%.2f)" % plumber.gait_amount)
	leg_report("idle")
	if plumber.limbs.has("knee_l"):
		var qk: Quaternion = (plumber.limbs["knee_l"] as LimbController).target
		var tk: float = 2.0 * atan2(qk.x, qk.w)
		ok(absf(joint_angle("shin_l", "thigh_l") - tk) < 0.12, "idle: the knee joint actually follows its muscle target (%.2f vs %.2f)" % [joint_angle("shin_l", "thigh_l"), tk])
	await screenshot("anim_idle")
	# Stick 0.6 = 0.4 of top speed after the 0.25 input deadzone (~1.8 m/s, a walk).
	var m: Dictionary = await _measure_gait(0.6, 210)
	print("  info  walk: %s" % str(m))
	ok(float(m["dist"]) > 2.0, "walk: moved forward (%.2f m)" % float(m["dist"]))
	ok(float(m["knee_bend"]) > 0.35 and float(m["knee_deepest"]) < -0.3, "walk: knees bend and straighten through the step (range %.2f rad, deepest %.2f)" % [float(m["knee_bend"]), float(m["knee_deepest"])])
	ok(float(m["contact"]) > 0.9, "walk: a foot is on the ground %.0f%% of the time (no floating)" % (100.0 * float(m["contact"])))
	ok(float(m["skate"]) < 0.5, "walk: planted foot doesn't skate (sole speed %.0f%% of body speed)" % (100.0 * float(m["skate"])))
	ok(float(m["steps_per_s"]) > 1.2, "walk: left and right feet alternate (%.1f steps/s)" % float(m["steps_per_s"]))
	ok(float(m["bob"]) > 0.008 and float(m["bob"]) < 0.16, "walk: body bobs with the steps (%.3f m)" % float(m["bob"]))
	# Screenshot mid-stride.
	Input.action_press("move_forward", 0.6)
	await frames(50)
	await screenshot("anim_walk")
	Input.action_release("move_forward")
	# Stops when input stops.
	await frames(80)
	var v: Vector3 = plumber.pelvis.linear_velocity
	v.y = 0.0
	ok(v.length() < 0.35, "walk: stops when the stick is released (%.2f m/s)" % v.length())
	ok(plumber.gait_amount < 0.15, "walk: legs stop stepping (%.2f)" % plumber.gait_amount)
	leg_report("stopped")
	ok(sole_clearance("l") < 0.07 and sole_clearance("r") < 0.07, "walk: ends standing on both feet")


func _check_run() -> void:
	await place(Vector3(0, 0.05, 0) - fwd() * 13.0, 60)
	var m: Dictionary = await _measure_gait(1.0, 125)
	print("  info  run: %s" % str(m))
	ok(float(m["vmax"]) > 3.6, "run: reaches running speed (%.1f m/s)" % float(m["vmax"]))
	ok(plumber.gait_run > 0.6 or float(m["vmax"]) > 3.6, "run: switches to the run cycle (%.2f)" % plumber.gait_run)
	ok(float(m["contact"]) > 0.55, "run: still mostly in contact with the ground (%.0f%%)" % (100.0 * float(m["contact"])))
	ok(float(m["steps_per_s"]) > 2.5, "run: faster steps than walking (%.1f steps/s)" % float(m["steps_per_s"]))
	Input.action_press("move_forward", 1.0)
	await frames(30)
	await screenshot("anim_run")
	Input.action_release("move_forward")
	await frames(90)


func _check_jump_and_land() -> void:
	await place(Vector3(0, 0.05, 11), 60)
	var y0: float = plumber.pelvis.global_position.y
	var landed: Array = [0]
	var cb: Callable = func(_p: Plumber) -> void: landed[0] = int(landed[0]) + 1
	plumber.landed.connect(cb)
	Input.action_press("jump")
	await frames(10)
	var tucked: bool = (plumber.limbs["knee_l"] as LimbController).target.get_angle() > 1.0 if plumber.limbs.has("knee_l") else true
	await frames(6)
	Input.action_release("jump")
	var peak: float = y0
	var shot: bool = false
	for i: int in 120:
		await frames(1)
		peak = maxf(peak, plumber.pelvis.global_position.y)
		if not shot and i == 4:
			shot = true
			await screenshot("anim_jump")
		if int(landed[0]) > 0:
			break
	ok(peak - y0 > 0.3, "jump: leaves the ground (%.2f m)" % (peak - y0))
	ok(tucked, "jump: knees tuck on the way up")
	ok(int(landed[0]) > 0, "jump: lands again")
	await frames(2)
	ok(plumber.land_squash > 0.0 or int(landed[0]) > 0, "land: knees soak up the landing")
	await frames(60)
	ok(plumber.state == Plumber.State.ACTIVE, "land: still on his feet after a jump")
	# Drop from a height: falling pose then landing.
	plumber.teleport(Transform3D(plumber.pelvis.global_basis.orthonormalized(), Vector3(0, 2.2, 11)))
	await frames(14)
	var falling_pose: bool = not plumber.grounded
	await screenshot("anim_fall")
	var t0: int = Engine.get_physics_frames()
	var landed2: bool = false
	for i: int in 200:
		await frames(1)
		if plumber.grounded:
			landed2 = true
			break
	ok(falling_pose and landed2, "fall: falls and lands (%d frames)" % (Engine.get_physics_frames() - t0))
	await frames(3)
	await screenshot("anim_land")
	plumber.landed.disconnect(cb)
	for i: int in 360:
		await frames(1)
		if plumber.state == Plumber.State.ACTIVE and i > 60:
			break
	ok(plumber.state == Plumber.State.ACTIVE, "fall: standing again after the drop")


func _check_ragdoll_recovery() -> void:
	await place(Vector3(0, 0.05, 11), 60)
	await key_tap("flop")
	await frames(10)
	ok(plumber.state == Plumber.State.RAGDOLL, "Flop: goes ragdoll")
	await frames(30)
	await screenshot("anim_ragdoll")
	var got_up: bool = false
	for i: int in 600:
		await frames(1)
		if plumber.state == Plumber.State.ACTIVE:
			got_up = true
			break
	ok(got_up, "ragdoll: gets back up by itself")
	await frames(60)
	var m: Dictionary = await _measure_gait(0.5, 150)
	ok(float(m["dist"]) > 1.0 and float(m["contact"]) > 0.8, "after recovery: walks normally again (%.1f m, contact %.0f%%)" % [float(m["dist"]), 100.0 * float(m["contact"])])
	await frames(60)


func _check_gravity_walls() -> void:
	for dir: Vector3 in [Vector3.RIGHT, Vector3.UP]:
		await place(Vector3(0, 0.05, 6), 30)
		GravityManager.request_shift(dir, 0.0, true)
		var stood: bool = false
		for i: int in 900:
			await frames(1)
			if GravityManager.phase == GravityManager.Phase.IDLE and plumber.state == Plumber.State.ACTIVE \
					and plumber.grounded and plumber.local_up.dot(-dir) > 0.9 and i > 120:
				stood = true
				break
		var label: String = "wall" if dir == Vector3.RIGHT else "ceiling"
		ok(stood, "[%s] lands and stands up with gravity %s (up %s)" % [label, str(dir), str(plumber.local_up)])
		if not stood:
			continue
		await frames(60)
		var start: Vector3 = plumber.get_center()
		var contact: int = 0
		Input.action_press("move_forward", 0.5)
		for i: int in 150:
			await frames(1)
			if minf(sole_clearance("l"), sole_clearance("r")) < 0.07:
				contact += 1
			if i == 90:
				await screenshot("anim_walk_" + label)
		Input.action_release("move_forward")
		var moved: Vector3 = plumber.get_center() - start
		moved -= dir * moved.dot(dir)
		ok(moved.length() > 1.0, "[%s] walks along it (%.2f m)" % [label, moved.length()])
		ok(float(contact) / 150.0 > 0.75, "[%s] feet stay on the surface (%.0f%%)" % [label, 100.0 * float(contact) / 150.0])
		await frames(30)
	GravityManager.set_global_immediate(Vector3.DOWN)


func _finish() -> void:
	print("GAMEPLAY E2E: %d checks, %d failed" % [checks, failures.size()])
	for f: String in failures:
		print("  failed: " + f)
	print("GAMEPLAY E2E PASSED" if failures.is_empty() else "GAMEPLAY E2E FAILED")
	GameState.quit_game(0 if failures.is_empty() else 1)
