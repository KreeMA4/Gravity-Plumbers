extends RefCounted
## Level 3 - Asteroid Waterworks (~8 min).
## New idea: PLANETOID GRAVITY. Walk all the way around a little rock (down
## always points at its centre), with pipes wrapped around it, then jump to a
## second tiny moon that has its own centre of gravity.

const A: Vector3 = Vector3(0, 0, 0)
const B: Vector3 = Vector3(17, 5, 0)
const RA: float = 6.0
const RB: float = 4.0


static func _on(c: Vector3, r: float, dir: Vector3, lift: float = 0.0) -> Vector3:
	return c + dir.normalized() * (r + lift)


static func _ring(c: Vector3, r: float, n: int, axis_a: Vector3, axis_b: Vector3, from_a: float, to_a: float) -> Array:
	var pts: Array = []
	for i: int in n + 1:
		var t: float = lerpf(from_a, to_a, float(i) / float(n))
		pts.append(c + (axis_a * cos(t) + axis_b * sin(t)) * r)
	return pts


static func data() -> Dictionary:
	var bridge_dir: Vector3 = (B - A).normalized()
	var bridge_a: Vector3 = _on(A, RA, bridge_dir, 0.3)
	var bridge_b: Vector3 = _on(B, RB, -bridge_dir, 0.3)
	var mid: Vector3 = (bridge_a + bridge_b) * 0.5
	return {
		"name": "Asteroid Waterworks",
		"time_limit": 600.0,
		"storm_interval": 0.0,
		"start_gravity": Vector3.DOWN,
		"bounds": {"center": Vector3(8, 2, 0), "radius": 40.0},
		"palette": {
			"floor": Color(0.48, 0.38, 0.62), "wall": Color(0.7, 0.63, 0.82), "ceiling": Color(0.46, 0.4, 0.58),
			"trim": Color(0.2, 0.62, 0.72), "lamp": Color(0.8, 0.9, 1.0), "ambient": Color(0.6, 0.6, 0.88),
			"nebula_a": Color(0.25, 0.1, 0.5), "nebula_b": Color(0.05, 0.35, 0.5), "planet": Color(1.0, 0.45, 0.3),
		},
		"fields": [
			# Open space between the rocks: no gravity, a touch of drag.
			{"id": "space", "kind": "zero_g", "center": Vector3(8, 2, 0), "half": Vector3(40, 40, 40), "priority": 1, "drag": 0.15, "visual": false},
			{"id": "rock_a", "kind": "sphere", "center": A, "surface": RA, "radius": 12.5, "priority": 2, "falloff": true},
			{"id": "rock_b", "kind": "sphere", "center": B, "surface": RB, "radius": 9.0, "priority": 2, "falloff": true},
		],
		"rocks": [
			{"center": A, "radius": RA, "color": Color(0.55, 0.45, 0.65)},
			{"center": B, "radius": RB, "color": Color(0.7, 0.5, 0.45)},
		],
		"pipes": [
			# Water main wrapped all the way round rock A (equator).
			{"points": _ring(A, RA + 0.35, 24, Vector3.RIGHT, Vector3.BACK, 0.0, TAU), "radius": 0.22, "color": "teal", "glow": true},
			# Meridian pipe over the poles.
			{"points": _ring(A, RA + 0.3, 20, Vector3.UP, Vector3.BACK, -PI * 0.5, PI * 0.9), "radius": 0.14, "color": "orange"},
			# Ring round the little moon.
			{"points": _ring(B, RB + 0.3, 16, Vector3.UP, Vector3.BACK, 0.0, TAU), "radius": 0.16, "color": "purple"},
			# The broken bridge pipe between the rocks (two halves with a gap).
			{"points": [bridge_a, mid - bridge_dir * 0.75], "radius": 0.18, "color": "grey"},
			{"points": [mid + bridge_dir * 0.75, bridge_b], "radius": 0.18, "color": "grey"},
		],
		"spawns": [
			{"pos": _on(A, RA, Vector3.UP), "up": Vector3.UP},
			{"pos": _on(A, RA, Vector3(0.25, 1, 0)), "up": Vector3(0.25, 1, 0).normalized()},
			{"pos": _on(A, RA, Vector3(-0.25, 1, 0)), "up": Vector3(-0.25, 1, 0).normalized()},
			{"pos": _on(A, RA, Vector3(0, 1, 0.25)), "up": Vector3(0, 1, 0.25).normalized()},
		],
		"tool_racks": [
			{"pos": _on(A, RA, Vector3(-0.3, 1, -0.5)), "up": Vector3(-0.3, 1, -0.5).normalized(), "yaw": 0.0, "tools": ["tape", "wrench", "plunger", "gwrench"]},
		],
		"props": [
			{"type": "canister", "pos": _on(A, RA, Vector3(0.6, 1, 0.4), 0.4), "worth": 4},
			{"type": "canister", "pos": _on(A, RA, Vector3(0.4, 1, 0.7), 0.4), "worth": 4},
		],
		"leaks": [
			{"id": "equator_leak", "pos": _on(A, RA + 0.35, Vector3.BACK, 0.25), "normal": Vector3.BACK},
			{"id": "south_leak", "pos": _on(A, RA, Vector3.DOWN, 0.1), "normal": Vector3.DOWN},
		],
		"valves": [{"id": "pole_valve", "pos": _on(A, RA, Vector3(0, -0.5, -1), 0.05), "normal": Vector3(0, -0.5, -1).normalized()}],
		"tanks": [{"id": "moon_tank", "pos": _on(B, RB, Vector3(0.4, 1, 0), 0.8), "up": Vector3(0.4, 1, 0).normalized(), "need": 8}],
		"clogs": [{"id": "moon_clog", "pos": _on(B, RB, Vector3(1, -0.4, 0.3), 0.2), "radius": 0.5}],
		"pipe_pieces": [{"id": "bridge_piece", "pos": _on(A, RA, Vector3(0.2, 1, -0.3), 0.4)}],
		"ports": [{"id": "bridge_port", "piece": "bridge_piece", "pos": mid, "axis": bridge_dir}],
		"ducks": [{"id": "waterworks_1", "pos": _on(B, RB, Vector3(0, -1, -0.3), 0.6)}],
		"work_orders": [
			{"id": "o_equator", "type": "leak", "targets": ["equator_leak"], "text": "Tape the leak on the water main (walk round the rock!)."},
			{"id": "o_south", "type": "leak", "targets": ["south_leak"], "text": "Tape the leak at the SOUTH POLE (keep walking, gravity follows you)."},
			{"id": "o_valve", "type": "valve", "targets": ["pole_valve"], "text": "Crank the pole valve shut.", "after": ["o_equator"]},
			{"id": "o_bridge", "type": "pipe", "targets": ["bridge_port"], "text": "Fix the bridge pipe between the rocks (float the piece into the gap)."},
			{"id": "o_tank", "type": "tank", "targets": ["moon_tank"], "text": "Carry both goo canisters to the tank on the little moon.", "after": ["o_bridge"]},
			{"id": "o_clog", "type": "clog", "targets": ["moon_clog"], "text": "Plunge the clog on the moon's far side.", "after": ["o_bridge"]},
		],
		"dispatcher": {
			"start": "Welcome to the Waterworks! Mind the drop. There's no drop. There's no down. Good luck!",
			"storm": ["Rock wobble!"],
			"done": ["Out of this world!", "Rock solid work!", "Asteroid-tastic!"],
			"flush": ["Drifted off into space! Reprinting plumber...", "Lost in space! Back you come."],
		},
		"tutorial": [
			"Down points at the rock's centre. Walk all the way round it!",
			"Jump hard toward the little moon, or climb along the bridge pipe.",
		],
	}
