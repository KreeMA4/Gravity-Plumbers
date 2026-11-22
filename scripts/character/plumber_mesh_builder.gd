class_name PlumberMeshBuilder
extends RefCounted
## Builds all the plumber's visuals from primitives, driven by a PlumberLook.
## Works for both the physics rig (meshes become children of each RigidBody3D)
## and the static preview (children of plain Node3D placeholders).
##
## build() returns a Dictionary of cosmetic nodes the face animator uses:
##   "pupils": Array[Node3D], "eye_rest": Array[Vector3], "mouth": Node3D,
##   "stache": Node3D, "stache_tips": Array[Node3D], "squash": Array[Node3D]

const PART_NAMES_FULL: Array = ["pelvis", "chest", "head", "upper_arm_l", "lower_arm_l", "upper_arm_r",
	"lower_arm_r", "thigh_l", "shin_l", "thigh_r", "shin_r"]
const PART_NAMES_SIMPLE: Array = ["pelvis", "chest", "head", "arm_l", "arm_r", "leg_l", "leg_r"]


## `nodes`: part name -> Node3D to attach meshes to (bodies or placeholders).
static func build(nodes: Dictionary, look: PlumberLook, simple: bool, outline: bool) -> Dictionary:
	var sc: Vector4 = PlumberLook.build_scales(look.get_v("build"))
	var hs: float = sc.x
	var ws: float = sc.y
	var ls: float = sc.z
	var head_s: float = sc.w
	var out: Dictionary = {"pupils": [], "eye_rest": [], "mouth": null, "stache": null, "stache_tips": [], "squash": []}
	var skin: Color = look.color("skin")
	var overalls: Color = look.color("overalls")
	var shirt: Color = look.color("accent")
	var glove_c: Color = look.color("gloves_col")
	var boot_c: Color = look.color("boots_col")
	var ol: float = 0.02 if outline else 0.0

	# --- Pelvis: overalls shorts ---
	var pelvis: Node3D = nodes.get("pelvis") as Node3D
	if pelvis != null:
		var m: MeshInstance3D = _mesh(pelvis, PipeBuilder.rounded_box(Vector3(0.38 * ws, 0.24 * hs, 0.28 * ws), 0.06), overalls, ol)
		out["squash"].append(m)
		_pattern(pelvis, look.get_v("pattern"), Vector3(0.38 * ws, 0.24 * hs, 0.28 * ws), overalls)
	# --- Chest: shirt + overalls bib + straps + buttons ---
	var chest: Node3D = nodes.get("chest") as Node3D
	if chest != null:
		var csize: Vector3 = Vector3(0.46 * ws, 0.36 * hs, 0.32 * ws)
		var m2: MeshInstance3D = _mesh(chest, PipeBuilder.rounded_box(csize, 0.08), shirt, ol)
		out["squash"].append(m2)
		var bib: MeshInstance3D = _mesh(chest, _box(Vector3(csize.x * 0.62, csize.y * 0.7, 0.04)), overalls, 0.0)
		bib.position = Vector3(0, -csize.y * 0.12, -csize.z * 0.5 - 0.01)
		for sx: float in [-1.0, 1.0]:
			var strap: MeshInstance3D = _mesh(chest, _box(Vector3(0.05, csize.y * 0.5, csize.z + 0.04)), overalls, 0.0)
			strap.position = Vector3(sx * csize.x * 0.26, csize.y * 0.22, 0)
			var btn: MeshInstance3D = _mesh(chest, _sphere(0.028), Color(1.0, 0.85, 0.2), 0.0)
			btn.position = Vector3(sx * csize.x * 0.24, csize.y * 0.15, -csize.z * 0.5 - 0.035)
		_pattern(chest, look.get_v("pattern"), Vector3(csize.x * 0.62, csize.y * 0.6, csize.z), overalls)
		_backpack(chest, look.get_v("backpack"), csize, look)
	# --- Head ---
	var head: Node3D = nodes.get("head") as Node3D
	if head != null:
		_head(head, look, head_s, ol, out)
	# --- Arms ---
	for side: String in ["l", "r"]:
		if simple:
			var arm: Node3D = nodes.get("arm_" + side) as Node3D
			if arm != null:
				var arm_len: float = 0.58 * hs
				var up: MeshInstance3D = _mesh(arm, _capsule(0.075 * ls, arm_len * 0.55), shirt, ol)
				up.position = Vector3(0, arm_len * 0.2, 0)
				var lo: MeshInstance3D = _mesh(arm, _capsule(0.065 * ls, arm_len * 0.55), skin, ol)
				lo.position = Vector3(0, -arm_len * 0.22, 0)
				_glove(arm, look.get_v("gloves"), glove_c, skin, Vector3(0, -arm_len * 0.5, 0), ol)
		else:
			var ua: Node3D = nodes.get("upper_arm_" + side) as Node3D
			if ua != null:
				_mesh(ua, _capsule(0.078 * ls, 0.32 * hs), shirt, ol)
			var la: Node3D = nodes.get("lower_arm_" + side) as Node3D
			if la != null:
				_mesh(la, _capsule(0.066 * ls, 0.29 * hs), skin, ol)
				_glove(la, look.get_v("gloves"), glove_c, skin, Vector3(0, -0.27 * hs * 0.5 - 0.03, 0), ol)
	# --- Legs ---
	for side2: String in ["l", "r"]:
		if simple:
			var leg: Node3D = nodes.get("leg_" + side2) as Node3D
			if leg != null:
				var leg_len: float = 0.76 * hs - 0.08
				_mesh(leg, _capsule(0.095 * ls, leg_len), overalls, ol)
				_boot(leg, look.get_v("boots"), boot_c, Vector3(0, -leg_len * 0.5 - 0.04, -0.05), ol)
		else:
			var th: Node3D = nodes.get("thigh_" + side2) as Node3D
			if th != null:
				_mesh(th, _capsule(0.1 * ls, 0.4 * hs), overalls, ol)
			var sh: Node3D = nodes.get("shin_" + side2) as Node3D
			if sh != null:
				var sh_len: float = 0.38 * hs - 0.07
				_mesh(sh, _capsule(0.088 * ls, sh_len + 0.06), overalls, ol)
				_boot(sh, look.get_v("boots"), boot_c, Vector3(0, -sh_len * 0.5 - 0.03, -0.05), ol)
	return out


