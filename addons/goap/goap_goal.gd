class_name GoapGoal
extends Resource

## A desired end-state the planner should try to reach. A Resource so it can
## be authored as a .tres asset (New Resource + Inspector, or the Goal Graph
## Editor bottom panel) instead of a GDScript subclass.
##
## `desired_state` is the flexible escape hatch for arbitrary positional
## facts (e.g. "at_landmark": true). `target_resource` is the abstraction
## convenience for the common "obtain some resource" case - set it instead
## of typing a fact key by hand, and it stays consistent with whatever
## GoapAction.produces_resource actions declare for the same GoapResourceType.

@export var goal_name: String = ""
@export var desired_state: Dictionary = {}
@export var target_resource: GoapResourceType
@export var priority: float = 0.0

## Editor-only: remembers this goal's node position in the Goal Graph Editor
## between sessions. Not read by planning.
@export var editor_graph_position: Vector2 = Vector2.ZERO

## Override for dynamic priority (e.g. hunger-based urgency).
func get_priority(_agent_owner: Variant) -> float:
	return priority

## Override to make a goal unselectable under some condition
## (e.g. "gather wood" invalid once storage is full).
func is_valid(_agent_owner: Variant) -> bool:
	return true

## Returns the set of flat fact-dictionaries that would each independently
## satisfy this goal. A leaf goal has exactly one. GoapCompositeGoal
## overrides this to combine sub-goals with AND (cartesian-merge) or OR
## (union) semantics - see goap_composite_goal.gd. The planner runs a search
## per alternative and keeps the cheapest successful plan.
func resolve_alternatives(_agent_owner: Variant) -> Array[Dictionary]:
	return [_effective_desired_state()]

func _effective_desired_state() -> Dictionary:
	var state := desired_state.duplicate()
	if target_resource:
		state[target_resource.fact_key()] = true
	return state
