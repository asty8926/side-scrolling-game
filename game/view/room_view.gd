class_name RoomView
extends Node3D
## Builds placeholder 3D meshes from a RoomLayout: floor, back wall, side walls
## and one box per platform. Purely visual: collision lives in the sim
## (sim_movement.gd), which reads the same RoomLayout, so editing
## data/rooms/test_room.tres changes both after a restart.

## Read-only source of the room; the view never writes to the sim.
@export var driver: SimDriver
## How deep (on Z) the floor and platforms are drawn, in meters.
@export_range(0.5, 20.0, 0.1, "suffix:m") var depth: float = 4.0
## How far behind the gameplay plane the back wall sits, in meters.
@export_range(0.5, 20.0, 0.1, "suffix:m") var back_wall_distance: float = 3.0
@export var floor_color: Color = Color(0.36, 0.42, 0.30)
@export var platform_color: Color = Color(0.62, 0.48, 0.32)
@export var wall_color: Color = Color(0.46, 0.41, 0.37)

const FLOOR_THICKNESS: float = 1.0
const SIDE_WALL_WIDTH: float = 0.5

var _platform_meshes: Array[MeshInstance3D] = []


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
	var left: float = SimUnits.to_meters(layout.left)
	var right: float = SimUnits.to_meters(layout.right)
	var floor_y: float = SimUnits.to_meters(layout.floor_y)
	var top: float = SimUnits.to_meters(layout.top)
	var width: float = right - left
	var center_x: float = (left + right) * 0.5
	var wall_height: float = top - floor_y + FLOOR_THICKNESS

	_add_box("Floor", Vector3(width, FLOOR_THICKNESS, depth), Vector3(center_x, floor_y - FLOOR_THICKNESS * 0.5, 0.0), floor_color)
	_add_box("BackWall", Vector3(width, wall_height, 0.2), Vector3(center_x, floor_y + wall_height * 0.5 - FLOOR_THICKNESS, -back_wall_distance), wall_color)
	# Side walls run from the back wall to just in front of the gameplay plane,
	# so they mark the room edges without blocking the camera.
	var side_depth: float = back_wall_distance + 0.5
	var side_z: float = 0.5 - side_depth * 0.5
	var side_y: float = floor_y + wall_height * 0.5 - FLOOR_THICKNESS
	_add_box("LeftWall", Vector3(SIDE_WALL_WIDTH, wall_height, side_depth), Vector3(left - SIDE_WALL_WIDTH * 0.5, side_y, side_z), wall_color.darkened(0.25))
	_add_box("RightWall", Vector3(SIDE_WALL_WIDTH, wall_height, side_depth), Vector3(right + SIDE_WALL_WIDTH * 0.5, side_y, side_z), wall_color.darkened(0.25))

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


func _add_box(node_name: String, size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
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
	add_child(instance)
	return instance
