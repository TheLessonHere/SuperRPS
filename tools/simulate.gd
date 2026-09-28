extends SceneTree
## Plays many all-bot games and prints balance stats.
##   godot --headless --path . -s res://tools/simulate.gd -- 200
## The optional number after `--` is how many games to run (default 100).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if not args.is_empty() else 100

	var total_rounds := 0
	var longest := 0
	var timeouts := 0
	var total_damage := 0
	var damaging_fights := 0
	var draws := 0
	var fights := 0
	var ghost_fights := 0
	var level_at_end := {}
	var biggest_hit := 0
	var level_turn_sum := [0, 0, 0, 0]
	var level_turn_count := [0, 0, 0, 0]

	for seed_value in games:
		var game := Game.new(seed_value)
		game.simulate()
		total_rounds += game.round_number
		longest = maxi(longest, game.round_number)
		if game.round_number >= GameConfig.MAX_ROUNDS:
			timeouts += 1
		for fight in game.fight_log:
			fights += 1
			var result: Combat.Result = fight.result
			if fight.ghost:
				ghost_fights += 1
			if result.winner == Combat.NO_WINNER:
				draws += 1
			else:
				damaging_fights += 1
				total_damage += result.damage
				biggest_hit = maxi(biggest_hit, result.damage)
		for p in game.players:
			level_at_end[p.level] = level_at_end.get(p.level, 0) + 1
			for i in p.level_up_turns.size():
				level_turn_sum[i] += p.level_up_turns[i]
				level_turn_count[i] += 1

	print("Games: %d" % games)
	print("Rounds per game: avg %.1f, max %d, hit MAX_ROUNDS %d" % [float(total_rounds) / games, longest, timeouts])
	print("Fights: %d (%.0f%% draws, %d vs ghost)" % [fights, 100.0 * draws / fights, ghost_fights])
	print("Damage per decisive fight: avg %.1f, max %d" % [float(total_damage) / maxi(damaging_fights, 1), biggest_hit])
	var players := games * GameConfig.LOBBY_SIZE
	for i in 4:
		if level_turn_count[i] > 0:
			print("Reached level %d: %.0f%% of players, avg turn %.1f" % [
				i + 2, 100.0 * level_turn_count[i] / players, float(level_turn_sum[i]) / level_turn_count[i],
			])
	var levels := level_at_end.keys()
	levels.sort()
	for level in levels:
		print("  ended at level %d: %d players" % [level, level_at_end[level]])
	quit()
