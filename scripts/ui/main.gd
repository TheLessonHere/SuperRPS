extends Control
## Rough playable prototype: you against 5 bots. Placeholder UI built in code.
##
## Every action works by dragging or by clicking (click a card, then where it
## should go):
## - Shop card to inventory or a board slot: buy it (and play it).
## - Inventory weapon to a board slot: play it (swaps if the slot is taken).
## - Board weapon to another board slot: move it; to the inventory: bench it.
## - Mod (inventory or shop) to a board weapon: apply it.
## - Board or inventory card to the shop: sell it. Clicking: select, then Sell.

const HUMAN_ID := 0
const FROZEN_TINT := Color(0.7, 0.85, 1.3)
const MESSAGES := {
	Player.ActionResult.NOT_ENOUGH_GOLD: "Not enough gold.",
	Player.ActionResult.INVENTORY_FULL: "Inventory is full. Sell something first.",
	Player.ActionResult.INVALID_TARGET: "Can't do that there.",
	Player.ActionResult.MAX_LEVEL: "Already at max level.",
	Player.ActionResult.CHOICE_PENDING: "Make your choice first.",
}

var game: Game
var me: Player
## What the player has clicked: {} or {zone = "board" or "inventory", index}.
var _selected := {}

var _info := Label.new()
var _level_button := Button.new()
var _roll_button := Button.new()
var _freeze_button := Button.new()
var _shop_heading: Label
var _sell_button := Button.new()
var _fight_button := Button.new()
var _shop_row := HBoxContainer.new()
var _board_row := HBoxContainer.new()
var _inventory_row := HBoxContainer.new()
var _status := Label.new()
var _lobby := VBoxContainer.new()
var _choice_box := VBoxContainer.new()
var _choice_overlay: Control
var _game_over_label := Label.new()
var _game_over_overlay: Control
var _combat := CombatView.new()


func _ready() -> void:
	_build_ui()
	new_game()


func new_game(seed_value: int = randi()) -> void:
	game = Game.new(seed_value)
	me = game.players[HUMAN_ID]
	_selected = {}
	_status.text = ""
	_game_over_overlay.hide()
	game.start_buy_phase()
	_fight_button.disabled = false
	_refresh()


# --- Actions -------------------------------------------------------------

func _on_shop_weapon(index: int) -> void:
	_act(me.buy_weapon(index))


func _on_shop_mod() -> void:
	_act(me.buy_mod())


func _on_level_up() -> void:
	_act(me.level_up())


func _on_freeze() -> void:
	_act(me.toggle_freeze())


func _on_roll() -> void:
	_act(me.roll())


func _on_sell() -> void:
	if _selected.is_empty():
		return
	if _selected.zone == "board":
		_act(me.sell_board(_selected.index))
	else:
		_act(me.sell_inventory(_selected.index))


func _on_board_slot(slot: int) -> void:
	match _selected.get("zone"):
		"inventory":
			var item: RefCounted = me.inventory[_selected.index]
			if item is Mod:
				_act(me.apply_mod(_selected.index, slot))
			else:
				_act(me.play_weapon(_selected.index, slot))
		"board":
			if _selected.index == slot:
				_select({})
			else:
				_act(me.move_weapon(_selected.index, slot))
		_:
			if me.board[slot] != null:
				_select({zone = "board", index = slot})


func _on_inventory_slot(index: int) -> void:
	if _selected.get("zone") == "board":
		_act(me.bench_weapon(_selected.index))
	elif index < me.inventory.size() and not _is_selected("inventory", index):
		_select({zone = "inventory", index = index})
	else:
		_select({})


func _on_choose(option: int) -> void:
	_act(me.choose(option))


func _on_fight() -> void:
	_fight_button.disabled = true
	_selected = {}
	me.auto_resolve_choices()
	game.play_bot_turns(HUMAN_ID)
	game.run_combat()

	var fight := _my_fight()
	if not fight.is_empty():
		var my_side: int = 0 if fight.ids[0] == HUMAN_ID else 1
		var opponent_id: int = fight.ids[1 - my_side]
		var opponent := ("Ghost of " if fight.ghost else "") + _player_name(opponent_id)
		_refresh()
		await _combat.play(fight, my_side, opponent)

	if game.is_over() and me.is_alive():
		game.finish()
	if not me.is_alive() or game.is_over():
		_show_game_over()
		return
	game.start_buy_phase()
	_status.text = ""
	_fight_button.disabled = false
	_refresh()


