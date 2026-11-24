class_name SimSetup
extends RefCounted
## Named ways to build a SimWorld (static data + initial entities), shared by
## the game (SimDriver) and replays, so a replay always rebuilds the same world.

const SETUPS: Array[StringName] = [&"empty"]


static func has_setup(setup: StringName) -> bool:
	return SETUPS.has(setup)


## Builds a world for `setup`, or null (with an error) when unknown.
static func create(setup: StringName, world_seed: int) -> SimWorld:
	match setup:
		&"empty":
			return SimWorld.new(world_seed)
	push_error("SimSetup: unknown setup '%s'" % setup)
	return null
