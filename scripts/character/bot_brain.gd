class_name BotBrain
extends Node
## Scripted input for test bots (Ragdoll Playground, and the "fake remote
## player" network test). Wanders around, jumps now and then, flops
## occasionally, and grabs whatever is in front of it.

var plumber: Plumber = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _dir: Vector3 = Vector3.FORWARD
var _timer: float = 0.0
var _grab_time: float = 0.0
var _jump_time: float = 0.0
var _flop_time: float = 0.0
var frame: PlumberInput = PlumberInput.new()


func _ready() -> void:
	rng.seed = hash(name)


func _physics_process(dt: float) -> void:
	if plumber == null or not is_instance_valid(plumber):
		return
	_timer -= dt
	if _timer <= 0.0:
		_timer = rng.randf_range(1.0, 3.0)
		var up: Vector3 = plumber.local_up
		var r: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		_dir = (r - up * r.dot(up)).normalized()
		if rng.randf() < 0.3:
			_grab_time = rng.randf_range(0.5, 2.0)
		if rng.randf() < 0.35:
			_jump_time = 0.15
		if rng.randf() < 0.05:
			_flop_time = 0.1
	var bits: int = 0
	if _grab_time > 0.0:
		_grab_time -= dt
		bits |= PlumberInput.GRAB_L | PlumberInput.GRAB_R
	if _jump_time > 0.0:
		_jump_time -= dt
		bits |= PlumberInput.JUMP
	if _flop_time > 0.0:
		_flop_time -= dt
		bits |= PlumberInput.FLOP
	frame.move = Vector2(0, 0.8)
	frame.aim = _dir if _dir.length_squared() > 0.5 else plumber.facing
	frame.buttons = bits
	if not plumber.is_puppet:
		plumber.input.copy_from(frame)
