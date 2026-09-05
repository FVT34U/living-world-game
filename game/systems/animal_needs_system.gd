class_name AnimalNeedsSystem
extends System

## Counts down each animal's mate_cooldown (see AnimalComponent) and clears
## is_juvenile once a newborn's maturation delay runs out - AnimalComponent
## fields with no equivalent in the generic addons/attributes system, so
## they're ticked separately from AttributeConsequenceSystem's
## AttributeSet.tick() (which drives Satiety/Energy/Age's passive drift).
## Runs before GoapPlanningSystem (lower priority number) so the change is
## visible to the same frame's planning tick.

var _buf: Array[int] = []

func _init() -> void:
	super._init(-10, System.Phase.PROCESS)

func update(world: ECSWorld, delta: float) -> void:
	world.query_into([Game.ANIMAL_TYPE], _buf)
	for e in _buf:
		var a: AnimalComponent = world.get_component(e, Game.ANIMAL_TYPE)
		if a.mate_cooldown > 0.0:
			a.mate_cooldown = maxf(a.mate_cooldown - delta, 0.0)
			if a.mate_cooldown <= 0.0:
				a.is_juvenile = false
