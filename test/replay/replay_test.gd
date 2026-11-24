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
