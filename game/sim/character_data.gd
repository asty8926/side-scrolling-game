class_name CharacterData
extends Resource
## Static data of one character type (player character or training dummy).

@export var id: StringName = &""
## # proposal, tune
@export_range(1, 10000000, 1) var max_hp: int = 10000
## Damage of a 100% hit. # proposal, tune
@export_range(0, 100000, 1) var attack: int = 100
@export var hurtbox: HurtboxData
## KD lost per tick once out of hitstun (placeholder rule until the M1 KD
## system, docs/systems/02-kd-knockdown.md). # proposal, tune
@export_range(0, 100, 1, "suffix:/tick") var kd_recovery_per_tick: int = 1
## Null for characters that do not attack (the training dummy).
@export var moveset: MoveSet


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("id is empty")
	if max_hp < 1 or attack < 0:
		problems.append("max_hp must be >= 1 and attack >= 0")
	if hurtbox == null:
		problems.append("hurtbox is missing")
	else:
		problems.append_array(hurtbox.validate())
	if moveset != null:
		problems.append_array(moveset.validate())
	return problems
