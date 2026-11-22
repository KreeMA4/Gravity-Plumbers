extends RefCounted
## Level 2 - Zero-G Cafeteria (~7 min).
## New idea: ZERO-G ZONES. The kitchen (left) has normal gravity; the dining
## hall (right) floats. Push off walls, anchor with the PLUNGER, and meet the
## G-WRENCH: zap floating canisters so they "fall" toward the kitchen tank.


static func data() -> Dictionary:
	return {
		"name": "Zero-G Cafeteria",
		"time_limit": 540.0,
		"storm_interval": 0.0,
		"start_gravity": Vector3.DOWN,
		"bounds": {"center": Vector3(0, 5, 0), "radius": 45.0},
		"palette": {
			"floor": Color(0.82, 0.42, 0.24), "wall": Color(0.88, 0.74, 0.5), "ceiling": Color(0.68, 0.52, 0.42),
			"trim": Color(0.72, 0.22, 0.24), "lamp": Color(1.0, 0.92, 0.75), "ambient": Color(0.86, 0.72, 0.64),
			"nebula_a": Color(0.5, 0.2, 0.4), "nebula_b": Color(0.2, 0.3, 0.5), "planet": Color(0.6, 0.9, 0.5),
		},
		"rooms": [
			{"id": "cafe", "center": Vector3(0, 5, 0), "size": Vector3(24, 10, 18),
				"openings": [
					{"wall": "+z", "at": Vector2(6, 1), "size": Vector2(9, 5), "window": true},
					{"wall": "-z", "at": Vector2(6, 1), "size": Vector2(9, 5), "window": true},
				]},
		],
		"fields": [
			{"id": "dining_zero_g", "kind": "zero_g", "center": Vector3(6.5, 5, 0), "half": Vector3(5.5, 5, 9), "priority": 3, "drag": 0.5},
		],
		"boxes": [
			# Kitchen counters
			{"pos": Vector3(-9, 0.5, -6), "size": Vector3(5, 1.0, 1.4), "color": Color(0.85, 0.4, 0.3)},
			{"pos": Vector3(-9, 0.5, 6), "size": Vector3(5, 1.0, 1.4), "color": Color(0.85, 0.4, 0.3)},
			# Serving hatch wall between kitchen and hall (with a big gap)
			{"pos": Vector3(0.5, 7.5, 0), "size": Vector3(0.4, 5, 18), "color": Color(0.95, 0.85, 0.7)},
			# Floating tables (static, grabbable) in the dining hall
			{"pos": Vector3(5, 3.5, -4), "size": Vector3(2.2, 0.2, 1.4), "color": Color(0.4, 0.75, 0.85), "grab": true},
			{"pos": Vector3(8, 6.5, 3), "size": Vector3(2.2, 0.2, 1.4), "color": Color(0.4, 0.75, 0.85), "grab": true},
			{"pos": Vector3(10, 2.0, -1), "size": Vector3(2.2, 0.2, 1.4), "color": Color(0.4, 0.75, 0.85), "grab": true},
		],
		"pipes": [
			{"points": [Vector3(-11.6, 0.3, -2), Vector3(-11.6, 3.5, -2), Vector3(-11.6, 3.5, 2)], "radius": 0.12, "color": "teal"},
			{"points": [Vector3(1, 9.6, -8.6), Vector3(11.6, 9.6, -8.6), Vector3(11.6, 0.4, -8.6)], "radius": 0.15, "color": "orange", "glow": true},
			{"points": [Vector3(2, 5, 8.6), Vector3(11, 5, 8.6)], "radius": 0.08, "color": "grey"},
			{"points": [Vector3(2, 2, -8.6), Vector3(11, 2, -8.6)], "radius": 0.08, "color": "grey"},
			{"points": [Vector3(-3, 0.3, -8.7), Vector3(-3, 1.6, -8.7)], "radius": 0.16, "color": "teal"},
			{"points": [Vector3(-3, 2.8, -8.7), Vector3(-3, 9.8, -8.7)], "radius": 0.16, "color": "teal"},
		],
		"labels": [
			{"text": "KITCHEN", "pos": Vector3(-11.7, 4.5, 0), "yaw": -PI * 0.5, "size": 100, "color": Color(0.85, 0.4, 0.3)},
			{"text": "ZERO-G DINING", "pos": Vector3(11.7, 7.5, 0), "yaw": PI * 0.5, "size": 100, "color": Color(0.3, 0.7, 0.9)},
		],
		"spawns": [
			{"pos": Vector3(-8, 0, -1), "yaw": -PI * 0.5},
			{"pos": Vector3(-8, 0, 1), "yaw": -PI * 0.5},
			{"pos": Vector3(-9.5, 0, -1), "yaw": -PI * 0.5},
			{"pos": Vector3(-9.5, 0, 1), "yaw": -PI * 0.5},
		],
		"tool_racks": [
			{"pos": Vector3(-11.7, 0, 3.8), "yaw": -PI * 0.5, "tools": ["plunger", "tape", "wrench", "gwrench"]},
		],
		"props": [
			{"type": "canister", "pos": Vector3(6, 6, -2), "worth": 4, "vel": Vector3(0.3, 0.2, 0.1)},
			{"type": "canister", "pos": Vector3(9, 4, 4), "worth": 4, "vel": Vector3(-0.2, 0.1, -0.2)},
			{"type": "canister", "pos": Vector3(4, 8, 5), "worth": 4, "vel": Vector3(0.1, -0.1, 0.2)},
			{"type": "food", "pos": Vector3(5, 5, 0)}, {"type": "food", "pos": Vector3(7, 3, -3)},
			{"type": "food", "pos": Vector3(9, 7, 1)}, {"type": "food", "pos": Vector3(3, 2, 2)},
			{"type": "food", "pos": Vector3(10, 5, -5)}, {"type": "food", "pos": Vector3(6, 8, 6)},
			{"type": "food", "pos": Vector3(4, 6, -6)}, {"type": "food", "pos": Vector3(8, 2, 6)},
		],
		"leaks": [
			{"id": "soda_leak", "pos": Vector3(-11.75, 1.6, -2.0), "normal": Vector3.RIGHT},
			{"id": "drip_leak", "pos": Vector3(8.0, 9.85, -3.0), "normal": Vector3.DOWN},
		],
		"tanks": [{"id": "kitchen_tank", "pos": Vector3(-5, 0.9, 5.5), "size": Vector3(1.8, 1.8, 1.8), "need": 12}],
		"clogs": [{"id": "chute_clog", "pos": Vector3(11.4, 5.0, 6.0), "radius": 0.5}],
		"valves": [{"id": "cooler_valve", "pos": Vector3(-6, 1.4, -8.85), "normal": Vector3.BACK, "two_player": true}],
		"pipe_pieces": [{"id": "feed_pipe", "pos": Vector3(9, 8.5, -6), "rot": Vector3(0.4, 0.2, 1.2)}],
		"ports": [{"id": "feed_port", "piece": "feed_pipe", "pos": Vector3(-3, 2.2, -8.7), "axis": Vector3.UP}],
		"ducks": [{"id": "cafeteria_1", "pos": Vector3(11, 9, 8)}],
		"work_orders": [
			{"id": "o_soda", "type": "leak", "targets": ["soda_leak"], "text": "Tape the leaking soda pipe in the kitchen."},
			{"id": "o_tank", "type": "tank", "targets": ["kitchen_tank"], "text": "Fetch the floating goo canisters into the kitchen tank (try the G-WRENCH!)."},
			{"id": "o_clog", "type": "clog", "targets": ["chute_clog"], "text": "Plunge the food chute clog (anchor with the plunger first!)."},
			{"id": "o_valve", "type": "valve", "targets": ["cooler_valve"], "text": "Turn the cooler valve - it takes TWO plumbers!", "after": ["o_soda"]},
			{"id": "o_pipe", "type": "pipe", "targets": ["feed_port"], "text": "Float the feed pipe back to the kitchen wall."},
			{"id": "o_drip", "type": "leak", "targets": ["drip_leak"], "text": "Seal the ceiling drip over the dining hall.", "after": ["o_clog"]},
		],
		"dispatcher": {
			"start": "Lunch time! The cafeteria's gravity generator is on its break. Again.",
			"storm": ["Gravity hiccup!"],
			"done": ["Delicious work!", "Five stars. For the plumbing. Not the food.", "Clean plates, clean pipes!"],
			"flush": ["Flushed with the leftovers!", "Back to the kitchen with you!"],
		},
		"tutorial": [
			"In zero-G: point the camera and push the stick to float. Grab tables to stop.",
			"G-WRENCH: aim at a canister and ZAP to choose which way it falls.",
		],
	}
