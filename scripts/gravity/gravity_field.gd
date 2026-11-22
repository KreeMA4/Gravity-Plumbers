class_name GravityField
extends Node3D
## A gravity zone placed in a level. Wraps a GravityFieldData and registers it
## with GravityManager while it is in the scene tree. Its region is centred on
## this node's global position (and rotated with it for boxes).
## Optionally draws a faint see-through visual so players can read the zone.

var data: GravityFieldData = GravityFieldData.new()
var moving: bool = false          ## Set true if this node moves (re-reads its transform each tick).
var show_visual: bool = true

var _visual: MeshInstance3D = null


static func create(field_data: GravityFieldData, visual: bool = true) -> GravityField:
	var gf: GravityField = GravityField.new()
	gf.data = field_data
	gf.show_visual = visual
	gf.name = "Field_" + (field_data.id if field_data.id != "" else "anon")
	gf.position = field_data.center
	gf.basis = field_data.basis
	return gf


func _ready() -> void:
	_refresh()
	GravityManager.register_field(data, self)
	if show_visual:
		_build_visual()
	GravityManager.field_changed.connect(_on_field_changed)


func _exit_tree() -> void:
	GravityManager.unregister_field(data)


func _refresh() -> void:
	data.center = global_position
	data.basis = global_basis.orthonormalized()


func refresh_if_moving() -> void:
	if moving and is_inside_tree():
		_refresh()


func _on_field_changed(field_id: String) -> void:
	if field_id == data.id and _visual != null:
		_visual.visible = data.enabled


func _build_visual() -> void:
	var col: Color
	match data.kind:
		GravityFieldData.Kind.ZERO_G:
			col = Color(0.5, 0.8, 1.0, 0.07)
		GravityFieldData.Kind.SPHERE:
			col = Color(0.9, 0.7, 1.0, 0.05)
		GravityFieldData.Kind.PUSH:
			col = Color(1.0, 0.5, 0.3, 0.08)
		_:
			col = Color(1.0, 0.9, 0.3, 0.05)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	_visual = MeshInstance3D.new()
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if data.kind == GravityFieldData.Kind.SPHERE or data.spherical_region:
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = data.radius
		sm.height = data.radius * 2.0
		sm.radial_segments = 24
		sm.rings = 12
		_visual.mesh = sm
	else:
		var bm: BoxMesh = BoxMesh.new()
		bm.size = data.half_extents * 2.0
		_visual.mesh = bm
	_visual.material_override = mat
	_visual.visible = data.enabled
	add_child(_visual)
