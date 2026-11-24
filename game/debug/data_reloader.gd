class_name DataReloader
extends Node
## Debug builds only: hot reload of the game data the sim uses.
##
## Twice a second it checks the modification time of every .tres the world
## was built from (characters, move sets, movement, room, input settings).
## A changed file is loaded fresh, validated, and swapped into the parent
## SimDriver's world between two ticks (this runs in _process, never inside
## a sim step). Invalid data keeps the previous values: the problems are
## printed with push_error and shown in a toast; the game keeps running.
## Works for Inspector saves (Cmd/Ctrl+S) and text edits alike.

## Emitted after each reload attempt (`problems` empty = applied).
signal reloaded(path: String, problems: Array[String])

## Seconds between file checks.
@export_range(0.1, 5.0, 0.1, "suffix:s") var poll_interval: float = 0.5
## Off in release exports regardless of this flag.
@export var enabled: bool = true

var _driver: SimDriver
var _mtimes: Dictionary[String, int] = {}
var _elapsed: float = 0.0


func _ready() -> void:
	_driver = get_parent() as SimDriver
	if _driver == null:
		push_error("DataReloader: must be a child of a SimDriver")
		enabled = false
	if not OS.is_debug_build():
		enabled = false
	set_process(enabled)
	if enabled:
		_snapshot_mtimes.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < poll_interval:
		return
	_elapsed = 0.0
	check_now()


## Paths of every data file the world currently uses.
func watched_paths() -> Array[String]:
	var paths: Array[String] = []
	var world: SimWorld = _driver.world
	for resource: Resource in [world.room, world.movement, world.input_settings]:
		_add_path(paths, resource)
	for data: CharacterData in world.characters:
		_add_path(paths, data)
		_add_path(paths, data.moveset)
	return paths


## Reloads every watched file whose modification time changed.
func check_now() -> void:
	for path: String in watched_paths():
		var mtime: int = FileAccess.get_modified_time(path)
		if _mtimes.has(path) and _mtimes[path] != mtime:
			_mtimes[path] = mtime
			reload_path(path)
		elif not _mtimes.has(path):
			_mtimes[path] = mtime


## Loads `path` fresh, validates it and swaps it into the world.
## Returns the problems (empty = applied).
func reload_path(path: String) -> Array[String]:
	var problems: Array[String] = []
	var fresh: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if fresh == null:
		problems.append("cannot load %s (syntax error?)" % path)
	else:
		problems = _apply(path, fresh)
	if problems.is_empty():
		# Make later loads of this path (and files that reference it) use the new data.
		fresh.take_over_path(path)
		print("DataReloader: reloaded %s" % path)
	else:
		push_error("DataReloader: %s kept its previous values: %s" % [path, "; ".join(problems)])
	reloaded.emit(path, problems)
	return problems


func _apply(path: String, fresh: Resource) -> Array[String]:
	var world: SimWorld = _driver.world
	var problems: Array[String] = []
	if fresh is RoomLayout:
		return world.replace_static(fresh as RoomLayout, world.movement, world.input_settings)
	if fresh is MovementParams:
		return world.replace_static(world.room, fresh as MovementParams, world.input_settings)
	if fresh is InputSettings:
		return world.replace_static(world.room, world.movement, fresh as InputSettings)
	var applied: bool = false
	for index: int in world.characters.size():
		var current: CharacterData = world.characters[index]
		var replacement: CharacterData = null
		if fresh is CharacterData and current.resource_path == path:
			replacement = fresh as CharacterData
		elif fresh is MoveSet and current.moveset != null and current.moveset.resource_path == path:
			replacement = current.duplicate() as CharacterData
			replacement.moveset = fresh as MoveSet
		if replacement != null:
			var character_path: String = current.resource_path
			var replace_problems: Array[String] = world.replace_character(index, replacement)
			if replace_problems.is_empty() and replacement.resource_path != character_path:
				replacement.take_over_path(character_path)
			problems.append_array(replace_problems)
			applied = true
	if not applied:
		problems.append("%s is not used by the running world" % path)
	return problems


func _snapshot_mtimes() -> void:
	for path: String in watched_paths():
		_mtimes[path] = FileAccess.get_modified_time(path)


static func _add_path(paths: Array[String], resource: Resource) -> void:
	if resource == null:
		return
	var path: String = resource.resource_path
	# Sub-resources ("file.tres::id") and unsaved resources are not files.
	if (path.begins_with("res://") or path.begins_with("user://")) and not path.contains("::") and not paths.has(path):
		paths.append(path)
