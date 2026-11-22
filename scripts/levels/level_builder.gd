class_name LevelBuilder
extends RefCounted
## Builds a level from plain data (see scripts/levels/level_data/*.gd).
## Visual parts: sky + light, box rooms with doorways and windows, rounded
## edges, glowing pipes, lamps and MultiMesh bolts. Gameplay parts (props,
## leaks, valves, switches, gravity fields, spawn pads...) are created by
## LevelRunner through the "spawn" hooks, so this file stays about geometry.

const WALL_T: float = 0.4

## Lighting budget (Linear tone mapping, so what we set is what you see):
## a fully lit surface gets ambient + sun ~= 1.1 x its colour, the shadow side
## ~0.4 x. Palette colours stay below ~0.85 so nothing burns out to white.
const AMBIENT_ENERGY: float = 0.5
const SUN_ENERGY: float = 0.8
const LAMP_ENERGY: float = 0.4

const DEFAULT_PALETTE: Dictionary = {
	"floor": Color(0.3, 0.38, 0.6),
	"wall": Color(0.66, 0.71, 0.82),
	"ceiling": Color(0.45, 0.49, 0.64),
	"trim": Color(0.95, 0.68, 0.2),
	"lamp": Color(1.0, 0.95, 0.8),
	"ambient": Color(0.62, 0.66, 0.9),
	"nebula_a": Color(0.35, 0.1, 0.45),
	"nebula_b": Color(0.05, 0.3, 0.45),
	"planet": Color(1.0, 0.55, 0.3),
}

## Pipe colour codes by function (shared accent set).
const PIPE_COLORS: Dictionary = {
	"orange": Color(1.0, 0.55, 0.2),    # main sludge line
	"teal": Color(0.15, 0.75, 0.75),    # fresh water
	"purple": Color(0.6, 0.3, 0.85),    # waste
	"yellow": Color(1.0, 0.82, 0.2),    # gravity conduits (switch-related)
	"grey": Color(0.55, 0.58, 0.65),    # structural, climbable
}


static func palette_color(palette: Dictionary, key: String) -> Color:
	if palette.has(key):
		return palette[key] as Color
	return DEFAULT_PALETTE.get(key, Color.WHITE) as Color


## Sky, ambient light and the one directional (shadow) light.
## Returns {"sky_material": ShaderMaterial, "sun": DirectionalLight3D, "environment": Environment}
static func build_environment(parent: Node, palette: Dictionary) -> Dictionary:
	var sky_mat: ShaderMaterial = Mats.new_sky_material()
	sky_mat.set_shader_parameter("nebula_a", palette_color(palette, "nebula_a"))
	sky_mat.set_shader_parameter("nebula_b", palette_color(palette, "nebula_b"))
	sky_mat.set_shader_parameter("planet_color", palette_color(palette, "planet"))
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = palette_color(palette, "ambient")
	apply_exposure(e)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = e
	parent.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(-0.95, 0.55, 0.0)
	setup_sun(sun)
	parent.add_child(sun)
	return {"sky_material": sky_mat, "sun": sun, "environment": e}


## Exposure shared by every 3D scene (levels, test rooms, the customise stage).
## Linear tone mapping keeps the cartoon colours pure; the old Filmic setup with
## white = 1.0 clipped everything brighter than 1 to flat white.
static func apply_exposure(e: Environment) -> void:
	e.ambient_light_energy = AMBIENT_ENERGY
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	e.glow_enabled = false


## The one shadow-casting light. Soft-edged shadows ground objects on the floor.
static func setup_sun(sun: DirectionalLight3D) -> void:
	sun.light_energy = SUN_ENERGY
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = Quality.shadows
	sun.shadow_blur = 1.5
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0


