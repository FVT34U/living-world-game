class_name DepositResourceAction
extends GoapAction

## Empties the agent's InventoryComponent for `requires_resource` into the
## storage resolved by the preceding MoveToNearestAction(target_tag=&"storage")
## into AiBlackboardComponent.target_entity. Configured as .tres instances -
## deposit_wood.tres / deposit_meat.tres - both using this one script with
## requires_resource set so the planner already knows "must be carrying this
## resource" without a hand-typed precondition.
##
## `delivered_fact` is set as an effect but is never written by
## Game.build_world_state(), so the agent's delivery goal
## (game/goap/goals/deliver_resource_goal.gd) is always unsatisfied at the
## start of a fresh tick - that is what makes the gather -> deliver cycle
## repeat forever using only the existing forward-search planner, no addon
## changes needed.

@export var delivered_fact: String = "delivered"

func procedural_effects(agent_owner: Variant, state: GoapWorldState) -> Dictionary:
	var d := super.procedural_effects(agent_owner, state)
	d[delivered_fact] = true
	return d

func perform(agent_owner: Variant, _delta: float) -> int:
	var world: ECSWorld = Game.ecs_world
	var board: AiBlackboardComponent = world.get_component(agent_owner, Game.AI_BLACKBOARD_TYPE)
	if not Game.is_valid_target(world, board.target_entity, &"storage"):
		return Status.FAILED
	var storage: StorageComponent = world.get_component(board.target_entity, Game.STORAGE_TYPE)
	var inv: InventoryComponent = world.get_component(agent_owner, Game.INVENTORY_TYPE)
	var amount := inv.get_amount(requires_resource.id)
	if amount <= 0:
		return Status.FAILED
	var accepted := storage.deposit(requires_resource.id, amount)
	if accepted <= 0:
		return Status.FAILED
	inv.add(requires_resource.id, -accepted)
	return Status.SUCCESS
