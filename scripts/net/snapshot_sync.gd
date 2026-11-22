class_name SnapshotSync
extends RefCounted
## Snapshot encoding (host -> clients, 20 per second, unreliable).
## Pure functions, unit tested in tests/net_codec_test.gd.
##
## Layout (little-endian, see docs/NETWORK.md):
##   u8 version, u16 seq, f32 host_time
##   u8 plumber count, then per plumber:
##     u8 player index, u8 state, u8 flags, u8 part count
##     pelvis: 3 x f32 position, quaternion (3 x s16), velocity (3 x s16, +-40 m/s)
##     local up: 3 x s8
##     each other part: position relative to pelvis (3 x s16, +-3 m), quaternion (3 x s16)
##   u8 prop count, then per prop: u16 net id, 3 x f32 position, quaternion (3 x s16)
##   u8 goo count, then per blob: u8 pool index, position (3 x s16, +-128 m around the level centre)
## Props and goo are trimmed (in priority order) to stay under the byte budget.

const VERSION: int = 1
const PART_RANGE: float = 3.0
const VEL_RANGE: float = 40.0
const GOO_RANGE: float = 128.0
const PLUMBER_PART_BYTES: int = 12
const PROP_BYTES: int = 20
const GOO_BYTES: int = 7

## flags
const F_BOOTS_ON: int = 1
const F_BOOTS_ACTIVE: int = 2
const F_CELEBRATE: int = 4
const F_EMOTE: int = 8


## plumbers: Array of Dictionary {index, state, flags (emote id in bits 4-6), up, vel, parts: [[pos, quat], ...]}
##   (parts[0] is the pelvis, absolute; the rest are absolute too and get stored relative)
## props: Array of [net_id, pos, quat] (already in priority order)
## goo: Array of [index, pos]
static func encode(seq: int, host_time: float, plumbers: Array, props: Array, goo: Array, center: Vector3, budget: int) -> PackedByteArray:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_u8(VERSION)
	buf.put_u16(seq & 0xFFFF)
	buf.put_float(host_time)
	buf.put_u8(mini(plumbers.size(), 8))
	for i: int in mini(plumbers.size(), 8):
		var p: Dictionary = plumbers[i] as Dictionary
		var parts: Array = p.get("parts", [])
		buf.put_u8(int(p.get("index", 0)) & 255)
		buf.put_u8(int(p.get("state", 0)) & 255)
		buf.put_u8(int(p.get("flags", 0)) & 255)
		buf.put_u8(mini(parts.size(), 15))
		if parts.is_empty():
			continue
		var pelvis_pos: Vector3 = (parts[0] as Array)[0] as Vector3
		buf.put_float(pelvis_pos.x)
		buf.put_float(pelvis_pos.y)
		buf.put_float(pelvis_pos.z)
		Quantize.put_quat(buf, (parts[0] as Array)[1] as Quaternion)
		Quantize.put_vec3(buf, (p.get("vel", Vector3.ZERO) as Vector3).limit_length(VEL_RANGE), VEL_RANGE)
		var up: Vector3 = p.get("up", Vector3.UP) as Vector3
		buf.put_8(Quantize.f_to_s8(up.x))
		buf.put_8(Quantize.f_to_s8(up.y))
		buf.put_8(Quantize.f_to_s8(up.z))
		for j: int in range(1, mini(parts.size(), 15)):
			var part: Array = parts[j] as Array
			Quantize.put_vec3(buf, (part[0] as Vector3) - pelvis_pos, PART_RANGE)
			Quantize.put_quat(buf, part[1] as Quaternion)
	# Props, within budget (leave room for the goo count byte).
	var used: int = buf.get_position() + 2
	var n_props: int = 0
	for pr: Variant in props:
		if used + PROP_BYTES > budget or n_props >= 255:
			break
		used += PROP_BYTES
		n_props += 1
	buf.put_u8(n_props)
	for k: int in n_props:
		var a: Array = props[k] as Array
		buf.put_u16(int(a[0]) & 0xFFFF)
		var pos: Vector3 = a[1] as Vector3
		buf.put_float(pos.x)
		buf.put_float(pos.y)
		buf.put_float(pos.z)
		Quantize.put_quat(buf, a[2] as Quaternion)
	var n_goo: int = 0
	for g: Variant in goo:
		if used + GOO_BYTES > budget or n_goo >= 255:
			break
		used += GOO_BYTES
		n_goo += 1
	buf.put_u8(n_goo)
	for k2: int in n_goo:
		var ga: Array = goo[k2] as Array
		buf.put_u8(int(ga[0]) & 255)
		Quantize.put_vec3(buf, (ga[1] as Vector3) - center, GOO_RANGE)
	return buf.data_array


