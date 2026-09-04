class_name GoapPlanningSystem
extends System

## Ticks a bounded number of GOAP agents per frame (round-robin), instead of
## every agent every frame - the concrete mitigation for "many NPCs planning
## in the same frame" mentioned in the goap addon's README. With more agents
## than MAX_PLANNING_TICKS_PER_FRAME, each agent effectively ticks less often
## than every frame; a production system with large NPC counts should pass
## each entity's own elapsed-time-since-last-tick instead of raw frame delta
## so timers (goal_recheck_interval, action durations) stay accurate. Not
## needed at this project's current demo scale (a handful of NPCs).

const MAX_PLANNING_TICKS_PER_FRAME := 8

var _buf: Array[int] = []
var _cursor: int = 0

func update(world: ECSWorld, delta: float) -> void:
	world.query_into([Game.GOAP_AGENT_TYPE], _buf)
	var n := _buf.size()
	if n == 0:
		return
	var processed := 0
	while processed < MAX_PLANNING_TICKS_PER_FRAME and processed < n:
		var e: int = _buf[_cursor % n]
		var comp: GoapAgentComponent = world.get_component(e, Game.GOAP_AGENT_TYPE)
		var state := Game.build_world_state(world, e)
		comp.agent.tick(e, state, delta)
		_cursor += 1
		processed += 1
