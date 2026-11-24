class_name SimRng
extends RefCounted
## Seeded, deterministic random numbers owned by the simulation.
##
## Algorithm: xoshiro128** (32-bit words), seeded through a 32-bit mixer.
## All intermediate values stay below 2^63, so GDScript's 64-bit signed `int`
## never overflows and results are identical on every platform.
## Never use the global randi()/randf() in game/sim/: they are not seeded by
## the sim and break replays.

const MASK32: int = 0xFFFFFFFF

var _s0: int = 0
var _s1: int = 0
var _s2: int = 0
var _s3: int = 0


func _init(seed_value: int = 1) -> void:
	reseed(seed_value)


## Resets the generator from any 64-bit seed. Same seed, same sequence.
func reseed(seed_value: int) -> void:
	var lo: int = seed_value & MASK32
	var hi: int = (seed_value >> 32) & MASK32
	# Every state word depends on both halves of the seed.
	_s0 = _mix32(_mix32((lo + 0x9E3779B9) & MASK32) ^ hi)
	_s1 = _mix32(_mix32((lo + 0x85EBCA6B) & MASK32) ^ hi ^ 0x27D4EB2F)
	_s2 = _mix32(_mix32((lo + 0x6A09E667) & MASK32) ^ hi ^ 0x165667B1)
	_s3 = _mix32(_mix32((lo + 0xBB67AE85) & MASK32) ^ hi ^ 0xD3A2646C)
	if (_s0 | _s1 | _s2 | _s3) == 0:
		_s0 = 1  # xoshiro must never have an all-zero state


## Next raw value in [0, 2^32 - 1].
func next_u32() -> int:
	var result: int = _mul32(_rotl32(_mul32(_s1, 5), 7), 9)
	var t: int = (_s1 << 9) & MASK32
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= t
	_s3 = _rotl32(_s3, 11)
	return result


## Uniform integer in [min_value, max_value] (both inclusive), without modulo bias.
func range_int(min_value: int, max_value: int) -> int:
	if max_value < min_value:
		push_error("SimRng.range_int: max_value (%d) < min_value (%d)" % [max_value, min_value])
		return min_value
	# Width check written so it cannot overflow 64-bit ints: span > 2^32 values
	# exactly when max - min > MASK32.
	var too_wide: bool = max_value > min_value + MASK32 if min_value < 0 else max_value - min_value > MASK32
	if too_wide:
		push_error("SimRng.range_int: [%d, %d] has more than 2^32 values" % [min_value, max_value])
		return min_value
	var span: int = max_value - min_value + 1
	var limit: int = (MASK32 + 1) - ((MASK32 + 1) % span)
	var value: int = next_u32()
	while value >= limit:
		value = next_u32()
	return min_value + (value % span)


## True with probability numerator / denominator (integers only, no floats).
## Supported denominators: 1 to 2^32. Out of range is an error and returns false.
func chance(numerator: int, denominator: int) -> bool:
	if denominator <= 0 or denominator > MASK32 + 1:
		push_error("SimRng.chance: denominator must be in [1, 2^32] (got %d)" % denominator)
		return false
	return range_int(0, denominator - 1) < numerator


## The 4 state words, for snapshots.
func get_state() -> PackedInt64Array:
	return PackedInt64Array([_s0, _s1, _s2, _s3])


## Restores the 4 state words from a snapshot. Returns false (and keeps the
## current state) when the words are invalid.
func set_state(words: PackedInt64Array) -> bool:
	if words.size() != 4:
		push_error("SimRng.set_state: expected 4 words, got %d" % words.size())
		return false
	for word: int in words:
		if word < 0 or word > MASK32:
			push_error("SimRng.set_state: word out of 32-bit range: %d" % word)
			return false
	if (words[0] | words[1] | words[2] | words[3]) == 0:
		push_error("SimRng.set_state: all-zero state is invalid")
		return false
	_s0 = words[0]
	_s1 = words[1]
	_s2 = words[2]
	_s3 = words[3]
	return true


static func _rotl32(x: int, k: int) -> int:
	return ((x << k) | (x >> (32 - k))) & MASK32


## (a * b) mod 2^32 for a, b in [0, 2^32), split in 16-bit halves so the
## product never exceeds 2^63.
static func _mul32(a: int, b: int) -> int:
	var low: int = a * (b & 0xFFFF)
	var high: int = ((a * (b >> 16)) & 0xFFFF) << 16
	return (low + high) & MASK32


## 32-bit finalizer (MurmurHash3 fmix32): spreads seed bits.
static func _mix32(value: int) -> int:
	var h: int = value & MASK32
	h ^= h >> 16
	h = _mul32(h, 0x85EBCA6B)
	h ^= h >> 13
	h = _mul32(h, 0xC2B2AE35)
	h ^= h >> 16
	return h
