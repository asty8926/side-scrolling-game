extends ReplayTest
## Movement (#41) as scripted replays on the test room.
## Test room (data/rooms/test_room.tres): spawn x = 0 on the floor, under the
## tier-1 platform "center1" (x -3250..1250) and the tier-2 platform "center2"
## (x -1500..2500). Tier height = 85% of one jump's apex.

const R: int = InputFrame.RIGHT
const L: int = InputFrame.LEFT
const U: int = InputFrame.UP
const D: int = InputFrame.DOWN


## segments: [[held_mask, ticks], ...] -> replay on the test room.
func _script(segments: Array[Array]) -> Replay:
	var replay: Replay = Replay.new()
	replay.setup = &"test_room"
	replay.world_seed = 41
	var previous: int = 0
	for segment: Array in segments:
		var held: int = segment[0]
		var ticks: int = segment[1]
		for i: int in ticks:
			replay.append_frame(InputFrame.from_held(0, previous, held))
			previous = held
	return replay


func _run(segments: Array[Array]) -> ReplayRunner.Result:
	var result: ReplayRunner.Result = ReplayRunner.run(_script(segments))
	assert_true(result.ok, "\n".join(result.problems))
	return result


func _fighter(result: ReplayRunner.Result) -> SimFighter:
	return result.world.fighters[0]


