class_name HungerGoal
extends GoapGoal

## Dynamic-priority goal driving an animal's "eat a plant" behavior: only
## valid once its own AnimalComponent.hunger has built up past
## `hunger_threshold` *and* a live plant exists somewhere (see
## Game.find_nearest) - otherwise it would keep losing out to wander_goal's
## flat priority forever, or plan for a plant that doesn't exist. Priority
## rises with hunger, so a starving animal is more insistent about eating
## than one that just started feeling peckish. Demonstrates GoapGoal's
## get_priority()/is_valid() override hooks (see addons/goap/README.md).

@export var hunger_threshold: float = 0.5
@export var desired_fact: String = "ate"

func is_valid(agent_owner: Variant) -> bool:
	var world: ECSWorld = Game.ecs_world
	if not world.has_component(agent_owner, Game.ANIMAL_TYPE):
		return false
	var animal: AnimalComponent = world.get_component(agent_owner, Game.ANIMAL_TYPE)
	if animal.hunger < hunger_threshold:
		return false
	return Game.find_nearest(world, Game.get_entity_position(world, agent_owner), &"plant") != -1

func get_priority(agent_owner: Variant) -> float:
	var world: ECSWorld = Game.ecs_world
	var animal: AnimalComponent = world.get_component(agent_owner, Game.ANIMAL_TYPE)
	return priority + animal.hunger

func resolve_alternatives(_agent_owner: Variant) -> Array[Dictionary]:
	return [{desired_fact: true}]
