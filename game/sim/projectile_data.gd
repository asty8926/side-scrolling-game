class_name ProjectileData
extends Resource
## One projectile (an arrow) a move fires, in sub-units and ticks. It flies
## straight in the facing direction at `speed`, hits the first hurtbox it
## overlaps (with the move's damage, hitstun and KD), then disappears; it also
## disappears at a room wall or after `lifetime_ticks`.

## Move tick it is fired on (inside the move's active phase). # proposal, tune
@export_range(0, 300, 1, "suffix:tick") var spawn_tick: int = 6
## Spawn point forward from the shooter's feet. # proposal, tune
@export_range(-2000, 5000, 10, "suffix:sub") var offset_x: int = 400
## Spawn height above the shooter's feet. # proposal, tune
@export_range(0, 5000, 10, "suffix:sub") var offset_y: int = 800
## Sub-units per tick (400 = 24 m/s). # proposal, tune
@export_range(1, 3000, 10, "suffix:sub/tick") var speed: int = 400
## Ticks before it vanishes. # proposal, tune
@export_range(1, 600, 1, "suffix:ticks") var lifetime_ticks: int = 30
## # proposal, tune
@export_range(10, 5000, 10, "suffix:sub") var width: int = 500
## # proposal, tune
@export_range(10, 2000, 10, "suffix:sub") var height: int = 120


func validate(first_active: int, last_active: int) -> Array[String]:
	var problems: Array[String] = []
	if speed <= 0 or lifetime_ticks < 1 or width <= 0 or height <= 0:
		problems.append("speed, lifetime_ticks, width and height must be > 0")
	if spawn_tick < first_active or spawn_tick > last_active:
		problems.append("spawn_tick %d is outside the move's active phase (%d..%d)" % [spawn_tick, first_active, last_active])
	return problems
