extends Node

## Autoload "Game". The one place in the project allowed to know about the
## ecs, goap, and pathfinding addons at the same time - none of the three
## addons reference this script or each other.
##
## Beyond wiring, this is also where "dynamic GOAP target" resolution lives:
## MoveToNearestAction asks find_nearest() for the closest live entity
## matching a tag (&"sawmill", &"storage", &"animal", &"plant") instead of
## any addon knowing what those tags mean.

var ecs_world: ECSWorld
var pathfinding_service: PathfindingService

## The Node2D new entities' Sprite2D visuals get parented under - set once by
## world_bootstrap.gd. Needed by actions that spawn new entities themselves
## at runtime (MateAction) rather than only at bootstrap/from the dev panel,
## both of which already have a parent Node2D in scope directly.
var world_root: Node2D

var POSITION_TYPE: int = -1
var PATH_FOLLOW_TYPE: int = -1
var GOAP_AGENT_TYPE: int = -1
var NODE_REF_TYPE: int = -1
var INVENTORY_TYPE: int = -1
var ANIMAL_TYPE: int = -1
var PLANT_TYPE: int = -1
var BUILDING_TYPE: int = -1
var STORAGE_TYPE: int = -1
var AI_BLACKBOARD_TYPE: int = -1
var SETTLER_ROLE_TYPE: int = -1

## How close (px) an agent must be to a resolved target to count as "at" it -
## kept in sync with MoveToNearestAction's own @export arrive_radius default.
const ARRIVE_RADIUS := 20.0

## An animal counts as "well-fed enough to mate" below this - well under
## HungerGoal's default 0.5 activation threshold, so the two goals'
## validity windows don't overlap (see MateGoal).
const MATE_HUNGER_THRESHOLD := 0.3
## Hard cap on total animals: past this, is_mate_eligible() always returns
## false, so reproduction can't grow the population unboundedly.
const MAX_ANIMAL_POPULATION := 24

const WOOD_RESOURCE: GoapResourceType = preload("res://game/resources/goap_resources/wood.tres")
const MEAT_RESOURCE: GoapResourceType = preload("res://game/resources/goap_resources/meat.tres")

## Builds a fresh GoapWorldState from live ECS component data for one entity.
## This is the adapter step that turns ECS state into the plain Dictionary
## the GOAP addon reasons over - the GOAP addon never does this itself.
## Generic across every kind of GOAP agent (settler or animal): the
## "at_<target>" fact comes from whatever AiBlackboardComponent.target_fact
## the entity's currently-running MoveToNearestAction last set, and resource
## facts come from InventoryComponent when the entity carries one.
func build_world_state(world: ECSWorld, entity: int) -> GoapWorldState:
	var state := GoapWorldState.new()

	if world.has_component(entity, AI_BLACKBOARD_TYPE):
		var board: AiBlackboardComponent = world.get_component(entity, AI_BLACKBOARD_TYPE)
		if board.target_entity != -1 and board.target_fact != "":
			var pos_comp: PositionComponent = world.get_component(entity, POSITION_TYPE)
			var target_alive := is_valid_target(world, board.target_entity, board.target_tag)
			var at_target := target_alive and pos_comp.pos.distance_to(get_entity_position(world, board.target_entity)) < ARRIVE_RADIUS
			state.facts[board.target_fact] = at_target

	if world.has_component(entity, INVENTORY_TYPE):
		var inv: InventoryComponent = world.get_component(entity, INVENTORY_TYPE)
		state.facts[WOOD_RESOURCE.fact_key()] = inv.get_amount(WOOD_RESOURCE.id) > 0
		state.facts[MEAT_RESOURCE.fact_key()] = inv.get_amount(MEAT_RESOURCE.id) > 0

	return state

func get_entity_position(world: ECSWorld, entity: int) -> Vector2:
	if not world.has_component(entity, POSITION_TYPE):
		return Vector2.INF
	return (world.get_component(entity, POSITION_TYPE) as PositionComponent).pos