## Returns {} on garbage, else {"seq", "time", "plumbers": [...], "props": [...], "goo": [...]}
static func decode(bytes: PackedByteArray, center: Vector3) -> Dictionary:
	if bytes.size() < 8:
		return {}
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.big_endian = false
	buf.data_array = bytes
	if buf.get_u8() != VERSION:
		return {}
	var out: Dictionary = {"seq": buf.get_u16(), "time": buf.get_float(), "plumbers": [], "props": [], "goo": []}
	var n_pl: int = buf.get_u8()
	for i: int in n_pl:
		if buf.get_available_bytes() < 4:
			return {}
		var p: Dictionary = {"index": buf.get_u8(), "state": buf.get_u8(), "flags": buf.get_u8()}
		var n_parts: int = buf.get_u8()
		var parts: Array = []
		if n_parts > 0:
			var need: int = 12 + 6 + 6 + 3 + (n_parts - 1) * PLUMBER_PART_BYTES
			if buf.get_available_bytes() < need:
				return {}
			var pelvis: Vector3 = Vector3(buf.get_float(), buf.get_float(), buf.get_float())
			var pq: Quaternion = Quantize.get_quat(buf)
			p["vel"] = Quantize.get_vec3(buf, VEL_RANGE)
			var ux: float = Quantize.s8_to_f(buf.get_8())
			var uy: float = Quantize.s8_to_f(buf.get_8())
			var uz: float = Quantize.s8_to_f(buf.get_8())
			var up: Vector3 = Vector3(ux, uy, uz)
			p["up"] = up.normalized() if up.length_squared() > 0.01 else Vector3.UP
			parts.append([pelvis, pq])
			for j: int in n_parts - 1:
				var rel: Vector3 = Quantize.get_vec3(buf, PART_RANGE)
				var q: Quaternion = Quantize.get_quat(buf)
				parts.append([pelvis + rel, q])
		p["parts"] = parts
		(out["plumbers"] as Array).append(p)
	if buf.get_available_bytes() < 1:
		return out
	var n_props: int = buf.get_u8()
	if buf.get_available_bytes() < n_props * PROP_BYTES:
		return {}
	for k: int in n_props:
		var id: int = buf.get_u16()
		var pos: Vector3 = Vector3(buf.get_float(), buf.get_float(), buf.get_float())
		var q2: Quaternion = Quantize.get_quat(buf)
		(out["props"] as Array).append([id, pos, q2])
	if buf.get_available_bytes() < 1:
		return out
	var n_goo: int = buf.get_u8()
	if buf.get_available_bytes() < n_goo * GOO_BYTES:
		return {}
	for k2: int in n_goo:
		var gi: int = buf.get_u8()
		(out["goo"] as Array).append([gi, Quantize.get_vec3(buf, GOO_RANGE) + center])
	return out


## Interpolate two decoded part lists ([[pos, quat], ...]) at t (0..1).
static func lerp_parts(a: Array, b: Array, t: float) -> Array:
	var out: Array = []
	for i: int in mini(a.size(), b.size()):
		var pa: Array = a[i] as Array
		var pb: Array = b[i] as Array
		out.append([(pa[0] as Vector3).lerp(pb[0] as Vector3, t), (pa[1] as Quaternion).slerp(pb[1] as Quaternion, t)])
	return out
