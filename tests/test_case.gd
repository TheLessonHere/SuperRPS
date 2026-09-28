class_name TestCase
extends RefCounted
## Base class for tests. Any method starting with `test_` is run by run_tests.gd.

var failures: PackedStringArray = []


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("expected %s, got %s %s" % [expected, actual, message])


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append("expected true %s" % message)
