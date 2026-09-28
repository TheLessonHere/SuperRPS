class_name ModCatalog
extends RefCounted
## Every mod that can be offered in a game. Mods aren't pooled: offers are
## unlimited copies of these definitions.

var mods: Array[Mod] = []


func _init(p_mods: Array[Mod] = []) -> void:
	mods = p_mods


## A random mod with tier <= max_tier, or null if there are none.
func random_up_to_tier(rng: RandomNumberGenerator, max_tier: int) -> Mod:
	var eligible := mods.filter(func(m: Mod) -> bool: return m.tier <= max_tier)
	if eligible.is_empty():
		return null
	return eligible[rng.randi_range(0, eligible.size() - 1)]
