class_name SimCombat
extends RefCounted
## Deterministic attack state machine and 2D AABB hit detection. Frame ticks
## are zero based. Hit results are events (HP/hitstun responses arrive in #45).

## Display phase of a move. Move state itself is its index + tick on SimFighter.
enum Phase { IDLE, STARTUP, ACTIVE, RECOVERY }


static func current_move(world: SimWorld, f: SimFighter) -> MoveData:
	if f.move < 0 or f.character >= world.characters.size():
		return null
	var moveset: MoveSet = world.characters[f.character].moveset
	if moveset == null or f.move >= moveset.moves.size():
		return null
	return moveset.moves[f.move]


static func phase(world: SimWorld, f: SimFighter) -> Phase:
	var move: MoveData = current_move(world, f)
	if move == null:
		return Phase.IDLE
	if f.move_tick < move.startup:
		return Phase.STARTUP
	if f.move_tick < move.startup + move.active:
		return Phase.ACTIVE
	return Phase.RECOVERY


## Resolves a cancel or a new attack at the start of the tick, before movement.
static func begin_tick(world: SimWorld, f: SimFighter, history: InputHistory) -> void:
	if f.character >= world.characters.size():
		return
	var moveset: MoveSet = world.characters[f.character].moveset
	if moveset == null:
		return
	var move: MoveData = current_move(world, f)
	if move != null and f.move_tick >= move.length():
		f.move = SimFighter.NO_MOVE
		f.move_tick = 0
		f.idle_ticks = 0
		f.hit_keys.clear()
		move = null
	if move != null:
		if f.move_tick >= move.cancel_from and f.move_tick <= move.cancel_to:
			for next_id: StringName in move.cancel_into:
				var next: int = moveset.index_of(next_id)
				if next >= 0 and history.buffered_press(_button(moveset.moves[next]), world.input_settings.buffer_ticks):
					_start(world, f, next)
					return
		return
	var buffer: int = mini(world.input_settings.buffer_ticks, f.idle_ticks)
	f.idle_ticks = mini(f.idle_ticks + 1, InputHistory.CAPACITY)
	if not f.is_grounded():
		return  # air commands are M1
	for i: int in moveset.moves.size():
		var candidate: MoveData = moveset.moves[i]
		if candidate.start == MoveData.Start.NEUTRAL and history.buffered_press(_button(candidate), buffer):
			_start(world, f, i)
			return


static func _start(world: SimWorld, f: SimFighter, index: int) -> void:
	f.move = index
	f.move_tick = 0
	f.idle_ticks = 0
	f.hit_keys.clear()
	f.dash_dir = 0
	f.vx = 0
	var move: MoveData = current_move(world, f)
	world.emit_event(&"move_start", f.id, 0, move.id)


## Step 1 of a tick's combat, for every fighter before any hit test: the
## move's root motion for the current move tick.
static func apply_motion(world: SimWorld, f: SimFighter) -> void:
	var move: MoveData = current_move(world, f)
	if move == null:
		return
	var m: MovementParams = world.movement
	f.x = clampi(f.x + move.motion_at(f.move_tick) * f.facing, world.room.left + m.half_width, world.room.right - m.half_width)


## Step 2: hits every overlapping hurtbox once per box, with every fighter
## already at its final position for the tick (no fighter-order dependence).
static func resolve_hits(world: SimWorld, f: SimFighter) -> void:
	var move: MoveData = current_move(world, f)
	if move == null:
		return
	for index: int in move.hitboxes.size():
		var box: HitboxData = move.hitboxes[index]
		if f.move_tick < box.from_tick or f.move_tick > box.to_tick:
			continue
		for target: SimFighter in world.fighters:
			if target.id == f.id or target.character >= world.characters.size():
				continue
			var hurtbox: HurtboxData = world.characters[target.character].hurtbox
			var key: int = (index << 32) | target.id
			if not f.hit_keys.has(key) and overlaps(f, box, target, hurtbox):
				f.hit_keys.append(key)
				var attack: int = world.characters[f.character].attack
				world.emit_hit(f.id, target.id, move, attack * move.damage_percent / 100)


