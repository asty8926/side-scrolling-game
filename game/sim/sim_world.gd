class_name SimWorld
extends RefCounted
## The deterministic simulation. Advances one fixed tick (1/60 s) per step().
##
## Rules (docs/roadmap.md "Determinism rule", AGENTS.md section 3):
## - The only input is the per-player InputFrame list given to step().
## - No scene tree, no nodes, no wall clock, no global random: randomness comes
##   from `rng` (seeded, part of the state).
## - All state is integers (SimUnits fixed-point). Entities live in an Array in
##   insertion order; never iterate a Dictionary for gameplay.
## - Everything that matters is written by snapshot() in a fixed field order,
##   so state_hash() changes if and only if the state changes.

## Snapshot header. Bump SNAPSHOT_VERSION whenever the field list changes.
const SNAPSHOT_MAGIC: int = 0x57534D53  # "SMSW"
const SNAPSHOT_VERSION: int = 2
## Players a world accepts input from (party of up to 4).
const MAX_PLAYERS: int = 4

## Ticks stepped since the world was created.
var tick: int = 0
## Seed this world was created with (kept for replays and debugging).
var world_seed: int = 0
## The sim-owned random generator. Only sim code may draw from it.
var rng: SimRng
## Rolling digest of every input frame consumed, so two runs that received
## different inputs never share a hash (early replay desync detection).
var input_digest: int = 0
## Recent input frames per player index (index = InputFrame.player). Grows
## when a new player index first sends input; every known player gets one
## frame per tick (an empty one when nothing was sent).
var histories: Array[InputHistory] = []
## Entities in stable insertion order.
var entities: Array[SimEntity] = []
var _next_entity_id: int = 1


func _init(seed_value: int = 1) -> void:
	world_seed = seed_value
	rng = SimRng.new(seed_value)


## Adds an entity, gives it the next id and returns that id.
## Adding the same entity object twice is an error and returns -1.
func add_entity(entity: SimEntity) -> int:
	if entities.has(entity):
		push_error("SimWorld.add_entity: entity %d is already in the world" % entity.id)
		return -1
	entity.id = _next_entity_id
	_next_entity_id += 1
	entities.append(entity)
	return entity.id


## Advances the simulation by exactly one tick.
## `inputs` may be in any order: frames are applied sorted by player index.
## Invalid frames (player outside [0, MAX_PLAYERS), unknown button bits, a
## second frame for the same player) are reported and ignored.
func step(inputs: Array[InputFrame]) -> void:
	var ordered: Array[InputFrame] = []
	for frame: InputFrame in inputs:
		if frame.player < 0 or frame.player >= MAX_PLAYERS or not frame.is_valid():
			push_error("SimWorld.step: invalid input frame (player %d, held %d, pressed %d, released %d) at tick %d" % [frame.player, frame.held, frame.pressed, frame.released, tick])
			continue
		ordered.append(frame)
	ordered.sort_custom(_input_before)
	var by_player: Array[InputFrame] = []
	for frame: InputFrame in ordered:
		if by_player.size() > 0 and by_player[-1].player == frame.player:
			push_error("SimWorld.step: two input frames for player %d at tick %d, keeping the first" % [frame.player, tick])
			continue
		by_player.append(frame)

	# Tick and frame count first, so moving or dropping a frame changes the digest.
	input_digest = _fold(input_digest, tick)
	input_digest = _fold(input_digest, by_player.size())
	for frame: InputFrame in by_player:
		input_digest = _fold(input_digest, frame.player)
		input_digest = _fold(input_digest, frame.held)
		input_digest = _fold(input_digest, frame.pressed)
		input_digest = _fold(input_digest, frame.released)

	if by_player.size() > 0:
		while histories.size() <= by_player[-1].player:
			histories.append(InputHistory.new())
	var next: int = 0
	for player: int in histories.size():
		if next < by_player.size() and by_player[next].player == player:
			histories[player].push(by_player[next])
			next += 1
		else:
			histories[player].push(InputFrame.new(player))

	for entity: SimEntity in entities:
		entity.x += entity.vx
		entity.y += entity.vy

	tick += 1


## Serializes the whole state in a fixed field order (little-endian).
func snapshot() -> PackedByteArray:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_32(SNAPSHOT_MAGIC)
	buf.put_32(SNAPSHOT_VERSION)
	buf.put_64(tick)
	buf.put_64(world_seed)
	for word: int in rng.get_state():
		buf.put_64(word)
	buf.put_64(input_digest)
	buf.put_64(_next_entity_id)
	buf.put_32(histories.size())
	for history: InputHistory in histories:
		history.write_to(buf)
	buf.put_32(entities.size())
	for entity: SimEntity in entities:
		buf.put_64(entity.id)
		buf.put_64(entity.x)
		buf.put_64(entity.y)
		buf.put_64(entity.vx)
		buf.put_64(entity.vy)
	return buf.data_array


