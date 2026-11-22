class_name PlumberCamera
extends Node3D
## Third-person orbit camera for the local plumber.
## - Orbits on a "frame" whose up slowly follows the plumber's local up
##   (~0.5 s), so during a gravity shift the world visibly rotates.
## - Comfort mode locks up to the nearest world axis and rotates faster.
## - Collision: pulls in if a wall is between the plumber and the camera.
## - Auto-recenters behind movement; follows the chest softly while ragdolled.
## Physics interpolation is OFF for the camera; it reads the plumber's
## interpolated transform every frame instead (smooth on 90/120 Hz screens).

var plumber: Plumber = null
var yaw: float = 0.0
var pitch: float = 0.35
var distance: float = 5.0
var cam: Camera3D
var frame: GravityFrame = GravityFrame.new()
var look_delta: Vector2 = Vector2.ZERO     ## pixels of look drag this frame (from LocalInput)

var _focus: Vector3 = Vector3.ZERO
var _hit_dist: float = 5.0
var _shake: float = 0.0
var _shake_t: float = 0.0
var _no_look_time: float = 0.0
var _initialised: bool = false


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.08
	cam.far = 400.0
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(cam)
	cam.current = true
	distance = Tuning.CAMERA_DISTANCE
	_hit_dist = distance


func set_plumber(p: Plumber) -> void:
	plumber = p
	_initialised = false


## Camera forward (used as the aim direction for walking and grabbing).
func get_aim() -> Vector3:
	return -global_basis.z


func add_shake(amount: float) -> void:
	if SaveData.setting_b("reduce_shake"):
		amount *= 0.2
	_shake = minf(1.0, _shake + amount)


func _orbit_basis() -> Basis:
	return frame.basis * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)


func _physics_process(_dt: float) -> void:
	# Camera collision ray (physics queries belong in the physics step).
	if plumber == null or not is_instance_valid(plumber) or not is_inside_tree():
		return
	var from: Vector3 = _focus
	var to: Vector3 = from + _orbit_basis() * Vector3(0, 0, distance)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD, plumber._exclude)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		_hit_dist = distance
	else:
		_hit_dist = maxf(0.6, from.distance_to(hit["position"] as Vector3) - 0.25)


func _process(delta: float) -> void:
	if plumber == null or not is_instance_valid(plumber):
		return
	var comfort: bool = SaveData.setting_b("comfort_camera")
	var want_up: Vector3 = plumber.local_up
	if comfort:
		want_up = GravityMath.AXES[GravityMath.nearest_axis_index(want_up)] as Vector3
	var follow_time: float = Tuning.CAMERA_UP_FOLLOW_COMFORT if comfort else Tuning.CAMERA_UP_FOLLOW_TIME
	if not _initialised:
		frame.snap(want_up)
		var f_local: Vector3 = frame.basis.inverse() * plumber.facing
		# Camera forward is frame * (-sin yaw, 0, -cos yaw); start behind the plumber.
		yaw = atan2(-f_local.x, -f_local.z)
		_focus = plumber.get_center_interpolated()
		_initialised = true
	frame.follow(want_up, GravityFrame.smooth_factor(delta, follow_time))
	# Look input.
	var sens: float = Tuning.LOOK_SENSITIVITY * SaveData.setting_f("look_sensitivity")
	if look_delta.length_squared() > 0.0:
		yaw -= look_delta.x * sens
		pitch = clampf(pitch + look_delta.y * sens, Tuning.CAMERA_PITCH_MIN, Tuning.CAMERA_PITCH_MAX)
		_no_look_time = 0.0
	else:
		_no_look_time += delta
	look_delta = Vector2.ZERO
	# Auto-recenter behind movement after a moment without manual look.
	var mv: Vector3 = plumber.move_dir
	if Tuning.CAMERA_RECENTER_SPEED > 0.0 and _no_look_time > 1.0 and mv.length() > 0.3 and plumber.state == Plumber.State.ACTIVE:
		var ml: Vector3 = frame.basis.inverse() * mv
		var want_yaw: float = atan2(-ml.x, -ml.z)
		var diff: float = wrapf(want_yaw - yaw, -PI, PI)
		if absf(diff) < 2.6:   # don't spin round when walking toward the camera
			yaw += clampf(diff, -1.0, 1.0) * Tuning.CAMERA_RECENTER_SPEED * delta * mv.length()
	# Follow the plumber (softer while limp so the camera never whips).
	var target: Vector3 = plumber.get_center_interpolated() + plumber.local_up * Tuning.CAMERA_HEIGHT * 0.5
	var smooth: float = Tuning.CAMERA_RAGDOLL_SMOOTH if plumber.state == Plumber.State.RAGDOLL else Tuning.CAMERA_FOLLOW_SMOOTH
	_focus = _focus.lerp(target, 1.0 - exp(-delta * smooth))
	var orbit: Basis = _orbit_basis()
	var pos: Vector3 = _focus + orbit * Vector3(0, 0, _hit_dist)
	# Shake.
	if _shake > 0.0:
		_shake_t += delta * 40.0
		var s: float = _shake * _shake * 0.25
		pos += orbit * Vector3(sin(_shake_t * 1.3) * s, cos(_shake_t * 1.7) * s, 0)
		_shake = maxf(0.0, _shake - delta * Tuning.SHAKE_DECAY)
	global_transform = Transform3D(orbit, pos)
	GravityManager.debug_probe = plumber.get_center()
