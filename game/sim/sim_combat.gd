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
		f.dash_attack_ticks = 0
		return  # cannot act in hitstun (it expires in apply_motion, after movement)
	f.kd = maxi(0, f.kd - data.kd_recovery_per_tick)
	var moveset: MoveSet = data.moveset
	if moveset == null:
		return
	var move: MoveData = current_move(world, f)
	if move != null and f.move_tick >= move.length():
		# A late hit can leave a gap after the last root-motion tick; finish
		# the pass (clamped at walls and edges) before turning or recovering.
		_finish_pass(world, f)
		if move.turn_at_end:
			_face_hit_targets(world, f)
		f.move = SimFighter.NO_MOVE
		f.move_tick = 0
		f.idle_ticks = 0
		f.hit_keys.clear()
		move = null
	if move != null:
		# A new `>>` / `<<` during recovery starts a run and a possible new
		# dash attack, and beats cancel_into (so `>>W` `>>W` is a new slide,
		# not the follow-up `>>ZZ`).
		if try_dash_cancel(world, f, history, move):
			move = null
		elif f.move_tick >= move.cancel_from and f.move_tick <= move.cancel_to:
			for next_id: StringName in move.cancel_into:
				var next: int = moveset.index_of(next_id)
				if next >= 0 and history.buffered_press(_button(moveset.moves[next]), world.input_settings.buffer_ticks):
					# Finish a short pass before the cancel (an early Z must
					# not leave the ranger on the near side). Then face the
					# target so the next Z still points at them.
					_finish_pass(world, f)
					if move.turn_at_end:
						_face_hit_targets(world, f)
					_start(world, f, next)
					return
		else:
			return
		if move != null:
			return
	var buffer: int = mini(world.input_settings.buffer_ticks, f.idle_ticks)
	f.idle_ticks = mini(f.idle_ticks + 1, InputHistory.CAPACITY)
	if not f.is_grounded():
		_age_dash_attack_window(f)
		return  # air commands are M1
	# Dash attacks: currently running, the run key just released (linger), or
	# the second tap of `>>` / `<<` on this tick (combat runs before movement
	# starts the dash, so a same-tick Z would otherwise become a standing kick).
	# A button with no dash-start move (today: X) still starts its standing
	# attack; otherwise the press would sit in the buffer and expire mid-linger.
	var dash_command: int = _dash_command_dir(world, f, history)
	if dash_command != 0:
		for i: int in moveset.moves.size():
			var candidate: MoveData = moveset.moves[i]
			if candidate.start == MoveData.Start.DASH and history.buffered_press(_button(candidate), buffer):
				f.facing = dash_command
				_start(world, f, i)
				return
	for i: int in moveset.moves.size():
		var candidate: MoveData = moveset.moves[i]
		if candidate.start == MoveData.Start.NEUTRAL and history.buffered_press(_button(candidate), buffer):
			_start(world, f, i)
			return
	_age_dash_attack_window(f)


static func _start(world: SimWorld, f: SimFighter, index: int) -> void:
	f.move = index
	f.move_tick = 0
	f.idle_ticks = 0
	f.hit_keys.clear()
	f.dash_dir = 0
	f.dash_attack_ticks = 0
	f.dir_cancel_facing = 0
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
	var motion: int = move.motion_at(f.move_tick) * f.facing
	# Root motion can be 0 on later pass ticks (the slash's array ends
	# before pass_to); still close any remaining gap to the far side.
	if motion != 0:
		var m: MovementParams = world.movement
		var low: int = world.room.left + m.half_width
		var high: int = world.room.right - m.half_width
		if f.ground >= 0:
			# Stop at the platform edge (M0 choice, docs/systems/04 open question 3).
			var platform: RoomPlatform = world.room.platforms[f.ground]
			low = maxi(low, mini(f.x, platform.left()))
			high = mini(high, maxi(f.x, platform.right()))
		var before: int = f.x
		f.x = clampi(f.x + motion, low, high)
		_carry(world, f, f.x - before)
	_complete_pass(world, f)


