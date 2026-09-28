class_name Mod
extends Resource
## A mod definition. Weapon mods attach to a weapon; shop mods act on the economy.
## Effects aren't implemented yet; this only carries shop and sell data.

enum Kind { WEAPON, SHOP }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.WEAPON
## Mod strength. Shops offer tiers up to the player's level.
@export_range(1, 5) var tier: int = 1
@export var cost: int = 0
@export var sell_value: int = 0
@export_multiline var description: String


static func make(p_id: StringName, p_kind: Kind = Kind.WEAPON, p_tier: int = 1, p_cost: int = 0) -> Mod:
	var mod := Mod.new()
	mod.id = p_id
	mod.display_name = String(p_id).capitalize()
	mod.kind = p_kind
	mod.tier = p_tier
	mod.cost = p_cost
	return mod
