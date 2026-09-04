class_name GoapPlanner
extends RefCounted

## Forward A* planner: searches forward from the current world state toward
## a goal's desired_state, expanding one node per applicable action.
##
## Forward search (rather than backward/regression search from the goal) is
## used deliberately: it reuses GoapWorldState directly with no separate
## "regression state merge" logic to get subtly wrong, which matters more
## here than shaving search cost, since per-agent state/action sets are small.
## The performance risk that actually matters - many agents planning in the
## same frame - is mitigated by budgeting planner calls per frame in the
## calling system, not by the search algorithm itself.
##
## A goal may resolve into several alternative desired-state dictionaries
## (see GoapGoal.resolve_alternatives() / GoapCompositeGoal for AND/OR
## composition) - plan() searches once per alternative, sharing one
## MAX_EXPANSIONS budget across all of them, and keeps the cheapest
## successful plan. A plain leaf GoapGoal always resolves to exactly one
## alternative, so this is a no-op for simple, non-composite goals.

## Hard cap on nodes expanded per plan() call, shared across every
## alternative a composite goal resolves into - bounds worst-case cost.
const MAX_EXPANSIONS := 500

class PlanNode:
	var state: GoapWorldState
	var g: float
	var f: float
	var action: GoapAction  # action taken to reach this node from its parent; null at root
	var parent: PlanNode

class SearchResult:
	var plan: Array[GoapAction] = []
	var cost: float = INF
	var expansions: int = 0

static func _heuristic(state: GoapWorldState, desired_state: Dictionary) -> float:
	var unsatisfied := 0
	for k in desired_state:
		if state.get_value(k) != desired_state[k]:
			unsatisfied += 1
	return float(unsatisfied)

## Returns an ordered Array[GoapAction] plan, or an empty array if none was
## found within MAX_EXPANSIONS.
static func plan(agent_owner: Variant, start_state: GoapWorldState, goal: GoapGoal, actions: Array[GoapAction]) -> Array[GoapAction]:
	var alternatives := goal.resolve_alternatives(agent_owner)
	var best_plan: Array[GoapAction] = []
	var best_cost := INF
	var expansions_used := 0
	for desired_state in alternatives:
		if expansions_used >= MAX_EXPANSIONS:
			break
		var result := _search(agent_owner, start_state, desired_state, actions, MAX_EXPANSIONS - expansions_used)
		expansions_used += result.expansions
		if not result.plan.is_empty() and result.cost < best_cost:
			best_cost = result.cost
			best_plan = result.plan
	return best_plan

static func _search(agent_owner: Variant, start_state: GoapWorldState, desired_state: Dictionary, actions: Array[GoapAction], expansion_budget: int) -> SearchResult:
	var result := SearchResult.new()
	var open := GoapPriorityQueue.new()
	var root := PlanNode.new()
	root.state = start_state
	root.g = 0.0
	root.f = _heuristic(start_state, desired_state)
	open.push(root)

	while not open.is_empty() and result.expansions < expansion_budget:
		result.expansions += 1
		var node: PlanNode = open.pop()
		if node.state.matches(desired_state):
			result.plan = _reconstruct(node)
			result.cost = node.g
			return result
		for action in actions:
			if not node.state.matches(action.get_preconditions(agent_owner, node.state)):
				continue
			if not action.is_procedurally_valid(agent_owner, node.state):
				continue
			var next := PlanNode.new()
			next.state = node.state.apply(action.procedural_effects(agent_owner, node.state))
			next.g = node.g + action.get_cost(agent_owner, node.state)
			next.f = next.g + _heuristic(next.state, desired_state)
			next.action = action
			next.parent = node
			open.push(next)
	return result

static func _reconstruct(node: PlanNode) -> Array[GoapAction]:
	var chain: Array[GoapAction] = []
	var n := node
	while n.action != null:
		chain.push_front(n.action)
		n = n.parent
	return chain
