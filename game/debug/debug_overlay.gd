class_name DebugOverlay
extends CanvasLayer
## Debug builds only, F1: a training-mode readout of the sim (read-only).
## Text: sim tick, FPS, pause state, each fighter's move and frame data with
## the cancel window, dummy KD/hitstun, and the last INPUT_COLUMNS input frames.
## 3D: hitboxes (red, active ticks only), hurtboxes (blue) and pushboxes
## (green) drawn on the gameplay plane. F2 pauses, F3 steps one tick.

const INPUT_COLUMNS: int = 20
const HITBOX_COLOR: Color = Color(1.0, 0.15, 0.1)
const HURTBOX_COLOR: Color = Color(0.2, 0.5, 1.0)
const PUSHBOX_COLOR: Color = Color(0.2, 0.9, 0.3)

@export var driver: SimDriver
## Parent of the 3D box lines (usually the Main Node3D).
@export var world_root: Node3D

var _label: Label
var _lines: MeshInstance3D
var _mesh: ImmediateMesh


func _ready() -> void:
	layer = 10
	_label = Label.new()
	_label.name = "Text"
	_label.position = Vector2(12, 44)
	_label.add_theme_font_size_override(&"font_size", 14)
	_label.add_theme_constant_override(&"outline_size", 5)
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_label)
	_mesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.name = "DebugBoxes"
	_lines.mesh = _mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	_lines.material_override = material
	# Attach from this node (not world_root.add_child.call_deferred), so a
	# freed overlay cancels the deferred call instead of adding a freed mesh.
	if world_root != null:
		call_deferred(&"_attach_lines")
	set_overlay_visible(false)


func _attach_lines() -> void:
	if world_root == null or _lines == null or not is_instance_valid(_lines):
		return
	if _lines.get_parent() == world_root:
		return
	world_root.add_child(_lines)


func _exit_tree() -> void:
	# _lines lives under world_root, or is unparented in tests, so it is not
	# freed with this CanvasLayer. A parented mesh may share that parent with
	# this overlay (main.tscn: both under Main); remove_child is blocked while
	# a sibling exits, so queue_free it and only free() when it has no parent.
	if _lines != null and is_instance_valid(_lines):
		if _lines.get_parent() != null:
			_lines.queue_free()
		else:
			_lines.free()
	_lines = null


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed(&"debug_overlay") and not event.is_echo():
		set_overlay_visible(not visible)


func set_overlay_visible(on: bool) -> void:
	visible = on and OS.is_debug_build()
	if _lines != null and is_instance_valid(_lines):
		_lines.visible = visible


func _process(_delta: float) -> void:
	if not visible or driver == null:
		return
	refresh(driver.world, driver.paused)


## Rebuilds the text and the box lines from `world` (public for tests).
func refresh(world: SimWorld, paused: bool = false) -> void:
	_label.text = describe(world, paused, Engine.get_frames_per_second())
	_draw_boxes(world)


static func describe(world: SimWorld, paused: bool, fps: float) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("tick %d   %d FPS   %s" % [world.tick, roundi(fps), "PAUSED (F2 resume, F3 step)" if paused else "F2 pause, F3 step"])
	for fighter: SimFighter in world.fighters:
		lines.append(_fighter_line(world, fighter))
	if not world.projectiles.is_empty():
		lines.append("arrows in flight: %d" % world.projectiles.size())
	if world.histories.size() > 0:
		lines.append("inputs (oldest → newest): %s" % input_row(world.histories[0], INPUT_COLUMNS))
	return "\n".join(lines)


static func _fighter_line(world: SimWorld, f: SimFighter) -> String:
	var char_name: String = String(world.characters[f.character].id) if f.character < world.characters.size() else "?"
	var text: String = "%s #%d  x %d y %d  " % [char_name, f.id, f.x, f.y]
	var move: MoveData = SimCombat.current_move(world, f)
	if move != null:
		# move_tick was already advanced past the tick that was simulated.
		var shown: int = f.move_tick - 1
		var phase_name: String = ["idle", "startup", "ACTIVE", "recovery"][SimCombat.phase_at(move, shown)]
		text += "%s  frame %d/%d %s  [startup %d | active %d | recovery %d]" % [move.id, shown, move.length(), phase_name, move.startup, move.active, move.recovery]
		if not move.cancel_into.is_empty():
			var open: bool = shown >= move.cancel_from and shown <= move.cancel_to
			text += "  cancel %d-%d %s" % [move.cancel_from, move.cancel_to, "OPEN" if open else "closed"]
	else:
		text += "free" if f.hitstun == 0 else "hitstun %d" % f.hitstun
	if f.player == SimFighter.NO_PLAYER:
		text += "   KD %d  hitstun %d  combo %d  HP %d" % [f.kd, f.hitstun, f.combo, f.hp]
	return text


