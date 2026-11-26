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
	assert_string_contains(problems[0], "outside the move's active phase (5..7)")


func test_validator_rejects_hits_before_startup_ends_and_bad_windows() -> void:
	var move: MoveData = (load(SimSetup.RANGER) as CharacterData).moveset.moves[0].duplicate(true) as MoveData
	move.startup = 10  # its hitbox still says ticks 5..7
	assert_string_contains("; ".join(move.validate()), "active phase (10..12)")
	var window: MoveData = (load(SimSetup.RANGER) as CharacterData).moveset.moves[0].duplicate(true) as MoveData
	window.cancel_from = -1
	assert_string_contains("; ".join(window.validate()), "cancel window")
	var many: MoveData = (load(SimSetup.RANGER) as CharacterData).moveset.moves[0].duplicate(true) as MoveData
	for i: int in MoveData.MAX_HITBOXES:
		many.hitboxes.append(many.hitboxes[0])
	assert_string_contains("; ".join(many.validate()), "at most %d per move" % MoveData.MAX_HITBOXES)


func test_ranger_moves_are_valid_and_editable_resources() -> void:
	var ranger: CharacterData = load(SimSetup.RANGER) as CharacterData
	assert_eq(ranger.validate(), [] as Array[String])
	assert_eq(ranger.moveset.moves.size(), 11, "ZZZZ, XXXX and >>Z / >>ZX / >>ZZ")
	var bad: MoveSet = ranger.moveset.duplicate(true) as MoveSet
	bad.moves[0].cancel_into = [&"nope"] as Array[StringName]
	assert_string_contains("; ".join(bad.validate()), "cancel_into 'nope' does not exist")


func test_invalid_character_is_refused_with_a_message() -> void:
	var world: SimWorld = SimWorld.new(1)
	var data: CharacterData = CharacterData.new()
	assert_eq(world.add_character(data), -1)
	assert_push_error_count(1)


func _arrow_world(dummy_x: int) -> SimWorld:
	var world: SimWorld = SimSetup.create(&"training", 1)
	world.fighters[1].x = dummy_x
	return world


func _press_x_then_wait(world: SimWorld, ticks: int) -> Array[String]:
	var lines: Array[String] = []
	var previous: int = 0
	for tick: int in ticks:
		var held: int = X if tick == 0 else 0
		world.step([InputFrame.from_held(0, previous, held)] as Array[InputFrame])
		previous = held
		for event: SimEvent in world.events:
			lines.append(event.to_text())
	return lines


func test_arrow_is_a_projectile_that_travels_to_the_dummy() -> void:
	var shot: ProjectileData = (load(SimSetup.RANGER) as CharacterData).moveset.moves[4].projectiles[0]
	# Spawns at x = 400 on move tick 6, moves `speed` per tick from tick 7 and
	# hits once its front reaches the dummy's hurtbox (dummy 6 m away).
	var world: SimWorld = _arrow_world(6000)
	var lines: Array[String] = _press_x_then_wait(world, 40)
	var fired: int = -1
	var hit_tick: int = -1
	for line: String in lines:
		if line.contains(":projectile:") and fired < 0:
			fired = int(line.split(":")[0])
		if line.contains(":hit:") and hit_tick < 0:
			hit_tick = int(line.split(":")[0])
	assert_eq(fired, 6, "fired on the spawn tick")
	var hurt_left: int = 6000 - 700 / 2
	var ticks_needed: int = ceili(float(hurt_left - shot.width / 2 - shot.offset_x) / float(shot.speed))
	assert_eq(hit_tick, fired + ticks_needed, "flight time = distance / speed")
	assert_eq(world.projectiles.size(), 0, "the arrow is gone after its hit")


func test_arrow_fired_away_from_the_dummy_misses_and_expires() -> void:
	var world: SimWorld = _arrow_world(-3000)  # behind the ranger, who faces right
	var lines: Array[String] = _press_x_then_wait(world, 60)
	var joined: String = "\n".join(lines)
	assert_false(joined.contains(":hit:"), "no hit behind")
	assert_true(joined.contains(":projectile_end:"), "the arrow ends (wall or lifetime)")
	assert_eq(world.projectiles.size(), 0)


func test_snapshot_keeps_an_arrow_in_flight() -> void:
	var world: SimWorld = _arrow_world(9000)
	_press_x_then_wait(world, 10)
	assert_eq(world.projectiles.size(), 1, "one arrow in flight")
	var copy: SimWorld = SimSetup.create(&"training", 1)
	assert_eq(copy.restore(world.snapshot()), OK)
	assert_eq(copy.state_hash(), world.state_hash())
	_press_x_then_wait(world, 30)
	_press_x_then_wait(copy, 30)
	assert_eq(copy.state_hash(), world.state_hash(), "same future from the snapshot")


