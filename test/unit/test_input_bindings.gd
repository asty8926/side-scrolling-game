extends GutTest


func after_each() -> void:
	for action: StringName in InputSampler.ACTIONS:
		Input.action_release(action)


func test_all_gameplay_bindings_are_physical_only() -> void:
	for action: StringName in InputSampler.ACTIONS:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		assert_eq(events.size(), 1, str(action))
		var key: InputEventKey = events[0] as InputEventKey
		assert_not_null(key)
		assert_ne(key.physical_keycode, 0)
		assert_eq(key.keycode, 0)
		assert_eq(key.unicode, 0)


func test_primary_is_physical_z_not_a_and_ctrl_is_left() -> void:
	var z: InputEventKey = InputMap.action_get_events(&"attack_z")[0] as InputEventKey
	assert_eq(z.physical_keycode, KEY_Z)
	var ctrl: InputEventKey = InputMap.action_get_events(&"awaken")[0] as InputEventKey
	assert_eq(ctrl.physical_keycode, KEY_CTRL)
	assert_eq(ctrl.location, KEY_LOCATION_LEFT)
	var physical_a: InputEventKey = InputEventKey.new()
	physical_a.physical_keycode = KEY_Q  # French AZERTY's A is physical Q
	physical_a.pressed = true
	assert_false(physical_a.is_action_pressed(&"attack_z"))
	assert_false(physical_a.is_action_pressed(&"left"))


func test_debug_record_is_f9() -> void:
	var key: InputEventKey = InputMap.action_get_events(&"debug_record_replay")[0] as InputEventKey
	assert_eq(key.physical_keycode, KEY_F9)


func test_sampler_builds_edges_only_once_per_tick() -> void:
	var sampler: InputSampler = autofree(InputSampler.new())
	Input.action_press(&"attack_z")
	var a: InputFrame = sampler.sample_tick()
	var b: InputFrame = sampler.sample_tick()
	assert_eq(a.held, InputFrame.Z)
	assert_eq(a.pressed, InputFrame.Z)
	assert_eq(b.pressed, 0)
	Input.action_release(&"attack_z")
	var c: InputFrame = sampler.sample_tick()
	assert_eq(c.held, 0)
	assert_eq(c.released, InputFrame.Z)


func test_sampler_does_not_lose_a_subtick_press_release() -> void:
	var sampler: InputSampler = autofree(InputSampler.new())
	var event: InputEventAction = InputEventAction.new()
	event.action = &"attack_z"
	event.pressed = true
	sampler._input(event)
	event.pressed = false
	sampler._input(event)
	var frame: InputFrame = sampler.sample_tick()
	assert_eq(frame.held, 0)
	assert_eq(frame.pressed, InputFrame.Z)
	assert_eq(frame.released, InputFrame.Z)


func test_key_label_has_headless_fallback() -> void:
	assert_ne(KeyLabel.for_action(&"attack_z"), "?")
	assert_eq(KeyLabel.for_action(&"missing_action"), "?")


func test_debug_keys_f1_to_f4() -> void:
	var expected: Dictionary[StringName, Key] = {&"debug_overlay": KEY_F1, &"debug_pause": KEY_F2, &"debug_step": KEY_F3, &"debug_reset": KEY_F4}
	for action: StringName in expected:
		var key: InputEventKey = InputMap.action_get_events(action)[0] as InputEventKey
		assert_eq(key.physical_keycode, expected[action], "%s physical key" % action)
