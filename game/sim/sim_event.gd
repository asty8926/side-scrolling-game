class_name SimEvent
extends RefCounted
## Something the sim reports happened during a tick (for tests, replays, debug
## and later VFX/sound). Output only: events are not part of the state hash.

var tick: int = 0
## Short snake_case name, e.g. &"jump", &"land", &"hit".
var type: StringName = &""
## Entity id that caused it (0 = none).
var actor: int = 0
## Entity id it happened to (0 = none).
var target: int = 0
## Move id when relevant (e.g. &"ranger_zzzz_1").
var move_id: StringName = &""
## Resolved integer damage and KD added (hit events only).
var damage: int = 0
var kd: int = 0
## View-only: this hit should pulse the side camera. Not in to_text/replays.
var camera_shake: bool = false


func _init(event_tick: int = 0, event_type: StringName = &"", actor_id: int = 0, target_id: int = 0, move: StringName = &"") -> void:
	tick = event_tick
	type = event_type
	actor = actor_id
	target = target_id
	move_id = move


## Stable text form used by replay files and test messages: "tick:type:actor:target:move".
func to_text() -> String:
	var text: String = "%d:%s:%d:%d:%s" % [tick, type, actor, target, move_id]
	if type == &"hit":
		text += ":damage=%d:kd=%d" % [damage, kd]
	return text
