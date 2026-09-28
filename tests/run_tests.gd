extends SceneTree
## Headless test runner. Runs every `test_*` method in every res://tests/test_*.gd.
## Exits with code 1 if any test fails.

const TEST_DIR := "res://tests"


func _initialize() -> void:
	var run := 0
	var failed := 0
	for file in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load(TEST_DIR.path_join(file))
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			var suite: TestCase = script.new()
			suite.call(name)
			run += 1
			if suite.failures.is_empty():
				print("  PASS  %s::%s" % [file, name])
			else:
				failed += 1
				print("  FAIL  %s::%s" % [file, name])
				for failure in suite.failures:
					print("        " + failure)
	print("\n%d run, %d failed" % [run, failed])
	quit(1 if failed > 0 else 0)
