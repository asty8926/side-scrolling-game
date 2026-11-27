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
