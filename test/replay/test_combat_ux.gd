extends ReplayTest
## Input-first combat UX: body collision, cycle resets, hit-stop, slide
## cancels, loop gaps, and the WWW<<>WWW<< run. InputFrame sequences
## (tick-accurate). The keyboard path is in test_input_layer_combat.gd.

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
	var hit_landed: bool = false
	for i: int in 30:
		if _current_id(world) == &"ranger_dash_z":
			saw_slide = true
		if world.fighters[1].combo >= 1:
			hit_landed = true
		# Press X the tick after the slide connects so the kick still lands.
		previous = _held(world, previous, X if hit_landed and world.fighters[1].combo >= 1 and _current_id(world) == &"ranger_dash_z" else 0)
		if _current_id(world) == &"ranger_dash_zx":
			assert_true(i <= 16, "hit-cancelled by tick %d, not at the end of the slide" % i)
			assert_gte(world.fighters[1].combo, 1, "the slide still hits before the cancel")
			return
	fail_test(">>ZX never started (saw the slide: %s, hit: %s)" % [saw_slide, hit_landed])


func test_zzz_back_forward_cancels_the_third_kick_and_restarts_the_string() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var ranger: SimFighter = world.fighters[0]
	var previous: int = 0
	var started: PackedStringArray = PackedStringArray()
	# Three kicks, then a double-tap back (queues a run) and a forward
	# cancel (`<<>`), then Z. A single back press must not eat the run.
	var script: Array[Array] = [[Z, 1], [0, 10], [Z, 1], [0, 10], [Z, 1], [0, 10], [L, 1], [0, 2], [L, 1], [R, 1], [0, 1], [Z, 1], [0, 8]]
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


func test_double_tap_back_during_recovery_starts_a_run() -> void:
	# A double-tap `<<` during recovery queues a left run and only starts
	# moving after the confirm window, if left is still held.
	var world: SimWorld = SimSetup.create(&"test_room", 1)
	var ranger: SimFighter = world.fighters[0]
	var previous: int = 0
	previous = _held(world, previous, Z)
	for _i: int in 12:
		previous = _held(world, previous, 0)
	previous = _held(world, previous, L)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, L)
	assert_eq(ranger.move, SimFighter.NO_MOVE, "recovery is dash-cancelled")
	assert_eq(ranger.dash_dir, 0, "the run has not started on the second-tap tick")
	assert_eq(ranger.queued_dash_dir, SimFighter.LEFT, "double-tap left queues a left run")
	assert_gt(ranger.queued_dash_ticks, 0)
	assert_eq(ranger.facing, SimFighter.LEFT)
	assert_eq(ranger.dir_cancel_facing, 0)
	var mid: int = ranger.x
	for _j: int in 5:
		previous = _held(world, previous, L)
	assert_eq(ranger.dash_dir, 0, "the run stays queued through the first half of the window")
	assert_eq(ranger.x, mid, "no run movement during the confirm window")
	for _k: int in 10:
		previous = _held(world, previous, L)
	assert_eq(ranger.dash_dir, SimFighter.LEFT, "the run starts after the confirm window while left is held")
	assert_eq(ranger.queued_dash_ticks, 0)
	assert_lt(ranger.x, mid, "the confirmed run moves left")


func test_www_left_right_flips_in_place_with_no_run() -> void:
	# Asty: WWW<<> at the right timing must not run the other way and come
	# back. A quick > inside the confirm window is an in-place turn-cancel.
	var world: SimWorld = SimSetup.create(&"test_room", 1)
	var ranger: SimFighter = world.fighters[0]
	var previous: int = 0
	var script: Array[Array] = [[Z, 1], [0, 10], [Z, 1], [0, 10], [Z, 1], [0, 10], [L, 1], [0, 2], [L, 1]]
	for segment: Array in script:
		var held: int = segment[0]
		var ticks: int = segment[1]
		for _i: int in ticks:
			previous = _held(world, previous, held)
	var x_at_queue: int = ranger.x
	assert_eq(ranger.queued_dash_dir, SimFighter.LEFT)
	assert_eq(ranger.dash_dir, 0)
	previous = _held(world, previous, R)
	assert_eq(ranger.facing, SimFighter.RIGHT, "quick > flips facing in place")
	assert_eq(ranger.dash_dir, 0, "no run starts")
	assert_eq(ranger.queued_dash_ticks, 0)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, 0)
	assert_eq(ranger.x, x_at_queue, "WWW<<> does not run the other way")
	assert_eq(ranger.dash_dir, 0)


