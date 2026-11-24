class_name RoomPlatform
extends Resource
## An axis-aligned one-way platform (sub-units, center X, top Y). Its AABB
## spans x +/- width/2 and y-thickness..y. Only its top blocks downward motion.

## Center x. # proposal, tune
@export_range(-100000, 100000, 50, "suffix:sub") var x: int = 0
## Tier number (top y = tier * RoomLayout.tier_height). # proposal, tune
@export_range(1, 20, 1) var tier: int = 1
## Width. # proposal, tune
@export_range(100, 20000, 100, "suffix:sub") var width: int = 4000
## Visible box thickness (collision lands on its top). # proposal, tune
@export_range(50, 2000, 50, "suffix:sub") var thickness: int = 300


func left() -> int:
	return x - width / 2


func right() -> int:
	return x + width / 2


## Y of the walkable top: `tier` tiers above the room floor at `floor_y`.
func top(floor_y: int, tier_height: int) -> int:
	return floor_y + tier * tier_height


func validate() -> Array[String]:
	var problems: Array[String] = []
	if width <= 0 or thickness <= 0 or tier < 1:
		problems.append("width, thickness, tier must be > 0")
	return problems
