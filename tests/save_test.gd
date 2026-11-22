extends TestCase
## Save-file migration and sanitising.


func test_defaults_are_current_version() -> void:
	var d: Dictionary = SaveLogic.default_data()
	check_eq(int(d["version"]), SaveLogic.CURRENT_VERSION, "default version")


func test_migrate_v1() -> void:
	var v1: Dictionary = {"version": 1, "player_name": "Bob", "stars": {"bathroom": 2}}
	var out: Dictionary = SaveLogic.sanitize(v1)
	check_eq(str(out["player_name"]), "Bob", "name kept")
	check_eq(int(out["version"]), SaveLogic.CURRENT_VERSION, "version bumped")
	check(out["levels"] is Dictionary and (out["levels"] as Dictionary).has("bathroom"), "stars migrated into levels")
	check_eq((out["outfits"] as Array).size(), 3, "three outfit slots")


func test_garbage_falls_back() -> void:
	var out: Dictionary = SaveLogic.sanitize("not a dictionary")
	check_eq(str(out["player_name"]), "Plumber", "defaults on garbage")
	var out2: Dictionary = SaveLogic.sanitize({"player_name": 42, "settings": {"vol_music": "loud"}})
	check_eq(str(out2["player_name"]), "Plumber", "wrong type replaced")
	check_near(float((out2["settings"] as Dictionary)["vol_music"]), 0.6, "bad setting replaced")


func test_json_ints_become_floats() -> void:
	# JSON has no int/float distinction; a whole-number volume must still load.
	var out: Dictionary = SaveLogic.sanitize({"settings": {"vol_music": 1}})
	check_near(float((out["settings"] as Dictionary)["vol_music"]), 1.0, "int volume accepted")