## A static (no physics) plumber in rest pose, for menus and the customise screen.
static func build_preview(look: PlumberLook) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "PlumberPreview"
	# Reuse the rig layout by building throwaway bodies' rest positions.
	var sc: Vector4 = PlumberLook.build_scales(look.get_v("build"))
	var hs: float = sc.x
	var ws: float = sc.y
	var head_s: float = sc.w
	var pos: Dictionary = {
		"pelvis": Vector3(0, 0.86 * hs, 0),
		"chest": Vector3(0, 1.14 * hs, 0),
		"head": Vector3(0, 1.31 * hs + 0.2 * head_s, 0),
		"upper_arm_l": Vector3(-0.29 * ws, 1.26 * hs - 0.145 * hs, 0),
		"upper_arm_r": Vector3(0.29 * ws, 1.26 * hs - 0.145 * hs, 0),
		"lower_arm_l": Vector3(-0.29 * ws, 1.26 * hs - 0.29 * hs - 0.135 * hs, 0),
		"lower_arm_r": Vector3(0.29 * ws, 1.26 * hs - 0.29 * hs - 0.135 * hs, 0),
		"thigh_l": Vector3(-0.1 * ws, 0.76 * hs - (0.76 * hs - 0.38 * hs) * 0.5, 0),
		"thigh_r": Vector3(0.1 * ws, 0.76 * hs - (0.76 * hs - 0.38 * hs) * 0.5, 0),
		"shin_l": Vector3(-0.1 * ws, 0.07 + (0.38 * hs - 0.07) * 0.5, 0),
		"shin_r": Vector3(0.1 * ws, 0.07 + (0.38 * hs - 0.07) * 0.5, 0),
	}
	var nodes: Dictionary = {}
	for part: String in pos.keys():
		var n: Node3D = Node3D.new()
		n.name = part
		n.position = pos[part]
		root.add_child(n)
		nodes[part] = n
	var cosmetics: Dictionary = build(nodes, look, false, true)
	root.set_meta("cosmetics", cosmetics)
	root.set_meta("parts", nodes)
	return root


