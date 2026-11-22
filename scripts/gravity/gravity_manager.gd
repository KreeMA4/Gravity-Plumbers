extends Node
## GravityManager (autoload)
## -----------------------------------------------------------------------------
## THE single source of truth for gravity. Godot's built-in gravity is 0 in
## project.godot; every dynamic thing asks get_gravity_at(position) instead.
##
## - Global gravity: the station's "down". Shifts rotate it (with warning).
## - Fields: GravityField nodes register their GravityFieldData here.
## - Shifts are decided on the host and replicated to everyone with a reliable
##   RPC. Offline/solo play uses the very same path (the host has no clients).

signal shift_warning(new_dir: Vector3, warning_time: float)  ## Siren time!
signal shift_started(new_dir: Vector3)                       ## Gravity starts rotating.
signal shift_finished(new_dir: Vector3)
signal field_changed(field_id: String)

enum Phase { IDLE, WARNING, SHIFTING }

var global_dir: Vector3 = Vector3.DOWN      ## Current global "down" (unit vector).
var global_strength: float = 9.8
var phase: Phase = Phase.IDLE
var warning_left: float = 0.0               ## Seconds until the pending shift starts.
var pending_dir: Vector3 = Vector3.DOWN     ## Where gravity is about to point.
var debug_probe: Vector3 = Vector3.ZERO     ## Point the debug overlay reports (the local player).
var shift_count: int = 0

var _fields: Array = []                     ## Array of GravityFieldData
var _field_nodes: Dictionary = {}           ## id -> GravityField node (for refreshing)
var _from_dir: Vector3 = Vector3.DOWN
var _shift_t: float = 1.0
var _shift_duration: float = 0.6
var _debug_axis: int = 0
# Scheduled storms (driven on the host only).
var _storm_interval: float = 0.0
var _storm_timer: float = 0.0
var _storm_sequence: Array = []             ## Optional list of axis indices to cycle through
var _storm_index: int = 0


func _ready() -> void:
	global_strength = Tuning.GRAVITY_STRENGTH


## Gravity acceleration (m/s^2, a vector) at a world position.
func get_gravity_at(pos: Vector3) -> Vector3:
	return GravityMath.resolve(_fields, global_dir * global_strength, pos)


## The "up" direction at a position (opposite of gravity). Falls back to the
## global up inside zero-G so cameras and players still have a sensible frame.
func get_up_at(pos: Vector3) -> Vector3:
	var g: Vector3 = get_gravity_at(pos)
	if g.length_squared() < 0.01:
		return -global_dir
	return -g.normalized()


func get_drag_at(pos: Vector3) -> float:
	return GravityMath.resolve_drag(_fields, pos)


func is_zero_g_at(pos: Vector3) -> bool:
	return get_gravity_at(pos).length_squared() < 0.25


# --- Field registry ----------------------------------------------------------

func register_field(data: GravityFieldData, node: Node = null) -> void:
	if not _fields.has(data):
		_fields.append(data)
	if node != null and data.id != "":
		_field_nodes[data.id] = node


func unregister_field(data: GravityFieldData) -> void:
	_fields.erase(data)
	if _field_nodes.has(data.id):
		_field_nodes.erase(data.id)


func get_field(field_id: String) -> GravityFieldData:
	for item: Variant in _fields:
		var f: GravityFieldData = item as GravityFieldData
		if f != null and f.id == field_id:
			return f
	return null


## Remove every field and reset to normal gravity (called when a level unloads).
func reset_all() -> void:
	_fields.clear()
	_field_nodes.clear()
	global_dir = Vector3.DOWN
	pending_dir = Vector3.DOWN
	_from_dir = Vector3.DOWN
	_shift_t = 1.0
	phase = Phase.IDLE
	warning_left = 0.0
	shift_count = 0
	stop_storms()


# --- Shifts (host decides, everyone runs) -----------------------------------

## Ask for a global gravity shift. On clients this does nothing (host decides).
## warning: seconds of siren before the shift. Never less than the difficulty minimum
## unless `force_no_warning` is set (debug tools only).
func request_shift(new_dir: Vector3, warning: float = -1.0, force_no_warning: bool = false) -> void:
	if not multiplayer.is_server():
		return
	if phase != Phase.IDLE:
		return
	var w: float = warning
	if w < 0.0:
		w = Tuning.gravity_warning_time()
	if not force_no_warning:
		# Always telegraph: 2 s minimum normally, 1 s minimum on Chaos.
		var min_w: float = 1.0 if GameState.difficulty == 2 else 2.0
		w = maxf(w, min_w)
	_rpc_begin_shift.rpc(new_dir.normalized(), w, Tuning.GRAVITY_SHIFT_DURATION)


@rpc("authority", "call_local", "reliable")
func _rpc_begin_shift(new_dir: Vector3, warning: float, duration: float) -> void:
	if not new_dir.is_finite() or new_dir.length_squared() < 0.5:
		return
	pending_dir = new_dir.normalized()
	_shift_duration = clampf(duration, 0.1, 3.0)
	warning_left = clampf(warning, 0.0, 10.0)
	if warning_left <= 0.0:
		_start_shift()
	else:
		phase = Phase.WARNING
		shift_warning.emit(pending_dir, warning_left)


