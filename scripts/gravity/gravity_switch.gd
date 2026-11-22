class_name GravitySwitch
extends LevelObject
## A big yellow lever panel. Use it (or grab its handle and yank) to shift
## gravity. Always telegraphed by GravityManager's warning phase.
##
## action:
##   "global"     - rotate global gravity to the next direction in `dirs`
##   "field"      - toggle the gravity field `field_id` on/off
##   "field_dir"  - switch field `field_id` ON and point it at the next direction in `dirs`
## two_player: needs two different plumbers to pull within 1.5 s (solo: one is enough).
## required_dir (optional, axis index): this switch counts as "done" for a
## relay work order when gravity ends up pointing that way after it's used.

var normal: Vector3 = Vector3.FORWARD
var action: String = "global"
var dirs: Array = [1, 0]          ## axis indices (GravityMath.AXES)
var field_id: String = ""
var two_player: bool = false
var required_dir: int = -1
var solo_mode: bool = false
var cooldown: float = 0.0

var _dir_index: int = 0
var _lever: Node3D
var _pulls: Dictionary = {}       ## Plumber -> msec
var _lever_angle: float = 0.6
var _label: Label3D
var _pending_relay: bool = false


func _init() -> void:
	super._init()
	add_to_group("interactables")
	add_to_group("switches")


func _ready() -> void:
	var b: Basis = PipeBuilder.basis_along(normal)
	var panel: MeshInstance3D = MeshInstance3D.new()
	var pm: BoxMesh = BoxMesh.new()
	pm.size = Vector3(0.9, 0.15, 1.1)
	panel.mesh = pm
	panel.material_override = Mats.toon(Color(0.25, 0.25, 0.32), Quality.outlines_on_props)
	panel.basis = b
	add_child(panel)
	var stripe: MeshInstance3D = MeshInstance3D.new()
	var sm: BoxMesh = BoxMesh.new()
	sm.size = Vector3(0.8, 0.02, 0.15)
	stripe.mesh = sm
	stripe.material_override = Mats.toon_glow(UITheme.C_ACCENT, 0.4, false)
	stripe.basis = b
	stripe.position = normal * 0.09 + b.z * 0.4
	add_child(stripe)
	_lever = Node3D.new()
	_lever.basis = b
	_lever.position = normal * 0.08
	add_child(_lever)
	var stick: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.05
	cm.height = 0.6
	stick.mesh = cm
	stick.material_override = Mats.toon(Color(0.7, 0.72, 0.8))
	stick.position = Vector3(0, 0.3, 0)
	_lever.add_child(stick)
	var knob: MeshInstance3D = MeshInstance3D.new()
	var km: SphereMesh = SphereMesh.new()
	km.radius = 0.11
	km.height = 0.22
	knob.mesh = km
	knob.material_override = Mats.toon_glow(UITheme.C_ACCENT, 0.5, Quality.outlines_on_props)
	knob.position = Vector3(0, 0.62, 0)
	_lever.add_child(knob)
	_label = Label3D.new()
	_label.font_size = 44
	_label.outline_size = 10
	_label.pixel_size = 0.004
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = normal * 0.5 + Vector3(0, 0.9, 0)
	_label.text = "GRAVITY" + ("\n2 PLUMBERS" if two_player else "")
	add_child(_label)
	GravityManager.shift_finished.connect(_on_shift_finished)


func get_use_label() -> String:
	return "PULL"


func interact(p: Plumber) -> void:
	if not is_host() or not active or cooldown > 0.0:
		return
	if GravityManager.phase != GravityManager.Phase.IDLE and action == "global":
		return
	var now: int = Time.get_ticks_msec()
	_pulls[p] = now
	AudioManager.play_at("valve_creak", global_position, -2.0, 1.5)
	if two_player and not solo_mode:
		var count: int = 0
		for k: Variant in _pulls.keys():
			if now - int(_pulls[k]) <= 1500:
				count += 1
		if count < 2:
			_label.text = "NEED ONE MORE!"
			return
	_trigger()


func _trigger() -> void:
	cooldown = 3.0
	_lever_angle = -_lever_angle
	_pulls.clear()
	var idx: int = int(dirs[_dir_index % maxi(1, dirs.size())]) if dirs.size() > 0 else 0
	_dir_index += 1
	match action:
		"global":
			GravityManager.request_shift(GravityMath.AXES[clampi(idx, 0, 5)] as Vector3)
			if required_dir >= 0:
				_pending_relay = true
		"field":
			var f: GravityFieldData = GravityManager.get_field(field_id)
			if f != null:
				GravityManager.set_field_enabled(field_id, not f.enabled)
			if required_dir < 0:
				mark_done()
		"field_dir":
			GravityManager.set_field_direction(field_id, GravityMath.AXES[clampi(idx, 0, 5)] as Vector3)
			GravityManager.set_field_enabled(field_id, true)
			if required_dir < 0:
				mark_done()
	if action == "global" and required_dir < 0:
		mark_done()


func _on_shift_finished(new_dir: Vector3) -> void:
	if not _pending_relay or not is_host():
		return
	_pending_relay = false
	if GravityMath.nearest_axis_index(new_dir) == required_dir:
		mark_done()


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if _lever != null:
		var b: Basis = PipeBuilder.basis_along(normal)
		_lever.basis = b * Basis(Vector3.RIGHT, _lever_angle)
	if _label != null and cooldown <= 0.0 and not _label.text.begins_with("GRAVITY"):
		_label.text = "GRAVITY" + ("\n2 PLUMBERS" if two_player else "")


func _exit_tree() -> void:
	if GravityManager.shift_finished.is_connected(_on_shift_finished):
		GravityManager.shift_finished.disconnect(_on_shift_finished)


## Switches are reusable; "done" only matters for relay orders.
func get_net_state() -> Array:
	return [active, done, _lever_angle]


func apply_net_state(s: Array) -> void:
	super.apply_net_state(s)
	if s.size() > 2:
		_lever_angle = float(s[2])