## Step 3: projectiles already in flight move, then hit the first hurtbox they
## overlap (fighters in id order) or vanish at a wall / end of lifetime.
static func step_projectiles(world: SimWorld) -> void:
	var alive: Array[SimProjectile] = []
	for projectile: SimProjectile in world.projectiles:
		var shot: ProjectileData = projectile_data(world, projectile)
		projectile.x += projectile.dir * shot.speed
		projectile.ticks_left -= 1
		var hit: bool = _projectile_hit(world, projectile, shot)
		var inside: bool = projectile.x >= world.room.left and projectile.x <= world.room.right
		if not hit and inside and projectile.ticks_left > 0:
			alive.append(projectile)
		elif not hit:
			world.emit_event(&"projectile_end", projectile.owner, 0, _move(world, projectile).id)
	world.projectiles = alive


## Step 4: projectiles fired on this move tick appear at their spawn point
## (they first move and can hit on the next tick).
static func fire_projectiles(world: SimWorld, f: SimFighter) -> void:
	var move: MoveData = current_move(world, f)
	if move == null:
		return
	for index: int in move.projectiles.size():
		var shot: ProjectileData = move.projectiles[index]
		if shot.spawn_tick != f.move_tick or world.projectiles.size() >= SimWorld.MAX_PROJECTILES:
			continue
		var projectile: SimProjectile = SimProjectile.new()
		projectile.id = world.take_id()
		projectile.owner = f.id
		projectile.character = f.character
		projectile.move = f.move
		projectile.index = index
		projectile.x = f.x + shot.offset_x * f.facing
		projectile.y = f.y + shot.offset_y
		projectile.dir = f.facing
		projectile.ticks_left = shot.lifetime_ticks
		world.projectiles.append(projectile)
		world.emit_event(&"projectile", f.id, 0, move.id)


## The data of a projectile in flight, or null when it no longer exists.
static func projectile_data(world: SimWorld, projectile: SimProjectile) -> ProjectileData:
	var move: MoveData = _move(world, projectile)
	if move == null or projectile.index >= move.projectiles.size():
		return null
	return move.projectiles[projectile.index]


static func _move(world: SimWorld, projectile: SimProjectile) -> MoveData:
	if projectile.character >= world.characters.size():
		return null
	var moveset: MoveSet = world.characters[projectile.character].moveset
	if moveset == null or projectile.move >= moveset.moves.size():
		return null
	return moveset.moves[projectile.move]


static func _projectile_hit(world: SimWorld, projectile: SimProjectile, shot: ProjectileData) -> bool:
	for target: SimFighter in world.fighters:
		if target.id == projectile.owner or target.character >= world.characters.size():
			continue
		var hurt: HurtboxData = world.characters[target.character].hurtbox
		var bx: int = target.x + hurt.offset_x * target.facing
		var by: int = target.y + hurt.offset_y
		if absi(projectile.x - bx) * 2 <= shot.width + hurt.width and projectile.y <= by + hurt.height and projectile.y + shot.height >= by:
			var move: MoveData = _move(world, projectile)
			var attack: int = world.characters[projectile.character].attack
			world.emit_hit(projectile.owner, target.id, move, attack * move.damage_percent / 100)
			return true
	return false


## Step 5: the move advances to its next tick.
static func advance(f: SimFighter) -> void:
	if f.move != SimFighter.NO_MOVE:
		f.move_tick += 1


## Integer AABB overlap (touching edges count as touching/hit).
static func overlaps(attacker: SimFighter, hit: HitboxData, target: SimFighter, hurt: HurtboxData) -> bool:
	var ax: int = attacker.x + hit.offset_x * attacker.facing
	var bx: int = target.x + hurt.offset_x * target.facing
	var ay: int = attacker.y + hit.offset_y
	var by: int = target.y + hurt.offset_y
	return absi(ax - bx) * 2 <= hit.width + hurt.width and ay <= by + hurt.height and ay + hit.height >= by


static func _button(move: MoveData) -> int:
	return InputFrame.Z if move.button == MoveData.AttackButton.Z else InputFrame.X
