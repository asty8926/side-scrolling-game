class_name RoomView
extends Node3D
## Builds placeholder 3D meshes from a RoomLayout: floor, back wall, and one
## box per platform, plus a continuation past the collision edges (floor,
## back wall, and optional door hints) so the camera can stay centered on
## the player at a wall without showing the void. Purely visual: collision
## lives in the sim (sim_movement.gd).
##
## Décor (forest backdrop, wood floor, pilasters, window openings, cornice)
## is procedural and view-only.

## Read-only source of the room; the view never writes to the sim.
@export var driver: SimDriver
## Framing and "beyond the room" tunables (same file as the camera).
@export var params: CameraParams
## How deep (on Z) the floor and platforms are drawn, in meters.
@export_range(0.5, 20.0, 0.1, "suffix:m") var depth: float = 4.0
## How far behind the gameplay plane the back wall sits, in meters.
@export_range(0.5, 20.0, 0.1, "suffix:m") var back_wall_distance: float = 3.0
@export var floor_color: Color = Color(0.45, 0.34, 0.24)
@export var platform_color: Color = Color(0.58, 0.42, 0.28)
@export var wall_color: Color = Color(0.55, 0.50, 0.44)
@export var beyond_floor_color: Color = Color(0.32, 0.28, 0.22)
@export var beyond_wall_color: Color = Color(0.38, 0.34, 0.32)
@export var door_color: Color = Color(0.28, 0.22, 0.18)

const FLOOR_THICKNESS: float = 1.0
## Door opening, wide enough for the placeholder character. # ours, tune
const DOOR_WIDTH: float = 2.2
const DOOR_HEIGHT: float = 3.2
const JAMB_THICKNESS: float = 0.28
const WAINSCOT_HEIGHT: float = 1.15
const PILASTER_SPACING: float = 4.0
const BACKDROP_PARALLAX: float = 0.18

var _platform_meshes: Array[MeshInstance3D] = []
var _door_roots: Array[Node3D] = []
var _decor: Node3D
var _backdrop: MeshInstance3D
var _backdrop_home_x: float = 0.0
var _wood: StandardMaterial3D
var _wood_beyond: StandardMaterial3D
var _plaster: StandardMaterial3D
var _stone: StandardMaterial3D


func _ready() -> void:
	if driver == null:
		return
	if not driver.is_node_ready():
		await driver.ready
	var world: SimWorld = driver.world
	if world.room != null:
		build(world.room, world.tier_height)


func _process(_delta: float) -> void:
	if _backdrop == null or not is_inside_tree():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		apply_parallax(camera.global_position.x)


## Rebuilds every mesh from `layout`. `tier_height` is in sub-units.
func build(layout: RoomLayout, tier_height: int) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_platform_meshes.clear()
	_door_roots.clear()
	_decor = null
	_backdrop = null
	_ensure_materials()
	var left: float = SimUnits.to_meters(layout.left)
	var right: float = SimUnits.to_meters(layout.right)
	var floor_y: float = SimUnits.to_meters(layout.floor_y)
	var top: float = SimUnits.to_meters(layout.top)
	var width: float = right - left
	var center_x: float = (left + right) * 0.5
	var wall_height: float = top - floor_y + FLOOR_THICKNESS
	var pad: float = _beyond_edge()

	_add_box("Floor", Vector3(width, FLOOR_THICKNESS, depth), Vector3(center_x, floor_y - FLOOR_THICKNESS * 0.5, 0.0), floor_color, _wood)
	# Low wainscot so the forest backdrop shows through the window openings.
	_add_box("BackWall", Vector3(width, WAINSCOT_HEIGHT, 0.28), Vector3(center_x, floor_y + WAINSCOT_HEIGHT * 0.5, -back_wall_distance), wall_color, _plaster)

	if pad > 0.0:
		var beyond_y: float = floor_y - FLOOR_THICKNESS * 0.5
		_add_box("FloorBeyondLeft", Vector3(pad, FLOOR_THICKNESS, depth), Vector3(left - pad * 0.5, beyond_y, 0.0), beyond_floor_color, _wood_beyond)
		_add_box("FloorBeyondRight", Vector3(pad, FLOOR_THICKNESS, depth), Vector3(right + pad * 0.5, beyond_y, 0.0), beyond_floor_color, _wood_beyond)
		_add_box("BackWallBeyondLeft", Vector3(pad, WAINSCOT_HEIGHT, 0.28), Vector3(left - pad * 0.5, floor_y + WAINSCOT_HEIGHT * 0.5, -back_wall_distance), beyond_wall_color, _plaster)
		_add_box("BackWallBeyondRight", Vector3(pad, WAINSCOT_HEIGHT, 0.28), Vector3(right + pad * 0.5, floor_y + WAINSCOT_HEIGHT * 0.5, -back_wall_distance), beyond_wall_color, _plaster)

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
		var mesh: MeshInstance3D = _add_box("Platform%d" % index, size, center, color, _wood)
		_platform_meshes.append(mesh)
		# A lighter cap so the walkable top reads against the edge.
		var cap: MeshInstance3D = _add_box(
			"PlatformCap%d" % index,
			Vector3(size.x + 0.04, 0.04, size.z + 0.04),
			Vector3(center.x, platform_top + 0.01, center.z),
			color.lightened(0.18),
			_wood
		)
		# Caps are décor, not platform_meshes(); parent them under Decor after it exists.
		if _decor == null:
			_begin_decor()
		_reparent_to_decor(cap)

	_build_decor(left, right, floor_y, top, width, center_x, wall_height, pad)


