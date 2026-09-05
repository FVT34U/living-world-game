class_name WanderAction
extends GoapAction

## Picks a random reachable point inside `bounds` and walks there - gives an
## idle settler/animal visible aimless movement whenever its primary goal is
## unavailable (storage full, no live animals/plants left) instead of
## freezing in place. Effects set `wander_fact` to a value Game.build_world_state()
## never writes into the live rebuilt GoapWorldState, so - like
## DepositResourceAction's delivered_fact - wander_goal never stays
## "satisfied" and keeps re-triggering a fresh random walk.

@export var bounds: Rect2 = Rect2(40, 40, 560, 560)
@export var wander_fact: String = "wandered"
@export var arrive_radius: float = 16.0

var _requested: bool = false
var _target_pos: Vector2 = Vector2.ZERO

func procedural_effects(agent_owner: Variant, state: GoapWorldState) -> Dictionary:
	var d := super.procedural_effects(agent_owner, state)
	d[wander_fact] = true
	return d

func start(_agent_owner: Variant) -> void:
	_requested = false
	_target_pos = Vector2(
		randf_range(bounds.position.x, bounds.end.x),
		randf_range(bounds.position.y, bounds.end.y)
	)

func perform(agent_owner: Variant, _delta: float) -> int:
	var world: ECSWorld = Game.ecs_world
	var pos_comp: PositionComponent = world.get_component(agent_owner, Game.POSITION_TYPE)
	var path_follow: PathFollowComponent = world.get_component(agent_owner, Game.PATH_FOLLOW_TYPE)

	if not _requested:
		_requested = true
		path_follow.arrived = false
		Game.pathfinding_service.request_path(pos_comp.pos, _target_pos, func(path: PackedVector2Array) -> void:
			path_follow.path = path
			path_follow.path_index = 0
			path_follow.arrived = path.is_empty()
		)
		return Status.RUNNING

	if path_follow.arrived:
		return Status.SUCCESS
	return Status.RUNNING

func stop(_agent_owner: Variant) -> void:
	_requested = false
