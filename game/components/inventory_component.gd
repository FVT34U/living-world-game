class_name InventoryComponent
extends RefCounted

## Generic per-entity carried-resource counts, keyed by GoapResourceType id
## (e.g. &"wood", &"meat"). Written by ChopWoodAction/HuntAction/
## DepositResourceAction, read back by Game.build_world_state() to derive
## "has_resource:<id>" facts - not part of the goap or ecs addons themselves,
## purely game-domain data.

var amounts: Dictionary = {}

func get_amount(resource_id: StringName) -> int:
	return amounts.get(resource_id, 0)

func add(resource_id: StringName, delta: int) -> void:
	amounts[resource_id] = get_amount(resource_id) + delta
