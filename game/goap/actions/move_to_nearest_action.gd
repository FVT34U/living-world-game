class_name MoveToNearestAction
extends GoapAction

## Dynamic-target counterpart to a fixed-waypoint move action: resolves the
## nearest live entity matching `target_tag` (see Game.find_nearest()) at
## plan-execution time, walks to it via the pathfinding addon, and publishes
## the resolved entity into the agent's AiBlackboardComponent so a following
## action (HuntAction, EatPlantAction, DepositResourceAction) can act on the
## same target without re-searching. Re-requests a path if the target has
## moved since the last request, so it can chase a wandering animal.
##
## Configured as .tres instances - move_to_sawmill.tres, move_to_storage.tres,
## move_to_animal.tres, move_to_plant.tres - all using this one script with
## different target_tag/target_fact pairs.

@export var target_tag: StringName = &""
@export var target_fact: String = "at_target"
@export var arrive_radius: float = 20.0
@export var reroute_distance: float = 24.0

var _requested: bool = false
var _last_target_pos: Vector2 = Vector2.INF

func procedural_effects(agent_owner: Variant, state: GoapWorldState) -> Dictionary:
	var d := super.procedural_effects(agent_owner, state)
	d[target_fact] = true
	return d

## A plan using this action only makes sense while a matching target exists
## somewhere - otherwise the planner should skip it, e.g. so a hunter with no
## live animals left falls back to wander_goal instead of stalling on an
## unreachable plan. Called by the planner on every candidate expansion, so
## must stay cheap - Game.find_nearest is O(n) over a handful of entities.
func is_procedurally_valid(agent_owner: Variant, _state: GoapWorldState) -> bool:
	var world: ECSWorld = Game.ecs_world
	var pos: PositionComponent = world.get_component(agent_owner, Game.POSITION_TYPE)
	return Game.find_nearest(world, pos.pos, target_tag) != -1

func start(agent_owner: Variant) -> void:
	_requested = false
	_last_target_pos = Vector2.INF
	var world: ECSWorld = Game.ecs_world
	var board: AiBlackboardComponent = world.get_component(agent_owner, Game.AI_BLACKBOARD_TYPE)
	board.target_entity = -1
	board.target_fact = target_fact
	board.target_tag = target_tag

func perform(agent_owner: Variant, _delta: float) -> int:
	var world: ECSWorld = Game.ecs_world
	var pos_comp: PositionComponent = world.get_component(agent_owner, Game.POSITION_TYPE)
	var board: AiBlackboardComponent = world.get_component(agent_owner, Game.AI_BLACKBOARD_TYPE)
	var path_follow: PathFollowComponent = world.get_component(agent_owner, Game.PATH_FOLLOW_TYPE)

	if board.target_entity == -1 or not Game.is_valid_target(world, board.target_entity, target_tag):
		board.target_entity = Game.find_nearest(world, pos_comp.pos, target_tag)
		if board.target_entity == -1:
			return Status.FAILED
		_requested = false

	var target_pos := Game.get_entity_position(world, board.target_entity)

	if not _requested or target_pos.distance_to(_last_target_pos) > reroute_distance:
		_requested = true
		_last_target_pos = target_pos
		path_follow.arrived = false
		Game.pathfinding_service.request_path(pos_comp.pos, target_pos, func(path: PackedVector2Array) -> void:
			path_follow.path = path
			path_follow.path_index = 0
			path_follow.arrived = path.is_empty()
		)
		return Status.RUNNING

	if not path_follow.arrived:
		return Status.RUNNING
	if pos_comp.pos.distance_to(target_pos) <= arrive_radius:
		return Status.SUCCESS
	# Arrived at a now-stale path endpoint because the (moving) target has
	# since drifted out of range - re-request a fresh path next tick.
	_requested = false
	return Status.RUNNING

func stop(_agent_owner: Variant) -> void:
	_requested = false