## Floors get tiles, walls panels, ceilings big panels; all without the rim glow.
static func surface_material(palette: Dictionary, key: String) -> Material:
	var col: Color = palette_color(palette, key)
	match key:
		"floor":
			return Mats.surface(col, 1, 1.0, 0.16)
		"wall":
			return Mats.surface(col, 2, 1.25, 0.12)
		"ceiling":
			return Mats.surface(col, 2, 2.0, 0.1)
	return Mats.surface(col)


## Build one box room. spec keys:
##   center: Vector3, size: Vector3 (inner size)
##   openings: [{"wall": "-z", "at": Vector2(u, v), "size": Vector2(w, h), "window": bool}]
##   skip: ["+x", ...]  walls not to build (to join modules)
##   lamp: bool (default true), pipes_trim: bool
static func build_room(parent: Node, spec: Dictionary, palette: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Room_" + str(spec.get("id", "x"))
	parent.add_child(root)
	var c: Vector3 = spec.get("center", Vector3.ZERO)
	var s: Vector3 = spec.get("size", Vector3(8, 4, 8))
	var skip: Array = spec.get("skip", [])
	var openings: Array = spec.get("openings", [])
	for wall_id: String in ["-y", "+y", "-x", "+x", "-z", "+z"]:
		if skip.has(wall_id):
			continue
		var wall_openings: Array = []
		for o: Variant in openings:
			if (o as Dictionary).get("wall", "") == wall_id:
				wall_openings.append(o)
		var key: String = "floor" if wall_id == "-y" else ("ceiling" if wall_id == "+y" else "wall")
		_build_wall(root, c, s, wall_id, wall_openings, palette_color(palette, key), surface_material(palette, key))
	_build_edges(root, c, s, skip, palette_color(palette, "trim"))
	if bool(spec.get("lamp", true)):
		_build_lamp(root, c + Vector3(0, s.y * 0.5 - 0.1, 0), s, palette)
	return root


static func _axes(wall_id: String) -> Array:
	## Returns [u axis, v axis, n axis] as Vector3 for a wall.
	match wall_id.substr(1):
		"x":
			return [Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)]
		"y":
			return [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)]
	return [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]


static func _wall_extent(wall_id: String, s: Vector3) -> Vector2:
	match wall_id.substr(1):
		"x":
			return Vector2(s.z + 2.0 * WALL_T, s.y)
		"y":
			return Vector2(s.x + 2.0 * WALL_T, s.z + 2.0 * WALL_T)
	return Vector2(s.x, s.y)


static func _build_wall(parent: Node3D, c: Vector3, s: Vector3, wall_id: String, openings: Array, color: Color, mat: Material = null) -> void:
	var ax: Array = _axes(wall_id)
	var u: Vector3 = ax[0]
	var v: Vector3 = ax[1]
	var n: Vector3 = ax[2]
	var sign_n: float = -1.0 if wall_id.begins_with("-") else 1.0
	var half_inner: float = absf(s.dot(n)) * 0.5
	var wall_center: Vector3 = c + n * sign_n * (half_inner + WALL_T * 0.5)
	var ext: Vector2 = _wall_extent(wall_id, s)
	var rects: Array = []   # [umin, umax, vmin, vmax]
	for o: Variant in openings:
		var od: Dictionary = o as Dictionary
		var at: Vector2 = od.get("at", Vector2.ZERO)
		var sz: Vector2 = od.get("size", Vector2(2, 2))
		rects.append([at.x - sz.x * 0.5, at.x + sz.x * 0.5, at.y - sz.y * 0.5, at.y + sz.y * 0.5, bool(od.get("window", false))])
	rects.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var hu: float = ext.x * 0.5
	var hv: float = ext.y * 0.5
	var cur: float = -hu
	for r: Variant in rects:
		var ra: Array = r as Array
		var umin: float = clampf(float(ra[0]), -hu, hu)
		var umax: float = clampf(float(ra[1]), -hu, hu)
		var vmin: float = clampf(float(ra[2]), -hv, hv)
		var vmax: float = clampf(float(ra[3]), -hv, hv)
		if umin > cur + 0.001:
			_wall_piece(parent, wall_center, u, v, n, cur, umin, -hv, hv, color, mat)
		if vmin > -hv + 0.001:
			_wall_piece(parent, wall_center, u, v, n, umin, umax, -hv, vmin, color, mat)
		if vmax < hv - 0.001:
			_wall_piece(parent, wall_center, u, v, n, umin, umax, vmax, hv, color, mat)
		if bool(ra[4]):
			_window(parent, wall_center, u, v, n, umin, umax, vmin, vmax)
		cur = maxf(cur, umax)
	if cur < hu - 0.001:
		_wall_piece(parent, wall_center, u, v, n, cur, hu, -hv, hv, color, mat)


