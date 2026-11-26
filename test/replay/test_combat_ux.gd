extends ReplayTest
## Input-first combat UX: body collision, the ZZZ<<> loop, hit-stop, and
## a mid-slide X cancel. These drive the sim with InputFrame sequences
## (tick-accurate). The keyboard path is covered in test_input_layer_combat.gd.

const Z: int = InputFrame.Z
const X: int = InputFrame.X
const L: int = InputFrame.LEFT
const R: int = InputFrame.RIGHT
const CW: int = 600


func _current_id(world: SimWorld) -> StringName:
	var move: MoveData = SimCombat.current_move(world, world.fighters[0])
	return move.id if move != null else &""


func _held(world: SimWorld, previous: int, held: int) -> int:
	world.step([InputFrame.from_held(0, previous, held)] as Array[InputFrame])
	return held


func test_walking_into_the_dummy_stops_the_player_and_does_not_move_it() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var ranger: SimFighter = world.fighters[0]
	var dummy: SimFighter = world.fighters[1]
	var dummy_start: int = dummy.x
	var previous: int = 0
	for _i: int in 40:
		previous = _held(world, previous, R)
	assert_eq(dummy.x, dummy_start, "walking does not push the dummy")
	assert_eq(ranger.x, dummy.x - world.movement.half_width * 2, "the player stops at the dummy's box")


func test_running_into_the_dummy_runs_in_place_and_does_not_move_it() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var ranger: SimFighter = world.fighters[0]
	var dummy: SimFighter = world.fighters[1]
	var dummy_start: int = dummy.x
	var previous: int = 0
	# Double-tap run and keep holding into the dummy.
	previous = _held(world, previous, R)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, 0)
	for _i: int in 30:
		previous = _held(world, previous, R)
	assert_eq(ranger.dash_dir, SimFighter.RIGHT, "still in the run")
	assert_eq(dummy.x, dummy_start, "running does not push the dummy")
	assert_eq(ranger.x, dummy.x - world.movement.half_width * 2, "runs in place against the box")


func test_slide_kick_into_the_dummy_travels_with_it_instead_of_bouncing() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var ranger: SimFighter = world.fighters[0]
	var dummy: SimFighter = world.fighters[1]
	var start_x: int = ranger.x
	var dummy_start: int = dummy.x
	var previous: int = 0
	previous = _held(world, previous, R)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, R)
	previous = _held(world, previous, R)
	previous = _held(world, previous, R | Z)
	for _i: int in 40:
		previous = _held(world, previous, 0)
	assert_gt(ranger.x - start_x, 2 * CW, "the slide covers well over 2 CW against the dummy")
	assert_gt(dummy.x - dummy_start, CW, "the dummy is driven along by the slide, not left in place")
	assert_eq(dummy.combo, 1, "the slide kick lands")
	assert_gt(ranger.x, dummy.x - world.movement.half_width * 2 - 50, "does not bounce back to a tiny bump")


func test_x_can_cancel_the_slide_as_soon_as_it_connects() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var previous: int = 0
	previous = _held(world, previous, R)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, R)
	previous = _held(world, previous, R | Z)
	var saw_slide: bool = false
	for i: int in 30:
		if _current_id(world) == &"ranger_dash_z":
			saw_slide = true
		previous = _held(world, previous, X if i == 6 else 0)
		if _current_id(world) == &"ranger_dash_zx":
			# The press is at the first active tick (~6); after the short
			# hit-stop it should still become the slash, not wait for the
			# slide to end. The slide hit must already have landed (cancel
			# opens on tick 7, after resolve_hits on tick 6).
			assert_true(i <= 12, "hit-cancelled by tick %d, not at the end of the slide" % i)
			assert_gte(world.fighters[1].combo, 1, "the slide still hits before the cancel")
			return
	fail_test(">>ZX never started (saw the slide: %s)" % saw_slide)


