class_name InputFrame
extends RefCounted
## What one player did during one sim tick. The ONLY input of the simulation.
##
## Three bitmasks over the same button bits (constants below):
## - `held`: buttons down at the end of the tick,
## - `pressed`: buttons that went down during the tick (edge),
## - `released`: buttons that went up during the tick (edge).
## A quick tap that starts and ends inside one tick shows up in `pressed` and
## `released` while `held` stays 0, so it is never lost.

const LEFT: int = 1 << 0
const RIGHT: int = 1 << 1
const UP: int = 1 << 2
const DOWN: int = 1 << 3
const Z: int = 1 << 4
const X: int = 1 << 5
const SKILL_1: int = 1 << 6
const SKILL_2: int = 1 << 7
const SKILL_3: int = 1 << 8
const SKILL_4: int = 1 << 9
const AWAKEN: int = 1 << 10
## Every valid bit. Bits outside this mask are rejected by the sim.
const ALL_BUTTONS: int = (1 << 11) - 1

var player: int = 0
var held: int = 0
var pressed: int = 0
var released: int = 0


func _init(player_index: int = 0, held_bits: int = 0, pressed_bits: int = 0, released_bits: int = 0) -> void:
	player = player_index
	held = held_bits
	pressed = pressed_bits
	released = released_bits


## Builds the next frame from the previous `held` mask and the new one
## (edges derived). Used by tests and by replays that only store held bits.
static func from_held(player_index: int, previous_held: int, new_held: int) -> InputFrame:
	return InputFrame.new(player_index, new_held, new_held & ~previous_held, previous_held & ~new_held)


func is_valid() -> bool:
	return ((held | pressed | released) & ~ALL_BUTTONS) == 0