# --- Head & face ---------------------------------------------------------------

static func _head(head: Node3D, look: PlumberLook, hsz: float, ol: float, out: Dictionary) -> void:
	var skin: Color = look.color("skin")
	var r: float = 0.21 * hsz
	var hm: MeshInstance3D = _mesh(head, _sphere(r), skin, ol)
	out["squash"].append(hm)
	var front: float = -r * 0.82
	# Eyes
	var eyes: int = look.get_v("eyes")
	var eye_r: float = 0.068 * hsz
	var pupil_r: float = 0.034 * hsz
	var eye_pos: Array = [Vector3(-0.075 * hsz, 0.035 * hsz, front), Vector3(0.075 * hsz, 0.035 * hsz, front)]
	var whites: bool = true
	match eyes:
		1: pass                              # sleepy (lids added below)
		3:
			whites = false                   # tiny dots
			pupil_r = 0.022 * hsz
		4:
			eye_r = 0.092 * hsz              # huge
			pupil_r = 0.04 * hsz
		5:
			eye_pos = [Vector3(0, 0.045 * hsz, front)]   # cyclops
			eye_r = 0.11 * hsz
			pupil_r = 0.05 * hsz
	for ep: Variant in eye_pos:
		var p: Vector3 = ep as Vector3
		if whites:
			var w: MeshInstance3D = _mesh(head, _sphere(eye_r), Color(1, 1, 1), 0.012 if ol > 0.0 else 0.0)
			w.position = p
		var pupil: MeshInstance3D = _mesh(head, _sphere(pupil_r), Color(0.05, 0.05, 0.08), 0.0)
		var rest: Vector3 = p + Vector3(0, 0, -eye_r * 0.75 if whites else -0.01)
		pupil.position = rest
		(out["pupils"] as Array).append(pupil)
		(out["eye_rest"] as Array).append(rest)
		if eyes == 1:
			var lid: MeshInstance3D = _mesh(head, _sphere(eye_r * 1.08), skin.darkened(0.1), 0.0)
			lid.position = p + Vector3(0, eye_r * 0.55, -0.005)
			lid.scale = Vector3(1, 0.55, 1)
	# Brows (angry eyes always get angry brows)
	var brows: int = 2 if eyes == 2 else look.get_v("brows")
	if brows != 5:
		var brow_c: Color = Color(0.25, 0.15, 0.1)
		for i: int in eye_pos.size():
			var bp: Vector3 = (eye_pos[i] as Vector3) + Vector3(0, eye_r + 0.025, -0.01)
			var bw: float = 0.09 * hsz if brows != 3 else 0.2 * hsz
			if brows == 3 and i > 0:
				break
			if brows == 3:
				bp.x = 0.0
			var b: MeshInstance3D = _mesh(head, _box(Vector3(bw, 0.03 if brows != 1 else 0.016, 0.03)), brow_c, 0.0)
			b.position = bp
			var tilt: float = 0.0
			if brows == 2:
				tilt = 0.4 if bp.x < 0.0 else -0.4
			elif brows == 4:
				tilt = -0.25 if bp.x < 0.0 else 0.25
				b.position.y += 0.02
			elif brows == 0:
				b.scale = Vector3(1.1, 1.6, 1.0)
			b.rotation = Vector3(0, 0, tilt)
	# Nose
	var nose: int = look.get_v("nose")
	var nose_c: Color = skin.darkened(0.08)
	var nose_pos: Vector3 = Vector3(0, -0.02 * hsz, front - 0.03)
	match nose:
		0:
			_mesh(head, _sphere(0.05 * hsz), nose_c, 0.0).position = nose_pos
		1:
			var long_n: MeshInstance3D = _mesh(head, _capsule(0.035 * hsz, 0.16 * hsz), nose_c, 0.0)
			long_n.position = nose_pos + Vector3(0, -0.01, -0.05)
			long_n.rotation = Vector3(PI * 0.5 + 0.3, 0, 0)
		2:
			_mesh(head, _sphere(0.028 * hsz), nose_c, 0.0).position = nose_pos + Vector3(0, 0, 0.01)
		3:
			var pot: MeshInstance3D = _mesh(head, _sphere(0.065 * hsz), nose_c, 0.0)
			pot.position = nose_pos
			pot.scale = Vector3(1.1, 0.85, 1.0)
		4:
			var cone: CylinderMesh = CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.035 * hsz
			cone.height = 0.1 * hsz
			cone.radial_segments = 8
			var pn: MeshInstance3D = _mesh(head, cone, nose_c, 0.0)
			pn.position = nose_pos + Vector3(0, 0, -0.03)
			pn.rotation = Vector3(-PI * 0.5, 0, 0)
	# Mouth (scaled by the face animator for expressions)
	var mouth_root: Node3D = Node3D.new()
	mouth_root.name = "Mouth"
	mouth_root.position = Vector3(0, -0.1 * hsz, front + 0.02)
	head.add_child(mouth_root)
	var mouth: MeshInstance3D = _mesh(mouth_root, _sphere(0.045 * hsz), Color(0.35, 0.08, 0.1), 0.0)
	mouth.scale = Vector3(1.4, 0.45, 0.5)
	out["mouth"] = mouth_root
	# Mustache: a root that sways, with tips that lag behind (cosmetic only).
	var stache: int = look.get_v("mustache")
	if stache != 5:
		var sroot: Node3D = Node3D.new()
		sroot.name = "Mustache"
		sroot.position = Vector3(0, -0.06 * hsz, front - 0.02)
		head.add_child(sroot)
		out["stache"] = sroot
		var hair: Color = Color(0.3, 0.17, 0.1)
		match stache:
			0, 3:
				for sx: float in [-1.0, 1.0]:
					var tip: Node3D = Node3D.new()
					tip.position = Vector3(sx * 0.03, 0, 0)
					sroot.add_child(tip)
					var seg: MeshInstance3D = _mesh(tip, _capsule(0.022 * hsz, 0.11 * hsz), hair, 0.0)
					seg.position = Vector3(sx * 0.04, 0.0, 0)
					seg.rotation = Vector3(0, 0, sx * (1.2 if stache == 0 else 1.0))
					if stache == 3:
						var curl: TorusMesh = TorusMesh.new()
						curl.inner_radius = 0.012
						curl.outer_radius = 0.03
						var cm: MeshInstance3D = _mesh(tip, curl, hair, 0.0)
						cm.position = Vector3(sx * 0.1, 0.03, 0)
						cm.rotation = Vector3(PI * 0.5, 0, 0)
					(out["stache_tips"] as Array).append(tip)
			1:
				var wal: MeshInstance3D = _mesh(sroot, _box(Vector3(0.17 * hsz, 0.07 * hsz, 0.05)), hair, 0.0)
				wal.position = Vector3(0, -0.025, 0)
				for sx2: float in [-1.0, 1.0]:
					var tip2: Node3D = Node3D.new()
					tip2.position = Vector3(sx2 * 0.07 * hsz, -0.03, 0)
					sroot.add_child(tip2)
					_mesh(tip2, _capsule(0.025, 0.08), hair, 0.0).position = Vector3(0, -0.03, 0)
					(out["stache_tips"] as Array).append(tip2)
			2:
				var pen: MeshInstance3D = _mesh(sroot, _box(Vector3(0.12 * hsz, 0.012, 0.02)), hair, 0.0)
				pen.position = Vector3(0, -0.012, 0)
			4:
				for i: int in 3:
					var puff: Node3D = Node3D.new()
					puff.position = Vector3((float(i) - 1.0) * 0.045 * hsz, 0, 0)
					sroot.add_child(puff)
					_mesh(puff, _sphere(0.035 * hsz), Color(0.92, 0.92, 0.9), 0.0)
					(out["stache_tips"] as Array).append(puff)
	_headgear(head, look.get_v("headgear"), r, look, ol)