func _start_shift() -> void:
	phase = Phase.SHIFTING
	_from_dir = global_dir
	_shift_t = 0.0
	shift_count += 1
	shift_started.emit(pending_dir)


## Instantly set global gravity (used when loading a level / late join).
func set_global_immediate(new_dir: Vector3) -> void:
	global_dir = new_dir.normalized()
	pending_dir = global_dir
	_from_dir = global_dir
	_shift_t = 1.0
	phase = Phase.IDLE


## Debug: cycle global gravity through the 6 axis directions.
func cycle_debug() -> void:
	_debug_axis = (_debug_axis + 1) % GravityMath.AXES.size()
	request_shift(GravityMath.AXES[_debug_axis] as Vector3, 1.0, true)


# --- Switchable zones (host) -------------------------------------------------

func set_field_enabled(field_id: String, on: bool) -> void:
	if not multiplayer.is_server():
		return
	var f: GravityFieldData = get_field(field_id)
	if f == null:
		return
	_rpc_set_field.rpc(field_id, on, f.direction)


func set_field_direction(field_id: String, new_dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var f: GravityFieldData = get_field(field_id)
	if f == null:
		return
	_rpc_set_field.rpc(field_id, f.enabled, new_dir.normalized())


@rpc("authority", "call_local", "reliable")
func _rpc_set_field(field_id: String, on: bool, new_dir: Vector3) -> void:
	var f: GravityFieldData = get_field(field_id)
	if f == null:
		return
	f.enabled = on
	if new_dir.is_finite() and new_dir.length_squared() > 0.5:
		f.direction = new_dir.normalized()
	field_changed.emit(field_id)


# --- Storms ------------------------------------------------------------------

## Start a scheduled gravity storm: every `interval` seconds gravity shifts.
## `sequence` (optional) is a list of axis indices to cycle through; otherwise random.
func start_storms(interval: float, sequence: Array = []) -> void:
	_storm_interval = maxf(5.0, interval)
	_storm_timer = _storm_interval
	_storm_sequence = sequence
	_storm_index = 0


func stop_storms() -> void:
	_storm_interval = 0.0


func storm_time_left() -> float:
	if _storm_interval <= 0.0:
		return -1.0
	return _storm_timer


## The axis index the next storm will use (host only).
func _next_storm_axis() -> int:
	if _storm_sequence.size() > 0:
		var idx: int = int(_storm_sequence[_storm_index % _storm_sequence.size()])
		_storm_index += 1
		return clampi(idx, 0, 5)
	var current: int = GravityMath.nearest_axis_index(global_dir)
	var pick: int = randi() % 6
	if pick == current:
		pick = (pick + 1 + randi() % 5) % 6
	return pick


# --- Sync for late joiners ---------------------------------------------------

func get_state() -> Dictionary:
	var fields: Dictionary = {}
	for item: Variant in _fields:
		var f: GravityFieldData = item as GravityFieldData
		if f != null and f.id != "":
			fields[f.id] = [f.enabled, f.direction]
	return {"dir": pending_dir if phase != Phase.IDLE else global_dir, "fields": fields}


func apply_state(state: Dictionary) -> void:
	var d: Variant = state.get("dir", Vector3.DOWN)
	if d is Vector3 and (d as Vector3).is_finite() and (d as Vector3).length_squared() > 0.5:
		set_global_immediate(d as Vector3)
	var fields: Variant = state.get("fields", {})
	if fields is Dictionary:
		for fid: Variant in (fields as Dictionary).keys():
			var f: GravityFieldData = get_field(str(fid))
			var v: Variant = (fields as Dictionary)[fid]
			if f != null and v is Array and (v as Array).size() == 2:
				f.enabled = bool((v as Array)[0])
				var fd: Variant = (v as Array)[1]
				if fd is Vector3:
					f.direction = fd as Vector3


# --- Tick --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	match phase:
		Phase.WARNING:
			warning_left -= delta
			if warning_left <= 0.0:
				_start_shift()
		Phase.SHIFTING:
			_shift_t += delta / _shift_duration
			global_dir = GravityMath.rotate_dir(_from_dir, pending_dir, GravityMath.ease_shift(_shift_t))
			if _shift_t >= 1.0:
				global_dir = pending_dir
				phase = Phase.IDLE
				shift_finished.emit(global_dir)
	if _storm_interval > 0.0 and multiplayer.is_server() and not get_tree().paused:
		_storm_timer -= delta
		var warn: float = Tuning.gravity_warning_time()
		if _storm_timer <= warn and phase == Phase.IDLE:
			_storm_timer = _storm_interval + warn
			request_shift(GravityMath.AXES[_next_storm_axis()] as Vector3, warn)
	# Keep field data in sync with nodes that move (rare).
	for fid: Variant in _field_nodes.keys():
		var n: Node = _field_nodes[fid] as Node
		if n != null and is_instance_valid(n) and n.has_method("refresh_if_moving"):
			n.call("refresh_if_moving")
