class_name SideCamera
extends Camera3D
## Side camera in the spirit of Elsword: perspective, a fixed distance on Z,
## horizontal follow with a dead zone, and a vertical position clamped to the
## room. All values are tunable in the Inspector. View only.

## What to follow (usually the FighterView).
@export var target: Node3D
## Read-only source of the room bounds (optional: no clamp without it).
@export var driver: SimDriver
@export_group("Framing")
## Distance from the gameplay plane (z = 0), in meters.
@export_range(2.0, 40.0, 0.1, "suffix:m") var distance: float = 11.0
## Camera height above the target's feet, in meters.
@export_range(-5.0, 10.0, 0.1, "suffix:m") var height_offset: float = 2.2
## Downward tilt, in degrees.
@export_range(-30.0, 45.0, 0.5, "suffix:°") var pitch_degrees: float = 6.0
@export_group("Follow")
## Half-width of the horizontal dead zone: the target moves this far from the
## camera center before the camera follows, in meters.
@export_range(0.0, 10.0, 0.05, "suffix:m") var dead_zone_half_width: float = 1.2
## Higher = snappier follow. 0 = locked on the dead-zone edge.
@export_range(0.0, 30.0, 0.1) var horizontal_smoothing: float = 10.0
@export_range(0.0, 30.0, 0.1) var vertical_smoothing: float = 5.0
@export_group("Room clamp")
## Keep the view this far inside the room walls horizontally, in meters
## (half the visible width is a good start).
@export_range(0.0, 30.0, 0.1, "suffix:m") var wall_margin: float = 8.0
## Lowest camera height above the room floor, in meters.
@export_range(-5.0, 20.0, 0.1, "suffix:m") var min_height_above_floor: float = 2.2
## Keep the camera this far below the room top, in meters.
@export_range(0.0, 20.0, 0.1, "suffix:m") var top_margin: float = 0.0

var _focus_x: float = 0.0
var _initialized: bool = false
var _has_focus: bool = false


func _ready() -> void:
	# After the fighter view interpolates, so the camera uses this frame's target.
	process_priority = 10
	rotation_degrees = Vector3(-pitch_degrees, 0.0, 0.0)


func _process(delta: float) -> void:
	if target == null:
		return
	rotation_degrees = Vector3(-pitch_degrees, 0.0, 0.0)
	var desired: Vector3 = desired_position(target.global_position)
	if not _initialized:
		global_position = desired
		_initialized = true
		return
	global_position = Vector3(
		_smooth(global_position.x, desired.x, horizontal_smoothing, delta),
		_smooth(global_position.y, desired.y, vertical_smoothing, delta),
		desired.z)


## Where the camera wants to be for a target at `target_position`. Updates the
## dead-zone focus. Public so tests can check the framing without a window.
func desired_position(target_position: Vector3) -> Vector3:
	if not _has_focus:
		_focus_x = target_position.x
		_has_focus = true
	if target_position.x > _focus_x + dead_zone_half_width:
		_focus_x = target_position.x - dead_zone_half_width
	elif target_position.x < _focus_x - dead_zone_half_width:
		_focus_x = target_position.x + dead_zone_half_width
	var x: float = _focus_x
	var y: float = target_position.y + height_offset
	var room: RoomLayout = _room()
	if room != null:
		var left: float = SimUnits.to_meters(room.left) + wall_margin
		var right: float = SimUnits.to_meters(room.right) - wall_margin
		x = (left + right) * 0.5 if left > right else clampf(x, left, right)
		var low: float = SimUnits.to_meters(room.floor_y) + min_height_above_floor
		var high: float = maxf(low, SimUnits.to_meters(room.top) - top_margin)
		y = clampf(y, low, high)
	return Vector3(x, y, distance)


func _room() -> RoomLayout:
	if driver == null:
		return null
	return driver.world.room


static func _smooth(from: float, to: float, rate: float, delta: float) -> float:
	if rate <= 0.0:
		return to
	return lerpf(from, to, 1.0 - exp(-rate * delta))