## True while `entity` still exists, still actually carries the component
## that makes it a `tag`, and, for tags whose targets can go inert without
## being destroyed (a plant that's been eaten and is regrowing), still
## counts as usable.
##
## Checking the component, not just is_alive(), matters because ECSWorld
## recycles entity ids: a stale AiBlackboardComponent.target_entity left
## over from a dead animal can later be reassigned to a completely
## different entity (a plant, a storage, ...). Without this check that
## coincidence would read as "still a valid animal" and hand callers
## (HuntAction, DepositResourceAction, ...) the wrong component - or, since
## ComponentStorage.get_comp() indexes its dense array without bounds
## checking, an *unrelated* entity's component when the type-storage lookup
## itself is missing.
func is_valid_target(world: ECSWorld, entity: int, tag: StringName) -> bool:
	if entity == -1 or not world.is_alive(entity):
		return false
	match tag:
		&"sawmill":
			return world.has_component(entity, BUILDING_TYPE) and (world.get_component(entity, BUILDING_TYPE) as BuildingComponent).kind == &"sawmill"
		&"storage":
			return world.has_component(entity, STORAGE_TYPE)
		&"animal":
			return world.has_component(entity, ANIMAL_TYPE)
		&"plant":
			return world.has_component(entity, PLANT_TYPE) and (world.get_component(entity, PLANT_TYPE) as PlantComponent).alive
		&"mate":
			return is_mate_eligible(world, entity)
	return false

## Finds the closest entity matching `tag` to `from_pos`, or -1 if none
## exists. Called both by MoveToNearestAction (during planning validity
## checks and at execution time) and by goals (HungerGoal, MateGoal) that
## need to know whether a target exists at all before committing to a plan
## for it. `requester` is only used by tag &"mate" (to exclude self and
## match species) - every other tag ignores it.
func find_nearest(world: ECSWorld, from_pos: Vector2, tag: StringName, requester: int = -1) -> int:
	var buf: Array[int] = []
	var best := -1
	var best_dist := INF
	match tag:
		&"sawmill":
			world.query_into([BUILDING_TYPE], buf)
			for e in buf:
				if (world.get_component(e, BUILDING_TYPE) as BuildingComponent).kind != &"sawmill":
					continue
				var d := from_pos.distance_squared_to(get_entity_position(world, e))
				if d < best_dist:
					best_dist = d
					best = e
		&"storage":
			world.query_into([STORAGE_TYPE], buf)
			for e in buf:
				if (world.get_component(e, STORAGE_TYPE) as StorageComponent).is_full():
					continue
				var d := from_pos.distance_squared_to(get_entity_position(world, e))
				if d < best_dist:
					best_dist = d
					best = e
		&"animal":
			# This tag is only ever used to find a hunt target (see
			# move_to_animal.tres), so it excludes animals off-limits to
			# hunting - MateAction/HuntAction re-validate an already-locked
			# target with is_valid_target()/is_animal_protected() directly,
			# which don't go through this search.
			world.query_into([ANIMAL_TYPE], buf)
			for e in buf:
				if is_animal_protected(world, e):
					continue
				var d := from_pos.distance_squared_to(get_entity_position(world, e))
				if d < best_dist:
					best_dist = d
					best = e
		&"plant":
			world.query_into([PLANT_TYPE], buf)
			for e in buf:
				if not (world.get_component(e, PLANT_TYPE) as PlantComponent).alive:
					continue
				var d := from_pos.distance_squared_to(get_entity_position(world, e))
				if d < best_dist:
					best_dist = d
					best = e
		&"mate":
			if requester == -1 or not world.has_component(requester, ANIMAL_TYPE):
				return -1
			var mine: AnimalComponent = world.get_component(requester, ANIMAL_TYPE)
			world.query_into([ANIMAL_TYPE], buf)
			for e in buf:
				if e == requester:
					continue
				var a: AnimalComponent = world.get_component(e, ANIMAL_TYPE)
				if a.species != mine.species or not is_mate_eligible(world, e):
					continue
				var d := from_pos.distance_squared_to(get_entity_position(world, e))
				if d < best_dist:
					best_dist = d
					best = e
	return best

