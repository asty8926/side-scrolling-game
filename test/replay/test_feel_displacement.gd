extends ReplayTest
## Feel check: how far each hit of a string moves the ranger, against the
## reference table in docs/reference/rena-combo-movement.md (1 character
## width = CW = 600 sub-units = the ranger's hurtbox width). Ranges are wide
## on purpose: they catch a move that stops moving, goes the wrong way or
## doubles its distance, not small tuning changes. Change the doc table and
## these ranges together.

const Z: int = InputFrame.Z
const X: int = InputFrame.X
const R: int = InputFrame.RIGHT
const U: int = InputFrame.UP
## One character width in sub-units (ranger hurtbox width).
const CW: int = 600


## One started move (or "end") and the ranger's x on its first tick.
class Mark:
	var id: String
	var x: int

	func _init(move_id: String, at_x: int) -> void:
		id = move_id
		x = at_x


## Presses `button` every `every` ticks for `ticks` ticks after an optional
## dash prefix and returns [move_id, ranger x at its first tick] per started
## move plus ["end", x] after the last tick. Ranger faces right (+x).
func _trace(world: SimWorld, script: Array[Array]) -> Array[Mark]:
	var ranger: SimFighter = world.fighters[0]
	var out: Array[Mark] = []
	var previous: int = 0
	for segment: Array in script:
		var held: int = segment[0]
		var ticks: int = segment[1]
		for i: int in ticks:
			var x_before: int = ranger.x
			world.step([InputFrame.from_held(0, previous, held)] as Array[InputFrame])
			previous = held
			for event: SimEvent in world.events:
				if event.type == &"move_start" and event.actor == ranger.id:
					out.append(Mark.new(str(event.move_id), x_before))
	out.append(Mark.new("end", ranger.x))
	return out


## Displacement of every started move: x at the next move's start (or the
## end) minus x at its own start. {move_id: sub-units}.
func _steps(trace: Array[Mark]) -> Dictionary[String, int]:
	var steps: Dictionary[String, int] = {}
	for i: int in trace.size() - 1:
		steps[trace[i].id] = trace[i + 1].x - trace[i].x
	return steps


func _mash(button: int, every: int, count: int, tail: int) -> Array[Array]:
	var script: Array[Array] = []
	for i: int in count:
		script.append([button, 1])
		script.append([0, every - 1])
	script.append([0, tail])
	return script


## Open space: test room, no dummy (nothing blocks or pushes the ranger).
func _open() -> SimWorld:
	return SimSetup.create(&"test_room", 1)


func _assert_cw(steps: Dictionary[String, int], id: String, low: float, high: float) -> void:
	assert_true(steps.has(id), "%s started: %s" % [id, steps])
	var moved: int = steps.get(id, 0)
	var cw: float = float(moved) / CW
	assert_between(cw, low, high, "%s moves %.2f CW (reference %.2f..%.2f CW)" % [id, cw, low, high])


func test_w_chain_first_kick_stays_then_each_kick_steps_forward() -> void:
	var steps: Dictionary[String, int] = _steps(_trace(_open(), _mash(Z, 6, 6, 60)))
	_assert_cw(steps, "ranger_z1", -0.05, 0.05)
	_assert_cw(steps, "ranger_z2", 0.55, 0.85)
	_assert_cw(steps, "ranger_z3", 0.55, 0.85)
	_assert_cw(steps, "ranger_z4", 0.7, 1.15)


func test_x_chain_first_arrow_stays_then_each_arrow_recoils_backward() -> void:
	var steps: Dictionary[String, int] = _steps(_trace(_open(), _mash(X, 6, 12, 60)))
	_assert_cw(steps, "ranger_x1", -0.05, 0.05)
	_assert_cw(steps, "ranger_x2", -0.4, -0.15)
	_assert_cw(steps, "ranger_x3", -1.8, -1.2)
	_assert_cw(steps, "ranger_x4", -0.7, -0.35)


func test_dash_w_slides_forward_a_real_distance() -> void:
	# >> (tap, release, hold) then Z while dashing.
	var trace: Array[Mark] = _trace(_open(), [[R, 3], [0, 3], [R, 1], [R | Z, 1], [0, 40]])
	_assert_cw(_steps(trace), "ranger_dash_z", 5.8, 7.5)


func test_dash_wx_covers_full_distance_in_open_space() -> void:
	# X mid-slide, no dummy: the slash itself is a fixed ~8 CW dash.
	var trace: Array[Mark] = _trace(_open(), [[R, 3], [0, 3], [R, 1], [R | Z, 1], [0, 4], [X, 1], [0, 40]])
	_assert_cw(_steps(trace), "ranger_dash_zx", 7.0, 9.0)


func test_dash_w_slide_carries_the_dummy_and_stays_in_contact() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var dummy: SimFighter = world.fighters[1]
	var dummy_start: int = dummy.x
	var trace: Array[Mark] = _trace(world, [[R, 3], [0, 3], [R, 1], [R | Z, 1], [0, 40]])
	var slide: int = _steps(trace).get("ranger_dash_z", 0)
	assert_gt(slide, CW, "slides more than 1 CW even into the dummy")
	assert_gt(dummy.x - dummy_start, CW / 2, "the dummy is pushed along by the slide")
	assert_eq(dummy.combo, 1, "the slide kick lands")


