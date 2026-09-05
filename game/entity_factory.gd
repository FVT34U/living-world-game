class_name EntityFactory
extends RefCounted

## Every entity in the demo - settlers, animals, plants, buildings - is
## spawned through one of these functions, both from world_bootstrap.gd's
## initial setup and from the dev panel (game/ui/dev_panel.gd), so there is
## exactly one code path that creates a given kind of entity. Actions are
## instantiate_for_agent()'d per entity (see addons/goap/README.md - loaded
## Resources are shared/cached, and these carry runtime-mutable state);
## goals are stateless here and safe to share directly.

const WOODCUTTER_COLOR := Color(0.85, 0.65, 0.2)
const HUNTER_COLOR := Color(0.75, 0.25, 0.25)
const BOAR_COLOR := Color(0.35, 0.25, 0.2)
const DEER_COLOR := Color(0.8, 0.7, 0.5)
const PLANT_COLOR := Color(0.25, 0.6, 0.3)
const SAWMILL_COLOR := Color(0.55, 0.35, 0.15)
const STORAGE_COLOR := Color(0.25, 0.45, 0.75)

const STORAGE_CAPACITY := 30

const MOVE_TO_SAWMILL_ACTION: GoapAction = preload("res://game/resources/goap_actions/move_to_sawmill.tres")
const MOVE_TO_STORAGE_WOOD_ACTION: GoapAction = preload("res://game/resources/goap_actions/move_to_storage_wood.tres")
const MOVE_TO_STORAGE_MEAT_ACTION: GoapAction = preload("res://game/resources/goap_actions/move_to_storage_meat.tres")
const MOVE_TO_ANIMAL_ACTION: GoapAction = preload("res://game/resources/goap_actions/move_to_animal.tres")
const MOVE_TO_PLANT_ACTION: GoapAction = preload("res://game/resources/goap_actions/move_to_plant.tres")
const CHOP_WOOD_ACTION: GoapAction = preload("res://game/resources/goap_actions/chop_wood.tres")
const HUNT_BOAR_ACTION: GoapAction = preload("res://game/resources/goap_actions/hunt_boar.tres")
const HUNT_DEER_ACTION: GoapAction = preload("res://game/resources/goap_actions/hunt_deer.tres")
const DEPOSIT_WOOD_ACTION: GoapAction = preload("res://game/resources/goap_actions/deposit_wood.tres")
const DEPOSIT_MEAT_ACTION: GoapAction = preload("res://game/resources/goap_actions/deposit_meat.tres")
const EAT_PLANT_ACTION: GoapAction = preload("res://game/resources/goap_actions/eat_plant.tres")
const MOVE_TO_MATE_ACTION: GoapAction = preload("res://game/resources/goap_actions/move_to_mate.tres")
const MATE_ACTION: GoapAction = preload("res://game/resources/goap_actions/mate.tres")
const WANDER_ACTION: GoapAction = preload("res://game/resources/goap_actions/wander.tres")

const DELIVER_WOOD_GOAL: GoapGoal = preload("res://game/resources/goap_goals/deliver_wood_goal.tres")
const DELIVER_MEAT_GOAL: GoapGoal = preload("res://game/resources/goap_goals/deliver_meat_goal.tres")
const HUNGER_GOAL: GoapGoal = preload("res://game/resources/goap_goals/hunger_goal.tres")
const MATE_GOAL: GoapGoal = preload("res://game/resources/goap_goals/mate_goal.tres")
const WANDER_GOAL: GoapGoal = preload("res://game/resources/goap_goals/wander_goal.tres")