func _events_of(result: ReplayRunner.Result, type: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for line: String in result.events:
		if line.split(":")[1] == type:
			out.append(line)
	return out


func test_one_jump_lands_on_the_next_tier() -> void:
	var result: ReplayRunner.Result = _run([[U, 2], [0, 120]])
	var f: SimFighter = _fighter(result)
	var w: SimWorld = result.world
	assert_eq(f.y, w.tier_height, "standing on tier 1")
	assert_eq(f.ground, 1, "on platform center1")
	assert_eq(_events_of(result, "jump").size(), 1)
	assert_eq(_events_of(result, "land").size(), 1)


func test_double_jump_reaches_two_tiers() -> void:
	# Jump, wait for the apex (~22 ticks), jump again in the air.
	var result: ReplayRunner.Result = _run([[U, 2], [0, 20], [U, 2], [0, 150]])
	var f: SimFighter = _fighter(result)
	assert_eq(f.y, 2 * result.world.tier_height, "standing on tier 2")
	assert_eq(f.ground, 3, "on platform center2")
	assert_eq(_events_of(result, "double_jump").size(), 1)


func test_single_jump_cannot_reach_tier_two() -> void:
	var m: MovementParams = load(SimSetup.RANGER_MOVEMENT) as MovementParams
	var room: RoomLayout = load(SimSetup.TEST_ROOM) as RoomLayout
	var apex: int = m.single_jump_height()
	assert_gte(apex, room.tier_height(m), "one jump reaches one tier")
	assert_lt(apex, 2 * room.tier_height(m), "one jump does not reach two tiers")


func test_double_tap_dashes_and_holding_keeps_running() -> void:
	var result: ReplayRunner.Result = _run([[R, 3], [0, 3], [R, 30]])
	var f: SimFighter = _fighter(result)
	var m: MovementParams = result.world.movement
	assert_eq(f.vx, m.dash_speed)
	assert_eq(f.dash_dir, SimFighter.RIGHT)
	assert_eq(_events_of(result, "dash").size(), 1)
	assert_eq(f.x, 3 * m.walk_speed + 30 * m.dash_speed, "walk 3 ticks, then dash 30 ticks")


func test_back_dash_faces_backward_then_reverse_stops_facing_right() -> void:
	# Facing right at spawn. << dashes left and faces left; > during it reverses.
	var result: ReplayRunner.Result = _run([[L, 2], [0, 2], [L, 10], [R, 1]])
	var f: SimFighter = _fighter(result)
	assert_eq(f.facing, SimFighter.RIGHT, "faces right after the reverse")
	assert_eq(f.vx, 0, "zero speed on the reverse tick")
	assert_eq(f.dash_dir, 0, "dash stopped")
	var reverse: PackedStringArray = _events_of(result, "dash_reverse")
	assert_eq(reverse.size(), 1)
	assert_eq(reverse[0].split(":")[0], "14", "reverse at the expected tick (0-based tick 14 = 15th frame)")


func test_back_dash_alone_faces_left() -> void:
	var result: ReplayRunner.Result = _run([[L, 2], [0, 2], [L, 10]])
	var f: SimFighter = _fighter(result)
	assert_eq(f.facing, SimFighter.LEFT)
	assert_eq(f.vx, -result.world.movement.dash_speed)


func test_drop_through_platform_but_not_floor() -> void:
	var result: ReplayRunner.Result = _run([[U, 2], [0, 120], [D, 2], [0, 120]])
	var f: SimFighter = _fighter(result)
	assert_eq(f.y, 0, "back on the floor")
	assert_eq(f.ground, SimFighter.ON_FLOOR)
	assert_eq(_events_of(result, "drop").size(), 1)
	var again: ReplayRunner.Result = _run([[D, 2], [0, 30]])
	assert_eq(_events_of(again, "drop").size(), 0, "down on the floor does nothing")
	assert_eq(_fighter(again).y, 0)


func test_walls_clamp_and_walking_off_a_platform_falls() -> void:
	# Stand on center1, walk right off its edge (x 1250) and fall to the floor.
	var result: ReplayRunner.Result = _run([[U, 2], [0, 120], [R, 60], [0, 120]])
	var f: SimFighter = _fighter(result)
	assert_eq(f.ground, SimFighter.ON_FLOOR)
	var walled: ReplayRunner.Result = _run([[L, 2], [0, 2], [L, 400]])
	var room: RoomLayout = walled.world.room
	assert_eq(_fighter(walled).x, room.left + walled.world.movement.half_width, "clamped at the left wall")


func test_jump_is_buffered_before_landing() -> void:
	# After the double jump (no air jump left), press up 3 ticks before landing:
	# the buffered press jumps again right on landing.
	var base: Array[Array] = [[U, 2], [0, 20], [U, 2]]
	var first_script: Array[Array] = base.duplicate()
	first_script.append([0, 200])
	var first: ReplayRunner.Result = _run(first_script)
	var land_tick: int = int(_events_of(first, "land")[0].split(":")[0])
	var wait: int = land_tick - 3 - 24  # frames 0..23 are the base segments
	var second_script: Array[Array] = base.duplicate()
	second_script.append_array([[0, wait], [U, 1], [0, 10]])
	var result: ReplayRunner.Result = _run(second_script)
	assert_eq(_events_of(result, "jump").size(), 2, "second ground jump comes from the buffered press")
	assert_eq(_events_of(result, "double_jump").size(), 1)


func test_same_movement_replay_is_deterministic() -> void:
	var segments: Array[Array] = [[R, 3], [0, 2], [R, 20], [U, 2], [0, 10], [U, 2], [L, 40], [D, 1], [0, 60]]
	var a: ReplayRunner.Result = _run(segments)
	var b: ReplayRunner.Result = _run(segments)
	assert_eq(a.final_hash, b.final_hash)
	assert_eq(a.events, b.events)


func test_movement_params_change_behaviour() -> void:
	var world: SimWorld = SimSetup.create(&"test_room", 1)
	var faster: MovementParams = world.movement.duplicate() as MovementParams
	faster.walk_speed = 100
	var room: RoomLayout = world.room
	var other: SimWorld = SimWorld.new(1)
	assert_eq(other.configure(room, faster, world.input_settings).size(), 0)
	other.add_fighter(0)
	for i: int in 10:
		other.step([InputFrame.new(0, R, R if i == 0 else 0)] as Array[InputFrame])
	assert_eq(other.fighters[0].x, 1000, "10 ticks at walk_speed 100")