## The platform meshes in RoomLayout.platforms order (one per platform).
func platform_meshes() -> Array[MeshInstance3D]:
	return _platform_meshes


## Door-hint roots (left, then right) when they are drawn.
func door_roots() -> Array[Node3D]:
	return _door_roots


## Root for procedural décor (backdrop, pilasters, cornice). Null before build.
func decor_root() -> Node3D:
	return _decor


## Shifts the far backdrop so it lags the camera (view-only parallax).
func apply_parallax(camera_x: float) -> void:
	if _backdrop != null:
		_backdrop.position.x = _backdrop_home_x + camera_x * BACKDROP_PARALLAX


func _beyond_edge() -> float:
	if params != null:
		return params.beyond_edge
	return 16.0


func _show_doors() -> bool:
	return params == null or params.show_door_hints


func _begin_decor() -> void:
	if _decor != null:
		return
	_decor = Node3D.new()
	_decor.name = "Decor"
	add_child(_decor)


func _reparent_to_decor(node: Node) -> void:
	if node.get_parent() != self:
		return
	remove_child(node)
	_decor.add_child(node)


func _build_decor(left: float, right: float, floor_y: float, top: float, width: float, center_x: float, wall_height: float, pad: float) -> void:
	_begin_decor()
	var span: float = width + pad * 2.0
	# Far forest, wide enough that a small parallax shift never shows an edge.
	var backdrop_width: float = span * 1.6
	var backdrop: MeshInstance3D = _add_plane(
		_decor,
		"ForestBackdrop",
		Vector2(backdrop_width, wall_height + 4.0),
		Vector3(center_x, floor_y + (wall_height + 4.0) * 0.4, -back_wall_distance - 8.0),
		_forest_material()
	)
	_backdrop = backdrop
	_backdrop_home_x = center_x

	# Mid hill plane, slightly closer and slower parallax is applied only to the far one.
	_add_plane(
		_decor,
		"NearHills",
		Vector2(span * 1.3, wall_height * 0.55),
		Vector3(center_x, floor_y + wall_height * 0.22, -back_wall_distance - 4.5),
		_hills_material()
	)

	var cornice_y: float = top + 0.05
	_add_box_to(
		_decor,
		"Cornice",
		Vector3(span, 0.32, 1.1),
		Vector3(center_x, cornice_y, -back_wall_distance + 0.35),
		wall_color.darkened(0.12),
		_stone
	)
	_add_box_to(
		_decor,
		"Soffit",
		Vector3(span, 0.18, depth * 0.55),
		Vector3(center_x, cornice_y + 0.2, -back_wall_distance + depth * 0.2),
		wall_color.darkened(0.2),
		_stone
	)
	# A shallow front lip so the floor edge toward the camera isn't a hard cut.
	_add_box_to(
		_decor,
		"FloorLip",
		Vector3(span, 0.18, 0.22),
		Vector3(center_x, floor_y + 0.02, depth * 0.5 + 0.05),
		floor_color.darkened(0.25),
		_wood
	)
	# Extend the boards toward the camera so the sky ground does not show as a grey band.
	_add_box_to(
		_decor,
		"FrontApron",
		Vector3(span, FLOOR_THICKNESS, 8.0),
		Vector3(center_x, floor_y - FLOOR_THICKNESS * 0.5, depth * 0.5 + 4.0),
		floor_color.darkened(0.08),
		_wood
	)

	var start_x: float = left - pad + PILASTER_SPACING * 0.5
	var end_x: float = right + pad
	var pilaster_h: float = top - floor_y + 0.15
	var x: float = start_x
	var previous: float = x
	var first: bool = true
	var pilaster_i: int = 0
	var window_i: int = 0
	while x <= end_x + 0.001:
		_add_box_to(
			_decor,
			"Pilaster%d" % pilaster_i,
			Vector3(0.42, pilaster_h, 0.55),
			Vector3(x, floor_y + pilaster_h * 0.5, -back_wall_distance + 0.18),
			wall_color.darkened(0.08),
			_stone
		)
		pilaster_i += 1
		if not first:
			var mid: float = (previous + x) * 0.5
			var gap: float = x - previous - 0.42
			# Skip a pane that would sit inside a door opening.
			var blocked: bool = absf(mid - left) < DOOR_WIDTH * 0.55 or absf(mid - right) < DOOR_WIDTH * 0.55
			if gap > 1.4 and not blocked:
				_add_box_to(
					_decor,
					"Window%d" % window_i,
					Vector3(gap * 0.72, 2.05, 0.06),
					Vector3(mid, floor_y + WAINSCOT_HEIGHT + 1.15, -back_wall_distance - 0.02),
					Color(0.55, 0.72, 0.88, 0.35),
					_window_material()
				)
				# Thin frame around the pane.
				_add_box_to(
					_decor,
					"WindowSill%d" % window_i,
					Vector3(gap * 0.8, 0.1, 0.28),
					Vector3(mid, floor_y + WAINSCOT_HEIGHT + 0.08, -back_wall_distance + 0.08),
					wall_color.darkened(0.2),
					_stone
				)
				window_i += 1
		previous = x
		first = false
		x += PILASTER_SPACING


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


