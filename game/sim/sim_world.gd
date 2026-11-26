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
const SNAPSHOT_VERSION: int = 8
## Players a world accepts input from (party of up to 4).
const MAX_PLAYERS: int = 4
## Most fighters (players + dummies/mobs) a world and its snapshot hold.
const MAX_FIGHTERS: int = 8

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
## Events emitted during the last step() (cleared at the start of each step).
## Output only, not part of the snapshot or hash.
var events: Array[SimEvent] = []
## Static configuration (set once by SimSetup, not part of the snapshot).
## Null room/movement means "no fighters" (e.g. the empty setup).
var room: RoomLayout
var movement: MovementParams
var input_settings: InputSettings = InputSettings.new()
## Derived from room + movement when the fighters' world is configured.
var tier_height: int = 0
## Player-controlled fighters, stable insertion order.
var fighters: Array[SimFighter] = []
## Melee contacts of the current tick (always empty between ticks).
var pending_hits: Array[SimCombat.PendingHit] = []
## Projectiles in flight, in creation (id) order.
var projectiles: Array[SimProjectile] = []
## Most projectiles alive at once (a snapshot limit).
const MAX_PROJECTILES: int = 64
## Static character data, indexed by each fighter's `character` field.
var characters: Array[CharacterData] = []
## Entities in stable insertion order.
var entities: Array[SimEntity] = []
var _next_entity_id: int = 1


func _init(seed_value: int = 1) -> void:
	world_seed = seed_value
	rng = SimRng.new(seed_value)


## Sets the static room/movement/input data. Returns the validation problems
## (empty = configured). Call before adding fighters.
func configure(room_layout: RoomLayout, movement_params: MovementParams, settings: InputSettings) -> Array[String]:
	var problems: Array[String] = []
	if room_layout == null or movement_params == null or settings == null:
		problems.append("room, movement and input settings are required")
		return problems
	var movement_problems: Array[String] = movement_params.validate()
	problems.append_array(movement_problems)
	# Room checks derive the tier height from the jump, which needs valid movement.
	if movement_problems.is_empty():
		problems.append_array(room_layout.validate(movement_params))
	problems.append_array(settings.validate())
	if problems.is_empty():
		room = room_layout
		movement = movement_params
		input_settings = settings
		tier_height = room_layout.tier_height(movement_params)
	return problems


## Adds a fighter for `player` standing on the floor at the room spawn.
## Returns its id, or -1 when the world has no room configured or is full.
func add_fighter(player: int, character_index: int = 0) -> int:
	if room == null or movement == null:
		push_error("SimWorld.add_fighter: configure() the world first")
		return -1
	if fighters.size() >= MAX_FIGHTERS:
		push_error("SimWorld.add_fighter: at most %d fighters fit in a snapshot" % MAX_FIGHTERS)
		return -1
	if player < SimFighter.NO_PLAYER or player >= MAX_PLAYERS:
		push_error("SimWorld.add_fighter: player %d is not NO_PLAYER or in [0, %d)" % [player, MAX_PLAYERS])
		return -1
	if character_index < 0 or character_index >= characters.size():
		push_error("SimWorld.add_fighter: unknown character %d (add_character first)" % character_index)
		return -1
	var fighter: SimFighter = SimFighter.new()
	fighter.id = _next_entity_id
	_next_entity_id += 1
	fighter.player = player
	fighter.character = character_index
	fighter.x = room.spawn_x
	fighter.home_x = room.spawn_x
	fighter.hp = characters[character_index].max_hp
	fighter.y = room.floor_y
	fighters.append(fighter)
	return fighter.id


## Registers static character data. Returns its index, or -1 with an error
## when the data is invalid.
func add_character(data: CharacterData) -> int:
	if data == null:
		push_error("SimWorld.add_character: no data")
		return -1
	var problems: Array[String] = data.validate()
	if not problems.is_empty():
		push_error("SimWorld.add_character: %s is invalid: %s" % [data.id, "; ".join(problems)])
		return -1
	characters.append(data)
	return characters.size() - 1


