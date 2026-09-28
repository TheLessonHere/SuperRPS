class_name Combat
extends RefCounted
## Resolves a battle between two boards. Pure logic: no nodes and no randomness,
## so the same boards always give the same result (useful for replays and P2P).
##
## A board is an Array[Weapon] sized to the player's battle slot count; empty
## slots are null.

const SIDE_A := 0
const SIDE_B := 1
const NO_WINNER := -1


class Result:
	## Total wins per side, indexed by SIDE_A / SIDE_B.
	var wins: Array[int] = [0, 0]
	## SIDE_A, SIDE_B, or NO_WINNER if the win counts are equal.
	var winner: int = NO_WINNER
	## Damage dealt to the losing side.
	var damage: int = 0
	## Ordered log for the UI to play back. Each event is one of:
	##   {kind = "extra_slot", side, lane, amount}
	##   {kind = "swing", round, lane, winner, durability = [a_left, b_left]}
	## For swings, `winner` is SIDE_A, SIDE_B or NO_WINNER (a tie).
	var events: Array[Dictionary] = []


static func resolve(level_a: int, board_a: Array[Weapon], level_b: int, board_b: Array[Weapon]) -> Result:
	var result := Result.new()
	var boards: Array = [board_a, board_b]
	# Only lanes both players have fight; the rest are extra slots.
	var lanes := mini(board_a.size(), board_b.size())

	# Extra slots give flat wins instead of swinging, so a high-durability weapon
	# can't farm free wins there.
	var bigger := SIDE_A if board_a.size() > board_b.size() else SIDE_B
	for lane in range(lanes, boards[bigger].size()):
		var amount := GameConfig.EXTRA_SLOT_WINS
		if boards[bigger][lane] != null:
			amount += GameConfig.EXTRA_SLOT_WEAPON_WINS
		result.wins[bigger] += amount
		result.events.append({kind = "extra_slot", side = bigger, lane = lane, amount = amount})

	# Remaining durability per side per lane; 0 means the slot is empty.
	var durability: Array = [[], []]
	for side in 2:
		for lane in lanes:
			var weapon: Weapon = boards[side][lane]
			durability[side].append(weapon.max_durability() if weapon else 0)

	# Every lane with a weapon left swings once per round until all are spent.
	var swing_round := 0
	while true:
		var any_swing := false
		for lane in lanes:
			var dur_a: int = durability[SIDE_A][lane]
			var dur_b: int = durability[SIDE_B][lane]
			if dur_a == 0 and dur_b == 0:
				continue
			any_swing = true

			var swing_winner := NO_WINNER
			if dur_a > 0 and dur_b > 0:
				var outcome := Weapon.compare(board_a[lane].type, board_b[lane].type)
				if outcome > 0:
					swing_winner = SIDE_A
				elif outcome < 0:
					swing_winner = SIDE_B
			else:
				# Swinging into an empty slot always wins.
				swing_winner = SIDE_A if dur_a > 0 else SIDE_B

			if swing_winner != NO_WINNER:
				result.wins[swing_winner] += 1
			durability[SIDE_A][lane] = maxi(dur_a - 1, 0)
			durability[SIDE_B][lane] = maxi(dur_b - 1, 0)
			result.events.append({
				kind = "swing",
				round = swing_round,
				lane = lane,
				winner = swing_winner,
				durability = [durability[SIDE_A][lane], durability[SIDE_B][lane]],
			})
		if not any_swing:
			break
		swing_round += 1

	var diff := result.wins[SIDE_A] - result.wins[SIDE_B]
	if diff != 0:
		result.winner = SIDE_A if diff > 0 else SIDE_B
		var winner_level := level_a if result.winner == SIDE_A else level_b
		result.damage = absi(diff) + winner_level
	return result
