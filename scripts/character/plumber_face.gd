class_name PlumberFace
extends RefCounted
## Cosmetic face animation (NOT synced over the network; every peer derives it
## from the plumber's state): spring-driven googly pupils that lag and wobble,
## mouth expressions, a swaying mustache, and squash & stretch on impacts.
## Updated from _physics_process so physics interpolation keeps it smooth.

var plumber: Plumber
var pupils: Array = []
var eye_rest: Array = []
var pupil_off: Array = []     ## current offset per pupil (Vector3, head space)
var pupil_vel: Array = []
var mouth: Node3D = null
var stache: Node3D = null
var stache_tips: Array = []
var squash_nodes: Array = []
var _stache_angle: Vector2 = Vector2.ZERO
var _stache_vel: Vector2 = Vector2.ZERO
var _squash: float = 0.0
var _squash_t: float = 0.0
var _prev_head_v: Vector3 = Vector3.ZERO
var _expression: int = 0


func _init(p: Plumber, cosmetics: Dictionary) -> void:
	plumber = p
	pupils = cosmetics.get("pupils", [])
	eye_rest = cosmetics.get("eye_rest", [])
	mouth = cosmetics.get("mouth") as Node3D
	stache = cosmetics.get("stache") as Node3D
	stache_tips = cosmetics.get("stache_tips", [])
	squash_nodes = cosmetics.get("squash", [])
	for i: int in pupils.size():
		pupil_off.append(Vector3.ZERO)
		pupil_vel.append(Vector3.ZERO)
	_expression = p.look.get_v("expression") if p.look != null else 0


func squash(amount: float) -> void:
	_squash = maxf(_squash, amount)
	_squash_t = 0.0


func update(dt: float) -> void:
	var head: RigidBody3D = plumber.head
	if head == null or not is_instance_valid(head):
		return
	var hv: Vector3 = head.linear_velocity
	var accel: Vector3 = (hv - _prev_head_v) / maxf(dt, 0.001)
	_prev_head_v = hv
	var inv: Basis = head.global_basis.inverse()
	# Pupils: a spring pulled toward rest, kicked opposite to head acceleration,
	# and gently pulled by gravity -> that lovely googly lag.
	var g_local: Vector3 = inv * GravityManager.get_gravity_at(head.global_position)
	var kick: Vector3 = inv * (-accel) * 0.0009 + g_local * 0.0004
	for i: int in pupils.size():
		var off: Vector3 = pupil_off[i]
		var vel: Vector3 = pupil_vel[i]
		vel += (kick - off * 160.0 - vel * 9.0) * dt
		off += vel * dt
		off.z = 0.0
		off = off.limit_length(0.03)
		pupil_off[i] = off
		pupil_vel[i] = vel
		var pn: Node3D = pupils[i] as Node3D
		if pn != null:
			pn.position = (eye_rest[i] as Vector3) + off
	# Mouth expression.
	if mouth != null:
		var target: Vector3 = Vector3(1.0, 1.0, 1.0)
		var speed: float = plumber.get_velocity().length()
		if plumber.celebrate_time > 0.0:
			target = Vector3(1.6, 1.3, 1.0)          # big grin
		elif plumber.state == Plumber.State.RAGDOLL and speed > 3.0:
			target = Vector3(0.9, 2.6, 1.0)          # scream!
		elif plumber.input.held(PlumberInput.GRAB_L) or plumber.input.held(PlumberInput.GRAB_R) or not plumber.grounded:
			target = Vector3(0.7, 0.5, 1.0)          # effort
		else:
			match _expression:
				1: target = Vector3(0.8, 0.6, 1.0)   # grumpy
				2: target = Vector3(1.3, 1.5, 1.0)   # goofy
				3: target = Vector3(0.6, 0.8, 1.0)   # shy
		mouth.scale = mouth.scale.lerp(target, 1.0 - exp(-dt * 14.0))
	# Mustache sway: damped spring driven by head spin and acceleration.
	if stache != null:
		var w_local: Vector3 = inv * head.angular_velocity
		var a_local: Vector3 = inv * accel
		var push: Vector2 = Vector2(-w_local.z * 0.02 + a_local.x * 0.002, w_local.x * 0.02 - a_local.y * 0.002)
		_stache_vel += (push * 60.0 - _stache_angle * 120.0 - _stache_vel * 8.0) * dt
		_stache_angle += _stache_vel * dt
		_stache_angle = _stache_angle.limit_length(0.6)
		stache.rotation = Vector3(_stache_angle.y, 0.0, _stache_angle.x)
		for t: Variant in stache_tips:
			var tip: Node3D = t as Node3D
			if tip != null:
				tip.rotation = Vector3(_stache_angle.y * 1.4, 0.0, _stache_angle.x * 1.6)
	# Squash & stretch.
	if _squash > 0.0:
		_squash_t += dt
		var k: float = _squash * exp(-_squash_t * 7.0) * cos(_squash_t * 28.0)
		for n: Variant in squash_nodes:
			var mn: Node3D = n as Node3D
			if mn != null:
				mn.scale = Vector3(1.0 + k * 0.6, 1.0 - k, 1.0 + k * 0.6)
		if _squash_t > 0.8:
			_squash = 0.0
			for n2: Variant in squash_nodes:
				var mn2: Node3D = n2 as Node3D
				if mn2 != null:
					mn2.scale = Vector3.ONE