static func _headgear(head: Node3D, kind: int, r: float, look: PlumberLook, ol: float) -> void:
	var acc: Color = look.color("accent")
	match kind:
		0:  # cap with lamp
			var cap: MeshInstance3D = _mesh(head, _sphere(r * 1.02), look.color("overalls"), ol)
			cap.position = Vector3(0, r * 0.25, 0)
			cap.scale = Vector3(1, 0.62, 1)
			var brim: MeshInstance3D = _mesh(head, _box(Vector3(r * 1.4, 0.03, r * 0.8)), look.color("overalls").darkened(0.2), 0.0)
			brim.position = Vector3(0, r * 0.38, -r * 0.85)
			var lamp: MeshInstance3D = _mesh(head, _sphere(0.045), Color(1, 1, 0.7), 0.0)
			lamp.material_override = Mats.glow(Color(1.0, 0.98, 0.7))
			lamp.position = Vector3(0, r * 0.62, -r * 0.88)
		1:  # bucket
			var b: CylinderMesh = CylinderMesh.new()
			b.top_radius = r * 0.85
			b.bottom_radius = r * 1.05
			b.height = r * 0.9
			var bk: MeshInstance3D = _mesh(head, b, Color(0.6, 0.65, 0.72), ol)
			bk.position = Vector3(0, r * 0.75, 0)
		2:  # fishbowl helmet
			var bowl: MeshInstance3D = MeshInstance3D.new()
			bowl.mesh = _sphere(r * 1.45)
			bowl.material_override = Mats.glass()
			bowl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			head.add_child(bowl)
			var ring: TorusMesh = TorusMesh.new()
			ring.inner_radius = r * 0.95
			ring.outer_radius = r * 1.15
			_mesh(head, ring, Color(0.75, 0.78, 0.85), 0.0).position = Vector3(0, -r * 0.95, 0)
		3:  # plunger hat
			var cup: CylinderMesh = CylinderMesh.new()
			cup.top_radius = r * 0.35
			cup.bottom_radius = r * 0.8
			cup.height = r * 0.5
			_mesh(head, cup, Color(0.85, 0.15, 0.2), ol).position = Vector3(0, r * 0.95, 0)
			var stick: MeshInstance3D = _mesh(head, _capsule(0.025, r * 1.6), Color(0.75, 0.5, 0.25), 0.0)
			stick.position = Vector3(0, r * 1.75, 0)
		4:  # hard hat
			var hh: MeshInstance3D = _mesh(head, _sphere(r * 1.08), Color(1.0, 0.8, 0.15), ol)
			hh.position = Vector3(0, r * 0.3, 0)
			hh.scale = Vector3(1, 0.65, 1)
			var hb: CylinderMesh = CylinderMesh.new()
			hb.top_radius = r * 1.3
			hb.bottom_radius = r * 1.3
			hb.height = 0.025
			_mesh(head, hb, Color(1.0, 0.75, 0.1), 0.0).position = Vector3(0, r * 0.3, 0)
		5:  # visor
			var vis: MeshInstance3D = _mesh(head, _box(Vector3(r * 1.9, r * 0.3, r * 0.5)), Color(0.2, 0.9, 0.95), 0.0)
			vis.material_override = Mats.toon_glow(Color(0.2, 0.9, 0.95), 0.4, false)
			vis.position = Vector3(0, r * 0.2, -r * 0.7)
		6:  # beanie with antenna
			var bean: MeshInstance3D = _mesh(head, _sphere(r * 1.03), acc, ol)
			bean.position = Vector3(0, r * 0.3, 0)
			bean.scale = Vector3(1, 0.7, 1)
			var ant: MeshInstance3D = _mesh(head, _capsule(0.012, r * 1.2), Color(0.3, 0.3, 0.35), 0.0)
			ant.position = Vector3(0, r * 1.4, 0)
			var ball: MeshInstance3D = _mesh(head, _sphere(0.04), Color(1, 0.3, 0.4), 0.0)
			ball.material_override = Mats.glow(Color(1.0, 0.35, 0.45))
			ball.position = Vector3(0, r * 2.05, 0)
		7:  # chef hat
			var band: CylinderMesh = CylinderMesh.new()
			band.top_radius = r * 0.85
			band.bottom_radius = r * 0.85
			band.height = r * 0.7
			_mesh(head, band, Color(0.97, 0.97, 0.97), ol).position = Vector3(0, r * 0.95, 0)
			for i: int in 3:
				var puff: MeshInstance3D = _mesh(head, _sphere(r * 0.55), Color(0.98, 0.98, 0.98), 0.0)
				puff.position = Vector3((float(i) - 1.0) * r * 0.45, r * 1.5, 0)


