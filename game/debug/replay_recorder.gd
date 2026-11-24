class_name ReplayRecorder
extends Node
## Debug builds only: F9 (`debug_record_replay`) starts/stops recording the
## inputs fed to the parent SimDriver. On stop it saves
## user://replays/<timestamp>.tres and prints the full path. Copy that file
## into test/replay/fixtures/ to turn it into a CI test.

const SAVE_DIR: String = "user://replays"

## Set to false to keep the recorder idle (it is also idle in release builds).
@export var enabled: bool = true

var _driver: SimDriver
var _replay: Replay
var _live_hash_at_end: String = ""


func _ready() -> void:
	_driver = get_parent() as SimDriver
	if _driver == null:
		push_error("ReplayRecorder: must be a child of a SimDriver")
		enabled = false
		return
	_driver.stepped.connect(_on_stepped)


func is_recording() -> bool:
	return _replay != null


func _unhandled_input(event: InputEvent) -> void:
	if enabled and OS.is_debug_build() and event.is_action_pressed(&"debug_record_replay") and not event.is_echo():
		toggle()


func toggle() -> void:
	if is_recording():
		stop_and_save()
	else:
		start()


func start() -> void:
	_replay = Replay.new()
	_replay.world_seed = _driver.world.world_seed
	_replay.setup = _driver.setup
	_replay.start_snapshot = _driver.world.snapshot()
	_replay.version_tag = "sim-v%d godot-%s" % [SimWorld.SNAPSHOT_VERSION, Engine.get_version_info().get("string", "?")]
	print("ReplayRecorder: recording started at tick %d (F9 to stop)" % _driver.world.tick)


## Stops, bakes expected hashes/events, saves. Returns the saved path or "".
func stop_and_save() -> String:
	if _replay == null:
		return ""
	var replay: Replay = _replay
	_replay = null
	_live_hash_at_end = _driver.world.state_hash()
	if not ReplayRunner.bake_expectations(replay):
		push_error("ReplayRecorder: cannot re-run the recording, not saved")
		return ""
	if replay.expected_final_hash != _live_hash_at_end:
		push_error("ReplayRecorder: replaying the recording does not reproduce the live game (desync): live %s, replay %s" % [_live_hash_at_end, replay.expected_final_hash])
	var err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		push_error("ReplayRecorder: cannot create %s: %s" % [SAVE_DIR, error_string(err)])
		return ""
	var stamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var path: String = "%s/%s.tres" % [SAVE_DIR, stamp]
	err = ResourceSaver.save(replay, path)
	if err != OK:
		push_error("ReplayRecorder: cannot save %s: %s" % [path, error_string(err)])
		return ""
	print("ReplayRecorder: saved %d ticks to %s" % [replay.tick_count(), ProjectSettings.globalize_path(path)])
	return path


func _on_stepped(frames: Array[InputFrame]) -> void:
	if _replay == null:
		return
	var mine: InputFrame = InputFrame.new()
	for frame: InputFrame in frames:
		if frame.player == 0:
			mine = frame
	_replay.append_frame(mine)
