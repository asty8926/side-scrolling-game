class_name CameraParams
extends Resource
## View-only side-camera and room-edge presentation. Not part of the sim.
## Edit data/view/side_camera.tres and save: DataReloader picks it up.
## Footage (docs/reference/camera.md): Elsword keeps the player at the
## screen center, with no useful lead/lag and no clamp at room walls.

@export_group("Framing")
## Distance from the gameplay plane (z = 0), in meters. # proposal, tune
@export_range(2.0, 40.0, 0.1, "suffix:m") var distance: float = 11.0
## Camera height above the target's feet, in meters. # proposal, tune
@export_range(-5.0, 10.0, 0.1, "suffix:m") var height_offset: float = 2.2
## Downward tilt, in degrees. # proposal, tune
@export_range(-30.0, 45.0, 0.5, "suffix:°") var pitch_degrees: float = 6.0
## Vertical field of view, in degrees. # proposal, tune
@export_range(20.0, 90.0, 0.5, "suffix:°") var fov: float = 50.0

@export_group("Follow")
## Half-width of a horizontal dead zone, in meters. Footage shows ~0, so the
## default is 0 (the player stays at the screen center). # est, tune
@export_range(0.0, 10.0, 0.05, "suffix:m") var dead_zone_half_width: float = 0.0
## Higher = snappier follow. 0 = locked on the target (or the dead-zone
## focus). Footage shows ~0 lead/lag, so the default is 0. # est, tune
@export_range(0.0, 30.0, 0.1) var horizontal_smoothing: float = 0.0
@export_range(0.0, 30.0, 0.1) var vertical_smoothing: float = 0.0

@export_group("Beyond the room")
## How far the floor and back wall continue past the collision edges, in
## meters. Should cover at least a visible half-width so the void never
## appears when the player is against a wall. # ours, tune
@export_range(0.0, 40.0, 0.1, "suffix:m") var beyond_edge: float = 16.0
## Door frames at the collision edges, with a hint of the next room
## visible through them. # ours
@export var show_door_hints: bool = true

@export_group("Shake")
## Peak offset in meters on a heavy hit. 0 disables. View only. # ours
@export_range(0.0, 0.5, 0.005, "suffix:m") var shake_amplitude: float = 0.08
## How quickly the shake dies out (higher = shorter). # ours
@export_range(0.0, 40.0, 0.1) var shake_decay: float = 18.0


## Returns the problems; empty when the data is usable.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if distance <= 0.0:
		problems.append("distance must be > 0")
	if fov < 20.0 or fov > 90.0:
		problems.append("fov must be in [20, 90], got %s" % fov)
	if dead_zone_half_width < 0.0 or horizontal_smoothing < 0.0 or vertical_smoothing < 0.0:
		problems.append("dead_zone_half_width and smoothing must be >= 0")
	if beyond_edge < 0.0:
		problems.append("beyond_edge must be >= 0")
	if shake_amplitude < 0.0 or shake_decay < 0.0:
		problems.append("shake_amplitude and shake_decay must be >= 0")
	return problems