func _buy_weapon_to_slot(shop_index: int, slot: int) -> void:
	var weapon := me.shop_weapons[shop_index]
	var result := me.buy_weapon(shop_index)
	var bought := me.inventory.find(weapon)
	# If the purchase completed a triple, the weapon is already combined.
	if result == Player.ActionResult.OK and bought >= 0 and me.pending.is_empty():
		result = me.play_weapon(bought, slot)
	_act(result)


func _buy_mod_to_slot(slot: int) -> void:
	var result := me.buy_mod()
	if result == Player.ActionResult.OK:
		result = me.apply_mod(me.inventory.size() - 1, slot)
	_act(result)


func _act(result: Player.ActionResult) -> void:
	_status.text = MESSAGES.get(result, "")
	_selected = {}
	_refresh()


func _select(selection: Dictionary) -> void:
	_selected = selection
	_status.text = ""
	_refresh()


func _is_selected(zone: String, index: int) -> bool:
	return _selected.get("zone") == zone and _selected.get("index") == index


## This round's fight involving the human, or {} if they sat out.
func _my_fight() -> Dictionary:
	for i in range(game.fight_log.size() - 1, -1, -1):
		var fight: Dictionary = game.fight_log[i]
		if fight.round != game.round_number:
			break
		if fight.ids[0] == HUMAN_ID or (fight.ids[1] == HUMAN_ID and not fight.ghost):
			return fight
	return {}


func _player_name(id: int) -> String:
	return "You" if id == HUMAN_ID else "Bot %d" % id


# --- Drag and drop -------------------------------------------------------
# Drag sources and drop targets are {zone, index}. Zones: "shop", "shop_mod",
# "board", "inventory". Dropping on the shop sells, like Battlegrounds.

## Makes `card` a drop target, and a drag source if `source` is given.
func _wire_drag(card: ItemCard, target: Dictionary, source: Dictionary = {}, item: RefCounted = null) -> void:
	card.set_meta("drop_target", target)
	card.set_drag_forwarding(
		func(_at: Vector2) -> Variant: return _begin_drag(card, source, item),
		func(_at: Vector2, data: Variant) -> bool: return _drop_action(data, target).is_valid(),
		func(_at: Vector2, data: Variant) -> void: _drop_action(data, target).call(),
	)


## Lets drops land in the empty space of a row, not just on its cards.
func _wire_row_drop(row: Control, target: Dictionary) -> void:
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.set_drag_forwarding(
		Callable(),
		func(_at: Vector2, data: Variant) -> bool: return _drop_action(data, target).is_valid(),
		func(_at: Vector2, data: Variant) -> void: _drop_action(data, target).call(),
	)


func _begin_drag(card: ItemCard, source: Dictionary, item: RefCounted) -> Variant:
	if source.is_empty() or _combat.visible or _choice_overlay.visible:
		return null
	_selected = {}
	var preview := Control.new()
	var ghost := ItemCard.new()
	ghost.show_item(item)
	ghost.position = -ItemCard.CARD_SIZE / 2
	ghost.modulate.a = 0.85
	preview.add_child(ghost)
	card.set_drag_preview(preview)
	return source


## What dropping `source` on `target` does, or an invalid Callable if nothing.
func _drop_action(source: Variant, target: Dictionary) -> Callable:
	if not (source is Dictionary and source.has("zone")) or not me.pending.is_empty():
		return Callable()
	var from: String = source.zone
	match target.zone:
		"shop":
			if from == "board":
				return func() -> void: _act(me.sell_board(source.index))
			if from == "inventory":
				return func() -> void: _act(me.sell_inventory(source.index))
		"inventory":
			if from == "shop":
				return _on_shop_weapon.bind(source.index)
			if from == "shop_mod":
				return _on_shop_mod
			if from == "board":
				return func() -> void: _act(me.bench_weapon(source.index))
		"board":
			var slot: int = target.index
			var has_weapon := me.board[slot] != null
			match from:
				"board":
					if source.index != slot:
						return func() -> void: _act(me.move_weapon(source.index, slot))
				"inventory":
					var item: RefCounted = me.inventory[source.index]
					if item is Weapon:
						return func() -> void: _act(me.play_weapon(source.index, slot))
					if has_weapon and item.kind == Mod.Kind.WEAPON:
						return func() -> void: _act(me.apply_mod(source.index, slot))
				"shop":
					return _buy_weapon_to_slot.bind(source.index, slot)
				"shop_mod":
					if has_weapon and me.shop_mod.kind == Mod.Kind.WEAPON:
						return _buy_mod_to_slot.bind(slot)
	return Callable()


