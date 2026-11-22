class_name Spinner
extends Node3D
## A purely decorative spinning ring (habitat rings, reactor cores).

var axis: Vector3 = Vector3.UP
var speed: float = 0.3


func _process(delta: float) -> void:
	rotate(axis.normalized(), speed * delta)


static func make(radius: float, thickness: float, col: Color, ax: Vector3, spd: float) -> Spinner:
	var s: Spinner = Spinner.new()
	s.axis = ax
	s.speed = spd
	var mi: MeshInstance3D = MeshInstance3D.new()
	var t: TorusMesh = TorusMesh.new()
	t.inner_radius = radius - thickness
	t.outer_radius = radius
	t.rings = 32
	t.ring_segments = 8
	mi.mesh = t
	mi.material_override = Mats.toon_glow(col, 0.3, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.basis = PipeBuilder.basis_along(ax)
	s.add_child(mi)
	for i: int in 6:
		var bolt: MeshInstance3D = MeshInstance3D.new()
		var b: BoxMesh = BoxMesh.new()
		b.size = Vector3(thickness * 1.6, thickness * 1.6, thickness * 1.6)
		bolt.mesh = b
		bolt.material_override = Mats.toon(col.darkened(0.3))
		var ang: float = TAU * float(i) / 6.0
		var perp: Vector3 = GravityMath.perpendicular(ax)
		var other: Vector3 = ax.normalized().cross(perp)
		bolt.position = (perp * cos(ang) + other * sin(ang)) * (radius - thickness * 0.5)
		s.add_child(bolt)
	return s
