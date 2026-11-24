extends Label
## Small live binding readout until the playable room arrives (#42).


func _process(_delta: float) -> void:
	text = "Physical bindings: primary %s | secondary %s | walk ← → | jump ↑ | drop ↓ | awaken %s" % [KeyLabel.for_action(&"attack_z"), KeyLabel.for_action(&"attack_x"), KeyLabel.for_action(&"awaken")]
