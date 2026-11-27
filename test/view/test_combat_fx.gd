extends GutTest
## CombatFx and FighterView hit / dash presentation is view-only.


func _training_world() -> SimWorld:
	var world: SimWorld = SimSetup.create(&"training", 1)
	assert_not_null(world, "training setup loads")
	return world


func test_a_hit_event_spawns_a_damage_number_and_sparks() -> void:
	var world: SimWorld = _training_world()
	var target: SimFighter = world.fighters[1]
	var event: SimEvent = SimEvent.new(world.tick, &"hit", world.fighters[0].id, target.id, &"ranger_z2")
	event.damage = 42
	world.events.append(event)
	var fx: CombatFx = CombatFx.new()
	add_child_autofree(fx)
	fx.present(world)
	assert_gt(fx.active_count(), 8, "sparks plus a damage number")
	var labels: Array[Label3D] = fx.damage_labels()
	assert_eq(labels.size(), 1, "one floating number per hit")
	assert_eq(labels[0].text, "42")


func test_a_dash_event_spawns_dust_at_the_fighters_feet() -> void:
	var world: SimWorld = _training_world()
	world.events.append(SimEvent.new(world.tick, &"dash", world.fighters[0].id))
	var fx: CombatFx = CombatFx.new()
	add_child_autofree(fx)
	fx.present(world)
	assert_eq(fx.active_count(), CombatFx.DUST_DIRS.size(), "one puff per dust direction")
	assert_eq(fx.damage_labels().size(), 0, "dash dust is not a damage number")


func test_a_running_fighter_leaves_a_motion_trail() -> void:
	var world: SimWorld = _training_world()
	world.fighters[0].dash_dir = SimFighter.RIGHT
	var fx: CombatFx = CombatFx.new()
	add_child_autofree(fx)
	fx.present(world)
	var after_first: int = fx.active_count()
	fx.present(world)
	assert_gt(fx.active_count(), after_first, "a ghost is spawned on even trailing ticks")


func test_notify_hit_flashes_the_fighter_and_then_fades() -> void:
	var view: FighterView = FighterView.new()
	add_child_autofree(view)
	# _ready builds the placeholder even without a driver.
	await wait_physics_frames(1)
	assert_eq(view.flash_amount(), 0.0)
	view.notify_hit()
	assert_almost_eq(view.flash_amount(), 1.0, 0.0001)
	view._update_feel(0.05)
	assert_lt(view.flash_amount(), 1.0, "the flash decays over time")
	assert_gt(view.flash_amount(), 0.0, "the flash is still visible after a short moment")
	assert_not_null(view.get_node_or_null("GroundShadow"), "fighters get a ground blob")
	var body: Node3D = view.get_node("Body") as Node3D
	assert_not_null(body)
	assert_gt(absf(body.rotation.z), 0.01, "the body flinches on hit")
