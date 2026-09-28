class_name CombatView
extends ColorRect
## Plays back one fight from its event log: opponent on top, you on the bottom.

const STEP_TIME := 0.4

var _their_name := Label.new()
var _their_row := HBoxContainer.new()
var _my_row := HBoxContainer.new()
var _my_name := Label.new()
var _result := Label.new()
var _skip := Button.new()
var _continue := Button.new()
var _skipping := false


func _init() -> void:
	color = Color(0.07, 0.08, 0.12, 0.96)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	for label: Label in [_their_name, _my_name, _result]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
	for row: HBoxContainer in [_their_row, _my_row]:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	for button: Button in [_skip, _continue]:
		button.custom_minimum_size = Vector2(140, 44)
		button.focus_mode = Control.FOCUS_NONE
		buttons.add_child(button)
	_skip.text = "Skip"
	_skip.pressed.connect(func() -> void: _skipping = true)
	_continue.text = "Continue"

	for node: Control in [_their_name, _their_row, gap, _my_row, _my_name, _result, buttons]:
		column.add_child(node)
	hide()


## Shows the fight and returns once the player presses Continue.
func play(fight: Dictionary, my_side: int, opponent_name: String) -> void:
	var their_side := 1 - my_side
	var result: Combat.Result = fight.result
	var boards: Array = fight.boards
	var cards := [[], []]
	cards[my_side] = _fill_row(_my_row, boards[my_side])
	cards[their_side] = _fill_row(_their_row, boards[their_side])
	var wins := [0, 0]
	var names := ["", ""]
	names[my_side] = "You"
	names[their_side] = opponent_name

	_skipping = false
	_result.text = ""
	_skip.show()
	_continue.hide()
	_update_names(names, wins, my_side, their_side)
	show()

	for event: Dictionary in result.events:
		await get_tree().create_timer(0.0 if _skipping else STEP_TIME).timeout
		match event.kind:
			"extra_slot":
				wins[event.side] += event.amount
				cards[event.side][event.lane].flash()
			"swing":
				for side in 2:
					var weapon: Weapon = boards[side][event.lane]
					if weapon == null:
						continue
					var card: ItemCard = cards[side][event.lane]
					card.show_weapon(weapon, event.durability[side])
					if event.durability[side] == 0:
						card.self_modulate = Color(1, 1, 1, 0.3)
				if event.winner != Combat.NO_WINNER:
					wins[event.winner] += 1
					cards[event.winner][event.lane].flash()
		_update_names(names, wins, my_side, their_side)

	if result.winner == my_side:
		_result.text = "You win! %s takes %d damage." % [opponent_name, result.damage]
	elif result.winner == their_side:
		_result.text = "You lose and take %d damage." % result.damage
	else:
		_result.text = "Draw. No damage."
	_skip.hide()
	_continue.show()
	await _continue.pressed
	hide()


func _fill_row(row: HBoxContainer, board: Array) -> Array:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var cards := []
	for weapon: Weapon in board:
		var card := ItemCard.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if weapon != null:
			card.show_weapon(weapon)
		row.add_child(card)
		cards.append(card)
	return cards


func _update_names(names: Array, wins: Array, my_side: int, their_side: int) -> void:
	_their_name.text = "%s: %s" % [names[their_side], _wins_text(wins[their_side])]
	_my_name.text = "%s: %s" % [names[my_side], _wins_text(wins[my_side])]


func _wins_text(count: int) -> String:
	return "1 win" if count == 1 else "%d wins" % count
