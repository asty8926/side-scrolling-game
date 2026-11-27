class_name CombatFx
extends Node3D
## View-only hit sparks, damage numbers, dust puffs and dash trails.
##
## Reads SimWorld.events and fighter positions after each tick. Never writes
## to the sim, and does not emit new sim events.

@export var driver: SimDriver

const SPARK_DIRS: Array[Vector3] = [
	Vector3(0.55, 0.95, 0.12),
	Vector3(-0.40, 1.05, -0.10),
	Vector3(0.15, 1.20, 0.25),
	Vector3(-0.20, 0.70, -0.30),
	Vector3(0.70, 0.60, -0.08),
	Vector3(-0.65, 0.55, 0.18),
	Vector3(0.10, 0.50, 0.40),
	Vector3(-0.05, 1.10, -0.22),
]
const DUST_DIRS: Array[Vector3] = [
	Vector3(0.45, 0.35, 0.20),
	Vector3(-0.40, 0.30, -0.15),
	Vector3(0.10, 0.25, 0.35),
	Vector3(-0.15, 0.40, -0.30),
	Vector3(0.30, 0.20, -0.25),
]

var _pieces: Array[FxPiece] = []
var _trail_ticks: Dictionary[int, int] = {}


func _ready() -> void:
	if driver == null:
		return
	if not driver.is_node_ready():
		await driver.ready
	driver.ticked.connect(_on_ticked)


func _process(delta: float) -> void:
	var remaining: Array[FxPiece] = []
	for piece: FxPiece in _pieces:
		if piece.advance(delta):
			remaining.append(piece)
		else:
			piece.node.queue_free()
	_pieces = remaining


func _on_ticked(_tick: int) -> void:
	if driver != null:
		present(driver.world)


## Spawns view FX for the events and trailing fighters in `world`.
func present(world: SimWorld) -> void:
	if world == null:
		return
	for event: SimEvent in world.events:
		match event.type:
			&"hit":
				_spawn_hit(world, event)
			&"dash", &"land":
				_spawn_dust(world, event.actor)
	for fighter: SimFighter in world.fighters:
		_maybe_trail(world, fighter)


func active_count() -> int:
	return _pieces.size()


func damage_labels() -> Array[Label3D]:
	var labels: Array[Label3D] = []
	for piece: FxPiece in _pieces:
		var label: Label3D = piece.node as Label3D
		if label != null:
			labels.append(label)
	return labels


func _spawn_hit(world: SimWorld, event: SimEvent) -> void:
	var target: SimFighter = _fighter_by_id(world, event.target)
	if target == null:
		return
	var height: float = _body_height(world)
	var origin: Vector3 = SimUnits.to_vector3(target.x, target.y) + Vector3(0.0, height * 0.62, 0.0)
	var kick: bool = not String(event.move_id).contains("x")
	var spark_color: Color = Color(1.0, 0.82, 0.35) if kick else Color(0.65, 0.90, 1.0)
	for direction: Vector3 in SPARK_DIRS:
		var spark: MeshInstance3D = _box_bit(Vector3(0.10, 0.04, 0.04), spark_color)
		spark.position = origin
		add_child(spark)
		_pieces.append(FxPiece.new(spark, direction * 6.5, 14.0, 0.22, spark_color, Vector3(1.0, 1.0, 1.0), Vector3(0.15, 0.15, 0.15)))
	if event.damage > 0:
		var label: Label3D = Label3D.new()
		label.name = "DamageNumber"
		label.text = str(event.damage)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.pixel_size = 0.008
		label.font_size = 64
		label.outline_size = 16
		label.modulate = Color(1.0, 0.92, 0.45)
		label.outline_modulate = Color(0.18, 0.08, 0.02, 0.9)
		label.position = origin + Vector3(0.0, 0.45, 0.15)
		add_child(label)
		_pieces.append(FxPiece.new(label, Vector3(0.0, 1.6, 0.0), 0.0, 0.7, label.modulate, Vector3(1.0, 1.0, 1.0), Vector3(0.7, 0.7, 0.7)))


