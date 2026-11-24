class_name SimGuard
extends RefCounted
## Static guard for the determinism rule: scans every script under game/sim/
## for APIs that would make the simulation non-deterministic or touch nodes.
## Used by test/unit/test_sim_guard.gd (runs in CI with the other GUT tests).
##
## Comments and string literals are stripped before matching, so docs may
## mention randi() safely.

const SIM_DIR: String = "res://game/sim"

## [regex, reason]. Keep the reasons short: they are printed in CI.
const RULES: Array[Array] = [
	["\\brandf\\s*\\(", "global randf(): use the world's SimRng"],
	["\\brandi\\s*\\(", "global randi(): use the world's SimRng"],
	["\\brandf_range\\s*\\(|\\brandi_range\\s*\\(|\\brandomize\\s*\\(|\\bRandomNumberGenerator\\b", "global random: use the world's SimRng"],
	["\\bTime\\s*\\.", "wall clock (Time.*) inside the sim"],
	["\\bOS\\s*\\.", "OS.* (clock, environment) inside the sim"],
	["\\bEngine\\s*\\.", "Engine.* inside the sim"],
	["\\bInput\\s*\\.", "reading the keyboard inside the sim: use InputFrame"],
	["\\bget_node\\s*\\(|\\bget_tree\\s*\\(|\\bget_parent\\s*\\(|\\bget_children\\s*\\(|\\badd_child\\s*\\(", "scene-tree access inside the sim"],
	["\\$", "node path shorthand ($) inside the sim"],
	["\\bextends\\s+(Node|Node2D|Node3D|Control|CanvasItem)\\b", "sim classes must extend RefCounted, not a node"],
	["^\\s*(static\\s+)?var\\s+\\w+\\s*:\\s*(float|Vector2|Vector3|Transform2D|Transform3D|Basis|Quaternion)\\b", "float field in sim state: use int sub-units (SimUnits)"],
	["^\\s*(static\\s+)?var\\s+\\w+\\s*:?=\\s*-?\\d+\\.\\d*", "float field in sim state: use int sub-units (SimUnits)"],
]


## Returns one line per violation ("path:line: reason | code"), empty when clean.
static func scan_dir(dir_path: String = SIM_DIR) -> Array[String]:
	var problems: Array[String] = []
	var files: Array[String] = []
	_collect(dir_path, files)
	files.sort()
	for path: String in files:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			problems.append("%s: cannot read (%s)" % [path, error_string(FileAccess.get_open_error())])
			continue
		problems.append_array(scan_source(path, file.get_as_text()))
	return problems


## Scans one script's source text. Public so tests can prove each rule fires.
static func scan_source(path: String, source: String) -> Array[String]:
	var problems: Array[String] = []
	var compiled: Array[RegEx] = []
	for rule: Array in RULES:
		var regex: RegEx = RegEx.new()
		var err: Error = regex.compile(str(rule[0]))
		if err != OK:
			problems.append("%s: guard rule failed to compile: %s" % [path, str(rule[0])])
			return problems
		compiled.append(regex)
	var lines: PackedStringArray = source.split("\n")
	for i: int in lines.size():
		var code: String = strip_comments_and_strings(lines[i])
		for r: int in compiled.size():
			if compiled[r].search(code) != null:
				problems.append("%s:%d: %s | %s" % [path, i + 1, str(RULES[r][1]), lines[i].strip_edges()])
	return problems


## Removes `# comments` and the contents of "..." / '...' literals from one line.
static func strip_comments_and_strings(line: String) -> String:
	var out: String = ""
	var quote: String = ""
	var i: int = 0
	while i < line.length():
		var c: String = line[i]
		if quote != "":
			if c == "\\":
				i += 2
				continue
			if c == quote:
				quote = ""
				out += c
		elif c == "\"" or c == "'":
			quote = c
			out += c
		elif c == "#":
			break
		else:
			out += c
		i += 1
	return out


static func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("SimGuard: cannot open %s (%s)" % [dir_path, error_string(DirAccess.get_open_error())])
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.get_extension() == "gd":
			out.append(dir_path.path_join(file))
