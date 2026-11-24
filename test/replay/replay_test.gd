class_name ReplayTest
extends GutTest
## Base for replay tests. Template (see test_example_replay.gd):
##
##   extends ReplayTest
##   func test_my_move() -> void:
##       assert_replay("res://test/replay/fixtures/my_move.tres")


## Loads a replay fixture, runs it headless and fails with a readable message
## (expected vs actual hash, first differing checkpoint tick) on any mismatch.
func assert_replay(path: String) -> ReplayRunner.Result:
	var replay: Replay = load(path) as Replay
	assert_not_null(replay, "replay fixture loads: %s" % path)
	if replay == null:
		return null
	var result: ReplayRunner.Result = ReplayRunner.run(replay)
	assert_true(result.ok, "%s:\n%s" % [path, "\n".join(result.problems)])
	return result


## Builds a replay from press timings: `presses` maps a tick to the held mask
## for that one tick (all other ticks hold `base`). Ticks are 0-based.
static func tapped(setup: StringName, total_ticks: int, presses: Dictionary[int, int], base: int = 0) -> Replay:
	var replay: Replay = Replay.new()
	replay.setup = setup
	replay.world_seed = 1
	var previous: int = 0
	for tick: int in total_ticks:
		var held: int = base | presses.get(tick, 0)
		replay.append_frame(InputFrame.from_held(0, previous, held))
		previous = held
	return replay


## Only the events of `type`, as text lines.
static func events_of(result: ReplayRunner.Result, type: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for line: String in result.events:
		if line.split(":")[1] == type:
			out.append(line)
	return out
