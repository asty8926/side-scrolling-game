extends GutTest
## Recorder (#40): record live play mid-session, save, replay headless.


func after_each() -> void:
	for action: StringName in InputSampler.ACTIONS:
		Input.action_release(action)


func test_record_mid_session_then_replay_matches_live() -> void:
	var driver: SimDriver = SimDriver.new()
	driver.world_seed = 9
	var recorder: ReplayRecorder = ReplayRecorder.new()
	driver.add_child(recorder)
	add_child_autofree(driver)
	for i: int in 30:
		driver.step_once()
	recorder.start()
	assert_true(recorder.is_recording())
	for i: int in 120:
		if i % 10 == 0:
			Input.action_press(&"right")
		elif i % 10 == 3:
			Input.action_release(&"right")
		driver.step_once()
	var path: String = recorder.stop_and_save()
	assert_ne(path, "", "saved")
	var replay: Replay = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Replay
	assert_not_null(replay)
	if replay == null:
		return
	assert_eq(replay.tick_count(), 120)
	var result: ReplayRunner.Result = ReplayRunner.run(replay)
	assert_true(result.ok, "\n".join(result.problems))
	assert_eq(result.final_hash, driver.world.state_hash(), "replay ends where the live game ended")
	DirAccess.remove_absolute(path)
