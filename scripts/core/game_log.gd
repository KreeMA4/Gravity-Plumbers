class_name GameLog
extends RefCounted
## Tiny logger. Prints to the Godot output AND appends to user://logs/game.log
## so you can read what happened after the game closes (handy on a phone).
## Godot's own engine log is also written to user://logs/godot.log
## (enabled in project.godot -> debug/file_logging).

const LOG_DIR: String = "user://logs"
const LOG_PATH: String = "user://logs/game.log"
const MAX_LOG_BYTES: int = 512 * 1024

static var _file: FileAccess = null


static func _ensure_open() -> void:
	if _file != null:
		return
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	# Start a fresh log if the old one is getting big.
	if FileAccess.file_exists(LOG_PATH):
		var old: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ)
		var too_big: bool = old != null and old.get_length() > MAX_LOG_BYTES
		old = null
		if too_big:
			DirAccess.remove_absolute(LOG_PATH)
	if FileAccess.file_exists(LOG_PATH):
		_file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		if _file != null:
			_file.seek_end()
	else:
		_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)


static func _write(level: String, msg: String) -> void:
	var line: String = "[%s] %s: %s" % [Time.get_time_string_from_system(), level, msg]
	_ensure_open()
	if _file != null:
		_file.store_line(line)
		_file.flush()


static func info(msg: String) -> void:
	print(msg)
	_write("INFO", msg)


static func warn(msg: String) -> void:
	# push_warning shows in the Debugger tab; we keep game warnings as plain
	# prints so a healthy session shows zero engine warnings.
	print("WARNING: " + msg)
	_write("WARN", msg)


static func error(msg: String) -> void:
	push_error(msg)
	_write("ERROR", msg)
