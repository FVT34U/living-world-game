class_name DeliverResourceGoal
extends GoapGoal

## "Bring a gathered resource to storage" - always desires the synthetic
## `delivered_fact` the matching DepositResourceAction sets as an effect
## (see its doc comment for why that makes the gather -> deliver cycle
## repeat forever). Only subclasses GoapGoal for the dynamic is_valid(): once
## every storage is full this goal becomes unselectable, so the settler's
## lower-priority wander_goal takes over instead of endlessly re-planning an
## unreachable delivery.

@export var delivered_fact: String = "delivered"

func is_valid(_agent_owner: Variant) -> bool:
	return not Game.all_storages_full(Game.ecs_world)

func resolve_alternatives(_agent_owner: Variant) -> Array[Dictionary]:
	return [{delivered_fact: true}]
