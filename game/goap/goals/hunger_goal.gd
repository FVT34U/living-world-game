class_name HungerGoal
extends GoapGoal

## Dynamic-priority goal driving an animal's "eat a plant" behavior: only
## valid once its own Satiety attribute (addons/attributes) has faded below
## `satiety_threshold` *and* a live plant exists somewhere (see
## Game.find_nearest) - otherwise it would keep losing out to wander_goal's
## flat priority forever, or plan for a plant that doesn't exist. Priority
## rises the hungrier the animal gets, so a starving animal is more
## insistent about eating than one that just started feeling peckish.
## Demonstrates GoapGoal's get_priority()/is_valid() override hooks (see
## addons/goap/README.md).

@export var satiety_threshold: float = 50.0
@export var desired_fact: String = "ate"

func is_valid(agent_owner: Variant) -> bool:
	var world: ECSWorld = Game.ecs_world
	if not world.has_component(agent_owner, Game.ATTRIBUTES_TYPE):
		return false
	var attrs: AttributeSet = world.get_component(agent_owner, Game.ATTRIBUTES_TYPE)
	if attrs.get_value(Game.SATIETY_ATTR) > satiety_threshold:
		return false
	return Game.find_nearest(world, Game.get_entity_position(world, agent_owner), &"plant") != -1

func get_priority(agent_owner: Variant) -> float:
	var world: ECSWorld = Game.ecs_world
	var attrs: AttributeSet = world.get_component(agent_owner, Game.ATTRIBUTES_TYPE)
	var deficit := satiety_threshold - attrs.get_value(Game.SATIETY_ATTR)  # bigger the hungrier it is
	return priority + deficit * 0.04

func resolve_alternatives(_agent_owner: Variant) -> Array[Dictionary]:
	return [{desired_fact: true}]
