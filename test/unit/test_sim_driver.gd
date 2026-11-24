extends GutTest
## SimDriver (#38): steps the world once per physics tick and exposes it.


func test_driver_steps_once_per_call_and_signals() -> void:
	var driver: SimDriver = SimDriver.new()
	driver.world_seed = 77
	add_child_autofree(driver)
	watch_signals(driver)
	assert_eq(driver.world.world_seed, 77, "world created from the exported seed")
	driver.step_once()
	driver.step_once()
	assert_eq(driver.world.tick, 2)
	assert_signal_emit_count(driver, "ticked", 2)


func test_driver_runs_in_physics_process() -> void:
	var driver: SimDriver = SimDriver.new()
	add_child_autofree(driver)
	await wait_physics_frames(5)
	assert_gte(driver.world.tick, 4, "ticks advance with physics frames")
