class_name SimDriver
extends Node
## Steps the SimWorld exactly once per physics tick (60 Hz, see project.godot).
##
## It owns the world and exposes it read-only to view and debug nodes. Views
## read `world` to draw; they never write to it. Inputs are empty until the
## input issue (#39) adds the per-tick InputFrame collection.

## Emitted after each sim tick, with the new tick number.
signal ticked(tick: int)

## Seed of the world created when this node enters the tree.
@export var world_seed: int = 1

var world: SimWorld = SimWorld.new(1)


func _ready() -> void:
	if Engine.physics_ticks_per_second != SimUnits.TICKS_PER_SECOND:
		push_error("SimDriver: physics_ticks_per_second is %d, the sim expects %d" % [Engine.physics_ticks_per_second, SimUnits.TICKS_PER_SECOND])
	world = SimWorld.new(world_seed)


func _physics_process(_delta: float) -> void:
	step_once()


## One sim tick. Called by _physics_process; tests may call it directly.
func step_once() -> void:
	var inputs: Array[InputFrame] = _collect_inputs()
	world.step(inputs)
	ticked.emit(world.tick)


func _collect_inputs() -> Array[InputFrame]:
	return []
