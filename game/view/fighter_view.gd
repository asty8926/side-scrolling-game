class_name FighterView
extends Node3D
## Placeholder fighter: a capsule with a nose that shows the facing.
##
## Reads one SimFighter after every sim tick and interpolates between the last
## two ticks with the physics interpolation fraction, so motion is smooth at
## any display refresh rate. Never writes to the sim.

## Read-only source of the fighter state.
@export var driver: SimDriver
## Index into SimWorld.fighters.
@export var fighter_index: int = 0
@export var body_color: Color = Color(0.25, 0.55, 0.95)
@export var nose_color: Color = Color(0.98, 0.85, 0.25)
## Seconds to turn around when the facing flips (0 = instant).
@export_range(0.0, 0.5, 0.01, "suffix:s") var turn_time: float = 0.06

var _previous: Vector3 = Vector3.ZERO
var _current: Vector3 = Vector3.ZERO
var _facing: int = SimFighter.RIGHT
var _has_state: bool = false
var _body: Node3D


func _ready() -> void:
	_build_placeholder()
	if driver == null:
		return
	if not driver.is_node_ready():
		await driver.ready
	driver.ticked.connect(_on_ticked)
	_read_state(true)


func _process(delta: float) -> void:
	if not _has_state:
		return
	var fraction: float = Engine.get_physics_interpolation_fraction()
	position = _previous.lerp(_current, fraction)
	var target_yaw: float = 0.0 if _facing == SimFighter.RIGHT else PI
	if turn_time <= 0.0:
		_body.rotation.y = target_yaw
	else:
		_body.rotation.y = lerp_angle(_body.rotation.y, target_yaw, clampf(delta / turn_time, 0.0, 1.0))


## Height of the placeholder in meters (the camera aims at its middle).
func body_height() -> float:
	if driver != null and driver.world.movement != null:
		return SimUnits.to_meters(driver.world.movement.height)
	return 1.4


func _on_ticked(_tick: int) -> void:
	_read_state(false)


func _read_state(snap: bool) -> void:
	var fighters: Array[SimFighter] = driver.world.fighters
	if fighter_index < 0 or fighter_index >= fighters.size():
		_has_state = false
		visible = false
		return
	var fighter: SimFighter = fighters[fighter_index]
	var position_now: Vector3 = SimUnits.to_vector3(fighter.x, fighter.y)
	_previous = position_now if snap or not _has_state else _current
	_current = position_now
	_facing = fighter.facing
	if not _has_state:
		position = position_now
		_body.rotation.y = 0.0 if _facing == SimFighter.RIGHT else PI
	_has_state = true
	visible = true


func _build_placeholder() -> void:
	var height: float = body_height()
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.height = height
	capsule.radius = minf(0.3, height * 0.25)
	capsule.material = _material(body_color)
	var capsule_instance: MeshInstance3D = MeshInstance3D.new()
	capsule_instance.name = "Capsule"
	capsule_instance.mesh = capsule
	capsule_instance.position = Vector3(0.0, height * 0.5, 0.0)
	_body.add_child(capsule_instance)
	var nose: BoxMesh = BoxMesh.new()
	nose.size = Vector3(0.3, 0.15, 0.2)
	nose.material = _material(nose_color)
	var nose_instance: MeshInstance3D = MeshInstance3D.new()
	nose_instance.name = "FacingNose"
	nose_instance.mesh = nose
	# Body faces +X when rotation.y == 0.
	nose_instance.position = Vector3(capsule.radius + 0.1, height * 0.75, 0.0)
	_body.add_child(nose_instance)


static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	return material
