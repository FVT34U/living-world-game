extends Node

## Autoload "Game". The one place in the project allowed to know about the
## ecs, goap, and pathfinding addons at the same time - none of the three
## addons reference this script or each other.

var ecs_world: ECSWorld
var pathfinding_service: PathfindingService

var POSITION_TYPE: int = -1
var PATH_FOLLOW_TYPE: int = -1
var GOAP_AGENT_TYPE: int = -1
var NODE_REF_TYPE: int = -1

const WOODPILE_POS := Vector2(520, 120)
const LANDMARK_POS := Vector2(120, 520)
const ARRIVE_RADIUS := 20.0

const WOOD_RESOURCE: GoapResourceType = preload("res://game/resources/goap_resources/wood.tres")
const MEAT_RESOURCE: GoapResourceType = preload("res://game/resources/goap_resources/meat.tres")

## Builds a fresh GoapWorldState from live ECS component data for one entity.
## This is the adapter step that turns ECS state into the plain Dictionary
## the GOAP addon reasons over - the GOAP addon never does this itself.
func build_world_state(world: ECSWorld, entity: int) -> GoapWorldState:
	var pos_comp: PositionComponent = world.get_component(entity, POSITION_TYPE)
	var goap_comp: GoapAgentComponent = world.get_component(entity, GOAP_AGENT_TYPE)
	var state := GoapWorldState.new()
	state.facts = {
		"at_woodpile": pos_comp.pos.distance_to(WOODPILE_POS) < ARRIVE_RADIUS,
		"at_landmark": pos_comp.pos.distance_to(LANDMARK_POS) < ARRIVE_RADIUS,
		WOOD_RESOURCE.fact_key(): goap_comp.inventory_wood > 0,
		MEAT_RESOURCE.fact_key(): goap_comp.inventory_meat > 0,
	}
	return state
