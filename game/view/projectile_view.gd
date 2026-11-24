class_name ProjectileView
extends Node3D
## Draws the projectiles (arrows) in flight as thin boxes, interpolated between
## the last two sim ticks by projectile id. Never writes to the sim.

@export var driver: SimDriver
@export var arrow_color: Color = Color(1.0, 0.2, 0.6)

## Projectile id -> [previous, current] positions in meters.
var _tracks: Dictionary[int, PackedVector3Array] = {}
var _meshes: Dictionary[int, MeshInstance3D] = {}
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = arrow_color
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if driver == null:
		return
	if not driver.is_node_ready():
		await driver.ready
	driver.ticked.connect(_on_ticked)
	_on_ticked(0)


## Number of arrows currently drawn.
func drawn_count() -> int:
	return _meshes.size()


func _process(_delta: float) -> void:
	var fraction: float = Engine.get_physics_interpolation_fraction()
	for id: int in _meshes:
		var track: PackedVector3Array = _tracks[id]
		_meshes[id].position = track[0].lerp(track[1], fraction)


func _on_ticked(_tick: int) -> void:
	var alive: Dictionary[int, bool] = {}
	for projectile: SimProjectile in driver.world.projectiles:
		var shot: ProjectileData = SimCombat.projectile_data(driver.world, projectile)
		if shot == null:
			continue
		alive[projectile.id] = true
		var now: Vector3 = SimUnits.to_vector3(projectile.x, projectile.y + shot.height / 2)
		if _meshes.has(projectile.id):
			_tracks[projectile.id] = PackedVector3Array([_tracks[projectile.id][1], now])
		else:
			var mesh: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(SimUnits.to_meters(shot.width), SimUnits.to_meters(shot.height), 0.08)
			mesh.mesh = box
			mesh.material_override = _material
			mesh.position = now
			add_child(mesh)
			_meshes[projectile.id] = mesh
			_tracks[projectile.id] = PackedVector3Array([now, now])
	for id: int in _meshes.keys():
		if not alive.has(id):
			_meshes[id].queue_free()
			_meshes.erase(id)
			_tracks.erase(id)
