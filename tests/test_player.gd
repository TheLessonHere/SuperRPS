extends TestCase

const OK := Player.ActionResult.OK
const ROCK := Weapon.Type.ROCK
const PAPER := Weapon.Type.PAPER

var pool: WeaponPool
var rng: RandomNumberGenerator


func _player(mods: Array[Mod] = []) -> Player:
	pool = WeaponPool.new()
	rng = RandomNumberGenerator.new()
	rng.seed = 1
	return Player.new(0, pool, ModCatalog.new(mods), rng)


## Puts a specific weapon in the shop and buys it.
func _buy(p: Player, type: Weapon.Type, level: int = 1) -> Player.ActionResult:
	p.shop_weapons = [Weapon.new(type, level)] as Array[Weapon]
	p.gold = maxi(p.gold, GameConfig.WEAPON_COST)
	return p.buy_weapon(0)


func test_gold_per_turn_caps_at_ten() -> void:
	var p := _player()
	var gold := []
	for t in 9:
		p.start_turn()
		gold.append(p.gold)
	assert_eq(gold, [3, 4, 5, 6, 7, 8, 9, 10, 10])


func test_level_up_curve() -> void:
	var p := _player()
	p.start_turn()
	assert_eq(p.level_up(), Player.ActionResult.NOT_ENOUGH_GOLD, "can't level on turn 1")
	p.start_turn()
	assert_eq(p.level_up(), OK, "turn 2 level-up")
	assert_eq(p.gold, 0, "turn 2 level-up takes all gold")
	assert_eq(p.board.size(), 2)
	assert_eq(p.level_up_cost, 7)
	p.start_turn()
	assert_eq(p.level_up_cost, 6, "cost drops each turn you don't level")


func test_shop_size_matches_level() -> void:
	var p := _player()
	p.start_turn()
	assert_eq(p.shop_weapons.size(), 1)
	p.level = 3
	p.gold = 1
	p.roll()
	assert_eq(p.shop_weapons.size(), 3)
	for w in p.shop_weapons:
		assert_true(w.level <= 3, "shop weapon above player level")


func test_buy_and_sell_weapon() -> void:
	var p := _player()
	p.gold = 3
	assert_eq(_buy(p, ROCK), OK)
	assert_eq(p.gold, 0)
	assert_eq(p.inventory.size(), 1)
	assert_eq(p.sell_inventory(0), OK)
	assert_eq(p.gold, GameConfig.WEAPON_SELL_VALUE)


func test_full_inventory_blocks_buying() -> void:
	var p := _player()
	for i in GameConfig.INVENTORY_SIZE:
		p.inventory.append(Mod.make(&"filler"))
	assert_eq(_buy(p, ROCK), Player.ActionResult.INVENTORY_FULL)


func test_play_weapon_swaps_with_occupied_slot() -> void:
	var p := _player()
	_buy(p, ROCK)
	_buy(p, PAPER)
	p.play_weapon(0, 0)
	p.play_weapon(0, 0)
	assert_eq(p.board[0].type, PAPER)
	assert_eq(p.inventory[0].type, ROCK)


func test_triple_counts_board_and_inventory() -> void:
	var p := _player()
	p.level = 2
	p.board = [null, null] as Array[Weapon]
	_buy(p, ROCK)
	p.play_weapon(0, 1)
	_buy(p, ROCK)
	_buy(p, ROCK)
	assert_eq(p.board[1].level, 2, "combined weapon takes the board slot")
	assert_eq(p.inventory.size(), 0)
	assert_eq(p.pending.size(), 1)
	assert_eq(p.pending[0].kind, Player.Choice.TRIPLE_REWARD)
	assert_eq(p.pending[0].weapon.level, 3, "reward is player level + 1")


func test_different_types_dont_triple() -> void:
	var p := _player()
	_buy(p, ROCK)
	_buy(p, ROCK)
	_buy(p, PAPER)
	assert_eq(p.inventory.size(), 3)


func test_triple_reward_weapon_goes_to_inventory() -> void:
	var p := _player()
	for i in 3:
		_buy(p, ROCK)
	assert_eq(p.choose(Player.REWARD_WEAPON), OK)
	assert_eq(p.inventory.size(), 2)
	assert_eq(p.pending.size(), 0)


func test_pending_choice_blocks_buying() -> void:
	var p := _player()
	for i in 3:
		_buy(p, ROCK)
	assert_eq(_buy(p, PAPER), Player.ActionResult.CHOICE_PENDING)


func test_triple_with_two_mods_asks_which_to_keep() -> void:
	var p := _player()
	p.level = 3
	p.board = [null, null, null] as Array[Weapon]
	var sharp := Mod.make(&"sharp")
	var heavy := Mod.make(&"heavy")
	_buy(p, ROCK)
	p.play_weapon(0, 0)
	p.board[0].mod = sharp
	_buy(p, ROCK)
	p.play_weapon(0, 1)
	p.board[1].mod = heavy
	_buy(p, ROCK)
	assert_eq(p.pending[0].kind, Player.Choice.PICK_MOD)
	assert_eq(p.choose(1), OK)
	assert_eq(p.board[0].mod, heavy)


func test_triple_with_one_mod_keeps_it() -> void:
	var p := _player()
	var sharp := Mod.make(&"sharp")
	_buy(p, ROCK)
	p.play_weapon(0, 0)
	p.board[0].mod = sharp
	_buy(p, ROCK)
	_buy(p, ROCK)
	assert_eq(p.board[0].mod, sharp)
	assert_eq(p.pending[0].kind, Player.Choice.TRIPLE_REWARD)


func test_triples_chain() -> void:
	var p := _player()
	_buy(p, ROCK, 2)
	_buy(p, ROCK, 2)
	for i in 3:
		_buy(p, ROCK)
		p.auto_resolve_choices()
	var levels := []
	for item in p.inventory:
		if item is Weapon and item.type == ROCK:
			levels.append(item.level)
	assert_true(levels.has(3), "three level-2 rocks should combine into a level 3")


func test_apply_mod_replaces_existing() -> void:
	var p := _player()
	var sharp := Mod.make(&"sharp")
	var heavy := Mod.make(&"heavy")
	_buy(p, ROCK)
	p.play_weapon(0, 0)
	p.inventory.append(sharp)
	p.inventory.append(heavy)
	assert_eq(p.apply_mod(0, 0), OK)
	assert_eq(p.apply_mod(0, 0), OK)
	assert_eq(p.board[0].mod, heavy)
	assert_eq(p.inventory.size(), 0)


func test_shop_mods_cant_attach_to_weapons() -> void:
	var p := _player()
	_buy(p, ROCK)
	p.play_weapon(0, 0)
	p.inventory.append(Mod.make(&"interest", Mod.Kind.SHOP))
	assert_eq(p.apply_mod(0, 0), Player.ActionResult.INVALID_TARGET)


func test_reroll_returns_offers_to_pool() -> void:
	var p := _player()
	p.level = 1
	p.start_turn()
	var before := pool.count_at_level(1)
	p.gold = 1
	p.roll()
	assert_eq(pool.count_at_level(1), before)
