class_name RoomLayout
extends Resource
## Room bounds, floor and one-way platforms, all integer fixed-point.
##
## Tier height is derived from MovementParams.single_jump_height(), at the
## chosen percent of the jump apex (default 85% leaves room to steer), so
## changing jump velocity/gravity keeps one jump = one platform tier.

## Left wall. # proposal, tune
@export_range(-100000, 0, 100, "suffix:sub") var left: int = -12000
## Right wall. # proposal, tune
@export_range(100, 100000, 100, "suffix:sub") var right: int = 12000
## Floor top y. # proposal, tune
@export_range(-10000, 10000, 100, "suffix:sub") var floor_y: int = 0
## Ceiling / view upper limit (not a solid ceiling in M0). # proposal, tune
@export_range(1000, 30000, 100, "suffix:sub") var top: int = 8500
## Where fighters appear (on the floor). # proposal, tune
@export_range(-100000, 100000, 100, "suffix:sub") var spawn_x: int = 0
## Tier height as percent of a single jump's apex. # proposal, tune
@export_range(50, 95, 1, "suffix:% of jump apex") var tier_percent: int = 85
@export var platforms: Array[RoomPlatform] = []


func tier_height(movement: MovementParams) -> int:
	return movement.single_jump_height() * tier_percent / 100


func validate(movement: MovementParams) -> Array[String]:
	var problems: Array[String] = []
	if right - left <= movement.half_width * 2 or top <= floor_y:
		problems.append("room bounds are too small or inverted")
	if spawn_x < left + movement.half_width or spawn_x > right - movement.half_width:
		problems.append("spawn_x is outside the room")
	if tier_percent < 1 or tier_percent >= 100:
		problems.append("tier_percent must be in [1, 99]")
	var tier: int = tier_height(movement)
	if tier <= 0:
		problems.append("derived tier height is %d; raise jump_velocity or tier_percent" % tier)
	for i: int in platforms.size():
		var platform: RoomPlatform = platforms[i]
		if platform == null:
			problems.append("platform %d is null" % i)
			continue
		for problem: String in platform.validate():
			problems.append("platform %d: %s" % [i, problem])
		if platform.left() < left or platform.right() > right or platform.top(floor_y, tier) > top:
			problems.append("platform %d is outside the room" % i)
	return problems