func test_dash_wx_dashes_well_past_the_target() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var ranger: SimFighter = world.fighters[0]
	var dummy: SimFighter = world.fighters[1]
	var trace: Array[Mark] = _trace(world, [[R, 3], [0, 3], [R, 1], [R | Z, 1], [0, 8], [X, 1], [0, 40]])
	var steps: Dictionary[String, int] = _steps(trace)
	_assert_cw(steps, "ranger_dash_zx", 6.5, 10.0)
	var behind: float = float(ranger.x - dummy.x) / CW
	assert_gte(behind, 6.0, "ends %.2f CW past the dummy (longer pass; a follow-up WWW may need a run back)" % behind)
	var follow: Array[Mark] = _trace(world, _mash(Z, 6, 3, 40))
	assert_eq(follow[0].id, "ranger_z1")
	assert_gte(dummy.combo, 2, "the slide and the slash both land")


func test_w_chain_against_the_dummy_keeps_every_hit_in_range() -> void:
	# Kicks 2-4 step forward and push the dummy about as far, so the string
	# walks forward and all four hits land.
	var world: SimWorld = SimSetup.create(&"training", 1)
	var ranger: SimFighter = world.fighters[0]
	var start: int = ranger.x
	_trace(world, _mash(Z, 6, 6, 60))
	assert_eq(world.fighters[1].combo, 4, "ZZZZ: four hits")
	assert_between(float(ranger.x - start) / CW, 1.2, 2.6, "the whole string walks the ranger forward")


func test_dash_w_on_the_same_tick_as_the_second_tap_slides() -> void:
	# Human >>W often puts W on the same tick as the second →. Combat used to
	# run before the dash started, so that input became standing Z (no slide).
	var trace: Array[Mark] = _trace(_open(), [[R, 3], [0, 3], [R | Z, 1], [0, 40]])
	assert_eq(trace[0].id, "ranger_dash_z")
	_assert_cw(_steps(trace), "ranger_dash_z", 5.8, 7.5)


func test_dash_w_after_holding_the_run_slides() -> void:
	# Double-tap, hold the run for a stretch, then W while still holding.
	var trace: Array[Mark] = _trace(_open(), [[R, 1], [0, 2], [R, 20], [R | Z, 1], [0, 40]])
	assert_eq(trace[0].id, "ranger_dash_z")
	_assert_cw(_steps(trace), "ranger_dash_z", 5.8, 7.5)


func test_dash_w_after_releasing_the_run_still_slides() -> void:
	# Double-tap, hold, release, then W a few ticks later (still in linger).
	var trace: Array[Mark] = _trace(_open(), [[R, 1], [0, 2], [R, 20], [0, 4], [Z, 1], [0, 40]])
	assert_eq(trace[0].id, "ranger_dash_z")
	_assert_cw(_steps(trace), "ranger_dash_z", 5.8, 7.5)


func test_w_after_the_dash_linger_expires_is_the_standing_kick() -> void:
	# Linger is 12 ticks; 13 ticks after release must be standing Z, no slide.
	var trace: Array[Mark] = _trace(_open(), [[R, 1], [0, 2], [R, 8], [0, 13], [Z, 1], [0, 40]])
	assert_eq(trace[0].id, "ranger_z1")
	_assert_cw(_steps(trace), "ranger_z1", -0.05, 0.05)


func test_w_during_a_walk_is_the_standing_kick() -> void:
	# Holding → without a double-tap is a walk; W must not become a slide.
	var trace: Array[Mark] = _trace(_open(), [[R, 20], [R | Z, 1], [0, 40]])
	assert_eq(trace[0].id, "ranger_z1")
	_assert_cw(_steps(trace), "ranger_z1", -0.05, 0.05)


func test_x_after_releasing_the_run_is_the_standing_arrow() -> void:
	# There is no dash-start X yet, so X during the linger must still start x1
	# instead of being held in the buffer until it expires.
	var trace: Array[Mark] = _trace(_open(), [[R, 1], [0, 2], [R, 8], [0, 4], [X, 1], [0, 40]])
	assert_eq(trace[0].id, "ranger_x1")
	_assert_cw(_steps(trace), "ranger_x1", -0.05, 0.05)


func test_dash_linger_expires_during_a_jump() -> void:
	# Release the run, jump, land after the 12-tick linger would have ended, then W.
	# The window must age in the air, so this is the standing kick, not a slide.
	var trace: Array[Mark] = _trace(_open(), [[R, 1], [0, 2], [R, 8], [0, 1], [U, 1], [0, 80], [Z, 1], [0, 40]])
	assert_eq(trace[0].id, "ranger_z1")
	_assert_cw(_steps(trace), "ranger_z1", -0.05, 0.05)
