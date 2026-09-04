class_name MoveToAction
extends GoapAction

## The one file that touches all three addons: it is a GoapAction (goap addon)
## that reads/writes ECS components (ecs addon, via the Game singleton) and
## requests a path from PathfindingService (pathfinding addon). None of the
## three addons reference each other directly - this adapter lives in
## res://game/ specifically so they don't have to.
##
## Configured as a .tres template (target_pos/target_fact set in the
## Inspector) - see game/resources/goap_actions/move_to_woodpile.tres and
## move_to_landmark.tres for two instances of this one script.

@export var target_pos: Vector2
@export var target_fact: String = "at_target"

var _requested: bool = false

func procedural_effects(agent_owner: Variant, state: GoapWorldState) -> Dictionary:
	var d := super.procedural_effects(agent_owner, state)
	d[target_fact] = true
	return d

func start(_agent_owner: Variant) -> void:
	_requested = false

func perform(agent_owner: Variant, _delta: float) -> int:
	var world: ECSWorld = Game.ecs_world
	var entity: int = agent_owner
	var path_follow: PathFollowComponent = world.get_component(entity, Game.PATH_FOLLOW_TYPE)

	if not _requested:
		_requested = true
		var pos_comp: PositionComponent = world.get_component(entity, Game.POSITION_TYPE)
		path_follow.arrived = false
		Game.pathfinding_service.request_path(pos_comp.pos, target_pos, func(path: PackedVector2Array) -> void:
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
