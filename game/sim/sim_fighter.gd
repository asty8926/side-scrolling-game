class_name SimFighter
extends RefCounted
## A player-controlled character in the sim (integer state only).
## x = pushbox center, y = feet, in sub-units; velocities in sub-units/tick.

const RIGHT: int = 1
const LEFT: int = -1
## `ground` value when standing on the room floor.
const ON_FLOOR: int = -1
## `ground` value when airborne.
const IN_AIR: int = -2

var id: int = 0
## Player index whose InputHistory drives this fighter.
var player: int = 0
var x: int = 0
var y: int = 0
var vx: int = 0
var vy: int = 0
## RIGHT (1) or LEFT (-1).
var facing: int = RIGHT
## ON_FLOOR, IN_AIR, or the index of the platform stood on.
var ground: int = ON_FLOOR
## Air jumps still available (1 = the double jump).
var air_jumps: int = 1
## 0 when not dashing, else RIGHT/LEFT (dash direction).
var dash_dir: int = 0
## Ticks left ignoring one-way platforms after a drop-through.
var drop_ticks: int = 0

## Field order for snapshots. Append new fields at the end and bump
## SimWorld.SNAPSHOT_VERSION.
const FIELD_COUNT: int = 11


func is_grounded() -> bool:
	return ground != IN_AIR


func write_to(buf: StreamPeerBuffer) -> void:
	for value: int in [id, player, x, y, vx, vy, facing, ground, air_jumps, dash_dir, drop_ticks]:
		buf.put_64(value)


static func read_from(buf: StreamPeerBuffer) -> SimFighter:
	if buf.get_available_bytes() < FIELD_COUNT * 8:
		return null
	var f: SimFighter = SimFighter.new()
	f.id = buf.get_64()
	f.player = buf.get_64()
	f.x = buf.get_64()
	f.y = buf.get_64()
	f.vx = buf.get_64()
	f.vy = buf.get_64()
	f.facing = buf.get_64()
	f.ground = buf.get_64()
	f.air_jumps = buf.get_64()
	f.dash_dir = buf.get_64()
	f.drop_ticks = buf.get_64()
	if (f.facing != RIGHT and f.facing != LEFT) or f.ground < IN_AIR or f.player < 0 or f.air_jumps < 0 or absi(f.dash_dir) > 1 or f.drop_ticks < 0:
		return null
	return f
