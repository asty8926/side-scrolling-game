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
