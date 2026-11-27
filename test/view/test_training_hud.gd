extends GutTest
## TrainingHud is view-only chrome on top of the existing hint / rec labels.


func test_the_hud_titles_the_room_and_adds_a_player_bar() -> void:
	var hud: TrainingHud = TrainingHud.new()
	var title: Label = Label.new()
	title.name = "Title"
	title.text = "side-scrolling-game M0 - test room"
	hud.add_child(title)
	add_child_autofree(hud)
	await wait_physics_frames(1)
	assert_eq(title.text, "Training Room")
	assert_not_null(hud.get_node_or_null("PlayerPanel"), "a player HP plate is added")
	assert_not_null(hud.get_node_or_null("PlayerPanel/HpBack/HpFill"))
	var combo: Label = hud.get_node_or_null("ComboLabel") as Label
	assert_not_null(combo)
	assert_eq(combo.visible, false, "combo stays hidden at zero")


func test_the_combo_label_follows_the_dummy_and_clears_on_reset() -> void:
	var driver: SimDriver = SimDriver.new()
	driver.setup = &"training"
	add_child_autofree(driver)
	await wait_physics_frames(1)
	var hud: TrainingHud = TrainingHud.new()
	hud.driver = driver
	add_child_autofree(hud)
	await wait_physics_frames(1)
	var combo: Label = hud.get_node("ComboLabel") as Label
	assert_not_null(combo)
	assert_eq(combo.visible, false, "combo stays hidden before any hit")
	var dummy: SimFighter = driver.world.fighters[1]
	var previous: int = 0
	for i: int in 48:
		var held: int = InputFrame.Z if i % 6 == 0 else 0
		driver.world.step([InputFrame.from_held(0, previous, held)] as Array[InputFrame])
		previous = held
		if dummy.combo >= 2:
			break
	assert_gte(dummy.combo, 2, "two kicks landed on the dummy")
	assert_eq(driver.world.fighters[0].combo, 0, "the player did not receive the hits")
	hud._refresh()
	assert_true(combo.visible, "the HUD shows the dummy's combo")
	assert_eq(combo.text, "COMBO  %d" % dummy.combo)
	driver.world.reset_dummies()
	hud._refresh()
	assert_eq(dummy.combo, 0)
	assert_eq(combo.visible, false, "resetting the dummy hides the combo")