## Debug reset (F4), between ticks: every fighter without a player (the
## training dummy) gets full HP, no KD/hitstun/combo, and goes back home.
func reset_dummies() -> void:
	for fighter: SimFighter in fighters:
		if fighter.player != SimFighter.NO_PLAYER:
			continue
		fighter.hp = characters[fighter.character].max_hp
		fighter.kd = 0
		fighter.hitstun = 0
		fighter.combo = 0
		fighter.last_damage = 0
		fighter.x = fighter.home_x
		fighter.y = room.floor_y if room != null else fighter.y
		fighter.vx = 0
		fighter.vy = 0
		fighter.ground = SimFighter.ON_FLOOR
		fighter.move = SimFighter.NO_MOVE
		fighter.move_tick = 0
	emit_event(&"reset")


## Debug hot reload, between ticks: replaces character `index` with `data`
## if it is valid. Returns the problems (empty = replaced). Fighters playing a
## move that no longer exists stop it.
func replace_character(index: int, data: CharacterData) -> Array[String]:
	var problems: Array[String] = []
	if index < 0 or index >= characters.size() or data == null:
		problems.append("no character %d to replace" % index)
		return problems
	problems = data.validate()
	if not problems.is_empty():
		return problems
	# Moves are stored as indexes: follow each one by its id into the new
	# move set, so a move shifting into a removed move's slot never takes over.
	var old_moves: MoveSet = characters[index].moveset
	var new_moves: MoveSet = data.moveset
	characters[index] = data
	for fighter: SimFighter in fighters:
		if fighter.character == index and fighter.move != SimFighter.NO_MOVE:
			fighter.move = _same_move(old_moves, new_moves, fighter.move)
			if fighter.move == SimFighter.NO_MOVE:
				fighter.move_tick = 0
				fighter.hit_keys.clear()
	# Arrows in flight follow their move too, and vanish without data.
	var alive: Array[SimProjectile] = []
	for projectile: SimProjectile in projectiles:
		if projectile.character == index:
			projectile.move = _same_move(old_moves, new_moves, projectile.move)
		if projectile.move != SimFighter.NO_MOVE and SimCombat.projectile_data(self, projectile) != null:
			alive.append(projectile)
	projectiles = alive
	return problems


## Index in `new_moves` of the move at `move` in `old_moves`, by id, or NO_MOVE.
static func _same_move(old_moves: MoveSet, new_moves: MoveSet, move: int) -> int:
	if old_moves == null or new_moves == null or move < 0 or move >= old_moves.moves.size():
		return SimFighter.NO_MOVE
	return new_moves.index_of(old_moves.moves[move].id)


## Debug hot reload, between ticks: like configure(), then puts fighters that
## stood on a platform that no longer exists into the air.
func replace_static(room_layout: RoomLayout, movement_params: MovementParams, settings: InputSettings) -> Array[String]:
	var problems: Array[String] = configure(room_layout, movement_params, settings)
	if problems.is_empty():
		for fighter: SimFighter in fighters:
			if fighter.ground >= room.platforms.size():
				fighter.ground = SimFighter.IN_AIR
			elif fighter.ground >= 0:
				var platform: RoomPlatform = room.platforms[fighter.ground]
				if fighter.x + movement.half_width < platform.left() or fighter.x - movement.half_width > platform.right():
					# The platform moved away: fall from where the fighter was.
					fighter.ground = SimFighter.IN_AIR
					fighter.vy = 0
					fighter.air_jumps = 1
				else:
					# Stand on the new top (a new tier or tier height).
					fighter.y = platform.top(room.floor_y, tier_height)
			elif fighter.ground == SimFighter.ON_FLOOR:
				fighter.y = room.floor_y
	return problems


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
	events.clear()
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

	var empty_history: InputHistory = InputHistory.new()
	empty_history.push(InputFrame.new())
	# Hit-stop is a short global tick pause (default 2 ticks, not a long freeze):
	# inputs are already recorded above, so a press during the pause is buffered.
	var frozen: bool = false
	for fighter: SimFighter in fighters:
		if fighter.hitstop > 0:
			frozen = true
			break
	if frozen:
		for fighter: SimFighter in fighters:
			if fighter.hitstop > 0:
				fighter.hitstop -= 1
		tick += 1
		return
	for fighter: SimFighter in fighters:
		var history: InputHistory = histories[fighter.player] if fighter.player >= 0 and fighter.player < histories.size() else empty_history
		SimCombat.begin_tick(self, fighter, history)
		SimMovement.step_fighter(self, fighter, history)
	for fighter: SimFighter in fighters:
		SimCombat.apply_motion(self, fighter)
	SimCombat.separate(self)
	for fighter: SimFighter in fighters:
		SimCombat.resolve_hits(self, fighter)
	SimCombat.apply_hits(self)
	SimCombat.step_projectiles(self)
	for fighter: SimFighter in fighters:
		SimCombat.fire_projectiles(self, fighter)
	for fighter: SimFighter in fighters:
		SimCombat.advance(fighter)

	for entity: SimEntity in entities:
		entity.x += entity.vx
		entity.y += entity.vy

	tick += 1