static func _backpack(chest: Node3D, kind: int, csize: Vector3, look: PlumberLook) -> void:
	var back: float = csize.z * 0.5 + 0.08
	var acc: Color = look.color("accent")
	match kind:
		0:
			var tank: MeshInstance3D = _mesh(chest, _capsule(0.09, 0.4), Color(0.75, 0.8, 0.88), 0.0)
			tank.position = Vector3(0, 0, back + 0.02)
		1:
			for i: int in 3:
				var pipe: MeshInstance3D = _mesh(chest, _capsule(0.045, 0.5), Color(1.0, 0.55, 0.2), 0.0)
				pipe.position = Vector3((float(i) - 1.0) * 0.09, 0.02, back)
		2:
			var tb: MeshInstance3D = _mesh(chest, _box(Vector3(0.32, 0.24, 0.14)), Color(0.85, 0.18, 0.2), 0.0)
			tb.position = Vector3(0, -0.02, back)
			var handle: MeshInstance3D = _mesh(chest, _box(Vector3(0.14, 0.03, 0.03)), Color(0.2, 0.2, 0.25), 0.0)
			handle.position = Vector3(0, 0.12, back)
		3:
			for sx: float in [-1.0, 1.0]:
				var noz: MeshInstance3D = _mesh(chest, _capsule(0.06, 0.3), Color(0.55, 0.58, 0.65), 0.0)
				noz.position = Vector3(sx * 0.09, 0, back)
				var flame: CylinderMesh = CylinderMesh.new()
				flame.top_radius = 0.05
				flame.bottom_radius = 0.0
				flame.height = 0.12
				var fm: MeshInstance3D = MeshInstance3D.new()
				fm.mesh = flame
				fm.material_override = Mats.glow(Color(1.0, 0.6, 0.15))
				fm.position = Vector3(sx * 0.09, -0.22, back)
				chest.add_child(fm)
		4:
			var ring: TorusMesh = TorusMesh.new()
			ring.inner_radius = 0.16
			ring.outer_radius = 0.28
			var duck_ring: MeshInstance3D = _mesh(chest, ring, Color(1.0, 0.85, 0.15), 0.0)
			duck_ring.position = Vector3(0, -0.12, 0)
			var dh: MeshInstance3D = _mesh(chest, _sphere(0.07), Color(1.0, 0.85, 0.15), 0.0)
			dh.position = Vector3(0, -0.02, back + 0.1)
			var beak: MeshInstance3D = _mesh(chest, _box(Vector3(0.05, 0.025, 0.06)), Color(1.0, 0.5, 0.1), 0.0)
			beak.position = Vector3(0, -0.03, back + 0.17)
	if kind != 5 and kind != 4:
		var strap: MeshInstance3D = _mesh(chest, _box(Vector3(csize.x * 0.9, 0.035, 0.03)), acc.darkened(0.4), 0.0)
		strap.position = Vector3(0, 0.08, back - 0.04)


