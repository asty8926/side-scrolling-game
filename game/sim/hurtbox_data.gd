class_name HurtboxData
extends Resource
## Where a character can be hit, on the gameplay plane, in sub-units.
## `offset_x` is forward from the feet (mirrored when facing left).

@export_range(-2000, 2000, 10, "suffix:sub") var offset_x: int = 0
@export_range(-2000, 2000, 10, "suffix:sub") var offset_y: int = 0
## # proposal, tune
@export_range(10, 5000, 10, "suffix:sub") var width: int = 700
## # proposal, tune
@export_range(10, 5000, 10, "suffix:sub") var height: int = 1400


func validate() -> Array[String]:
	var problems: Array[String] = []
	if width <= 0 or height <= 0:
		problems.append("hurtbox width and height must be > 0")
	return problems