## Highlights every valid drop spot while a drag is in progress.
func _notification(what: int) -> void:
	if game == null:
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		for row: Container in [_shop_row, _board_row, _inventory_row]:
			for card in row.get_children():
				if card is ItemCard and card.has_meta("drop_target"):
					card.set_drop_highlight(_drop_action(data, card.get_meta("drop_target")).is_valid())
	elif what == NOTIFICATION_DRAG_END:
		_refresh()


# --- Display -------------------------------------------------------------

func _refresh() -> void:
	_info.text = "Round %d     Health %d     Gold %d     Level %d" % [game.round_number, me.health, me.gold, me.level]
	if me.level < GameConfig.MAX_PLAYER_LEVEL:
		_level_button.text = "Level up (%dg)" % me.level_up_cost
	else:
		_level_button.text = "Max level"
	_level_button.disabled = me.level >= GameConfig.MAX_PLAYER_LEVEL
	_sell_button.disabled = _selected.is_empty()
	_fill_shop()
	_fill_board()
	_fill_inventory()
	_fill_lobby()
	_fill_choice()


func _fill_shop() -> void:
	_clear(_shop_row)
	for i in me.shop_weapons.size():
		var card := _add_card(_shop_row, _on_shop_weapon.bind(i))
		if me.shop_weapons[i] != null:
			card.show_weapon(me.shop_weapons[i])
			card.set_footer("%dg" % GameConfig.WEAPON_COST)
			_wire_drag(card, {zone = "shop"}, {zone = "shop", index = i}, me.shop_weapons[i])
		else:
			card.show_empty("Sold")
			_wire_drag(card, {zone = "shop"})
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(24, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_PASS
	_shop_row.add_child(spacer)
	var mod_card := _add_card(_shop_row, _on_shop_mod)
	if me.shop_mod != null:
		mod_card.show_mod(me.shop_mod)
		mod_card.set_footer("%dg" % me.shop_mod.cost)
		_wire_drag(mod_card, {zone = "shop"}, {zone = "shop_mod", index = 0}, me.shop_mod)
	else:
		mod_card.show_empty("No mod")
		_wire_drag(mod_card, {zone = "shop"})
	_shop_heading.text = "Shop (frozen until next turn)" if me.shop_frozen else "Shop"
	_freeze_button.text = "Unfreeze" if me.shop_frozen else "Freeze"
	for card in _shop_row.get_children():
		card.modulate = FROZEN_TINT if me.shop_frozen else Color.WHITE


func _fill_board() -> void:
	_clear(_board_row)
	for slot in GameConfig.MAX_PLAYER_LEVEL:
		var card := _add_card(_board_row, _on_board_slot.bind(slot))
		if slot >= me.board.size():
			card.show_empty("Locked")
			card.disabled = true
			continue
		var here := {zone = "board", index = slot}
		if me.board[slot] != null:
			card.show_weapon(me.board[slot])
			_wire_drag(card, here, here, me.board[slot])
		else:
			card.show_empty("Empty")
			_wire_drag(card, here)
		card.set_selected(_is_selected("board", slot))


func _fill_inventory() -> void:
	_clear(_inventory_row)
	for i in GameConfig.INVENTORY_SIZE:
		var card := _add_card(_inventory_row, _on_inventory_slot.bind(i))
		if i < me.inventory.size():
			var item: RefCounted = me.inventory[i]
			card.show_item(item)
			_wire_drag(card, {zone = "inventory"}, {zone = "inventory", index = i}, item)
		else:
			_wire_drag(card, {zone = "inventory"})
		card.set_selected(_is_selected("inventory", i))


func _fill_lobby() -> void:
	_clear(_lobby)
	for p in game.players:
		var label := Label.new()
		if p.is_alive():
			label.text = "%s   %d HP   Lv %d" % [_player_name(p.id), p.health, p.level]
		else:
			label.text = "%s   out (#%d)" % [_player_name(p.id), game.placements.get(p.id, 0)]
			label.modulate = Color(1, 1, 1, 0.45)
		if p.id == HUMAN_ID:
			label.add_theme_color_override("font_color", Color("ffe08a"))
		_lobby.add_child(label)


func _fill_choice() -> void:
	_clear(_choice_box)
	_choice_overlay.visible = not me.pending.is_empty()
	if me.pending.is_empty():
		return
	var choice: Dictionary = me.pending[0]
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_box.add_child(title)
	match choice.kind:
		Player.Choice.PICK_MOD:
			title.text = "Triple! Which mod should the new weapon keep?"
			for i in choice.options.size():
				_add_choice_button(choice.options[i].display_name, i)
		Player.Choice.TRIPLE_REWARD:
			title.text = "Triple reward! Pick one:"
			if choice.mod != null:
				_add_choice_button("Mod: %s" % choice.mod.display_name, Player.REWARD_MOD)
			if choice.weapon != null:
				_add_choice_button("Weapon: %s" % choice.weapon, Player.REWARD_WEAPON)


func _add_choice_button(text: String, option: int) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_choose.bind(option))
	_choice_box.add_child(button)


