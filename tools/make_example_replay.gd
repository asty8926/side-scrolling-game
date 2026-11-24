extends SceneTree
## Regenerates test/replay/fixtures/example_scripted_10s.tres: 10 s (600 ticks)
## of scripted "play" (walks, double taps, jumps, attacks) on the test room,
## with baked hashes. Run only when sim rules change on purpose:
##   godot --headless -s res://tools/make_example_replay.gd

const PATH: String = "res://test/replay/fixtures/example_scripted_10s.tres"


func _init() -> void:
	var replay: Replay = Replay.new()
	replay.world_seed = 2026
	replay.setup = &"test_room"
	replay.version_tag = "scripted fixture"
	var previous: int = 0
	for t: int in 600:
		var held: int = 0
		var phase: int = t % 120
		if phase < 30:
			held |= InputFrame.RIGHT
		elif phase >= 34 and phase < 60:
			held |= InputFrame.RIGHT  # second tap: a double tap (dash) at tick 34
		elif phase >= 70 and phase < 74:
			held |= InputFrame.UP
		if t % 20 == 10:
			held |= InputFrame.Z
		var frame: InputFrame = InputFrame.from_held(0, previous, held)
		replay.append_frame(frame)
		previous = held
	if not ReplayRunner.bake_expectations(replay):
		push_error("make_example_replay: baking failed, nothing saved")
		quit(1)
		return
	var err: Error = ResourceSaver.save(replay, PATH)
	if err != OK:
		push_error("make_example_replay: cannot save %s: %s" % [PATH, error_string(err)])
		quit(1)
		return
	print("make_example_replay: wrote %s (%d ticks, final hash %s)" % [PATH, replay.tick_count(), replay.expected_final_hash])
	quit(0)
