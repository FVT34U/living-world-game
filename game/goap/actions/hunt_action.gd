class_name HuntAction
extends GoapAction

## One script, several .tres instances with different parameters - the
## "data-driven, don't multiply classes" pattern: hunt_boar.tres (slower,
## costlier) and hunt_deer.tres (faster, cheaper) both use this script and
## both set produces_resource = meat.tres, so a goal that just wants meat
## can be satisfied by either, and the planner prefers the cheaper one.

@export var quarry_name: String = "Animal"
@export var hunt_duration: float = 1.0

var _elapsed: float = 0.0

func start(_agent_owner: Variant) -> void:
	_elapsed = 0.0

func perform(agent_owner: Variant, delta: float) -> int:
	_elapsed += delta
	if _elapsed < hunt_duration:
		return Status.RUNNING
	var world: ECSWorld = Game.ecs_world
	var goap_comp: GoapAgentComponent = world.get_component(agent_owner, Game.GOAP_AGENT_TYPE)
	goap_comp.inventory_meat += 1
	return Status.SUCCESS