static func _wall_piece(parent: Node3D, wc: Vector3, u: Vector3, v: Vector3, n: Vector3,
		umin: float, umax: float, vmin: float, vmax: float, color: Color, mat: Material = null) -> void:
	var center: Vector3 = wc + u * (umin + umax) * 0.5 + v * (vmin + vmax) * 0.5
	var size: Vector3 = u * (umax - umin) + v * (vmax - vmin) + n * WALL_T
	size = Vector3(absf(size.x), absf(size.y), absf(size.z))
	var sb: StaticBody3D = Geo.static_box(parent, center, size, color, Vector3.ZERO, mat)
	sb.add_to_group("level_static")


static func _window(parent: Node3D, wc: Vector3, u: Vector3, v: Vector3, n: Vector3,
		umin: float, umax: float, vmin: float, vmax: float) -> void:
	var center: Vector3 = wc + u * (umin + umax) * 0.5 + v * (vmin + vmax) * 0.5
	var w: float = umax - umin
	var h: float = vmax - vmin
	# Glass: a solid collider (you can't fall out) with a see-through mesh.
	var sb: StaticBody3D = StaticBody3D.new()
	sb.position = center
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	var size: Vector3 = u * w + v * h + n * 0.1
	bs.size = Vector3(absf(size.x), absf(size.y), absf(size.z))
	cs.shape = bs
	sb.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	mi.material_override = Mats.glass()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sb.add_child(mi)
	parent.add_child(sb)
	# Chunky frame in the trim colour.
	var frame_col: Color = Color(1.0, 0.82, 0.2)
	var f: float = 0.18
	var mat: Material = Mats.toon(frame_col.darkened(0.15))
	for i: int in 4:
		var fc: Vector3
		var fs: Vector3
		if i < 2:
			fc = center + v * (h * 0.5 + f * 0.5) * (1.0 if i == 0 else -1.0)
			fs = u * (w + 2.0 * f) + v * f + n * (WALL_T + 0.1)
		else:
			fc = center + u * (w * 0.5 + f * 0.5) * (1.0 if i == 2 else -1.0)
			fs = u * f + v * h + n * (WALL_T + 0.1)
		var fm: MeshInstance3D = MeshInstance3D.new()
		var fb: BoxMesh = BoxMesh.new()
		fb.size = Vector3(absf(fs.x), absf(fs.y), absf(fs.z))
		fm.mesh = fb
		fm.material_override = mat
		fm.position = fc
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(fm)


