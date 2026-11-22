class_name TestCase
extends RefCounted
## Base class for the tiny test framework. A test file extends TestCase and
## defines methods named test_something(). Use the check_* helpers inside.

var failures: PackedStringArray = PackedStringArray()
var checks: int = 0
var current_test: String = ""


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [current_test, msg])


func check_eq(a: Variant, b: Variant, msg: String) -> void:
	check(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])


func check_near(a: float, b: float, msg: String, eps: float = 0.001) -> void:
	check(absf(a - b) <= eps, "%s (got %f, expected %f)" % [msg, a, b])


func check_vec(a: Vector3, b: Vector3, msg: String, eps: float = 0.01) -> void:
	check(a.distance_to(b) <= eps, "%s (got %s, expected %s)" % [msg, str(a), str(b)])
