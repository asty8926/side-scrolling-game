extends Label
## Bottom-of-screen readout of the physical bindings (labels follow the keyboard layout).


func _process(_delta: float) -> void:
	text = "walk ← → | dash: double-tap ← or → | jump ↑ (twice = double jump) | drop ↓ | primary %s | secondary %s | awaken %s | record replay F9" % [KeyLabel.for_action(&"attack_z"), KeyLabel.for_action(&"attack_x"), KeyLabel.for_action(&"awaken")]
