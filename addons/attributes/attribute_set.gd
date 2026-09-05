class_name AttributeSet
extends RefCounted

## Generic per-character bag of attribute values. Zero dependency on ECS,
## GOAP, pathfinding, or any concept of "player" vs "NPC" - construct one
## for any character and register() whichever AttributeType resources apply
## to it. A game can drop this straight in as an ECS component (it needs no
## adapter - see game/game_singleton.gd's ATTRIBUTES_TYPE in this project),
## attach it to a plain Node, or use it standalone.
##
## This addon has no _process of its own and starts no timers - call tick()
## once per update from your own game loop/system to apply every registered
## type's passive regen_per_second.

signal value_changed(type: AttributeType, old_value: float, new_value: float)
## Emitted the instant a value crosses down to its type's min_value (from
## above it) - e.g. to react to satiety hitting zero.
signal depleted(type: AttributeType)
## Emitted the instant a value crosses up to its type's max_value (from
## below it) - e.g. to react to energy topping out.
signal filled(type: AttributeType)

var _values: Dictionary = {}  # AttributeType -> float

## Adds `type` to this set. `value` defaults to the type's own
## `default_value` when left as NAN (the common case) - pass an explicit
## value to start a character above/below the type default (e.g. a
## newborn's age, or a randomized starting satiety).
func register(type: AttributeType, value: float = NAN) -> void:
	_values[type] = clampf(type.default_value if is_nan(value) else value, type.min_value, type.max_value)

func has(type: AttributeType) -> bool:
	return _values.has(type)

## Returns the type's own default_value (or 0.0 if `type` is null) for a
## type never registered, rather than erroring - reading a value you
## haven't set up yet is a reasonable no-op, unlike writing one.
func get_value(type: AttributeType) -> float:
	if _values.has(type):
		return _values[type]
	return type.default_value if type else 0.0

## 0..1 position between min_value and max_value - convenient for driving a
## bar/meter or for game-layer logic that wants to compare characteristics
## on a common scale regardless of each one's own range.
func get_ratio(type: AttributeType) -> float:
	var span := type.max_value - type.min_value
	return 0.0 if span <= 0.0 else clampf((get_value(type) - type.min_value) / span, 0.0, 1.0)

## Clamps to [min_value, max_value] and emits value_changed/depleted/filled
## as appropriate. A no-op (no signals) if the clamped result doesn't
## actually differ from the current value.
func set_value(type: AttributeType, value: float) -> void:
	var old_value := get_value(type)
	var new_value := clampf(value, type.min_value, type.max_value)
	if is_equal_approx(old_value, new_value):
		return
	_values[type] = new_value
	value_changed.emit(type, old_value, new_value)
	if new_value <= type.min_value and old_value > type.min_value:
		depleted.emit(type)
	if new_value >= type.max_value and old_value < type.max_value:
		filled.emit(type)

func add_value(type: AttributeType, delta: float) -> void:
	set_value(type, get_value(type) + delta)

## Applies every registered type's regen_per_second * delta. Call once per
## update from whatever drives this character (a budgeted ECS system, a
## Node's _process, ...) - this addon never ticks itself.
func tick(delta: float) -> void:
	for type: AttributeType in _values.keys():
		if type.regen_per_second != 0.0:
			add_value(type, type.regen_per_second * delta)