## Carries fighters already hit by `f`'s current move, by the motion `f`
## actually travelled this tick (so a wall or platform edge stops both).
static func _carry(world: SimWorld, f: SimFighter, delta: int) -> void:
	if delta == 0:
		return
	var move: MoveData = current_move(world, f)
	if move == null or not move.carries_at(f.move_tick):
		return
	var m: MovementParams = world.movement
	var low: int = world.room.left + m.half_width
	var high: int = world.room.right - m.half_width
	for target: SimFighter in world.fighters:
		if target.id != f.id and _already_hit(f, target.id):
			target.x = clampi(target.x + delta, low, high)


## Whether this move activation has already recorded a hit on `target_id`.
static func _already_hit(f: SimFighter, target_id: int) -> bool:
	for key: int in f.hit_keys:
		if (key & 0xFFFFFFFF) == target_id:
			return true
	return false


## The already-hit fighter with the lowest id, or null.
static func _first_hit_target(world: SimWorld, f: SimFighter) -> SimFighter:
	var found: SimFighter = null
	for other: SimFighter in world.fighters:
		if other.id != f.id and _already_hit(f, other.id):
			if found == null or other.id < found.id:
				found = other
	return found


## Face a struck target. If the slash could not pass (a wall), this keeps the
## next Z pointed at them instead of always reversing.
static func _face_hit_targets(world: SimWorld, f: SimFighter) -> void:
	var target: SimFighter = _first_hit_target(world, f)
	if target == null or target.x == f.x:
		return
	f.facing = 1 if target.x > f.x else -1


## After a pass-through hit, close any remaining gap to the far side over the
## rest of the pass window (clamped at walls and platform edges). A fixed
## root-motion length alone is not enough when the target is further away.
static func _complete_pass(world: SimWorld, f: SimFighter) -> void:
	var move: MoveData = current_move(world, f)
	if move == null or not move.passes_at(f.move_tick):
		return
	var target: SimFighter = _first_hit_target(world, f)
	if target == null:
		return
	var far: int = _far_side_x(world, f, target)
	var remaining: int = move.pass_to - f.move_tick + 1
	if remaining < 1:
		return
	_step_toward(f, far, remaining)


## Snap to the far side in one step (still clamped at walls and edges). Used
## when the move ends or cancels, so a late hit or an early cancel cannot
## leave the ranger short of a completed pass.
static func _finish_pass(world: SimWorld, f: SimFighter) -> void:
	var move: MoveData = current_move(world, f)
	if move == null or move.pass_from < 0:
		return
	var target: SimFighter = _first_hit_target(world, f)
	if target == null:
		return
	_step_toward(f, _far_side_x(world, f, target), 1)


## Far-side x next to `target`, clamped at room walls and at the platform edge.
static func _far_side_x(world: SimWorld, f: SimFighter, target: SimFighter) -> int:
	if world.room == null or world.movement == null:
		return f.x
	var m: MovementParams = world.movement
	var low: int = world.room.left + m.half_width
	var high: int = world.room.right - m.half_width
	if f.ground >= 0:
		var platform: RoomPlatform = world.room.platforms[f.ground]
		low = maxi(low, mini(f.x, platform.left()))
		high = mini(high, maxi(f.x, platform.right()))
	var move: MoveData = current_move(world, f)
	var overshoot: int = move.pass_overshoot if move != null else 0
	return clampi(target.x + f.facing * (2 * m.half_width + overshoot), low, high)


static func _step_toward(f: SimFighter, far: int, remaining: int) -> void:
	if remaining < 1:
		return
	if f.facing > 0 and f.x < far:
		var step: int = (far - f.x + remaining - 1) / remaining
		f.x = mini(f.x + step, far)
	elif f.facing < 0 and f.x > far:
		var step: int = (f.x - far + remaining - 1) / remaining
		f.x = maxi(f.x - step, far)


