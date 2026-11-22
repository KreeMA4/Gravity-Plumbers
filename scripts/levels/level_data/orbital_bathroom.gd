extends RefCounted
## Level 1 - Orbital Bathroom (tutorial, ~5 min).
## One idea: a single global gravity switch that flips the room 180 degrees.
## Teaches: move, jump, grab, taping leaks, plunging, the switch warning and
## bracing (hold a pipe or use BOOTS when gravity flips).


static func data() -> Dictionary:
	return {
		"name": "Orbital Bathroom",
		"time_limit": 420.0,
		"storm_interval": 0.0,
		"start_gravity": Vector3.DOWN,
		"bounds": {"center": Vector3(0, 3.5, 0), "radius": 40.0},
		"palette": {
			"floor": Color(0.55, 0.75, 0.85), "wall": Color(0.95, 0.97, 1.0), "ceiling": Color(0.75, 0.85, 0.92),
			"trim": Color(0.3, 0.55, 0.75), "lamp": Color(0.9, 1.0, 1.0), "ambient": Color(0.7, 0.78, 0.92),
			"nebula_a": Color(0.2, 0.35, 0.6), "nebula_b": Color(0.1, 0.45, 0.45), "planet": Color(1.0, 0.6, 0.35),
		},
		"rooms": [
			{"id": "loo", "center": Vector3(0, 3.5, 0), "size": Vector3(16, 7, 12),
				"openings": [{"wall": "+z", "at": Vector2(1.5, 0.3), "size": Vector2(7, 3.4), "window": true}]},
		],
		"boxes": [
			# Sinks
			{"pos": Vector3(-3.5, 0.45, -5.5), "size": Vector3(0.3, 0.9, 0.3), "color": Color(0.95, 0.95, 0.98)},
			{"pos": Vector3(-3.5, 0.95, -5.4), "size": Vector3(1.2, 0.2, 0.9), "color": Color(0.95, 0.95, 0.98)},
			{"pos": Vector3(-1.5, 0.45, -5.5), "size": Vector3(0.3, 0.9, 0.3), "color": Color(0.95, 0.95, 0.98)},
			{"pos": Vector3(-1.5, 0.95, -5.4), "size": Vector3(1.2, 0.2, 0.9), "color": Color(0.95, 0.95, 0.98)},
			# Space toilets
			{"pos": Vector3(3, 0.3, -5.2), "size": Vector3(0.8, 0.6, 1.0), "color": Color(0.97, 0.97, 1.0)},
			{"pos": Vector3(3, 0.9, -5.7), "size": Vector3(0.8, 0.8, 0.3), "color": Color(0.97, 0.97, 1.0)},
			{"pos": Vector3(5, 0.3, -5.2), "size": Vector3(0.8, 0.6, 1.0), "color": Color(0.97, 0.97, 1.0)},
			{"pos": Vector3(5, 0.9, -5.7), "size": Vector3(0.8, 0.8, 0.3), "color": Color(0.97, 0.97, 1.0)},
			# Stall walls
			{"pos": Vector3(4, 1.0, -4.6), "size": Vector3(0.1, 2.0, 2.6), "color": Color(0.4, 0.7, 0.9)},
			{"pos": Vector3(6, 1.0, -4.6), "size": Vector3(0.1, 2.0, 2.6), "color": Color(0.4, 0.7, 0.9)},
			# Shower step
			{"pos": Vector3(6.8, 0.2, 2.0), "size": Vector3(2.2, 0.4, 2.2), "color": Color(0.6, 0.85, 0.95)},
			# Ceiling cabinets (reachable once gravity flips)
			{"pos": Vector3(-5, 6.6, 0), "size": Vector3(2.0, 0.8, 1.2), "color": Color(0.4, 0.7, 0.9)},
		],
		"pipes": [
			{"points": [Vector3(-3.5, 0.9, -5.85), Vector3(-3.5, 0.2, -5.85), Vector3(-1.5, 0.2, -5.85), Vector3(-1.5, 0.9, -5.85)], "radius": 0.08, "color": "teal"},
			{"points": [Vector3(7.8, 0.2, 0.5), Vector3(7.8, 2.4, 0.5), Vector3(7.8, 2.4, 3.5)], "radius": 0.1, "color": "teal", "glow": true},
			# Towel rail next to the switch (brace here when gravity flips!)
			{"points": [Vector3(-7.75, 1.3, 0.5), Vector3(-7.75, 1.3, 2.3)], "radius": 0.06, "color": "grey"},
			# Ceiling pipes (become floor pipes after the flip)
			{"points": [Vector3(-7.6, 6.8, -4), Vector3(7.6, 6.8, -4)], "radius": 0.16, "color": "orange", "glow": true},
			{"points": [Vector3(-7.6, 6.8, 4), Vector3(7.6, 6.8, 4)], "radius": 0.12, "color": "purple"},
			{"points": [Vector3(0, 6.85, -4), Vector3(0, 6.85, 4)], "radius": 0.1, "color": "grey"},
		],
		"labels": [
			{"text": "SPACE LOO", "pos": Vector3(4, 2.6, -5.85), "size": 90, "color": Color(0.2, 0.5, 0.8)},
			{"text": "HOLD THE RAIL\nWHEN IT FLIPS!", "pos": Vector3(-7.75, 2.4, 1.4), "yaw": -PI * 0.5, "size": 48, "color": Color(1.0, 0.7, 0.2)},
		],
		"spawns": [
			{"pos": Vector3(-5.5, 0, 3.5), "yaw": PI * 0.75},
			{"pos": Vector3(-4.2, 0, 3.5), "yaw": PI * 0.75},
			{"pos": Vector3(-5.5, 0, 4.8), "yaw": PI * 0.75},
			{"pos": Vector3(-4.2, 0, 4.8), "yaw": PI * 0.75},
			{"pos": Vector3(0, 7.0, 0), "up": Vector3.DOWN},
		],
		"tool_racks": [
			{"pos": Vector3(-7.75, 0, -2.5), "yaw": -PI * 0.5, "tools": ["tape", "plunger", "wrench"]},
		],
		"props": [
			{"type": "crate", "pos": Vector3(1.0, 0.35, 1.0), "size": Vector3(0.7, 0.7, 0.7), "color": Color(1.0, 0.85, 0.2)},
			{"type": "crate", "pos": Vector3(1.8, 0.3, 1.4), "size": Vector3(0.6, 0.6, 0.6), "color": Color(1.0, 0.45, 0.65)},
		],
		"leaks": [
			{"id": "sink_leak", "pos": Vector3(-2.5, 0.25, -5.8), "normal": Vector3.BACK},
			{"id": "shower_leak", "pos": Vector3(7.8, 2.0, 2.0), "normal": Vector3.LEFT},
			{"id": "ceiling_leak", "pos": Vector3(3.0, 6.95, 0.0), "normal": Vector3.DOWN},
		],
		"clogs": [{"id": "toilet_clog", "pos": Vector3(3, 0.85, -5.0), "radius": 0.4, "hits": 4}],
		"switches": [{"id": "flip_switch", "pos": Vector3(-7.75, 1.4, 3.6), "normal": Vector3.RIGHT, "dirs": [1, 0]}],
		"valves": [{"id": "main_valve", "pos": Vector3(-2.0, 6.9, 2.0), "normal": Vector3.DOWN}],
		"ducks": [{"id": "bathroom_1", "pos": Vector3(-5, 6.0, 0)}],
		"work_orders": [
			{"id": "o_sink", "type": "leak", "targets": ["sink_leak"], "text": "Grab the TAPE (rack, Grab R) and tape the leaky sink!"},
			{"id": "o_shower", "type": "leak", "targets": ["shower_leak"], "text": "Tape the shower leak (hop on the step).", "after": ["o_sink"]},
			{"id": "o_toilet", "type": "clog", "targets": ["toilet_clog"], "text": "Plunge the clogged space toilet!", "after": ["o_sink"]},
			{"id": "o_flip", "type": "switch", "targets": ["flip_switch"], "text": "Pull the gravity switch. Hold the rail or use BOOTS!", "after": ["o_shower", "o_toilet"]},
			{"id": "o_ceiling", "type": "leak", "targets": ["ceiling_leak"], "text": "Walk on the ceiling and tape the leak up there!", "after": ["o_flip"]},
			{"id": "o_valve", "type": "valve", "targets": ["main_valve"], "text": "Crank the main valve shut with the WRENCH.", "after": ["o_flip"]},
		],
		"on_done": {
			"o_sink": {"say": "Taped! Drop the tape with GRAB R, grab the PLUNGER for the toilet."},
			"o_flip": {"say": "Whee! The ceiling is the floor now. Fix the leak and the valve up there!"},
		},
		"dispatcher": {
			"start": "Ah, the Orbital Bathroom. Our most... aromatic module. Let's fix it!",
			"storm": ["Gravity flip in 3! Grab the rail or BOOTS ON!", "Here comes the flip!"],
			"done": ["Sparkling! Well, less sticky.", "Plumbing perfection!", "That's going on your report card!"],
			"flush": ["Flushed! Ironic, in a bathroom.", "Down the cosmic U-bend!"],
		},
		"tutorial": [
			"Left thumb walks, right side looks. Tap JUMP to hop.",
			"Hold GRAB near the rack to take a tool. USE does the job.",
		],
	}
