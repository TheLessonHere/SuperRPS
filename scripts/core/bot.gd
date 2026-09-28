class_name Bot
extends RefCounted
## Simple rule-based buy phase. Good enough to fill lobbies and to simulate games
## for balance; not meant to be smart. Uses only Player's public actions.


static func take_turn(p: Player, rng: RandomNumberGenerator) -> void:
	if _board_full(p):
		p.level_up()
	_shop(p)
	_arrange_board(p)
	_apply_mods(p)
	_shuffle_lanes(p, rng)
	p.auto_resolve_choices()


## Lane order is the only positioning decision, and bots can't read opponents,
## so they randomize it rather than repeat the same matchup every round.
static func _shuffle_lanes(p: Player, rng: RandomNumberGenerator) -> void:
	for i in range(p.board.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		if p.board[j] != null:
			p.move_weapon(j, i)
		elif p.board[i] != null:
			p.move_weapon(i, j)


## Buys the best offer while affordable, rerolling if nothing is left.
static func _shop(p: Player) -> void:
	while true:
		p.auto_resolve_choices()
		if p.gold < GameConfig.WEAPON_COST:
			return
		if p.inventory_full() and not _sell_weakest_inventory_weapon(p):
			return
		var best := _best_offer(p)
		if best >= 0:
			p.buy_weapon(best)
		elif p.gold >= GameConfig.ROLL_COST + GameConfig.WEAPON_COST:
			p.roll()
		else:
			return


## Prefers offers that pair with weapons already owned, then higher level.
static func _best_offer(p: Player) -> int:
	var best := -1
	var best_score := -1
	for i in p.shop_weapons.size():
		var offer := p.shop_weapons[i]
		if offer == null:
			continue
		var score := _owned_count(p, offer.type, offer.level) * 10 + offer.level
		if score > best_score:
			best = i
			best_score = score
	return best


static func _owned_count(p: Player, type: Weapon.Type, level: int) -> int:
	var count := 0
	for item: RefCounted in p.board + p.inventory:
		if item is Weapon and item.type == type and item.level == level:
			count += 1
	return count


static func _sell_weakest_inventory_weapon(p: Player) -> bool:
	var weakest := -1
	for i in p.inventory.size():
		var item := p.inventory[i]
		if item is Weapon and (weakest < 0 or item.level < p.inventory[weakest].level):
			weakest = i
	return weakest >= 0 and p.sell_inventory(weakest) == Player.ActionResult.OK


## Fills empty slots, then swaps the weakest board weapon for stronger ones in hand.
static func _arrange_board(p: Player) -> void:
	while true:
		var best_inventory := -1
		for i in p.inventory.size():
			var item := p.inventory[i]
			if item is Weapon and (best_inventory < 0 or item.level > p.inventory[best_inventory].level):
				best_inventory = i
		if best_inventory < 0:
			return
		var weakest_slot := 0
		for slot in p.board.size():
			var weapon := p.board[slot]
			if weapon == null:
				weakest_slot = slot
				break
			if weapon.level < p.board[weakest_slot].level:
				weakest_slot = slot
		var current := p.board[weakest_slot]
		if current != null and current.level >= p.inventory[best_inventory].level:
			return
		p.play_weapon(best_inventory, weakest_slot)


static func _apply_mods(p: Player) -> void:
	var i := 0
	while i < p.inventory.size():
		var mod := p.inventory[i] as Mod
		var target := _best_unmodded_slot(p)
		if mod != null and mod.kind == Mod.Kind.WEAPON and target >= 0:
			p.apply_mod(i, target)
		else:
			i += 1


static func _best_unmodded_slot(p: Player) -> int:
	var best := -1
	for slot in p.board.size():
		var weapon := p.board[slot]
		if weapon != null and weapon.mod == null and (best < 0 or weapon.level > p.board[best].level):
			best = slot
	return best


static func _board_full(p: Player) -> bool:
	return not p.board.has(null)
