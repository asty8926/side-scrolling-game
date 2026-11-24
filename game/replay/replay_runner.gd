class_name ReplayRunner
extends RefCounted
## Runs a Replay headless on a fresh SimWorld and compares it to its expectations.

## Result of one run.
class Result:
	extends RefCounted
	var ok: bool = true
	var final_hash: String = ""
	var ticks: int = 0
	## SimEvent.to_text() lines, ticks relative to the world.
	var events: PackedStringArray = PackedStringArray()
	## Hashes at the replay's checkpoint ticks.
	var checkpoint_hashes: PackedStringArray = PackedStringArray()
	## Human-readable problems (empty when ok).
	var problems: Array[String] = []
	## The world after the last frame (null when the run could not start).
	var world: SimWorld


static func run(replay: Replay) -> Result:
	var result: Result = Result.new()
	var invalid: Array[String] = replay.validate()
	if not invalid.is_empty():
		result.ok = false
		result.problems = invalid
		return result
	var world: SimWorld = SimSetup.create(replay.setup, replay.world_seed)
	if world == null:
		result.ok = false
		result.problems.append("could not create setup '%s'" % replay.setup)
		return result
	if not replay.start_snapshot.is_empty() and world.restore(replay.start_snapshot) != OK:
		result.ok = false
		result.problems.append("start_snapshot does not restore (sim snapshot format changed?)")
		return result

	var next_checkpoint: int = 0
	var tick: int = 0
	for frame: InputFrame in replay.expand():
		world.step([frame] as Array[InputFrame])
		tick += 1
		for event: SimEvent in world.events:
			result.events.append(event.to_text())
		while next_checkpoint < replay.checkpoint_ticks.size() and replay.checkpoint_ticks[next_checkpoint] == tick:
			var actual: String = world.state_hash()
			result.checkpoint_hashes.append(actual)
			var expected: String = replay.checkpoint_hashes[next_checkpoint]
			if result.ok and actual != expected:
				result.ok = false
				result.problems.append("first differing checkpoint at replay tick %d: expected hash %s, got %s" % [tick, expected, actual])
			next_checkpoint += 1
	result.ticks = tick
	result.world = world
	result.final_hash = world.state_hash()
	if replay.expected_final_hash != "" and result.final_hash != replay.expected_final_hash:
		result.ok = false
		result.problems.append("final hash after %d ticks: expected %s, got %s" % [tick, replay.expected_final_hash, result.final_hash])
	if not replay.expected_events.is_empty() and result.events != replay.expected_events:
		result.ok = false
		result.problems.append("events differ:\n  expected %s\n  got      %s" % [replay.expected_events, result.events])
	return result


## Fills the replay's expectations from an actual run (used when recording).
static func bake_expectations(replay: Replay, checkpoint_every: int = 60) -> void:
	replay.checkpoint_ticks = PackedInt64Array()
	replay.checkpoint_hashes = PackedStringArray()
	replay.expected_final_hash = ""
	replay.expected_events = PackedStringArray()
	var total: int = replay.tick_count()
	for t: int in range(checkpoint_every, total + 1, checkpoint_every):
		replay.checkpoint_ticks.append(t)
		replay.checkpoint_hashes.append("")
	var first: Result = run(replay)
	replay.checkpoint_hashes = first.checkpoint_hashes
	replay.expected_final_hash = first.final_hash
	replay.expected_events = first.events