func _add_box(node_name: String, size: Vector3, center: Vector3, color: Color, material: Material = null) -> MeshInstance3D:
	return _add_box_to(self, node_name, size, center, color, material)


func _add_box_to(parent: Node, node_name: String, size: Vector3, center: Vector3, color: Color, material: Material = null) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	if material != null:
		mesh.material = material
	else:
		var painted: StandardMaterial3D = StandardMaterial3D.new()
		painted.albedo_color = color
		painted.roughness = 0.9
		mesh.material = painted
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = center
	parent.add_child(instance)
	return instance


func _add_plane(parent: Node, node_name: String, size: Vector2, center: Vector3, material: Material) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	quad.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = quad
	instance.position = center
	parent.add_child(instance)
	return instance


func _ensure_materials() -> void:
	if _wood != null:
		return
	var wood_tex: ImageTexture = _wood_texture()
	_wood = _triplanar(wood_tex, Color(1, 1, 1), 0.22)
	_wood_beyond = _triplanar(wood_tex, Color(0.72, 0.74, 0.7), 0.22)
	_plaster = _triplanar(_plaster_texture(), Color(1, 1, 1), 0.35)
	_stone = _triplanar(_stone_texture(), Color(1, 1, 1), 0.28)


func _triplanar(texture: ImageTexture, tint: Color, uv_scale: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.roughness = 0.88
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_triplanar_sharpness = 4.0
	material.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	return material


func _window_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.72, 0.88, 0.28)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.12
	material.metallic = 0.05
	material.emission_enabled = true
	material.emission = Color(0.45, 0.62, 0.8)
	material.emission_energy_multiplier = 0.35
	return material


