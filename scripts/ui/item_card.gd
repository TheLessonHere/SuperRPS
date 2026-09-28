class_name ItemCard
extends Button
## A clickable card showing a weapon, a mod, or an empty slot. Placeholder art:
## fill color is the weapon type, border color is the weapon level.

const CARD_SIZE := Vector2(96, 112)
const TYPE_COLORS := {
	Weapon.Type.ROCK: Color("7a6a5a"),
	Weapon.Type.PAPER: Color("4f7cc9"),
	Weapon.Type.SCISSORS: Color("c9504a"),
}
## Indexed by weapon level: basic (bronze), silver, gold, platinum, diamond.
const LEVEL_COLORS: Array[Color] = [
	Color.BLACK, Color("a0703c"), Color("c8ccd0"), Color("f2c14e"), Color("5fd3c6"), Color("c9a8ff"),
]
const MOD_COLOR := Color("3d8a5a")
const EMPTY_FILL := Color(1, 1, 1, 0.05)
const EMPTY_BORDER := Color(1, 1, 1, 0.15)
const DROP_COLOR := Color("7dff9a")

var _title := Label.new()
var _subtitle := Label.new()
var _detail := Label.new()
var _footer := Label.new()
var _fill := EMPTY_FILL
var _border := EMPTY_BORDER
var _selected := false
var _drop_highlight := false


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	focus_mode = Control.FOCUS_NONE
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	for label: Label in [_title, _subtitle, _detail, _footer]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
	_title.add_theme_font_size_override("font_size", 20)
	_footer.add_theme_color_override("font_color", Color("ffe08a"))
	add_child(box)
	show_empty()


## `durability` overrides the shown durability (used during combat playback).
func show_weapon(weapon: Weapon, durability: int = -1) -> void:
	_fill = TYPE_COLORS[weapon.type]
	_border = LEVEL_COLORS[weapon.level]
	_title.text = String(Weapon.Type.keys()[weapon.type]).capitalize()
	_subtitle.text = Weapon.LEVEL_NAMES[weapon.level]
	_detail.text = "Durability %d" % (weapon.max_durability() if durability < 0 else durability)
	_footer.text = "+" + weapon.mod.display_name if weapon.mod != null else ""
	_apply_style()


func show_mod(mod: Mod) -> void:
	_fill = MOD_COLOR
	_border = LEVEL_COLORS[mod.tier]
	_title.text = "Mod"
	_subtitle.text = mod.display_name
	_detail.text = "Weapon mod" if mod.kind == Mod.Kind.WEAPON else "Shop mod"
	_footer.text = ""
	_apply_style()


func show_item(item: RefCounted) -> void:
	if item is Weapon:
		show_weapon(item)
	elif item is Mod:
		show_mod(item)
	else:
		show_empty()


func show_empty(text: String = "") -> void:
	_fill = EMPTY_FILL
	_border = EMPTY_BORDER
	_title.text = ""
	_subtitle.text = text
	_detail.text = ""
	_footer.text = ""
	_apply_style()


## Small highlighted line at the bottom, e.g. a price.
func set_footer(text: String) -> void:
	_footer.text = text


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_style()


## Marks the card as a valid drop spot during a drag.
func set_drop_highlight(highlighted: bool) -> void:
	_drop_highlight = highlighted
	_apply_style()


func flash() -> void:
	modulate = Color(1.8, 1.8, 1.8)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.3)


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = _fill
	if _selected:
		style.border_color = Color.WHITE
	elif _drop_highlight:
		style.border_color = DROP_COLOR
	else:
		style.border_color = _border
	style.set_border_width_all(5 if _selected or _drop_highlight else 3)
	style.set_corner_radius_all(8)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = _fill.lightened(0.15)
	for state in ["normal", "pressed", "focus"]:
		add_theme_stylebox_override(state, style)
	add_theme_stylebox_override("hover", hover)
	var disabled := style.duplicate() as StyleBoxFlat
	disabled.bg_color = _fill.darkened(0.5)
	add_theme_stylebox_override("disabled", disabled)
