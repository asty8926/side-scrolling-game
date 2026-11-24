extends GutTest
## DataReloader (#44): a changed file is swapped into the running world; an
## invalid one is refused and the old data stays.

const DIR: String = "user://test_hot_reload"
const MOVES: String = DIR + "/moves.tres"

var _driver: SimDriver
var _reloader: DataReloader


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var source: MoveSet = (load(SimSetup.RANGER) as CharacterData).moveset.duplicate(true) as MoveSet
	assert_eq(ResourceSaver.save(source, MOVES), OK)
	var moves: MoveSet = ResourceLoader.load(MOVES, "", ResourceLoader.CACHE_MODE_REPLACE) as MoveSet
	var ranger: CharacterData = (load(SimSetup.RANGER) as CharacterData).duplicate() as CharacterData
	ranger.moveset = moves
	_driver = SimDriver.new()
	_driver.setup = &"empty"
	_reloader = DataReloader.new()
	_driver.add_child(_reloader)
	add_child_autofree(_driver)
	var world: SimWorld = SimSetup.create(&"test_room", 1)
	world.characters[0] = ranger
	_driver.world = world


func after_each() -> void:
	DirAccess.remove_absolute(MOVES)


func _save_with(change: Callable) -> void:
	var edited: MoveSet = ResourceLoader.load(MOVES, "", ResourceLoader.CACHE_MODE_IGNORE) as MoveSet
	change.call(edited)
	assert_eq(ResourceSaver.save(edited, MOVES), OK)


func test_changed_damage_is_used_by_the_world() -> void:
	assert_has(_reloader.watched_paths(), MOVES, "the moves file is watched")
	_save_with(func(moves: MoveSet) -> void: moves.moves[0].damage_percent = 999)
	var problems: Array[String] = _reloader.reload_path(MOVES)
	assert_eq(problems, [] as Array[String])
	assert_eq(_driver.world.characters[0].moveset.moves[0].damage_percent, 999, "next hit uses the new damage")


func test_invalid_data_keeps_the_old_values() -> void:
	var before: int = _driver.world.characters[0].moveset.moves[0].active
	_save_with(func(moves: MoveSet) -> void: moves.moves[0].active = -3)
	var problems: Array[String] = _reloader.reload_path(MOVES)
	assert_gt(problems.size(), 0, "the problem is reported")
	assert_push_error_count(1)
	assert_eq(_driver.world.characters[0].moveset.moves[0].active, before, "old data kept")


func test_watched_paths_cover_the_room_data() -> void:
	var paths: Array[String] = _reloader.watched_paths()
	assert_has(paths, SimSetup.TEST_ROOM)
	assert_has(paths, SimSetup.RANGER_MOVEMENT)
	assert_has(paths, SimSetup.INPUT_SETTINGS)


func _fire_arrow() -> void:
	var previous: int = 0
	for tick: int in 8:
		var held: int = InputFrame.X if tick == 0 else 0
		_driver.world.step([InputFrame.from_held(0, previous, held)] as Array[InputFrame])
		previous = held
	assert_eq(_driver.world.projectiles.size(), 1, "an arrow is in flight")


func test_arrow_speed_change_applies_to_an_arrow_in_flight() -> void:
	_fire_arrow()
	_save_with(func(moves: MoveSet) -> void: moves.moves[4].projectiles[0].speed = 1000)
	assert_eq(_reloader.reload_path(MOVES), [] as Array[String])
	var x_before: int = _driver.world.projectiles[0].x
	_driver.world.step([InputFrame.from_held(0, 0, 0)] as Array[InputFrame])
	assert_eq(_driver.world.projectiles[0].x - x_before, 1000, "flies at the new speed")


func test_removed_projectile_entry_drops_its_arrow_in_flight() -> void:
	_fire_arrow()
	_save_with(func(moves: MoveSet) -> void: moves.moves[4].projectiles.clear())
	assert_eq(_reloader.reload_path(MOVES), [] as Array[String])
	assert_eq(_driver.world.projectiles.size(), 0, "no arrow without data")
	_driver.world.step([InputFrame.from_held(0, 0, 0)] as Array[InputFrame])
	assert_eq(_driver.world.projectiles.size(), 0)
