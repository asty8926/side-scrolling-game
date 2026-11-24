extends ReplayTest
## >>Z slide kick and >>ZX slash-through (#47). Training setup: ranger at
## spawn 0, dummy at +1000. Root motion, pass-through and numbers are proposals
## (data/characters/ranger_moves.tres); the expected ticks follow that file.

const Z: int = InputFrame.Z
const X: int = InputFrame.X
const R: int = InputFrame.RIGHT


func _script(segments: Array[Array], setup: StringName = &"training") -> Replay:
	var replay: Replay = Replay.new()
	replay.setup = setup
	replay.world_seed = 1
	var previous: int = 0
	for segment: Array in segments:
		var held: int = segment[0]
		var ticks: int = segment[1]
		for i: int in ticks:
			replay.append_frame(InputFrame.from_held(0, previous, held))
			previous = held
	return replay


func _run(segments: Array[Array], setup: StringName = &"training") -> ReplayRunner.Result:
	var result: ReplayRunner.Result = ReplayRunner.run(_script(segments, setup))
	assert_true(result.ok, "\n".join(result.problems))
	return result


func test_dash_z_starts_the_slide_not_neutral_z() -> void:
	# >> then Z while still dashing: the dash attack, not ranger_z1.
	var result: ReplayRunner.Result = _run([[R, 3], [0, 3], [R, 1], [R | Z, 1], [0, 20]])
	var starts: PackedStringArray = events_of(result, "move_start")
	assert_eq(starts.size(), 1)
	assert_string_contains(starts[0], "ranger_dash_z")
	assert_eq(events_of(result, "hit").size(), 1, "the slide kick hits the dummy once")


func test_standing_z_is_still_the_neutral_string() -> void:
	var result: ReplayRunner.Result = _run([[Z, 1], [0, 10]])
	assert_string_contains(events_of(result, "move_start")[0], "ranger_z1")


func test_dash_zz_plays_the_placeholder_second_kick() -> void:
	var result: ReplayRunner.Result = _run([[R, 3], [0, 3], [R, 1], [R | Z, 1], [0, 10], [Z, 1], [0, 20]])
	var start_ids: PackedStringArray = PackedStringArray()
	for line: String in events_of(result, "move_start"):
		start_ids.append(line.split(":")[4])
	assert_eq(start_ids, PackedStringArray(["ranger_dash_z", "ranger_dash_zz"]))
	assert_eq(events_of(result, "hit").size(), 2)


func test_dash_zx_crosses_to_the_far_side_then_zzz_continues_the_combo() -> void:
	# >>Z, X in the cancel window, then Z Z Z. The slash is a blade (no arrow).
	# Dash: 3 walk + 3 release + 4 hold, Z on the next tick (tick 10).
	# Cancel opens when dash_z move_tick reaches 10, 10 ticks after start.
	var result: ReplayRunner.Result = _run([
		[R, 3], [0, 3], [R, 1], [R | Z, 1], [0, 10], [X, 1], [0, 10], [Z, 1], [0, 6], [Z, 1], [0, 6], [Z, 1], [0, 30],
	])
	var starts: PackedStringArray = events_of(result, "move_start")
	var start_ids: PackedStringArray = PackedStringArray()
	for line: String in starts:
		start_ids.append(line.split(":")[4])
	assert_eq(start_ids, PackedStringArray([
		"ranger_dash_z", "ranger_dash_zx", "ranger_z1", "ranger_z2", "ranger_z3",
	]), "hit chain >>Z, X, Z, Z, Z: %s" % [starts])
	assert_eq(events_of(result, "projectile").size(), 0, "X after the dash-kick is a blade slash, not an arrow")
	var hits: PackedStringArray = events_of(result, "hit")
	var hit_ids: PackedStringArray = PackedStringArray()
	for line: String in hits:
		hit_ids.append(line.split(":")[4])
	assert_eq(hit_ids, PackedStringArray([
		"ranger_dash_z", "ranger_dash_zx", "ranger_z1", "ranger_z2", "ranger_z3",
	]), "each move lands once: %s" % [hits])
	var ranger: SimFighter = result.world.fighters[0]
	var dummy: SimFighter = result.world.fighters[1]
	assert_gt(ranger.x, dummy.x, "the ranger ends on the far side of the dummy")
	assert_eq(ranger.facing, SimFighter.LEFT, "turns around at the end of the slash to face the dummy")
	assert_eq(dummy.combo, 5, "the counter keeps going through the five hits")
	assert_gt(dummy.hitstun, 0, "the dummy is left in hitstun, not knocked down")
	var m: MovementParams = result.world.movement
	assert_lte(ranger.x, result.world.room.right - m.half_width)
	assert_lte(dummy.x, result.world.room.right - m.half_width)


func test_slash_next_to_a_wall_stops_before_the_wall() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var m: MovementParams = world.movement
	var wall: int = world.room.right - m.half_width
	var dummy: SimFighter = world.fighters[1]
	var ranger: SimFighter = world.fighters[0]
	dummy.x = wall - 200
	dummy.home_x = dummy.x
	ranger.x = dummy.x - 700
	ranger.facing = SimFighter.RIGHT
	ranger.dash_dir = SimFighter.RIGHT
	var previous: int = 0
	for tick: int in 80:
		var held: int = 0
		if tick == 0:
			held = Z
		elif tick == 11:
			held = X
		world.step([InputFrame.from_held(0, previous, held)] as Array[InputFrame])
		previous = held
		assert_lte(ranger.x, wall, "ranger stays inside the wall at tick %d" % tick)
		assert_lte(dummy.x, wall, "dummy stays inside the wall at tick %d" % tick)
		assert_gte(ranger.x, world.room.left + m.half_width)
		assert_gte(dummy.x, world.room.left + m.half_width)
	assert_gte(dummy.combo, 2, "both the slide and the slash landed in the tight space")


func test_root_motion_stops_at_a_platform_edge() -> void:
	var world: SimWorld = SimSetup.create(&"test_room", 1)
	var platform: RoomPlatform = world.room.platforms[1]  # center1, right edge 1250
	var ranger: SimFighter = world.fighters[0]
	ranger.x = platform.right() - 100
	ranger.y = platform.top(world.room.floor_y, world.tier_height)
	ranger.ground = 1
	ranger.facing = SimFighter.RIGHT
	ranger.dash_dir = SimFighter.RIGHT
	var previous: int = 0
	for tick: int in 30:
		var held: int = Z if tick == 0 else 0
		world.step([InputFrame.from_held(0, previous, held)] as Array[InputFrame])
		previous = held
		assert_lte(ranger.x, platform.right(), "slide stops at the platform edge at tick %d" % tick)
		assert_eq(ranger.ground, 1, "does not slide off (M0 choice, docs/systems/04 Q3)")


func test_pass_and_carry_windows_must_fit_the_move() -> void:
	var move: MoveData = MoveData.new()
	move.id = &"broken"
	move.startup = 2
	move.active = 2
	move.recovery = 2
	move.pass_from = 0
	move.pass_to = 40
	var problems: Array[String] = move.validate()
	assert_gt(problems.size(), 0)
	assert_string_contains("; ".join(problems), "pass window")
	move.pass_to = 3
	move.carry_to = 40
	problems = move.validate()
	assert_string_contains("; ".join(problems), "carry_to")
