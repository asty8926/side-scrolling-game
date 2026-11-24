extends GutTest
## Determinism rule (docs/roadmap.md, AGENTS.md section 3) for the sim core (#38).

const TICKS: int = 600
## First 4 SimRng outputs for seed 1, cross-checked against an independent
## Python implementation of the same seeding + xoshiro128**.
const GOLDEN_SEED_1: Array[int] = [4266011616, 1056828797, 3030579440, 3292237493]


## Scripted, varied but reproducible inputs for 2 players.
func _inputs_for(t: int) -> Array[InputFrame]:
	var frames: Array[InputFrame] = []
	frames.append(InputFrame.new(0, (t * 7) % 32))
	if t % 3 == 0:
		frames.append(InputFrame.new(1, (t * 13) % 64))
	return frames


func _make_world(seed_value: int) -> SimWorld:
	var world: SimWorld = SimWorld.new(seed_value)
	world.add_entity(SimEntity.new(0, 0, 25, 0))
	world.add_entity(SimEntity.new(SimUnits.from_meters(3), 0, -10, 4))
	return world


func test_same_seed_same_inputs_same_hash_every_tick() -> void:
	var a: SimWorld = _make_world(1234)
	var b: SimWorld = _make_world(1234)
	assert_eq(a.state_hash(), b.state_hash(), "hash before the first tick")
	var mismatches: int = 0
	for t: int in TICKS:
		a.step(_inputs_for(t))
		b.step(_inputs_for(t))
		if a.state_hash() != b.state_hash():
			mismatches += 1
	assert_eq(mismatches, 0, "identical state_hash() at each of the %d ticks" % TICKS)
	assert_eq(a.tick, TICKS)


func test_empty_inputs_are_deterministic_too() -> void:
	var a: SimWorld = SimWorld.new(7)
	var b: SimWorld = SimWorld.new(7)
	var empty: Array[InputFrame] = []
	for t: int in TICKS:
		a.step(empty)
		b.step(empty)
	assert_eq(a.state_hash(), b.state_hash())


func test_hash_reacts_to_different_inputs() -> void:
	var a: SimWorld = _make_world(1234)
	var b: SimWorld = _make_world(1234)
	a.step([InputFrame.new(0, 1)] as Array[InputFrame])
	b.step([InputFrame.new(0, 2)] as Array[InputFrame])
	assert_ne(a.state_hash(), b.state_hash(), "different inputs give different hashes")


func test_hash_sees_empty_frames_and_input_timing() -> void:
	var none: Array[InputFrame] = []
	var a: SimWorld = SimWorld.new(1)
	var b: SimWorld = SimWorld.new(1)
	a.step(none)
	b.step([InputFrame.new(0, 0)] as Array[InputFrame])
	assert_ne(a.state_hash(), b.state_hash(), "an all-zero frame differs from no frame")

	var early: SimWorld = SimWorld.new(1)
	var late: SimWorld = SimWorld.new(1)
	early.step([InputFrame.new(0, 4)] as Array[InputFrame])
	early.step(none)
	late.step(none)
	late.step([InputFrame.new(0, 4)] as Array[InputFrame])
	assert_ne(early.state_hash(), late.state_hash(), "the same input one tick later differs")


func test_adding_the_same_entity_twice_is_rejected() -> void:
	var world: SimWorld = SimWorld.new(1)
	var entity: SimEntity = SimEntity.new()
	assert_eq(world.add_entity(entity), 1)
	assert_eq(world.add_entity(entity), -1)
	assert_eq(world.entities.size(), 1)
	assert_eq(entity.id, 1, "id unchanged")
	assert_push_error_count(1)


func test_input_order_within_a_tick_does_not_matter() -> void:
	var a: SimWorld = SimWorld.new(1)
	var b: SimWorld = SimWorld.new(1)
	a.step([InputFrame.new(0, 5), InputFrame.new(1, 9)] as Array[InputFrame])
	b.step([InputFrame.new(1, 9), InputFrame.new(0, 5)] as Array[InputFrame])
	assert_eq(a.state_hash(), b.state_hash())


func test_entities_move_by_integer_velocity() -> void:
	var world: SimWorld = SimWorld.new(1)
	var entity: SimEntity = SimEntity.new(100, 200, 3, -2)
	var id: int = world.add_entity(entity)
	var empty: Array[InputFrame] = []
	for t: int in 10:
		world.step(empty)
	assert_eq(id, 1)
	assert_eq(entity.x, 130)
	assert_eq(entity.y, 180)


