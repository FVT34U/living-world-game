class_name GoapAgent
extends RefCounted

## Drives goal selection, planning and plan execution for one agent.
## Knows nothing about ECS or any concrete game type - the caller supplies
## `agent_owner` (forwarded untouched into action/goal callbacks) and a fresh
## GoapWorldState each tick.

var goals: Array[GoapGoal] = []
var actions: Array[GoapAction] = []

var current_goal: GoapGoal = null
var current_plan: Array[GoapAction] = []
var current_action_index: int = -1

## How often (seconds) to re-evaluate goal choice while a plan is running.
## Stagger this per agent (e.g. seed _goal_recheck_timer with a random value
## at spawn) so many agents don't all re-evaluate on the same frame.
var goal_recheck_interval: float = 1.0
var _goal_recheck_timer: float = 0.0

func select_goal(agent_owner: Variant) -> GoapGoal:
	var best: GoapGoal = null
	var best_priority := -INF
	for g in goals:
		if g.is_valid(agent_owner):
			var p := g.get_priority(agent_owner)
			if p > best_priority:
				best_priority = p
				best = g
	return best

## Call once per tick (typically from a budgeted ECS system, not every agent
## every frame) with the agent's live world-state snapshot.
func tick(agent_owner: Variant, state: GoapWorldState, delta: float) -> void:
	_goal_recheck_timer -= delta
	if current_plan.is_empty() or _goal_recheck_timer <= 0.0:
		_goal_recheck_timer = goal_recheck_interval
		var new_goal := select_goal(agent_owner)
		if new_goal != current_goal or current_plan.is_empty():
			current_goal = new_goal
			_replan(agent_owner, state)

	if current_action_index < 0 or current_action_index >= current_plan.size():
		return

	var action: GoapAction = current_plan[current_action_index]
	if not action.is_ready(agent_owner) or not state.matches(action.get_preconditions(agent_owner, state)):
		_replan(agent_owner, state)
		return

	var status := action.perform(agent_owner, delta)
	match status:
		GoapAction.Status.SUCCESS:
			action.stop(agent_owner)
			current_action_index += 1
			if current_action_index >= current_plan.size():
				current_plan.clear()
				current_action_index = -1
			else:
				# Every action becomes "current" through this same lifecycle
				# step - index 0 via _replan() below, every later index via
				# this advance - so start() is always called exactly once
				# when an action becomes current, never skipped for
				# non-first plan steps.
				current_plan[current_action_index].start(agent_owner)
		GoapAction.Status.FAILED:
			_replan(agent_owner, state)
		GoapAction.Status.RUNNING:
			pass

## Clears the current plan and searches for a new one for `current_goal`.
## Called from every path that abandons a plan before it finishes on its
## own (a changed goal, a failed action, a precondition that stopped
## matching) - including the goal-recheck at the top of tick(), which can
## fire while an action is still RUNNING. Always calls stop() on whatever
## action was still current first, so an action's start()/stop() pair stays
## a reliable place for setup/teardown (e.g. locking an external resource
## for the action's duration) no matter which of those paths ends it -
## forgetting this here previously left a locked target stuck forever
## whenever a plan was abandoned this way instead of finishing cleanly.
func _replan(agent_owner: Variant, state: GoapWorldState) -> void:
	if current_action_index >= 0 and current_action_index < current_plan.size():
		current_plan[current_action_index].stop(agent_owner)
	current_plan.clear()
	current_action_index = -1
	if current_goal == null:
		return
	var new_plan := GoapPlanner.plan(agent_owner, state, current_goal, actions)
	if not new_plan.is_empty():
		current_plan = new_plan
		current_action_index = 0
		current_plan[0].start(agent_owner)
