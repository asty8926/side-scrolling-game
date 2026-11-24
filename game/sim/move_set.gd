class_name MoveSet
extends Resource
## All the moves of one character. Moves refer to each other by id.

@export var moves: Array[MoveData] = []


## Index of the move with `move_id`, or -1.
func index_of(move_id: StringName) -> int:
	for i: int in moves.size():
		if moves[i] != null and moves[i].id == move_id:
			return i
	return -1


func validate() -> Array[String]:
	var problems: Array[String] = []
	var seen: Array[StringName] = []
	for i: int in moves.size():
		var move: MoveData = moves[i]
		if move == null:
			problems.append("move %d is empty" % i)
			continue
		var label: String = "move %d (%s)" % [i, move.id]
		if seen.has(move.id):
			problems.append("%s: duplicate id" % label)
		seen.append(move.id)
		for problem: String in move.validate():
			problems.append("%s: %s" % [label, problem])
	for move: MoveData in moves:
		if move == null:
			continue
		for next: StringName in move.cancel_into:
			if index_of(next) < 0:
				problems.append("move %s: cancel_into '%s' does not exist" % [move.id, next])
	return problems
