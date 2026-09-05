class_name AnimalNeedsSystem
extends System

## Raises each living animal's hunger over time so HungerGoal's dynamic
## priority eventually outweighs wander_goal's flat one - see
## game/goap/goals/hunger_goal.gd. Runs before GoapPlanningSystem (lower
## priority number) so a hunger change is visible to the same frame's
## planning tick.

const HUNGER_RATE := 0.05  # per second; crosses the default 0.5 threshold in ~10s

var _buf: Array[int] = []

func _init() -> void:
	super._init(-10, System.Phase.PROCESS)

func update(world: ECSWorld, delta: float) -> void:
	world.query_into([Game.ANIMAL_TYPE], _buf)
	for e in _buf:
		var a: AnimalComponent = world.get_component(e, Game.ANIMAL_TYPE)
		a.hunger = minf(a.hunger + HUNGER_RATE * delta, 2.0)
