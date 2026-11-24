extends ReplayTest
## Example replay test (#40): the committed 10 s fixture must reproduce its
## baked hashes. Regenerate on purpose with tools/make_example_replay.gd.

const FIXTURE: String = "res://test/replay/fixtures/example_scripted_10s.tres"


func test_fixture_reproduces_its_hashes() -> void:
	var result: ReplayRunner.Result = assert_replay(FIXTURE)
	if result != null:
		assert_eq(result.ticks, 600, "10 s at 60 ticks/s")


func test_recorded_keyboard_session_replays_identically() -> void:
	var path: String = "res://test/replay/fixtures/recorded_keyboard_10s.tres"
	var result: ReplayRunner.Result = assert_replay(path)
	if result != null:
		assert_gte(result.ticks, 600, "at least 10 s recorded with F9 and real keyboard events")


func test_two_runs_give_the_same_final_hash() -> void:
	var replay: Replay = load(FIXTURE) as Replay
	assert_eq(ReplayRunner.run(replay).final_hash, ReplayRunner.run(replay).final_hash)


func test_changed_behaviour_fails_with_a_readable_message() -> void:
	var replay: Replay = (load(FIXTURE) as Replay).duplicate(true) as Replay
	# Simulate "a sim rule changed after tick 120": change one input there.
	var frames: Array[InputFrame] = replay.expand()
	frames[150] = InputFrame.new(0, InputFrame.X, InputFrame.X)
	var edited: Replay = replay.duplicate(true) as Replay
	edited.frames = PackedInt64Array()
	for frame: InputFrame in frames:
		edited.append_frame(frame)
	var result: ReplayRunner.Result = ReplayRunner.run(edited)
	assert_false(result.ok)
	var message: String = "\n".join(result.problems)
	assert_string_contains(message, "first differing checkpoint at replay tick 180")
	assert_string_contains(message, "expected hash")
	assert_string_contains(message, "final hash after 600 ticks: expected")


func test_invalid_replay_is_reported_not_run() -> void:
	var replay: Replay = Replay.new()
	replay.frames = PackedInt64Array([1])
	replay.setup = &"nope"
	var result: ReplayRunner.Result = ReplayRunner.run(replay)
	assert_false(result.ok)
	assert_eq(result.problems.size(), 2, "\n".join(result.problems))


func test_pack_round_trip_and_run_length() -> void:
	var replay: Replay = Replay.new()
	var frame: InputFrame = InputFrame.new(0, InputFrame.AWAKEN | InputFrame.Z, InputFrame.Z, InputFrame.LEFT)
	replay.append_frame(frame)
	replay.append_frame(frame)
	replay.append_frame(InputFrame.new())
	assert_eq(replay.frames.size(), 4, "two runs")
	assert_eq(replay.tick_count(), 3)
	var back: InputFrame = replay.expand()[1]
	assert_eq([back.held, back.pressed, back.released], [frame.held, frame.pressed, frame.released])
