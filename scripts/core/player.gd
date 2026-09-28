class_name Player
extends RefCounted
## One player's state and buy-phase actions. Every action checks its own rules
## and returns ActionResult.OK or why it was refused, so the UI and bots go
## through the same path.

enum ActionResult {
	OK,
	NOT_ENOUGH_GOLD,
	INVENTORY_FULL,
	INVALID_TARGET,
	MAX_LEVEL,
	CHOICE_PENDING,
	NO_CHOICE_PENDING,
}

enum Choice { PICK_MOD, TRIPLE_REWARD }
## Options for a TRIPLE_REWARD choice.
const REWARD_MOD := 0
const REWARD_WEAPON := 1

var id: int
var health := GameConfig.STARTING_HEALTH
var level := GameConfig.MIN_PLAYER_LEVEL
var gold := 0
var turn := 0
var level_up_cost: int = GameConfig.LEVEL_UP_BASE_COST[0]
## Turn each level was reached; index 0 is level 2. For stats and balance sims.
var level_up_turns: Array[int] = []
## Battle slots; size equals level. Empty slots are null.
var board: Array[Weapon] = [null]
## The hand: Weapons and Mods, up to INVENTORY_SIZE.
var inventory: Array[RefCounted] = []
## Current shop offers. Buying one leaves a null in its slot until the next roll.
var shop_weapons: Array[Weapon] = []
var shop_mod: Mod = null
## A frozen shop keeps its unbought offers into the next turn. Rolling unfreezes.
var shop_frozen := false
## Choices the player must make, oldest first. While any are pending, only
## selling and choosing are allowed. Each entry is one of:
##   {kind = Choice.PICK_MOD, weapon, options: Array[Mod]}
##   {kind = Choice.TRIPLE_REWARD, mod: Mod or null, weapon: Weapon or null}
var pending: Array[Dictionary] = []

var _pool: WeaponPool
var _mods: ModCatalog
var _rng: RandomNumberGenerator


func _init(p_id: int, pool: WeaponPool, mods: ModCatalog, rng: RandomNumberGenerator) -> void:
	id = p_id
	_pool = pool
	_mods = mods
	_rng = rng


func is_alive() -> bool:
	return health > 0


func inventory_full() -> bool:
	return inventory.size() >= GameConfig.INVENTORY_SIZE


func start_turn() -> void:
	turn += 1
	if turn > 1 and level < GameConfig.MAX_PLAYER_LEVEL:
		level_up_cost = maxi(level_up_cost - 1, 0)
	gold = mini(GameConfig.STARTING_GOLD + (turn - 1) * GameConfig.GOLD_PER_TURN_INCREASE, GameConfig.MAX_GOLD)
	if shop_frozen:
		shop_frozen = false
		_refill_shop()
	else:
		_refresh_shop()


func roll() -> ActionResult:
	if not pending.is_empty():
		return ActionResult.CHOICE_PENDING
	if gold < GameConfig.ROLL_COST:
		return ActionResult.NOT_ENOUGH_GOLD
	gold -= GameConfig.ROLL_COST
	shop_frozen = false
	_refresh_shop()
	return ActionResult.OK


## Freezing is free and can be toggled any number of times.
func toggle_freeze() -> ActionResult:
	shop_frozen = not shop_frozen
	return ActionResult.OK


func buy_weapon(index: int) -> ActionResult:
	if not pending.is_empty():
		return ActionResult.CHOICE_PENDING
	if index < 0 or index >= shop_weapons.size() or shop_weapons[index] == null:
		return ActionResult.INVALID_TARGET
	if gold < GameConfig.WEAPON_COST:
		return ActionResult.NOT_ENOUGH_GOLD
	if inventory_full():
		return ActionResult.INVENTORY_FULL
	gold -= GameConfig.WEAPON_COST
	inventory.append(shop_weapons[index])
	shop_weapons[index] = null
	_check_triples()
	return ActionResult.OK


func buy_mod() -> ActionResult:
	if not pending.is_empty():
		return ActionResult.CHOICE_PENDING
	if shop_mod == null:
		return ActionResult.INVALID_TARGET
	if gold < shop_mod.cost:
		return ActionResult.NOT_ENOUGH_GOLD
	if inventory_full():
		return ActionResult.INVENTORY_FULL
	gold -= shop_mod.cost
	inventory.append(shop_mod)
	shop_mod = null
	return ActionResult.OK


