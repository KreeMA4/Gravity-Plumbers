class_name LevelRunner
extends Node3D
## LevelRunner: the "game" screen. Builds a level from its data, spawns the
## plumbers, and runs the rules: work orders, sludge meter, timer, gravity
## storms, DISPATCH-O-TRON lines, win / fail, flushing and respawning.
##
## Host-authoritative: on the host (and in solo, which is a host with no
## clients) this runs all rules. On a network client it only builds the level
## and shows what the host sends (see NetManager / snapshot_sync).

signal level_finished(won: bool)

var level_id: String = "hub"
var data: Dictionary = {}
var is_hub: bool = false
var orders: WorkOrderManager = WorkOrderManager.new()
var sludge: SludgeMeter = SludgeMeter.new()
var goo_pool: GooPool
var objects: Dictionary = {}          ## obj_id -> LevelObject
var dyn_props: Array = []             ## dynamic RigidBody3D props in creation order (net ids)
var plumbers: Dictionary = {}         ## peer_id -> Plumber
var spawn_pads: Array = []            ## Array of Transform3D
var local_player: LocalPlayer
var hud: GameHUD
var pause_menu: PauseMenu
var time_limit: float = 0.0
var time_left: float = 0.0
var elapsed: float = 0.0
var penalty: float = 0.0
var finished: bool = false
var ducks_found: Array = []
var sky_material: ShaderMaterial = null

var _world: Node3D
var _dispatch: Dictionary = {}
var _state_sync_t: float = 0.0
var _all_flushed_grace: float = 0.0
var _storm_line_index: int = 0


func setup(params: Dictionary) -> void:
	level_id = str(params.get("level_id", GameState.level_id))


func _ready() -> void:
	GravityManager.reset_all()
	data = LevelCatalog.load_data(level_id)
	if data.is_empty():
		GameLog.error("Level not found: " + level_id)
		GameState.menu_message = "Level '%s' is missing." % level_id
		GameState.goto_screen.call_deferred("main_menu")
		return
	is_hub = bool(data.get("is_hub", false))
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	var b: Dictionary = data.get("bounds", {})
	LevelBounds.set_bounds(b.get("center", Vector3.ZERO) as Vector3, float(b.get("radius", Tuning.KILL_DISTANCE)))
	goo_pool = GooPool.new()
	_world.add_child(goo_pool)
	LevelSpawner.build(self, _world, data)
	GravityManager.set_global_immediate(data.get("start_gravity", Vector3.DOWN) as Vector3)
	_dispatch = data.get("dispatcher", {})
	# Work orders.
	orders.order_activated.connect(_on_order_activated)
	orders.order_completed.connect(_on_order_completed)
	orders.all_completed.connect(_on_all_completed)
	for o: Variant in objects.values():
		(o as LevelObject).completed.connect(_on_object_completed)
	orders.load_orders(data.get("work_orders", []))
	_apply_dormancy()
	# Rules.
	time_limit = float(data.get("time_limit", 0.0)) * Tuning.diff("time")
	time_left = time_limit
	sludge.can_flood = NetManager.player_count() > 1   # solo can never hard-fail
	var storm: float = float(data.get("storm_interval", 0.0))
	if storm > 0.0 and multiplayer.is_server():
		GravityManager.start_storms(storm * Tuning.diff("storm_interval"), data.get("storm_sequence", []))
	GravityManager.shift_warning.connect(_on_shift_warning)
	# Players.
	local_player = LocalPlayer.new()
	add_child(local_player)
	hud = GameHUD.new()
	add_child(hud)
	hud.camera = local_player.camera.cam
	hud.set_orders(orders.orders)
	hud.checklist_panel.visible = not is_hub
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.closed.connect(func() -> void: local_player.set_blocked(false))
	local_player.touch.pause_pressed.connect(open_pause)
	for i: int in NetManager.get_player_ids().size():
		var pid: int = int(NetManager.get_player_ids()[i])
		spawn_plumber(pid, i)
	_attach_local()
	Quality.set_watchdog(true)
	Quality.low_fps_detected.connect(_on_low_fps)
	GameState.app_paused.connect(_on_app_paused)
	NetManager.level_started(self)
	AudioManager.play_music("game")
	if _dispatch.has("start"):
		hud.say(str(_dispatch["start"]), 5.0)
	if bool(SaveData.setting_b("tutorial_prompts")):
		for line: Variant in data.get("tutorial", []):
			hud.say(str(line), 4.5)


