class_name GoapWorldState
extends RefCounted

## A snapshot of symbolic facts about the world/agent, as seen by the planner.
## Keys and values are entirely domain-defined (this addon never inspects
## them) - e.g. {"at_woodpile": true, "inventory_wood": 3}.

var facts: Dictionary = {}

func get_value(key: String, default: Variant = null) -> Variant:
	return facts.get(key, default)

func set_value(key: String, value: Variant) -> void:
	facts[key] = value

## True if every key/value pair in `required` is present and equal in this state.
func matches(required: Dictionary) -> bool:
	for k in required:
		if facts.get(k) != required[k]:
			return false
	return true

## Returns a new state equal to this one with `effects` merged on top.
## Facts dictionaries are small (tens of keys), so a shallow copy is cheap.
func apply(effects: Dictionary) -> GoapWorldState:
	var next := GoapWorldState.new()
	next.facts = facts.duplicate()
	for k in effects:
		next.facts[k] = effects[k]
	return next

func duplicate_state() -> GoapWorldState:
	var next := GoapWorldState.new()
	next.facts = facts.duplicate()
	return next