## Woodcutters chop at the sawmill and deliver wood; hunters stalk animals
## and deliver meat. Both fall back to wander_goal once their delivery goal
## is invalid (storage full - see DeliverResourceGoal.is_valid()).
##
## move_to_storage_wood.tres/move_to_storage_meat.tres set requires_resource
## (folded into their preconditions automatically by the base GoapAction) so
## the planner can only route through them once the matching resource is
## already in hand - without that, an empty-precondition "walk to storage"
## action is free to slot in *anywhere* in the plan, including before
## chopping/hunting, since nothing else constrains its position.
static func spawn_settler(world: ECSWorld, parent: Node2D, pos: Vector2, role: StringName) -> int:
	var e := world.create_entity()
	_add_movement(world, e, pos)
	_add_attributes(world, e)
	world.add_component(e, Game.INVENTORY_TYPE, InventoryComponent.new())
	world.add_component(e, Game.AI_BLACKBOARD_TYPE, AiBlackboardComponent.new())

	var role_comp := SettlerRoleComponent.new()
	role_comp.role = role
	world.add_component(e, Game.SETTLER_ROLE_TYPE, role_comp)

	var agent := GoapAgent.new()
	var color: Color
	if role == &"hunter":
		agent.goals = [DELIVER_MEAT_GOAL, WANDER_GOAL]
		agent.actions = [
			MOVE_TO_ANIMAL_ACTION.instantiate_for_agent(),
			HUNT_BOAR_ACTION.instantiate_for_agent(),
			HUNT_DEER_ACTION.instantiate_for_agent(),
			MOVE_TO_STORAGE_MEAT_ACTION.instantiate_for_agent(),
			DEPOSIT_MEAT_ACTION.instantiate_for_agent(),
			WANDER_ACTION.instantiate_for_agent(),
		]
		color = HUNTER_COLOR
	else:
		agent.goals = [DELIVER_WOOD_GOAL, WANDER_GOAL]
		agent.actions = [
			MOVE_TO_SAWMILL_ACTION.instantiate_for_agent(),
			CHOP_WOOD_ACTION.instantiate_for_agent(),
			MOVE_TO_STORAGE_WOOD_ACTION.instantiate_for_agent(),
			DEPOSIT_WOOD_ACTION.instantiate_for_agent(),
			WANDER_ACTION.instantiate_for_agent(),
		]
		color = WOODCUTTER_COLOR
	agent.goal_recheck_interval = 1.0 + randf()

	var goap_comp := GoapAgentComponent.new()
	goap_comp.agent = agent
	world.add_component(e, Game.GOAP_AGENT_TYPE, goap_comp)

	_add_visual(world, parent, e, pos, _make_circle_texture(color, 8), true)
	return e

## Animals cycle between eating (once hungry enough and a plant exists - see
## HungerGoal), mating (once well-fed, off cooldown, and a same-species
## partner exists - see MateGoal/game/goap/actions/mate_action.gd), and
## wandering the map at random.
static func spawn_animal(world: ECSWorld, parent: Node2D, pos: Vector2, species: StringName) -> int:
	var e := world.create_entity()
	_add_movement(world, e, pos)
	_add_attributes(world, e)
	world.add_component(e, Game.AI_BLACKBOARD_TYPE, AiBlackboardComponent.new())

	var animal := AnimalComponent.new()
	animal.species = species
	animal.meat_yield = 2 if species == &"boar" else 1
	animal.mate_cooldown = randf() * 5.0
	world.add_component(e, Game.ANIMAL_TYPE, animal)

	var agent := GoapAgent.new()
	agent.goals = [HUNGER_GOAL, MATE_GOAL, WANDER_GOAL]
	agent.actions = [
		MOVE_TO_PLANT_ACTION.instantiate_for_agent(),
		EAT_PLANT_ACTION.instantiate_for_agent(),
		MOVE_TO_MATE_ACTION.instantiate_for_agent(),
		MATE_ACTION.instantiate_for_agent(),
		WANDER_ACTION.instantiate_for_agent(),
	]
	agent.goal_recheck_interval = 0.75 + randf() * 0.5

	var goap_comp := GoapAgentComponent.new()
	goap_comp.agent = agent
	world.add_component(e, Game.GOAP_AGENT_TYPE, goap_comp)

	var color := BOAR_COLOR if species == &"boar" else DEER_COLOR
	_add_visual(world, parent, e, pos, _make_circle_texture(color, 7), true)
	return e