func test_left_right_and_z_on_the_same_tick_flips_then_starts_the_first_kick() -> void:
	# A queued recovery `<<` plus `>` and Z on the same tick must not start
	# a left slide. Combat runs before movement, so the opposite press has
	# to clear the queue in begin_tick.
	var world: SimWorld = SimSetup.create(&"test_room", 1)
	var ranger: SimFighter = world.fighters[0]
	var previous: int = 0
	var started: PackedStringArray = PackedStringArray()
	var script: Array[Array] = [[Z, 1], [0, 10], [Z, 1], [0, 10], [Z, 1], [0, 10], [L, 1], [0, 2], [L, 1]]
	for segment: Array in script:
		var held: int = segment[0]
		var ticks: int = segment[1]
		for _i: int in ticks:
			previous = _held(world, previous, held)
			for event: SimEvent in world.events:
				if event.type == &"move_start" and event.actor == ranger.id:
					started.append(String(event.move_id))
	assert_eq(ranger.queued_dash_dir, SimFighter.LEFT)
	var x_at_queue: int = ranger.x
	previous = _held(world, previous, R | Z)
	for event: SimEvent in world.events:
		if event.type == &"move_start" and event.actor == ranger.id:
			started.append(String(event.move_id))
	assert_eq(started, PackedStringArray(["ranger_z1", "ranger_z2", "ranger_z3", "ranger_z1"]), "same-tick >Z after << is z1, got %s" % [started])
	assert_eq(ranger.facing, SimFighter.RIGHT)
	assert_eq(ranger.dash_dir, 0)
	assert_eq(ranger.queued_dash_ticks, 0)
	assert_eq(ranger.x, x_at_queue, "the opposite press still flips in place")


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


func test_xxx_back_forward_cancels_the_third_arrow_and_restarts_the_string() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var ranger: SimFighter = world.fighters[0]
	var previous: int = 0
	var started: PackedStringArray = PackedStringArray()
	# X3 recovery opens later than Z3 (startup 8 + active 8 = 16).
	var script: Array[Array] = [[X, 1], [0, 16], [X, 1], [0, 16], [X, 1], [0, 18], [L, 1], [0, 2], [L, 1], [R, 1], [0, 1], [X, 1], [0, 8]]
	for segment: Array in script:
		var held: int = segment[0]
		var ticks: int = segment[1]
		for _i: int in ticks:
			previous = _held(world, previous, held)
			for event: SimEvent in world.events:
				if event.type == &"move_start" and event.actor == ranger.id:
					started.append(String(event.move_id))
	assert_eq(started, PackedStringArray(["ranger_x1", "ranger_x2", "ranger_x3", "ranger_x1"]), "XXX<<>X is x1-x2-x3-x1, got %s" % [started])
	assert_eq(ranger.facing, SimFighter.RIGHT, "faces the original forward after >")


func test_mixed_zzx_back_forward_restarts_on_z() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var ranger: SimFighter = world.fighters[0]
	var previous: int = 0
	var started: PackedStringArray = PackedStringArray()
	var script: Array[Array] = [[Z, 1], [0, 10], [Z, 1], [0, 24], [X, 1], [0, 18], [L, 1], [0, 2], [L, 1], [R, 1], [0, 1], [Z, 1], [0, 8]]
	for segment: Array in script:
		var held: int = segment[0]
		var ticks: int = segment[1]
		for _i: int in ticks:
			previous = _held(world, previous, held)
			for event: SimEvent in world.events:
				if event.type == &"move_start" and event.actor == ranger.id:
					started.append(String(event.move_id))
	assert_eq(started, PackedStringArray(["ranger_z1", "ranger_z2", "ranger_x1", "ranger_z1"]), "ZZX<<>Z restarts on z1, got %s" % [started])


