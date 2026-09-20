extends RefCounted

## Shared assertion helpers for the headless content verification scripts that
## tools/verify_content.ps1 runs through Godot.

var checks := 0
var failures: Array[String] = []


func check(condition: bool, message: String) -> bool:
	checks += 1
	if condition:
		return true
	failures.append(message)
	printerr("  FAIL: %s" % message)
	return false


func check_eq(actual: Variant, expected: Variant, message: String) -> bool:
	return check(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func check_float(actual: float, expected: float, message: String) -> bool:
	return check(is_equal_approx(actual, expected), "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func check_resource_path(path: String, message: String) -> bool:
	if path.is_empty():
		return check(false, "%s (no path configured)" % message)
	if not check(FileAccess.file_exists(path), "%s (missing file %s)" % [message, path]):
		return false
	return check(ResourceLoader.exists(path), "%s (cannot load %s)" % [message, path])


func collect_files(dir_path: String, suffix: String, out: Array) -> void:
	var directory := DirAccess.open(dir_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if directory.current_is_dir():
			if not entry_name.begins_with("."):
				collect_files(dir_path.path_join(entry_name), suffix, out)
		elif entry_name.ends_with(suffix):
			out.append(dir_path.path_join(entry_name))
		entry_name = directory.get_next()
	directory.list_dir_end()


func report(title: String) -> int:
	if failures.is_empty():
		print("PASS %s (%d checks)" % [title, checks])
		return 0
	printerr("FAIL %s (%d of %d checks failed)" % [title, failures.size(), checks])
	for failure in failures:
		printerr("  - %s" % failure)
	return 1
