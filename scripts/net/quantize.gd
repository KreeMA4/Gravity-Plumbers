class_name Quantize
extends RefCounted
## Pure helpers to squeeze numbers into few bytes for the network.

## -1..1 float -> signed byte (-127..127)
static func f_to_s8(v: float) -> int:
	return clampi(roundi(clampf(v, -1.0, 1.0) * 127.0), -127, 127)


static func s8_to_f(v: int) -> float:
	return clampf(float(v) / 127.0, -1.0, 1.0)


## Float in [-range_m, range_m] -> signed 16-bit.
static func f_to_s16(v: float, range_m: float) -> int:
	return clampi(roundi(clampf(v / range_m, -1.0, 1.0) * 32767.0), -32767, 32767)


static func s16_to_f(v: int, range_m: float) -> float:
	return float(v) / 32767.0 * range_m


## Quaternion "smallest three" packed into 4 int16 (simple + robust: x,y,z,w scaled).
static func quat_to_s16(q: Quaternion) -> PackedInt32Array:
	var n: Quaternion = q.normalized()
	if n.w < 0.0:
		n = -n   # q and -q are the same rotation; keep w positive
	return PackedInt32Array([f_to_s16(n.x, 1.0), f_to_s16(n.y, 1.0), f_to_s16(n.z, 1.0)])


static func s16_to_quat(x: int, y: int, z: int) -> Quaternion:
	var qx: float = s16_to_f(x, 1.0)
	var qy: float = s16_to_f(y, 1.0)
	var qz: float = s16_to_f(z, 1.0)
	var w2: float = 1.0 - qx * qx - qy * qy - qz * qz
	var qw: float = sqrt(maxf(0.0, w2))
	return Quaternion(qx, qy, qz, qw).normalized()


## Write a Vector3 position (range +-range_m) as 3 x int16 into a StreamPeerBuffer.
static func put_vec3(buf: StreamPeerBuffer, v: Vector3, range_m: float) -> void:
	buf.put_16(f_to_s16(v.x, range_m))
	buf.put_16(f_to_s16(v.y, range_m))
	buf.put_16(f_to_s16(v.z, range_m))


static func get_vec3(buf: StreamPeerBuffer, range_m: float) -> Vector3:
	var x: float = s16_to_f(buf.get_16(), range_m)
	var y: float = s16_to_f(buf.get_16(), range_m)
	var z: float = s16_to_f(buf.get_16(), range_m)
	return Vector3(x, y, z)


static func put_quat(buf: StreamPeerBuffer, q: Quaternion) -> void:
	var p: PackedInt32Array = quat_to_s16(q)
	buf.put_16(p[0])
	buf.put_16(p[1])
	buf.put_16(p[2])


static func get_quat(buf: StreamPeerBuffer) -> Quaternion:
	var x: int = buf.get_16()
	var y: int = buf.get_16()
	var z: int = buf.get_16()
	return s16_to_quat(x, y, z)
