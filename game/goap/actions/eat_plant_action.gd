class_name EatPlantAction
extends GoapAction

## Consumes the plant resolved by the preceding
## MoveToNearestAction(target_tag=&"plant") into
## AiBlackboardComponent.target_entity: marks it inert (PlantComponent.alive
## = false, regrow_timer started - see PlantRegrowSystem) and hides its
## visual, then resets the eater's own AnimalComponent.hunger. Configured via
## eat_plant.tres (precondition "at_plant": true, matching
## move_to_plant.tres's target_fact).

@export var eat_duration: float = 0.6
@export var regrow_time: float = 12.0

var _elapsed: float = 0.0

func start(_agent_owner: Variant) -> void:
	_elapsed = 0.0

func is_ready(agent_owner: Variant) -> bool:
	var world: ECSWorld = Game.ecs_world
	var board: AiBlackboardComponent = world.get_component(agent_owner, Game.AI_BLACKBOARD_TYPE)
	return Game.is_valid_target(world, board.target_entity, &"plant")

func perform(agent_owner: Variant, delta: float) -> int:
	_elapsed += delta
	if _elapsed < eat_duration:
		return Status.RUNNING
	var world: ECSWorld = Game.ecs_world
	var board: AiBlackboardComponent = world.get_component(agent_owner, Game.AI_BLACKBOARD_TYPE)
	if not Game.is_valid_target(world, board.target_entity, &"plant"):
		return Status.FAILED

	var plant: PlantComponent = world.get_component(board.target_entity, Game.PLANT_TYPE)
	plant.alive = false
	plant.regrow_timer = regrow_time
	if world.has_component(board.target_entity, Game.NODE_REF_TYPE):
		var plant_node_ref: NodeRefComponent = world.get_component(board.target_entity, Game.NODE_REF_TYPE)
		if is_instance_valid(plant_node_ref.node):
			plant_node_ref.node.visible = false

	if world.has_component(agent_owner, Game.ANIMAL_TYPE):
		var animal: AnimalComponent = world.get_component(agent_owner, Game.ANIMAL_TYPE)
		animal.hunger = 0.0
	return Status.SUCCESS
