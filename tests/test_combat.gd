extends TestCase

const A := Combat.SIDE_A
const B := Combat.SIDE_B


## Builds a board from a spec like "S1 R2 -": type letter + level, "-" for empty.
func _board(spec: String) -> Array[Weapon]:
	var board: Array[Weapon] = []
	var types := {R = Weapon.Type.ROCK, P = Weapon.Type.PAPER, S = Weapon.Type.SCISSORS}
	for token in spec.split(" ", false):
		board.append(null if token == "-" else Weapon.new(types[token[0]], int(token.substr(1))))
	return board


func test_rps_compare() -> void:
	assert_eq(Weapon.compare(Weapon.Type.PAPER, Weapon.Type.ROCK), 1)
	assert_eq(Weapon.compare(Weapon.Type.SCISSORS, Weapon.Type.PAPER), 1)
	assert_eq(Weapon.compare(Weapon.Type.ROCK, Weapon.Type.SCISSORS), 1)
	assert_eq(Weapon.compare(Weapon.Type.ROCK, Weapon.Type.PAPER), -1)
	assert_eq(Weapon.compare(Weapon.Type.ROCK, Weapon.Type.ROCK), 0)


func test_writeup_example() -> void:
	var r := Combat.resolve(3, _board("S1 R1 P1"), 3, _board("R1 S2 S2"))
	assert_eq(r.wins, [1, 4] as Array[int])
	assert_eq(r.winner, B)
	assert_eq(r.damage, 6)


func test_tie_costs_durability_without_a_win() -> void:
	var r := Combat.resolve(1, _board("R1"), 1, _board("R1"))
	assert_eq(r.wins, [0, 0] as Array[int])
	assert_eq(r.winner, Combat.NO_WINNER)
	assert_eq(r.damage, 0)
	assert_eq(r.events.size(), 1, "one swing, then both weapons are spent")


func test_tie_then_survivor_swings_into_empty() -> void:
	var r := Combat.resolve(2, _board("R2"), 2, _board("R1"))
	assert_eq(r.wins, [1, 0] as Array[int])
	assert_eq(r.damage, 1 + 2)


func test_empty_slot_gives_a_win_per_swing() -> void:
	var r := Combat.resolve(3, _board("R3 - -"), 3, _board("- - -"))
	assert_eq(r.wins, [3, 0] as Array[int])
	assert_eq(r.damage, 3 + 3)


func test_higher_durability_keeps_swinging() -> void:
	var r := Combat.resolve(2, _board("R2 -"), 2, _board("S1 -"))
	assert_eq(r.wins, [2, 0] as Array[int])


func test_extra_slots_give_one_win_each() -> void:
	var r := Combat.resolve(4, _board("- - - -"), 2, _board("- -"))
	assert_eq(r.wins, [2, 0] as Array[int])
	assert_eq(r.damage, 2 + 4)
	assert_eq(r.events[0], {kind = "extra_slot", side = A, lane = 2, amount = 1})
	assert_eq(r.events[1], {kind = "extra_slot", side = A, lane = 3, amount = 1})


func test_weapon_in_extra_slot_is_capped_at_two_wins() -> void:
	var r := Combat.resolve(1, _board("-"), 3, _board("- P5 R1"))
	assert_eq(r.wins, [0, 2 + 2] as Array[int])
	assert_eq(r.events.size(), 2, "extra-slot weapons don't swing")


func test_swings_are_ordered_by_round_then_lane() -> void:
	var r := Combat.resolve(2, _board("R2 R1"), 2, _board("R2 R1"))
	var order := []
	for e in r.events:
		order.append([e.round, e.lane])
	assert_eq(order, [[0, 0], [0, 1], [1, 0]])
	assert_eq(r.events[2].durability, [0, 0])