static func spawn_plant(world: ECSWorld, parent: Node2D, pos: Vector2) -> int:
	var e := world.create_entity()
	var pos_comp := PositionComponent.new()
	pos_comp.pos = pos
	world.add_component(e, Game.POSITION_TYPE, pos_comp)
	world.add_component(e, Game.PLANT_TYPE, PlantComponent.new())

	_add_visual(world, parent, e, pos, _make_circle_texture(PLANT_COLOR, 4), false)
	return e

## kind is &"sawmill" or &"storage"; only storage buildings get a
## StorageComponent (and a live-updating stock label - see StorageLabelSystem).
static func spawn_building(world: ECSWorld, parent: Node2D, pos: Vector2, kind: StringName) -> int:
	var e := world.create_entity()
	var pos_comp := PositionComponent.new()
	pos_comp.pos = pos
	world.add_component(e, Game.POSITION_TYPE, pos_comp)

	var building := BuildingComponent.new()
	building.kind = kind
	world.add_component(e, Game.BUILDING_TYPE, building)

	var color := SAWMILL_COLOR
	if kind == &"storage":
		var storage := StorageComponent.new()
		storage.capacity = STORAGE_CAPACITY
		world.add_component(e, Game.STORAGE_TYPE, storage)
		color = STORAGE_COLOR

	var node_ref := _add_visual(world, parent, e, pos, _make_square_texture(color, 22), true)
	if kind != &"storage":
		node_ref.label.text = "Sawmill"
	return e

static func _add_movement(world: ECSWorld, e: int, pos: Vector2) -> void:
	var pos_comp := PositionComponent.new()
	pos_comp.pos = pos
	world.add_component(e, Game.POSITION_TYPE, pos_comp)
	world.add_component(e, Game.PATH_FOLLOW_TYPE, PathFollowComponent.new())

## Registers every settler/animal with the full addons/attributes set (see
## game/systems/attribute_consequence_system.gd for what happens to each
## one). Satiety/Energy/Happiness/Age start jittered rather than pinned to
## their type's default so a freshly spawned batch doesn't get hungry, tired,
## or old in perfect lockstep - the same reasoning as GoapAgent.goal_recheck_interval's
## own random jitter elsewhere in this file.
static func _add_attributes(world: ECSWorld, e: int) -> void:
	var attrs := AttributeSet.new()
	attrs.register(Game.SATIETY_ATTR, 70.0 + randf() * 30.0)
	attrs.register(Game.ENERGY_ATTR, 80.0 + randf() * 20.0)
	attrs.register(Game.HEALTH_ATTR)
	attrs.register(Game.HAPPINESS_ATTR, 60.0 + randf() * 20.0)
	attrs.register(Game.AGE_ATTR, randf() * 20.0)
	world.add_component(e, Game.ATTRIBUTES_TYPE, attrs)

static func _add_visual(world: ECSWorld, parent: Node2D, e: int, pos: Vector2, texture: ImageTexture, with_label: bool) -> NodeRefComponent:
	var visual := Sprite2D.new()
	visual.texture = texture
	visual.global_position = pos
	parent.add_child(visual)

	var node_ref := NodeRefComponent.new()
	node_ref.node = visual
	if with_label:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 10)
		label.position = Vector2(-30, -28)
		label.custom_minimum_size = Vector2(60, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		visual.add_child(label)
		node_ref.label = label

	world.add_component(e, Game.NODE_REF_TYPE, node_ref)
	return node_ref

static func _make_circle_texture(color: Color, radius: int) -> ImageTexture:
	var size := radius * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(radius - 0.5, radius - 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center)
			img.set_pixel(x, y, color if d <= radius - 0.5 else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

static func _make_square_texture(color: Color, size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