func _spawn_dust(world: SimWorld, actor_id: int) -> void:
	var fighter: SimFighter = _fighter_by_id(world, actor_id)
	if fighter == null:
		return
	var origin: Vector3 = SimUnits.to_vector3(fighter.x, fighter.y) + Vector3(0.0, 0.06, 0.0)
	var color: Color = Color(0.55, 0.46, 0.32, 0.7)
	for direction: Vector3 in DUST_DIRS:
		var puff: MeshInstance3D = _box_bit(Vector3(0.22, 0.08, 0.18), color)
		puff.position = origin
		add_child(puff)
		_pieces.append(FxPiece.new(puff, direction * 1.8, 2.5, 0.35, color, Vector3(1.0, 1.0, 1.0), Vector3(2.2, 0.6, 2.2)))


func _maybe_trail(world: SimWorld, fighter: SimFighter) -> void:
	if not _should_trail(world, fighter):
		_trail_ticks.erase(fighter.id)
		return
	var ticks: int = 0
	if _trail_ticks.has(fighter.id):
		ticks = _trail_ticks[fighter.id]
	ticks += 1
	_trail_ticks[fighter.id] = ticks
	if ticks % 2 != 0:
		return
	var height: float = _body_height(world)
	var color: Color = Color(0.55, 0.75, 1.0, 0.35)
	var ghost: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.height = height
	capsule.radius = minf(0.3, height * 0.25)
	capsule.material = _unshaded(color)
	ghost.mesh = capsule
	ghost.position = SimUnits.to_vector3(fighter.x, fighter.y) + Vector3(0.0, height * 0.5, 0.0)
	add_child(ghost)
	_pieces.append(FxPiece.new(ghost, Vector3.ZERO, 0.0, 0.18, color, Vector3(1.0, 1.0, 1.0), Vector3(0.7, 0.85, 0.7)))


func _should_trail(world: SimWorld, fighter: SimFighter) -> bool:
	if fighter.dash_dir != 0:
		return true
	var move: MoveData = SimCombat.current_move(world, fighter)
	if move != null and String(move.id).begins_with("ranger_dash"):
		return true
	return world.movement != null and absi(fighter.vx) >= (world.movement.dash_speed * 8) / 10


func _body_height(world: SimWorld) -> float:
	if world != null and world.movement != null:
		return SimUnits.to_meters(world.movement.height)
	return 1.4


func _fighter_by_id(world: SimWorld, id: int) -> SimFighter:
	for fighter: SimFighter in world.fighters:
		if fighter.id == id:
			return fighter
	return null


func _box_bit(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = _unshaded(color)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.disable_receive_shadows = true
	return material


class FxPiece extends RefCounted:
	var node: Node3D
	var velocity: Vector3
	var gravity: float
	var life: float
	var max_life: float
	var start_color: Color
	var start_scale: Vector3
	var end_scale: Vector3

	func _init(fx_node: Node3D, fx_velocity: Vector3, fx_gravity: float, fx_life: float, color: Color, from_scale: Vector3, to_scale: Vector3) -> void:
		node = fx_node
		velocity = fx_velocity
		gravity = fx_gravity
		life = fx_life
		max_life = fx_life
		start_color = color
		start_scale = from_scale
		end_scale = to_scale

	func advance(delta: float) -> bool:
		life -= delta
		if life <= 0.0 or node == null or not is_instance_valid(node):
			return false
		node.position += velocity * delta
		velocity.y -= gravity * delta
		var t: float = clampf(1.0 - life / max_life, 0.0, 1.0)
		node.scale = start_scale.lerp(end_scale, t)
		var fade: Color = start_color
		fade.a = start_color.a * (1.0 - t)
		var label: Label3D = node as Label3D
		if label != null:
			label.modulate = fade
		else:
			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			if mesh_instance != null:
				var material: StandardMaterial3D = mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
				if material == null:
					material = mesh_instance.get_active_material(0) as StandardMaterial3D
				if material != null:
					material.albedo_color = fade
		return true
