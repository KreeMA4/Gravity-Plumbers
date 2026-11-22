extends RefCounted
## Level 5 - Reactor Plumbing Panic (finale, ~10 min).
## Everything at once: three rooms, two room switches that must BOTH be
## pulled to aim the reactor's gravity, a gravity storm about every 40 s,
## and the boss: THE GREAT CLOG in the reactor core. You can't plunge it -
## you have to FEED it goo until it bursts. Lure goo into it with gravity
## shifts and the burp vents, or throw canisters at it.
## The room switches switch ON the reactor's own gravity field and point it
## sideways (after that, storms no longer reach the reactor hall).


static func data() -> Dictionary:
	return {
		"name": "Reactor Plumbing Panic",
		"time_limit": 780.0,
		"storm_interval": 40.0,
		"start_gravity": Vector3.DOWN,
		"bounds": {"center": Vector3(0, 6, 0), "radius": 50.0},
		"palette": {
			"floor": Color(0.25, 0.32, 0.44), "wall": Color(0.62, 0.65, 0.74), "ceiling": Color(0.38, 0.4, 0.5),
			"trim": Color(0.95, 0.55, 0.12), "lamp": Color(1.0, 0.75, 0.5), "ambient": Color(0.78, 0.62, 0.62),
			"nebula_a": Color(0.55, 0.15, 0.2), "nebula_b": Color(0.35, 0.1, 0.4), "planet": Color(0.9, 0.3, 0.25),
		},
		"rooms": [
			{"id": "hall", "center": Vector3(0, 6, 0), "size": Vector3(20, 12, 20),
				"openings": [
					{"wall": "-x", "at": Vector2(0, -4.6), "size": Vector2(3, 2.8)},
					{"wall": "+x", "at": Vector2(0, -4.6), "size": Vector2(3, 2.8)},
					{"wall": "+z", "at": Vector2(0, 1), "size": Vector2(10, 5), "window": true},
				]},
			{"id": "coolant", "center": Vector3(-16.4, 4, 0), "size": Vector3(12, 8, 12), "skip": ["+x"]},
			{"id": "waste", "center": Vector3(16.4, 4, 0), "size": Vector3(12, 8, 12), "skip": ["-x"]},
		],
		"fields": [
			{"id": "reactor_field", "kind": "box", "center": Vector3(0, 6, 0), "half": Vector3(9.8, 5.8, 9.8), "dir": Vector3.DOWN, "priority": 1, "visual": false, "enabled": false},
		],
		"spinners": [
			{"pos": Vector3(0, 6, 0), "radius": 3.6, "thickness": 0.25, "axis": Vector3.UP, "speed": 0.6, "color": Color(1.0, 0.55, 0.2)},
			{"pos": Vector3(0, 6, 0), "radius": 3.2, "thickness": 0.2, "axis": Vector3.RIGHT, "speed": -0.45, "color": Color(0.4, 0.9, 1.0)},
		],
		"pipes": [
			{"points": [Vector3(-9.6, 0.4, -9.6), Vector3(-9.6, 11.6, -9.6), Vector3(9.6, 11.6, -9.6), Vector3(9.6, 0.4, -9.6)], "radius": 0.22, "color": "orange", "glow": true},
			{"points": [Vector3(-9.7, 2, 5), Vector3(-9.7, 2, 9)], "radius": 0.08, "color": "grey"},
			{"points": [Vector3(9.7, 2, 5), Vector3(9.7, 2, 9)], "radius": 0.08, "color": "grey"},
			{"points": [Vector3(-5, 0.35, 9.6), Vector3(5, 0.35, 9.6)], "radius": 0.08, "color": "grey"},
			{"points": [Vector3(-5, 11.65, 9.6), Vector3(5, 11.65, 9.6)], "radius": 0.08, "color": "grey"},
			{"points": [Vector3(-22, 1.2, -5.7), Vector3(-11, 1.2, -5.7)], "radius": 0.08, "color": "grey"},
			{"points": [Vector3(11, 1.2, -5.7), Vector3(22, 1.2, -5.7)], "radius": 0.08, "color": "grey"},
			# Reactor feed (broken: the piece goes in the gap)
			{"points": [Vector3(4, 0.3, -9.65), Vector3(4, 2.0, -9.65)], "radius": 0.16, "color": "teal"},
			{"points": [Vector3(4, 3.2, -9.65), Vector3(4, 11.7, -9.65)], "radius": 0.16, "color": "teal"},
		],
		"labels": [
			{"text": "COOLANT", "pos": Vector3(-22.3, 5, 0), "yaw": -PI * 0.5, "size": 100, "color": Color(0.3, 0.8, 1.0)},
			{"text": "WASTE", "pos": Vector3(22.3, 5, 0), "yaw": PI * 0.5, "size": 100, "color": Color(0.7, 0.4, 0.9)},
			{"text": "REACTOR CORE", "pos": Vector3(0, 10.5, -9.75), "size": 120, "color": Color(1.0, 0.55, 0.2)},
		],
		"spawns": [
			{"pos": Vector3(-3, 0, 6), "yaw": 0.0},
			{"pos": Vector3(-1, 0, 6), "yaw": 0.0},
			{"pos": Vector3(1, 0, 6), "yaw": 0.0},
			{"pos": Vector3(3, 0, 6), "yaw": 0.0},
			{"pos": Vector3(0, 12, 6), "up": Vector3.DOWN},
			{"pos": Vector3(-10, 6, 6), "up": Vector3.RIGHT},
			{"pos": Vector3(10, 6, 6), "up": Vector3.LEFT},
			{"pos": Vector3(-16, 0, 3), "yaw": 0.0},
			{"pos": Vector3(16, 0, 3), "yaw": 0.0},
		],
		"tool_racks": [
			{"pos": Vector3(-6, 0, 9.75), "yaw": 0.0, "tools": ["tape", "wrench", "plunger", "gwrench"]},
			{"pos": Vector3(6, 0, 9.75), "yaw": 0.0, "tools": ["tape", "wrench", "gwrench"]},
		],
		"props": [
			{"type": "canister", "pos": Vector3(-20, 0.4, 4), "worth": 4},
			{"type": "canister", "pos": Vector3(-20, 0.4, 2), "worth": 4},
			{"type": "canister", "pos": Vector3(20, 0.4, 4), "worth": 4},
			{"type": "canister", "pos": Vector3(20, 0.4, 2), "worth": 4},
			{"type": "canister", "pos": Vector3(-6, 0.4, -6), "worth": 4},
			{"type": "canister", "pos": Vector3(6, 0.4, -6), "worth": 4},
		],
		"leaks": [
			{"id": "coolant_leak_a", "pos": Vector3(-22.25, 2, -2), "normal": Vector3.RIGHT},
			{"id": "coolant_leak_b", "pos": Vector3(-16, 7.85, 0), "normal": Vector3.DOWN},
		],
		"valves": [{"id": "waste_valve", "pos": Vector3(16.4, 1.4, -5.85), "normal": Vector3.BACK, "two_player": true}],
		"pipe_pieces": [{"id": "feed_piece", "pos": Vector3(-18, 0.3, -3)}],
		"ports": [{"id": "feed_port", "piece": "feed_piece", "pos": Vector3(4, 2.6, -9.65), "axis": Vector3.UP}],
		"switches": [
			{"id": "switch_coolant", "pos": Vector3(-12, 1.4, 5.85), "normal": Vector3.FORWARD, "action": "field_dir", "field": "reactor_field", "dirs": [2]},
			{"id": "switch_waste", "pos": Vector3(12, 1.4, 5.85), "normal": Vector3.FORWARD, "action": "field_dir", "field": "reactor_field", "dirs": [3]},
		],
		"vents": [
			{"id": "vent_floor", "pos": Vector3(0, 0.02, -6), "dir": Vector3.UP, "period": 11.0},
			{"id": "vent_left", "pos": Vector3(-9.98, 6, -6), "dir": Vector3.RIGHT, "period": 13.0},
			{"id": "vent_right", "pos": Vector3(9.98, 6, -6), "dir": Vector3.LEFT, "period": 15.0},
		],
		"great_clogs": [{"id": "great_clog", "pos": Vector3(0, 6, 0), "radius": 2.0, "hp": 30}],
		"tanks": [{"id": "emergency_tank", "pos": Vector3(16, 0.9, 3.5), "need": 8}],
		"ducks": [
			{"id": "reactor_1", "pos": Vector3(-21.5, 7.3, 5.5)},
			{"id": "reactor_2", "pos": Vector3(0, 11.5, -9.2)},
		],
		"work_orders": [
			{"id": "o_coolant", "type": "leak", "targets": ["coolant_leak_a", "coolant_leak_b"], "text": "COOLANT ROOM: tape both coolant leaks."},
			{"id": "o_valve", "type": "valve", "targets": ["waste_valve"], "text": "WASTE ROOM: two plumbers on the big valve!"},
			{"id": "o_feed", "type": "pipe", "targets": ["feed_port"], "text": "Carry the feed pipe from Coolant to the reactor wall."},
			{"id": "o_switches", "type": "switch", "targets": ["switch_coolant", "switch_waste"], "text": "Pull BOTH room switches to aim the reactor's gravity.", "after": ["o_coolant", "o_valve"]},
			{"id": "o_boss", "type": "clog", "targets": ["great_clog"], "text": "FEED THE GREAT CLOG GOO UNTIL IT BURSTS!", "after": ["o_feed"]},
			{"id": "o_tank", "type": "tank", "targets": ["emergency_tank"], "text": "Fill the emergency tank in the Waste room.", "after": ["o_switches"]},
		],
		"on_done": {
			"o_feed": {"say": "The reactor's awake... and so is THE GREAT CLOG! Feed it goo: shift gravity so blobs fly into it, or throw canisters!"},
			"o_switches": {"say": "Reactor gravity aimed! Watch out, it points sideways now."},
		},
		"dispatcher": {
			"start": "This is it, plumbers. The reactor. The pipes. The PANIC. Let's fix the whole station!",
			"storm": ["Reactor surge! Gravity storm!", "Brace brace brace!", "Here we gooooo!", "Everything's sideways again!"],
			"done": ["Heroic plumbing!", "The reactor thanks you!", "That's the stuff!"],
			"flush": ["Flushed into the reactor! It's fine. Probably.", "Down the big drain!"],
		},
		"tutorial": [
			"Feed THE GREAT CLOG goo. Shifts and vents send blobs flying into the core.",
		],
	}