func test_zzz_back_forward_cancels_the_third_kick_and_restarts_the_string() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var ranger: SimFighter = world.fighters[0]
	var previous: int = 0
	var started: PackedStringArray = PackedStringArray()
	# Three kicks, then a back-forward twitch during the 3rd recovery, then Z.
	var script: Array[Array] = [[Z, 1], [0, 10], [Z, 1], [0, 10], [Z, 1], [0, 10], [L, 1], [0, 1], [R, 1], [0, 1], [Z, 1], [0, 8]]
	for segment: Array in script:
		var held: int = segment[0]
		var ticks: int = segment[1]
		for _i: int in ticks:
			previous = _held(world, previous, held)
			for event: SimEvent in world.events:
				if event.type == &"move_start" and event.actor == ranger.id:
					started.append(String(event.move_id))
	assert_eq(started, PackedStringArray(["ranger_z1", "ranger_z2", "ranger_z3", "ranger_z1"]), "ZZZ<<>Z is z1-z2-z3-z1, got %s" % [started])
	assert_eq(ranger.facing, SimFighter.RIGHT, "faces the original forward after >")
	assert_eq(ranger.dir_cancel_facing, 0)


func test_dir_cancel_faces_away_with_no_step() -> void:
	var world: SimWorld = SimSetup.create(&"test_room", 1)
	var ranger: SimFighter = world.fighters[0]
	var previous: int = 0
	previous = _held(world, previous, Z)
	for _i: int in 8:
		previous = _held(world, previous, 0)
	# First kick, mid-recovery: one back press.
	var x_before: int = ranger.x
	var facing_before: int = ranger.facing
	previous = _held(world, previous, L)
	assert_eq(ranger.move, SimFighter.NO_MOVE)
	assert_eq(ranger.facing, -facing_before, "instantly faces away")
	assert_eq(ranger.x, x_before, "no step on <<")
	previous = _held(world, previous, 0)
	previous = _held(world, previous, R)
	assert_eq(ranger.facing, facing_before, "snaps back on >")
	assert_eq(ranger.x, x_before, "no step on >")
	assert_eq(ranger.dir_cancel_facing, 0)


func test_hit_stop_freezes_attacker_and_target_then_resumes() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var ranger: SimFighter = world.fighters[0]
	var dummy: SimFighter = world.fighters[1]
	var previous: int = 0
	previous = _held(world, previous, Z)
	var frozen: int = 0
	var saw_hit: bool = false
	var move_tick_on_hit: int = -1
	var ranger_x_on_hit: int = 0
	for _i: int in 30:
		previous = _held(world, previous, 0)
		if not saw_hit:
			for event: SimEvent in world.events:
				if event.type == &"hit":
					saw_hit = true
					move_tick_on_hit = ranger.move_tick
					ranger_x_on_hit = ranger.x
					assert_eq(ranger.hitstop, 2, "attacker hit-stop is 2 ticks [ours]")
					assert_eq(dummy.hitstop, 2, "target hit-stop is 2 ticks [ours]")
			continue
		# The last paused tick ends with hitstop already decremented to 0, so
		# count by motion not being applied, for the first 2 steps after the hit.
		if frozen < 2:
			frozen += 1
			assert_eq(ranger.move_tick, move_tick_on_hit, "move tick paused during hit-stop")
			assert_eq(ranger.x, ranger_x_on_hit, "attacker does not move during hit-stop")
	assert_true(saw_hit, "the first kick lands")
	assert_eq(frozen, 2, "both stay paused for 2 ticks")
	assert_eq(ranger.hitstop, 0)
	assert_gt(dummy.hitstun, 0, "hitstun resumes after the freeze")


func test_recoil_into_a_dummy_behind_does_not_fling_it_forward() -> void:
	# A backward step (x2 recoil) into a dummy behind must push it further
	# back, not teleport it in front of the ranger.
	var world: SimWorld = SimSetup.create(&"training", 1)
	var ranger: SimFighter = world.fighters[0]
	var dummy: SimFighter = world.fighters[1]
	ranger.x = 0
	ranger.facing = SimFighter.RIGHT
	dummy.x = -600
	dummy.home_x = dummy.x
	ranger.move = world.characters[0].moveset.index_of(&"ranger_x2")
	ranger.move_tick = 2  # first recoil tick of x2 (root motion -25)
	world.step([InputFrame.new(0, 0, 0, 0)] as Array[InputFrame])
	assert_lt(dummy.x, -600, "the dummy is pushed further back, got %d" % dummy.x)
	assert_lt(ranger.x, dummy.x + world.movement.half_width * 2 + 1)
	assert_gt(ranger.x, dummy.x - world.movement.half_width * 2 - 1)
