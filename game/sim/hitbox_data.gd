class_name HitboxData
extends Resource
## One attack box of a move, on the gameplay plane, in sub-units (1 m = 1000).
## Offsets are from the fighter's feet: `offset_x` points forward (mirrored
## when facing left), `offset_y` up. Active on move ticks
## [from_tick, to_tick] inclusive (tick 0 = the first tick of the move),
## which must lie inside the move's active phase.

## Center of the box, forward from the fighter. # proposal, tune
@export_range(-5000, 10000, 10, "suffix:sub") var offset_x: int = 500
## Bottom of the box above the feet. # proposal, tune
@export_range(-2000, 5000, 10, "suffix:sub") var offset_y: int = 400
## # proposal, tune
@export_range(10, 10000, 10, "suffix:sub") var width: int = 700
## # proposal, tune
@export_range(10, 5000, 10, "suffix:sub") var height: int = 600
## First move tick the box can hit. # proposal, tune
@export_range(0, 300, 1, "suffix:tick") var from_tick: int = 5
## Last move tick the box can hit (inclusive). # proposal, tune
@export_range(0, 300, 1, "suffix:tick") var to_tick: int = 7


## `first_active`..`last_active`: the move's active phase (startup ..
## startup + active - 1).
func validate(first_active: int, last_active: int) -> Array[String]:
	var problems: Array[String] = []
	if width <= 0 or height <= 0:
		problems.append("width and height must be > 0")
	if from_tick > to_tick:
		problems.append("from_tick %d is after to_tick %d" % [from_tick, to_tick])
	elif from_tick < first_active or to_tick > last_active:
		problems.append("active ticks %d..%d are outside the move's active phase (%d..%d)" % [from_tick, to_tick, first_active, last_active])
	return problems