## Objects whose work order isn't open yet stay dormant (no spraying leaks etc.).
func _apply_dormancy() -> void:
	for oid: Variant in objects.keys():
		var obj: LevelObject = objects[oid] as LevelObject
		var w: WorkOrder = orders.order_for_target(str(oid))
		if w != null and w.status == WorkOrder.Status.LOCKED:
			obj.active = false
			obj.apply_net_state([false, false])
		elif not obj.active:
			obj.activate()


func register_object(obj: LevelObject) -> void:
	objects[obj.obj_id] = obj


func register_prop(rb: RigidBody3D) -> void:
	dyn_props.append(rb)
	rb.set_meta("net_id", dyn_props.size())


# --- Plumbers ------------------------------------------------------------------

func spawn_plumber(peer_id: int, index: int) -> Plumber:
	if plumbers.has(peer_id):
		return plumbers[peer_id] as Plumber
	var p: Plumber = Plumber.new()
	var look: PlumberLook = NetManager.get_look(peer_id)
	if look == null:
		look = PlumberLook.default_for(index)
	p.setup(get_spawn(index), look, peer_id, index)
	p.display_name = NetManager.get_player_name(peer_id)
	p.respawn_provider = _respawn_point
	_world.add_child(p)
	p.flushed.connect(_on_plumber_flushed)
	plumbers[peer_id] = p
	_add_nametag(p)
	if not multiplayer.is_server():
		p.set_puppet(true)
	if hud != null:
		hud.teammates = plumbers.values()
	for v: Variant in objects.values():
		if v is Valve:
			(v as Valve).solo_mode = plumbers.size() <= 1
		elif v is GravitySwitch:
			(v as GravitySwitch).solo_mode = plumbers.size() <= 1
	return p


func despawn_plumber(peer_id: int) -> void:
	if not plumbers.has(peer_id):
		return
	var p: Plumber = plumbers[peer_id] as Plumber
	plumbers.erase(peer_id)
	if is_instance_valid(p):
		for gh: Variant in p.grab_hands.values():
			(gh as GrabHand).release()
		# Anyone holding this plumber lets go too.
		for other: Variant in plumbers.values():
			for gh2: Variant in (other as Plumber).grab_hands.values():
				var hand: GrabHand = gh2 as GrabHand
				if hand.target != null and is_instance_valid(hand.target) and hand.target.get_meta("plumber", null) == p:
					hand.release()
		p.queue_free()
	if hud != null:
		hud.teammates = plumbers.values()


func _attach_local() -> void:
	var me: int = multiplayer.get_unique_id()
	if plumbers.has(me):
		var p: Plumber = plumbers[me] as Plumber
		local_player.attach(p)
		hud.local_plumber = p
		NetManager.set_local_input(local_player.input)


func get_spawn(index: int) -> Transform3D:
	if spawn_pads.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0))
	return spawn_pads[index % spawn_pads.size()] as Transform3D


## Respawn at the safe pad nearest to where you got flushed.
func _respawn_point(p: Plumber) -> Transform3D:
	var best: Transform3D = get_spawn(p.player_index)
	var best_d: float = INF
	for t: Variant in spawn_pads:
		var x: Transform3D = t as Transform3D
		var d: float = x.origin.distance_squared_to(p.get_center())
		if d < best_d:
			best_d = d
			best = x
	return best


