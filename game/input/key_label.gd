class_name KeyLabel
extends RefCounted
## UI labels for physical bindings. Recompute when drawing the UI so changing
## the OS keyboard layout while the game runs updates W <-> Z correctly.


static func for_action(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: InputEventKey = event as InputEventKey
			return for_physical(key.physical_keycode)
	return "?"


static func for_physical(physical: Key) -> String:
	# The headless display server has no keyboard layout. Don't call the OS
	# method there (Godot pushes an error); use the US physical label in tests.
	if DisplayServer.get_name() == "headless":
		return OS.get_keycode_string(physical)
	var label: Key = DisplayServer.keyboard_get_label_from_physical(physical)
	return OS.get_keycode_string(label)
