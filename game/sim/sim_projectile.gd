class_name SimProjectile
extends RefCounted
## A projectile in flight (integer state only). Its size, damage, hitstun and
## KD are read from the move that fired it: (character, move, index).

## Ints in snapshot order.
const FIELD_COUNT: int = 9

var id: int = 0
## Fighter id of the shooter (never hit by its own projectile).
var owner: int = 0
var character: int = 0
var move: int = 0
## Index into MoveData.projectiles.
var index: int = 0
## Center x and bottom y.
var x: int = 0
var y: int = 0
## RIGHT (1) or LEFT (-1).
var dir: int = 1
var ticks_left: int = 0


func write_to(buf: StreamPeerBuffer) -> void:
	for value: int in [id, owner, character, move, index, x, y, dir, ticks_left]:
		buf.put_64(value)


static func read_from(buf: StreamPeerBuffer) -> SimProjectile:
	if buf.get_available_bytes() < FIELD_COUNT * 8:
		return null
	var p: SimProjectile = SimProjectile.new()
	p.id = buf.get_64()
	p.owner = buf.get_64()
	p.character = buf.get_64()
	p.move = buf.get_64()
	p.index = buf.get_64()
	p.x = buf.get_64()
	p.y = buf.get_64()
	p.dir = buf.get_64()
	p.ticks_left = buf.get_64()
	if p.id <= 0 or p.character < 0 or p.move < 0 or p.index < 0 or absi(p.dir) != 1 or p.ticks_left < 1:
		return null
	return p
