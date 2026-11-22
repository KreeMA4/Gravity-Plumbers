class_name PipeBuilder
extends RefCounted
## Procedural pipe meshes. Pipes ARE the level design (climb them, grab them,
## patch them), so they are cheap: one merged ArrayMesh per pipe run.
##
##   PipeBuilder.tube(points, radius)          tube along a polyline with rounded bends
##   PipeBuilder.pipe_run(parent, points, ...) tube mesh + collision + flanges + bolts
##   PipeBuilder.valve_wheel(radius)           a wheel mesh for valves
##   PipeBuilder.flange_mesh(radius)           short wide ring
##   PipeBuilder.rounded_box(size, r)          a box with soft edges (capsule-ish)

const SIDES: int = 10

static var _bolt_mesh: Mesh = null
static var _flange_cache: Dictionary = {}


## Round the corners of a polyline: each inner corner is replaced by a small arc.
static func round_corners(points: PackedVector3Array, bend_radius: float, steps: int = 5) -> PackedVector3Array:
	if points.size() < 3:
		return points
	var out: PackedVector3Array = PackedVector3Array()
	out.append(points[0])
	for i: int in range(1, points.size() - 1):
		var prev: Vector3 = points[i - 1]
		var cur: Vector3 = points[i]
		var nxt: Vector3 = points[i + 1]
		var a: Vector3 = (prev - cur)
		var b: Vector3 = (nxt - cur)
		var r: float = minf(bend_radius, minf(a.length(), b.length()) * 0.45)
		var p0: Vector3 = cur + a.normalized() * r
		var p1: Vector3 = cur + b.normalized() * r
		for s: int in steps + 1:
			var t: float = float(s) / float(steps)
			# Quadratic Bezier through the corner gives a nice soft bend.
			var q: Vector3 = p0.lerp(cur, t).lerp(cur.lerp(p1, t), t)
			out.append(q)
	out.append(points[points.size() - 1])
	return out


