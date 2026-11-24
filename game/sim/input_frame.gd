class_name InputFrame
extends RefCounted
## What one player pressed during one sim tick. The ONLY input of the simulation.
##
## `buttons` is a bitmask. The meaning of each bit (left, right, up, down, Z, X,
## skills...) is defined by the input issue (#39); the sim core only carries it.

var player: int = 0
var buttons: int = 0


func _init(player_index: int = 0, button_bits: int = 0) -> void:
	player = player_index
	buttons = button_bits
