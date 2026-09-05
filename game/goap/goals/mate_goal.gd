class_name MateGoal
extends GoapGoal

## Valid only while this animal is itself eligible to mate (well-fed, off
## cooldown, population under the cap - see Game.is_mate_eligible()) *and* a
## same-species eligible partner exists somewhere (see Game.find_nearest,
## tag &"mate"). Sits at a flat priority between wander_goal (always valid,
## lowest) and hunger_goal (rises with hunger) - the two are mutually
## exclusive in practice anyway, since hunger_goal only activates at or
## above hunger 0.5 and mating requires hunger below 0.3.

@export var desired_fact: String = "mated"

func is_valid(agent_owner: Variant) -> bool:
	var world: ECSWorld = Game.ecs_world
	if not Game.is_mate_eligible(world, agent_owner):
		return false
	return Game.find_nearest(world, Game.get_entity_position(world, agent_owner), &"mate", agent_owner) != -1

func resolve_alternatives(_agent_owner: Variant) -> Array[Dictionary]:
	return [{desired_fact: true}]
