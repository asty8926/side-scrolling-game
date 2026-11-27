class_name DisplayMode
extends Node
## View only: 1920x1080 base, launches in borderless fullscreen, Alt+Enter
## or F11 toggles a 1920x1080 window. Not part of the sim.

const WINDOWED_SIZE: Vector2i = Vector2i(1920, 1080)


func _ready() -> void:
	# project.godot stays windowed so headless CI is safe. The playable
	# build fills the screen on launch; Alt+Enter / F11 toggles windowed.
	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		return
	get_window().mode = Window.MODE_FULLSCREEN


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	var key: InputEventKey = event as InputEventKey
	if key == null:
		return
	var toggle: bool = key.physical_keycode == KEY_F11
	if not toggle and key.physical_keycode == KEY_ENTER and key.alt_pressed:
		toggle = true
	if not toggle:
		return
	var win: Window = get_window()
	if win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		win.mode = Window.MODE_WINDOWED
		win.size = WINDOWED_SIZE
	else:
		win.mode = Window.MODE_FULLSCREEN
	get_viewport().set_input_as_handled()
