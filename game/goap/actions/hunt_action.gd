class_name HuntAction
extends GoapAction

## One script, several .tres instances with different parameters - the
## "data-driven, don't multiply classes" pattern: hunt_boar.tres (slower,
## costlier, bigger meat_yield on AnimalComponent) and hunt_deer.tres
## (faster, cheaper) both use this script and both set produces_resource =
## meat.tres, so a goal that just wants meat can be satisfied by either, and
## the planner prefers the cheaper one.
##
## Kills the animal resolved by the preceding
## MoveToNearestAction(target_tag=&"animal") into
## AiBlackboardComponent.target_entity - fully destroyed via
## Game.despawn_entity() rather than left inert, unlike EatPlantAction's
## plants (an animal doesn't "regrow").

@export var quarry_name: String = "Animal"
@export var hunt_duration: float = 1.0

var _elapsed: float = 0.0

func start(_agent_owner: Variant) -> void:
	_elapsed = 0.0

func is_ready(agent_owner: Variant) -> bool:
	var world: ECSWorld = Game.ecs_world
	var board: AiBlackboardComponent = world.get_component(agent_owner, Game.AI_BLACKBOARD_TYPE)
	return Game.is_valid_target(world, board.target_entity, &"animal")

func perform(agent_owner: Variant, delta: float) -> int:
	_elapsed += delta
	if _elapsed < hunt_duration:
		return Status.RUNNING
	var world: ECSWorld = Game.ecs_world
	var board: AiBlackboardComponent = world.get_component(agent_owner, Game.AI_BLACKBOARD_TYPE)
	if not Game.is_valid_target(world, board.target_entity, &"animal"):
		return Status.FAILED

	var animal: AnimalComponent = world.get_component(board.target_entity, Game.ANIMAL_TYPE)
	var yield_amount := animal.meat_yield
	Game.despawn_entity(world, board.target_entity)

	var inv: InventoryComponent = world.get_component(agent_owner, Game.INVENTORY_TYPE)
	inv.add(produces_resource.id, yield_amount)
	return Status.SUCCESS
