extends ReplayTest
## Moves as data (#43): ZZZZ / XXXX strings on the training setup (ranger at
## the spawn, a static dummy hurtbox 1 m in front). Frame data comes from
## data/characters/ranger_moves.tres; the expected ticks below follow it.

const Z: int = InputFrame.Z
const X: int = InputFrame.X
const R: int = InputFrame.RIGHT


func _run(replay: Replay) -> ReplayRunner.Result:
	var result: ReplayRunner.Result = ReplayRunner.run(replay)
	assert_true(result.ok, "\n".join(result.problems))
	return result


func _mash(button: int, every: int, until: int) -> Dictionary[int, int]:
	var presses: Dictionary[int, int] = {}
	for tick: int in range(0, until + 1, every):
		presses[tick] = button
	return presses


func test_zzzz_mashed_hits_four_times_at_expected_ticks() -> void:
	var result: ReplayRunner.Result = _run(tapped(&"training", 120, _mash(Z, 6, 30)))
	var hits: PackedStringArray = events_of(result, "hit")
	assert_eq(hits.size(), 4, "exactly 4 hits: %s" % [hits])
	var expected: PackedStringArray = PackedStringArray([
		"5:hit:1:2:ranger_z1:damage=163:kd=15",
		"13:hit:1:2:ranger_z2:damage=201:kd=15",
		"22:hit:1:2:ranger_z3:damage=249:kd=20",
		"33:hit:1:2:ranger_z4:damage=339:kd=40",
	])
	assert_eq(hits, expected, "early presses are buffered into each cancel window")


func test_late_third_press_ends_the_string_after_two() -> void:
	# z1 at 0, z2 starts at 8 (press at 6), z2's window closes at tick 28 and it
	# ends at 31: a press at 29 is too late and does not restart the string.
	var result: ReplayRunner.Result = _run(tapped(&"training", 90, {0: Z, 6: Z, 29: Z}))
	var starts: PackedStringArray = events_of(result, "move_start")
	assert_eq(starts, PackedStringArray(["0:move_start:1:0:ranger_z1", "8:move_start:1:0:ranger_z2"]))
	assert_eq(events_of(result, "hit").size(), 2)


func test_press_after_the_string_ends_starts_it_again() -> void:
	var result: ReplayRunner.Result = _run(tapped(&"training", 90, {0: Z, 30: Z}))
	var starts: PackedStringArray = events_of(result, "move_start")
	assert_eq(starts.size(), 2)
	assert_eq(starts[1], "30:move_start:1:0:ranger_z1", "z1 (22 ticks) is over, a fresh press starts a new string")


func test_xxxx_plays_the_arrow_string() -> void:
	var result: ReplayRunner.Result = _run(tapped(&"training", 160, _mash(X, 6, 60)))
	var moves: PackedStringArray = PackedStringArray()
	for line: String in events_of(result, "hit"):
		moves.append(line.split(":")[4])
	assert_eq(moves, PackedStringArray(["ranger_x1", "ranger_x2", "ranger_x3", "ranger_x3", "ranger_x4"]), "x3 shoots two arrows")


func test_no_walking_during_a_move() -> void:
	var result: ReplayRunner.Result = _run(tapped(&"training", 10, {0: Z}, R))
	assert_eq(result.world.fighters[0].x, 0, "holding right during the kick does not walk")


func test_each_hitbox_hits_a_target_once_per_activation() -> void:
	var result: ReplayRunner.Result = _run(tapped(&"training", 30, {0: Z}))
	assert_eq(events_of(result, "hit").size(), 1, "3 active ticks, one hit")


func test_validator_explains_an_active_range_outside_the_move() -> void:
	var move: MoveData = MoveData.new()
	move.id = &"broken"
	var box: HitboxData = HitboxData.new()
	box.from_tick = 5
	box.to_tick = 40
	move.hitboxes.append(box)
	var problems: Array[String] = move.validate()
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "outside the move")


func test_ranger_moves_are_valid_and_editable_resources() -> void:
	var ranger: CharacterData = load(SimSetup.RANGER) as CharacterData
	assert_eq(ranger.validate(), [] as Array[String])
	assert_eq(ranger.moveset.moves.size(), 8, "ZZZZ and XXXX")
	var bad: MoveSet = ranger.moveset.duplicate(true) as MoveSet
	bad.moves[0].cancel_into = [&"nope"] as Array[StringName]
	assert_string_contains("; ".join(bad.validate()), "cancel_into 'nope' does not exist")


func test_invalid_character_is_refused_with_a_message() -> void:
	var world: SimWorld = SimWorld.new(1)
	var data: CharacterData = CharacterData.new()
	assert_eq(world.add_character(data), -1)
	assert_push_error_count(1)
