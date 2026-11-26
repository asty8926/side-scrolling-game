class_name SimFighter
extends RefCounted
## A character in the sim (integer state only): a player's fighter, or a
## fighter without input (player NO_PLAYER) such as the training dummy.
## x = pushbox center, y = feet, in sub-units; velocities in sub-units/tick.

const RIGHT: int = 1
const LEFT: int = -1
## `ground` value when standing on the room floor.
const ON_FLOOR: int = -1
## `ground` value when airborne.
const IN_AIR: int = -2
## `player` of a fighter that reads no input.
const NO_PLAYER: int = -1
## `move` when no move is playing.
const NO_MOVE: int = -1

var id: int = 0
## Player index whose InputHistory drives this fighter, or NO_PLAYER.
var player: int = 0
## Index into SimWorld.characters.
var character: int = 0
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

## Index of the playing move in the character's MoveSet, or NO_MOVE.
var move: int = NO_MOVE
## Ticks since the move started (0 on its first tick).
var move_tick: int = 0
## Ticks since the fighter was last free of a move (capped), so a press made
## during a finished string's recovery does not restart it.
var idle_ticks: int = 0
## (hitbox index << 32) | target id, for every hit the current move landed:
## each hitbox hits each target once per activation.
var hit_keys: PackedInt64Array = PackedInt64Array()
var hp: int = 0
## Ticks left unable to act after being hit.
var hitstun: int = 0
## KD gauge (display only in M0: no knockdown yet).
var kd: int = 0
## Hits taken in a row while in hitstun (1 = a fresh hit).
var combo: int = 0
## Damage of the last hit taken.
var last_damage: int = 0
## Where the debug reset puts the fighter back.
var home_x: int = 0
## Ticks a dash attack may still start after the run key was released (0 = none).
var dash_attack_ticks: int = 0
## Ticks of hit-stop left (freezes this fighter and, via SimWorld.step, the
## rest of the sim until it expires). Not motion, just a pause counter.
var hitstop: int = 0
## When non-zero, the fighter is in the `<<>` twitch: facing the other way
## with no step, waiting for a press of this facing (the original forward)
## to snap back and reset the string.
var dir_cancel_facing: int = 0

## Fixed fields in snapshot order (hit_keys follow as a count + values).
## Append new fields at the end and bump SimWorld.SNAPSHOT_VERSION.
## Transient, not in snapshots: whether this tick started in hitstun (set by
## SimCombat.apply_motion before any hit of the tick, so it is never stale).
var stunned_this_tick: bool = false

const FIELD_COUNT: int = 24
## Most hits one move can record (hitboxes x targets).
const MAX_HIT_KEYS: int = 256


func is_grounded() -> bool:
	return ground != IN_AIR


func is_in_move() -> bool:
	return move != NO_MOVE


func is_in_hitstun() -> bool:
	return hitstun > 0


func write_to(buf: StreamPeerBuffer) -> void:
	for value: int in [id, player, character, x, y, vx, vy, facing, ground, air_jumps, dash_dir, drop_ticks, move, move_tick, idle_ticks, hp, hitstun, kd, combo, last_damage, home_x, dash_attack_ticks, hitstop, dir_cancel_facing]:
		buf.put_64(value)
	buf.put_32(hit_keys.size())
	for key: int in hit_keys:
		buf.put_64(key)


static func read_from(buf: StreamPeerBuffer) -> SimFighter:
	if buf.get_available_bytes() < FIELD_COUNT * 8 + 4:
		return null
	var f: SimFighter = SimFighter.new()
	f.id = buf.get_64()
	f.player = buf.get_64()
	f.character = buf.get_64()
	f.x = buf.get_64()
	f.y = buf.get_64()
	f.vx = buf.get_64()
	f.vy = buf.get_64()
	f.facing = buf.get_64()
	f.ground = buf.get_64()
	f.air_jumps = buf.get_64()
	f.dash_dir = buf.get_64()
	f.drop_ticks = buf.get_64()
	f.move = buf.get_64()
	f.move_tick = buf.get_64()
	f.idle_ticks = buf.get_64()
	f.hp = buf.get_64()
	f.hitstun = buf.get_64()
	f.kd = buf.get_64()
	f.combo = buf.get_64()
	f.last_damage = buf.get_64()
	f.home_x = buf.get_64()
	f.dash_attack_ticks = buf.get_64()
	f.hitstop = buf.get_64()
	f.dir_cancel_facing = buf.get_64()
	var key_count: int = buf.get_32()
	if key_count < 0 or key_count > MAX_HIT_KEYS or buf.get_available_bytes() < key_count * 8:
		return null
	for i: int in key_count:
		f.hit_keys.append(buf.get_64())
	if (f.facing != RIGHT and f.facing != LEFT) or f.ground < IN_AIR or f.player < NO_PLAYER or f.character < 0:
		return null
	if f.air_jumps < 0 or absi(f.dash_dir) > 1 or f.drop_ticks < 0:
		return null
	if f.move < NO_MOVE or f.move_tick < 0 or f.idle_ticks < 0 or f.hp < 0 or f.hitstun < 0 or f.kd < 0 or f.combo < 0 or f.dash_attack_ticks < 0 or f.hitstop < 0:
		return null
	if absi(f.dir_cancel_facing) > 1:
		return null
	return f
