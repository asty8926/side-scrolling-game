class_name MovementParams
extends Resource
## Integer fixed-point movement tuning, in sub-units (1 m = 1000) and ticks
## (60/s). All defaults are our proposals, not Elsword data. Edit the .tres
## in the Inspector, restart to apply (hot reload is #44).

@export_group("Ground movement")
## Sub-units per tick. # proposal, tune
@export_range(1, 1000, 1, "suffix:sub/tick") var walk_speed: int = 65
## Sub-units per tick. # proposal, tune
@export_range(1, 1500, 1, "suffix:sub/tick") var dash_speed: int = 150
@export_group("Jump")
## Upward sub-units per tick when jumping. # proposal, tune
@export_range(1, 1000, 1, "suffix:sub/tick") var jump_velocity: int = 230
## Second jump in the air. # proposal, tune
@export_range(1, 1000, 1, "suffix:sub/tick") var double_jump_velocity: int = 230
## Sub-units per tick per tick. # proposal, tune
@export_range(1, 100, 1, "suffix:sub/tick²") var gravity: int = 10
## Max downward sub-units per tick. # proposal, tune
@export_range(1, 1000, 1, "suffix:sub/tick") var max_fall_speed: int = 300
@export_group("Collision")
## Pushbox half-width (x is its center, y its feet). # proposal, tune
@export_range(1, 2000, 1, "suffix:sub") var half_width: int = 300
## Pushbox height. # proposal, tune
@export_range(1, 4000, 1, "suffix:sub") var height: int = 1400
## Ticks of ignoring the platform after pressing down. # proposal, tune
@export_range(1, 60, 1, "suffix:ticks") var drop_ticks: int = 12


func validate() -> Array[String]:
	var problems: Array[String] = []
	if walk_speed <= 0 or dash_speed < walk_speed:
		problems.append("walk_speed must be > 0 and dash_speed >= walk_speed")
	if jump_velocity <= 0 or double_jump_velocity <= 0 or gravity <= 0 or max_fall_speed <= 0:
		problems.append("jump velocities, gravity and max_fall_speed must be > 0")
	elif jump_velocity <= gravity:
		problems.append("jump_velocity must be > gravity, or a jump never leaves the ground")
	if half_width <= 0 or height <= 0 or drop_ticks < 1:
		problems.append("half_width, height and drop_ticks must be > 0")
	return problems


## Peak height above takeoff, with the same discrete integration as the sim.
func single_jump_height() -> int:
	var y: int = 0
	var vy: int = jump_velocity
	while vy > 0:
		vy -= gravity
		y += maxi(vy, 0)
	return y
