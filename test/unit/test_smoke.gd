extends GutTest
## Smoke test: proves GUT runs headless and the project settings are the ones AGENTS.md requires.


func test_gut_runs() -> void:
	assert_true(true, "GUT is wired up")


func test_physics_tick_is_60_hz() -> void:
	var ticks: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 0)
	assert_eq(ticks, 60, "the sim runs at a fixed 60 Hz tick")


func test_untyped_declaration_is_an_error() -> void:
	var level: int = ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration", 0)
	assert_eq(level, 2, "untyped declarations must fail to parse")


func test_main_scene_loads() -> void:
	var scene: PackedScene = load("res://game/main.tscn")
	assert_not_null(scene, "main scene loads")


func test_viewport_is_1920x1080_with_hidpi_and_canvas_stretch() -> void:
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width", 0)
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height", 0)
	var stretch: String = ProjectSettings.get_setting("display/window/stretch/mode", "")
	var aspect: String = ProjectSettings.get_setting("display/window/stretch/aspect", "")
	var hidpi: bool = ProjectSettings.get_setting("display/window/dpi/allow_hidpi", false)
	assert_eq(width, 1920)
	assert_eq(height, 1080)
	assert_eq(stretch, "canvas_items")
	assert_eq(aspect, "expand")
	assert_true(hidpi, "Retina / hi-DPI is on")


func test_main_scene_has_a_display_mode_toggle() -> void:
	var scene: PackedScene = load("res://game/main.tscn")
	var root: Node = scene.instantiate()
	var node: Node = root.get_node_or_null("DisplayMode")
	assert_not_null(node, "DisplayMode is in the main scene")
	assert_true(node is DisplayMode)
	root.free()
