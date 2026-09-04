class_name GoapCompositeGoal
extends GoapGoal

## A goal built out of several other goals, combined as AND (ALL) or OR (ANY).
## Example: "prepare for winter" = ALL[gather wood, gather meat].
## Example: "forage anything" = ANY[gather wood, gather meat].
##
## Recurses naturally - a sub_goal can itself be a GoapCompositeGoal. Reuses
## the unmodified forward-search planner: ALL flattens into merged fact
## dictionaries (one search covers all of them at once), ANY expands into
## several independent alternatives (the planner tries each and keeps the
## cheapest plan) - see GoapPlanner.plan().

enum Mode { ALL, ANY }

## Hard cap on how many alternative fact-dictionaries resolve_alternatives()
## may produce, so a wide/deep goal tree can't blow up planning cost.
const MAX_ALTERNATIVES := 16

@export var mode: Mode = Mode.ALL
@export var sub_goals: Array[GoapGoal] = []

func resolve_alternatives(agent_owner: Variant) -> Array[Dictionary]:
	if sub_goals.is_empty():
		return [{}] if mode == Mode.ALL else []
	if mode == Mode.ALL:
		return _resolve_all(agent_owner)
	return _resolve_any(agent_owner)

## AND: every sub-goal must hold at once. Cartesian-merges one alternative
## from each sub-goal per combination (later sub-goals win on key conflicts).
func _resolve_all(agent_owner: Variant) -> Array[Dictionary]:
	var combos: Array[Dictionary] = [{}]
	for sub in sub_goals:
		var sub_alts := sub.resolve_alternatives(agent_owner)
		if sub_alts.is_empty():
			return []  # a required sub-goal with no way to satisfy it makes ALL unsatisfiable
		var next_combos: Array[Dictionary] = []
		for combo in combos:
			for alt in sub_alts:
				var merged := combo.duplicate()
				for k in alt:
					merged[k] = alt[k]
				next_combos.append(merged)
				if next_combos.size() >= MAX_ALTERNATIVES:
					break
			if next_combos.size() >= MAX_ALTERNATIVES:
				break
		combos = next_combos
		if combos.size() >= MAX_ALTERNATIVES:
			break
	return combos

## OR: any single sub-goal being satisfied is enough. Unions each sub-goal's
## own alternatives into one flat list of options.
func _resolve_any(agent_owner: Variant) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for sub in sub_goals:
		for alt in sub.resolve_alternatives(agent_owner):
			options.append(alt)
			if options.size() >= MAX_ALTERNATIVES:
				return options
	return options
