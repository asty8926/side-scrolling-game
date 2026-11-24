class_name ReloadToast
extends Label
## Short on-screen message after each data hot reload (green = applied,
## red = rejected, with the problems).

@export var reloader: DataReloader
## Seconds a success message stays.
@export var ok_seconds: float = 2.0
## Seconds an error message stays.
@export var error_seconds: float = 8.0

var _left: float = 0.0
var _showing_error: bool = false


func _ready() -> void:
	visible = false
	add_theme_constant_override(&"outline_size", 6)
	add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	if reloader != null:
		reloader.reloaded.connect(_on_reloaded)


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		visible = false
		_showing_error = false


func _on_reloaded(path: String, problems: Array[String]) -> void:
	var line: String = "Reloaded %s" % path.get_file()
	if not problems.is_empty():
		line = "%s NOT reloaded (old values kept):\n- %s" % [path.get_file(), "\n- ".join(problems)]
	if _showing_error and _left > 0.0:
		# Never hide a rejected file behind a later message: add a line instead.
		text += "\n" + line
		if not problems.is_empty():
			_left = error_seconds
		return
	visible = true
	text = line
	_showing_error = not problems.is_empty()
	if _showing_error:
		add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.35))
		_left = error_seconds
	else:
		add_theme_color_override(&"font_color", Color(0.45, 1.0, 0.5))
		_left = ok_seconds