func sell_inventory(index: int) -> ActionResult:
	if index < 0 or index >= inventory.size():
		return ActionResult.INVALID_TARGET
	_sell(inventory.pop_at(index))
	return ActionResult.OK


func sell_board(slot: int) -> ActionResult:
	if not _is_slot(slot) or board[slot] == null:
		return ActionResult.INVALID_TARGET
	_sell(board[slot])
	board[slot] = null
	return ActionResult.OK


func level_up() -> ActionResult:
	if not pending.is_empty():
		return ActionResult.CHOICE_PENDING
	if level >= GameConfig.MAX_PLAYER_LEVEL:
		return ActionResult.MAX_LEVEL
	if gold < level_up_cost:
		return ActionResult.NOT_ENOUGH_GOLD
	gold -= level_up_cost
	level += 1
	level_up_turns.append(turn)
	board.append(null)
	level_up_cost = GameConfig.LEVEL_UP_BASE_COST[level - 1] if level < GameConfig.MAX_PLAYER_LEVEL else 0
	return ActionResult.OK


## Plays an inventory weapon into a battle slot. If the slot is taken, the two swap.
func play_weapon(inventory_index: int, slot: int) -> ActionResult:
	if not pending.is_empty():
		return ActionResult.CHOICE_PENDING
	if not _is_slot(slot) or not _inventory_item(inventory_index) is Weapon:
		return ActionResult.INVALID_TARGET
	var weapon: Weapon = inventory[inventory_index]
	if board[slot] != null:
		inventory[inventory_index] = board[slot]
	else:
		inventory.remove_at(inventory_index)
	board[slot] = weapon
	return ActionResult.OK


## Moves a board weapon to another slot, swapping with whatever is there.
func move_weapon(from_slot: int, to_slot: int) -> ActionResult:
	if not pending.is_empty():
		return ActionResult.CHOICE_PENDING
	if not _is_slot(from_slot) or not _is_slot(to_slot) or board[from_slot] == null:
		return ActionResult.INVALID_TARGET
	var moved := board[from_slot]
	board[from_slot] = board[to_slot]
	board[to_slot] = moved
	return ActionResult.OK


## Moves a board weapon back to the inventory.
func bench_weapon(slot: int) -> ActionResult:
	if not pending.is_empty():
		return ActionResult.CHOICE_PENDING
	if not _is_slot(slot) or board[slot] == null:
		return ActionResult.INVALID_TARGET
	if inventory_full():
		return ActionResult.INVENTORY_FULL
	inventory.append(board[slot])
	board[slot] = null
	return ActionResult.OK


## Attaches an inventory weapon mod to a board weapon, replacing any mod it had.
func apply_mod(inventory_index: int, slot: int) -> ActionResult:
	if not pending.is_empty():
		return ActionResult.CHOICE_PENDING
	var mod := _inventory_item(inventory_index) as Mod
	if mod == null or mod.kind != Mod.Kind.WEAPON or not _is_slot(slot) or board[slot] == null:
		return ActionResult.INVALID_TARGET
	board[slot].mod = mod
	inventory.remove_at(inventory_index)
	return ActionResult.OK


## Resolves the oldest pending choice. For PICK_MOD, `option` indexes its
## options; for TRIPLE_REWARD it's REWARD_MOD or REWARD_WEAPON.
func choose(option: int) -> ActionResult:
	if pending.is_empty():
		return ActionResult.NO_CHOICE_PENDING
	var choice: Dictionary = pending[0]
	match choice.kind:
		Choice.PICK_MOD:
			if option < 0 or option >= choice.options.size():
				return ActionResult.INVALID_TARGET
			choice.weapon.mod = choice.options[option]
		Choice.TRIPLE_REWARD:
			var reward: RefCounted = null
			if option == REWARD_MOD:
				reward = choice.mod
			elif option == REWARD_WEAPON:
				reward = choice.weapon
			if reward == null:
				return ActionResult.INVALID_TARGET
			if inventory_full():
				return ActionResult.INVENTORY_FULL
			inventory.append(reward)
			if choice.weapon != null and reward != choice.weapon:
				_pool.put_back(choice.weapon)
	pending.pop_front()
	_check_triples()
	return ActionResult.OK