## Step 1b: body collision. Walking or running into a monster stops the
## player and does not move the monster (footage: the dummy stays put).
## During an attack, leftover root motion that would overlap the target
## instead drives it forward so a slide kick is not eaten by the body box.
## Pass windows still skip the pair (the `>>ZX` slash-through). Two players
## still split the overlap; two monsters leave it alone. Walls clamp only
## the body that is allowed to move.
static func separate(world: SimWorld) -> void:
	if world.room == null or world.movement == null:
		return
	var m: MovementParams = world.movement
	var low: int = world.room.left + m.half_width
	var high: int = world.room.right - m.half_width
	for i: int in world.fighters.size():
		for j: int in range(i + 1, world.fighters.size()):
			var a: SimFighter = world.fighters[i]
			var b: SimFighter = world.fighters[j]
			if is_passing(world, a) or is_passing(world, b):
				continue
			if absi(a.y - b.y) >= m.height:
				continue
			if 2 * m.half_width - absi(a.x - b.x) <= 0:
				continue
			var a_attack: bool = a.is_in_move()
			var b_attack: bool = b.is_in_move()
			if a_attack and not b_attack:
				_drive_from_overlap(a, b, low, high, m)
			elif b_attack and not a_attack:
				_drive_from_overlap(b, a, low, high, m)
			elif not a_attack and not b_attack:
				_resolve_bodies(a, b, low, high, m)


## Snap the attacker to the near-side contact of `other` and move `other`
## by the overshoot, so a slide travels its full distance with the target.
static func _drive_from_overlap(attacker: SimFighter, other: SimFighter, low: int, high: int, m: MovementParams) -> void:
	# Side comes from positions, not facing: a backward recoil must not treat
	# a dummy behind the attacker as a target in front.
	var side: int = 1 if attacker.x <= other.x else -1
	var contact: int = other.x - side * 2 * m.half_width
	var overshoot: int = (attacker.x - contact) * side
	if overshoot <= 0:
		return
	other.x = clampi(other.x + side * overshoot, low, high)
	attacker.x = clampi(other.x - side * 2 * m.half_width, low, high)


## Idle bodies: the player is blocked by a monster; the monster is not
## displaced. Two players split the overlap (a leftover wall is taken by
## the one who can still move).
static func _resolve_bodies(a: SimFighter, b: SimFighter, low: int, high: int, m: MovementParams) -> void:
	var a_mobile: bool = a.player >= 0
	var b_mobile: bool = b.player >= 0
	if a_mobile and b_mobile:
		var gap: int = 2 * m.half_width - absi(a.x - b.x)
		var left: SimFighter = a if a.x < b.x or (a.x == b.x and a.id < b.id) else b
		var right: SimFighter = b if left == a else a
		var left_x: int = clampi(left.x - gap / 2, low, high)
		var right_x: int = clampi(right.x + (gap - gap / 2), low, high)
		if right_x - left_x < 2 * m.half_width:
			if left_x == low:
				right_x = mini(left_x + 2 * m.half_width, high)
			else:
				left_x = maxi(right_x - 2 * m.half_width, low)
		left.x = left_x
		right.x = right_x
		return
	if not a_mobile and not b_mobile:
		return
	var player: SimFighter = a if a_mobile else b
	var obstacle: SimFighter = b if a_mobile else a
	if player.x < obstacle.x or (player.x == obstacle.x and player.id < obstacle.id):
		player.x = clampi(obstacle.x - 2 * m.half_width, low, high)
	else:
		player.x = clampi(obstacle.x + 2 * m.half_width, low, high)


## Whether `f`'s pushbox is off this tick (passing through fighters).
static func is_passing(world: SimWorld, f: SimFighter) -> bool:
	var move: MoveData = current_move(world, f)
	return move != null and move.passes_at(f.move_tick)


