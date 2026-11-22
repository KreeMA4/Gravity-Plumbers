class_name OrbitCamera
extends Node3D
## Simple orbit camera for debug rooms: drag to rotate, pinch or mouse wheel
## to zoom. Its "up" follows gravity at the target point, so you can see the
## room rotate during a gravity shift.

var target: Vector3 = Vector3.ZERO
var distance: float = 12.0
var yaw: float = 0.6
var pitch: float = 0.45
var follow_gravity: bool = true

var cam: Camera3D
var _frame: GravityFrame = GravityFrame.new()
var _drag_index: int = -1
var _touches: Dictionary = {}
var _pinch_start: float = 0.0
var _pinch_dist0: float = 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 65.0
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(cam)
	cam.current = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_touches[t.index] = t.position
			if _touches.size() == 1:
				_drag_index = t.index
			elif _touches.size() == 2:
				var pts: Array = _touches.values()
				_pinch_dist0 = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
				_pinch_start = distance
		else:
			_touches.erase(t.index)
			if t.index == _drag_index:
				_drag_index = -1
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		_touches[d.index] = d.position
		if _touches.size() >= 2 and _pinch_dist0 > 1.0:
			var pts2: Array = _touches.values()
			var now: float = (pts2[0] as Vector2).distance_to(pts2[1] as Vector2)
			distance = clampf(_pinch_start * _pinch_dist0 / maxf(1.0, now), 3.0, 40.0)
		elif d.index == _drag_index:
			yaw -= d.relative.x * 0.006
			pitch = clampf(pitch + d.relative.y * 0.006, -1.3, 1.3)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(3.0, distance * 0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(40.0, distance * 1.1)


func _process(delta: float) -> void:
	if follow_gravity:
		_frame.follow(GravityManager.get_up_at(target), GravityFrame.smooth_factor(delta, Tuning.CAMERA_UP_FOLLOW_TIME))
	var orbit: Basis = _frame.basis * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)
	var pos: Vector3 = target + orbit * Vector3(0, 0, distance)
	global_transform = Transform3D(orbit, pos)
