class_name ChopWoodAction
extends GoapAction

## Configured as a .tres template - preconditions ({"at_sawmill": true},
## matching move_to_sawmill.tres's target_fact) and produces_resource
## (wood.tres) are set in the Inspector, not hardcoded here. See
## game/resources/goap_actions/chop_wood.tres.

@export var chop_duration: float = 1.0

var _elapsed: float = 0.0

func start(_agent_owner: Variant) -> void:
	_elapsed = 0.0

func perform(agent_owner: Variant, delta: float) -> int:
	_elapsed += delta
	if _elapsed < chop_duration:
		return Status.RUNNING
	var world: ECSWorld = Game.ecs_world
	var inv: InventoryComponent = world.get_component(agent_owner, Game.INVENTORY_TYPE)
	inv.add(produces_resource.id, 1)
	return Status.SUCCESS
