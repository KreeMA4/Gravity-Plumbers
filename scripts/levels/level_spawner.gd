class_name LevelSpawner
extends RefCounted
## Turns level data (plain Dictionaries, see level_data/*.gd) into nodes.
## Geometry goes through LevelBuilder; gameplay objects are created here and
## registered with the LevelRunner (so ids, net ids and work orders line up).
## Every peer builds the same level in the same order, so dynamic props get
## the same network id everywhere without sending anything.

## Orientation with a given up vector and a yaw (radians) around it.
static func frame(up: Vector3, yaw: float) -> Basis:
	var q: Quaternion = GravityMath.quat_between(Vector3.UP, up.normalized())
	return Basis(q) * Basis(Vector3.UP, yaw)


static func build(runner: LevelRunner, world: Node3D, d: Dictionary) -> void:
	var palette: Dictionary = d.get("palette", LevelBuilder.DEFAULT_PALETTE)
	var env: Dictionary = LevelBuilder.build_environment(world, palette)
	runner.sky_material = env["sky_material"] as ShaderMaterial
	for r: Variant in d.get("rooms", []):
		LevelBuilder.build_room(world, r as Dictionary, palette)
	for b: Variant in d.get("boxes", []):
		var bd: Dictionary = b as Dictionary
		var sb: StaticBody3D = Geo.static_box(world, bd.get("pos", Vector3.ZERO) as Vector3, bd.get("size", Vector3.ONE) as Vector3,
			bd.get("color", LevelBuilder.palette_color(palette, "trim")) as Color, bd.get("rot", Vector3.ZERO) as Vector3)
		if bool(bd.get("grab", false)):
			sb.add_to_group("grabbable_static")
	for p: Variant in d.get("pipes", []):
		LevelBuilder.build_pipe(world, p as Dictionary)
	for r2: Variant in d.get("rocks", []):
		var rd: Dictionary = r2 as Dictionary
		LevelBuilder.build_rock(world, rd.get("center", Vector3.ZERO) as Vector3, float(rd.get("radius", 2.0)),
			rd.get("color", Color(0.55, 0.42, 0.7)) as Color)
	for l: Variant in d.get("labels", []):
		var ld: Dictionary = l as Dictionary
		var lbl: Label3D = Label3D.new()
		lbl.text = str(ld.get("text", ""))
		lbl.font_size = int(ld.get("size", 72))
		lbl.outline_size = 14
		lbl.pixel_size = 0.005
		lbl.modulate = ld.get("color", Color(1, 1, 1)) as Color
		lbl.position = ld.get("pos", Vector3.ZERO) as Vector3
		lbl.basis = frame(ld.get("up", Vector3.UP) as Vector3, float(ld.get("yaw", 0.0)))
		world.add_child(lbl)
	_build_fields(world, d)
	_build_spawns(runner, world, d)
	_build_props(runner, world, d)
	for t: Variant in d.get("tool_racks", []):
		var td: Dictionary = t as Dictionary
		var rack: ToolRack = ToolRack.build(world, Transform3D(frame(td.get("up", Vector3.UP) as Vector3, float(td.get("yaw", 0.0))),
			td.get("pos", Vector3.ZERO) as Vector3), td.get("tools", ["plunger", "wrench", "tape"]) as Array)
		for tool: Variant in rack.tools:
			runner.register_prop(tool as RigidBody3D)
	_build_objects(runner, world, d)
	for k: Variant in d.get("kill_volumes", []):
		var kd: Dictionary = k as Dictionary
		var kv: KillVolume = KillVolume.new()
		kv.half = kd.get("half", Vector3(10, 1, 10)) as Vector3
		kv.position = kd.get("center", Vector3(0, -20, 0)) as Vector3
		world.add_child(kv)


static func _build_fields(world: Node3D, d: Dictionary) -> void:
	for f: Variant in d.get("fields", []):
		var fd: Dictionary = f as Dictionary
		var id: String = str(fd.get("id", ""))
		var kind: String = str(fd.get("kind", "box"))
		var c: Vector3 = fd.get("center", Vector3.ZERO) as Vector3
		var data: GravityFieldData
		match kind:
			"sphere":
				data = GravityFieldData.make_sphere(id, c, float(fd.get("surface", 2.0)), float(fd.get("radius", 6.0)),
					int(fd.get("priority", 2)), float(fd.get("strength", Tuning.GRAVITY_STRENGTH)))
				data.falloff = bool(fd.get("falloff", true))
			"zero_g":
				data = GravityFieldData.make_zero_g(id, c, fd.get("half", Vector3(3, 3, 3)) as Vector3,
					int(fd.get("priority", 3)), float(fd.get("drag", Tuning.ZERO_G_DRAG)))
			_:
				data = GravityFieldData.make_box(id, c, fd.get("half", Vector3(3, 3, 3)) as Vector3,
					fd.get("dir", Vector3.DOWN) as Vector3, int(fd.get("priority", 1)), float(fd.get("strength", Tuning.GRAVITY_STRENGTH)))
		data.enabled = bool(fd.get("enabled", true))
		var gf: GravityField = GravityField.create(data, bool(fd.get("visual", true)))
		world.add_child(gf)


