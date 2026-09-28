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

	# Buy the first shop weapon and play it through the UI handlers.
	_main._on_shop_weapon(0)
	_main._on_inventory_slot(0)
	_main._on_board_slot(0)
	if me.board[0] == null:
		return _fail("buying and playing a weapon didn't put it on the board")
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


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _fail(message: String) -> void:
	push_error("UI smoke failed: " + message)
	quit(1)
