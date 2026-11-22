extends Node
## SaveData (autoload)
## -----------------------------------------------------------------------------
## Loads and saves user://save.json. Saving writes a temp file first and then
## renames it, so a crash mid-save can never leave a half-written file.
## If the file is corrupt we keep a backup copy and fall back to defaults.

signal settings_changed

const SAVE_PATH: String = "user://save.json"
const TEMP_PATH: String = "user://save.json.tmp"
const BACKUP_PATH: String = "user://save.corrupt.json"

var data: Dictionary = {}


func _ready() -> void:
	load_save()


func load_save() -> void:
	data = SaveLogic.default_data()
	if not FileAccess.file_exists(SAVE_PATH):
		GameLog.info("No save file yet, using defaults")
		return
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		GameLog.warn("Save file was corrupt; backed up and reset")
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
		return
	data = SaveLogic.sanitize(parsed)


func save() -> void:
	var f: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if f == null:
		GameLog.error("Could not write save: " + str(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var err: Error = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		GameLog.error("Save rename failed: " + str(err))


# --- Settings helpers --------------------------------------------------------

func get_setting(key: String) -> Variant:
	var s: Dictionary = data.get("settings", {})
	if s.has(key):
		return s[key]
	return SaveLogic.default_settings().get(key)


func set_setting(key: String, value: Variant) -> void:
	var s: Dictionary = data.get("settings", {})
	s[key] = value
	data["settings"] = s
	settings_changed.emit()


func setting_f(key: String) -> float:
	return float(get_setting(key))


func setting_b(key: String) -> bool:
	return bool(get_setting(key))


# --- Progress helpers --------------------------------------------------------

func has_duck(duck_id: String) -> bool:
	return (data.get("ducks", []) as Array).has(duck_id)


func add_duck(duck_id: String) -> void:
	var ducks: Array = data.get("ducks", [])
	if not ducks.has(duck_id):
		ducks.append(duck_id)
		data["ducks"] = ducks


func duck_count() -> int:
	return (data.get("ducks", []) as Array).size()


func record_level(level_id: String, stars: int, time_s: float) -> void:
	var levels: Dictionary = data.get("levels", {})
	var rec: Dictionary = levels.get(level_id, {"stars": 0, "best_time": 0.0})
	rec["stars"] = maxi(int(rec.get("stars", 0)), stars)
	var best: float = float(rec.get("best_time", 0.0))
	if best <= 0.0 or time_s < best:
		rec["best_time"] = time_s
	levels[level_id] = rec
	data["levels"] = levels
	save()


func level_stars(level_id: String) -> int:
	var levels: Dictionary = data.get("levels", {})
	var rec: Dictionary = levels.get(level_id, {})
	return int(rec.get("stars", 0))


func get_look_bytes() -> PackedByteArray:
	var arr: Array = data.get("look", [])
	var out: PackedByteArray = PackedByteArray()
	for v: Variant in arr:
		out.append(clampi(int(v), 0, 255))
	return out


func set_look_bytes(b: PackedByteArray) -> void:
	var arr: Array = []
	for v: int in b:
		arr.append(v)
	data["look"] = arr
