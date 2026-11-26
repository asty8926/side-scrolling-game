class_name SimMovement
extends RefCounted
## Fighter movement on the 2D gameplay plane (docs/systems/01-combat-inputs.md,
## Movement). Pure integer rules, one call per fighter per tick:
##
## - Hold ← / → to walk; double tap (`>>` / `<<`) to dash that way and face it.
## - While dashing, a single press of the opposite direction stops the dash and
##   turns around with zero speed on that tick (the `<<>` reverse of `ZZZ<<>`).
## - Releasing the dash direction on the ground stops the dash.
## - ↑ jumps (buffered, so a press just before landing still jumps); ↑ in the
##   air is the double jump. Jumping while dashing keeps dash speed (dash jump).
## - ↓ on a one-way platform drops through it; ↓ on the floor does nothing.
## - One-way platforms only stop downward motion from above; walls clamp x.


static func step_fighter(world: SimWorld, f: SimFighter, history: InputHistory) -> void:
	var m: MovementParams = world.movement
	var room: RoomLayout = world.room
	var window: int = world.input_settings.double_tap_window_ticks
	var attacking: bool = f.is_in_move() or f.is_in_hitstun() or f.dir_cancel_facing != 0
	var held: int = 0 if attacking else history.held_now()
	var pressed: int = 0 if attacking else history.pressed_ago(0)
	var dir: int = 0
	if (held & InputFrame.RIGHT) != 0:
		dir += 1
	if (held & InputFrame.LEFT) != 0:
		dir -= 1

	# Dash start / reverse / stop.
	var started: int = 0
	var reverse_press: bool = false
	if f.dash_dir != 0:
		var against: int = InputFrame.LEFT if f.dash_dir == SimFighter.RIGHT else InputFrame.RIGHT
		reverse_press = (pressed & against) != 0
	# An opposite press during a dash is always the reverse (below), even when it
	# also completes a double tap.
	if not reverse_press and not attacking:
		if history.double_tap(InputFrame.RIGHT, window):
			started = SimFighter.RIGHT
		elif history.double_tap(InputFrame.LEFT, window):
			started = SimFighter.LEFT
	var reversed: bool = false
	if started != 0:
		f.dash_dir = started
		f.facing = started
		world.emit_event(&"dash", f.id)
	elif f.dash_dir != 0:
		var opposite: int = InputFrame.LEFT if f.dash_dir == SimFighter.RIGHT else InputFrame.RIGHT
		if (pressed & opposite) != 0:
			f.facing = -f.dash_dir
			f.dash_dir = 0
			reversed = true
			world.emit_event(&"dash_reverse", f.id)
		elif f.is_grounded() and dir != f.dash_dir:
			f.dash_dir = 0
			f.dash_attack_ticks = world.input_settings.dash_attack_linger_ticks
			world.emit_event(&"dash_stop", f.id)

	# Horizontal speed.
	if f.dir_cancel_facing != 0:
		# `<<>` twitch: face-turn only, no step (footage).
		f.vx = 0
	elif reversed:
		f.vx = 0
	elif f.dash_dir != 0:
		f.vx = f.dash_dir * m.dash_speed
	else:
		f.vx = dir * m.walk_speed
		if dir != 0:
			f.facing = dir

	# Drop-through, jump, double jump.
	if f.is_grounded() and f.ground >= 0 and (pressed & InputFrame.DOWN) != 0:
		f.ground = SimFighter.IN_AIR
		f.drop_ticks = m.drop_ticks
		f.vy = 0
		f.air_jumps = 1
		world.emit_event(&"drop", f.id)
	elif not attacking and f.is_grounded() and history.buffered_press(InputFrame.UP, world.input_settings.buffer_ticks):
		f.ground = SimFighter.IN_AIR
		f.vy = m.jump_velocity
		f.air_jumps = 1
		world.emit_event(&"jump", f.id)
	elif not attacking and not f.is_grounded() and f.air_jumps > 0 and history.buffered_press(InputFrame.UP, 0):
		f.vy = m.double_jump_velocity
		f.air_jumps -= 1
		world.emit_event(&"double_jump", f.id)

	# Integrate x, clamp to walls.
	f.x = clampi(f.x + f.vx, room.left + m.half_width, room.right - m.half_width)

	# Still supported? Walking off a platform edge starts a fall.
	if f.ground >= 0:
		var platform: RoomPlatform = room.platforms[f.ground]
		if f.x + m.half_width < platform.left() or f.x - m.half_width > platform.right():
			f.ground = SimFighter.IN_AIR
			f.vy = 0
			f.air_jumps = 1

	if f.is_grounded():
		return

	# Gravity, then vertical move with one-way landing.
	f.vy = maxi(f.vy - m.gravity, -m.max_fall_speed)
	var old_y: int = f.y
	var new_y: int = f.y + f.vy
	# Platforms are ignored on every tick the drop timer is running, including
	# the drop tick itself (so drop_ticks = 1 still falls through).
	var dropping: bool = f.drop_ticks > 0
	if dropping:
		f.drop_ticks -= 1
	var landed_on: int = SimFighter.IN_AIR
	var landed_y: int = new_y
	if f.vy <= 0:
		if new_y <= room.floor_y:
			landed_on = SimFighter.ON_FLOOR
			landed_y = room.floor_y
		if not dropping:
			var tier_height: int = world.tier_height
			for i: int in room.platforms.size():
				var platform: RoomPlatform = room.platforms[i]
				var top: int = platform.top(room.floor_y, tier_height)
				var overlaps: bool = f.x + m.half_width >= platform.left() and f.x - m.half_width <= platform.right()
				if overlaps and old_y >= top and new_y <= top and (landed_on == SimFighter.IN_AIR or top > landed_y):
					landed_on = i
					landed_y = top
	if landed_on != SimFighter.IN_AIR:
		f.y = landed_y
		f.vy = 0
		f.ground = landed_on
		f.air_jumps = 1
		f.drop_ticks = 0
		world.emit_event(&"land", f.id)
	else:
		f.y = new_y
