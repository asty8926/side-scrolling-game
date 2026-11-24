extends GutTest
## CI guard (#38): no node, scene-tree, clock, global-random or float-state
## code anywhere under game/sim/.


func test_game_sim_is_clean() -> void:
	var problems: Array[String] = SimGuard.scan_dir()
	assert_eq(problems, [] as Array[String], "violations:\n" + "\n".join(problems))


func test_guard_catches_each_forbidden_pattern() -> void:
	var bad_lines: Array[String] = [
		"var a: int = randi()",
		"var b: float = randf()",
		"randomize()",
		"var t: int = Time.get_ticks_msec()",
		"var u: int = OS.get_ticks_usec()",
		"var n: Node = get_node(\"Player\")",
		"var m: Node = $Player",
		"extends Node3D",
		"var speed: float = 0.0",
		"var pos: Vector3 = Vector3.ZERO",
		"var half := 0.5",
		"var k: bool = Input.is_action_pressed(\"z\")",
	]
	for line: String in bad_lines:
		var problems: Array[String] = SimGuard.scan_source("res://fake.gd", line)
		assert_gt(problems.size(), 0, "guard flags: %s" % line)


func test_guard_ignores_comments_and_strings() -> void:
	var source: String = "## Never call randi() or get_node() here.\nvar label: String = \"$ randf() Time.now\"  # Time.get_ticks\n"
	assert_eq(SimGuard.scan_source("res://fake.gd", source).size(), 0)
