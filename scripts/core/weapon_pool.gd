class_name WeaponPool
extends RefCounted
## The lobby's shared weapon supply. Shops draw from it; weapons that leave play
## (rerolled away, sold, or an unchosen triple reward) go back in.

## _counts[level][type] copies left. Index 0 is unused so levels index directly.
var _counts: Array = [[0, 0, 0]]
var _max: Array[int] = [0]


func _init(copies_per_level: Array[int] = GameConfig.POOL_COPIES_PER_LEVEL) -> void:
	for copies in copies_per_level:
		_counts.append([copies, copies, copies])
		_max.append(copies)


func count(type: Weapon.Type, level: int) -> int:
	return _counts[level][type]


func count_at_level(level: int) -> int:
	var total := 0
	for copies: int in _counts[level]:
		total += copies
	return total


## A random weapon for a shop at `player_level`, or null if the pool is empty.
## Picks the weapon level by SHOP_LEVEL_ODDS, skipping levels that have run out.
func draw_for_shop(rng: RandomNumberGenerator, player_level: int) -> Weapon:
	var odds: Array = GameConfig.SHOP_LEVEL_ODDS[player_level - 1]
	var weights := PackedFloat32Array()
	var total := 0.0
	for i in odds.size():
		var weight: float = odds[i] if count_at_level(i + 1) > 0 else 0.0
		weights.append(weight)
		total += weight
	if total == 0.0:
		return null
	return draw_at_level(rng, rng.rand_weighted(weights) + 1)


## A random weapon of exactly `level`, weighted by copies left, or null if none remain.
func draw_at_level(rng: RandomNumberGenerator, level: int) -> Weapon:
	if count_at_level(level) == 0:
		return null
	var counts: Array = _counts[level]
	var type: Weapon.Type = rng.rand_weighted(PackedFloat32Array(counts)) as Weapon.Type
	counts[type] -= 1
	return Weapon.new(type, level)


## Returns a weapon's copy to the pool, never above the starting count.
func put_back(weapon: Weapon) -> void:
	var counts: Array = _counts[weapon.level]
	counts[weapon.type] = mini(counts[weapon.type] + 1, _max[weapon.level])
