class_name ComponentStorage
extends RefCounted

## Sparse-set storage for a single component type.
##
## Gives O(1) add/remove/has/get and a tightly packed dense array for fast,
## cache-friendly iteration over every entity that owns this component type.
##
## dense_entities[i] is the entity that owns dense_components[i]; sparse[entity]
## is the index into both dense arrays, or -1 if the entity does not have this
## component.

var dense_components: Array = []
var dense_entities: Array[int] = []
var sparse: Array[int] = []

func has(entity: int) -> bool:
	return entity < sparse.size() and sparse[entity] != -1

func get_comp(entity: int) -> Object:
	return dense_components[sparse[entity]]

func add(entity: int, component: Object) -> void:
	if entity >= sparse.size():
		var old_size := sparse.size()
		sparse.resize(entity + 1)
		# Array.resize() zero-fills new slots, and 0 is a valid dense index,
		# so every newly grown slot must be explicitly marked empty.
		for i in range(old_size, entity + 1):
			sparse[i] = -1
	if has(entity):
		dense_components[sparse[entity]] = component
		return
	sparse[entity] = dense_components.size()
	dense_components.append(component)
	dense_entities.append(entity)

func remove(entity: int) -> void:
	if not has(entity):
		return
	var idx: int = sparse[entity]
	var last_idx := dense_components.size() - 1
	var last_entity: int = dense_entities[last_idx]
	# Swap-remove: move the last dense element into the removed slot so the
	# dense arrays stay contiguous (no holes) without shifting everything.
	dense_components[idx] = dense_components[last_idx]
	dense_entities[idx] = last_entity
	sparse[last_entity] = idx
	dense_components.resize(last_idx)
	dense_entities.resize(last_idx)
	sparse[entity] = -1

func size() -> int:
	return dense_components.size()

func clear() -> void:
	dense_components.clear()
	dense_entities.clear()
	sparse.clear()