## True while `entity` is a living animal that is well-fed (hunger below
## MATE_HUNGER_THRESHOLD), off its own mate cooldown, and the total animal
## population is still under MAX_ANIMAL_POPULATION. Used both to filter
## find_nearest(tag=&"mate") candidates and by MateGoal/MateAction to gate
## the actor itself.
func is_mate_eligible(world: ECSWorld, entity: int) -> bool:
	if not world.has_component(entity, ANIMAL_TYPE):
		return false
	var animal: AnimalComponent = world.get_component(entity, ANIMAL_TYPE)
	if animal.hunger >= MATE_HUNGER_THRESHOLD or animal.mate_cooldown > 0.0:
		return false
	var buf: Array[int] = []
	world.query_into([ANIMAL_TYPE], buf)
	return buf.size() < MAX_ANIMAL_POPULATION

## True if `entity` should be off-limits to hunting: too young
## (AnimalComponent.is_juvenile, still short of its maturation delay - see
## AnimalNeedsSystem) or actively engaged in mating, whether still
## approaching a partner (current action is MoveToNearestAction targeting
## &"mate") or already mating (current action is MateAction). Deliberately
## separate from is_valid_target()'s generic &"animal" check - MateAction
## itself calls that same check on its own partner, who is by definition
## "protected", so folding this in there would make a mating pair see each
## other as invalid and break mating instead of hunting.
func is_animal_protected(world: ECSWorld, entity: int) -> bool:
	if not world.has_component(entity, ANIMAL_TYPE):
		return true
	if (world.get_component(entity, ANIMAL_TYPE) as AnimalComponent).is_juvenile:
		return true
	if not world.has_component(entity, GOAP_AGENT_TYPE):
		return false
	var agent: GoapAgent = (world.get_component(entity, GOAP_AGENT_TYPE) as GoapAgentComponent).agent
	if agent.current_action_index < 0 or agent.current_action_index >= agent.current_plan.size():
		return false
	var step: GoapAction = agent.current_plan[agent.current_action_index]
	if step is MateAction:
		return true
	return step is MoveToNearestAction and (step as MoveToNearestAction).target_tag == &"mate"

## Locks/unlocks an entity's own movement (see PathFollowComponent.locked) -
## used by any action whose target needs to stay put for the action's
## duration instead of wandering off mid-attempt (HuntAction, MateAction).
func set_locked(world: ECSWorld, entity: int, locked: bool) -> void:
	if entity == -1 or not world.is_alive(entity) or not world.has_component(entity, PATH_FOLLOW_TYPE):
		return
	(world.get_component(entity, PATH_FOLLOW_TYPE) as PathFollowComponent).locked = locked

## True once no StorageComponent in the world has free space left (or there
## are none at all) - see game/goap/goals/deliver_resource_goal.gd.
func all_storages_full(world: ECSWorld) -> bool:
	var buf: Array[int] = []
	world.query_into([STORAGE_TYPE], buf)
	if buf.is_empty():
		return true
	for e in buf:
		if not (world.get_component(e, STORAGE_TYPE) as StorageComponent).is_full():
			return false
	return true

## Single despawn path for both game logic (HuntAction killing its quarry)
## and the dev panel's remove tool: frees the entity's visual node (if any)
## before destroying the ECS entity, so no orphaned Sprite2D/Label is left
## behind in the scene tree.
func despawn_entity(world: ECSWorld, entity: int) -> void:
	if not world.is_alive(entity):
		return
	if world.has_component(entity, NODE_REF_TYPE):
		var node_ref: NodeRefComponent = world.get_component(entity, NODE_REF_TYPE)
		if is_instance_valid(node_ref.node):
			node_ref.node.queue_free()
	world.destroy_entity(entity)
