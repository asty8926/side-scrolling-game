extends GutTest


func _history(masks: Array[int], player: int = 0) -> InputHistory:
	var h: InputHistory = InputHistory.new()
	var last: int = 0
	for held: int in masks:
		h.push(InputFrame.from_held(player, last, held))
		last = held
	return h


func test_double_tap_right_inside_window() -> void:
	var h: InputHistory = _history([InputFrame.RIGHT, 0, 0, InputFrame.RIGHT])
	assert_true(h.double_tap(InputFrame.RIGHT, 3))
	assert_false(h.double_tap(InputFrame.LEFT, 3))
	assert_false(h.double_tap(InputFrame.RIGHT, 2), "outside smaller window")


func test_double_tap_left_and_hold_does_not_retrigger() -> void:
	var h: InputHistory = _history([InputFrame.LEFT, 0, InputFrame.LEFT])
	assert_true(h.double_tap(InputFrame.LEFT, 12))
	h.push(InputFrame.from_held(0, InputFrame.LEFT, InputFrame.LEFT))
	assert_false(h.double_tap(InputFrame.LEFT, 12), "holding has no second edge")


func test_buffer_is_inclusive_once_then_consumed() -> void:
	var h: InputHistory = _history([InputFrame.Z, 0, 0, 0])
	assert_false(h.buffered_press(InputFrame.Z, 2), "3 ticks old is outside a 2-tick buffer")
	assert_true(h.buffered_press(InputFrame.Z, 3))
	assert_false(h.buffered_press(InputFrame.Z, 3), "consumed")


func test_buffer_wraps_and_old_presses_expire() -> void:
	var h: InputHistory = _history([InputFrame.Z])
	for i: int in InputHistory.CAPACITY + 2:
		h.push(InputFrame.new())
	assert_false(h.buffered_press(InputFrame.Z, 63))
	h.push(InputFrame.new(0, InputFrame.X, InputFrame.X))
	assert_true(h.buffered_press(InputFrame.X, 0))


func test_consumed_buffer_and_ring_survive_snapshot() -> void:
	var a: SimWorld = SimWorld.new(1)
	for tick: int in 80:
		var held: int = InputFrame.Z if tick == 78 else 0
		var press: int = InputFrame.Z if tick == 78 else 0
		a.step([InputFrame.new(0, held, press)] as Array[InputFrame])
	assert_true(a.histories[0].buffered_press(InputFrame.Z, 8))
	var b: SimWorld = SimWorld.new(1)
	assert_eq(b.restore(a.snapshot()), OK)
	assert_eq(b.state_hash(), a.state_hash())
	assert_false(b.histories[0].buffered_press(InputFrame.Z, 8), "consumed press stays consumed after restore")


func test_world_missing_input_advances_history_with_empty_frame() -> void:
	var world: SimWorld = SimWorld.new()
	world.step([InputFrame.new(0, InputFrame.RIGHT, InputFrame.RIGHT)] as Array[InputFrame])
	world.step([] as Array[InputFrame])
	assert_eq(world.histories[0].held_now(), 0)
	assert_eq(world.histories[0].pressed_ago(1), InputFrame.RIGHT)


func test_input_settings_resource_validates() -> void:
	var settings: InputSettings = load("res://data/input_settings.tres") as InputSettings
	assert_not_null(settings)
	assert_eq(settings.validate().size(), 0)
	assert_eq(settings.double_tap_window_ticks, 12)
	assert_eq(settings.buffer_ticks, 8)


func test_frame_edges_and_quick_tap() -> void:
	var press: InputFrame = InputFrame.from_held(0, 0, InputFrame.Z)
	assert_eq(press.pressed, InputFrame.Z)
	assert_eq(press.released, 0)
	var release: InputFrame = InputFrame.from_held(0, InputFrame.Z, 0)
	assert_eq(release.released, InputFrame.Z)
	assert_true(InputFrame.new(0, 0, InputFrame.Z, InputFrame.Z).is_valid(), "sub-tick tap may press AND release")