## Rounded look: chunky cylinders along the floor and ceiling edges.
static func _build_edges(parent: Node3D, c: Vector3, s: Vector3, skip: Array, color: Color) -> void:
	var mat: Material = Mats.toon(color, false, 0.025, 0.15)
	var r: float = 0.22
	var h: Vector3 = s * 0.5
	for y_sign: float in [-1.0, 1.0]:
		for i: int in 4:
			var wall_id: String = ["-x", "+x", "-z", "+z"][i]
			if skip.has(wall_id):
				continue
			var mi: MeshInstance3D = MeshInstance3D.new()
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = r
			cyl.bottom_radius = r
			cyl.radial_segments = 8
			cyl.rings = 1
			var pos: Vector3
			var dir: Vector3
			if i < 2:
				cyl.height = s.z
				pos = c + Vector3(h.x * (-1.0 if i == 0 else 1.0), h.y * y_sign, 0)
				dir = Vector3(0, 0, 1)
			else:
				cyl.height = s.x
				pos = c + Vector3(0, h.y * y_sign, h.z * (-1.0 if i == 2 else 1.0))
				dir = Vector3(1, 0, 0)
			mi.mesh = cyl
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.transform = Transform3D(PipeBuilder.basis_along(dir), pos)
			parent.add_child(mi)


static func _build_lamp(parent: Node3D, pos: Vector3, room_size: Vector3, palette: Dictionary) -> void:
	var lamp_col: Color = palette_color(palette, "lamp")
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(minf(3.0, room_size.x * 0.4), 0.08, 0.5)
	mi.mesh = bm
	mi.material_override = Mats.glow(lamp_col)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if Quality.preset_name != "low":
		var omni: OmniLight3D = OmniLight3D.new()
		omni.position = pos - Vector3(0, 0.6, 0)
		omni.omni_range = maxf(room_size.x, room_size.z) * 0.8
		omni.light_energy = LAMP_ENERGY
		omni.omni_attenuation = 0.8   # soft pool of light, no hot spot
		omni.light_color = lamp_col
		omni.shadow_enabled = false
		parent.add_child(omni)


## A row of bolts along a line, drawn with ONE MultiMesh.
static func bolts_along(parent: Node, a: Vector3, b: Vector3, normal: Vector3, count: int) -> void:
	var xforms: Array = []
	var basis: Basis = PipeBuilder.basis_along(normal)
	for i: int in count:
		var t: float = (float(i) + 0.5) / float(count)
		xforms.append(Transform3D(basis, a.lerp(b, t)))
	PipeBuilder.multimesh(parent, PipeBuilder.bolt_mesh(), xforms, Mats.toon(Color(0.7, 0.72, 0.8)))


## Decorative + climbable pipes. spec: {"points": [Vector3...], "radius": float,
## "color": "orange"|"teal"|..., "glow": bool, "collide": bool}
static func build_pipe(parent: Node, spec: Dictionary) -> StaticBody3D:
	var pts: PackedVector3Array = PackedVector3Array()
	for p: Variant in spec.get("points", []):
		pts.append(p as Vector3)
	if pts.size() < 2:
		return null
	var col_name: String = str(spec.get("color", "orange"))
	var col: Color = PIPE_COLORS.get(col_name, PIPE_COLORS["orange"]) as Color
	var sb: StaticBody3D = PipeBuilder.pipe_run(parent, pts, float(spec.get("radius", 0.15)), col,
		bool(spec.get("glow", false)), bool(spec.get("collide", true)))
	sb.add_to_group("grabbable_static")
	return sb


## A planetoid: a static lumpy rock (sphere collision) of radius r.
static func build_rock(parent: Node, center: Vector3, r: float, color: Color) -> StaticBody3D:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = "Rock"
	sb.position = center
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = r
	cs.shape = shape
	sb.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	mi.material_override = Mats.toon(color)
	sb.add_child(mi)
	# A few craters/bumps for charm.
	for i: int in 7:
		var dir: Vector3 = Vector3(sin(i * 2.4), cos(i * 1.7), sin(i * 3.1)).normalized()
		var bump: MeshInstance3D = MeshInstance3D.new()
		var bs: SphereMesh = SphereMesh.new()
		bs.radius = r * 0.25
		bs.height = r * 0.25
		bump.mesh = bs
		bump.material_override = Mats.toon(color.darkened(0.15))
		bump.position = dir * r * 0.92
		sb.add_child(bump)
	sb.add_to_group("grabbable_static")
	parent.add_child(sb)
	return sb
