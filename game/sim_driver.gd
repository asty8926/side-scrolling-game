class_name SimDriver
extends Node
## Steps the SimWorld exactly once per physics tick (60 Hz, see project.godot).
##
## It owns the world and exposes it read-only to view and debug nodes. Views
## read `world` to draw; they never write to it.
## InputSampler builds each per-tick InputFrame before the sim step.

## Emitted after each sim tick, with the new tick number.
signal ticked(tick: int)
## Emitted after each sim tick with the input frames that tick consumed.
signal stepped(frames: Array[InputFrame])

## Seed of the world created when this node enters the tree.
@export var world_seed: int = 1
## Which SimSetup builds the world (static data + initial entities).
@export var setup: StringName = &"test_room"

var world: SimWorld = SimWorld.new(1)
var input_settings: InputSettings
var _sampler: InputSampler


func _ready() -> void:
	if Engine.physics_ticks_per_second != SimUnits.TICKS_PER_SECOND:
		push_error("SimDriver: physics_ticks_per_second is %d, the sim expects %d" % [Engine.physics_ticks_per_second, SimUnits.TICKS_PER_SECOND])
	var created: SimWorld = SimSetup.create(setup, world_seed)
	if created == null:
		set_physics_process(false)
		return
	world = created
	input_settings = load("res://data/input_settings.tres") as InputSettings
	if input_settings == null:
		push_error("SimDriver: failed to load res://data/input_settings.tres")
		set_physics_process(false)
		return
	var problems: Array[String] = input_settings.validate()
	if not problems.is_empty():
		push_error("SimDriver: invalid input settings: %s" % "; ".join(problems))
		set_physics_process(false)
		return
	_sampler = InputSampler.new()
	add_child(_sampler)


func _physics_process(_delta: float) -> void:
	step_once()


## One sim tick. Called by _physics_process; tests may call it directly.
func step_once() -> void:
	var inputs: Array[InputFrame] = _collect_inputs()
	world.step(inputs)
	ticked.emit(world.tick)
	stepped.emit(inputs)


func _collect_inputs() -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	if _sampler != null:
		frames.append(_sampler.sample_tick())
	return frames
