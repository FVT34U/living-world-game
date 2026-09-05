class_name AttributeType
extends Resource

## An abstract characteristic identity ("satiety", "health", ...) that an
## AttributeSet tracks a value for. Save instances as .tres assets (e.g.
## res://.../health.tres) the same way GoapResourceType works in the goap
## addon - a designer authors/tunes a characteristic entirely in the
## Inspector, no subclassing needed for the common case.
##
## This addon never inspects `id` beyond using it as a Dictionary key
## fallback - what a "satiety" or "health" value *means*, and what reads or
## changes it, is entirely up to the consuming project.

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D

@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var default_value: float = 100.0

## Passive change per second an AttributeSet.tick() call applies on its own,
## with no other code involved - positive drifts the value up (e.g. age
## climbing every second), negative drifts it down (e.g. satiety fading),
## zero means "only ever changes when something explicit calls
## set_value()/add_value()" (e.g. health, which should hold steady until an
## event changes it, not fade on its own).
@export var regen_per_second: float = 0.0
