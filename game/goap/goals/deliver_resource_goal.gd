class_name DeliverResourceGoal
extends GoapGoal

## "Bring a gathered resource to storage" - always desires the synthetic
## `delivered_fact` the matching DepositResourceAction sets as an effect
## (see its doc comment for why that makes the gather -> deliver cycle
## repeat forever). Only subclasses GoapGoal for the dynamic is_valid(): once
## every storage is full, or (when `requires_tag` is set) no source of the
## resource exists at all - e.g. every animal has been hunted out - this
## goal becomes unselectable, so the settler's lower-priority wander_goal
## takes over instead of endlessly re-planning an unreachable delivery.
## Without the `requires_tag` check, a hunter with no animals left to find
## would sit is_valid()==true forever (storage isn't full, it's just that
## nothing can satisfy the goal), and GoapPlanner.plan() would keep failing
## every recheck without ever falling back to wander_goal.

@export var delivered_fact: String = "delivered"
@export var requires_tag: StringName = &""

func is_valid(agent_owner: Variant) -> bool:
	if Game.all_storages_full(Game.ecs_world):
		return false
	if requires_tag == &"":
		return true
	var world: ECSWorld = Game.ecs_world
	return Game.find_nearest(world, Game.get_entity_position(world, agent_owner), requires_tag) != -1

func resolve_alternatives(_agent_owner: Variant) -> Array[Dictionary]:
	return [{delivered_fact: true}]
