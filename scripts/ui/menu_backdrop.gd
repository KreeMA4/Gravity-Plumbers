extends Node3D
## Animated 3D background for the main menu: the starfield sky and planet
## seen through a big round space window, with a gently drifting camera.
## Your customised plumber idles in front of the window.

var _cam: Camera3D
var _t: float = 0.0
var _plumber_spot: Node3D
var _preview: Node3D


func _ready() -> void:
	# Nothing here is physics; it's animated in _process, so opt out of interpolation.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	GravityManager.reset_all()
	var palette: Dictionary = LevelBuilder.DEFAULT_PALETTE
	LevelBuilder.build_environment(self, palette)
	LevelBuilder.build_room(self, {
		"id": "menu", "center": Vector3(0, 2, 0), "size": Vector3(9, 4.4, 7),
		"openings": [{"wall": "-z", "at": Vector2(1.6, 0.4), "size": Vector2(4.6, 3.0), "window": true}],
	}, palette)
	LevelBuilder.build_pipe(self, {"points": [Vector3(-4.3, 0.3, -3.3), Vector3(-4.3, 3.9, -3.3), Vector3(4.3, 3.9, -3.3)], "radius": 0.16, "color": "orange", "glow": true})
	LevelBuilder.build_pipe(self, {"points": [Vector3(4.3, 0.3, 3.0), Vector3(4.3, 0.3, -3.2)], "radius": 0.12, "color": "teal"})
	_plumber_spot = Node3D.new()
	_plumber_spot.name = "PlumberSpot"
	_plumber_spot.position = Vector3(1.4, -0.2, -1.2)
	add_child(_plumber_spot)
	var b: PackedByteArray = SaveData.get_look_bytes()
	var look: PlumberLook = PlumberLook.from_bytes(b) if b.size() >= 2 else PlumberLook.default_for(0)
	_preview = PlumberMeshBuilder.build_preview(look)
	_preview.rotation = Vector3(0, -0.5, 0)
	_plumber_spot.add_child(_preview)
	_cam = Camera3D.new()
	_cam.position = Vector3(-0.4, 1.4, 2.8)
	_cam.fov = 62.0
	add_child(_cam)
	_cam.current = true


func _process(delta: float) -> void:
	_t += delta
	_cam.rotation = Vector3(-0.08 + sin(_t * 0.2) * 0.03, -0.35 + sin(_t * 0.13) * 0.06, 0.0)
	# Idle animation: a little bob, sway and the odd look around.
	if _preview != null:
		_preview.position = Vector3(0, absf(sin(_t * 2.2)) * 0.04, 0)
		_preview.rotation = Vector3(sin(_t * 1.1) * 0.03, -0.5 + sin(_t * 0.4) * 0.35, sin(_t * 2.2) * 0.04)
		var head: Node3D = (_preview.get_meta("parts") as Dictionary).get("head") as Node3D
		if head != null:
			head.rotation = Vector3(0, sin(_t * 0.7) * 0.4, sin(_t * 1.3) * 0.08)