## Next id for a fighter, entity or projectile (shared, increasing).
func take_id() -> int:
	var id: int = _next_entity_id
	_next_entity_id += 1
	return id


## Records an event for this tick (used by sim systems).
func emit_event(type: StringName, actor: int = 0, target: int = 0, move_id: StringName = &"") -> void:
	events.append(SimEvent.new(tick, type, actor, target, move_id))


## Records a hit with resolved damage and KD (response is added in #45).
func emit_hit(actor: int, target: int, move: MoveData, damage: int) -> void:
	var event: SimEvent = SimEvent.new(tick, &"hit", actor, target, move.id)
	event.damage = damage
	event.kd = move.kd
	event.camera_shake = move.camera_shake
	events.append(event)


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
	buf.put_32(fighters.size())
	for fighter: SimFighter in fighters:
		fighter.write_to(buf)
	buf.put_32(projectiles.size())
	for projectile: SimProjectile in projectiles:
		projectile.write_to(buf)
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
		push_error("SimWorld.restore: snapshot truncated before the fighter list")
		return ERR_INVALID_DATA
	var fighter_count: int = buf.get_32()
	if fighter_count < 0 or fighter_count > MAX_FIGHTERS:
		push_error("SimWorld.restore: invalid fighter count %d" % fighter_count)
		return ERR_INVALID_DATA
	var new_fighters: Array[SimFighter] = []
	for i: int in fighter_count:
		var fighter: SimFighter = SimFighter.read_from(buf)
		if fighter == null or (room != null and fighter.ground >= room.platforms.size()) or fighter.player >= MAX_PLAYERS or not _fighter_data_ok(fighter):
			push_error("SimWorld.restore: invalid fighter %d" % i)
			return ERR_INVALID_DATA
		new_fighters.append(fighter)
	if buf.get_available_bytes() < 4:
		push_error("SimWorld.restore: snapshot truncated before the projectile list")
		return ERR_INVALID_DATA
	var projectile_count: int = buf.get_32()
	if projectile_count < 0 or projectile_count > MAX_PROJECTILES:
		push_error("SimWorld.restore: invalid projectile count %d" % projectile_count)
		return ERR_INVALID_DATA
	var new_projectiles: Array[SimProjectile] = []
	for i: int in projectile_count:
		var projectile: SimProjectile = SimProjectile.read_from(buf)
		if projectile == null or SimCombat.projectile_data(self, projectile) == null:
			push_error("SimWorld.restore: invalid projectile %d" % i)
			return ERR_INVALID_DATA
		new_projectiles.append(projectile)
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

	if not new_fighters.is_empty() and room == null:
		push_error("SimWorld.restore: snapshot has fighters but this world has no room configured")
		return ERR_INVALID_DATA
	var last_id: int = 0
	for fighter: SimFighter in new_fighters:
		if fighter.id <= last_id:
			push_error("SimWorld.restore: fighter ids must be positive and increasing")
			return ERR_INVALID_DATA
		last_id = fighter.id
	var last_fighter_id: int = last_id
	last_id = 0
	for projectile: SimProjectile in new_projectiles:
		if projectile.id <= last_id:
			push_error("SimWorld.restore: projectile ids must be positive and increasing")
			return ERR_INVALID_DATA
		last_id = projectile.id
	last_fighter_id = maxi(last_fighter_id, last_id)
	last_id = 0
	for entity: SimEntity in new_entities:
		if entity.id <= last_id:
			push_error("SimWorld.restore: entity ids must be positive and increasing (got %d after %d)" % [entity.id, last_id])
			return ERR_INVALID_DATA
		last_id = entity.id
	if new_next_id <= maxi(last_id, last_fighter_id):
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
	fighters = new_fighters
	projectiles = new_projectiles
	entities = new_entities
	return OK


func _fighter_data_ok(fighter: SimFighter) -> bool:
	if fighter.character >= characters.size():
		return false
	if fighter.move == SimFighter.NO_MOVE:
		return true
	var moveset: MoveSet = characters[fighter.character].moveset
	return moveset != null and fighter.move < moveset.moves.size()


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
