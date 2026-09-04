class_name GoapAction
extends Resource

## Base class for a GOAP action. A Resource so a single script (e.g.
## "AttackAction.gd") can back many .tres instances with different exported
## parameters ("attack_light.tres", "attack_heavy.tres") instead of one
## GDScript subclass per variant.
##
## Subclass this in game code and override the virtual methods to reach into
## your own ECS/game state - this addon never imports or assumes anything
## about how `agent_owner` is represented; it is an opaque value (an entity
## int, a Node, anything) forwarded untouched into every call. Typed as
## Variant rather than Object since GDScript's static type system does not
## consider `int` a subtype of `Object`.
##
## IMPORTANT - shared Resource instances: a .tres loaded via load()/preload()
## is a single cached object. Any action with runtime-mutable state (a
## "requested" flag, an elapsed timer - see MoveToAction/ChopWoodAction in
## the game/ layer) will corrupt that state across agents if the same loaded
## instance is reused directly. Always call instantiate_for_agent() (or
## .duplicate(true)) before adding a template action to an agent's action
## list. See addons/goap/README.md.

enum Status { RUNNING, SUCCESS, FAILED }

@export var action_name: String = ""
@export var cost: float = 1.0

## Static requirements checked against GoapWorldState.facts by the planner.
## Flexible escape hatch for arbitrary positional facts (e.g. "at_woodpile").
@export var preconditions: Dictionary = {}
## Static effects applied to GoapWorldState.facts by the planner.
@export var effects: Dictionary = {}

## Abstraction convenience: when set, get_preconditions()/procedural_effects()
## automatically fold in `resource.fact_key(): true` alongside the raw dicts
## above, so a designer can point at a GoapResourceType asset instead of
## typing a fact string.
@export var requires_resource: GoapResourceType
@export var produces_resource: GoapResourceType

## The planner/agent call this instead of reading `preconditions` directly.
func get_preconditions(_agent_owner: Variant, _state: GoapWorldState) -> Dictionary:
	var d := preconditions.duplicate()
	if requires_resource:
		d[requires_resource.fact_key()] = true
	return d

## Dynamic validity check the planner cannot express via `preconditions` alone
## (e.g. "a free bed exists nearby"). Called during planning, must be cheap.
func is_procedurally_valid(_agent_owner: Variant, _state: GoapWorldState) -> bool:
	return true

## Dynamic cost (distance-based, scarcity-based, ...) used during planning.
## Defaults to the static `cost`.
func get_cost(_agent_owner: Variant, _state: GoapWorldState) -> float:
	return cost

## Dynamic effects the planner should simulate for this action.
## Defaults to `effects` merged with `produces_resource.fact_key(): true`.
func procedural_effects(_agent_owner: Variant, _state: GoapWorldState) -> Dictionary:
	var d := effects.duplicate()
	if produces_resource:
		d[produces_resource.fact_key()] = true
	return d

## Runtime gate checked right before/while executing (e.g. target still valid).
func is_ready(_agent_owner: Variant) -> bool:
	return true

func start(_agent_owner: Variant) -> void:
	pass

## Called every tick while this action is the current plan step.
## Return SUCCESS to advance to the next action, FAILED to trigger a replan,
## RUNNING to keep executing.
func perform(_agent_owner: Variant, _delta: float) -> int:
	return Status.SUCCESS

func stop(_agent_owner: Variant) -> void:
	pass

## Returns an independent runtime copy of this action template. Call this
## when adding a shared/loaded action Resource to an agent's action list -
## see the class-level note above.
func instantiate_for_agent() -> GoapAction:
	return duplicate(true)