## SHA-256 of snapshot(), as a lowercase hex string.
func state_hash() -> String:
	var ctx: HashingContext = HashingContext.new()
	var err: Error = ctx.start(HashingContext.HASH_SHA256)
	if err != OK:
		push_error("SimWorld.state_hash: HashingContext.start failed: %s" % error_string(err))
		return ""
	err = ctx.update(snapshot())
	if err != OK:
		push_error("SimWorld.state_hash: HashingContext.update failed: %s" % error_string(err))
		return ""
	return ctx.finish().hex_encode()


## Replaces the whole state with a snapshot. On any problem returns an error
## and leaves the current state untouched.
func restore(data: PackedByteArray) -> Error:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.big_endian = false
	buf.data_array = data
	var header_size: int = 4 + 4 + 8 * 8 + 4 + 4
	if data.size() < header_size:
		push_error("SimWorld.restore: snapshot too small (%d bytes)" % data.size())
		return ERR_INVALID_DATA
	if buf.get_32() != SNAPSHOT_MAGIC:
		push_error("SimWorld.restore: not a SimWorld snapshot (bad magic)")
		return ERR_INVALID_DATA
	var version: int = buf.get_32()
	if version != SNAPSHOT_VERSION:
		push_error("SimWorld.restore: snapshot version %d, expected %d" % [version, SNAPSHOT_VERSION])
		return ERR_INVALID_DATA

	var new_tick: int = buf.get_64()
	var new_seed: int = buf.get_64()
	var rng_words: PackedInt64Array = PackedInt64Array()
	for i: int in 4:
		rng_words.append(buf.get_64())
	var new_digest: int = buf.get_64()
	var new_next_id: int = buf.get_64()
	var history_count: int = buf.get_32()
	if history_count < 0 or history_count > MAX_PLAYERS:
		push_error("SimWorld.restore: invalid player history count %d" % history_count)
		return ERR_INVALID_DATA
	var new_histories: Array[InputHistory] = []
	for i: int in history_count:
		var history: InputHistory = InputHistory.read_from(buf)
		if history == null:
			push_error("SimWorld.restore: invalid input history for player %d" % i)
			return ERR_INVALID_DATA
		new_histories.append(history)
	if buf.get_available_bytes() < 4:
		push_error("SimWorld.restore: snapshot truncated before the entity list")
		return ERR_INVALID_DATA
	var count: int = buf.get_32()
	if count < 0 or buf.get_available_bytes() != count * 5 * 8:
		push_error("SimWorld.restore: entity count %d does not match snapshot size %d" % [count, data.size()])
		return ERR_INVALID_DATA
	var new_entities: Array[SimEntity] = []
	for i: int in count:
		var entity: SimEntity = SimEntity.new()
		entity.id = buf.get_64()
		entity.x = buf.get_64()
		entity.y = buf.get_64()
		entity.vx = buf.get_64()
		entity.vy = buf.get_64()
		new_entities.append(entity)

	var last_id: int = 0
	for entity: SimEntity in new_entities:
		if entity.id <= last_id:
			push_error("SimWorld.restore: entity ids must be positive and increasing (got %d after %d)" % [entity.id, last_id])
			return ERR_INVALID_DATA
		last_id = entity.id
	if new_next_id <= last_id:
		push_error("SimWorld.restore: next entity id %d is not above the last id %d" % [new_next_id, last_id])
		return ERR_INVALID_DATA

	var new_rng: SimRng = SimRng.new()
	if not new_rng.set_state(rng_words):
		return ERR_INVALID_DATA

	tick = new_tick
	world_seed = new_seed
	rng = new_rng
	input_digest = new_digest
	_next_entity_id = new_next_id
	histories = new_histories
	entities = new_entities
	return OK


static func _input_before(a: InputFrame, b: InputFrame) -> bool:
	if a.player != b.player:
		return a.player < b.player
	return false


## FNV-1a style fold of one int into a 32-bit digest (stays below 2^63).
static func _fold(digest: int, value: int) -> int:
	var h: int = digest
	for shift: int in [0, 16, 32, 48]:
		h ^= (value >> shift) & 0xFFFF
		h = SimRng._mul32(h, 0x01000193)
	return h
