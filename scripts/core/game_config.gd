class_name GameConfig
extends RefCounted
## Tunable rule numbers. See docs/RULES.md for how they're used.

const LOBBY_SIZE := 6
const TOP_PLACEMENTS := 3
const STARTING_HEALTH := 25

const MIN_PLAYER_LEVEL := 1
const MAX_PLAYER_LEVEL := 5
## Base cost to reach level N is LEVEL_UP_BASE_COST[N - 2]. Drops by 1 each turn you don't level.
const LEVEL_UP_BASE_COST: Array[int] = [5, 7, 8, 9]

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

const TRIPLE_COUNT := 3
## Can't be paired against the same opponent within this many fights.
const REMATCH_COOLDOWN := 3
