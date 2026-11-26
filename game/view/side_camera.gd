class_name SideCamera
extends Camera3D
## Side camera in the spirit of Elsword: the player stays at the screen
## center, even at a room's collision edges. View only. Tunables live in
## CameraParams (`data/view/side_camera.tres`) and hot-reload.

## What to follow (usually the FighterView).
@export var target: Node3D
## The tunables. If empty, defaults are used (tests can assign a new one).
@export var params: CameraParams

var _focus_x: float = 0.0
var _initialized: bool = false
var _has_focus: bool = false


func _ready() -> void:
	# After the fighter view interpolates, so the camera uses this frame's target.
	process_priority = 10
	apply_params()


## Applies framing from `params` (also called after a hot reload).
func apply_params() -> void:
	_ensure_params()
	fov = params.fov
	rotation_degrees = Vector3(-params.pitch_degrees, 0.0, 0.0)


func _process(delta: float) -> void:
	if target == null:
		return
	apply_params()
	var desired: Vector3 = desired_position(target.global_position)
	if not _initialized:
		global_position = desired
		_initialized = true
		return
	global_position = Vector3(
		_smooth(global_position.x, desired.x, params.horizontal_smoothing, delta),
		_smooth(global_position.y, desired.y, params.vertical_smoothing, delta),
		desired.z)


## Where the camera wants to be for a target at `target_position`. Updates the
## (optional) dead-zone focus. Public so tests can check the framing without a window.
## Never clamped to the room: the player stays centered at the walls too.
func desired_position(target_position: Vector3) -> Vector3:
	_ensure_params()
	var half: float = params.dead_zone_half_width
	if not _has_focus:
		_focus_x = target_position.x
		_has_focus = true
	if half <= 0.0:
		_focus_x = target_position.x
	elif target_position.x > _focus_x + half:
		_focus_x = target_position.x - half
	elif target_position.x < _focus_x - half:
		_focus_x = target_position.x + half
	return Vector3(_focus_x, target_position.y + params.height_offset, params.distance)


## Half of the visible width at the target's depth along the view axis, in
## meters, for the current window shape (recomputed every frame, so resizing
## is handled). `vertical_offset` is camera y minus target y.
func visible_half_width(vertical_offset: float = -1.0) -> float:
	_ensure_params()
	if vertical_offset < 0.0:
		vertical_offset = params.height_offset
	var aspect: float = 16.0 / 9.0
	if is_inside_tree():
		var view_size: Vector2 = get_viewport().get_visible_rect().size
		if view_size.x > 0.0 and view_size.y > 0.0:
			aspect = view_size.x / view_size.y
	var pitch: float = deg_to_rad(params.pitch_degrees)
	var depth: float = maxf(0.1, params.distance * cos(pitch) + vertical_offset * sin(pitch))
	var half_fov: float = tan(deg_to_rad(params.fov) * 0.5) * depth
	# KEEP_HEIGHT: fov is vertical; KEEP_WIDTH: fov is horizontal.
	return half_fov * aspect if keep_aspect == KEEP_HEIGHT else half_fov


func _ensure_params() -> void:
	if params == null:
		params = CameraParams.new()


static func _smooth(from: float, to: float, rate: float, delta: float) -> float:
	if rate <= 0.0:
		return to
	return lerpf(from, to, 1.0 - exp(-rate * delta))
