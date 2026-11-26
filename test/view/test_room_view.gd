extends GutTest
## RoomView builds its meshes from the RoomLayout Resource (issue #42).
## SideCamera framing follows CameraParams (player stays centered; no wall clamp).

const TEST_ROOM: String = "res://data/rooms/test_room.tres"
const MOVEMENT: String = "res://data/characters/ranger_movement.tres"
const CAMERA: String = "res://data/view/side_camera.tres"


func _build(layout: RoomLayout, params: CameraParams = null) -> RoomView:
	var movement: MovementParams = load(MOVEMENT) as MovementParams
	var view: RoomView = RoomView.new()
	add_child_autofree(view)
	view.params = params
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
	# Floor, back wall, 4 beyond meshes, 2 door roots, and the platforms.
	assert_eq(view.get_child_count(), layout.platforms.size() + 8, "room, beyond, doors and the platforms")


func test_floor_and_back_wall_continue_past_the_collision_edges() -> void:
	var layout: RoomLayout = load(TEST_ROOM) as RoomLayout
	var params: CameraParams = CameraParams.new()
	params.beyond_edge = 16.0
	params.show_door_hints = true
	var view: RoomView = _build(layout, params)
	var left: float = SimUnits.to_meters(layout.left)
	var floor_beyond: MeshInstance3D = view.get_node("FloorBeyondLeft") as MeshInstance3D
	var wall_beyond: MeshInstance3D = view.get_node("BackWallBeyondLeft") as MeshInstance3D
	assert_not_null(floor_beyond, "a floor continues past the left edge")
	assert_not_null(wall_beyond, "a back wall continues past the left edge")
	var floor_box: BoxMesh = floor_beyond.mesh as BoxMesh
	assert_almost_eq(floor_box.size.x, 16.0, 0.0001)
	assert_almost_eq(floor_beyond.position.x, left - 8.0, 0.0001, "the beyond floor sits just past the collision edge")
	assert_eq(view.door_roots().size(), 2, "a door hint at each edge")
	assert_eq(view.door_roots()[0].name, "LeftDoor")
	var jamb: Node3D = view.get_node("LeftDoor/JambLeft") as Node3D
	assert_not_null(jamb)
	assert_almost_eq(jamb.position.x, left - RoomView.DOOR_WIDTH * 0.5, 0.0001)


func test_camera_stays_centered_on_the_player() -> void:
	var camera: SideCamera = SideCamera.new()
	add_child_autofree(camera)
	camera.params = CameraParams.new()
	camera.params.dead_zone_half_width = 0.0
	camera.params.height_offset = 2.2
	camera.params.distance = 11.0
	var at_origin: Vector3 = camera.desired_position(Vector3.ZERO)
	assert_almost_eq(at_origin.x, 0.0, 0.0001)
	assert_almost_eq(at_origin.y, 2.2, 0.0001)
	assert_almost_eq(at_origin.z, 11.0, 0.0001)
	var far: Vector3 = camera.desired_position(Vector3(20.0, 3.0, 0.0))
	assert_almost_eq(far.x, 20.0, 0.0001, "no dead zone: the camera x equals the player x")
	assert_almost_eq(far.y, 5.2, 0.0001, "the camera follows jump height")


func test_camera_does_not_clamp_at_the_room_edges() -> void:
	# The test room walls are at ±12 m; a 1.2 m dead zone plus a wall clamp
	# used to pin the camera before the player reached the edge.
	var camera: SideCamera = SideCamera.new()
	add_child_autofree(camera)
	camera.params = load(CAMERA) as CameraParams
	var edge: Vector3 = camera.desired_position(Vector3(-12.0, 0.0, 0.0))
	assert_almost_eq(edge.x, -12.0, 0.0001, "at the left wall the player is still centered")
	var other: Vector3 = camera.desired_position(Vector3(12.0, 0.0, 0.0))
	assert_almost_eq(other.x, 12.0, 0.0001, "at the right wall the player is still centered")


func test_optional_dead_zone_still_follows_at_its_edge() -> void:
	var camera: SideCamera = SideCamera.new()
	add_child_autofree(camera)
	camera.params = CameraParams.new()
	camera.params.dead_zone_half_width = 1.0
	assert_almost_eq(camera.desired_position(Vector3.ZERO).x, 0.0, 0.0001)
	assert_almost_eq(camera.desired_position(Vector3(0.8, 0.0, 0.0)).x, 0.0, 0.0001, "inside the dead zone the camera stays")
	assert_almost_eq(camera.desired_position(Vector3(3.0, 0.0, 0.0)).x, 2.0, 0.0001, "past the dead zone it follows at the edge")


func test_visible_half_width_shrinks_at_a_steep_pitch() -> void:
	var camera: SideCamera = SideCamera.new()
	add_child_autofree(camera)
	camera.params = CameraParams.new()
	camera.params.pitch_degrees = -30.0
	var flat: SideCamera = SideCamera.new()
	add_child_autofree(flat)
	flat.params = CameraParams.new()
	flat.params.pitch_degrees = 0.0
	assert_lt(camera.visible_half_width(), flat.visible_half_width(), "looking up from above the target sees less width at its depth")


func test_committed_camera_params_validate_and_lock_to_center() -> void:
	var params: CameraParams = load(CAMERA) as CameraParams
	assert_eq(params.validate(), [] as Array[String])
	assert_almost_eq(params.dead_zone_half_width, 0.0, 0.0001)
	assert_almost_eq(params.horizontal_smoothing, 0.0, 0.0001)
	assert_gt(params.beyond_edge, 8.0, "the continuation covers at least a typical half-screen")
	assert_true(params.show_door_hints)


func test_shake_decay_must_be_positive_when_shake_is_enabled() -> void:
	var params: CameraParams = CameraParams.new()
	params.shake_amplitude = 0.08
	params.shake_decay = 0.0
	var problems: Array[String] = params.validate()
	assert_gt(problems.size(), 0, "zero decay with a non-zero amplitude is rejected")
	params.shake_decay = 18.0
	assert_eq(params.validate(), [] as Array[String])
	params.shake_amplitude = 0.0
	params.shake_decay = 0.0
	assert_eq(params.validate(), [] as Array[String], "disabled shake may have zero decay")


func test_invalid_camera_params_are_rejected_on_apply() -> void:
	var camera: SideCamera = SideCamera.new()
	add_child_autofree(camera)
	var bad: CameraParams = CameraParams.new()
	bad.shake_amplitude = 0.08
	bad.shake_decay = 0.0
	camera.params = bad
	camera.apply_params()
	assert_push_error_count(1)
	assert_gt(camera.params.shake_decay, 0.0, "invalid params are replaced with defaults")
	assert_eq(camera.params.validate(), [] as Array[String])