## Resolves every pending choice with a default, e.g. when the buy-phase timer
## runs out. A triple reward with no inventory room is forfeited.
func auto_resolve_choices() -> void:
	while not pending.is_empty():
		var choice: Dictionary = pending[0]
		var option := 0
		if choice.kind == Choice.TRIPLE_REWARD:
			option = REWARD_WEAPON if choice.weapon != null else REWARD_MOD
		if choose(option) != ActionResult.OK:
			if choice.kind == Choice.TRIPLE_REWARD and choice.weapon != null:
				_pool.put_back(choice.weapon)
			pending.pop_front()


func _refresh_shop() -> void:
	for weapon in shop_weapons:
		if weapon != null:
			_pool.put_back(weapon)
	shop_weapons.clear()
	shop_mod = null
	_refill_shop()


## Keeps current offers and fills bought or newly unlocked slots, like a frozen
## Battlegrounds tavern.
func _refill_shop() -> void:
	var kept := shop_weapons.filter(func(w: Weapon) -> bool: return w != null)
	shop_weapons.assign(kept)
	while shop_weapons.size() < level:
		var weapon := _pool.draw_for_shop(_rng, level)
		if weapon == null:
			break
		shop_weapons.append(weapon)
	if shop_mod == null:
		shop_mod = _mods.random_up_to_tier(_rng, level)


func _sell(item: RefCounted) -> void:
	if item is Weapon:
		gold += GameConfig.WEAPON_SELL_VALUE
		_pool.put_back(item)
	else:
		gold += (item as Mod).sell_value


func _is_slot(slot: int) -> bool:
	return slot >= 0 and slot < board.size()


func _inventory_item(index: int) -> RefCounted:
	return inventory[index] if index >= 0 and index < inventory.size() else null


## Combines every set of 3 same type and level weapons across board and
## inventory. Repeats, since a combined weapon can complete another set.
func _check_triples() -> void:
	var combined_any := true
	while combined_any:
		combined_any = false
		for weapon_level in range(Weapon.MIN_LEVEL, Weapon.MAX_LEVEL):
			for type: Weapon.Type in Weapon.Type.values():
				var matches := _find_weapons(type, weapon_level)
				if matches.size() >= GameConfig.TRIPLE_COUNT:
					_combine(matches.slice(0, GameConfig.TRIPLE_COUNT), type, weapon_level)
					combined_any = true


## Board weapons first, then inventory.
func _find_weapons(type: Weapon.Type, weapon_level: int) -> Array[Weapon]:
	var found: Array[Weapon] = []
	for weapon in board:
		if weapon != null and weapon.type == type and weapon.level == weapon_level:
			found.append(weapon)
	for item in inventory:
		if item is Weapon and item.type == type and item.level == weapon_level:
			found.append(item)
	return found


## The result takes the leftmost board slot among the parts, or goes to the
## inventory if none were on the board.
func _combine(parts: Array[Weapon], type: Weapon.Type, weapon_level: int) -> void:
	var combined := Weapon.new(type, weapon_level + 1)
	var mods: Array[Mod] = []
	var board_slot := -1
	for part in parts:
		if part.mod != null:
			mods.append(part.mod)
		var slot := board.find(part)
		if slot >= 0:
			board[slot] = null
			if board_slot < 0:
				board_slot = slot
		else:
			inventory.erase(part)
	if board_slot >= 0:
		board[board_slot] = combined
	else:
		inventory.append(combined)

	if mods.size() == 1:
		combined.mod = mods[0]
	elif mods.size() > 1:
		pending.append({kind = Choice.PICK_MOD, weapon = combined, options = mods})

	var reward_level := mini(level + 1, Weapon.MAX_LEVEL)
	var reward_mod := _mods.random_up_to_tier(_rng, reward_level)
	var reward_weapon := _pool.draw_at_level(_rng, reward_level)
	if reward_mod != null or reward_weapon != null:
		pending.append({kind = Choice.TRIPLE_REWARD, mod = reward_mod, weapon = reward_weapon})
