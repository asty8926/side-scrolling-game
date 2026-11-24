extends ReplayTest
## Training dummy (#45): HP, hitstun, KD and combo readout from the sim.

const Z: int = InputFrame.Z


func _dummy(result: ReplayRunner.Result) -> SimFighter:
	return result.world.fighters[1]


func _zzzz() -> ReplayRunner.Result:
	var presses: Dictionary[int, int] = {}
	for tick: int in range(0, 31, 6):
		presses[tick] = Z
	var result: ReplayRunner.Result = ReplayRunner.run(tapped(&"training", 40, presses))
	assert_true(result.ok, "\n".join(result.problems))
	return result


func test_zzzz_on_the_dummy_counts_four_and_sums_kd() -> void:
	var result: ReplayRunner.Result = _zzzz()
	var dummy: SimFighter = _dummy(result)
	assert_eq(events_of(result, "hit").size(), 4)
	var moves: MoveSet = (load(SimSetup.RANGER) as CharacterData).moveset
	var kd_sum: int = 0
	var damage_sum: int = 0
	for move_id: StringName in [&"ranger_z1", &"ranger_z2", &"ranger_z3", &"ranger_z4"]:
		var move: MoveData = moves.moves[moves.index_of(move_id)]
		kd_sum += move.kd
		damage_sum += move.damage_percent  # ranger attack = 100
	assert_eq(dummy.combo, 4, "combo counter 4: still in hitstun between the hits")
	assert_eq(dummy.kd, kd_sum, "KD = sum of the 4 kicks' KD")
	assert_eq(dummy.hp, (load(SimSetup.DUMMY) as CharacterData).max_hp - damage_sum)
	assert_gt(dummy.hitstun, 0, "in hitstun after the last kick")
	assert_eq(dummy.last_damage, 339)


func test_kd_and_combo_wear_off_after_hitstun() -> void:
	var presses: Dictionary[int, int] = {0: Z}
	var result: ReplayRunner.Result = ReplayRunner.run(tapped(&"training", 200, presses))
	var dummy: SimFighter = _dummy(result)
	assert_eq(dummy.hitstun, 0)
	assert_eq(dummy.kd, 0, "placeholder rule: KD recovers once out of hitstun")
	var again: ReplayRunner.Result = ReplayRunner.run(tapped(&"training", 200, {0: Z, 120: Z}))
	assert_eq(_dummy(again).combo, 1, "a hit after hitstun ended starts a new combo")


func test_pushback_moves_the_dummy_away() -> void:
	var result: ReplayRunner.Result = _zzzz()
	assert_gt(_dummy(result).x, SimSetup.DUMMY_OFFSET, "pushed away from the attacker")


func test_reset_restores_the_dummy() -> void:
	var result: ReplayRunner.Result = _zzzz()
	var world: SimWorld = result.world
	world.reset_dummies()
	var dummy: SimFighter = _dummy(result)
	assert_eq(dummy.hp, (load(SimSetup.DUMMY) as CharacterData).max_hp)
	assert_eq(dummy.kd, 0)
	assert_eq(dummy.combo, 0)
	assert_eq(dummy.hitstun, 0)
	assert_eq(dummy.x, dummy.home_x)
	assert_eq(world.fighters[0].hp, (load(SimSetup.RANGER) as CharacterData).max_hp, "the player is untouched")


func test_readout_shows_hp_kd_combo() -> void:
	var text: String = FighterView.readout_text(_dummy(_zzzz()))
	assert_string_contains(text, "Combo 4")
	assert_string_contains(text, "KD ")
	assert_string_contains(text, "HP ")


func test_arrows_hit_the_dummy_from_range_with_hitstun_and_pushback() -> void:
	var world: SimWorld = SimSetup.create(&"training", 1)
	var dummy: SimFighter = world.fighters[1]
	dummy.x += 4000  # 5 m away: out of kick range, inside arrow range
	dummy.home_x = dummy.x
	var start_x: int = dummy.x
	var x1: MoveData = world.characters[0].moveset.moves[4]
	var previous: int = 0
	var hit_tick: int = -1
	for tick: int in 40:
		var held: int = InputFrame.X if tick == 0 else 0
		world.step([InputFrame.from_held(0, previous, held)] as Array[InputFrame])
		previous = held
		for event: SimEvent in world.events:
			if event.type == &"hit" and hit_tick < 0:
				hit_tick = tick
				assert_eq(dummy.hitstun, x1.hitstun_ticks, "hitstun from the move")
				assert_eq(dummy.kd, x1.kd, "KD from the move")
				assert_eq(dummy.combo, 1)
				assert_eq(dummy.last_damage, world.characters[0].attack * x1.damage_percent / 100)
	assert_gt(hit_tick, x1.projectiles[0].spawn_tick + 1, "the arrow needs time to fly 5 m")
	assert_eq(dummy.x, start_x + x1.pushback, "pushed along the arrow's flight")
