class_name System
extends RefCounted

## Base class for ECS systems. A System holds no per-entity state itself -
## only a handful of System instances exist, one per behavior, each iterating
## many entities via World.query_into().

enum Phase { PROCESS, PHYSICS_PROCESS }

## Lower priority runs first within its phase.
var priority: int = 0
var phase: int = Phase.PROCESS

func _init(p_priority: int = 0, p_phase: int = Phase.PROCESS) -> void:
	priority = p_priority
	phase = p_phase

## Override in subclasses. Called once per frame (or physics tick) by ECSWorld.
func update(world: ECSWorld, delta: float) -> void:
	pass