## One column per frame (oldest first): the buttons pressed on that frame,
## with attack/skill keys shown as the label of the physical key on this
## keyboard (W on AZERTY, Z on QWERTY), or "·" for no press.
static func input_row(history: InputHistory, columns: int) -> String:
	var cells: PackedStringArray = PackedStringArray()
	for ago: int in range(mini(columns, history.size()) - 1, -1, -1):
		var pressed: int = history.pressed_ago(ago)
		cells.append(symbols(pressed) if pressed != 0 else "·")
	return " ".join(cells)


static func symbols(bits: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var named: Array[Array] = [
		[InputFrame.LEFT, "←"], [InputFrame.RIGHT, "→"], [InputFrame.UP, "↑"], [InputFrame.DOWN, "↓"],
		[InputFrame.Z, KeyLabel.for_action(&"attack_z")], [InputFrame.X, KeyLabel.for_action(&"attack_x")],
		[InputFrame.SKILL_1, KeyLabel.for_action(&"skill_1")], [InputFrame.SKILL_2, KeyLabel.for_action(&"skill_2")],
		[InputFrame.SKILL_3, KeyLabel.for_action(&"skill_3")], [InputFrame.SKILL_4, KeyLabel.for_action(&"skill_4")],
		[InputFrame.AWAKEN, KeyLabel.for_action(&"awaken")],
	]
	for entry: Array in named:
		var bit: int = entry[0]
		var label: String = entry[1]
		if (bits & bit) != 0:
			parts.append(label)
	return "+".join(parts)


## Number of hitboxes and arrows drawn on the last refresh (for tests).
var drawn_hitboxes: int = 0


func _draw_boxes(world: SimWorld) -> void:
	_mesh.clear_surfaces()
	drawn_hitboxes = 0
	if world.movement == null:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var vertex_count: int = 0
	var m: MovementParams = world.movement
	for f: SimFighter in world.fighters:
		_rect(f.x - m.half_width, f.y, f.x + m.half_width, f.y + m.height, PUSHBOX_COLOR, 0.02)
		vertex_count += 8
		if f.character < world.characters.size():
			var hurt: HurtboxData = world.characters[f.character].hurtbox
			var cx: int = f.x + hurt.offset_x * f.facing
			_rect(cx - hurt.width / 2, f.y + hurt.offset_y, cx + hurt.width / 2, f.y + hurt.offset_y + hurt.height, HURTBOX_COLOR, 0.04)
			vertex_count += 8
		var move: MoveData = SimCombat.current_move(world, f)
		if move == null:
			continue
		for box: HitboxData in move.hitboxes:
			if f.move_tick - 1 < box.from_tick or f.move_tick - 1 > box.to_tick:
				continue
			var hx: int = f.x + box.offset_x * f.facing
			_rect(hx - box.width / 2, f.y + box.offset_y, hx + box.width / 2, f.y + box.offset_y + box.height, HITBOX_COLOR, 0.06)
			vertex_count += 8
			drawn_hitboxes += 1
	# Arrows in flight hit like hitboxes: same red.
	for projectile: SimProjectile in world.projectiles:
		var shot: ProjectileData = SimCombat.projectile_data(world, projectile)
		if shot == null:
			continue
		_rect(projectile.x - shot.width / 2, projectile.y, projectile.x + shot.width / 2, projectile.y + shot.height, HITBOX_COLOR, 0.06)
		vertex_count += 8
		drawn_hitboxes += 1
	if vertex_count == 0:
		_mesh.surface_add_vertex(Vector3.ZERO)
		_mesh.surface_add_vertex(Vector3.ZERO)
	_mesh.surface_end()


func _rect(left: int, bottom: int, right: int, top: int, color: Color, z: float) -> void:
	var corners: Array[Vector3] = [
		SimUnits.to_vector3(left, bottom, z), SimUnits.to_vector3(right, bottom, z),
		SimUnits.to_vector3(right, top, z), SimUnits.to_vector3(left, top, z),
	]
	for i: int in 4:
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(corners[i])
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(corners[(i + 1) % 4])
