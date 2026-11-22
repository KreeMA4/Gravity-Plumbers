extends RefCounted
## Level 4 - Spin-Cycle Habitat (~8 min).
## New idea: a SCHEDULED GRAVITY CYCLE. The habitat drum "rotates": every
## storm, down moves to the next wall in order - floor, right wall, ceiling,
## left wall, floor... Each wall has jobs on it. Timing puzzle: be on (or
## braced next to) the right wall when it becomes the floor.
## Axis indices: 0 = -Y (floor), 2 = +X (right wall), 1 = +Y (ceiling), 3 = -X (left wall).


static func data() -> Dictionary:
	return {
		"name": "Spin-Cycle Habitat",
		"time_limit": 600.0,
		"storm_interval": 32.0,
		"storm_sequence": [2, 1, 3, 0],
		"start_gravity": Vector3.DOWN,
		"bounds": {"center": Vector3(0, 7, 0), "radius": 40.0},
		"palette": {
			"floor": Color(0.35, 0.6, 0.55), "wall": Color(0.85, 0.92, 0.9), "ceiling": Color(0.6, 0.75, 0.72),
			"trim": Color(0.2, 0.45, 0.45), "lamp": Color(0.9, 1.0, 0.95), "ambient": Color(0.65, 0.8, 0.8),
			"nebula_a": Color(0.1, 0.35, 0.3), "nebula_b": Color(0.3, 0.2, 0.5), "planet": Color(0.95, 0.85, 0.4),
		},
		"rooms": [
			{"id": "drum", "center": Vector3(0, 7, 0), "size": Vector3(14, 14, 16),
				"openings": [
					{"wall": "+z", "at": Vector2(0, 0), "size": Vector2(6, 6), "window": true},
					{"wall": "-z", "at": Vector2(0, 0), "size": Vector2(6, 6), "window": true},
				]},
		],
		"spinners": [
			{"pos": Vector3(0, 7, 10), "radius": 9.0, "thickness": 0.5, "axis": Vector3.BACK, "speed": 0.25, "color": Color(0.4, 0.9, 0.8)},
			{"pos": Vector3(0, 7, -10), "radius": 9.0, "thickness": 0.5, "axis": Vector3.BACK, "speed": -0.25, "color": Color(0.4, 0.9, 0.8)},
		],
		"pipes": [
			# Grab rails running round the drum on every wall (brace on these!).
			{"points": [Vector3(-6.7, 0.5, -3), Vector3(6.7, 0.5, -3)], "radius": 0.08, "color": "grey"},
			{"points": [Vector3(6.5, 0.5, 3), Vector3(6.5, 13.5, 3)], "radius": 0.08, "color": "grey"},
			{"points": [Vector3(6.7, 13.5, -3), Vector3(-6.7, 13.5, -3)], "radius": 0.08, "color": "grey"},
			{"points": [Vector3(-6.5, 13.5, 3), Vector3(-6.5, 0.5, 3)], "radius": 0.08, "color": "grey"},
			{"points": [Vector3(-6.7, 0.4, 6), Vector3(6.7, 0.4, 6), Vector3(6.7, 13.6, 6), Vector3(-6.7, 13.6, 6), Vector3(-6.7, 0.4, 6)], "radius": 0.18, "color": "orange", "glow": true},
		],
		"labels": [
			{"text": "FLOOR 1", "pos": Vector3(0, 1.5, -7.9), "up": Vector3.UP, "size": 120, "color": Color(1.0, 0.82, 0.2)},
			{"text": "FLOOR 2", "pos": Vector3(5.5, 7, -7.9), "up": Vector3.LEFT, "size": 120, "color": Color(1.0, 0.82, 0.2)},
			{"text": "FLOOR 3", "pos": Vector3(0, 12.5, -7.9), "up": Vector3.DOWN, "size": 120, "color": Color(1.0, 0.82, 0.2)},
			{"text": "FLOOR 4", "pos": Vector3(-5.5, 7, -7.9), "up": Vector3.RIGHT, "size": 120, "color": Color(1.0, 0.82, 0.2)},
		],
		"spawns": [
			{"pos": Vector3(-1.5, 0, 2), "yaw": 0.0},
			{"pos": Vector3(1.5, 0, 2), "yaw": 0.0},
			{"pos": Vector3(-1.5, 0, 4), "yaw": 0.0},
			{"pos": Vector3(1.5, 0, 4), "yaw": 0.0},
			{"pos": Vector3(7.0, 7, 2), "up": Vector3.LEFT},
			{"pos": Vector3(0, 14.0, 2), "up": Vector3.DOWN},
			{"pos": Vector3(-7.0, 7, 2), "up": Vector3.RIGHT},
		],
		"tool_racks": [
			{"pos": Vector3(-3.5, 0, -7.75), "yaw": PI, "tools": ["tape", "wrench", "plunger", "gwrench"]},
		],
		"props": [
			{"type": "canister", "pos": Vector3(-6.4, 4, -5), "worth": 4},
			{"type": "canister", "pos": Vector3(-6.4, 10, -5), "worth": 4},
			{"type": "crate", "pos": Vector3(3, 0.4, 0), "size": Vector3(0.8, 0.8, 0.8)},
			{"type": "crate", "pos": Vector3(4, 0.4, -1), "size": Vector3(0.7, 0.7, 0.7)},
		],
		"leaks": [
			{"id": "floor_leak", "pos": Vector3(3, 0.2, -7.8), "normal": Vector3.BACK},
			{"id": "wall_leak", "pos": Vector3(6.8, 4, -4), "normal": Vector3.LEFT},
		],
		"valves": [{"id": "ceiling_valve", "pos": Vector3(-2, 13.9, -2), "normal": Vector3.DOWN}],
		"clogs": [{"id": "wall_clog", "pos": Vector3(6.5, 10, 2), "radius": 0.5}],
		"tanks": [{"id": "left_tank", "pos": Vector3(-6.2, 7, -1), "up": Vector3.RIGHT, "need": 8}],
		"switches": [{"id": "relay_switch", "pos": Vector3(3.5, 13.85, 4.5), "normal": Vector3.DOWN, "dirs": [3], "required_dir": 3}],
		"ducks": [{"id": "spincycle_1", "pos": Vector3(-6.3, 12.5, 7.2)}],
		"work_orders": [
			{"id": "o_floor", "type": "leak", "targets": ["floor_leak"], "text": "FLOOR 1: tape the leak before the spin!"},
			{"id": "o_wall", "type": "leak", "targets": ["wall_leak"], "text": "FLOOR 2: tape the leak on the right wall."},
			{"id": "o_clog", "type": "clog", "targets": ["wall_clog"], "text": "FLOOR 2: plunge the clog high on the right wall."},
			{"id": "o_valve", "type": "valve", "targets": ["ceiling_valve"], "text": "FLOOR 3: crank the valve on the ceiling."},
			{"id": "o_relay", "type": "switch", "targets": ["relay_switch"], "text": "FLOOR 3: hit the relay switch to drop everything onto FLOOR 4.", "after": ["o_valve"]},
			{"id": "o_tank", "type": "tank", "targets": ["left_tank"], "text": "FLOOR 4: get both canisters into the wall tank (it only fills when FLOOR 4 is down!)."},
		],
		"dispatcher": {
			"start": "The Spin-Cycle Habitat! Every half minute, down moves to the next wall. Plan ahead, plumbers!",
			"storm": ["Spin cycle! Next floor coming up!", "Rotating! Grab a rail!", "Floors are walls, walls are floors!"],
			"done": ["Spin-credible!", "Round and round and fixed!", "Clean cycle!"],
			"flush": ["Rinsed and flushed!", "Spun right out of there!"],
		},
		"tutorial": [
			"Down moves to the next wall every storm: FLOOR 1, 2, 3, 4, then round again.",
		],
	}