static func _build_spawns(runner: LevelRunner, world: Node3D, d: Dictionary) -> void:
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.7
	disc.height = 0.06
	disc.radial_segments = 16
	for s: Variant in d.get("spawns", []):
		var sd: Dictionary = s as Dictionary
		var up: Vector3 = sd.get("up", Vector3.UP) as Vector3
		var pos: Vector3 = sd.get("pos", Vector3.ZERO) as Vector3
		var xf: Transform3D = Transform3D(frame(up, float(sd.get("yaw", 0.0))), pos + up * 0.05)
		runner.spawn_pads.append(xf)
		var pad: MeshInstance3D = MeshInstance3D.new()
		pad.mesh = disc
		pad.material_override = Mats.toon_glow(UITheme.C_TEAL, 0.4, false)
		pad.transform = Transform3D(frame(up, 0.0), pos + up * 0.03)
		world.add_child(pad)


static func _build_props(runner: LevelRunner, world: Node3D, d: Dictionary) -> void:
	var colors: Array = [UITheme.C_PIPE, UITheme.C_TEAL, UITheme.C_ACCENT, UITheme.C_LEAK]
	var i: int = 0
	for p: Variant in d.get("props", []):
		var pd: Dictionary = p as Dictionary
		var type: String = str(pd.get("type", "crate"))
		var pos: Vector3 = pd.get("pos", Vector3.ZERO) as Vector3
		var rb: RigidBody3D = null
		match type:
			"canister":
				var can: GooCanister = GooCanister.new()
				can.worth = int(pd.get("worth", 4))
				can.position = pos
				world.add_child(can)
				rb = can
			"food":
				rb = _food(world, pos, i)
			_:
				var sz: Vector3 = pd.get("size", Vector3(0.6, 0.6, 0.6)) as Vector3
				rb = Geo.dynamic_box(world, pos, sz, pd.get("color", colors[i % colors.size()]) as Color, float(pd.get("mass", 5.0)))
				rb.collision_layer = Layers.PROPS
				rb.collision_mask = Layers.MASK_SOLID
				rb.add_to_group("grabbable")
		if pd.has("vel"):
			rb.linear_velocity = pd["vel"] as Vector3
		runner.register_prop(rb)
		i += 1


## Floating cafeteria food: burgers, donuts, jelly. Purely for fun (and blocking).
static func _food(world: Node3D, pos: Vector3, i: int) -> RigidBody3D:
	var rb: RigidBody3D = RigidBody3D.new()
	rb.mass = 1.0
	rb.position = pos
	rb.collision_layer = Layers.PROPS
	rb.collision_mask = Layers.MASK_SOLID
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	match i % 3:
		0:
			var t: TorusMesh = TorusMesh.new()
			t.inner_radius = 0.08
			t.outer_radius = 0.22
			mi.mesh = t
			mi.material_override = Mats.toon(Color(1.0, 0.55, 0.75), Quality.outlines_on_props)
			var sh: CylinderShape3D = CylinderShape3D.new()
			sh.radius = 0.22
			sh.height = 0.14
			cs.shape = sh
		1:
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 0.22
			cm.bottom_radius = 0.24
			cm.height = 0.22
			mi.mesh = cm
			mi.material_override = Mats.toon(Color(0.85, 0.55, 0.25), Quality.outlines_on_props)
			var sh2: CylinderShape3D = CylinderShape3D.new()
			sh2.radius = 0.24
			sh2.height = 0.22
			cs.shape = sh2
		_:
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.3, 0.3, 0.3)
			mi.mesh = bm
			mi.material_override = Mats.toon(Color(0.4, 1.0, 0.5), Quality.outlines_on_props)
			var sh3: BoxShape3D = BoxShape3D.new()
			sh3.size = Vector3(0.3, 0.3, 0.3)
			cs.shape = sh3
	rb.add_child(mi)
	rb.add_child(cs)
	rb.add_child(GravityBody.new())
	rb.add_to_group("grabbable")
	rb.add_to_group("props")
	world.add_child(rb)
	rb.angular_velocity = Vector3(0.3, 0.7, 0.2) * float(i % 4)
	return rb


static func _place(obj: LevelObject, od: Dictionary, prefix: String, idx: int) -> void:
	obj.obj_id = str(od.get("id", "%s_%d" % [prefix, idx]))
	obj.position = od.get("pos", Vector3.ZERO) as Vector3


