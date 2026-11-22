class_name Vent
extends LevelObject
## Burp vent hazard: every `period` seconds it rumbles and glows (warning),
## then BURPS: a short gravity PUSH field blasts things away and goo sprays out.
## Always telegraphed (glow + sound) before it fires.

var dir: Vector3 = Vector3.UP
var period: float = 12.0
var warn_time: float = 1.5
var push_strength: float = 28.0
var half: Vector3 = Vector3(1.0, 1.5, 1.0)
var goo_pool: GooPool = null
var sludge_bump: float = 1.5
var runner_sludge: Callable = Callable()   ## (amount) -> void, set by LevelRunner

var _t: float = 6.0
var _field: GravityField
var _grate: MeshInstance3D
var _firing: float = 0.0


func _init() -> void:
	super._init()
	add_to_group("vents")


func _ready() -> void:
	_t = period * 0.6
	var b: Basis = PipeBuilder.basis_along(dir)
	_grate = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.8
	cm.height = 0.2
	cm.radial_segments = 12
	_grate.mesh = cm
	_grate.basis = b
	_grate.material_override = Mats.toon(Color(0.3, 0.3, 0.36))
	add_child(_grate)
	var fd: GravityFieldData = GravityFieldData.make_push(obj_id + "_push", global_position + dir * half.y, half, dir, push_strength)
	_field = GravityField.create(fd, false)
	_field.basis = b
	_field.position = dir * half.y   # set BEFORE add_child: the field reads its position in _ready
	add_child(_field)


func _physics_process(dt: float) -> void:
	if not active:
		return
	var prev: float = _t
	_t -= dt
	if _t <= warn_time and prev > warn_time:
		AudioManager.play_at("gravity_siren", global_position, -6.0, 1.6)
	if _t <= warn_time and _t > 0.0:
		var k: float = 0.5 + 0.5 * sin(_t * 30.0)
		_grate.material_override = Mats.toon_glow(UITheme.C_DANGER, k, false)
	if _t <= 0.0:
		_t = period
		_firing = 0.6
		_grate.material_override = Mats.toon(Color(0.3, 0.3, 0.36))
		if is_host():
			GravityManager.set_field_enabled(_field.data.id, true)
			if goo_pool != null:
				goo_pool.burst(global_position + dir * 0.3, dir, 5, 7.0)
			if runner_sludge.is_valid():
				runner_sludge.call(sludge_bump)
		AudioManager.play_at("sludge_splat", global_position, 4.0, 0.7)
		FX.splat(get_parent(), global_position, dir)
	if _firing > 0.0:
		_firing -= dt
		if _firing <= 0.0 and is_host():
			GravityManager.set_field_enabled(_field.data.id, false)
