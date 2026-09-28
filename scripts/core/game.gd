class_name Game
extends RefCounted
## One lobby, from the first buy phase until one player is left. Headless and
## seeded, so a seed replays the same game. simulate() plays every seat with
## Bot; a UI would call start_buy_phase(), let the human act, then run_combat().

var players: Array[Player] = []
var pool := WeaponPool.new()
var mods: ModCatalog
var rng := RandomNumberGenerator.new()
var round_number := 0
## Player id -> final placement (1 = winner).
var placements := {}
## One entry per fight: {round, ids = [a, b], ghost: bool, result: Combat.Result}.
## With a ghost, ids[1] is the eliminated player the ghost copies.
var fight_log: Array[Dictionary] = []

var _matchmaker := Matchmaker.new()
## {id, level, board} of the most recently eliminated player, or empty.
var _ghost := {}


func _init(seed_value: int, p_mods: ModCatalog = ModCatalog.new(), player_count: int = GameConfig.LOBBY_SIZE) -> void:
	rng.seed = seed_value
	mods = p_mods
	for i in player_count:
		players.append(Player.new(i, pool, mods, rng))


func alive() -> Array[Player]:
	return players.filter(func(p: Player) -> bool: return p.is_alive())


func is_over() -> bool:
	return alive().size() <= 1 or round_number >= GameConfig.MAX_ROUNDS


func simulate() -> void:
	while not is_over():
		start_buy_phase()
		for p in alive():
			Bot.take_turn(p, rng)
		run_combat()
	finish()


func start_buy_phase() -> void:
	round_number += 1
	for p in alive():
		p.start_turn()


func run_combat() -> void:
	var fighters := alive()
	for p in fighters:
		p.auto_resolve_choices()
	var ids: Array[int] = []
	for p in fighters:
		ids.append(p.id)
	# With an odd count, someone fights the ghost. Before anyone is eliminated
	# (only possible in lobbies started with an odd count), someone sits out.
	if ids.size() % 2 == 1:
		if _ghost.is_empty():
			ids.remove_at(rng.randi_range(0, ids.size() - 1))
		else:
			ids.append(_ghost.id)

	for pair: Array in _matchmaker.pair(ids, round_number, rng):
		var a := _fighter(pair[0])
		var b := _fighter(pair[1])
		# Keep the ghost on side B so the log reads consistently.
		if a.player == null:
			var swap := a
			a = b
			b = swap
		var result := Combat.resolve(a.level, a.board, b.level, b.board)
		if result.winner != Combat.NO_WINNER:
			var loser: Player = [a, b][1 - result.winner].player
			if loser != null:
				loser.health -= result.damage
		fight_log.append({
			round = round_number,
			ids = [a.id, b.id],
			ghost = b.player == null,
			result = result,
		})
	_eliminate_dead(fighters)


## Ranks whoever is left (normally one player; more if MAX_ROUNDS was hit).
func finish() -> void:
	var remaining := alive()
	remaining.sort_custom(func(x: Player, y: Player) -> bool: return x.health > y.health)
	for i in remaining.size():
		placements[remaining[i].id] = i + 1


## {id, level, board, player}; player is null for the ghost.
func _fighter(id: int) -> Dictionary:
	var p := players[id]
	if p.is_alive():
		return {id = id, level = p.level, board = p.board, player = p}
	return {id = id, level = _ghost.level, board = _ghost.board, player = null}


## Players knocked out together are placed by health: the least negative
## places highest, and becomes the new ghost.
func _eliminate_dead(fought: Array[Player]) -> void:
	var dead := fought.filter(func(p: Player) -> bool: return not p.is_alive())
	if dead.is_empty():
		return
	dead.sort_custom(func(x: Player, y: Player) -> bool: return x.health > y.health)
	var survivors := alive().size()
	for i in dead.size():
		placements[dead[i].id] = survivors + 1 + i
	var newest: Player = dead[0]
	_ghost = {id = newest.id, level = newest.level, board = _copy_board(newest.board)}


func _copy_board(board: Array[Weapon]) -> Array[Weapon]:
	var copy: Array[Weapon] = []
	for weapon in board:
		var clone: Weapon = null
		if weapon != null:
			clone = Weapon.new(weapon.type, weapon.level)
			clone.mod = weapon.mod
		copy.append(clone)
	return copy
