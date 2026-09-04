class_name EntityFactory
extends RefCounted

const WOOD_PRIORITY_COLOR := Color(0.85, 0.65, 0.2)
const WANDER_PRIORITY_COLOR := Color(0.3, 0.55, 0.85)

const MOVE_TO_WOODPILE_ACTION: GoapAction = preload("res://game/resources/goap_actions/move_to_woodpile.tres")
const MOVE_TO_LANDMARK_ACTION: GoapAction = preload("res://game/resources/goap_actions/move_to_landmark.tres")
const CHOP_WOOD_ACTION: GoapAction = preload("res://game/resources/goap_actions/chop_wood.tres")
const HUNT_BOAR_ACTION: GoapAction = preload("res://game/resources/goap_actions/hunt_boar.tres")
const HUNT_DEER_ACTION: GoapAction = preload("res://game/resources/goap_actions/hunt_deer.tres")

const PREPARE_FOR_WINTER_GOAL: GoapGoal = preload("res://game/resources/goap_goals/prepare_for_winter_goal.tres")
const FORAGE_ANYTHING_GOAL: GoapGoal = preload("res://game/resources/goap_goals/forage_anything_goal.tres")
const WANDER_GOAL: GoapGoal = preload("res://game/resources/goap_goals/wander_goal.tres")

## Spawns one NPC entity: ECS components + a GoapAgent whose actions/goals are
## duplicated from shared .tres templates (see addons/goap/README.md - loaded
## Resources are cached/shared, so any per-agent mutation, including the
## priority override below, needs its own copy). NPCs alternate between a
## composite ALL goal (must gather both wood AND meat) and a composite ANY
## goal (either resource will do) as their primary goal, so both AND/OR
## composition modes are visible in the running demo.
static func spawn_npc(world: ECSWorld, parent: Node2D, spawn_pos: Vector2, prioritize_composite: bool) -> int:
	var e := world.create_entity()

	var pos_comp := PositionComponent.new()
	pos_comp.pos = spawn_pos
	world.add_component(e, Game.POSITION_TYPE, pos_comp)

	world.add_component(e, Game.PATH_FOLLOW_TYPE, PathFollowComponent.new())

	var primary_goal: GoapGoal = (PREPARE_FOR_WINTER_GOAL if prioritize_composite else FORAGE_ANYTHING_GOAL).duplicate(true)
	var wander_goal: GoapGoal = WANDER_GOAL.duplicate(true)
	primary_goal.priority = 2.0
	wander_goal.priority = 1.0

	var agent := GoapAgent.new()
	agent.goals = [primary_goal, wander_goal]
	agent.actions = [
		MOVE_TO_WOODPILE_ACTION.instantiate_for_agent(),
		CHOP_WOOD_ACTION.instantiate_for_agent(),
		MOVE_TO_LANDMARK_ACTION.instantiate_for_agent(),
		HUNT_BOAR_ACTION.instantiate_for_agent(),
		HUNT_DEER_ACTION.instantiate_for_agent(),
	]
	agent.goal_recheck_interval = 1.0 + randf()

	var goap_comp := GoapAgentComponent.new()
	goap_comp.agent = agent
	world.add_component(e, Game.GOAP_AGENT_TYPE, goap_comp)

	var visual := Sprite2D.new()
	visual.texture = _make_circle_texture(WOOD_PRIORITY_COLOR if prioritize_composite else WANDER_PRIORITY_COLOR)
	visual.global_position = spawn_pos
	parent.add_child(visual)

	var node_ref := NodeRefComponent.new()
	node_ref.node = visual
	world.add_component(e, Game.NODE_REF_TYPE, node_ref)

	return e

static func _make_circle_texture(color: Color) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length()
			img.set_pixel(x, y, color if d <= 7.5 else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
