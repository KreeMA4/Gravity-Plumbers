class_name Valve
extends LevelObject
## A valve wheel. Hold Use with the Pipe Wrench to turn it until it's done.
## two_player valves have two handles and only turn while TWO different
## plumbers are turning (within Tuning.VALVE_TWO_PLAYER_WINDOW of each other).
## Playing solo? Then a two-player valve turns at half speed for one player.

var normal: Vector3 = Vector3.FORWARD
var two_player: bool = false
var progress: float = 0.0
var solo_mode: bool = false        ## set by LevelRunner when only one player is in the game

var _wheel: Node3D
var _turners: Dictionary = {}      ## Plumber -> last turn time (msec)
var _creak_t: float = 0.0


func _init() -> void:
	super._init()
	add_to_group("valves")


func _ready() -> void:
	var stub: MeshInstance3D = MeshInstance3D.new()
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = 0.1
	c.bottom_radius = 0.1
	c.height = 0.4
	stub.mesh = c
	stub.material_override = Mats.toon(LevelBuilder.PIPE_COLORS["grey"] as Color)
	stub.basis = PipeBuilder.basis_along(normal)
	stub.position = -normal * 0.15
	add_child(stub)
	_wheel = Node3D.new()
	_wheel.basis = PipeBuilder.basis_along(normal)
	_wheel.position = normal * 0.08
	add_child(_wheel)
	var wm: MeshInstance3D = MeshInstance3D.new()
	wm.mesh = PipeBuilder.valve_wheel(0.5 if two_player else 0.35)
	wm.material_override = Mats.toon_glow(Color(0.95, 0.25, 0.25), 0.2, Quality.outlines_on_props)
	wm.rotation = Vector3(PI * 0.5, 0, 0)
	_wheel.add_child(wm)
	if two_player:
		var lbl: Label3D = Label3D.new()
		lbl.text = "2 PLUMBERS"
		lbl.font_size = 48
		lbl.outline_size = 10
		lbl.pixel_size = 0.004
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = normal * 0.2 + Vector3(0, 0.8, 0)
		add_child(lbl)


func get_use_label() -> String:
	return "TURN"


func interact_distance(from: Vector3) -> float:
	if not active or done:
		return 999.0
	var r: float = 0.5 if two_player else 0.35
	return maxf(0.0, global_position.distance_to(from) - r)


func wrench_turn(dt: float, p: Plumber) -> void:
	if not is_host() or not active or done:
		return
	var now: int = Time.get_ticks_msec()
	_turners[p] = now
	var speed: float = 1.0
	if two_player:
		var count: int = 0
		for k: Variant in _turners.keys():
			if float(now - int(_turners[k])) <= Tuning.VALVE_TWO_PLAYER_WINDOW * 1000.0:
				count += 1
		if count < 2:
			if not solo_mode:
				return
			speed = 0.5
	progress = minf(1.0, progress + dt * speed / Tuning.VALVE_TURN_TIME)
	_creak_t -= dt
	if _creak_t <= 0.0:
		_creak_t = 0.5
		AudioManager.play_at("valve_creak", global_position, -4.0)
	if progress >= 1.0:
		mark_done()


func _on_done() -> void:
	AudioManager.play_at("pipe_snap", global_position)
	FX.stars(get_parent(), global_position + normal * 0.3)


func _process(_delta: float) -> void:
	if _wheel != null:
		_wheel.basis = PipeBuilder.basis_along(normal) * Basis(Vector3.UP, progress * TAU * 2.0)


func get_net_state() -> Array:
	return [active, done, progress]


func apply_net_state(s: Array) -> void:
	super.apply_net_state(s)
	if s.size() > 2:
		progress = clampf(float(s[2]), 0.0, 1.0)
