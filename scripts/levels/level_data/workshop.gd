extends RefCounted
## Plumbing Workshop: a debug level with one of every plumbing object, used
## to test milestone M5 (Main menu > Debug rooms > Plumbing Workshop).


static func data() -> Dictionary:
	return {
		"name": "Plumbing Workshop",
		"time_limit": 360.0,
		"storm_interval": 45.0,
		"start_gravity": Vector3.DOWN,
		"bounds": {"center": Vector3(0, 4, 0), "radius": 40.0},
		"palette": {
			"floor": Color(0.36, 0.32, 0.28), "wall": Color(0.6, 0.66, 0.54), "ceiling": Color(0.4, 0.44, 0.38),
			"trim": Color(0.92, 0.62, 0.14), "lamp": Color(1.0, 0.92, 0.75), "ambient": Color(0.74, 0.72, 0.66),
			"nebula_a": Color(0.3, 0.15, 0.4), "nebula_b": Color(0.1, 0.3, 0.35), "planet": Color(0.9, 0.6, 0.3),
		},
		"rooms": [
			{"id": "shop", "center": Vector3(0, 4, 0), "size": Vector3(20, 8, 16),
				"openings": [{"wall": "+z", "at": Vector2(0, 0.5), "size": Vector2(8, 4), "window": true}]},
		],
		"pipes": [
			{"points": [Vector3(-2, 0.2, -7.6), Vector3(-2, 1.9, -7.6)], "radius": 0.16, "color": "teal"},
			{"points": [Vector3(-2, 3.1, -7.6), Vector3(-2, 7.8, -7.6)], "radius": 0.16, "color": "teal"},
			{"points": [Vector3(-9.6, 6.5, -7.6), Vector3(9.6, 6.5, -7.6)], "radius": 0.18, "color": "orange", "glow": true},
			{"points": [Vector3(3, 0.2, -7.7), Vector3(3, 6.5, -7.7)], "radius": 0.14, "color": "orange"},
			{"points": [Vector3(-9.6, 2.2, 2), Vector3(-9.6, 2.2, 6)], "radius": 0.08, "color": "grey"},
		],
		"spawns": [
			{"pos": Vector3(-6, 0, 4), "yaw": PI},
			{"pos": Vector3(-4.5, 0, 4), "yaw": PI},
			{"pos": Vector3(-6, 0, 5.5), "yaw": PI},
			{"pos": Vector3(-4.5, 0, 5.5), "yaw": PI},
		],
		"tool_racks": [
			{"pos": Vector3(-9.7, 0, -2), "yaw": -PI * 0.5, "tools": ["plunger", "wrench", "tape", "gwrench"]},
		],
		"props": [
			{"type": "canister", "pos": Vector3(-6, 0.4, -5), "worth": 4},
			{"type": "canister", "pos": Vector3(-6.6, 0.4, -4.2), "worth": 4},
			{"type": "crate", "pos": Vector3(4, 0.4, 3), "size": Vector3(0.8, 0.8, 0.8)},
			{"type": "crate", "pos": Vector3(4.2, 1.3, 3), "size": Vector3(0.6, 0.6, 0.6)},
		],
		"leaks": [{"id": "leak_a", "pos": Vector3(3, 1.6, -7.75), "normal": Vector3.BACK}],
		"valves": [{"id": "valve_a", "pos": Vector3(9.75, 1.3, 0), "normal": Vector3.LEFT}],
		"clogs": [{"id": "clog_a", "pos": Vector3(6, 0.6, 5), "radius": 0.6}],
		"tanks": [{"id": "tank_a", "pos": Vector3(-4, 0.8, -5), "size": Vector3(1.6, 1.6, 1.6), "need": 8}],
		"pipe_pieces": [{"id": "piece_a", "pos": Vector3(0, 0.3, 2)}],
		"ports": [{"id": "port_a", "piece": "piece_a", "pos": Vector3(-2, 2.5, -7.6), "axis": Vector3.UP}],
		"switches": [{"id": "switch_a", "pos": Vector3(9.8, 1.4, 4), "normal": Vector3.LEFT, "dirs": [1, 0]}],
		"vents": [{"id": "vent_a", "pos": Vector3(0, 0.02, -3), "dir": Vector3.UP, "period": 14.0}],
		"ducks": [{"id": "workshop_1", "pos": Vector3(8, 7.2, -6)}],
		"work_orders": [
			{"id": "w_leak", "type": "leak", "targets": ["leak_a"], "text": "Tape up the leaky orange pipe!"},
			{"id": "w_valve", "type": "valve", "targets": ["valve_a"], "text": "Crank the red valve with the wrench.", "after": ["w_leak"]},
			{"id": "w_pipe", "type": "pipe", "targets": ["port_a"], "text": "Reconnect the missing teal pipe."},
			{"id": "w_clog", "type": "clog", "targets": ["clog_a"], "text": "Plunge the purple clog until it pops."},
			{"id": "w_tank", "type": "tank", "targets": ["tank_a"], "text": "Fill the tank with goo (canisters count!)."},
			{"id": "w_switch", "type": "switch", "targets": ["switch_a"], "text": "Pull the yellow gravity switch."},
		],
		"dispatcher": {
			"start": "Welcome to the workshop, plumbers! Everything here is broken. On purpose. Mostly.",
			"storm": ["Gravity storm! Grab a pipe!", "Uh oh. Floors are optional now!", "Hold on to something! Or someone!"],
			"done": ["Ooh, shiny work!", "That's a fix! I think.", "Plumbtastic!"],
			"flush": ["Whoosh! Down the cosmic drain!", "Flushed! We'll print you a new one."],
		},
	}
