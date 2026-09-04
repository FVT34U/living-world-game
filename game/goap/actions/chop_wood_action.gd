class_name ChopWoodAction
extends GoapAction

## Configured as a .tres template - preconditions ({"at_woodpile": true}) and
## produces_resource (wood.tres) are set in the Inspector, not hardcoded here.
## See game/resources/goap_actions/chop_wood.tres.

@export var chop_duration: float = 1.0

var _elapsed: float = 0.0

func start(_agent_owner: Variant) -> void:
	_elapsed = 0.0

func perform(agent_owner: Variant, delta: float) -> int:
	_elapsed += delta
	if _elapsed < chop_duration:
		return Status.RUNNING
	var world: ECSWorld = Game.ecs_world
	var goap_comp: GoapAgentComponent = world.get_component(agent_owner, Game.GOAP_AGENT_TYPE)
	goap_comp.inventory_wood += 1
	return Status.SUCCESS
