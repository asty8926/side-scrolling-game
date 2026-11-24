class_name Replay
extends Resource
## A recorded input sequence that rebuilds a play session tick by tick.
##
## Saved as a text `.tres`. Frames are for player 0 (single-player until M5),
## run-length encoded as pairs [packed_frame, run_length]; packed_frame is
## held | pressed << 11 | released << 22 (see InputFrame bits).

const SHIFT: int = 11
const MASK: int = (1 << SHIFT) - 1

## Seed of the world.
@export var world_seed: int = 1
## Which world setup to build before replaying (see SimSetup).
@export var setup: StringName = &"empty"
## Optional: SimWorld snapshot at the first recorded tick (recording started mid-session).
@export var start_snapshot: PackedByteArray = PackedByteArray()
## Version tag of the recording build, e.g. "sim-v2 godot-4.7.2". Informational.
@export var version_tag: String = ""
## Run-length encoded frames: [packed, count, packed, count, ...].
@export var frames: PackedInt64Array = PackedInt64Array()
## Hash checkpoints: ticks (relative to the replay start) and expected hashes.
@export var checkpoint_ticks: PackedInt64Array = PackedInt64Array()
@export var checkpoint_hashes: PackedStringArray = PackedStringArray()
## Expected hash after the last frame ("" = not checked).
@export var expected_final_hash: String = ""
## Expected events as SimEvent.to_text() lines (empty = not checked).
@export var expected_events: PackedStringArray = PackedStringArray()


static func pack(frame: InputFrame) -> int:
	return frame.held | (frame.pressed << SHIFT) | (frame.released << (SHIFT * 2))


static func unpack(packed: int, player: int = 0) -> InputFrame:
	return InputFrame.new(player, packed & MASK, (packed >> SHIFT) & MASK, (packed >> (SHIFT * 2)) & MASK)


## Appends one tick (merges with the previous run when identical).
func append_frame(frame: InputFrame) -> void:
	var packed: int = pack(frame)
	var n: int = frames.size()
	if n >= 2 and frames[n - 2] == packed:
		frames[n - 1] += 1
	else:
		frames.append(packed)
		frames.append(1)


## Total number of ticks.
func tick_count() -> int:
	var total: int = 0
	for i: int in range(1, frames.size(), 2):
		total += frames[i]
	return total


## Expanded per-tick frames.
func expand() -> Array[InputFrame]:
	var out: Array[InputFrame] = []
	for i: int in range(0, frames.size() - 1, 2):
		for r: int in frames[i + 1]:
			out.append(unpack(frames[i]))
	return out


## Returns a list of problems; empty when usable.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if frames.size() % 2 != 0:
		problems.append("frames must be [packed, count] pairs (odd length %d)" % frames.size())
	for i: int in range(0, frames.size() - 1, 2):
		if frames[i + 1] <= 0:
			problems.append("run %d has count %d" % [i / 2, frames[i + 1]])
		if not unpack(frames[i]).is_valid() or (frames[i] >> (SHIFT * 3)) != 0:
			problems.append("run %d has unknown button bits" % (i / 2))
	if checkpoint_ticks.size() != checkpoint_hashes.size():
		problems.append("checkpoint_ticks and checkpoint_hashes differ in length")
	if not SimSetup.has_setup(setup):
		problems.append("unknown setup '%s'" % setup)
	return problems
