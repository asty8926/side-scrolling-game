extends SceneTree
## CI guard: loads every GDScript file of ours and exits with code 1 if any fails.
##
## Why: Godot's headless run exits with code 0 even when a script fails to parse
## (verified on 4.7.2), so a strict-typing violation ("Warning treated as error")
## would not fail CI on its own. This script makes it fail.
##
## Run: godot --headless --path . -s res://tools/check_scripts.gd
## (run `godot --headless --import` once before, so class_name types are registered.)

const SKIP_DIRS: Array[String] = ["res://addons", "res://.godot"]


func _init() -> void:
	var files: Array[String] = []
	var failures: Array[String] = []
	_collect_scripts("res://", files, failures)
	files.sort()

	for path: String in files:
		var problem: String = _check_script(path)
		if problem != "":
			failures.append("%s: %s" % [path, problem])

	print("check_scripts: %d script(s) checked, %d failure(s)." % [files.size(), failures.size()])
	for failure: String in failures:
		printerr("check_scripts: FAILED %s" % failure)
	quit(1 if failures.size() > 0 else 0)


## Fills `out` with every .gd path; a folder that cannot be read is a failure
## (otherwise its scripts would silently go unchecked).
func _collect_scripts(dir_path: String, out: Array[String], failures: Array[String]) -> void:
	for skip: String in SKIP_DIRS:
		if dir_path.trim_suffix("/") == skip:
			return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		failures.append("%s: cannot open folder (%s)" % [dir_path, error_string(DirAccess.get_open_error())])
		return
	for sub: String in dir.get_directories():
		_collect_scripts(dir_path.path_join(sub), out, failures)
	for file: String in dir.get_files():
		if file.get_extension() == "gd":
			out.append(dir_path.path_join(file))


## Returns "" when the script parses and compiles, otherwise a short reason.
func _check_script(path: String) -> String:
	var res: Resource = ResourceLoader.load(path)
	if res == null:
		return "failed to load (parse error, see the SCRIPT ERROR lines above)"
	var script: Script = res as Script
	if script == null:
		return "not a Script resource"
	if not script.can_instantiate():
		return "does not compile (see the SCRIPT ERROR lines above)"
	return ""