static func _build_objects(runner: LevelRunner, world: Node3D, d: Dictionary) -> void:
	var i: int = 0
	for e: Variant in d.get("leaks", []):
		var od: Dictionary = e as Dictionary
		var lk: Leak = Leak.new()
		_place(lk, od, "leak", i)
		lk.normal = (od.get("normal", Vector3.FORWARD) as Vector3).normalized()
		lk.goo_pool = runner.goo_pool
		world.add_child(lk)
		runner.register_object(lk)
		i += 1
	i = 0
	for e: Variant in d.get("valves", []):
		var od: Dictionary = e as Dictionary
		var v: Valve = Valve.new()
		_place(v, od, "valve", i)
		v.normal = (od.get("normal", Vector3.FORWARD) as Vector3).normalized()
		v.two_player = bool(od.get("two_player", false))
		world.add_child(v)
		runner.register_object(v)
		i += 1
	i = 0
	for e: Variant in d.get("clogs", []):
		var od: Dictionary = e as Dictionary
		var c: Clog = Clog.new()
		_place(c, od, "clog", i)
		c.radius = float(od.get("radius", 0.5))
		c.hits_needed = int(od.get("hits", Tuning.CLOG_HITS))
		c.goo_pool = runner.goo_pool
		world.add_child(c)
		runner.register_object(c)
		i += 1
	i = 0
	for e: Variant in d.get("tanks", []):
		var od: Dictionary = e as Dictionary
		var t: Tank = Tank.new()
		_place(t, od, "tank", i)
		t.size = od.get("size", Vector3(1.6, 1.6, 1.6)) as Vector3
		t.up_dir = (od.get("up", Vector3.UP) as Vector3).normalized()
		t.need = int(od.get("need", 12))
		t.goo_pool = runner.goo_pool
		world.add_child(t)
		runner.register_object(t)
		i += 1
	i = 0
	for e: Variant in d.get("pipe_pieces", []):
		var od: Dictionary = e as Dictionary
		var ps: PipeSegment = PipeSegment.new()
		ps.piece_id = str(od.get("id", "piece_%d" % i))
		ps.position = od.get("pos", Vector3.ZERO) as Vector3
		ps.rotation = od.get("rot", Vector3(0, 0, PI * 0.5)) as Vector3
		world.add_child(ps)
		runner.register_prop(ps)
		i += 1
	i = 0
	for e: Variant in d.get("ports", []):
		var od: Dictionary = e as Dictionary
		var port: PipePort = PipePort.new()
		_place(port, od, "port", i)
		port.piece_id = str(od.get("piece", ""))
		port.axis = (od.get("axis", Vector3.UP) as Vector3).normalized()
		world.add_child(port)
		runner.register_object(port)
		i += 1
	i = 0
	for e: Variant in d.get("switches", []):
		var od: Dictionary = e as Dictionary
		var sw: GravitySwitch = GravitySwitch.new()
		_place(sw, od, "switch", i)
		sw.normal = (od.get("normal", Vector3.FORWARD) as Vector3).normalized()
		sw.action = str(od.get("action", "global"))
		sw.dirs = od.get("dirs", [1, 0]) as Array
		sw.field_id = str(od.get("field", ""))
		sw.two_player = bool(od.get("two_player", false))
		sw.required_dir = int(od.get("required_dir", -1))
		world.add_child(sw)
		runner.register_object(sw)
		i += 1
	i = 0
	for e: Variant in d.get("vents", []):
		var od: Dictionary = e as Dictionary
		var vt: Vent = Vent.new()
		_place(vt, od, "vent", i)
		vt.dir = (od.get("dir", Vector3.UP) as Vector3).normalized()
		vt.period = float(od.get("period", 12.0))
		vt.goo_pool = runner.goo_pool
		vt.runner_sludge = runner.sludge.add
		world.add_child(vt)
		runner.register_object(vt)
		i += 1
	for e: Variant in d.get("great_clogs", []):
		var od: Dictionary = e as Dictionary
		var gc: GreatClog = GreatClog.new()
		_place(gc, od, "great_clog", i)
		gc.radius = float(od.get("radius", 2.0))
		gc.hp_max = int(od.get("hp", 30))
		gc.goo_pool = runner.goo_pool
		gc.runner_sludge = runner.sludge.add
		world.add_child(gc)
		runner.register_object(gc)
	for e: Variant in d.get("spinners", []):
		var od: Dictionary = e as Dictionary
		var sp: Spinner = Spinner.make(float(od.get("radius", 4.0)), float(od.get("thickness", 0.3)),
			od.get("color", Color(0.4, 0.8, 1.0)) as Color, od.get("axis", Vector3.UP) as Vector3, float(od.get("speed", 0.3)))
		sp.position = od.get("pos", Vector3.ZERO) as Vector3
		world.add_child(sp)
	for e: Variant in d.get("ducks", []):
		var od: Dictionary = e as Dictionary
		var duck: GoldenDuck = GoldenDuck.new()
		duck.duck_id = str(od.get("id", "duck"))
		duck.position = od.get("pos", Vector3.ZERO) as Vector3
		duck.add_to_group("ducks")
		world.add_child(duck)
		duck.collected.connect(runner.on_duck_collected)
	for e: Variant in d.get("stations", []):
		var od: Dictionary = e as Dictionary
		var st: HubStation = HubStation.new()
		_place(st, od, "station", i)
		st.kind = str(od.get("kind", "console"))
		st.normal = (od.get("normal", Vector3.FORWARD) as Vector3).normalized()
		st.runner = runner
		world.add_child(st)
		i += 1
