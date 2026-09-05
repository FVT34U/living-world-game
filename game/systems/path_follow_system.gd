class_name PathFollowSystem
extends System

## Pure ECS data manipulation: advances PositionComponent along whatever
## PackedVector2Array sits in PathFollowComponent. Knows nothing about GOAP
## or the pathfinding addon beyond that plain array.

var _buf: Array[int] = []

func _init() -> void:
	super._init(10, System.Phase.PROCESS)

func update(world: ECSWorld, delta: float) -> void:
	world.query_into([Game.POSITION_TYPE, Game.PATH_FOLLOW_TYPE], _buf)
	for e in _buf:
		var pos: PositionComponent = world.get_component(e, Game.POSITION_TYPE)
		var pf: PathFollowComponent = world.get_component(e, Game.PATH_FOLLOW_TYPE)
		if pf.locked or pf.arrived or pf.path.is_empty() or pf.path_index >= pf.path.size():
			continue
		var target: Vector2 = pf.path[pf.path_index]
		var to_target := target - pos.pos
		var step := pf.speed * delta
		if to_target.length() <= step:
			pos.pos = target
			pf.path_index += 1
			if pf.path_index >= pf.path.size():
				pf.arrived = true
		else:
			pos.pos += to_target.normalized() * step