## A tube mesh along `points`, using parallel-transport frames so it never twists.
static func tube(points: PackedVector3Array, radius: float, bend_radius: float = 0.4, sides: int = SIDES, caps: bool = true) -> ArrayMesh:
	var pts: PackedVector3Array = round_corners(points, bend_radius)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if pts.size() < 2:
		return ArrayMesh.new()
	var tangent: Vector3 = (pts[1] - pts[0]).normalized()
	var normal: Vector3 = GravityMath.perpendicular(tangent)
	var rings: Array = []
	for i: int in pts.size():
		var t: Vector3
		if i == 0:
			t = (pts[1] - pts[0]).normalized()
		elif i == pts.size() - 1:
			t = (pts[i] - pts[i - 1]).normalized()
		else:
			t = ((pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()).normalized()
		if t.length_squared() < 0.5:
			t = tangent
		# Parallel transport: rotate the previous normal onto the new tangent.
		var q: Quaternion = GravityMath.quat_between(tangent, t)
		normal = (q * normal).normalized()
		tangent = t
		var binormal: Vector3 = t.cross(normal).normalized()
		var ring: Array = []
		for s: int in sides:
			var ang: float = TAU * float(s) / float(sides)
			var n: Vector3 = normal * cos(ang) + binormal * sin(ang)
			ring.append(n)
		rings.append(ring)
	for i: int in pts.size() - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for s: int in sides:
			var s2: int = (s + 1) % sides
			var n00: Vector3 = r0[s]
			var n01: Vector3 = r0[s2]
			var n10: Vector3 = r1[s]
			var n11: Vector3 = r1[s2]
			_vert(st, pts[i] + n00 * radius, n00)
			_vert(st, pts[i + 1] + n10 * radius, n10)
			_vert(st, pts[i] + n01 * radius, n01)
			_vert(st, pts[i] + n01 * radius, n01)
			_vert(st, pts[i + 1] + n10 * radius, n10)
			_vert(st, pts[i + 1] + n11 * radius, n11)
	if caps:
		_cap(st, pts[0], -(pts[1] - pts[0]).normalized(), rings[0] as Array, radius, true)
		var last: int = pts.size() - 1
		_cap(st, pts[last], (pts[last] - pts[last - 1]).normalized(), rings[last] as Array, radius, false)
	return st.commit()


static func _vert(st: SurfaceTool, p: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(p)


static func _cap(st: SurfaceTool, center: Vector3, n: Vector3, ring: Array, radius: float, flip: bool) -> void:
	var count: int = ring.size()
	for s: int in count:
		var a: Vector3 = center + (ring[s] as Vector3) * radius
		var b: Vector3 = center + (ring[(s + 1) % count] as Vector3) * radius
		# Godot treats clockwise triangles as front faces.
		if flip:
			_vert(st, center, n)
			_vert(st, a, n)
			_vert(st, b, n)
		else:
			_vert(st, center, n)
			_vert(st, b, n)
			_vert(st, a, n)


## Build a static, grabbable pipe along `points` (world space, under `parent`).
## Returns the StaticBody3D (group "pipes" and "grabbable_static").
static func pipe_run(parent: Node, points: PackedVector3Array, radius: float, color: Color, glow: bool = false, collide: bool = true) -> StaticBody3D:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = "Pipe"
	sb.add_to_group("pipes")
	parent.add_child(sb)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = tube(points, radius, maxf(radius * 2.5, 0.3))
	mi.material_override = Mats.toon_glow(color, 0.25, false) if glow else Mats.toon(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sb.add_child(mi)
	if collide:
		for i: int in points.size() - 1:
			var a: Vector3 = points[i]
			var b: Vector3 = points[i + 1]
			var length: float = a.distance_to(b)
			if length < 0.01:
				continue
			var cs: CollisionShape3D = CollisionShape3D.new()
			var cyl: CylinderShape3D = CylinderShape3D.new()
			cyl.radius = radius
			cyl.height = length
			cs.shape = cyl
			cs.transform = Transform3D(basis_along(b - a), (a + b) * 0.5)
			sb.add_child(cs)
	# Flanges at both ends and at every corner for that plumbing look.
	var flange: Mesh = flange_mesh(radius)
	var fl_mat: Material = Mats.toon(color.darkened(0.25))
	for i: int in points.size():
		var dir: Vector3
		if i < points.size() - 1:
			dir = points[i + 1] - points[i]
		else:
			dir = points[i] - points[i - 1]
		var f: MeshInstance3D = MeshInstance3D.new()
		f.mesh = flange
		f.material_override = fl_mat
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var at: Vector3 = points[i]
		if i > 0 and i < points.size() - 1:
			# corners: put the flange a little after the bend
			at = points[i] + dir.normalized() * minf(0.5, dir.length() * 0.3)
		f.transform = Transform3D(basis_along(dir), at)
		sb.add_child(f)
	return sb


## Basis whose Y axis points along `dir` (cylinders and capsules are Y-up).
static func basis_along(dir: Vector3) -> Basis:
	var y: Vector3 = dir.normalized()
	if y.length_squared() < 0.5:
		return Basis.IDENTITY
	var x: Vector3 = GravityMath.perpendicular(y)
	var z: Vector3 = x.cross(y).normalized()
	return Basis(x, y, z)


static func flange_mesh(radius: float) -> Mesh:
	var key: String = "%.3f" % radius
	if _flange_cache.has(key):
		return _flange_cache[key] as Mesh
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = radius * 1.45
	c.bottom_radius = radius * 1.45
	c.height = radius * 0.7
	c.radial_segments = SIDES
	c.rings = 1
	_flange_cache[key] = c
	return c


static func valve_wheel(radius: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = radius * 0.82
	torus.outer_radius = radius
	torus.rings = 20
	torus.ring_segments = 8
	st.append_from(torus, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
	var spoke: BoxMesh = BoxMesh.new()
	spoke.size = Vector3(radius * 1.8, radius * 0.12, radius * 0.12)
	st.append_from(spoke, 0, Transform3D.IDENTITY)
	st.append_from(spoke, 0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO))
	var hub: CylinderMesh = CylinderMesh.new()
	hub.top_radius = radius * 0.2
	hub.bottom_radius = radius * 0.2
	hub.height = radius * 0.3
	st.append_from(hub, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
	return st.commit()


## A soft-edged box made from a box core plus capsule-ish edges (cheap look).
static func rounded_box(size: Vector3, r: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var core: BoxMesh = BoxMesh.new()
	core.size = Vector3(maxf(0.01, size.x - 2.0 * r), size.y, maxf(0.01, size.z - 2.0 * r))
	st.append_from(core, 0, Transform3D.IDENTITY)
	var side_x: BoxMesh = BoxMesh.new()
	side_x.size = Vector3(size.x, maxf(0.01, size.y - 2.0 * r), maxf(0.01, size.z - 2.0 * r))
	st.append_from(side_x, 0, Transform3D.IDENTITY)
	var side_z: BoxMesh = BoxMesh.new()
	side_z.size = Vector3(maxf(0.01, size.x - 2.0 * r), maxf(0.01, size.y - 2.0 * r), size.z)
	st.append_from(side_z, 0, Transform3D.IDENTITY)
	return st.commit()


## One shared bolt mesh for MultiMesh decoration.
static func bolt_mesh() -> Mesh:
	if _bolt_mesh == null:
		var c: CylinderMesh = CylinderMesh.new()
		c.top_radius = 0.05
		c.bottom_radius = 0.06
		c.height = 0.05
		c.radial_segments = 6
		c.rings = 1
		_bolt_mesh = c
	return _bolt_mesh


## Scatter bolts (or any small repeated mesh) with ONE draw call via MultiMesh.
static func multimesh(parent: Node, mesh: Mesh, transforms: Array, mat: Material) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i: int in transforms.size():
		mm.set_instance_transform(i, transforms[i] as Transform3D)
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi
