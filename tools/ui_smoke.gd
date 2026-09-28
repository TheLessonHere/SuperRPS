extends SceneTree
## Drives the prototype UI through a full game with scripted clicks, then quits
## with exit code 1 if something went wrong. Run with a window (no --headless)
## to also save screenshots:
##   godot --path . -s res://tools/ui_smoke.gd -- <screenshot_dir>

var _shots_dir := ""
var _main: Control


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless":
		_shots_dir = args[0]
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _run() -> void:
	_main.new_game(5)
	await _frames(3)
	var me: Player = _main.me

	# Drag with real mouse events: shop -> board slot buys and plays.
	var bought: Weapon = me.shop_weapons[0]
	await _drag(_main._shop_row.get_child(0), _main._board_row.get_child(0), "0_dragging")
	if me.board[0] != bought:
		return _fail("dragging a shop card onto the board didn't buy and play it")
	if not _main._selected.is_empty():
		return _fail("a drag also registered as a click")
	# Board -> another slot is locked at level 1; board -> inventory benches.
	await _drag(_main._board_row.get_child(0), _main._inventory_row.get_child(4))
	if me.board[0] != null or me.inventory.size() != 1:
		return _fail("dragging a board card to the inventory didn't bench it")
	# Inventory -> shop sells.
	await _drag(_main._inventory_row.get_child(0), _main._shop_row)
	if not me.inventory.is_empty() or me.gold != GameConfig.WEAPON_SELL_VALUE:
		return _fail("dragging a card onto the shop didn't sell it")
	me.gold = GameConfig.ROLL_COST + GameConfig.WEAPON_COST
	_main._on_roll()

	# Buy the first shop weapon and play it with clicks.
	_main._on_shop_weapon(0)
	_main._on_inventory_slot(0)
	_main._on_board_slot(0)
	if me.board[0] == null:
		return _fail("buying and playing a weapon didn't put it on the board")
	_main._on_level_up()
	_main._on_freeze()
	if not me.shop_frozen:
		return _fail("freeze button did nothing")
	await _shot("1_buy_phase")

	var first_fight := true
	while not _main._game_over_overlay.visible:
		if _main.game.round_number > GameConfig.MAX_ROUNDS + 1:
			return _fail("game never ended")
		if not first_fight:
			Bot.take_turn(me, _main.game.rng)
			_main._refresh()
		if me.pending.size() > 0:
			await _shot("choice")
			me.auto_resolve_choices()
		_main._on_fight()
		if first_fight or _main.game.round_number == 6:
			await create_timer(1.2).timeout
			await _shot("2_combat_round_%d" % _main.game.round_number)
			first_fight = false
		_main._combat._skipping = true
		while _main._combat.visible and not _main._combat._continue.visible:
			await process_frame
		if _main._combat.visible:
			_main._combat._continue.pressed.emit()
		await _frames(2)
	await _shot("3_game_over")
	print("UI smoke OK: placed #%d after %d rounds" % [_main.game.placements.get(0, 0), _main.game.round_number])
	quit(0)


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty():
		return
	await _frames(3)
	var path := _shots_dir.path_join(shot_name + ".png")
	if FileAccess.file_exists(path) and shot_name == "choice":
		return
	root.get_texture().get_image().save_png(path)


## Presses on `from`, moves in steps to `to` and releases, like a real mouse.
## Optionally screenshots mid-drag.
func _drag(from: Control, to: Control, shot_name: String = "") -> void:
	var start := from.get_global_rect().get_center()
	var end := to.get_global_rect().get_center()
	_mouse_button(start, true)
	await process_frame
	var steps := 12
	for i in range(1, steps + 1):
		var motion := InputEventMouseMotion.new()
		motion.position = start.lerp(end, float(i) / steps)
		motion.global_position = motion.position
		motion.relative = (end - start) / steps
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await process_frame
	if not shot_name.is_empty():
		await _shot(shot_name)
	_mouse_button(end, false)
	await _frames(2)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _fail(message: String) -> void:
	push_error("UI smoke failed: " + message)
	quit(1)
