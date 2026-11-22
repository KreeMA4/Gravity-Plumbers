extends Node3D
## Animated 3D background for the main menu: the starfield sky and planet
## seen through a big round space window, with a gently drifting camera.
## (M8 adds your customised plumber idling in front of the window.)

var _cam: Camera3D
var _t: float = 0.0
var _plumber_spot: Node3D


func _ready() -> void:
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
	_plumber_spot.position = Vector3(1.4, 0.0, -1.2)
	add_child(_plumber_spot)
	_cam = Camera3D.new()
	_cam.position = Vector3(-0.4, 1.4, 2.8)
	_cam.fov = 62.0
	add_child(_cam)
	_cam.current = true


func _process(delta: float) -> void:
	_t += delta
	_cam.rotation = Vector3(-0.08 + sin(_t * 0.2) * 0.03, -0.35 + sin(_t * 0.13) * 0.06, 0.0)
