class_name TrainingHud
extends CanvasLayer
## View-only training-room chrome: title, player HP / combo, hint plate.
## Reads fighter state after each tick and never writes to the sim.

@export var driver: SimDriver

var _hp_fill: ColorRect
var _hp_label: Label
var _combo_label: Label
var _built: bool = false


func _ready() -> void:
	_build()
	if driver == null:
		return
	if not driver.is_node_ready():
		await driver.ready
	driver.ticked.connect(_on_ticked)
	_refresh()


func _on_ticked(_tick: int) -> void:
	_refresh()


func _build() -> void:
	if _built:
		return
	_built = true
	var title: Label = get_node_or_null("Title") as Label
	if title != null:
		title.text = "Training Room"
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
		title.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.85))
		title.add_theme_constant_override("outline_size", 6)
	var hint: Label = get_node_or_null("InputHint") as Label
	if hint != null:
		var plate: StyleBoxFlat = StyleBoxFlat.new()
		plate.bg_color = Color(0.05, 0.06, 0.08, 0.62)
		plate.content_margin_left = 24
		plate.content_margin_right = 24
		plate.content_margin_top = 10
		plate.content_margin_bottom = 12
		hint.add_theme_stylebox_override("normal", plate)
		hint.add_theme_color_override("font_color", Color(0.86, 0.86, 0.82))
	var panel: ColorRect = ColorRect.new()
	panel.name = "PlayerPanel"
	panel.color = Color(0.05, 0.06, 0.08, 0.58)
	panel.position = Vector2(20, 56)
	panel.size = Vector2(320, 62)
	add_child(panel)
	var bar_back: ColorRect = ColorRect.new()
	bar_back.name = "HpBack"
	bar_back.color = Color(0.12, 0.10, 0.10, 0.9)
	bar_back.position = Vector2(10, 28)
	bar_back.size = Vector2(300, 14)
	panel.add_child(bar_back)
	_hp_fill = ColorRect.new()
	_hp_fill.name = "HpFill"
	_hp_fill.color = Color(0.30, 0.78, 0.45)
	_hp_fill.position = Vector2.ZERO
	_hp_fill.size = Vector2(300, 14)
	bar_back.add_child(_hp_fill)
	_hp_label = Label.new()
	_hp_label.name = "HpLabel"
	_hp_label.position = Vector2(10, 4)
	_hp_label.size = Vector2(300, 22)
	_hp_label.add_theme_font_size_override("font_size", 16)
	_hp_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	panel.add_child(_hp_label)
	_combo_label = Label.new()
	_combo_label.name = "ComboLabel"
	_combo_label.position = Vector2(348, 56)
	_combo_label.size = Vector2(280, 36)
	_combo_label.add_theme_font_size_override("font_size", 26)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	_combo_label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02, 0.9))
	_combo_label.add_theme_constant_override("outline_size", 8)
	_combo_label.visible = false
	add_child(_combo_label)


func _refresh() -> void:
	if driver == null or _hp_fill == null:
		return
	var fighters: Array[SimFighter] = driver.world.fighters
	if fighters.is_empty():
		return
	var fighter: SimFighter = fighters[0]
	var max_hp: int = _max_hp(driver.world, fighter)
	var ratio: float = clampf(float(fighter.hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	_hp_fill.size = Vector2(300.0 * ratio, 14.0)
	if ratio <= 0.25:
		_hp_fill.color = Color(0.86, 0.28, 0.22)
	elif ratio <= 0.5:
		_hp_fill.color = Color(0.90, 0.72, 0.22)
	else:
		_hp_fill.color = Color(0.30, 0.78, 0.45)
	_hp_label.text = "HP  %d / %d" % [fighter.hp, max_hp]
	# Combo counts received hits, so the dummy holds the training combo, not the player.
	var combo: int = _target_combo(driver.world)
	if combo >= 2:
		_combo_label.text = "COMBO  %d" % combo
		_combo_label.visible = true
	else:
		_combo_label.visible = false


static func _max_hp(world: SimWorld, fighter: SimFighter) -> int:
	if fighter.character >= 0 and fighter.character < world.characters.size():
		return world.characters[fighter.character].max_hp
	return maxi(fighter.hp, 1)


static func _target_combo(world: SimWorld) -> int:
	var best: int = 0
	for fighter: SimFighter in world.fighters:
		if fighter.player == SimFighter.NO_PLAYER:
			best = maxi(best, fighter.combo)
	return best