func test_www_left_right_www_left_left_ends_running_left() -> void:
	# The exact sequence Asty reported: WWW<<>WWW<< must end in a left run,
	# not stopped in place. The `>` of the first `<<>` must not swallow the
	# later `<<`.
	var world: SimWorld = SimSetup.create(&"test_room", 1)
	var ranger: SimFighter = world.fighters[0]
	var previous: int = 0
	var script: Array[Array] = [
		[Z, 1], [0, 10], [Z, 1], [0, 10], [Z, 1], [0, 10],
		[L, 1], [0, 2], [L, 1], [R, 1],
		[Z, 1], [0, 10], [Z, 1], [0, 10], [Z, 1], [0, 10],
		[L, 1], [0, 2], [L, 14],
	]
	for segment: Array in script:
		var held: int = segment[0]
		var ticks: int = segment[1]
		for _i: int in ticks:
			previous = _held(world, previous, held)
	assert_eq(ranger.dash_dir, SimFighter.LEFT, "WWW<<>WWW<< ends running left, dash_dir=%d move=%s" % [ranger.dash_dir, _current_id(world)])
	assert_eq(ranger.facing, SimFighter.LEFT)
	assert_eq(ranger.move, SimFighter.NO_MOVE)


func test_x_cancels_the_slide_after_visible_frames_in_open_space() -> void:
	# `>>WX` must dash its full distance even with no enemy. X can cancel
	# only after a few visible slide frames (cancel_from 7), not on tick 0
	# and not only on connect.
	var world: SimWorld = SimSetup.create(&"test_room", 1)
	var ranger: SimFighter = world.fighters[0]
	var start_x: int = ranger.x
	var previous: int = 0
	previous = _held(world, previous, R)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, R)
	previous = _held(world, previous, R | Z)
	# Press X as soon as the slide exists; it must stay a slide until tick 7.
	var cancelled: bool = false
	var zx_tick: int = -1
	var slide_before_zx: int = 0
	for i: int in 16:
		if _current_id(world) == &"ranger_dash_z":
			var tick_before: int = ranger.move_tick
			var x_before: int = ranger.x
			previous = _held(world, previous, X)
			if _current_id(world) == &"ranger_dash_zx":
				cancelled = true
				zx_tick = tick_before
				slide_before_zx = x_before - start_x
				break
		else:
			previous = _held(world, previous, 0)
	assert_true(cancelled, "X cancelled the slide in open space (move=%s)" % _current_id(world))
	assert_gte(zx_tick, 7, "X starts the dash only after a few slide frames (started at slide tick %d)" % zx_tick)
	assert_gte(slide_before_zx, 400, "the slide already travelled before the dash (got %d sub)" % slide_before_zx)
	for _j: int in 40:
		previous = _held(world, previous, 0)
	var travelled: float = float(ranger.x - start_x) / CW
	assert_between(travelled, 7.0, 13.0, "empty-space >>WX covers %.2f CW (target ~8-10 CW plus a little slide)" % travelled)


func test_dash_wx_hits_two_dummies_along_the_path() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var dummy2: SimFighter = SimSetup.add_dummy_at(world, world.room.spawn_x + 4000)
	assert_not_null(dummy2, "second dummy spawned")
	var previous: int = 0
	previous = _held(world, previous, R)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, R)
	previous = _held(world, previous, R | Z)
	previous = _held(world, previous, 0)
	var slash_hits: Dictionary[int, int] = {}
	previous = _held(world, previous, X)
	for event: SimEvent in world.events:
		if event.type == &"hit" and event.move_id == &"ranger_dash_zx":
			slash_hits[event.target] = slash_hits.get(event.target, 0) + 1
	for _i: int in 50:
		previous = _held(world, previous, 0)
		for event: SimEvent in world.events:
			if event.type == &"hit" and event.move_id == &"ranger_dash_zx":
				slash_hits[event.target] = slash_hits.get(event.target, 0) + 1
	# Also catch a hit on the cancel tick itself, before the loop.
	assert_gte(world.fighters[1].combo, 1, "the near dummy is hit")
	assert_gte(dummy2.combo, 1, "the far dummy is also hit once along the dash")
	var near_slash: int = slash_hits[world.fighters[1].id] if slash_hits.has(world.fighters[1].id) else 0
	var far_slash: int = slash_hits[dummy2.id] if slash_hits.has(dummy2.id) else 0
	assert_eq(near_slash, 1, "near dummy takes exactly one slash hit, got %d" % near_slash)
	assert_eq(far_slash, 1, "far dummy takes exactly one slash hit, got %d" % far_slash)


