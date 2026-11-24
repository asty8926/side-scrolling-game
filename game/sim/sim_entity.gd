class_name SimEntity
extends RefCounted
## One thing that exists in the simulation (later: players, mobs, projectiles).
## Plain integer data only (see SimUnits). Behaviour is added by later issues.

var id: int = 0
## Position on the gameplay plane, in sub-units (x right, y up).
var x: int = 0
var y: int = 0
## Velocity in sub-units per tick.
var vx: int = 0
var vy: int = 0


func _init(pos_x: int = 0, pos_y: int = 0, vel_x: int = 0, vel_y: int = 0) -> void:
	x = pos_x
	y = pos_y
	vx = vel_x
	vy = vel_y
