extends GutTest
## RoomView builds its meshes from the RoomLayout Resource (issue #42).

const TEST_ROOM: String = "res://data/rooms/test_room.tres"
const MOVEMENT: String = "res://data/characters/ranger_movement.tres"


func _build(layout: RoomLayout) -> RoomView:
	var movement: MovementParams = load(MOVEMENT) as MovementParams
	var view: RoomView = RoomView.new()
	add_child_autofree(view)
	view.build(layout, layout.tier_height(movement))
	return view


func test_one_mesh_per_platform() -> void:
	var layout: RoomLayout = load(TEST_ROOM) as RoomLayout
	var view: RoomView = _build(layout)
	assert_gt(layout.platforms.size(), 0, "the test room has platforms")
	assert_eq(view.platform_meshes().size(), layout.platforms.size(), "one mesh per platform")
	for index: int in layout.platforms.size():
		var box: BoxMesh = view.platform_meshes()[index].mesh as BoxMesh
		assert_not_null(box, "platform %d is a box" % index)
		assert_almost_eq(box.size.x, SimUnits.to_meters(layout.platforms[index].width), 0.0001, "platform %d width follows the layout" % index)


func test_edited_layout_changes_the_meshes() -> void:
	var layout: RoomLayout = (load(TEST_ROOM) as RoomLayout).duplicate(true) as RoomLayout
	var extra: RoomPlatform = RoomPlatform.new()
	extra.x = -9000
	extra.tier = 2
	extra.width = 2000
	layout.platforms.append(extra)
	var view: RoomView = _build(layout)
	var meshes: Array[MeshInstance3D] = view.platform_meshes()
	assert_eq(meshes.size(), layout.platforms.size(), "added platform gets a mesh")
	var last: MeshInstance3D = meshes[meshes.size() - 1]
	assert_almost_eq(last.position.x, -9.0, 0.0001, "mesh sits at the platform x")
	var movement: MovementParams = load(MOVEMENT) as MovementParams
	var top: float = SimUnits.to_meters(extra.top(layout.floor_y, layout.tier_height(movement)))
	var box: BoxMesh = last.mesh as BoxMesh
	assert_almost_eq(last.position.y + box.size.y * 0.5, top, 0.0001, "mesh top is the collision top")


func test_rebuild_replaces_old_meshes() -> void:
	var layout: RoomLayout = load(TEST_ROOM) as RoomLayout
	var view: RoomView = _build(layout)
	var movement: MovementParams = load(MOVEMENT) as MovementParams
	view.build(layout, layout.tier_height(movement))
	await wait_physics_frames(1)
	assert_eq(view.get_child_count(), layout.platforms.size() + 4, "floor, back wall, two side walls and the platforms")


func test_camera_dead_zone_and_room_clamp() -> void:
	var camera: SideCamera = SideCamera.new()
	add_child_autofree(camera)
	camera.dead_zone_half_width = 1.0
	camera.wall_margin = 0.0
	var start: Vector3 = camera.desired_position(Vector3.ZERO)
	assert_almost_eq(start.x, 0.0, 0.0001)
	assert_almost_eq(camera.desired_position(Vector3(0.8, 0.0, 0.0)).x, 0.0, 0.0001, "inside the dead zone the camera stays")
	assert_almost_eq(camera.desired_position(Vector3(3.0, 0.0, 0.0)).x, 2.0, 0.0001, "past the dead zone it follows at the edge")
	assert_almost_eq(camera.desired_position(Vector3(3.0, 0.0, 0.0)).z, camera.distance, 0.0001, "fixed distance on Z")


func test_wall_margin_shrinks_in_narrow_windows() -> void:
	var camera: SideCamera = SideCamera.new()
	add_child_autofree(camera)
	camera.wall_margin = 8.0
	camera.edge_padding = 1.0
	var half: float = camera.visible_half_width()
	assert_gt(half, 0.0)
	assert_almost_eq(camera.effective_wall_margin(), minf(8.0, half - 1.0), 0.0001, "margin never pushes the wall-side fighter off screen")
	assert_lte(camera.effective_wall_margin() + 1.0, half + 0.0001)