func test_dash_w_chains_from_recovery_with_no_idle_gap() -> void:
	# Before: dash_z could not be cancelled into a new run until tick 24
	# (cancel_to 20 left ticks 21-23 uncancelable, then idle), and a Z in
	# recovery became the follow-up >>ZZ. After: a double-tap during
	# recovery (tick 10) starts a new slide. Open space, no hit-stop.
	var world: SimWorld = SimSetup.create(&"test_room", 1)
	var previous: int = 0
	previous = _held(world, previous, R)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, R)
	previous = _held(world, previous, R | Z)
	var first_start: int = -1
	for event: SimEvent in world.events:
		if event.type == &"move_start" and event.move_id == &"ranger_dash_z":
			first_start = world.tick
	assert_gt(first_start, 0, "first slide started")
	# Wait until recovery (startup 6 + active 4 = 10).
	while world.fighters[0].move_tick < 10 and world.tick < first_start + 30:
		previous = _held(world, previous, 0)
	assert_eq(_current_id(world), &"ranger_dash_z")
	assert_gte(world.fighters[0].move_tick, 10)
	previous = _held(world, previous, R)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, R | Z)
	var second_start: int = -1
	for event: SimEvent in world.events:
		if event.type == &"move_start" and event.move_id == &"ranger_dash_z":
			second_start = world.tick
	if second_start < 0:
		previous = _held(world, previous, 0)
		for event: SimEvent in world.events:
			if event.type == &"move_start" and event.move_id == &"ranger_dash_z":
				second_start = world.tick
	assert_eq(_current_id(world), &"ranger_dash_z", "the next >>W is a new slide, not >>ZZ")
	assert_gt(second_start, first_start, "second slide started")
	var gap: int = second_start - first_start
	# Old gap was >= 24 (full length). New: recovery opens at 10, plus up to
	# ~3 ticks to enter `>>Z`, so the next slide starts well before tick 24.
	assert_between(gap, 10, 16, ">>W loop gap is %d ticks (was 24+; recovery opens at 10)" % gap)


func test_walk_and_run_speeds_match_the_tuned_values() -> void:
	var world: SimWorld = SimSetup.create(&"test_room", 1)
	assert_eq(world.movement.walk_speed, 65, "walk is 65 sub/tick (6.5 CW/s), matching footage")
	assert_eq(world.movement.dash_speed, 150, "run is 150 sub/tick (15.0 CW/s), ~2.3× walk")
	var ranger: SimFighter = world.fighters[0]
	var previous: int = 0
	var walk_start: int = ranger.x
	for _i: int in 10:
		previous = _held(world, previous, R)
	assert_eq(ranger.x - walk_start, 65 * 10, "walk covers 65 sub per tick")
	# Stop long enough that the walk's first press is outside the 12-tick
	# double-tap window, then double-tap a run and hold.
	for _idle: int in 16:
		previous = _held(world, previous, 0)
	previous = _held(world, previous, R)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, 0)
	previous = _held(world, previous, R)
	var run_start: int = ranger.x
	for _j: int in 10:
		previous = _held(world, previous, R)
	assert_eq(ranger.dash_dir, SimFighter.RIGHT)
	assert_eq(ranger.x - run_start, 150 * 10, "run covers 150 sub per tick")
