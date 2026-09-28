class_name GameConfig
extends RefCounted
## Tunable rule numbers. See docs/RULES.md for how they're used.

const LOBBY_SIZE := 6
const TOP_PLACEMENTS := 3
const STARTING_HEALTH := 25

const MIN_PLAYER_LEVEL := 1
const MAX_PLAYER_LEVEL := 5
## Base cost to reach level N is LEVEL_UP_BASE_COST[N - 2]. Drops by 1 each turn you don't level.
const LEVEL_UP_BASE_COST: Array[int] = [5, 9, 11, 13]

const STARTING_GOLD := 3
const GOLD_PER_TURN_INCREASE := 1
const MAX_GOLD := 10

const INVENTORY_SIZE := 10
const WEAPON_COST := 3
const WEAPON_SELL_VALUE := 1
const ROLL_COST := 1
const MOD_SHOP_SLOTS := 1

## Wins for each battle slot you have that the opponent doesn't, plus a bonus
## if that slot holds a weapon. Weapons in extra slots don't swing.
const EXTRA_SLOT_WINS := 1
const EXTRA_SLOT_WEAPON_WINS := 1

## Copies of each weapon type in the shared pool, by weapon level 1-5.
const POOL_COPIES_PER_LEVEL: Array[int] = [18, 15, 13, 11, 9]
## Shop odds (%) for each weapon level, by player level (row N-1 is player level N).
const SHOP_LEVEL_ODDS: Array = [
	[100],
	[70, 30],
	[50, 35, 15],
	[35, 35, 20, 10],
	[25, 30, 25, 15, 5],
]

const TRIPLE_COUNT := 3
## Can't be paired against the same opponent within this many fights.
const REMATCH_COOLDOWN := 3
## Safety cap so two identical final boards can't draw forever; remaining
## players are then ranked by health.
const MAX_ROUNDS := 50
