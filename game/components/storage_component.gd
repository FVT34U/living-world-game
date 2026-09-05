class_name StorageComponent
extends RefCounted

## A resource stockpile building. `amounts` mirrors InventoryComponent's
## shape (resource id -> count). `capacity` is the combined total across
## every resource kept here, so "the storage is full" is one simple concept
## regardless of the wood/meat mix - matches the settlers' fallback rule:
## once every storage is full they stop delivering and wander instead
## (see game/goap/goals/deliver_resource_goal.gd).

var amounts: Dictionary = {}
var capacity: int = 30

func get_amount(resource_id: StringName) -> int:
	return amounts.get(resource_id, 0)

func total() -> int:
	var sum := 0
	for v in amounts.values():
		sum += v
	return sum

func free_space() -> int:
	return capacity - total()

func is_full() -> bool:
	return free_space() <= 0

## Deposits up to `amount`, clamped by remaining capacity. Returns how much
## was actually accepted (DepositResourceAction fails the delivery if this
## comes back 0, e.g. another settler filled the last space first).
func deposit(resource_id: StringName, amount: int) -> int:
	var accepted := mini(amount, free_space())
	if accepted > 0:
		amounts[resource_id] = get_amount(resource_id) + accepted
	return accepted

## Removes up to `amount` (gradual consumption - see StorageConsumptionSystem).
## Returns how much was actually removed.
func consume(resource_id: StringName, amount: int) -> int:
	var have := get_amount(resource_id)
	var removed := mini(amount, have)
	amounts[resource_id] = have - removed
	return removed