static func _pattern(node: Node3D, kind: int, size: Vector3, base: Color) -> void:
	var front: float = -size.z * 0.5 - 0.012
	match kind:
		1:  # stripes
			for i: int in 3:
				var s: MeshInstance3D = _mesh(node, _box(Vector3(size.x * 0.9, 0.025, 0.012)), base.lightened(0.35), 0.0)
				s.position = Vector3(0, (float(i) - 1.0) * size.y * 0.25, front)
		2:  # patches
			var p: MeshInstance3D = _mesh(node, _box(Vector3(0.08, 0.08, 0.012)), base.darkened(0.3), 0.0)
			p.position = Vector3(size.x * 0.22, -size.y * 0.15, front)
			p.rotation = Vector3(0, 0, 0.3)
			var p2: MeshInstance3D = _mesh(node, _box(Vector3(0.06, 0.07, 0.012)), Color(0.95, 0.8, 0.3), 0.0)
			p2.position = Vector3(-size.x * 0.2, size.y * 0.15, front)
		3:  # polka dots
			for i: int in 5:
				var d: MeshInstance3D = _mesh(node, _sphere(0.022), Color(0.97, 0.97, 0.97), 0.0)
				d.position = Vector3(sin(i * 2.3) * size.x * 0.3, cos(i * 1.9) * size.y * 0.3, front)
				d.scale = Vector3(1, 1, 0.3)
		4:  # hazard stripes
			for i: int in 4:
				var h: MeshInstance3D = _mesh(node, _box(Vector3(0.05, size.y * 0.7, 0.012)), Color(1.0, 0.82, 0.1) if i % 2 == 0 else Color(0.1, 0.1, 0.1), 0.0)
				h.position = Vector3((float(i) - 1.5) * 0.06, 0, front)
				h.rotation = Vector3(0, 0, 0.5)
		5:  # stars
			for i: int in 3:
				var star: CylinderMesh = CylinderMesh.new()
				star.top_radius = 0.035
				star.bottom_radius = 0.035
				star.height = 0.01
				star.radial_segments = 5
				var sm: MeshInstance3D = _mesh(node, star, Color(1.0, 0.9, 0.3), 0.0)
				sm.position = Vector3((float(i) - 1.0) * size.x * 0.28, sin(float(i) * 2.0) * size.y * 0.2, front)
				sm.rotation = Vector3(PI * 0.5, 0, 0)


