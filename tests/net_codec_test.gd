extends TestCase
## Quantisation, input packets and snapshot encode/decode.


func test_quantize_round_trip() -> void:
	for v: float in [-1.0, -0.5, 0.0, 0.33, 1.0]:
		check_near(Quantize.s8_to_f(Quantize.f_to_s8(v)), v, "s8 round trip", 0.01)
	for v2: float in [-39.0, -1.25, 0.0, 12.5, 39.9]:
		check_near(Quantize.s16_to_f(Quantize.f_to_s16(v2, 40.0), 40.0), v2, "s16 round trip", 0.005)
	var q: Quaternion = Quaternion(Vector3(0.3, 1.0, -0.2).normalized(), 2.4)
	var p: PackedInt32Array = Quantize.quat_to_s16(q)
	var q2: Quaternion = Quantize.s16_to_quat(p[0], p[1], p[2])
	check(absf(q.dot(q2)) > 0.9999, "quaternion round trip (same rotation)")
	check_near(Quantize.s8_to_f(Quantize.f_to_s8(5.0)), 1.0, "clamps out of range")


func test_input_packet() -> void:
	var inp: PlumberInput = PlumberInput.new()
	inp.move = Vector2(0.5, -0.75)
	inp.aim = Vector3(0.2, -0.3, -0.9).normalized()
	inp.buttons = PlumberInput.JUMP | PlumberInput.GRAB_R | PlumberInput.BOOTS
	inp.emote_id = 3
	var b: PackedByteArray = inp.to_bytes()
	check_eq(b.size(), 8, "input is 8 bytes")
	var out: PlumberInput = PlumberInput.from_bytes(b)
	check(out.move.distance_to(inp.move) < 0.02, "move survives")
	check(out.aim.distance_to(inp.aim) < 0.03, "aim survives")
	check_eq(out.buttons, inp.buttons, "buttons survive")
	check_eq(out.emote_id, 3, "emote survives")
	# The Interact bit (256) rides in the packet's spare byte.
	inp.buttons = PlumberInput.INTERACT | PlumberInput.USE | PlumberInput.EMOTE
	var out2: PlumberInput = PlumberInput.from_bytes(inp.to_bytes())
	check_eq(out2.buttons, inp.buttons, "Interact bit survives the network packet")
	var junk: PlumberInput = PlumberInput.from_bytes(PackedByteArray([1, 2]))
	check_eq(junk.buttons, 0, "short packet is ignored safely")


func test_snapshot_round_trip() -> void:
	var parts: Array = []
	var pelvis: Vector3 = Vector3(10.5, 3.25, -7.0)
	parts.append([pelvis, Quaternion(Vector3.UP, 0.7)])
	for i: int in 10:
		parts.append([pelvis + Vector3(0.1 * i, -0.08 * i, 0.05), Quaternion(Vector3.RIGHT, 0.1 * i)])
	var pl: Dictionary = {"index": 2, "state": 1, "flags": SnapshotSync.F_BOOTS_ON, "up": Vector3(0, 0, 1),
		"vel": Vector3(3, -12, 0.5), "parts": parts}
	var props: Array = [[7, Vector3(1, 2, 3), Quaternion(Vector3.BACK, 1.0)], [300, Vector3(-4, 0.5, 9), Quaternion.IDENTITY]]
	var goo: Array = [[5, Vector3(2, 1, -3)], [59, Vector3(-20, 4, 11)]]
	var center: Vector3 = Vector3(0, 4, 0)
	var bytes: PackedByteArray = SnapshotSync.encode(42, 12.5, [pl], props, goo, center, 1200)
	var d: Dictionary = SnapshotSync.decode(bytes, center)
	check(not d.is_empty(), "decodes")
	check_eq(int(d["seq"]), 42, "seq")
	check_near(float(d["time"]), 12.5, "time")
	var dp: Dictionary = (d["plumbers"] as Array)[0]
	check_eq(int(dp["index"]), 2, "plumber index")
	check_eq(int(dp["state"]), 1, "plumber state")
	check_eq(int(dp["flags"]), SnapshotSync.F_BOOTS_ON, "flags")
	check_vec(dp["vel"] as Vector3, Vector3(3, -12, 0.5), "velocity", 0.01)
	check_vec(dp["up"] as Vector3, Vector3(0, 0, 1), "up", 0.02)
	var dparts: Array = dp["parts"]
	check_eq(dparts.size(), 11, "11 parts")
	check_vec((dparts[0] as Array)[0] as Vector3, pelvis, "pelvis exact", 0.0001)
	check_vec((dparts[7] as Array)[0] as Vector3, (parts[7] as Array)[0] as Vector3, "limb position", 0.001)
	check(absf(((dparts[7] as Array)[1] as Quaternion).dot((parts[7] as Array)[1] as Quaternion)) > 0.9999, "limb rotation")
	check_eq((d["props"] as Array).size(), 2, "props")
	check_eq(int(((d["props"] as Array)[1] as Array)[0]), 300, "prop id")
	check_vec(((d["goo"] as Array)[1] as Array)[1] as Vector3, Vector3(-20, 4, 11), "goo position", 0.01)


func test_snapshot_budget() -> void:
	var props: Array = []
	for i: int in 200:
		props.append([i, Vector3(i, 0, 0), Quaternion.IDENTITY])
	var bytes: PackedByteArray = SnapshotSync.encode(1, 0.0, [], props, [], Vector3.ZERO, 1200)
	check(bytes.size() <= 1200, "snapshot stays within the byte budget (%d)" % bytes.size())
	var d: Dictionary = SnapshotSync.decode(bytes, Vector3.ZERO)
	check((d["props"] as Array).size() > 40, "fits a useful number of props")


func test_snapshot_garbage() -> void:
	check(SnapshotSync.decode(PackedByteArray([1, 2, 3]), Vector3.ZERO).is_empty(), "short garbage rejected")
	var bad: PackedByteArray = PackedByteArray([1, 0, 0, 0, 0, 0, 0, 9, 1, 1, 1, 11])
	check(SnapshotSync.decode(bad, Vector3.ZERO).is_empty(), "truncated plumber rejected")


func test_look_round_trip_and_clamp() -> void:
	var look: PlumberLook = PlumberLook.default_for(2)
	look.set_v("headgear", 7)
	var b: PackedByteArray = look.to_bytes()
	check(b.size() >= 16 and b.size() <= 20, "look is 16-20 bytes (%d)" % b.size())
	var back: PlumberLook = PlumberLook.from_bytes(b)
	check(back.equals(look), "look round trip")
	var evil: PackedByteArray = PackedByteArray()
	for i: int in 25:
		evil.append(250)
	var clamped: PlumberLook = PlumberLook.from_bytes(evil)
	for f: Variant in PlumberLook.FIELDS:
		check(clamped.get_v(str(f)) <= PlumberLook.max_value(str(f)), "field %s clamped" % str(f))
	clamped.enforce_unlocks(0)
	check(PlumberLook.is_unlocked("headgear", clamped.get_v("headgear"), 0), "host strips locked items")
