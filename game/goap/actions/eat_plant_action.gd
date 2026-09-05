class_name EatPlantAction
extends GoapAction

## Consumes the plant resolved by the preceding
## MoveToNearestAction(target_tag=&"plant") into
## AiBlackboardComponent.target_entity: marks it inert (PlantComponent.alive
## = false, regrow_timer started - see PlantRegrowSystem) and hides its
## visual, then refills the eater's own Satiety attribute (addons/attributes)
## to full. Configured via eat_plant.tres (precondition "at_plant": true,
## matching move_to_plant.tres's target_fact).

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

	if world.has_component(agent_owner, Game.ATTRIBUTES_TYPE):
		var attrs: AttributeSet = world.get_component(agent_owner, Game.ATTRIBUTES_TYPE)
		attrs.set_value(Game.SATIETY_ATTR, Game.SATIETY_ATTR.max_value)
	return Status.SUCCESS
