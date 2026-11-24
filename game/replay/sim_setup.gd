class_name SimSetup
extends RefCounted
## Named ways to build a SimWorld (static data + initial entities), shared by
## the game (SimDriver) and replays, so a replay always rebuilds the same world.
##
## - empty: no room, no fighters (sim core tests).
## - test_room: data/rooms/test_room.tres + data/characters/ranger_movement.tres
##   + data/input_settings.tres, one ranger (data/characters/ranger.tres) for
##   player 0 at the spawn.
## - training: test_room plus a training dummy (data/characters/dummy.tres)
##   standing DUMMY_OFFSET in front of the spawn, facing the player.

const SETUPS: Array[StringName] = [&"empty", &"test_room", &"training"]
const TEST_ROOM: String = "res://data/rooms/test_room.tres"
const RANGER_MOVEMENT: String = "res://data/characters/ranger_movement.tres"
const INPUT_SETTINGS: String = "res://data/input_settings.tres"
const RANGER: String = "res://data/characters/ranger.tres"
const DUMMY: String = "res://data/characters/dummy.tres"
## Dummy x relative to the spawn. # proposal, tune
const DUMMY_OFFSET: int = 1000


static func has_setup(setup: StringName) -> bool:
	return SETUPS.has(setup)


## Builds a world for `setup`, or null (with an error) when unknown or invalid.
static func create(setup: StringName, world_seed: int) -> SimWorld:
	match setup:
		&"empty":
			return SimWorld.new(world_seed)
		&"test_room":
			return _test_room(world_seed)
		&"training":
			return _training(world_seed)
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
	var ranger: int = world.add_character(load(RANGER) as CharacterData)
	if ranger < 0 or world.add_fighter(0, ranger) < 0:
		push_error("SimSetup: cannot add the ranger from %s" % RANGER)
		return null
	return world


static func _training(world_seed: int) -> SimWorld:
	var world: SimWorld = _test_room(world_seed)
	if world == null:
		return null
	var dummy: int = world.add_character(load(DUMMY) as CharacterData)
	var id: int = world.add_fighter(SimFighter.NO_PLAYER, dummy) if dummy >= 0 else -1
	if id < 0:
		push_error("SimSetup: cannot add the training dummy from %s" % DUMMY)
		return null
	var fighter: SimFighter = world.fighters[world.fighters.size() - 1]
	fighter.x = world.room.spawn_x + DUMMY_OFFSET
	fighter.facing = SimFighter.LEFT
	return world
