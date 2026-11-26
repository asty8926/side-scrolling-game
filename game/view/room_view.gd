class_name RoomView
extends Node3D
## Builds placeholder 3D meshes from a RoomLayout: floor, back wall, and one
## box per platform, plus a continuation past the collision edges (floor,
## back wall, and optional door hints) so the camera can stay centered on
## the player at a wall without showing the void. Purely visual: collision
## lives in the sim (sim_movement.gd).

## Read-only source of the room; the view never writes to the sim.
@export var driver: SimDriver
## Framing and "beyond the room" tunables (same file as the camera).
@export var params: CameraParams
## How deep (on Z) the floor and platforms are drawn, in meters.
@export_range(0.5, 20.0, 0.1, "suffix:m") var depth: float = 4.0
## How far behind the gameplay plane the back wall sits, in meters.
@export_range(0.5, 20.0, 0.1, "suffix:m") var back_wall_distance: float = 3.0
@export var floor_color: Color = Color(0.36, 0.42, 0.30)
@export var platform_color: Color = Color(0.62, 0.48, 0.32)
@export var wall_color: Color = Color(0.46, 0.41, 0.37)
@export var beyond_floor_color: Color = Color(0.28, 0.32, 0.24)
@export var beyond_wall_color: Color = Color(0.38, 0.34, 0.40)
@export var door_color: Color = Color(0.32, 0.28, 0.25)

const FLOOR_THICKNESS: float = 1.0
## Door opening, wide enough for the placeholder character. # ours, tune
const DOOR_WIDTH: float = 2.2
const DOOR_HEIGHT: float = 3.2
const JAMB_THICKNESS: float = 0.28

var _platform_meshes: Array[MeshInstance3D] = []
var _door_roots: Array[Node3D] = []


func _ready() -> void:
	if driver == null:
		return
	if not driver.is_node_ready():
		await driver.ready
	var world: SimWorld = driver.world
	if world.room != null:
		build(world.room, world.tier_height)


## Rebuilds every mesh from `layout`. `tier_height` is in sub-units.
func build(layout: RoomLayout, tier_height: int) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_platform_meshes.clear()
	_door_roots.clear()
	var left: float = SimUnits.to_meters(layout.left)
	var right: float = SimUnits.to_meters(layout.right)
	var floor_y: float = SimUnits.to_meters(layout.floor_y)
	var top: float = SimUnits.to_meters(layout.top)
	var width: float = right - left
	var center_x: float = (left + right) * 0.5
	var wall_height: float = top - floor_y + FLOOR_THICKNESS
	var pad: float = _beyond_edge()

	_add_box("Floor", Vector3(width, FLOOR_THICKNESS, depth), Vector3(center_x, floor_y - FLOOR_THICKNESS * 0.5, 0.0), floor_color)
	_add_box("BackWall", Vector3(width, wall_height, 0.2), Vector3(center_x, floor_y + wall_height * 0.5 - FLOOR_THICKNESS, -back_wall_distance), wall_color)

	# Floor and back wall continue past the collision edges, slightly recolored
	# so the next-room hint reads as a different space.
	if pad > 0.0:
		var beyond_y: float = floor_y - FLOOR_THICKNESS * 0.5
		var wall_y: float = floor_y + wall_height * 0.5 - FLOOR_THICKNESS
		_add_box("FloorBeyondLeft", Vector3(pad, FLOOR_THICKNESS, depth), Vector3(left - pad * 0.5, beyond_y, 0.0), beyond_floor_color)
		_add_box("FloorBeyondRight", Vector3(pad, FLOOR_THICKNESS, depth), Vector3(right + pad * 0.5, beyond_y, 0.0), beyond_floor_color)
		_add_box("BackWallBeyondLeft", Vector3(pad, wall_height, 0.2), Vector3(left - pad * 0.5, wall_y, -back_wall_distance), beyond_wall_color)
		_add_box("BackWallBeyondRight", Vector3(pad, wall_height, 0.2), Vector3(right + pad * 0.5, wall_y, -back_wall_distance), beyond_wall_color)

	if _show_doors():
		_add_door("LeftDoor", left, floor_y)
		_add_door("RightDoor", right, floor_y)

	for index: int in layout.platforms.size():
		var platform: RoomPlatform = layout.platforms[index]
		var platform_top: float = SimUnits.to_meters(platform.top(layout.floor_y, tier_height))
		var thickness: float = SimUnits.to_meters(platform.thickness)
		var size: Vector3 = Vector3(SimUnits.to_meters(platform.width), thickness, depth * 0.75)
		var center: Vector3 = Vector3(SimUnits.to_meters(platform.x), platform_top - thickness * 0.5, 0.0)
		var color: Color = platform_color.lightened(0.08 * float(platform.tier - 1))
		_platform_meshes.append(_add_box("Platform%d" % index, size, center, color))


## The platform meshes in RoomLayout.platforms order (one per platform).
func platform_meshes() -> Array[MeshInstance3D]:
	return _platform_meshes


## Door-hint roots (left, then right) when they are drawn.
func door_roots() -> Array[Node3D]:
	return _door_roots


func _beyond_edge() -> float:
	if params != null:
		return params.beyond_edge
	return 16.0


func _show_doors() -> bool:
	return params == null or params.show_door_hints


## A door frame on the collision line: two jambs and a lintel. The continued
## floor and back wall show through the opening as a hint of the next room.
func _add_door(node_name: String, x: float, floor_y: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = node_name
	add_child(root)
	_door_roots.append(root)
	var side_depth: float = back_wall_distance + 0.5
	var side_z: float = 0.5 - side_depth * 0.5
	var half: float = DOOR_WIDTH * 0.5
	var jamb_h: float = DOOR_HEIGHT
	_add_box_to(root, "JambLeft", Vector3(JAMB_THICKNESS, jamb_h, side_depth), Vector3(x - half, floor_y + jamb_h * 0.5, side_z), door_color)
	_add_box_to(root, "JambRight", Vector3(JAMB_THICKNESS, jamb_h, side_depth), Vector3(x + half, floor_y + jamb_h * 0.5, side_z), door_color)
	_add_box_to(root, "Lintel", Vector3(DOOR_WIDTH + JAMB_THICKNESS, JAMB_THICKNESS, side_depth), Vector3(x, floor_y + jamb_h + JAMB_THICKNESS * 0.5, side_z), door_color)


func _add_box(node_name: String, size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
	return _add_box_to(self, node_name, size, center, color)


func _add_box_to(parent: Node, node_name: String, size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = center
	parent.add_child(instance)
	return instance
