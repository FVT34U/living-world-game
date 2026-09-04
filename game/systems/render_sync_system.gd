class_name RenderSyncSystem
extends System

## Copies PositionComponent -> NodeRefComponent.node.global_position each
## frame so ECS state is visible on screen. Runs last (highest priority
## number) so it always reflects this frame's final position.

var _buf: Array[int] = []

func _init() -> void:
	super._init(20, System.Phase.PROCESS)

func update(world: ECSWorld, _delta: float) -> void:
	world.query_into([Game.POSITION_TYPE, Game.NODE_REF_TYPE], _buf)
	for e in _buf:
		var pos: PositionComponent = world.get_component(e, Game.POSITION_TYPE)
		var node_ref: NodeRefComponent = world.get_component(e, Game.NODE_REF_TYPE)
		if is_instance_valid(node_ref.node):
			node_ref.node.global_position = pos.pos