## A melee contact found in resolve_hits, applied in apply_hits.
class PendingHit:
	var attacker: SimFighter
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
				hit.attacker = f
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
		_apply_hitstop(hit.attacker, hit.target, hit.move)
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
	var attacker: SimFighter = null
	for fighter: SimFighter in world.fighters:
		if fighter.id == projectile.owner:
			attacker = fighter
			break
	_apply_hitstop(attacker, best, move)
	return true


## Step 5: the move advances to its next tick.
static func advance(f: SimFighter) -> void:
	if f.move != SimFighter.NO_MOVE:
		f.move_tick += 1
	elif f.dir_cancel_facing != 0 and f.facing == f.dir_cancel_facing:
		# Keep the no-step lock through this tick's movement, then release.
		f.dir_cancel_facing = 0


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
	target.dash_attack_ticks = 0
	target.dir_cancel_facing = 0
	var m: MovementParams = world.movement
	target.x = clampi(target.x + move.pushback * dir, world.room.left + m.half_width, world.room.right - m.half_width)


## Pause attacker and target for `move.hitstop_ticks` (the next world steps
## skip motion while any fighter still has hitstop left).
static func _apply_hitstop(attacker: SimFighter, target: SimFighter, move: MoveData) -> void:
	if move.hitstop_ticks <= 0:
		return
	if attacker != null:
		attacker.hitstop = maxi(attacker.hitstop, move.hitstop_ticks)
	if target != null:
		target.hitstop = maxi(target.hitstop, move.hitstop_ticks)


## A double-tap of ← or → during recovery ends the move so movement can
## start a dash on this same tick. The opposite press then cancels that dash
## (`<<>`). A single back press does not lock the fighter in place.
static func try_dash_cancel(world: SimWorld, f: SimFighter, history: InputHistory, move: MoveData) -> bool:
	if f.move_tick < move.startup + move.active:
		return false
	var window: int = world.input_settings.double_tap_window_ticks
	if not history.double_tap(InputFrame.RIGHT, window) and not history.double_tap(InputFrame.LEFT, window):
		return false
	_finish_pass(world, f)
	if move.turn_at_end:
		_face_hit_targets(world, f)
	f.move = SimFighter.NO_MOVE
	f.move_tick = 0
	f.idle_ticks = 0
	f.hit_keys.clear()
	f.dash_dir = 0
	f.dash_attack_ticks = 0
	f.dir_cancel_facing = 0
	f.vx = 0
	world.emit_event(&"dash_cancel", f.id)
	return true


static func overlaps(attacker: SimFighter, hit: HitboxData, target: SimFighter, hurt: HurtboxData) -> bool:
	var ax: int = attacker.x + hit.offset_x * attacker.facing
	var bx: int = target.x + hurt.offset_x * target.facing
	var ay: int = attacker.y + hit.offset_y
	var by: int = target.y + hurt.offset_y
	return absi(ax - bx) * 2 <= hit.width + hurt.width and ay <= by + hurt.height and ay + hit.height >= by


## Counts down the post-release dash-attack window. Also called while airborne
## so a jump cannot extend the window past dash_attack_linger_ticks.
static func _age_dash_attack_window(f: SimFighter) -> void:
	if f.dash_dir == 0 and f.dash_attack_ticks > 0:
		f.dash_attack_ticks -= 1


## Facing used for a dash attack this tick: an active run, a just-released run
## still inside the linger window, or a `>>` / `<<` whose second tap is now.
static func _dash_command_dir(world: SimWorld, f: SimFighter, history: InputHistory) -> int:
	if f.dash_dir != 0:
		return f.dash_dir
	if f.dash_attack_ticks > 0:
		return f.facing
	var window: int = world.input_settings.double_tap_window_ticks
	if history.double_tap(InputFrame.RIGHT, window):
		return SimFighter.RIGHT
	if history.double_tap(InputFrame.LEFT, window):
		return SimFighter.LEFT
	return 0


static func _button(move: MoveData) -> int:
	return InputFrame.Z if move.button == MoveData.AttackButton.Z else InputFrame.X