func _add_nametag(p: Plumber) -> void:
	var tag: Label3D = Label3D.new()
	tag.text = p.display_name
	tag.font_size = 56
	tag.outline_size = 14
	tag.pixel_size = 0.004
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.modulate = GameHUD.TeammatePointers._tag_color(p)
	tag.position = Vector3(0, 0.45, 0)
	p.head.add_child(tag)
	tag.visible = p.peer_id != multiplayer.get_unique_id()


func _on_plumber_flushed(p: Plumber) -> void:
	if not multiplayer.is_server():
		return
	penalty += Tuning.FLUSH_TIME_PENALTY
	if hud != null and not is_hub:
		hud.say(_line("flush", "%s got flushed! +%ds" % [p.display_name, int(Tuning.FLUSH_TIME_PENALTY)]), 2.5)
	NetManager.broadcast_event("flushed", [p.peer_id])


# --- Work orders ---------------------------------------------------------------

func _on_object_completed(obj_id: String) -> void:
	if not multiplayer.is_server():
		return
	orders.target_done(obj_id)
	_sync_state_now()


func _on_order_activated(w: WorkOrder) -> void:
	for t: String in w.targets:
		var obj: LevelObject = objects.get(t) as LevelObject
		if obj != null and not obj.active:
			obj.activate()
	if hud != null and finished == false and elapsed > 0.5:
		hud.say(w.text, 3.5)
		hud.refresh_orders(orders.orders)


func _on_order_completed(w: WorkOrder) -> void:
	sludge.reward(w.reward)
	AudioManager.play_ui("work_done")
	for p: Variant in plumbers.values():
		(p as Plumber).celebrate()
	if hud != null:
		hud.refresh_orders(orders.orders)
		hud.say(_line("done", "Nice work! Order done."), 2.5)
	var trig: Dictionary = (data.get("on_done", {}) as Dictionary).get(w.id, {})
	_run_trigger(trig)


## Optional scripted reactions when an order completes (level data "on_done").
func _run_trigger(trig: Dictionary) -> void:
	if trig.is_empty() or not multiplayer.is_server():
		return
	if trig.has("shift"):
		GravityManager.request_shift(GravityMath.AXES[clampi(int(trig["shift"]), 0, 5)] as Vector3)
	if trig.has("enable_field"):
		GravityManager.set_field_enabled(str(trig["enable_field"]), true)
	if trig.has("disable_field"):
		GravityManager.set_field_enabled(str(trig["disable_field"]), false)
	if trig.has("say"):
		hud.say(str(trig["say"]), 4.0)
	if trig.has("storms"):
		GravityManager.start_storms(float(trig["storms"]) * Tuning.diff("storm_interval"), data.get("storm_sequence", []))


func _on_all_completed() -> void:
	if is_hub or finished:
		return
	_finish(true)


func _finish(won: bool) -> void:
	if finished:
		return
	finished = true
	GravityManager.stop_storms()
	var total_time: float = elapsed + penalty
	var stars: int = SludgeMeter.stars_for(total_time, float(data.get("par", 300.0)), sludge.value) if won else 0
	var awards: Array = _awards()
	var results: Dictionary = {"level_id": level_id, "won": won, "time": total_time, "stars": stars,
		"sludge": sludge.value, "ducks": ducks_found, "awards": awards,
		"name": str(LevelCatalog.info(level_id).get("name", level_id))}
	if won:
		SaveData.record_level(level_id, stars, total_time)
		AudioManager.play_ui("level_clear")
	else:
		AudioManager.play_ui("fail")
	GameState.last_results = results
	NetManager.broadcast_results(results)
	level_finished.emit(won)
	_show_results.call_deferred()


func _show_results() -> void:
	await get_tree().create_timer(1.5).timeout
	if is_inside_tree():
		GameState.goto_screen("results")


