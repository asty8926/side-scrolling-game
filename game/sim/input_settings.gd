class_name InputSettings
extends Resource
## Input timing, in sim ticks (60 per second). Edit data/input_settings.tres in
## the Inspector. Both defaults are our own proposals, not Elsword data.

## Max ticks between the two taps of `>>` / `<<` (12 ticks = 0.2 s). # proposal, tune
@export_range(1, 60, 1, "suffix:ticks") var double_tap_window_ticks: int = 12
## How many ticks early a press is remembered so the next move can use it (8 ticks = 0.13 s). # proposal, tune
@export_range(0, 60, 1, "suffix:ticks") var buffer_ticks: int = 8
## After a dash/run is released, dash attacks (`>>Z`) still start for this many
## ticks (12 ticks = 0.2 s). 0 = only while the run key is still held, or on
## the same tick as the second tap. # proposal, tune
@export_range(0, 60, 1, "suffix:ticks") var dash_attack_linger_ticks: int = 12
## After a recovery double-tap, ticks to wait before the run starts, so a
## quick opposite press (`<<>`) can flip facing in place. Footage: movement
## begins ~11 frames after a held second tap; an opposite at ~4 frames does
## not run. 10 ticks [seen]. Idle double-taps still start the run immediately.
@export_range(1, 60, 1, "suffix:ticks") var dash_confirm_ticks: int = 10


## Returns a list of problems; empty when the data is usable.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if double_tap_window_ticks < 1 or double_tap_window_ticks >= InputHistory.CAPACITY:
		problems.append("double_tap_window_ticks must be in [1, %d], got %d" % [InputHistory.CAPACITY - 1, double_tap_window_ticks])
	if buffer_ticks < 0 or buffer_ticks >= InputHistory.CAPACITY:
		problems.append("buffer_ticks must be in [0, %d], got %d" % [InputHistory.CAPACITY - 1, buffer_ticks])
	if dash_attack_linger_ticks < 0 or dash_attack_linger_ticks >= InputHistory.CAPACITY:
		problems.append("dash_attack_linger_ticks must be in [0, %d], got %d" % [InputHistory.CAPACITY - 1, dash_attack_linger_ticks])
	if dash_confirm_ticks < 1 or dash_confirm_ticks >= InputHistory.CAPACITY:
		problems.append("dash_confirm_ticks must be in [1, %d], got %d" % [InputHistory.CAPACITY - 1, dash_confirm_ticks])
	return problems
