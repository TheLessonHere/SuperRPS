class_name Weapon
extends RefCounted
## One weapon instance, in the shop, the inventory or a battle slot.

enum Type { ROCK, PAPER, SCISSORS }

const MIN_LEVEL := 1
const MAX_LEVEL := 5
const LEVEL_NAMES: Array[String] = ["", "Basic", "Silver", "Gold", "Platinum", "Diamond"]

var type: Type
var level: int


func _init(p_type: Type, p_level: int = MIN_LEVEL) -> void:
	assert(p_level >= MIN_LEVEL and p_level <= MAX_LEVEL, "weapon level out of range")
	type = p_type
	level = p_level


## Durability at the start of each fight.
func max_durability() -> int:
	return level


## Returns 1 if `a` beats `b`, -1 if `b` beats `a`, 0 on a tie.
static func compare(a: Type, b: Type) -> int:
	if a == b:
		return 0
	# Each type beats the one before it in the enum, wrapping around:
	# PAPER > ROCK, SCISSORS > PAPER, ROCK > SCISSORS.
	return 1 if a == (b + 1) % 3 else -1


func _to_string() -> String:
	return "%s %s" % [LEVEL_NAMES[level], Type.keys()[type].capitalize()]
