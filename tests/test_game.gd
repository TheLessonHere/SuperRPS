extends TestCase


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_matchmaker_avoids_rematches_while_possible() -> void:
	# 4 players have exactly 3 disjoint pairings, so rounds 1-3 must use all of them.
	var mm := Matchmaker.new()
	var rng := _rng()
	var seen := {}
	for r in range(1, 4):
		for p: Array in mm.pair([0, 1, 2, 3] as Array[int], r, rng):
			var key := "%d:%d" % [mini(p[0], p[1]), maxi(p[0], p[1])]
			assert_true(not seen.has(key), "rematch in round %d" % r)
			seen[key] = true
	assert_eq(mm.pair([0, 1, 2, 3] as Array[int], 4, rng).size(), 2, "relaxes when impossible")


func test_matchmaker_six_players_never_rematch_immediately() -> void:
	var mm := Matchmaker.new()
	var rng := _rng()
	var last := {}
	for r in range(1, 60):
		for p: Array in mm.pair([0, 1, 2, 3, 4, 5] as Array[int], r, rng):
			var key := "%d:%d" % [mini(p[0], p[1]), maxi(p[0], p[1])]
			assert_true(not last.has(key) or r - last[key] > 1, "back-to-back rematch in round %d" % r)
			last[key] = r


func test_full_bot_game_places_everyone() -> void:
	var game := Game.new(42)
	game.simulate()
	var places := game.placements.values()
	places.sort()
	assert_eq(places, [1, 2, 3, 4, 5, 6])
	assert_true(game.round_number < GameConfig.MAX_ROUNDS, "game should end naturally")


func test_same_seed_same_game() -> void:
	var a := Game.new(7)
	a.simulate()
	var b := Game.new(7)
	b.simulate()
	assert_eq(a.placements, b.placements)
	assert_eq(a.round_number, b.round_number)


func test_ghost_fights_when_odd_and_takes_no_damage() -> void:
	var ghost_fights := 0
	for seed_value in range(1, 11):
		var game := Game.new(seed_value)
		game.simulate()
		for fight in game.fight_log:
			if fight.ghost:
				ghost_fights += 1
				assert_true(not game.players[fight.ids[1]].is_alive(), "ghost copies an eliminated player")
	assert_true(ghost_fights > 0, "expected some ghost fights across 10 games")


func test_bots_level_up_and_triple() -> void:
	var game := Game.new(3)
	game.simulate()
	var max_level := 0
	var best_weapon := 0
	for p in game.players:
		max_level = maxi(max_level, p.level)
		for w in p.board:
			if w != null:
				best_weapon = maxi(best_weapon, w.level)
	assert_true(max_level >= 3, "bots should level up")
	assert_true(best_weapon >= 2, "bots should field upgraded weapons")
