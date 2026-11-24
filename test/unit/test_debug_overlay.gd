extends GutTest
## Debug overlay (#46) builds from a restored sim snapshot without errors and
## shows frame data, active hitboxes only on active ticks, and inputs.


func _world_at(ticks: int) -> SimWorld:
	var live: SimWorld = SimSetup.create(&"training", 1)
	var previous: int = 0
	for tick: int in ticks:
		var held: int = InputFrame.Z if tick == 0 else 0
		live.step([InputFrame.from_held(0, previous, held)] as Array[InputFrame])
		previous = held
	var restored: SimWorld = SimSetup.create(&"training", 1)
	assert_eq(restored.restore(live.snapshot()), OK)
	return restored


func _overlay() -> DebugOverlay:
	var overlay: DebugOverlay = DebugOverlay.new()
	add_child_autofree(overlay)
	return overlay


func test_active_tick_shows_one_hitbox_and_frame_data() -> void:
	var overlay: DebugOverlay = _overlay()
	var world: SimWorld = _world_at(6)  # ticks 0..5 simulated: z1 move tick 5 is active
	overlay.refresh(world)
	assert_eq(overlay.drawn_hitboxes, 1)
	var text: String = DebugOverlay.describe(world, false, 60.0)
	assert_string_contains(text, "ranger_z1  frame 5/22 ACTIVE")
	assert_string_contains(text, "[startup 5 | active 3 | recovery 14]")
	assert_string_contains(text, "cancel 8-19 closed")


func test_startup_tick_draws_no_hitbox() -> void:
	var overlay: DebugOverlay = _overlay()
	overlay.refresh(_world_at(3))
	assert_eq(overlay.drawn_hitboxes, 0, "hitboxes only on active ticks")


func test_input_row_uses_the_keyboard_label() -> void:
	var world: SimWorld = _world_at(6)
	var row: String = DebugOverlay.input_row(world.histories[0], DebugOverlay.INPUT_COLUMNS)
	assert_string_contains(row, KeyLabel.for_action(&"attack_z"), "the physical Z key shown with its label (W on AZERTY)")
	assert_eq(row.split(" ").size(), 6, "one column per stored frame, up to 20")


func test_paused_state_is_shown() -> void:
	assert_string_contains(DebugOverlay.describe(_world_at(1), true, 60.0), "PAUSED")


func test_driver_pause_and_step() -> void:
	var driver: SimDriver = SimDriver.new()
	driver.setup = &"training"
	add_child_autofree(driver)
	driver.paused = true
	var before: int = driver.world.tick
	driver._physics_process(0.016)
	assert_eq(driver.world.tick, before, "paused: no sim step")
	var step: InputEventAction = InputEventAction.new()
	step.action = &"debug_step"
	step.pressed = true
	driver._unhandled_input(step)
	driver._physics_process(0.016)
	assert_eq(driver.world.tick, before + 1, "F3 steps exactly one tick")
	driver._physics_process(0.016)
	assert_eq(driver.world.tick, before + 1, "and stays paused")


func test_arrow_in_flight_is_drawn_from_a_restored_snapshot() -> void:
	var live: SimWorld = SimSetup.create(&"training", 1)
	live.fighters[1].x += 8000  # far: the arrow is still flying
	var previous: int = 0
	for tick: int in 10:
		var held: int = InputFrame.X if tick == 0 else 0
		live.step([InputFrame.from_held(0, previous, held)] as Array[InputFrame])
		previous = held
	var restored: SimWorld = SimSetup.create(&"training", 1)
	assert_eq(restored.restore(live.snapshot()), OK)
	var overlay: DebugOverlay = _overlay()
	overlay.refresh(restored)
	assert_eq(overlay.drawn_hitboxes, 1, "the arrow (x1 has no melee hitbox)")
	assert_string_contains(DebugOverlay.describe(restored, false, 60.0), "arrows in flight: 1")