func test_restore_then_step_matches_original() -> void:
	var original: SimWorld = _make_world(99)
	for t: int in 300:
		original.step(_inputs_for(t))
	original.rng.next_u32()  # RNG state must survive the round trip too
	var snap: PackedByteArray = original.snapshot()

	var restored: SimWorld = SimWorld.new(1)
	assert_eq(restored.restore(snap), OK, "restore accepts its own snapshot")
	assert_eq(restored.state_hash(), original.state_hash(), "same hash right after restore")

	var mismatches: int = 0
	for t: int in range(300, 600):
		original.step(_inputs_for(t))
		restored.step(_inputs_for(t))
		if original.state_hash() != restored.state_hash():
			mismatches += 1
	assert_eq(mismatches, 0, "restored world stays in lockstep for 300 ticks")
	assert_eq(restored.rng.next_u32(), original.rng.next_u32(), "RNG continues identically")


func test_restore_rejects_bad_data_and_keeps_state() -> void:
	var world: SimWorld = _make_world(5)
	var empty: Array[InputFrame] = []
	world.step(empty)
	var before: String = world.state_hash()

	assert_eq(world.restore(PackedByteArray([1, 2, 3])), ERR_INVALID_DATA, "too small")
	var truncated: PackedByteArray = world.snapshot().slice(0, -8)
	assert_eq(world.restore(truncated), ERR_INVALID_DATA, "truncated")
	var wrong_magic: PackedByteArray = world.snapshot()
	wrong_magic[0] = wrong_magic[0] ^ 0xFF
	assert_eq(world.restore(wrong_magic), ERR_INVALID_DATA, "bad magic")
	var bad_next_id: PackedByteArray = world.snapshot()
	bad_next_id.encode_s64(4 + 4 + 8 * 7, 2)  # next id 2 while entity id 2 exists
	assert_eq(world.restore(bad_next_id), ERR_INVALID_DATA, "next id not above existing ids")
	assert_eq(world.state_hash(), before, "state untouched after failed restores")
	assert_push_error_count(4, "each rejected snapshot reports a push_error")


func test_rng_same_seed_same_sequence() -> void:
	var a: SimRng = SimRng.new(42)
	var b: SimRng = SimRng.new(42)
	var mismatches: int = 0
	for i: int in 1000:
		if a.next_u32() != b.next_u32():
			mismatches += 1
	assert_eq(mismatches, 0)


func test_rng_different_seed_different_sequence() -> void:
	var a: SimRng = SimRng.new(42)
	var b: SimRng = SimRng.new(43)
	var same: int = 0
	for i: int in 100:
		if a.next_u32() == b.next_u32():
			same += 1
	assert_lt(same, 3, "seeds 42 and 43 produce different sequences")


func test_world_rng_is_seeded_by_world_seed() -> void:
	assert_eq(SimWorld.new(8).rng.next_u32(), SimWorld.new(8).rng.next_u32())
	assert_ne(SimWorld.new(8).rng.next_u32(), SimWorld.new(9).rng.next_u32())


func test_rng_known_values_are_stable() -> void:
	# Golden values: if this fails, the RNG changed and every replay breaks.
	var rng: SimRng = SimRng.new(1)
	var values: Array[int] = []
	for i: int in 4:
		values.append(rng.next_u32())
	assert_eq(values, GOLDEN_SEED_1, "first 4 values for seed 1")


func test_rng_values_stay_in_range() -> void:
	var rng: SimRng = SimRng.new(2026)
	var out_of_range: int = 0
	var seen: Dictionary[int, bool] = {}
	for i: int in 2000:
		var value: int = rng.range_int(-3, 3)
		if value < -3 or value > 3:
			out_of_range += 1
		seen[value] = true
		var raw: int = rng.next_u32()
		if raw < 0 or raw > SimRng.MASK32:
			out_of_range += 1
	assert_eq(out_of_range, 0)
	assert_eq(seen.size(), 7, "every value of [-3, 3] shows up")


func test_rng_rejects_ranges_wider_than_2_pow_32() -> void:
	var rng: SimRng = SimRng.new(3)
	assert_eq(rng.range_int(0, 9223372036854775807), 0, "huge range returns min with an error")
	assert_eq(rng.range_int(-9223372036854775807 - 1, 9223372036854775807), -9223372036854775807 - 1)
	assert_eq(rng.range_int(5, 5), 5, "singleton range")
	assert_between(rng.range_int(0, SimRng.MASK32), 0, SimRng.MASK32, "exactly 2^32 values still works")
	assert_false(rng.chance(1, SimRng.MASK32 + 2), "unsupported denominator is never a success")
	assert_push_error_count(3)


func test_rng_huge_seed_works() -> void:
	var rng: SimRng = SimRng.new(-1)
	var value: int = rng.next_u32()
	assert_between(value, 0, SimRng.MASK32)

