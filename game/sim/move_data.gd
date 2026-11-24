class_name MoveData
extends Resource
## One attack (a node of a command string), all in ticks (60/s) and sub-units.
## Frame data and KD values are our proposals (docs/systems/05-game-feel.md);
## damage percents come from ElWiki Rena commands where noted.
##
## A move lasts startup + active + recovery ticks. Move tick 0 is the tick the
## move starts. Its string continues when the button of a move listed in
## `cancel_into` is pressed (or was pressed up to InputSettings.buffer_ticks
## earlier) while the move tick is inside [cancel_from, cancel_to].

## Which attack button starts this move.
enum AttackButton { Z, X }
## Most hitboxes per move, so hit keys (hitboxes x fighters) always fit a snapshot.
const MAX_HITBOXES: int = SimFighter.MAX_HIT_KEYS / SimWorld.MAX_FIGHTERS
## Most projectiles one move fires. # proposal, tune
const MAX_PROJECTILES: int = 8
## How the move can start when no move is playing.
enum Start {
	## Only as the next hit of a string (via another move's cancel_into).
	CHAIN_ONLY,
	## From standing/walking on the ground.
	NEUTRAL,
	## While dashing (`>>`).
	DASH,
}

@export var id: StringName = &""
@export var button: AttackButton = AttackButton.Z
@export var start: Start = Start.CHAIN_ONLY

@export_group("Frame data")
## Ticks before the first hit can land. # proposal, tune
@export_range(0, 120, 1, "suffix:ticks") var startup: int = 5
## Ticks the attack is out. # proposal, tune
@export_range(1, 120, 1, "suffix:ticks") var active: int = 3
## Ticks after the attack before the fighter is free. # proposal, tune
@export_range(0, 180, 1, "suffix:ticks") var recovery: int = 14
## Melee boxes (kicks).
@export var hitboxes: Array[HitboxData] = []
## Projectiles fired (arrows), each hitting with this move's damage/hitstun/KD.
@export var projectiles: Array[ProjectileData] = []

@export_group("On hit")
## Percent of the attacker's attack stat per hit (ElWiki % where sourced).
@export_range(0, 2000, 1, "suffix:%") var damage_percent: int = 100
## Ticks the target stays in hitstun after this hit. # proposal, tune
@export_range(0, 180, 1, "suffix:ticks") var hitstun_ticks: int = 30
## KD (knockdown) gauge added per hit. # proposal, tune
@export_range(0, 200, 1) var kd: int = 10
## Sub-units the target is pushed away per hit. # proposal, tune
@export_range(0, 2000, 10, "suffix:sub") var pushback: int = 60

@export_group("String")
## Moves this one can cancel into (next nodes of the string).
@export var cancel_into: Array[StringName] = []
## First move tick of the cancel window. # proposal, tune
@export_range(0, 300, 1, "suffix:tick") var cancel_from: int = 8
## Last move tick of the cancel window (inclusive). # proposal, tune
@export_range(0, 300, 1, "suffix:tick") var cancel_to: int = 20

@export_group("Motion")
## Forward sub-units moved on each move tick (index = move tick, missing = 0;
## negative = backward). Root motion stops at walls and at platform edges
## (M0 choice for docs/systems/04 open question 3). # proposal, tune
@export var root_motion: PackedInt32Array = PackedInt32Array()
## First move tick with the pushbox off, so the fighter passes through other
## fighters (the `>>ZX` slash-through); -1 = never. # proposal, tune
@export_range(-1, 300, 1, "suffix:tick") var pass_from: int = -1
## Last move tick with the pushbox off (inclusive). # proposal, tune
@export_range(-1, 300, 1, "suffix:tick") var pass_to: int = -1
## Turn around when the move ends (face the target you passed). # proposal, tune
@export var turn_at_end: bool = false
## Last move tick on which a fighter already hit by this move is carried
## along by the attacker's actual root motion that tick; -1 = no carry.
## # proposal, tune
@export_range(-1, 300, 1, "suffix:tick") var carry_to: int = -1


## Whether the pushbox is off on move tick `move_tick`.
func passes_at(move_tick: int) -> bool:
	return pass_from >= 0 and move_tick >= pass_from and move_tick <= pass_to


## Whether a previously hit target is carried on move tick `move_tick`.
func carries_at(move_tick: int) -> bool:
	return carry_to >= 0 and move_tick <= carry_to


## Total ticks of the move.
func length() -> int:
	return startup + active + recovery


## Sub-units forward on move tick `move_tick`.
func motion_at(move_tick: int) -> int:
	if move_tick < 0 or move_tick >= root_motion.size():
		return 0
	return root_motion[move_tick]


func validate() -> Array[String]:
	var problems: Array[String] = []
	var total: int = length()
	if id == &"":
		problems.append("id is empty")
	if active < 1 or startup < 0 or recovery < 0:
		problems.append("startup and recovery must be >= 0, active >= 1")
	if hitstun_ticks < 0 or kd < 0 or damage_percent < 0 or pushback < 0:
		problems.append("damage_percent, hitstun_ticks, kd and pushback must be >= 0")
	if hitboxes.size() > MAX_HITBOXES:
		problems.append("%d hitboxes, at most %d per move" % [hitboxes.size(), MAX_HITBOXES])
	for i: int in hitboxes.size():
		var box: HitboxData = hitboxes[i]
		if box == null:
			problems.append("hitbox %d is empty" % i)
			continue
		for problem: String in box.validate(startup, startup + active - 1):
			problems.append("hitbox %d: %s" % [i, problem])
	if projectiles.size() > MAX_PROJECTILES:
		problems.append("%d projectiles, at most %d per move" % [projectiles.size(), MAX_PROJECTILES])
	for i: int in projectiles.size():
		var shot: ProjectileData = projectiles[i]
		if shot == null:
			problems.append("projectile %d is empty" % i)
			continue
		for problem: String in shot.validate(startup, startup + active - 1):
			problems.append("projectile %d: %s" % [i, problem])
	if not cancel_into.is_empty() and (cancel_from < 0 or cancel_from > cancel_to or cancel_to >= total):
		problems.append("cancel window %d..%d must be inside the move (0..%d)" % [cancel_from, cancel_to, total - 1])
	if pass_from >= 0 and (pass_from > pass_to or pass_to >= total):
		problems.append("pass window %d..%d must be inside the move (0..%d)" % [pass_from, pass_to, total - 1])
	if carry_to >= 0 and carry_to >= total:
		problems.append("carry_to %d must be inside the move (0..%d)" % [carry_to, total - 1])
	if root_motion.size() > total:
		problems.append("root_motion has %d entries but the move lasts %d ticks" % [root_motion.size(), total])
	return problems
