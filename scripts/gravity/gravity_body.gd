class_name GravityBody
extends Node
## Gives a RigidBody3D its gravity from GravityManager instead of Godot's.
## Add it as a CHILD of any RigidBody3D:  body.add_child(GravityBody.new())
##
## Every physics tick it applies  mass * gravity_at(position)  as a central
## force, adds zero-G air drag, clamps crazy speeds, and handles the G-Wrench
## override (a temporary personal gravity direction with a timer).

signal out_of_bounds(body: RigidBody3D)    ## Fired when the body drifts out of the level.
signal override_changed(active: bool)

var body: RigidBody3D = null
var multiplier: float = 1.0          ## 0 = ignore gravity (e.g. carried by magnet boots logic).
var cancel_field: bool = false       ## Plumber magnetic boots: ignore field gravity entirely.
var override_dir: Vector3 = Vector3.ZERO
var override_time: float = 0.0
var override_strength: float = 9.8
var home: Transform3D = Transform3D.IDENTITY  ## Where to reset if lost in space.
var last_gravity: Vector3 = Vector3.ZERO      ## Gravity applied last tick (for effects / camera).


func _ready() -> void:
	body = get_parent() as RigidBody3D
	if body == null:
		GameLog.error("GravityBody must be a child of a RigidBody3D (%s)" % get_path())
		set_physics_process(false)
		return
	body.gravity_scale = 0.0
	home = body.global_transform
	add_to_group("gravity_bodies")


## Temporarily point this body's gravity along `dir` (G-Wrench). Host replicates it.
func set_override(dir: Vector3, duration: float, strength: float = 9.8) -> void:
	if not dir.is_finite() or dir.length_squared() < 0.5:
		return
	override_dir = dir.normalized()
	override_strength = strength
	override_time = duration
	override_changed.emit(true)
	if body != null:
		body.sleeping = false


func clear_override() -> void:
	override_time = 0.0
	override_changed.emit(false)


func has_override() -> bool:
	return override_time > 0.0


## The gravity this body currently feels.
func current_gravity() -> Vector3:
	if override_time > 0.0:
		return override_dir * override_strength
	if cancel_field:
		return Vector3.ZERO
	return GravityManager.get_gravity_at(body.global_position) * multiplier


func _physics_process(delta: float) -> void:
	if body == null or body.freeze:
		return
	if override_time > 0.0:
		override_time -= delta
		if override_time <= 0.0:
			clear_override()
	var g: Vector3 = current_gravity()
	last_gravity = g
	if body.sleeping and g.length_squared() > 0.01:
		# Sleeping bodies don't feel forces; wake them if gravity changed under them.
		if GravityManager.phase != GravityManager.Phase.IDLE or override_time > 0.0:
			body.sleeping = false
	body.apply_central_force(g * body.mass)
	var drag: float = GravityManager.get_drag_at(body.global_position)
	if drag > 0.0:
		body.apply_central_force(-body.linear_velocity * drag * body.mass)
	# Safety: never let anything go faster than the clamp (no physics explosions).
	var v: Vector3 = body.linear_velocity
	if not v.is_finite():
		reset_to_home()
		return
	if v.length_squared() > Tuning.MAX_BODY_SPEED * Tuning.MAX_BODY_SPEED:
		body.linear_velocity = v.limit_length(Tuning.MAX_BODY_SPEED)
	if body.angular_velocity.length_squared() > 900.0:
		body.angular_velocity = body.angular_velocity.limit_length(30.0)
	# Out of bounds?
	if body.global_position.distance_squared_to(LevelBounds.center) > LevelBounds.radius_sq():
		if out_of_bounds.get_connections().size() > 0:
			out_of_bounds.emit(body)
		else:
			reset_to_home()


## Put the body back where it started (used for lost props).
func reset_to_home() -> void:
	if body == null:
		return
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.global_transform = home
	body.reset_physics_interpolation()
	clear_override()
