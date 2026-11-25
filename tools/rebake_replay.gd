extends SceneTree
## Re-bakes the expected hashes and events of existing replay fixtures,
## keeping their recorded inputs. Run only when sim rules or move data change
## on purpose, and explain the change in the PR:
##   godot --headless -s res://tools/rebake_replay.gd -- res://test/replay/fixtures/a.tres [...]


func _init() -> void:
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	if paths.is_empty():
		push_error("rebake_replay: pass fixture paths after --")
		quit(1)
		return
	for path: String in paths:
		var replay: Replay = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Replay
		if replay == null:
			push_error("rebake_replay: cannot load %s" % path)
			quit(1)
			return
		var every: int = 60
		if not replay.checkpoint_ticks.is_empty():
			every = int(replay.checkpoint_ticks[0])
		var old_hash: String = replay.expected_final_hash
		if not ReplayRunner.bake_expectations(replay, every):
			push_error("rebake_replay: baking %s failed, nothing saved" % path)
			quit(1)
			return
		var err: Error = ResourceSaver.save(replay, path)
		if err != OK:
			push_error("rebake_replay: cannot save %s: %s" % [path, error_string(err)])
			quit(1)
			return
		print("rebake_replay: %s final hash %s -> %s" % [path, old_hash.left(12), replay.expected_final_hash.left(12)])
	quit(0)
