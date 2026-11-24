class_name InputSampler
extends Node
## Bridges Godot's Input system to one immutable-per-tick InputFrame.
##
## SimDriver calls sample_tick() exactly once in its _physics_process, before
## world.step(). This node does not have its own _physics_process (so correctness
## never depends on scene-tree node order).
##
## Event latches preserve a quick press+release between two ticks; sampling
## Input's current state also catches focus changes and action_press in tests.

const ACTIONS: Array[StringName] = [
	&"left", &"right", &"up", &"down", &"attack_z", &"attack_x",
	&"skill_1", &"skill_2", &"skill_3", &"skill_4", &"awaken",
]
const BITS: Array[int] = [
	InputFrame.LEFT, InputFrame.RIGHT, InputFrame.UP, InputFrame.DOWN, InputFrame.Z, InputFrame.X,
	InputFrame.SKILL_1, InputFrame.SKILL_2, InputFrame.SKILL_3, InputFrame.SKILL_4, InputFrame.AWAKEN,
]

var _last_held: int = 0
var _event_held: int = 0
var _pressed_latch: int = 0
var _released_latch: int = 0


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	for i: int in ACTIONS.size():
		if event.is_action_pressed(ACTIONS[i]):
			if (_event_held & BITS[i]) == 0:
				_pressed_latch |= BITS[i]
			_event_held |= BITS[i]
		elif event.is_action_released(ACTIONS[i]):
			_released_latch |= BITS[i]
			_event_held &= ~BITS[i]


## Called ONCE per sim tick, by SimDriver, before the step.
func sample_tick(player: int = 0) -> InputFrame:
	var held: int = 0
	for i: int in ACTIONS.size():
		if Input.is_action_pressed(ACTIONS[i]):
			held |= BITS[i]
	var pressed: int = _pressed_latch | (held & ~_last_held)
	var released: int = _released_latch | (_last_held & ~held)
	var frame: InputFrame = InputFrame.new(player, held, pressed, released)
	_last_held = held
	_event_held = held
	_pressed_latch = 0
	_released_latch = 0
	return frame
