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


## Drops `moves[0]` and any cancel_into that pointed at it, so the saved set stays valid.
func _drop_first_move(moves: MoveSet) -> void:
	var removed: StringName = moves.moves[0].id
	moves.moves.remove_at(0)
	for move: MoveData in moves.moves:
		var kept: Array[StringName] = []
		for id: StringName in move.cancel_into:
			if id != removed:
				kept.append(id)
		move.cancel_into = kept


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


func test_a_fix_saved_in_the_same_second_is_still_picked_up() -> void:
	_reloader._snapshot_hashes()
	_save_with(func(moves: MoveSet) -> void: moves.moves[0].active = -3)
	_reloader.check_now()
	assert_push_error_count(1)
	_save_with(func(moves: MoveSet) -> void:
		moves.moves[0].active = 3
		moves.moves[0].damage_percent = 777)
	_reloader.check_now()
	assert_eq(_driver.world.characters[0].moveset.moves[0].damage_percent, 777, "content change detected")


func test_cached_loads_return_the_reloaded_data() -> void:
	_save_with(func(moves: MoveSet) -> void: moves.moves[0].damage_percent = 555)
	assert_eq(_reloader.reload_path(MOVES), [] as Array[String])
	assert_eq((load(MOVES) as MoveSet).moves[0].damage_percent, 555, "the resource cache holds the new copy")


func test_a_fighter_follows_its_move_by_id_when_moves_shift() -> void:
	var fighter: SimFighter = _driver.world.fighters[0]
	fighter.move = 1  # ranger_z2
	fighter.move_tick = 4
	_save_with(_drop_first_move)  # z2 shifts into slot 0
	assert_eq(_reloader.reload_path(MOVES), [] as Array[String])
	assert_eq(fighter.move, 0, "still playing z2, now in slot 0")
	assert_eq(fighter.move_tick, 4)


func test_a_fighter_whose_move_was_removed_stops_it() -> void:
	var fighter: SimFighter = _driver.world.fighters[0]
	fighter.move = 0  # ranger_z1
	fighter.move_tick = 3
	_save_with(_drop_first_move)
	assert_eq(_reloader.reload_path(MOVES), [] as Array[String])
	assert_eq(fighter.move, SimFighter.NO_MOVE, "z1 is gone, z2 (now in slot 0) does not take over")


func test_room_reload_redraws_the_room_and_reseats_standing_fighters() -> void:
	var view: RoomView = RoomView.new()
	add_child_autofree(view)
	view.build(_driver.world.room, _driver.world.tier_height)
	_reloader.room_view = view
	var fighter: SimFighter = _driver.world.fighters[0]
	fighter.ground = 0
	fighter.x = _driver.world.room.platforms[0].x
	var room: RoomLayout = _driver.world.room.duplicate(true) as RoomLayout
	room.platforms[0].x += 1000
	room.platforms[0].tier += 1
	var path: String = DIR + "/room.tres"
	assert_eq(ResourceSaver.save(room, path), OK)
	assert_eq(_reloader.reload_path(path), [] as Array[String])
	var world: SimWorld = _driver.world
	assert_eq(fighter.y, world.room.platforms[0].top(world.room.floor_y, world.tier_height), "stands on the new top")
	assert_almost_eq(view.platform_meshes()[0].position.x, SimUnits.to_meters(world.room.platforms[0].x), 0.001, "mesh moved")
	DirAccess.remove_absolute(path)


func test_toast_keeps_an_error_visible_after_a_later_success() -> void:
	var toast: ReloadToast = ReloadToast.new()
	add_child_autofree(toast)
	toast._on_reloaded("res://room.tres", ["bad tier"] as Array[String])
	toast._on_reloaded("res://movement.tres", [] as Array[String])
	assert_string_contains(toast.text, "room.tres NOT reloaded")
	assert_string_contains(toast.text, "Reloaded movement.tres")


func test_a_platform_moved_away_drops_its_fighter_from_the_old_height() -> void:
	var fighter: SimFighter = _driver.world.fighters[0]
	var world: SimWorld = _driver.world
	fighter.ground = 0
	fighter.x = world.room.platforms[0].x
	fighter.y = world.room.platforms[0].top(world.room.floor_y, world.tier_height)
	var old_y: int = fighter.y
	var room: RoomLayout = world.room.duplicate(true) as RoomLayout
	var center: int = (world.room.left + world.room.right) / 2
	var away: int = room.platforms[0].width + 2 * world.movement.half_width + 100
	room.platforms[0].x += away if room.platforms[0].x < center else -away
	room.platforms[0].tier += 1
	assert_eq(world.replace_static(room, world.movement, world.input_settings), [] as Array[String])
	assert_eq(fighter.ground, SimFighter.IN_AIR, "no longer supported")
	assert_eq(fighter.y, old_y, "falls from where it was")


func test_camera_params_at_the_wrong_path_are_refused() -> void:
	# A valid CameraParams file must not replace the camera unless it is the
	# path the camera is already using (e.g. a room .tres overwritten by mistake).
	var path: String = DIR + "/wrong_camera.tres"
	var fresh: CameraParams = CameraParams.new()
	assert_eq(ResourceSaver.save(fresh, path), OK)
	var camera: SideCamera = SideCamera.new()
	add_child_autofree(camera)
	camera.params = CameraParams.new()
	_reloader.camera = camera
	var problems: Array[String] = _reloader.reload_path(path)
	assert_gt(problems.size(), 0)
	assert_string_contains(problems[0], "not used by the running world")
	assert_push_error_count(1)
	DirAccess.remove_absolute(path)
