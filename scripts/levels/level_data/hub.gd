extends RefCounted
## The Rusty Pipe: the crew's cosy (safe) ship. Pick jobs at the console,
## grab tools from the rack, practise with the gravity switch, and (from M8)
## change outfits at the mirror. Also the 3D space of the online lobby.


static func data() -> Dictionary:
	return {
		"name": "The Rusty Pipe",
		"time_limit": 0.0,
		"storm_interval": 0.0,
		"start_gravity": Vector3.DOWN,
		"bounds": {"center": Vector3(0, 3, 0), "radius": 40.0},
		"palette": {
			"floor": Color(0.45, 0.32, 0.28), "wall": Color(0.9, 0.82, 0.7), "ceiling": Color(0.6, 0.5, 0.45),
			"trim": Color(0.55, 0.3, 0.2), "lamp": Color(1.0, 0.9, 0.7), "ambient": Color(0.75, 0.68, 0.7),
			"nebula_a": Color(0.45, 0.15, 0.35), "nebula_b": Color(0.1, 0.25, 0.4), "planet": Color(0.4, 0.7, 1.0),
		},
		"rooms": [
			{"id": "hub", "center": Vector3(0, 3, 0), "size": Vector3(16, 6, 12),
				"openings": [
					{"wall": "+z", "at": Vector2(0, 0.6), "size": Vector2(9, 3.2), "window": true},
					{"wall": "+y", "at": Vector2(0, 0), "size": Vector2(4, 4), "window": true},
				]},
		],
		"pipes": [
			{"points": [Vector3(-7.6, 0.25, -5.6), Vector3(-7.6, 5.5, -5.6), Vector3(7.6, 5.5, -5.6), Vector3(7.6, 0.25, -5.6)], "radius": 0.18, "color": "orange", "glow": true},
			{"points": [Vector3(7.7, 1.3, 1.0), Vector3(7.7, 1.3, 3.5)], "radius": 0.07, "color": "grey"},
			{"points": [Vector3(-3, 5.7, -3), Vector3(3, 5.7, -3)], "radius": 0.08, "color": "grey"},
			{"points": [Vector3(-3, 5.7, 3), Vector3(3, 5.7, 3)], "radius": 0.08, "color": "grey"},
		],
		"boxes": [
			{"pos": Vector3(-4.5, 0.35, 2.5), "size": Vector3(2.4, 0.7, 1.0), "color": Color(0.85, 0.35, 0.3)},
			{"pos": Vector3(-4.5, 0.95, 2.95), "size": Vector3(2.4, 0.9, 0.2), "color": Color(0.85, 0.35, 0.3)},
		],
		"labels": [
			{"text": "THE RUSTY PIPE", "pos": Vector3(0, 4.6, -5.75), "size": 120, "color": Color(1.0, 0.82, 0.2)},
			{"text": "PRACTICE\nGRAVITY", "pos": Vector3(7.7, 2.6, 2.2), "yaw": -PI * 0.5, "size": 56},
		],
		"spawns": [
			{"pos": Vector3(-1.5, 0, 1.5), "yaw": PI},
			{"pos": Vector3(0, 0, 1.5), "yaw": PI},
			{"pos": Vector3(1.5, 0, 1.5), "yaw": PI},
			{"pos": Vector3(0, 0, 3.0), "yaw": PI},
		],
		"tool_racks": [
			{"pos": Vector3(-7.75, 0, -1.5), "yaw": -PI * 0.5, "tools": ["plunger", "wrench", "tape", "gwrench"]},
		],
		"props": [
			{"type": "crate", "pos": Vector3(4.5, 0.4, -2.5), "size": Vector3(0.8, 0.8, 0.8)},
			{"type": "crate", "pos": Vector3(5.2, 0.35, -1.6), "size": Vector3(0.7, 0.7, 0.7)},
			{"type": "crate", "pos": Vector3(4.8, 1.1, -2.2), "size": Vector3(0.5, 0.5, 0.5)},
		],
		"switches": [{"id": "hub_switch", "pos": Vector3(7.75, 1.4, 4.6), "normal": Vector3.LEFT, "dirs": [1, 0]}],
		"stations": [
			{"id": "console", "kind": "console", "pos": Vector3(0, 0, -4.5), "normal": Vector3.BACK},
			{"id": "mirror", "kind": "mirror", "pos": Vector3(-4.5, 0, -5.4), "normal": Vector3.BACK},
		],
		"ducks": [{"id": "hub_1", "pos": Vector3(0, 5.4, 0)}],
		"dispatcher": {
			"start": "Welcome aboard The Rusty Pipe! JOB CONSOLE picks a job, the MIRROR changes your look. Tools are on the rack.",
			"storm": ["Practice flip! Grab that rail!"],
		},
		"tutorial": [
			"Left thumb: walk. Drag on the right: look around.",
		],
	}