func _awards() -> Array:
	var out: Array = []
	var most_flushed: Plumber = null
	var best_grabber: Plumber = null
	var victim: Plumber = null
	for v: Variant in plumbers.values():
		var p: Plumber = v as Plumber
		if most_flushed == null or p.flush_count > most_flushed.flush_count:
			most_flushed = p
		if best_grabber == null or p.grab_time_total > best_grabber.grab_time_total:
			best_grabber = p
		if victim == null or p.ragdoll_count > victim.ragdoll_count:
			victim = p
	if most_flushed != null and most_flushed.flush_count > 0:
		out.append(["Most Flushed", most_flushed.display_name, "%d flushes" % most_flushed.flush_count])
	if best_grabber != null:
		out.append(["Best Grabber", best_grabber.display_name, "%ds holding on" % int(best_grabber.grab_time_total)])
	if victim != null:
		out.append(["Gravity Victim", victim.display_name, "%d tumbles" % victim.ragdoll_count])
	return out


func _line(key: String, fallback: String) -> String:
	var v: Variant = _dispatch.get(key, fallback)
	if v is Array and (v as Array).size() > 0:
		return str((v as Array)[randi() % (v as Array).size()])
	return str(v)


func _on_shift_warning(_dir: Vector3, _t: float) -> void:
	var lines: Array = _dispatch.get("storm", ["Gravity shift incoming! Grab something!"])
	if lines.size() > 0 and hud != null:
		hud.say(str(lines[_storm_line_index % lines.size()]), 2.5)
		_storm_line_index += 1
	if SaveData.setting_b("haptics") and OS.has_feature("mobile"):
		Input.vibrate_handheld(80)
	local_player.camera.add_shake(0.2)


## Duck collected (host). Everyone saves it locally.
func on_duck_collected(duck_id: String) -> void:
	NetManager.broadcast_event("duck", [duck_id])


func apply_duck(duck_id: String) -> void:
	if not ducks_found.has(duck_id):
		ducks_found.append(duck_id)
	SaveData.add_duck(duck_id)
	SaveData.save()
	for n: Node in get_tree().get_nodes_in_group("ducks"):
		var d: GoldenDuck = n as GoldenDuck
		if d != null and d.duck_id == duck_id:
			d.show_collected()
	if hud != null:
		hud.say("A golden duck! (%d found)" % SaveData.duck_count(), 2.5)


# --- Tick ----------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if finished or data.is_empty():
		return
	if not multiplayer.is_server():
		return
	var all_flushed: bool = plumbers.size() > 0
	for v: Variant in plumbers.values():
		if not (v as Plumber).is_flushed():
			all_flushed = false
	if all_flushed:
		_all_flushed_grace = 3.0
	if _all_flushed_grace > 0.0:
		_all_flushed_grace -= dt   # short respawn grace: no sludge, no clock
	elif not is_hub:
		elapsed += dt
		var open_leaks: int = 0
		var open_clogs: int = 0
		for o: Variant in objects.values():
			if o is Leak and (o as Leak).is_open():
				open_leaks += 1
			elif o is Clog and (o as Clog).is_open():
				open_clogs += 1
		sludge.tick(dt, open_leaks, open_clogs, Tuning.diff("sludge"), Tuning.LEAK_SLUDGE_RATE, Tuning.CLOG_SLUDGE_RATE)
		if time_limit > 0.0:
			time_left = time_limit - elapsed - penalty
			if time_left <= 0.0 and sludge.can_flood:
				_finish(false)
		if sludge.is_flooded():
			_finish(false)
	_state_sync_t -= dt
	if _state_sync_t <= 0.0:
		_state_sync_t = 1.0 / Tuning.STATE_SYNC_RATE
		_sync_state_now()


func _sync_state_now() -> void:
	NetManager.send_level_state(get_level_state())


## Everything clients need for the HUD and object visuals.
func get_level_state() -> Dictionary:
	var objs: Dictionary = {}
	for k: Variant in objects.keys():
		objs[k] = (objects[k] as LevelObject).get_net_state()
	return {"sludge": sludge.value, "time_left": time_left, "elapsed": elapsed + penalty,
		"orders": orders.get_state(), "objects": objs}