func _forest_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = _forest_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _hills_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = _hills_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _wood_texture() -> ImageTexture:
	const WIDTH: int = 256
	const HEIGHT: int = 256
	const PLANKS: int = 8
	var image: Image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var plank_w: int = WIDTH / PLANKS
	for y: int in HEIGHT:
		for x: int in WIDTH:
			var plank: int = x / plank_w
			var across: int = x % plank_w
			var base: Color = Color(0.48, 0.34, 0.22) if plank % 2 == 0 else Color(0.40, 0.29, 0.19)
			var grain: float = 0.05 * sin(float(y) * 0.18 + float(plank) * 1.7) + 0.03 * sin(float(y) * 0.7 + float(x) * 0.05)
			base = Color(clampf(base.r + grain, 0.0, 1.0), clampf(base.g + grain * 0.8, 0.0, 1.0), clampf(base.b + grain * 0.5, 0.0, 1.0))
			if across < 3 or across > plank_w - 2:
				base *= 0.55
			image.set_pixel(x, y, base)
	return ImageTexture.create_from_image(image)


func _plaster_texture() -> ImageTexture:
	const SIZE: int = 128
	var image: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in SIZE:
		for x: int in SIZE:
			var n: float = 0.04 * sin(float(x) * 0.4 + float(y) * 0.15) + 0.03 * sin(float(x + y) * 0.7)
			var color: Color = Color(0.58 + n, 0.53 + n, 0.47 + n)
			if x % 64 < 2 or y % 64 < 2:
				color *= 0.9
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _stone_texture() -> ImageTexture:
	const SIZE: int = 128
	var image: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in SIZE:
		for x: int in SIZE:
			var n: float = 0.05 * sin(float(x) * 0.25) * sin(float(y) * 0.3)
			image.set_pixel(x, y, Color(0.50 + n, 0.46 + n, 0.40 + n))
	return ImageTexture.create_from_image(image)


func _forest_texture() -> ImageTexture:
	const WIDTH: int = 1024
	const HEIGHT: int = 384
	var image: Image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Distant ridge.
	for x: int in WIDTH:
		var ridge: int = int(110.0 + 28.0 * sin(float(x) * 0.012) + 16.0 * sin(float(x) * 0.031 + 1.2))
		for y: int in range(HEIGHT - ridge, HEIGHT):
			var t: float = float(y - (HEIGHT - ridge)) / float(maxi(ridge, 1))
			var color: Color = Color(0.18, 0.28, 0.24).lerp(Color(0.10, 0.16, 0.14), t)
			color.a = 1.0
			image.set_pixel(x, y, color)
	# Trees along the ridge.
	var tree_x: int = 20
	var tree_i: int = 0
	while tree_x < WIDTH - 20:
		var trunk_w: int = 4 + (tree_i * 3) % 5
		var trunk_h: int = 28 + (tree_i * 11) % 36
		var canopy_w: int = 18 + (tree_i * 7) % 26
		var canopy_h: int = 40 + (tree_i * 13) % 50
		var ground: int = HEIGHT - 8 - (tree_i * 5) % 18
		for y: int in range(ground - trunk_h, ground):
			for x: int in range(tree_x - trunk_w / 2, tree_x + trunk_w / 2 + 1):
				if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
					image.set_pixel(x, y, Color(0.14, 0.10, 0.07, 1))
		for y: int in range(ground - trunk_h - canopy_h, ground - trunk_h + 8):
			var row: float = float(y - (ground - trunk_h - canopy_h)) / float(maxi(canopy_h, 1))
			var half: int = int(float(canopy_w) * (0.25 + 0.75 * (1.0 - absf(row * 2.0 - 1.0))))
			for x: int in range(tree_x - half, tree_x + half + 1):
				if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
					var shade: float = 0.16 + 0.06 * sin(float(tree_i) + float(x) * 0.2)
					image.set_pixel(x, y, Color(0.08, shade + 0.08, 0.10, 1))
		tree_x += 28 + (tree_i * 5) % 22
		tree_i += 1
	return ImageTexture.create_from_image(image)


func _hills_texture() -> ImageTexture:
	const WIDTH: int = 768
	const HEIGHT: int = 192
	var image: Image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x: int in WIDTH:
		var hill: int = int(70.0 + 22.0 * sin(float(x) * 0.02 + 0.4) + 10.0 * sin(float(x) * 0.05))
		for y: int in range(HEIGHT - hill, HEIGHT):
			var t: float = float(y - (HEIGHT - hill)) / float(maxi(hill, 1))
			var color: Color = Color(0.16, 0.32, 0.18).lerp(Color(0.10, 0.20, 0.12), t)
			color.a = 1.0
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
