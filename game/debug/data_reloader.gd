class_name DataReloader
extends Node
## Debug builds only: hot reload of the game data the sim uses.
##
## Twice a second it checks the content (MD5) of every .tres the world
## was built from (characters, move sets, movement, room, input settings)
## and, when assigned, the camera params file (view only).
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
## Redrawn after a room, movement, or camera-params reload.
@export var room_view: RoomView
## View camera; its CameraParams file is watched and applied on reload.
@export var camera: SideCamera

var _driver: SimDriver
## Content fingerprints: file modification times only have 1 s precision,
## so a fix saved in the same second as a rejected edit would be missed.
var _hashes: Dictionary[String, String] = {}
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
		_snapshot_hashes.call_deferred()


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
	if camera != null:
		_add_path(paths, camera.params)
	return paths


## Reloads every watched file whose content changed.
func check_now() -> void:
	for path: String in watched_paths():
		var digest: String = FileAccess.get_md5(path)
		if _hashes.has(path) and _hashes[path] != digest:
			_hashes[path] = digest
			reload_path(path)
		elif not _hashes.has(path):
			_hashes[path] = digest


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
		# Make later loads of this path use the new data. The fresh copy already
		# carries `path` without being cached, and take_over_path does nothing
		# when the path is unchanged, so clear it first.
		fresh.resource_path = ""
		fresh.take_over_path(path)
		if (fresh is RoomLayout or fresh is MovementParams or fresh is CameraParams) and room_view != null:
			room_view.build(_driver.world.room, _driver.world.tier_height)
		print("DataReloader: reloaded %s" % path)
	else:
		push_error("DataReloader: %s kept its previous values: %s" % [path, "; ".join(problems)])
	reloaded.emit(path, problems)
	return problems


func _apply(path: String, fresh: Resource) -> Array[String]:
	var world: SimWorld = _driver.world
	var problems: Array[String] = []
	if fresh is CameraParams:
		var cam_problems: Array[String] = (fresh as CameraParams).validate()
		if not cam_problems.is_empty():
			return cam_problems
		if camera != null:
			camera.params = fresh as CameraParams
			camera.apply_params()
		if room_view != null:
			room_view.params = fresh as CameraParams
		return []
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


func _snapshot_hashes() -> void:
	for path: String in watched_paths():
		_hashes[path] = FileAccess.get_md5(path)


static func _add_path(paths: Array[String], resource: Resource) -> void:
	if resource == null:
		return
	var path: String = resource.resource_path
	# Sub-resources ("file.tres::id") and unsaved resources are not files.
	if (path.begins_with("res://") or path.begins_with("user://")) and not path.contains("::") and not paths.has(path):
		paths.append(path)
