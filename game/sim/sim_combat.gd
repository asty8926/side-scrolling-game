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


## Phase of `move` on move tick `move_tick`.
static func phase_at(move: MoveData, move_tick: int) -> Phase:
	if move == null or move_tick < 0 or move_tick >= move.length():
		return Phase.IDLE
	if move_tick < move.startup:
		return Phase.STARTUP
	if move_tick < move.startup + move.active:
		return Phase.ACTIVE
	return Phase.RECOVERY


## Resolves a cancel or a new attack at the start of the tick, before movement.
static func begin_tick(world: SimWorld, f: SimFighter, history: InputHistory) -> void:
	if f.character >= world.characters.size():
		return
	var data: CharacterData = world.characters[f.character]
	if f.hitstun > 0:
		f.idle_ticks = 0
		return  # cannot act in hitstun (it expires in apply_motion, after movement)
	f.kd = maxi(0, f.kd - data.kd_recovery_per_tick)
	var moveset: MoveSet = data.moveset
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
	# Hitstun ticks down here, after this tick's attack and movement checks,
	# so both stay blocked for the same ticks.
	f.stunned_this_tick = f.hitstun > 0
	if f.hitstun > 0:
		f.hitstun -= 1
	var move: MoveData = current_move(world, f)
	if move == null:
		return
	var m: MovementParams = world.movement
	f.x = clampi(f.x + move.motion_at(f.move_tick) * f.facing, world.room.left + m.half_width, world.room.right - m.half_width)


## A melee contact found in resolve_hits, applied in apply_hits.
class PendingHit:
	var dir: int
	var target: SimFighter
	var move: MoveData
	var damage: int


## Step 2: hits every overlapping hurtbox once per box, with every fighter
## already at its final position for the tick. Contacts are only collected
## here and applied in apply_hits, so two fighters trading active attacks both
## land, whatever the fighter order.
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
				var damage: int = attack * move.damage_percent / 100
				var hit: PendingHit = PendingHit.new()
				hit.dir = f.facing
				hit.target = target
				hit.move = move
				hit.damage = damage
				world.pending_hits.append(hit)
				world.emit_hit(f.id, target.id, move, damage)


## Step 2b: applies the melee contacts of this tick (in the order found).
static func apply_hits(world: SimWorld) -> void:
	for hit: PendingHit in world.pending_hits:
		_take_hit(world, hit.dir, hit.target, hit.move, hit.damage)
	world.pending_hits.clear()


## Step 3: projectiles already in flight move, then hit the first hurtbox they
## overlap (fighters in id order) or vanish at a wall / end of lifetime.
static func step_projectiles(world: SimWorld) -> void:
	var alive: Array[SimProjectile] = []
	for projectile: SimProjectile in world.projectiles:
		var shot: ProjectileData = projectile_data(world, projectile)
		var from_x: int = projectile.x
		projectile.x += projectile.dir * shot.speed
		projectile.ticks_left -= 1
		var hit: bool = _projectile_hit(world, projectile, shot, from_x)
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


## Hits the first hurtbox the arrow's swept box (from `from_x` to its new x)
## overlaps: the one it touches first along its direction, then the lowest
## fighter id (boxes it already overlaps at its start all count as touched first). A fast
## arrow therefore never passes through a target between two ticks.
static func _projectile_hit(world: SimWorld, projectile: SimProjectile, shot: ProjectileData, from_x: int) -> bool:
	var sweep_left: int = mini(from_x, projectile.x) - shot.width / 2
	var sweep_right: int = maxi(from_x, projectile.x) + shot.width / 2
	var best: SimFighter = null
	var best_distance: int = 0
	for target: SimFighter in world.fighters:
		if target.id == projectile.owner or target.character >= world.characters.size():
			continue
		var hurt: HurtboxData = world.characters[target.character].hurtbox
		var bx: int = target.x + hurt.offset_x * target.facing
		var by: int = target.y + hurt.offset_y
		var hurt_left: int = bx - hurt.width / 2
		var hurt_right: int = bx + hurt.width / 2
		if sweep_right < hurt_left or sweep_left > hurt_right:
			continue
		if projectile.y > by + hurt.height or projectile.y + shot.height < by:
			continue
		var near_edge: int = hurt_left if projectile.dir == SimFighter.RIGHT else hurt_right
		# Travel until the arrow's front touches it; 0 for every box it already overlaps.
		var distance: int = maxi(0, (near_edge - from_x) * projectile.dir - shot.width / 2)
		if best == null or distance < best_distance:
			best = target
			best_distance = distance
	if best == null:
		return false
	var move: MoveData = _move(world, projectile)
	var attack: int = world.characters[projectile.character].attack
	var damage: int = attack * move.damage_percent / 100
	_take_hit(world, projectile.dir, best, move, damage)
	world.emit_hit(projectile.owner, best.id, move, damage)
	return true


## Step 5: the move advances to its next tick.
static func advance(f: SimFighter) -> void:
	if f.move != SimFighter.NO_MOVE:
		f.move_tick += 1


## Target response (#45): damage, hitstun, KD, combo count, pushback along
## `dir` (the kicker's facing or the arrow's flight). A hit interrupts the
## target's own move.
static func _take_hit(world: SimWorld, dir: int, target: SimFighter, move: MoveData, damage: int) -> void:
	# A hit on the last blocked tick still continues the combo.
	target.combo = target.combo + 1 if target.hitstun > 0 or target.stunned_this_tick else 1
	target.hp = maxi(0, target.hp - damage)
	target.hitstun = move.hitstun_ticks
	target.kd += move.kd
	target.last_damage = damage
	target.move = SimFighter.NO_MOVE
	target.move_tick = 0
	target.hit_keys.clear()
	target.dash_dir = 0
	var m: MovementParams = world.movement
	target.x = clampi(target.x + move.pushback * dir, world.room.left + m.half_width, world.room.right - m.half_width)


## Integer AABB overlap (touching edges count as touching/hit).
static func overlaps(attacker: SimFighter, hit: HitboxData, target: SimFighter, hurt: HurtboxData) -> bool:
	var ax: int = attacker.x + hit.offset_x * attacker.facing
	var bx: int = target.x + hurt.offset_x * target.facing
	var ay: int = attacker.y + hit.offset_y
	var by: int = target.y + hurt.offset_y
	return absi(ax - bx) * 2 <= hit.width + hurt.width and ay <= by + hurt.height and ay + hit.height >= by


static func _button(move: MoveData) -> int:
	return InputFrame.Z if move.button == MoveData.AttackButton.Z else InputFrame.X