func apply_level_state(s: Dictionary) -> void:
	sludge.value = clampf(float(s.get("sludge", 0.0)), 0.0, 100.0)
	time_left = float(s.get("time_left", 0.0))
	elapsed = float(s.get("elapsed", 0.0))
	var o: Variant = s.get("orders", [])
	if o is Array:
		orders.apply_state(o as Array)
		if hud != null:
			hud.refresh_orders(orders.orders)
	var objs: Variant = s.get("objects", {})
	if objs is Dictionary:
		for k: Variant in (objs as Dictionary).keys():
			var obj: LevelObject = objects.get(str(k)) as LevelObject
			var st: Variant = (objs as Dictionary)[k]
			if obj != null and st is Array:
				obj.apply_net_state(st as Array)


func _process(delta: float) -> void:
	if hud == null:
		return
	hud.sludge = sludge.value
	hud.time_left = time_left if time_limit > 0.0 and not is_hub else -1.0
	if is_hub:
		hud.elapsed = 0.0
	var me: Plumber = plumbers.get(multiplayer.get_unique_id()) as Plumber
	if me != null and is_instance_valid(me):
		local_player.touch.use_label = me.get_use_label()
	if sky_material != null:
		var storm: float = 0.6 if GravityManager.phase != GravityManager.Phase.IDLE else 0.0
		var cur: float = float(sky_material.get_shader_parameter("storm"))
		sky_material.set_shader_parameter("storm", move_toward(cur, storm, delta * 1.5))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		open_pause()
	elif event.is_action_pressed("debug_gravity") and OS.is_debug_build():
		GravityManager.cycle_debug()


## Hub stations (console / mirror) call this on the host.
func on_station(kind: String, p: Plumber) -> void:
	var me: int = multiplayer.get_unique_id()
	if kind == "console":
		if p.peer_id == me:
			_open_level_select()
		else:
			NetManager.send_event_to(p.peer_id, "toast", ["Only the host can pick the job!"])
	elif kind == "mirror":
		NetManager.send_event_to(p.peer_id, "open_mirror", [])


func _open_level_select() -> void:
	local_player.set_blocked(true)
	var ls: LevelSelect = LevelSelect.new()
	add_child(ls)
	ls.closed.connect(func() -> void: local_player.set_blocked(false))


## Opens the customise screen as an overlay (it saves + syncs your look).
func open_mirror() -> void:
	if not GameState.screen_available("customize"):
		return
	local_player.set_blocked(true)
	var scr: GDScript = load(str(GameState.SCREENS["customize"])) as GDScript
	var c: Node = scr.new() as Node
	if c.has_method("set_overlay"):
		c.call("set_overlay", true)
	add_child(c)
	c.tree_exited.connect(func() -> void:
		if is_instance_valid(local_player):
			local_player.set_blocked(false))


func open_pause() -> void:
	if pause_menu.visible:
		return
	local_player.set_blocked(true)
	pause_menu.open(self)


func _on_low_fps() -> void:
	if hud != null:
		hud.say("Your phone is working hard! Try Settings > Graphics > %s." % Quality.lower_preset_name().capitalize(), 6.0)


func _on_app_paused(paused: bool) -> void:
	if paused:
		if NetManager.is_online() and multiplayer.is_server():
			NetManager.broadcast_event("host_paused", [true])
		elif not NetManager.is_online():
			open_pause.call_deferred()
	elif NetManager.is_online() and multiplayer.is_server():
		NetManager.broadcast_event("host_paused", [false])


func _exit_tree() -> void:
	Quality.set_watchdog(false)
	if Quality.low_fps_detected.is_connected(_on_low_fps):
		Quality.low_fps_detected.disconnect(_on_low_fps)
	if GameState.app_paused.is_connected(_on_app_paused):
		GameState.app_paused.disconnect(_on_app_paused)
	if GravityManager.shift_warning.is_connected(_on_shift_warning):
		GravityManager.shift_warning.disconnect(_on_shift_warning)
	NetManager.level_ended(self)
	GravityManager.reset_all()
	Mats.clear_cache()
