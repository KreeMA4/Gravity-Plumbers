extends Node3D
## M2 look test: two clean station modules joined by a doorway, big windows
## onto the starfield and planet, colour-coded pipes, a valve wheel, goo
## blobs, outlined props and MultiMesh bolts. Use it to judge the art style
## and the draw-call cost on your phone (open the debug overlay).

var _cam: OrbitCamera
var _ui: DebugRoomUI


func _ready() -> void:
	GravityManager.reset_all()
	var palette: Dictionary = LevelBuilder.DEFAULT_PALETTE
	LevelBuilder.build_environment(self, palette)
	LevelBuilder.build_room(self, {
		"id": "a", "center": Vector3(0, 2, 0), "size": Vector3(10, 4, 10),
		"openings": [
			{"wall": "-z", "at": Vector2(0, 0.3), "size": Vector2(6, 2.4), "window": true},
			{"wall": "+x", "at": Vector2(0, -0.6), "size": Vector2(2.2, 2.8)},
		],
	}, palette)
	LevelBuilder.build_room(self, {
		"id": "b", "center": Vector3(11, 2, 0), "size": Vector3(11.2, 4, 8),
		"skip": ["-x"],
		"openings": [
			{"wall": "+y", "at": Vector2(0, 0), "size": Vector2(4, 3), "window": true},
			{"wall": "+z", "at": Vector2(2, 0.2), "size": Vector2(3, 2), "window": true},
		],
	}, palette)
	# Pipes along the walls (orange = sludge, teal = water, purple = waste).
	LevelBuilder.build_pipe(self, {"points": [Vector3(-4.6, 0.4, -4.6), Vector3(-4.6, 3.4, -4.6), Vector3(4.6, 3.4, -4.6)], "radius": 0.16, "color": "orange", "glow": true})
	LevelBuilder.build_pipe(self, {"points": [Vector3(-4.7, 0.3, 4.0), Vector3(-4.7, 0.3, -3.0), Vector3(-4.7, 2.5, -3.0)], "radius": 0.12, "color": "teal"})
	LevelBuilder.build_pipe(self, {"points": [Vector3(8, 0.35, 3.6), Vector3(14, 0.35, 3.6), Vector3(14, 3.5, 3.6), Vector3(16.2, 3.5, 3.6)], "radius": 0.2, "color": "purple"})
	LevelBuilder.bolts_along(self, Vector3(-4.9, 3.8, -4.79), Vector3(4.9, 3.8, -4.79), Vector3(0, 0, 1), 24)
	# A valve wheel on the wall.
	var wheel: MeshInstance3D = MeshInstance3D.new()
	wheel.mesh = PipeBuilder.valve_wheel(0.45)
	wheel.material_override = Mats.toon_glow(Color(1.0, 0.3, 0.3), 0.2, true)
	wheel.position = Vector3(4.6, 1.5, -2.0)
	wheel.rotation = Vector3(0, PI * 0.5, 0)
	add_child(wheel)
	# Goo blobs and a few outlined crates.
	for i: int in 6:
		var blob: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.25
		sm.height = 0.5
		sm.radial_segments = 12
		sm.rings = 6
		blob.mesh = sm
		blob.material_override = Mats.goo()
		blob.position = Vector3(1.0 + i * 0.6, 0.25, 2.0 + sin(i) * 0.5)
		add_child(blob)
	var colors: Array = [UITheme.C_PIPE, UITheme.C_TEAL, UITheme.C_ACCENT]
	for i: int in 3:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = PipeBuilder.rounded_box(Vector3(0.8, 0.8, 0.8), 0.1)
		mi.material_override = Mats.toon(colors[i] as Color, true)
		mi.position = Vector3(-2.0 + i * 1.2, 0.4, 1.0)
		mi.rotation = Vector3(0, i * 0.5, 0)
		add_child(mi)
	LevelBuilder.build_rock(self, Vector3(12, 1.5, -1.0), 1.2, Color(0.55, 0.42, 0.7))
	_cam = OrbitCamera.new()
	_cam.target = Vector3(3, 1.5, 0)
	_cam.distance = 9.0
	add_child(_cam)
	_ui = DebugRoomUI.new()
	add_child(_ui)
	_ui.info.text = "Look test room\nDrag to orbit, pinch to zoom"
	AudioManager.play_music("game")
