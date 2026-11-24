class_name SimSetup
extends RefCounted
## Named ways to build a SimWorld (static data + initial entities), shared by
## the game (SimDriver) and replays, so a replay always rebuilds the same world.
##
## - empty: no room, no fighters (sim core tests).
## - test_room: data/rooms/test_room.tres + data/characters/ranger_movement.tres
##   + data/input_settings.tres, one fighter for player 0 at the spawn.

const SETUPS: Array[StringName] = [&"empty", &"test_room"]
const TEST_ROOM: String = "res://data/rooms/test_room.tres"
const RANGER_MOVEMENT: String = "res://data/characters/ranger_movement.tres"
const INPUT_SETTINGS: String = "res://data/input_settings.tres"


static func has_setup(setup: StringName) -> bool:
	return SETUPS.has(setup)


## Builds a world for `setup`, or null (with an error) when unknown or invalid.
static func create(setup: StringName, world_seed: int) -> SimWorld:
	match setup:
		&"empty":
			return SimWorld.new(world_seed)
		&"test_room":
			return _test_room(world_seed)
	push_error("SimSetup: unknown setup '%s'" % setup)
	return null


static func _test_room(world_seed: int) -> SimWorld:
	var room: RoomLayout = load(TEST_ROOM) as RoomLayout
	var movement: MovementParams = load(RANGER_MOVEMENT) as MovementParams
	var settings: InputSettings = load(INPUT_SETTINGS) as InputSettings
	if room == null or movement == null or settings == null:
		push_error("SimSetup: cannot load %s, %s or %s" % [TEST_ROOM, RANGER_MOVEMENT, INPUT_SETTINGS])
		return null
	var world: SimWorld = SimWorld.new(world_seed)
	var problems: Array[String] = world.configure(room, movement, settings)
	if not problems.is_empty():
		push_error("SimSetup: invalid test room data: %s" % "; ".join(problems))
		return null
	world.add_fighter(0)
	return world
