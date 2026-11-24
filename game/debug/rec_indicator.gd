class_name RecIndicator
extends Label
## Shows "REC" and the recorded time while the ReplayRecorder (F9) records.

@export var recorder: ReplayRecorder


func _ready() -> void:
	visible = false
	add_theme_color_override(&"font_color", Color(1.0, 0.25, 0.2))


func _process(_delta: float) -> void:
	var recording: bool = recorder != null and recorder.is_recording()
	visible = recording
	if recording:
		text = "● REC  %.1f s  (F9 to stop)" % (float(recorder.recorded_ticks()) / float(SimUnits.TICKS_PER_SECOND))
