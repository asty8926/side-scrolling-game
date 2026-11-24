class_name InputHistory
extends RefCounted
## Recent input frames of one player (ring buffer), part of the sim state.
##
## Queries:
## - double_tap(button, window): `>>` / `<<` detection.
## - buffered_press(button, buffer): a press up to `buffer` ticks old, reported
##   once then consumed.

## Frames kept. Windows and buffers must stay below this.
const CAPACITY: int = 64

var _held: PackedInt64Array = PackedInt64Array()
var _pressed: PackedInt64Array = PackedInt64Array()
var _consumed: PackedInt64Array = PackedInt64Array()
## Index of the newest frame; -1 when empty.
var _head: int = -1
## Number of frames stored (<= CAPACITY).
var _count: int = 0


func _init() -> void:
	_held.resize(CAPACITY)
	_pressed.resize(CAPACITY)
	_consumed.resize(CAPACITY)


## Appends this tick's frame (one per tick, empty frames included).
func push(frame: InputFrame) -> void:
	_head = (_head + 1) % CAPACITY
	_held[_head] = frame.held
	_pressed[_head] = frame.pressed
	_consumed[_head] = 0
	_count = mini(_count + 1, CAPACITY)


## Buttons held in the newest frame.
## Frames stored (at most CAPACITY).
func size() -> int:
	return _count


func held_now() -> int:
	return _held[_head] if _count > 0 else 0


## Buttons pressed `ago` ticks back (0 = this tick). 0 outside the history.
func pressed_ago(ago: int) -> int:
	if ago < 0 or ago >= _count:
		return 0
	return _pressed[(_head - ago + CAPACITY) % CAPACITY]


## True on the tick where `button` is pressed for the 2nd time within
## `window_ticks` of the previous press. Holding never retriggers (no new press
## edge), and a 3rd quick press does not count again: presses pair up
## (2nd, 4th... in a chain of presses each within the window).
func double_tap(button: int, window_ticks: int) -> bool:
	if (pressed_ago(0) & button) == 0:
		return false
	var chain: int = 1
	var last: int = 0
	var ago: int = 1
	while ago < _count and ago - last <= window_ticks:
		if (pressed_ago(ago) & button) != 0:
			chain += 1
			last = ago
		ago += 1
	return chain % 2 == 0


## True once if `button` was pressed within the last `buffer_ticks` ticks
## (0 = this tick only) and that press was not consumed yet. Consumes it.
func buffered_press(button: int, buffer_ticks: int) -> bool:
	var ago: int = 0
	while ago <= buffer_ticks and ago < _count:
		var index: int = (_head - ago + CAPACITY) % CAPACITY
		if (_pressed[index] & button) != 0 and (_consumed[index] & button) == 0:
			_consumed[index] |= button
			return true
		ago += 1
	return false


## Appends the state in a fixed order (oldest frame first) to `buf`.
func write_to(buf: StreamPeerBuffer) -> void:
	buf.put_32(_count)
	for i: int in _count:
		var index: int = (_head - (_count - 1 - i) + CAPACITY) % CAPACITY
		buf.put_64(_held[index])
		buf.put_64(_pressed[index])
		buf.put_64(_consumed[index])


## Reads what write_to wrote. Returns null on invalid data.
static func read_from(buf: StreamPeerBuffer) -> InputHistory:
	if buf.get_available_bytes() < 4:
		return null
	var count: int = buf.get_32()
	if count < 0 or count > CAPACITY or buf.get_available_bytes() < count * 3 * 8:
		return null
	var history: InputHistory = InputHistory.new()
	for i: int in count:
		history._head = i
		history._held[i] = buf.get_64()
		history._pressed[i] = buf.get_64()
		history._consumed[i] = buf.get_64()
	history._count = count
	return history