func _show_game_over() -> void:
	var place: int = game.placements.get(HUMAN_ID, 0)
	var verdict := "Top %d, you gain Elo!" % GameConfig.TOP_PLACEMENTS if place <= GameConfig.TOP_PLACEMENTS else "You lose Elo."
	_game_over_label.text = "You placed #%d\n%s" % [place, verdict]
	_refresh()
	_game_over_overlay.show()


# --- Layout --------------------------------------------------------------

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("1e2230")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	margin.add_child(columns)

	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	columns.add_child(main)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	main.add_child(top)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 20)
	top.add_child(_info)
	_roll_button.text = "Roll (%dg)" % GameConfig.ROLL_COST
	_sell_button.text = "Sell"
	_fight_button.text = "Fight!"
	var actions := [
		[_level_button, _on_level_up], [_roll_button, _on_roll], [_freeze_button, _on_freeze],
		[_sell_button, _on_sell], [_fight_button, _on_fight],
	]
	for pair: Array in actions:
		var button: Button = pair[0]
		button.custom_minimum_size = Vector2(110, 44)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(pair[1])
		top.add_child(button)

	_shop_heading = _heading("Shop")
	main.add_child(_shop_heading)
	main.add_child(_shop_row)
	main.add_child(_heading("Board"))
	main.add_child(_board_row)
	main.add_child(_heading("Inventory"))
	main.add_child(_inventory_row)
	for row: HBoxContainer in [_shop_row, _board_row, _inventory_row]:
		row.add_theme_constant_override("separation", 6)
	_wire_row_drop(_shop_row, {zone = "shop"})
	_wire_row_drop(_inventory_row, {zone = "inventory"})
	_status.add_theme_color_override("font_color", Color("ff9a8a"))
	main.add_child(_status)
	var help := Label.new()
	help.text = "Drag cards to buy, play, move or apply mods. Drag onto the shop to sell. " \
		+ "Or click a card, then click where it should go."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.modulate = Color(1, 1, 1, 0.5)
	main.add_child(help)

	var side_panel := VBoxContainer.new()
	side_panel.custom_minimum_size = Vector2(200, 0)
	side_panel.add_theme_constant_override("separation", 8)
	side_panel.add_child(_heading("Lobby"))
	side_panel.add_child(_lobby)
	columns.add_child(side_panel)

	_choice_box.add_theme_constant_override("separation", 10)
	_choice_overlay = _overlay(_choice_box)

	var game_over_box := VBoxContainer.new()
	game_over_box.add_theme_constant_override("separation", 16)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.add_theme_font_size_override("font_size", 28)
	game_over_box.add_child(_game_over_label)
	var again := Button.new()
	again.text = "Play again"
	again.custom_minimum_size = Vector2(200, 48)
	again.pressed.connect(func() -> void: new_game())
	game_over_box.add_child(again)
	_game_over_overlay = _overlay(game_over_box)

	_combat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_combat)


## A dimmed full-screen layer with `content` centered in a panel. Starts hidden.
func _overlay(content: Control) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	margin.add_child(content)
	dim.hide()
	add_child(dim)
	return dim


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(1, 1, 1, 0.7)
	return label


func _add_card(row: HBoxContainer, on_pressed: Callable) -> ItemCard:
	var card := ItemCard.new()
	card.pressed.connect(on_pressed)
	row.add_child(card)
	return card


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