func test_projectile_validator() -> void:
	var move: MoveData = (load(SimSetup.RANGER) as CharacterData).moveset.moves[4].duplicate(true) as MoveData
	move.projectiles[0].spawn_tick = 0
	assert_string_contains("; ".join(move.validate()), "spawn_tick 0 is outside the move's active phase")
	move.projectiles[0].spawn_tick = 6
	move.projectiles[0].speed = 0
	assert_string_contains("; ".join(move.validate()), "speed")


func test_projectile_view_draws_arrows_in_flight() -> void:
	var driver: SimDriver = SimDriver.new()
	driver.setup = &"training"
	add_child_autofree(driver)
	driver.world.fighters[1].x = 9000
	var view: ProjectileView = ProjectileView.new()
	view.driver = driver
	add_child_autofree(view)
	_press_x_then_wait(driver.world, 10)
	view._on_ticked(10)
	assert_eq(view.drawn_count(), 1, "one arrow mesh")
	_press_x_then_wait(driver.world, 40)
	view._on_ticked(50)
	assert_eq(view.drawn_count(), 0, "removed after the hit")


func test_fast_arrow_does_not_pass_through_a_target() -> void:
	var world: SimWorld = _arrow_world(2000)
	# A deep copy, so the shared ranger data loaded by other tests is untouched.
	world.characters[0] = world.characters[0].duplicate(true) as CharacterData
	world.characters[0].moveset.moves[4].projectiles[0].speed = 3000
	var joined: String = "\n".join(_press_x_then_wait(world, 20))
	assert_string_contains(joined, ":hit:1:2:ranger_x1:", "the swept box still hits the dummy")


func test_arrow_overlapping_two_targets_hits_the_lower_id() -> void:
	# Pushboxes now separate overlapping fighters, so two dummies cannot sit
	# in the arrow's spawn box without also overlapping the shooter. Fly the
	# arrow out, then place both hurtboxes on it (centers 650 apart, so the
	# pushboxes do not touch; both already overlap the arrow).
	var world: SimWorld = _arrow_world(9000)
	_press_x_then_wait(world, 10)
	assert_eq(world.projectiles.size(), 1)
	var arrow_x: int = world.projectiles[0].x
	var third: int = world.add_fighter(SimFighter.NO_PLAYER, world.fighters[1].character)
	assert_gt(third, 0)
	world.fighters[1].x = arrow_x - 325  # id 2
	world.fighters[2].x = arrow_x + 325  # id 3
	world.step([InputFrame.from_held(0, 0, 0)] as Array[InputFrame])
	var lines: PackedStringArray = PackedStringArray()
	for event: SimEvent in world.events:
		lines.append(event.to_text())
	var joined: String = "\n".join(lines)
	assert_string_contains(joined, ":hit:1:2:ranger_x1:", "both touched at once: the lower id is hit")
	assert_false(joined.contains(":hit:1:3:"), "one target per arrow")


func test_arrow_expires_around_seven_metres() -> void:
	# [ours] lifetime 17 ticks at 400 sub/tick from a spawn 400 in front: the
	# arrow disappears 7.2 m from the ranger and must not still be in flight at 12 m.
	var shot: ProjectileData = (load(SimSetup.RANGER) as CharacterData).moveset.moves[4].projectiles[0]
	assert_eq(shot.speed, 400)
	assert_eq(shot.lifetime_ticks, 17)
	var range_sub: int = shot.offset_x + shot.speed * shot.lifetime_ticks
	assert_between(float(range_sub) / 1000.0, 6.0, 7.5, "range is %.2f m (target ~6.8 m)" % (float(range_sub) / 1000.0))
	var world: SimWorld = _arrow_world(12000)
	_press_x_then_wait(world, 40)
	assert_eq(world.projectiles.size(), 0, "the arrow is gone before 12 m")
	assert_eq(world.fighters[1].combo, 0, "a dummy 12 m away is not hit")


func test_mashing_x_cannot_start_the_next_arrow_before_cancel_from() -> void:
	# cancel_from is 16 on x1; mashing every tick must still wait that long.
	var world: SimWorld = SimSetup.create(&"training", 1)
	var x2_tick: int = -1
	for tick: int in 40:
		# A new press every tick (mash), not a hold.
		world.step([InputFrame.new(0, X, X, 0)] as Array[InputFrame])
		for event: SimEvent in world.events:
			if event.type == &"move_start" and event.move_id == &"ranger_x2":
				x2_tick = event.tick
	assert_eq(x2_tick, 16, "x2 starts at x1.cancel_from, not earlier, even when X is mashed")
