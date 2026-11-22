class_name TestRunner
extends RefCounted
## Runs every test file listed in TEST_FILES and collects the results.
## Used by tests/run_all.gd (headless, command line) and by the in-game
## "Run Tests" debug screen (so you can run tests on the phone too).

const TEST_FILES: Array = [
	"res://tests/save_test.gd",
	"res://tests/gravity_test.gd",
	"res://tests/work_order_test.gd",
	"res://tests/room_code_test.gd",
	"res://tests/net_codec_test.gd",
	"res://tests/look_test.gd",
	"res://tests/joystick_test.gd",
]


## Returns {"passed": int, "failed": int, "lines": PackedStringArray}
static func run_all() -> Dictionary:
	var lines: PackedStringArray = PackedStringArray()
	var passed: int = 0
	var failed: int = 0
	for path: Variant in TEST_FILES:
		var scr: GDScript = load(str(path)) as GDScript
		if scr == null:
			lines.append("FAIL could not load " + str(path))
			failed += 1
			continue
		var tc: TestCase = scr.new() as TestCase
		for m: Dictionary in tc.get_method_list():
			var mname: String = str(m.get("name", ""))
			if not mname.begins_with("test_"):
				continue
			tc.current_test = mname
			var before: int = tc.failures.size()
			tc.call(mname)
			if tc.failures.size() == before:
				passed += 1
				lines.append("ok   %s.%s" % [str(path).get_file().get_basename(), mname])
			else:
				failed += 1
				for i: int in range(before, tc.failures.size()):
					lines.append("FAIL " + tc.failures[i])
	lines.append("%d passed, %d failed" % [passed, failed])
	return {"passed": passed, "failed": failed, "lines": lines}
