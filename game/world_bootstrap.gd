extends Node2D

## Attached to the World node in world.tscn. Wires the three independent
## addons together for a small runnable demo: spawns NPCs that alternate
## between a composite ALL goal ("prepare for winter": wood AND meat) and a
## composite ANY goal ("forage anything": wood OR meat), falling back to
## wandering, and walk to their targets via the pathfinding addon, driven by
## ECS systems. All goals/actions are loaded from res://game/resources/.

@export var WOODPILE_MARKER_COLOR := Color(0.55, 0.35, 0.15)
@export var LANDMARK_MARKER_COLOR := Color(0.2, 0.6, 0.3)
@export var GRID_SIZE := 40
@export var CELL_SIZE := Vector2(16, 16)
@export var NPC_COUNT := 3
@export var SPAWN_POS := Vector2(300, 300)

func _ready() -> void:
	var world := ECSWorld.new()
	add_child(world)
	Game.ecs_world = world

	Game.POSITION_TYPE = world.register_component(PositionComponent)
	Game.PATH_FOLLOW_TYPE = world.register_component(PathFollowComponent)
	Game.GOAP_AGENT_TYPE = world.register_component(GoapAgentComponent)
	Game.NODE_REF_TYPE = world.register_component(NodeRefComponent)

	var provider := Grid2DPathfinder.new()
	provider.setup({
		"region": Rect2i(0, 0, GRID_SIZE, GRID_SIZE),
		"cell_size": CELL_SIZE,
		"diagonal_mode": AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES,
	})
	# A short wall between the spawn point and the targets so the demo
	# visibly exercises pathfinding around an obstacle, not just a straight line.
	for cy in range(10, 20):
		provider.set_obstacle(Vector2i(20, cy), true)

	var service := PathfindingService.new()
	service.provider = provider
	add_child(service)
	Game.pathfinding_service = service

	world.add_system(GoapPlanningSystem.new())
	world.add_system(PathFollowSystem.new())
	world.add_system(RenderSyncSystem.new())

	_spawn_marker(Game.WOODPILE_POS, WOODPILE_MARKER_COLOR)
	_spawn_marker(Game.LANDMARK_POS, LANDMARK_MARKER_COLOR)

	for i in NPC_COUNT:
		EntityFactory.spawn_npc(world, self, SPAWN_POS + Vector2(i * 24, 0), i % 2 == 0)

func _spawn_marker(pos: Vector2, color: Color) -> void:
	var marker := ColorRect.new()
	marker.size = Vector2(20, 20)
	marker.position = pos - marker.size / 2.0
	marker.color = color
	add_child(marker)
