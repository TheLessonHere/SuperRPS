class_name Matchmaker
extends RefCounted
## Pairs fighters at random each round, avoiding any pair that fought within
## the last REMATCH_COOLDOWN rounds. When no pairing avoids every recent
## rematch (it can be impossible), the cooldown is relaxed a round at a time,
## so the rematches allowed are always the oldest ones.

## "low_id:high_id" -> last round the pair fought.
var _last_fought := {}


## Returns an Array of [id_a, id_b] pairs covering every id. `ids` must be even.
func pair(ids: Array[int], round_number: int, rng: RandomNumberGenerator) -> Array:
	assert(ids.size() % 2 == 0, "pair() needs an even number of fighters")
	for cooldown in range(GameConfig.REMATCH_COOLDOWN, -1, -1):
		var options := []
		_collect_pairings(ids, [], options, round_number, cooldown)
		if not options.is_empty():
			var chosen: Array = options[rng.randi_range(0, options.size() - 1)]
			for p: Array in chosen:
				_last_fought[_key(p[0], p[1])] = round_number
			return chosen
	return []


## Every way to split `remaining` into allowed pairs. Lobbies are at most 6
## fighters (15 pairings), so enumerating them all is cheap.
func _collect_pairings(remaining: Array[int], current: Array, out: Array, round_number: int, cooldown: int) -> void:
	if remaining.is_empty():
		out.append(current.duplicate())
		return
	var first := remaining[0]
	for i in range(1, remaining.size()):
		var other := remaining[i]
		if _fought_recently(first, other, round_number, cooldown):
			continue
		var rest := remaining.duplicate()
		rest.remove_at(i)
		rest.remove_at(0)
		current.append([first, other])
		_collect_pairings(rest, current, out, round_number, cooldown)
		current.pop_back()


func _fought_recently(a: int, b: int, round_number: int, cooldown: int) -> bool:
	var key := _key(a, b)
	return _last_fought.has(key) and round_number - _last_fought[key] <= cooldown


func _key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]
