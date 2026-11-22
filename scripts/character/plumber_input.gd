class_name PlumberInput
extends RefCounted
## One frame of player input. The same structure is used for the local
## player, bots, and network clients (sent to the host 30 times a second).
## move: joystick, x = right, y = forward (camera-relative), length <= 1.
## aim:  world-space direction the camera looks (used for walking and grabbing).

const JUMP: int = 1
const GRAB_L: int = 2
const GRAB_R: int = 4
const USE: int = 8
const BOOTS: int = 16
const FLOP: int = 32
const GET_UP: int = 64
const EMOTE: int = 128
const INTERACT: int = 256   ## contextual: pick up / drop / flip a switch (sent in the spare byte)
const ALL_BITS: int = 511

var move: Vector2 = Vector2.ZERO
var aim: Vector3 = Vector3.FORWARD
var buttons: int = 0
var emote_id: int = 0


func held(bit: int) -> bool:
	return (buttons & bit) != 0


func copy_from(other: PlumberInput) -> void:
	move = other.move
	aim = other.aim
	buttons = other.buttons
	emote_id = other.emote_id


## Make untrusted input safe (network clients).
func sanitize() -> void:
	if not move.is_finite():
		move = Vector2.ZERO
	move = move.limit_length(1.0)
	if not aim.is_finite() or aim.length_squared() < 0.01:
		aim = Vector3.FORWARD
	aim = aim.normalized()
	buttons = buttons & ALL_BITS
	emote_id = clampi(emote_id, 0, 7)


## 8 bytes: move x/y as int8, aim as 3 x int8 (quantised unit vector), buttons (low 8 bits),
## emote, buttons (high bits: INTERACT).
func to_bytes() -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(8)
	b.encode_s8(0, Quantize.f_to_s8(move.x))
	b.encode_s8(1, Quantize.f_to_s8(move.y))
	b.encode_s8(2, Quantize.f_to_s8(aim.x))
	b.encode_s8(3, Quantize.f_to_s8(aim.y))
	b.encode_s8(4, Quantize.f_to_s8(aim.z))
	b.encode_u8(5, buttons & 255)
	b.encode_u8(6, emote_id & 7)
	b.encode_u8(7, (buttons >> 8) & 255)
	return b


static func from_bytes(b: PackedByteArray) -> PlumberInput:
	var inp: PlumberInput = PlumberInput.new()
	if b.size() < 8:
		return inp
	inp.move = Vector2(Quantize.s8_to_f(b.decode_s8(0)), Quantize.s8_to_f(b.decode_s8(1)))
	inp.aim = Vector3(Quantize.s8_to_f(b.decode_s8(2)), Quantize.s8_to_f(b.decode_s8(3)), Quantize.s8_to_f(b.decode_s8(4)))
	inp.buttons = b.decode_u8(5) | (b.decode_u8(7) << 8)
	inp.emote_id = b.decode_u8(6)
	inp.sanitize()
	return inp