static func _glove(node: Node3D, kind: int, col: Color, skin: Color, at: Vector3, ol: float) -> void:
	var m: MeshInstance3D
	match kind:
		1:
			m = _mesh(node, _capsule(0.07, 0.17), col, ol)
		2:
			m = _mesh(node, _sphere(0.06), col, ol)
		3:
			m = _mesh(node, _sphere(0.07), skin, ol)
		4:
			m = _mesh(node, PipeBuilder.rounded_box(Vector3(0.17, 0.2, 0.12), 0.04), Color(0.9, 0.85, 0.75), ol)
		5:
			m = _mesh(node, _sphere(0.11), Color(0.85, 0.15, 0.2), ol)
		_:
			m = _mesh(node, _sphere(0.09), col, ol)
	m.position = at


static func _boot(node: Node3D, kind: int, col: Color, at: Vector3, ol: float) -> void:
	var size: Vector3 = Vector3(0.16, 0.12, 0.3)
	var c: Color = col
	match kind:
		1: size = Vector3(0.17, 0.14, 0.3)
		2: size = Vector3(0.11, 0.08, 0.2)
		3:
			size = Vector3(0.12, 0.08, 0.24)
			c = Color(0.95, 0.95, 0.95)
		4:
			size = Vector3(0.2, 0.05, 0.42)
			c = Color(0.2, 0.75, 0.4)
		5: size = Vector3(0.16, 0.22, 0.3)
	var m: MeshInstance3D = _mesh(node, PipeBuilder.rounded_box(size, 0.04), c, ol)
	m.position = at + Vector3(0, size.y * 0.5 - 0.04, -0.02 if kind != 4 else -0.08)
	if kind == 1:
		var fl: CylinderMesh = CylinderMesh.new()
		fl.top_radius = 0.06
		fl.bottom_radius = 0.0
		fl.height = 0.12
		var f: MeshInstance3D = MeshInstance3D.new()
		f.mesh = fl
		f.material_override = Mats.glow(Color(1.0, 0.55, 0.15))
		f.position = at + Vector3(0, -0.06, 0.12)
		node.add_child(f)


# --- primitive helpers -------------------------------------------------------

static func _mesh(parent: Node3D, mesh: Mesh, color: Color, outline: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Mats.toon(color, outline > 0.0, outline)
	parent.add_child(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c: CapsuleMesh = CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.01)
	c.radial_segments = 12
	c.rings = 4
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	return b
