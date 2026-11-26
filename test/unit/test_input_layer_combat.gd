extends GutTest
## Drives the same path Asty uses: InputEventKey with physical_keycode through
## Input.parse_input_event, then SimDriver.step_once() (the same method
## _physics_process calls). Earlier >>W tests only injected InputFrame into
## world.step(), so they could not catch sampler or body-collision issues.


func after_each() -> void:
	_release_all()


func _release_all() -> void:
	for key: Key in [KEY_RIGHT, KEY_LEFT, KEY_Z, KEY_X, KEY_UP]:
		_key(key, false)
	for action: StringName in InputSampler.ACTIONS:
		Input.action_release(action)


func _key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	event.echo = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _driver(setup: StringName = &"training") -> SimDriver:
	var driver: SimDriver = SimDriver.new()
	driver.setup = setup
	driver.paused = true
	add_child_autofree(driver)
	return driver


func _move_id(world: SimWorld) -> StringName:
	var move: MoveData = SimCombat.current_move(world, world.fighters[0])
	return move.id if move != null else &""


func _collect_starts(world: SimWorld, started: PackedStringArray) -> void:
	for event: SimEvent in world.events:
		if event.type == &"move_start" and event.actor == world.fighters[0].id:
			started.append(String(event.move_id))


func test_mid_run_physical_w_starts_the_slide_on_that_tick_or_the_next() -> void:
	var driver: SimDriver = _driver(&"training")
	await get_tree().process_frame
	assert_not_null(driver.world)
	# Double-tap → to start a run, then hold it.
	_key(KEY_RIGHT, true)
	await get_tree().process_frame
	driver.step_once()
	_key(KEY_RIGHT, false)
	await get_tree().process_frame
	driver.step_once()
	driver.step_once()
	_key(KEY_RIGHT, true)
	await get_tree().process_frame
	driver.step_once()
	for _i: int in 8:
		driver.step_once()
	assert_eq(driver.world.fighters[0].dash_dir, SimFighter.RIGHT, "still running")
	var tick_before: int = driver.world.tick
	var x_before: int = driver.world.fighters[0].x
	# Physical Z is W on AZERTY, mid-run.
	_key(KEY_Z, true)
	await get_tree().process_frame
	driver.step_once()
	# One more tick covers a press that lands at the end of the frame.
	if _move_id(driver.world) != &"ranger_dash_z":
		driver.step_once()
	assert_eq(_move_id(driver.world), &"ranger_dash_z", "run converts to the slide immediately")
	assert_lte(driver.world.tick - tick_before, 2, "the slide starts on the press tick or the next")
	# Hold nothing else; let the slide play (including hit-stop against the dummy).
	_key(KEY_Z, false)
	await get_tree().process_frame
	for _j: int in 40:
		driver.step_once()
	var travelled: int = driver.world.fighters[0].x - x_before
	assert_gt(travelled, 1200, "the slide still travels well over 2 CW even with the dummy in front (got %d sub)" % travelled)


func test_www_left_right_loops_from_the_keyboard() -> void:
	# ZZZ<<>Z through physical keys: the 4th kick never starts, Z1 starts again.
	var driver: SimDriver = _driver(&"training")
	await get_tree().process_frame
	var started: PackedStringArray = PackedStringArray()
	for _kick: int in 3:
		_key(KEY_Z, true)
		await get_tree().process_frame
		driver.step_once()
		_collect_starts(driver.world, started)
		_key(KEY_Z, false)
		await get_tree().process_frame
		for _wait: int in 12:
			driver.step_once()
			_collect_starts(driver.world, started)
	# After the third kick's cancel window is open, twitch turn <<>.
	_key(KEY_LEFT, true)
	await get_tree().process_frame
	driver.step_once()
	_collect_starts(driver.world, started)
	_key(KEY_LEFT, false)
	await get_tree().process_frame
	driver.step_once()
	_collect_starts(driver.world, started)
	_key(KEY_RIGHT, true)
	await get_tree().process_frame
	driver.step_once()
	_collect_starts(driver.world, started)
	_key(KEY_RIGHT, false)
	await get_tree().process_frame
	driver.step_once()
	_collect_starts(driver.world, started)
	_key(KEY_Z, true)
	await get_tree().process_frame
	driver.step_once()
	_collect_starts(driver.world, started)
	_key(KEY_Z, false)
	await get_tree().process_frame
	assert_eq(started[0], "ranger_z1")
	assert_eq(started[1], "ranger_z2")
	assert_eq(started[2], "ranger_z3")
	assert_true(started.has("ranger_z1"), "the string resets to the first kick")
	assert_false(started.has("ranger_z4"), "the 4th kick was cancelled")
	assert_eq(started[3], "ranger_z1", "the next Z after <<> is the first kick again: %s" % [started])
