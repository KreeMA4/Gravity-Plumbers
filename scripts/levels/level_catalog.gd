class_name LevelCatalog
extends RefCounted
## Every playable level: id -> display info + its data script.
## Each data script has `static func data() -> Dictionary` (see level_data/).

## Levels are added here as their data files land (milestones M5, M6, M9).
const LEVELS: Array = [
	{"id": "hub", "name": "The Rusty Pipe (Hub)", "script": "res://scripts/levels/level_data/hub.gd", "hub": true},
	{"id": "bathroom", "name": "1. Orbital Bathroom", "script": "res://scripts/levels/level_data/orbital_bathroom.gd", "par": 300.0},
	{"id": "workshop", "name": "Plumbing Workshop (test)", "script": "res://scripts/levels/level_data/workshop.gd", "par": 240.0, "debug": true},
]


static func info(level_id: String) -> Dictionary:
	for l: Variant in LEVELS:
		var d: Dictionary = l as Dictionary
		if str(d["id"]) == level_id:
			return d
	return {}


static func exists(level_id: String) -> bool:
	var i: Dictionary = info(level_id)
	return not i.is_empty() and ResourceLoader.exists(str(i["script"]))


static func load_data(level_id: String) -> Dictionary:
	var i: Dictionary = info(level_id)
	if i.is_empty() or not ResourceLoader.exists(str(i["script"])):
		return {}
	var scr: GDScript = load(str(i["script"])) as GDScript
	if scr == null:
		return {}
	var d: Variant = scr.call("data")
	if d is Dictionary:
		var out: Dictionary = d as Dictionary
		out["id"] = level_id
		out["par"] = float(i.get("par", 300.0))
		out["is_hub"] = bool(i.get("hub", false))
		return out
	return {}


## Playable story levels (for the hub console), in order.
static func story_levels() -> Array:
	var out: Array = []
	for l: Variant in LEVELS:
		var d: Dictionary = l as Dictionary
		if not bool(d.get("hub", false)) and not bool(d.get("debug", false)) and exists(str(d["id"])):
			out.append(d)
	return out
