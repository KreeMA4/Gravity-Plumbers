class_name SaveLogic
extends RefCounted
## Pure save-file logic (no nodes), so tests can check it:
## default data, version migration and sanitising whatever we loaded.

const CURRENT_VERSION: int = 3


static func default_data() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"player_name": "Plumber",
		"look": [],                     # PlumberLook bytes as an int array
		"outfits": [[], [], []],        # 3 favourite outfit slots
		"ducks": [],                    # ids of golden ducks found, e.g. "bathroom_1"
		"levels": {},                   # level_id -> {"stars": int, "best_time": float}
		"settings": default_settings(),
		"last_ip": "",
		"last_port": 24777,
	}


static func default_settings() -> Dictionary:
	return {
		"quality": "auto",              # low / medium / high / auto
		"quality_auto_done": false,
		"render_scale": 0.0,            # 0 = use the preset's value
		"shadows": true,
		"comfort_camera": false,
		"reduce_shake": false,
		"vol_master": 0.9,
		"vol_music": 0.6,
		"vol_sfx": 0.9,
		"vol_voice": 0.8,
		"left_handed": false,
		"single_grab": false,
		"button_scale": 1.0,
		"button_opacity": 0.75,
		"joystick_deadzone": 0.12,
		"look_sensitivity": 1.0,
		"haptics": true,
		"show_fps": false,
		"random_on_join": false,
		"language": "en",
		"tutorial_prompts": true,
		"hit_stop": true,
	}


## Bring an old save up to the current version, step by step.
static func migrate(data: Dictionary) -> Dictionary:
	var v: int = int(data.get("version", 1))
	if v < 2:
		# v1 had no outfits.
		data["outfits"] = [[], [], []]
		v = 2
	if v < 3:
		# v3 renamed "stars" (a flat dict) into "levels".
		var old_stars: Dictionary = data.get("stars", {}) if data.get("stars") is Dictionary else {}
		var levels: Dictionary = {}
		for k: Variant in old_stars.keys():
			levels[str(k)] = {"stars": int(old_stars[k]), "best_time": 0.0}
		data["levels"] = levels
		data.erase("stars")
		v = 3
	data["version"] = v
	return data


## Fill in missing keys and fix wrong types so the rest of the game can trust the data.
static func sanitize(raw: Variant) -> Dictionary:
	var defaults: Dictionary = default_data()
	if not (raw is Dictionary):
		return defaults
	var data: Dictionary = migrate((raw as Dictionary).duplicate(true))
	var out: Dictionary = defaults.duplicate(true)
	for key: String in defaults.keys():
		if data.has(key) and typeof(data[key]) == typeof(defaults[key]):
			out[key] = data[key]
		elif data.has(key) and key == "last_port" and (data[key] is float):
			out[key] = int(data[key])
	# Settings: same treatment per key (JSON turns ints into floats, allow that).
	var s_def: Dictionary = default_settings()
	var s_in: Dictionary = out["settings"] if out["settings"] is Dictionary else {}
	var s_out: Dictionary = s_def.duplicate()
	for key: String in s_def.keys():
		if s_in.has(key):
			var val: Variant = s_in[key]
			if typeof(val) == typeof(s_def[key]):
				s_out[key] = val
			elif (s_def[key] is float) and (val is int):
				s_out[key] = float(val)
	out["settings"] = s_out
	out["version"] = CURRENT_VERSION
	while (out["outfits"] as Array).size() < 3:
		(out["outfits"] as Array).append([])
	return out
