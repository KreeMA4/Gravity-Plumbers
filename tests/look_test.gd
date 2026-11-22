extends TestCase
## Customisation: randomizer respects locks and unlocks; host clamps bad data.


func test_randomize_respects_locks() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var look: PlumberLook = PlumberLook.default_for(1)
	var before: PackedByteArray = look.to_bytes()
	var keep_head: int = look.get_v("headgear")
	var keep_skin: int = look.get_v("skin")
	for i: int in 30:
		look.randomize_look(rng, ["headgear", "colors"], 0)
		check_eq(look.get_v("headgear"), keep_head, "locked headgear unchanged")
		check_eq(look.get_v("skin"), keep_skin, "locked colours unchanged")
	check(look.to_bytes() != before, "something else changed")


func test_randomize_respects_unlocks() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var look: PlumberLook = PlumberLook.new()
	for i: int in 200:
		look.randomize_look(rng, [], 0)
		for f: Variant in PlumberLook.FIELDS:
			var field: String = str(f)
			check(PlumberLook.is_unlocked(field, look.get_v(field), 0), "never picks a locked %s" % field)


func test_colors_only() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var look: PlumberLook = PlumberLook.default_for(0)
	var hat: int = look.get_v("headgear")
	var build: int = look.get_v("build")
	look.randomize_look(rng, [], 99, true)
	check_eq(look.get_v("headgear"), hat, "colours-only keeps hat")
	check_eq(look.get_v("build"), build, "colours-only keeps build")


func test_unlock_share() -> void:
	# At least 60% of all options are unlocked from the start.
	var total: int = 0
	var open: int = 0
	for f: Variant in PlumberLook.OPTIONS.keys():
		var field: String = str(f)
		for i: int in (PlumberLook.OPTIONS[field] as Array).size():
			total += 1
			if PlumberLook.is_unlocked(field, i, 0):
				open += 1
	check(float(open) / float(total) >= 0.6, "%d of %d unlocked at start" % [open, total])


func test_option_counts() -> void:
	for f: String in ["build", "eyes", "nose", "mustache", "brows", "headgear", "backpack", "pattern", "boots", "gloves"]:
		check((PlumberLook.OPTIONS[f] as Array).size() >= 6, "%s has at least 6 variants" % f)
