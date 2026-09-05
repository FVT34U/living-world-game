extends Node2D

## Attached to the World node in world.tscn. Wires the four independent
## addons together into a small living-settlement simulation: settlers
## specialize as woodcutters (sawmill -> chop -> storage) or hunters
## (stalk a boar/deer -> kill it -> storage), animals wander, eat plants, and
## mate, a storage building slowly consumes its own stock, and every settler
## and animal carries a generic AttributeSet (Satiety/Energy/Health/
## Happiness/Age - see game/systems/attribute_consequence_system.gd) whose
## consequences include starving/exhausting/aging to death. All of it is
## driven by the same generic addons/ecs + addons/goap + addons/pathfinding +
## addons/attributes quartet - see docs/ARCHITECTURE.md for the full
## data-flow explanation. A dev panel (F1, game/ui/dev_panel.gd) can
## spawn/remove any of it at runtime.

@export var GRID_SIZE := 40
@export var CELL_SIZE := Vector2(16, 16)
@export var NPC_COUNT := 6
@export var BOAR_COUNT := 6
@export var DEER_COUNT := 6
@export var PLANT_COUNT := 16
@export var SPAWN_POS := Vector2(300, 340)
@export var STORAGE_POS := Vector2(300, 80)
@export var SAWMILL_POS := Vector2(540, 140)

func _ready() -> void:
	var world := ECSWorld.new()
	add_child(world)
	Game.ecs_world = world
	Game.world_root = self

	Game.POSITION_TYPE = world.register_component(PositionComponent)
	Game.PATH_FOLLOW_TYPE = world.register_component(PathFollowComponent)
	Game.GOAP_AGENT_TYPE = world.register_component(GoapAgentComponent)
	Game.NODE_REF_TYPE = world.register_component(NodeRefComponent)
	Game.INVENTORY_TYPE = world.register_component(InventoryComponent)
	Game.ANIMAL_TYPE = world.register_component(AnimalComponent)
	Game.PLANT_TYPE = world.register_component(PlantComponent)
	Game.BUILDING_TYPE = world.register_component(BuildingComponent)
	Game.STORAGE_TYPE = world.register_component(StorageComponent)
	Game.AI_BLACKBOARD_TYPE = world.register_component(AiBlackboardComponent)
	Game.SETTLER_ROLE_TYPE = world.register_component(SettlerRoleComponent)
	# AttributeSet (addons/attributes) needs no game-specific wrapper to work
	# as an ECS component - it's already a plain RefCounted class.
	Game.ATTRIBUTES_TYPE = world.register_component(AttributeSet)

	var provider := Grid2DPathfinder.new()
	provider.setup({
		"region": Rect2i(0, 0, GRID_SIZE, GRID_SIZE),
		"cell_size": CELL_SIZE,
		"diagonal_mode": AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES,
	})
	# A short wall so the demo visibly exercises pathfinding around an
	# obstacle, not just straight lines.
	for cy in range(10, 20):
		provider.set_obstacle(Vector2i(20, cy), true)

	var service := PathfindingService.new()
	service.provider = provider
	add_child(service)
	Game.pathfinding_service = service

	world.add_system(AnimalNeedsSystem.new())
	world.add_system(AttributeConsequenceSystem.new())
	world.add_system(GoapPlanningSystem.new())
	world.add_system(PathFollowSystem.new())
	world.add_system(PlantRegrowSystem.new())
	world.add_system(StorageConsumptionSystem.new())
	world.add_system(RenderSyncSystem.new())
	world.add_system(StatusLabelSystem.new())
	world.add_system(StorageLabelSystem.new())

	EntityFactory.spawn_building(world, self, SAWMILL_POS, &"sawmill")
	EntityFactory.spawn_building(world, self, STORAGE_POS, &"storage")

	for i in PLANT_COUNT:
		EntityFactory.spawn_plant(world, self, _random_point())
	for i in BOAR_COUNT:
		EntityFactory.spawn_animal(world, self, _random_point(), &"boar")
	for i in DEER_COUNT:
		EntityFactory.spawn_animal(world, self, _random_point(), &"deer")

	for i in NPC_COUNT:
		# Only one hunter rather than half the settlers: with mating now the
		# only source of new animals (see MateGoal/MateAction), too much
		# hunting pressure relative to the starting population reliably wipes
		# every same-species pair out before a single litter has time to
		# complete - same-species pairing makes small populations fragile.
		var role: StringName = &"hunter" if i == 0 else &"woodcutter"
		EntityFactory.spawn_settler(world, self, SPAWN_POS + Vector2(i * 20, 0), role)

	var dev_panel := DevPanel.new()
	add_child(dev_panel)
	dev_panel.setup(world, self)

func _random_point() -> Vector2:
	return Vector2(
		randf_range(40, GRID_SIZE * CELL_SIZE.x - 40),
		randf_range(40, GRID_SIZE * CELL_SIZE.y - 40)
	)
