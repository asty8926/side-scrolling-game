class_name SimGuard
extends RefCounted
## Static guard for the determinism rule: scans every script under game/sim/
## for APIs that would make the simulation non-deterministic or touch nodes.
## Used by test/unit/test_sim_guard.gd (runs in CI with the other GUT tests).
##
## Comments and string literals (including multi-line triple-quoted strings)
## are blanked before matching, so docs may mention randi() safely.

const SIM_DIR: String = "res://game/sim"

## [regex, reason]. Keep the reasons short: they are printed in CI.
const RULES: Array[Array] = [
	["\\brandf\\s*\\(", "global randf(): use the world's SimRng"],
	["\\brandi\\s*\\(", "global randi(): use the world's SimRng"],
	["\\b(randf_range|randi_range|randfn|rand_from_seed|randomize|seed)\\s*\\(|\\bRandomNumberGenerator\\b", "global random: use the world's SimRng"],
	["\\bTime\\s*\\.", "wall clock (Time.*) inside the sim"],
	["\\bOS\\s*\\.", "OS.* (clock, environment) inside the sim"],
	["\\bEngine\\s*\\.", "Engine.* inside the sim"],
	["\\bInput\\s*\\.", "reading the keyboard inside the sim: use InputFrame"],
	["\\b(get_node|get_tree|get_parent|get_children|add_child)\\s*\\(", "scene-tree access inside the sim"],
	["\\$", "node path shorthand ($) inside the sim"],
	["^\\s*extends\\s+[\"']", "extend a class_name, not a script path (the guard checks the base class)"],
	["^\\s*(static\\s+)?var\\s+\\w+\\s*:\\s*(float|Vector2|Vector3|Vector4|Transform2D|Transform3D|Basis|Quaternion)\\b", "float field in sim state: use int sub-units (SimUnits)"],
	["^\\s*(static\\s+)?var\\s+\\w+\\s*:?=\\s*-?\\d+\\.\\d*", "float field in sim state: use int sub-units (SimUnits)"],
	["^\\s*(static\\s+)?var\\s+\\w+\\s*:?=\\s*(float|Vector2|Vector3|Vector4|Transform2D|Transform3D|Basis|Quaternion)\\b", "float field in sim state: use int sub-units (SimUnits)"],
]


## Returns one line per violation ("path:line: reason | code"), empty when clean.
static func scan_dir(dir_path: String = SIM_DIR) -> Array[String]:
	var problems: Array[String] = []
	var files: Array[String] = []
	_collect(dir_path, files, problems)
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
	var code_lines: PackedStringArray = strip_comments_and_strings(source).split("\n")
	var raw_lines: PackedStringArray = source.split("\n")
	for i: int in code_lines.size():
		var raw: String = raw_lines[i].strip_edges() if i < raw_lines.size() else ""
		for r: int in compiled.size():
			if compiled[r].search(code_lines[i]) != null:
				problems.append("%s:%d: %s | %s" % [path, i + 1, str(RULES[r][1]), raw])
		var base_problem: String = node_base_problem(code_lines[i])
		if base_problem != "":
			problems.append("%s:%d: %s | %s" % [path, i + 1, base_problem, raw])
	return problems


## Returns a reason when `code_line` is `extends X` and X is Node or derives
## from Node (engine classes through ClassDB, our class_name types through the
## global class list). Sim classes must derive from RefCounted.
static func node_base_problem(code_line: String) -> String:
	var regex: RegEx = RegEx.create_from_string("^\\s*extends\\s+(\\w+)")
	var found: RegExMatch = regex.search(code_line)
	if found == null:
		return ""
	var base: String = found.get_string(1)
	var native: String = native_base_of(base)
	if native == "":
		return "unknown base class %s" % base
	if native == "Node" or ClassDB.is_parent_class(native, "Node"):
		return "sim classes must extend RefCounted, not a node (%s)" % base
	return ""


## Follows class_name bases up to the first engine class. "" when unknown.
static func native_base_of(type_name: String) -> String:
	var global_bases: Dictionary[String, String] = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		global_bases[str(entry.get("class", ""))] = str(entry.get("base", ""))
	var current: String = type_name
	for depth: int in 64:
		if ClassDB.class_exists(current):
			return current
		if not global_bases.has(current):
			return ""
		current = global_bases[current]
	return ""


## Blanks comments and string contents in a whole source text, keeping the
## quotes and every newline (so line numbers still match the original).
static func strip_comments_and_strings(source: String) -> String:
	var out: String = ""
	var quote: String = ""  # active delimiter: one or three quote characters
	var in_comment: bool = false
	var i: int = 0
	var n: int = source.length()
	while i < n:
		var c: String = source[i]
		if c == "\n":
			in_comment = false
			if quote.length() == 1:
				quote = ""  # a single-line string cannot continue past its line
			out += c
			i += 1
		elif in_comment:
			i += 1
		elif quote != "":
			if c == "\\":
				i += 2
			elif source.substr(i, quote.length()) == quote:
				out += quote
				i += quote.length()
				quote = ""
			else:
				i += 1
		elif c == "#":
			in_comment = true
			i += 1
		elif c == "\"" or c == "'":
			var triple: String = c + c + c
			quote = triple if source.substr(i, 3) == triple else c
			out += quote
			i += quote.length()
		else:
			out += c
			i += 1
	return out


static func _collect(dir_path: String, out: Array[String], problems: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		problems.append("%s: cannot open folder (%s)" % [dir_path, error_string(DirAccess.get_open_error())])
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out, problems)
	for file: String in dir.get_files():
		if file.get_extension() == "gd":
			out.append(dir_path.path_join(file))
